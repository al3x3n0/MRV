// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "xm_macro.svh"

`TRACING_OFF
module xrv_mem_coalescer #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_REQS      = 1,
    parameter ADDR_WIDTH    = 32,
    parameter FLAGS_WIDTH   = 0,
    parameter DATA_IN_SIZE  = 4,
    parameter DATA_OUT_SIZE = 64,
    parameter TAG_WIDTH     = 8,
    parameter UUID_WIDTH    = 0, // upper section of the request tag contains the UUID
    parameter QUEUE_SIZE    = 8,

    parameter DATA_IN_WIDTH = DATA_IN_SIZE * 8,
    parameter DATA_OUT_WIDTH= DATA_OUT_SIZE * 8,
    parameter DATA_RATIO    = DATA_OUT_SIZE / DATA_IN_SIZE,
    parameter DATA_RATIO_W  = `XM_LOG2UP(DATA_RATIO),
    parameter OUT_REQS      = NUM_REQS / DATA_RATIO,
    parameter OUT_ADDR_WIDTH= ADDR_WIDTH - DATA_RATIO_W,
    parameter QUEUE_ADDRW   = `XM_CLOG2(QUEUE_SIZE),
    parameter OUT_TAG_WIDTH = UUID_WIDTH + QUEUE_ADDRW
) (
    input wire clk_i,
    input wire rst_i,

    // Input request
    input wire                          in_req_vld,
    input wire                          in_req_rw,
    input wire [NUM_REQS-1:0]           in_req_mask,
    input wire [NUM_REQS-1:0][DATA_IN_SIZE-1:0] in_req_be,
    input wire [NUM_REQS-1:0][ADDR_WIDTH-1:0] in_req_addr,
    input wire [NUM_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] in_req_flags,
    input wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_req_data,
    input wire [TAG_WIDTH-1:0]          in_req_tag,
    output wire                         in_req_rdy,

    // Input response
    output wire                         in_resp_vld,
    output wire [NUM_REQS-1:0]          in_resp_mask,
    output wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_resp_data,
    output wire [TAG_WIDTH-1:0]         in_resp_tag,
    input wire                          in_resp_rdy,

    // Output request
    output wire                         out_req_vld,
    output wire                         out_req_rw,
    output wire [OUT_REQS-1:0]          out_req_mask,
    output wire [OUT_REQS-1:0][DATA_OUT_SIZE-1:0] out_req_be,
    output wire [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] out_req_addr,
    output wire [OUT_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] out_req_flags,
    output wire [OUT_REQS-1:0][DATA_OUT_WIDTH-1:0] out_req_data,
    output wire [OUT_TAG_WIDTH-1:0]     out_req_tag,
    input wire 	                        out_req_rdy,

    // Output response
    input wire                          out_resp_vld,
    input wire [OUT_REQS-1:0]           out_resp_mask,
    input wire [OUT_REQS-1:0][DATA_OUT_WIDTH-1:0] out_resp_data,
    input wire [OUT_TAG_WIDTH-1:0]      out_resp_tag,
    output wire                         out_resp_rdy
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    `STATIC_ASSERT ((NUM_REQS > 1), ("invld parameter"))
    `STATIC_ASSERT (`XM_IS_DIVISBLE(NUM_REQS * DATA_IN_WIDTH, DATA_OUT_WIDTH), ("invld parameter"))
    `STATIC_ASSERT ((NUM_REQS * DATA_IN_WIDTH >= DATA_OUT_WIDTH), ("invld parameter"))
    `RUNTIME_ASSERT ((~in_req_vld || in_req_mask != 0), ("%t: invld request mask", $time))
    `RUNTIME_ASSERT ((~out_resp_vld || out_resp_mask != 0), ("%t: invld request mask", $time))

    localparam TAG_ID_WIDTH = TAG_WIDTH - UUID_WIDTH;
    //                           tag          + mask     + offest
    localparam IBUF_DATA_WIDTH = TAG_ID_WIDTH + NUM_REQS + (NUM_REQS * DATA_RATIO_W);

    localparam STATE_WAIT = 0;
    localparam STATE_SEND = 1;

    logic state_r, state_n;

    logic out_req_vld_r, out_req_vld_n;
    logic out_req_rw_r, out_req_rw_n;
    logic [OUT_REQS-1:0] out_req_mask_r, out_req_mask_n;
    logic [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] out_req_addr_r, out_req_addr_n;
    logic [OUT_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] out_req_flags_r, out_req_flags_n;
    logic [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_SIZE-1:0] out_req_be_r, out_req_be_n;
    logic [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_WIDTH-1:0] out_req_data_r, out_req_data_n;
    logic [OUT_TAG_WIDTH-1:0] out_req_tag_r, out_req_tag_n;

    reg in_req_rdy_n;

    wire                        ibuf_push;
    wire                        ibuf_pop;
    wire [QUEUE_ADDRW-1:0]      ibuf_waddr;
    wire [QUEUE_ADDRW-1:0]      ibuf_raddr;
    wire                        ibuf_full;
    wire                        ibuf_empty;
    wire [IBUF_DATA_WIDTH-1:0]  ibuf_din;
    wire [IBUF_DATA_WIDTH-1:0]  ibuf_dout;

    logic [OUT_REQS-1:0] batch_vld_r, batch_vld_n;
    logic [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] seed_addr_r, seed_addr_n;
    logic [OUT_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] seed_flags_r, seed_flags_n;
    logic [NUM_REQS-1:0] addr_matches_r, addr_matches_n;
    logic [NUM_REQS-1:0] req_rem_mask_r, req_rem_mask_n;

    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] in_addr_offset;
    for (genvar i = 0; i < NUM_REQS; i++) begin : g_in_addr_offset
        assign in_addr_offset[i] = in_req_addr[i][DATA_RATIO_W-1:0];
    end

    for (genvar i = 0; i < OUT_REQS; ++i) begin : g_seed_gen
        wire [DATA_RATIO-1:0] batch_mask;
        wire [DATA_RATIO_W-1:0] batch_idx;

        assign batch_mask = in_req_mask[i * DATA_RATIO +: DATA_RATIO] & req_rem_mask_r[i * DATA_RATIO +: DATA_RATIO];

        xrv_priority_encoder #(
            .N (DATA_RATIO)
        ) priority_encoder (
            .data_i         (batch_mask),
            .index_o        (batch_idx),
            `XM_UNUSED_PIN  (onehot_o),
            .vld_o          (batch_vld_n[i])
        );

        wire [DATA_RATIO-1:0][OUT_ADDR_WIDTH-1:0] addr_base;
        for (genvar j = 0; j < DATA_RATIO; ++j) begin : g_addr_base
            assign addr_base[j] = in_req_addr[DATA_RATIO * i + j][ADDR_WIDTH-1:DATA_RATIO_W];
        end

        wire [DATA_RATIO-1:0][`XM_UP(FLAGS_WIDTH)-1:0] req_flags;
        for (genvar j = 0; j < DATA_RATIO; ++j) begin : g_req_flags
            assign req_flags[j] = in_req_flags[DATA_RATIO * i + j];
        end

        assign seed_addr_n[i]  = addr_base[batch_idx];
        assign seed_flags_n[i] = req_flags[batch_idx];

        for (genvar j = 0; j < DATA_RATIO; ++j) begin : g_addr_matches_n
            assign addr_matches_n[i * DATA_RATIO + j] = (addr_base[j] == seed_addr_n[i]);
        end
    end

    wire [NUM_REQS-1:0] current_pmask = in_req_mask & addr_matches_r;

    wire [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_SIZE-1:0] req_be_merged;
    wire [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_WIDTH-1:0] req_data_merged;

    for (genvar i = 0; i < OUT_REQS; ++i) begin : g_data_merged
        reg [DATA_RATIO-1:0][DATA_IN_SIZE-1:0] be_merged;
        reg [DATA_RATIO-1:0][DATA_IN_WIDTH-1:0] data_merged;
        always @(*) begin
            be_merged = '0;
            data_merged = 'x;
            for (integer j = 0; j < DATA_RATIO; ++j) begin
                for (integer k = 0; k < DATA_IN_SIZE; ++k) begin
                    // perform byte-level merge since each thread may have different bytes enabled
                    if (current_pmask[i * DATA_RATIO + j] && in_req_be[DATA_RATIO * i + j][k]) begin
                        be_merged[in_addr_offset[DATA_RATIO * i + j]][k] = 1'b1;
                        data_merged[in_addr_offset[DATA_RATIO * i + j]][k * 8 +: 8] = in_req_data[DATA_RATIO * i + j][k * 8 +: 8];
                    end
                end
            end
        end
        assign req_be_merged[i] = be_merged;
        assign req_data_merged[i]   = data_merged;
    end

    wire is_last_batch = ~(| (in_req_mask & ~addr_matches_r & req_rem_mask_r));

    wire out_req_fire = out_req_vld && out_req_rdy;

    always @(*) begin
        state_n          = state_r;
        out_req_vld_n  = out_req_vld_r;
        out_req_mask_n   = out_req_mask_r;
        out_req_rw_n     = out_req_rw_r;
        out_req_addr_n   = out_req_addr_r;
        out_req_flags_n  = out_req_flags_r;
        out_req_be_n = out_req_be_r;
        out_req_data_n   = out_req_data_r;
        out_req_tag_n    = out_req_tag_r;
        req_rem_mask_n   = req_rem_mask_r;
        in_req_rdy_n   = 0;

        case (state_r)
        STATE_WAIT: begin
            // wait for pending outgoing request to submit
            if (out_req_fire) begin
                out_req_vld_n = 0;
            end
            if (in_req_vld && ~out_req_vld_n && ~ibuf_full) begin
                state_n = STATE_SEND;
            end
        end
        default/*STATE_SEND*/: begin
            state_n         = STATE_WAIT;
            out_req_vld_n = 1;
            out_req_mask_n  = batch_vld_r;
            out_req_rw_n    = in_req_rw;
            out_req_addr_n  = seed_addr_r;
            out_req_flags_n = seed_flags_r;
            out_req_be_n= req_be_merged;
            out_req_data_n  = req_data_merged;
            out_req_tag_n   = {in_req_tag[TAG_WIDTH-1 -: UUID_WIDTH], ibuf_waddr};
            req_rem_mask_n  = is_last_batch ? '1 : (req_rem_mask_r & ~current_pmask);
            in_req_rdy_n  = is_last_batch;
        end
        endcase
    end

    xrv_pipe_register #(
        .DATA_WIDTH_P   (1 + NUM_REQS + 1 + 1 + NUM_REQS + OUT_REQS * (1 + 1 + OUT_ADDR_WIDTH + `XM_UP(FLAGS_WIDTH) + OUT_ADDR_WIDTH + `XM_UP(FLAGS_WIDTH) + DATA_OUT_SIZE + DATA_OUT_WIDTH) + OUT_TAG_WIDTH),
        .RESET_WIDTH_P  (1 + NUM_REQS + 1),
        .INIT_VALUE     ({1'b0, {NUM_REQS{1'b1}}, 1'b0})
    ) pipe_reg (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     ({state_n, req_rem_mask_n, out_req_vld_n, out_req_rw_n, addr_matches_n, batch_vld_n, out_req_mask_n, seed_addr_n, seed_flags_n, out_req_addr_n, out_req_flags_n, out_req_be_n, out_req_data_n, out_req_tag_n}),
        .data_o     ({state_r, req_rem_mask_r, out_req_vld_r, out_req_rw_r, addr_matches_r, batch_vld_r, out_req_mask_r, seed_addr_r, seed_flags_r, out_req_addr_r, out_req_flags_r, out_req_be_r, out_req_data_r, out_req_tag_r})
    );

    wire out_resp_fire = out_resp_vld && out_resp_rdy;

    wire out_resp_eop;

    wire req_sent = (state_r == STATE_SEND);

    assign ibuf_push  = req_sent && ~in_req_rw;
    assign ibuf_pop   = out_resp_fire && out_resp_eop;
    assign ibuf_raddr = out_resp_tag[QUEUE_ADDRW-1:0];

    wire [TAG_ID_WIDTH-1:0] ibuf_din_tag = in_req_tag[TAG_ID_WIDTH-1:0];
    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] ibuf_din_offset = in_addr_offset;
    wire [NUM_REQS-1:0] ibuf_din_pmask = current_pmask;

    assign ibuf_din = {ibuf_din_tag, ibuf_din_pmask, ibuf_din_offset};

    xrv_index_buffer #(
        .DATA_WIDTH_P   (IBUF_DATA_WIDTH),
        .SIZE_P         (QUEUE_SIZE)
    ) req_ibuf (
        .clk_i        (clk_i),
        .rst_i        (rst_i),
        .acquire_en   (ibuf_push),
        .write_addr   (ibuf_waddr),
        .write_data   (ibuf_din),
        .read_data    (ibuf_dout),
        .read_addr    (ibuf_raddr),
        .release_en   (ibuf_pop),
        .full         (ibuf_full),
        .empty        (ibuf_empty)
    );
    `XM_UNUSED_VAR (ibuf_empty)

    assign out_req_vld  = out_req_vld_r;
    assign out_req_rw     = out_req_rw_r;
    assign out_req_mask   = out_req_mask_r;
    assign out_req_be = out_req_be_r;
    assign out_req_addr   = out_req_addr_r;
    if (FLAGS_WIDTH != 0) begin : g_out_req_flags
        assign out_req_flags = out_req_flags_r;
    end else begin : g_out_req_flags_0
        `XM_UNUSED_VAR (out_req_flags_r)
        assign out_req_flags = '0;
    end
    assign out_req_data   = out_req_data_r;
    assign out_req_tag    = out_req_tag_r;

    assign in_req_rdy = in_req_rdy_n;

    // unmerge responses

    reg [QUEUE_SIZE-1:0][OUT_REQS-1:0] resp_rem_mask;
    wire [OUT_REQS-1:0] resp_rem_mask_n = resp_rem_mask[ibuf_raddr] & ~out_resp_mask;
    assign out_resp_eop = ~(| resp_rem_mask_n);

    always @(posedge clk_i) begin
        if (ibuf_push) begin
            resp_rem_mask[ibuf_waddr] <= batch_vld_r;
        end
        if (out_resp_fire) begin
            resp_rem_mask[ibuf_raddr] <= resp_rem_mask_n;
        end
    end

    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] ibuf_dout_offset;
    wire [NUM_REQS-1:0] ibuf_dout_pmask;
    wire [TAG_ID_WIDTH-1:0] ibuf_dout_tag;

    assign {ibuf_dout_tag, ibuf_dout_pmask, ibuf_dout_offset} = ibuf_dout;

    wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_resp_data_n;
    for (genvar i = 0; i < OUT_REQS; ++i) begin : g_in_resp_data_n
        for (genvar j = 0; j < DATA_RATIO; ++j) begin : g_j
            assign in_resp_data_n[i * DATA_RATIO + j] = out_resp_data[i][ibuf_dout_offset[i * DATA_RATIO + j] * DATA_IN_WIDTH +: DATA_IN_WIDTH];
        end
    end

    wire [NUM_REQS-1:0] in_resp_mask_n;
    for (genvar i = 0; i < OUT_REQS; ++i) begin : g_in_resp_mask_n
        for (genvar j = 0; j < DATA_RATIO; ++j) begin : g_j
            assign in_resp_mask_n[i * DATA_RATIO + j] = out_resp_mask[i] && ibuf_dout_pmask[i * DATA_RATIO + j];
        end
    end

    assign in_resp_vld  = out_resp_vld;
    assign in_resp_mask   = in_resp_mask_n;
    assign in_resp_data   = in_resp_data_n;
    assign in_resp_tag    = {out_resp_tag[OUT_TAG_WIDTH-1 -: UUID_WIDTH], ibuf_dout_tag};
    assign out_resp_rdy = in_resp_rdy;

`ifdef DBG_TRACE_MEM
    wire [`XM_UP(UUID_WIDTH)-1:0] out_req_uuid;
    wire [`XM_UP(UUID_WIDTH)-1:0] out_resp_uuid;

    if (UUID_WIDTH != 0) begin : g_out_req_uuid
        assign out_req_uuid = out_req_tag[OUT_TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin : g_out_req_uuid_0
        assign out_req_uuid = '0;
    end

    if (UUID_WIDTH != 0) begin : g_out_resp_uuid
        assign out_resp_uuid = out_resp_tag[OUT_TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin : g_out_resp_uuid_0
        assign out_resp_uuid = '0;
    end

    reg [NUM_REQS-1:0][DATA_RATIO_W-1:0] out_req_offset;
    reg [NUM_REQS-1:0] out_req_pmask;

    always @(posedge clk_i) begin
        if (req_sent) begin
            out_req_offset <= ibuf_din_offset;
            out_req_pmask <= ibuf_din_pmask;
        end
    end

    always @(posedge clk_i) begin
        if (out_req_fire) begin
            if (out_req_rw) begin
                `TRACE(2, ("%t: %s out-req-wr: vld=%b, addr=", $time, INSTANCE_ID, out_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", out_req_addr, OUT_REQS)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", out_req_flags, OUT_REQS)
                `TRACE(2, (", be="))
                `TRACE_ARRAY1D(2, "0x%h", out_req_be, OUT_REQS)
                `TRACE(2, (", data="))
                `TRACE_ARRAY1D(2, "0x%0h", out_req_data, OUT_REQS)
            end else begin
                `TRACE(2,  ("%d: %s out-req-rd: vld=%b, addr=", $time, INSTANCE_ID, out_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", out_req_addr, OUT_REQS)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", out_req_flags, OUT_REQS)
            end
            `TRACE(2, (", offset="))
            `TRACE_ARRAY1D(2, "%0d", out_req_offset, NUM_REQS)
            `TRACE(2, (", pmask=%b, coalesced=%0d, tag=0x%0h (#%0d)\n", out_req_pmask, $countones(out_req_pmask), out_req_tag, out_req_uuid))
        end
        if (out_resp_fire) begin
            `TRACE(2, ("%t: %s out-resp: vld=%b, data=", $time, INSTANCE_ID, out_resp_mask))
            `TRACE_ARRAY1D(2, "0x%0h", out_resp_data, OUT_REQS)
            `TRACE(2, (", offset="))
            `TRACE_ARRAY1D(2, "%0d", ibuf_dout_offset, NUM_REQS)
            `TRACE(2, (", eop=%b, pmask=%b, tag=0x%0h (#%0d)\n", out_resp_eop, ibuf_dout_pmask, out_resp_tag, out_resp_uuid))
        end
    end
`endif

endmodule
`TRACING_ON
