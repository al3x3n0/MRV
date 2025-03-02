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
module xrv_mem_scheduler #(
    parameter `STRING INSTANCE_ID = "",
    parameter CORE_REQS     = 1,
    parameter MEM_CHANNELS  = 1,
    parameter WORD_SIZE     = 4,
    parameter LINE_SIZE     = WORD_SIZE,
    parameter ADDR_WIDTH    = 32 - `XM_CLOG2(WORD_SIZE),
    parameter FLAGS_WIDTH   = 0,
    parameter TAG_WIDTH     = 8,
    parameter UUID_WIDTH    = 0, // upper section of the request tag contains the UUID
    parameter CORE_QUEUE_SIZE= 8,
    parameter MEM_QUEUE_SIZE= CORE_QUEUE_SIZE,
    parameter RSP_PARTIAL   = 0,
    parameter CORE_OUT_BUF  = 0,
    parameter MEM_OUT_BUF   = 0,

    parameter WORD_WIDTH    = WORD_SIZE * 8,
    parameter LINE_WIDTH    = LINE_SIZE * 8,
    parameter COALESCE_ENABLE = (CORE_REQS > 1) && (LINE_SIZE != WORD_SIZE),
    parameter PER_LINE_REQS = LINE_SIZE / WORD_SIZE,
    parameter MERGED_REQS   = CORE_REQS / PER_LINE_REQS,
    parameter MEM_BATCHES   = `XM_CDIV(MERGED_REQS, MEM_CHANNELS),
    parameter MEM_BATCH_BITS= `XM_CLOG2(MEM_BATCHES),
    parameter MEM_QUEUE_ADDRW= `XM_CLOG2(COALESCE_ENABLE ? MEM_QUEUE_SIZE : CORE_QUEUE_SIZE),
    parameter MEM_ADDR_WIDTH= ADDR_WIDTH - `XM_CLOG2(PER_LINE_REQS),
    parameter MEM_TAG_WIDTH = UUID_WIDTH + MEM_QUEUE_ADDRW + MEM_BATCH_BITS
) (
    input wire clk_i,
    input wire rst_i,

    // Core request
    input wire                              core_req_vld,
    input wire                              core_req_rw,
    input wire [CORE_REQS-1:0]              core_req_mask,
    input wire [CORE_REQS-1:0][WORD_SIZE-1:0] core_req_be,
    input wire [CORE_REQS-1:0][ADDR_WIDTH-1:0] core_req_addr,
    input wire [CORE_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] core_req_flags,
    input wire [CORE_REQS-1:0][WORD_WIDTH-1:0] core_req_data,
    input wire [TAG_WIDTH-1:0]              core_req_tag,
    output wire                             core_req_rdy,
    output wire                             core_req_empty,
    output wire                             core_req_wr_notify,

    // Core response
    output wire                             core_resp_vld,
    output wire [CORE_REQS-1:0]             core_resp_mask,
    output wire [CORE_REQS-1:0][WORD_WIDTH-1:0] core_resp_data,
    output wire [TAG_WIDTH-1:0]             core_resp_tag,
    //output wire                             core_resp_sop,
    //output wire                             core_resp_eop,
    input wire                              core_resp_rdy,

    // Memory request
    output wire                             mem_req_vld,
    output wire                             mem_req_rw,
    output wire [MEM_CHANNELS-1:0]          mem_req_mask,
    output wire [MEM_CHANNELS-1:0][LINE_SIZE-1:0] mem_req_be,
    output wire [MEM_CHANNELS-1:0][MEM_ADDR_WIDTH-1:0] mem_req_addr,
    output wire [MEM_CHANNELS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] mem_req_flags,
    output wire [MEM_CHANNELS-1:0][LINE_WIDTH-1:0] mem_req_data,
    output wire [MEM_TAG_WIDTH-1:0]         mem_req_tag,
    input wire                              mem_req_rdy,

    // Memory response
    input wire                              mem_resp_vld,
    input wire [MEM_CHANNELS-1:0]           mem_resp_mask,
    input wire [MEM_CHANNELS-1:0][LINE_WIDTH-1:0] mem_resp_data,
    input wire [MEM_TAG_WIDTH-1:0]          mem_resp_tag,
    output wire                             mem_resp_rdy
);
    localparam BATCH_SEL_WIDTH = `XM_UP(MEM_BATCH_BITS);
    localparam STALL_TIMEOUT   = 10000000;
    localparam CORE_QUEUE_ADDRW= `XM_CLOG2(CORE_QUEUE_SIZE);
    localparam TAG_ID_WIDTH    = TAG_WIDTH - UUID_WIDTH;
    localparam REQQ_TAG_WIDTH  = UUID_WIDTH + CORE_QUEUE_ADDRW;
    localparam MERGED_TAG_WIDTH= UUID_WIDTH + MEM_QUEUE_ADDRW;
    localparam CORE_CHANNELS   = COALESCE_ENABLE ? CORE_REQS : MEM_CHANNELS;
    localparam CORE_BATCHES    = COALESCE_ENABLE ? 1 : MEM_BATCHES;
    localparam CORE_BATCH_BITS = `XM_CLOG2(CORE_BATCHES);

    `STATIC_ASSERT ((MEM_CHANNELS <= CORE_REQS), ("invld parameter"))
    `STATIC_ASSERT (`XM_IS_DIVISBLE(CORE_REQS * WORD_SIZE, LINE_SIZE), ("invld parameter"))
    `STATIC_ASSERT ((TAG_WIDTH >= UUID_WIDTH), ("invld parameter"))
    `RUNTIME_ASSERT((~core_req_vld || core_req_mask != 0), ("%t: invld request mask", $time))

    wire                            ibuf_push;
    wire                            ibuf_pop;
    wire [CORE_QUEUE_ADDRW-1:0]     ibuf_waddr;
    wire [CORE_QUEUE_ADDRW-1:0]     ibuf_raddr;
    wire                            ibuf_full;
    wire                            ibuf_empty;
    wire [TAG_ID_WIDTH-1:0]         ibuf_din;
    wire [TAG_ID_WIDTH-1:0]         ibuf_dout;

    wire                            reqq_vld;
    wire [CORE_REQS-1:0]            reqq_mask;
    wire                            reqq_rw;
    wire [CORE_REQS-1:0][WORD_SIZE-1:0] reqq_be;
    wire [CORE_REQS-1:0][ADDR_WIDTH-1:0] reqq_addr;
    wire [CORE_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] reqq_flags;
    wire [CORE_REQS-1:0][WORD_WIDTH-1:0] reqq_data;
    wire [REQQ_TAG_WIDTH-1:0]       reqq_tag;
    wire                            reqq_rdy;

    wire                            reqq_vld_s;
    wire [MERGED_REQS-1:0]          reqq_mask_s;
    wire                            reqq_rw_s;
    wire [MERGED_REQS-1:0][LINE_SIZE-1:0] reqq_be_s;
    wire [MERGED_REQS-1:0][MEM_ADDR_WIDTH-1:0] reqq_addr_s;
    wire [MERGED_REQS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] reqq_flags_s;
    wire [MERGED_REQS-1:0][LINE_WIDTH-1:0] reqq_data_s;
    wire [MERGED_TAG_WIDTH-1:0]     reqq_tag_s;
    wire                            reqq_rdy_s;

    wire                            mem_req_vld_s;
    wire [MEM_CHANNELS-1:0]         mem_req_mask_s;
    wire                            mem_req_rw_s;
    wire [MEM_CHANNELS-1:0][LINE_SIZE-1:0] mem_req_be_s;
    wire [MEM_CHANNELS-1:0][MEM_ADDR_WIDTH-1:0] mem_req_addr_s;
    wire [MEM_CHANNELS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] mem_req_flags_s;
    wire [MEM_CHANNELS-1:0][LINE_WIDTH-1:0] mem_req_data_s;
    wire [MEM_TAG_WIDTH-1:0]        mem_req_tag_s;
    wire                            mem_req_rdy_s;

    wire                            mem_resp_vld_s;
    wire [CORE_CHANNELS-1:0]        mem_resp_mask_s;
    wire [CORE_CHANNELS-1:0][WORD_WIDTH-1:0] mem_resp_data_s;
    wire [MEM_TAG_WIDTH-1:0]        mem_resp_tag_s;
    wire                            mem_resp_rdy_s;

    wire                            cresp_vld;
    wire [CORE_REQS-1:0]            cresp_mask;
    wire [CORE_REQS-1:0][WORD_WIDTH-1:0] cresp_data;
    wire [TAG_WIDTH-1:0]            cresp_tag;
    wire                            cresp_sop;
    wire                            cresp_eop;
    wire                            cresp_rdy;

    // Request queue //////////////////////////////////////////////////////////

    wire req_sent_all;

    wire ibuf_rdy = (core_req_rw || ~ibuf_full);
    wire reqq_vld_in = core_req_vld && ibuf_rdy;
    wire reqq_rdy_in;

    wire [REQQ_TAG_WIDTH-1:0] reqq_tag_u;
    if (UUID_WIDTH != 0) begin : g_reqq_tag_u_uuid
        assign reqq_tag_u = {core_req_tag[TAG_WIDTH-1 -: UUID_WIDTH], ibuf_waddr};
    end else begin : g_reqq_tag_u
        assign reqq_tag_u = ibuf_waddr;
    end

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (1 + CORE_REQS * (1 + WORD_SIZE + ADDR_WIDTH + `XM_UP(FLAGS_WIDTH) + WORD_WIDTH) + REQQ_TAG_WIDTH),
        .SIZE_P         (CORE_QUEUE_SIZE),
        .OUT_REG        (1)
    ) req_queue (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (reqq_vld_in),
        .rdy_i      (reqq_rdy_in),
        .data_i     ({core_req_rw, core_req_mask, core_req_be, core_req_addr, core_req_flags, core_req_data, reqq_tag_u}),
        .data_o     ({reqq_rw,     reqq_mask,     reqq_be,     reqq_addr,     reqq_flags,     reqq_data,     reqq_tag}),
        .vld_o      (reqq_vld),
        .rdy_o      (reqq_rdy)
    );

    // can accept another request?
    assign core_req_rdy = reqq_rdy_in && ibuf_rdy;

    // no pending requests
    assign core_req_empty = !reqq_vld && ibuf_empty;

    // notify write request submisison
    assign core_req_wr_notify = reqq_vld && reqq_rdy && reqq_rw;

    // Index buffer ///////////////////////////////////////////////////////////

    wire core_req_fire = core_req_vld && core_req_rdy;
    wire cresp_fire = cresp_vld && cresp_rdy;

    assign ibuf_push  = core_req_fire && ~core_req_rw;
    assign ibuf_pop   = cresp_fire && cresp_eop;
    assign ibuf_raddr = mem_resp_tag_s[CORE_BATCH_BITS +: CORE_QUEUE_ADDRW];
    assign ibuf_din   = core_req_tag[TAG_ID_WIDTH-1:0];

    xrv_index_buffer #(
        .DATA_WIDTH_P   (TAG_ID_WIDTH),
        .SIZE_P         (CORE_QUEUE_SIZE)
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

    // Handle memory coalescing ///////////////////////////////////////////////

    if (COALESCE_ENABLE) begin : g_coalescer

        VX_mem_coalescer #(
            .INSTANCE_ID    (`SFORMATF(("%s-coalescer", INSTANCE_ID))),
            .NUM_REQS       (CORE_REQS),
            .DATA_IN_SIZE   (WORD_SIZE),
            .DATA_OUT_SIZE  (LINE_SIZE),
            .ADDR_WIDTH     (ADDR_WIDTH),
            .FLAGS_WIDTH    (FLAGS_WIDTH),
            .TAG_WIDTH      (REQQ_TAG_WIDTH),
            .UUID_WIDTH     (UUID_WIDTH),
            .QUEUE_SIZE     (MEM_QUEUE_SIZE)
        ) coalescer (
            .clk_i            (clk_i),
            .rst_i          (rst_i),

            // Input request
            .in_req_vld   (reqq_vld),
            .in_req_mask    (reqq_mask),
            .in_req_rw      (reqq_rw),
            .in_req_be  (reqq_be),
            .in_req_addr    (reqq_addr),
            .in_req_flags   (reqq_flags),
            .in_req_data    (reqq_data),
            .in_req_tag     (reqq_tag),
            .in_req_rdy   (reqq_rdy),

            // Input response
            .in_resp_vld   (mem_resp_vld_s),
            .in_resp_mask    (mem_resp_mask_s),
            .in_resp_data    (mem_resp_data_s),
            .in_resp_tag     (mem_resp_tag_s),
            .in_resp_rdy   (mem_resp_rdy_s),

            // Output request
            .out_req_vld  (reqq_vld_s),
            .out_req_mask   (reqq_mask_s),
            .out_req_rw     (reqq_rw_s),
            .out_req_be (reqq_be_s),
            .out_req_addr   (reqq_addr_s),
            .out_req_flags  (reqq_flags_s),
            .out_req_data   (reqq_data_s),
            .out_req_tag    (reqq_tag_s),
            .out_req_rdy  (reqq_rdy_s),

            // Output response
            .out_resp_vld  (mem_resp_vld),
            .out_resp_mask   (mem_resp_mask),
            .out_resp_data   (mem_resp_data),
            .out_resp_tag    (mem_resp_tag),
            .out_resp_rdy  (mem_resp_rdy)
        );

    end else begin : g_no_coalescer
        assign reqq_vld_s = reqq_vld;
        assign reqq_mask_s  = reqq_mask;
        assign reqq_rw_s    = reqq_rw;
        assign reqq_be_s= reqq_be;
        assign reqq_addr_s  = reqq_addr;
        assign reqq_flags_s = reqq_flags;
        assign reqq_data_s  = reqq_data;
        assign reqq_tag_s   = reqq_tag;
        assign reqq_rdy   = reqq_rdy_s;

        assign mem_resp_vld_s = mem_resp_vld;
        assign mem_resp_mask_s  = mem_resp_mask;
        assign mem_resp_data_s  = mem_resp_data;
        assign mem_resp_tag_s   = mem_resp_tag;
        assign mem_resp_rdy   = mem_resp_rdy_s;

    end

    // Handle memory requests /////////////////////////////////////////////////

    wire [MEM_BATCHES-1:0][MEM_CHANNELS-1:0] mem_req_mask_b;
    wire [MEM_BATCHES-1:0][MEM_CHANNELS-1:0][LINE_SIZE-1:0] mem_req_be_b;
    wire [MEM_BATCHES-1:0][MEM_CHANNELS-1:0][MEM_ADDR_WIDTH-1:0] mem_req_addr_b;
    wire [MEM_BATCHES-1:0][MEM_CHANNELS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] mem_req_flags_b;
    wire [MEM_BATCHES-1:0][MEM_CHANNELS-1:0][LINE_WIDTH-1:0] mem_req_data_b;

    wire [BATCH_SEL_WIDTH-1:0] req_batch_idx;

    for (genvar i = 0; i < MEM_BATCHES; ++i) begin : g_mem_req_data_b
        for (genvar j = 0; j < MEM_CHANNELS; ++j) begin : g_j
            localparam r = i * MEM_CHANNELS + j;
            if (r < MERGED_REQS) begin : g_vld
                assign mem_req_mask_b[i][j]   = reqq_mask_s[r];
                assign mem_req_be_b[i][j] = reqq_be_s[r];
                assign mem_req_addr_b[i][j]   = reqq_addr_s[r];
                assign mem_req_flags_b[i][j]  = reqq_flags_s[r];
                assign mem_req_data_b[i][j]   = reqq_data_s[r];
            end else begin : g_padding
                assign mem_req_mask_b[i][j]   = 0;
                assign mem_req_be_b[i][j] = '0;
                assign mem_req_addr_b[i][j]   = '0;
                assign mem_req_flags_b[i][j]  = '0;
                assign mem_req_data_b[i][j]   = '0;
            end
        end
    end

    assign mem_req_mask_s   = mem_req_mask_b[req_batch_idx];
    assign mem_req_rw_s     = reqq_rw_s;
    assign mem_req_be_s = mem_req_be_b[req_batch_idx];
    assign mem_req_addr_s   = mem_req_addr_b[req_batch_idx];
    assign mem_req_flags_s  = mem_req_flags_b[req_batch_idx];
    assign mem_req_data_s   = mem_req_data_b[req_batch_idx];

    if (MEM_BATCHES != 1) begin : g_batch
        reg [MEM_BATCH_BITS-1:0] req_batch_idx_r;

        wire is_degenerate_batch = ~(| mem_req_mask_s);
        wire mem_req_vld_b = reqq_vld_s && ~is_degenerate_batch;
        wire mem_req_rdy_b = mem_req_rdy_s || is_degenerate_batch;

        always @(posedge clk_i) begin
            if (rst_i) begin
                req_batch_idx_r <= '0;
            end else begin
                if (reqq_vld_s && mem_req_rdy_b) begin
                    if (req_sent_all) begin
                        req_batch_idx_r <= '0;
                    end else begin
                        req_batch_idx_r <= req_batch_idx_r + MEM_BATCH_BITS'(1);
                    end
                end
            end
        end

        wire [MEM_BATCHES-1:0] req_batch_vlds;
        wire [MEM_BATCHES-1:0][MEM_BATCH_BITS-1:0] req_batch_idxs;
        wire [MEM_BATCH_BITS-1:0] req_batch_idx_last;

        for (genvar i = 0; i < MEM_BATCHES; ++i) begin : g_req_batch
            assign req_batch_vlds[i] = (| mem_req_mask_b[i]);
            assign req_batch_idxs[i] = MEM_BATCH_BITS'(i);
        end

        VX_find_first #(
            .N       (MEM_BATCHES),
            .DATAW   (MEM_BATCH_BITS),
            .REVERSE (1)
        ) find_last (
            .vld_in  (req_batch_vlds),
            .data_in   (req_batch_idxs),
            .data_out  (req_batch_idx_last),
            `XM_UNUSED_PIN (vld_out)
        );

        assign mem_req_vld_s = mem_req_vld_b;
        assign req_batch_idx = req_batch_idx_r;
        assign req_sent_all  = mem_req_rdy_b && (req_batch_idx_r == req_batch_idx_last);
        assign mem_req_tag_s = {reqq_tag_s, req_batch_idx};

    end else begin : g_no_batch

        assign mem_req_vld_s = reqq_vld_s;
        assign req_batch_idx = '0;
        assign req_sent_all  = mem_req_rdy_s;
        assign mem_req_tag_s = reqq_tag_s;

    end

    assign reqq_rdy_s = req_sent_all;

    wire [MEM_CHANNELS-1:0][`XM_UP(FLAGS_WIDTH)-1:0] mem_req_flags_u;

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (MEM_CHANNELS + 1 + MEM_CHANNELS * (LINE_SIZE + MEM_ADDR_WIDTH + `XM_UP(FLAGS_WIDTH) + LINE_WIDTH) + MEM_TAG_WIDTH),
        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(MEM_OUT_BUF)),
        .OUT_REG        (`XM_TO_OUT_BUF_REG(MEM_OUT_BUF))
    ) mem_req_buf (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .vld_i  (mem_req_vld_s),
        .rdy_i  (mem_req_rdy_s),
        .data_i ({mem_req_mask_s, mem_req_rw_s, mem_req_be_s, mem_req_addr_s, mem_req_flags_s, mem_req_data_s, mem_req_tag_s}),
        .data_o ({mem_req_mask,   mem_req_rw,   mem_req_be,   mem_req_addr,   mem_req_flags_u, mem_req_data,   mem_req_tag}),
        .vld_o  (mem_req_vld),
        .rdy_o  (mem_req_rdy)
    );

    if (FLAGS_WIDTH != 0) begin : g_mem_req_flags
        assign mem_req_flags = mem_req_flags_u;
    end else begin : g_mem_req_flags_0
        `XM_UNUSED_VAR (mem_req_flags_u)
        assign mem_req_flags = '0;
    end

    // Handle memory responses ////////////////////////////////////////////////

    wire [BATCH_SEL_WIDTH-1:0] resp_batch_idx;
    if (CORE_BATCHES > 1) begin : g_resp_batch_idx
        assign resp_batch_idx = mem_resp_tag_s[CORE_BATCH_BITS-1:0];
    end else begin : g_resp_batch_idx_0
        assign resp_batch_idx = '0;
    end

    if (CORE_REQS == 1) begin : g_resp_1
        `XM_UNUSED_VAR (resp_batch_idx)

        assign cresp_vld = mem_resp_vld_s;
        assign cresp_mask  = mem_resp_mask_s;
        assign cresp_sop   = 1'b1;
        assign cresp_eop   = 1'b1;
        assign cresp_data  = mem_resp_data_s;

        assign mem_resp_rdy_s = cresp_rdy;

    end else begin : g_resp_N

        reg [CORE_QUEUE_SIZE-1:0][CORE_REQS-1:0] resp_rem_mask;
        wire [CORE_REQS-1:0] resp_rem_mask_n, curr_mask;

        for (genvar r = 0; r < CORE_REQS; ++r) begin : g_curr_mask
            localparam i = r / CORE_CHANNELS;
            localparam j = r % CORE_CHANNELS;
            assign curr_mask[r] = (BATCH_SEL_WIDTH'(i) == resp_batch_idx) && mem_resp_mask_s[j];
        end

        assign resp_rem_mask_n = resp_rem_mask[ibuf_raddr] & ~curr_mask;

        wire mem_resp_fire_s = mem_resp_vld_s && mem_resp_rdy_s;

        always @(posedge clk_i) begin
            if (ibuf_push) begin
                resp_rem_mask[ibuf_waddr] <= core_req_mask;
            end
            if (mem_resp_fire_s) begin
                resp_rem_mask[ibuf_raddr] <= resp_rem_mask_n;
            end
        end

        wire resp_complete = ~(| resp_rem_mask_n) || (CORE_REQS == 1);

        if (RSP_PARTIAL != 0) begin : g_resp_partial

            reg [CORE_QUEUE_SIZE-1:0] resp_sop_r;

            always @(posedge clk_i) begin
                if (ibuf_push) begin
                    resp_sop_r[ibuf_waddr] <= 1;
                end
                if (mem_resp_fire_s) begin
                    resp_sop_r[ibuf_raddr] <= 0;
                end
            end

            assign cresp_vld = mem_resp_vld_s;
            assign cresp_mask  = curr_mask;
            assign cresp_sop   = resp_sop_r[ibuf_raddr];

            for (genvar r = 0; r < CORE_REQS; ++r) begin : g_cresp_data
                localparam j = r % CORE_CHANNELS;
                assign cresp_data[r] = mem_resp_data_s[j];
            end

            assign mem_resp_rdy_s = cresp_rdy;

        end else begin : g_resp_full

            wire [CORE_CHANNELS-1:0][CORE_BATCHES-1:0][WORD_WIDTH-1:0] resp_store_n;
            reg [CORE_REQS-1:0] resp_orig_mask [CORE_QUEUE_SIZE-1:0];

            for (genvar i = 0; i < CORE_CHANNELS; ++i) begin : g_resp_store
                for (genvar j = 0; j < CORE_BATCHES; ++j) begin : g_j
                    reg [WORD_WIDTH-1:0] resp_store [0:CORE_QUEUE_SIZE-1];
                    wire resp_wren = mem_resp_fire_s
                                && (BATCH_SEL_WIDTH'(j) == resp_batch_idx)
                                && ((CORE_CHANNELS == 1) || mem_resp_mask_s[i]);
                    always @(posedge clk_i) begin
                        if (resp_wren) begin
                            resp_store[ibuf_raddr] <= mem_resp_data_s[i];
                        end
                    end
                    assign resp_store_n[i][j] = resp_wren ? mem_resp_data_s[i] : resp_store[ibuf_raddr];
                end
            end

            always @(posedge clk_i) begin
                if (ibuf_push) begin
                    resp_orig_mask[ibuf_waddr] <= core_req_mask;
                end
            end

            assign cresp_vld = mem_resp_vld_s && resp_complete;
            assign cresp_mask  = resp_orig_mask[ibuf_raddr];
            assign cresp_sop   = 1'b1;

            for (genvar r = 0; r < CORE_REQS; ++r) begin : g_cresp_data
                localparam i = r / CORE_CHANNELS;
                localparam j = r % CORE_CHANNELS;
                assign cresp_data[r] = resp_store_n[j][i];
            end

            assign mem_resp_rdy_s = cresp_rdy || ~resp_complete;
        end

        assign cresp_eop = resp_complete;
    end

    if (UUID_WIDTH != 0) begin : g_cresp_tag
        assign cresp_tag = {mem_resp_tag_s[MEM_TAG_WIDTH-1 -: UUID_WIDTH], ibuf_dout};
    end else begin : g_cresp_tag_0
        assign cresp_tag = ibuf_dout;
    end

    // Send response to caller
    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (CORE_REQS /*+ 1 + 1*/ + (CORE_REQS * WORD_WIDTH) + TAG_WIDTH),
        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(CORE_OUT_BUF)),
        .OUT_REG        (`XM_TO_OUT_BUF_REG(CORE_OUT_BUF))
    ) resp_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (cresp_vld),
        .rdy_i      (cresp_rdy),
        .data_i     ({cresp_mask,     /*cresp_sop,     cresp_eop,*/     cresp_data,     cresp_tag}),
        .data_o     ({core_resp_mask, /*core_resp_sop, core_resp_eop,*/ core_resp_data, core_resp_tag}),
        .vld_o      (core_resp_vld),
        .rdy_o      (core_resp_rdy)
    );

`ifdef SIMULATION
    wire [`XM_UP(UUID_WIDTH)-1:0] req_dbg_uuid;

    if (UUID_WIDTH != 0) begin : g_req_dbg_uuid
        assign req_dbg_uuid = core_req_tag[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin : g_req_dbg_uuid_0
        assign req_dbg_uuid = '0;
    end

    reg [(`XM_UP(UUID_WIDTH) + TAG_ID_WIDTH + 64)-1:0] pending_reqs_time [CORE_QUEUE_SIZE-1:0];
    reg [CORE_QUEUE_SIZE-1:0] pending_reqs_vld;

    always @(posedge clk_i) begin
        if (rst_i) begin
            pending_reqs_vld <= '0;
        end else begin
            if (ibuf_push) begin
                pending_reqs_vld[ibuf_waddr] <= 1'b1;
            end
            if (ibuf_pop) begin
                pending_reqs_vld[ibuf_raddr] <= 1'b0;
            end
        end

        if (ibuf_push) begin
            pending_reqs_time[ibuf_waddr] <= {req_dbg_uuid, ibuf_din, $time};
        end

        for (integer i = 0; i < CORE_QUEUE_SIZE; ++i) begin
            if (pending_reqs_vld[i]) begin
                `ASSERT(($time - pending_reqs_time[i][63:0]) < STALL_TIMEOUT,
                    ("%t: *** %s response timeout: tag=0x%0h (#%0d)",
                        $time, INSTANCE_ID, pending_reqs_time[i][64 +: TAG_ID_WIDTH], pending_reqs_time[i][64+TAG_ID_WIDTH +: `XM_UP(UUID_WIDTH)]));
            end
        end
    end
`endif

    ///////////////////////////////////////////////////////////////////////////

`ifdef DBG_TRACE_MEM
    wire [`XM_UP(UUID_WIDTH)-1:0] mem_req_dbg_uuid;
    wire [`XM_UP(UUID_WIDTH)-1:0] mem_resp_dbg_uuid;
    wire [`XM_UP(UUID_WIDTH)-1:0] resp_dbg_uuid;

    if (UUID_WIDTH != 0) begin : g_dbg_uuid
        assign mem_req_dbg_uuid = mem_req_tag_s[MEM_TAG_WIDTH-1 -: UUID_WIDTH];
        assign mem_resp_dbg_uuid = mem_resp_tag_s[MEM_TAG_WIDTH-1 -: UUID_WIDTH];
        assign resp_dbg_uuid     = core_resp_tag[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin : g_dbg_uuid_0
        assign mem_req_dbg_uuid = '0;
        assign mem_resp_dbg_uuid = '0;
        assign resp_dbg_uuid     = '0;
    end

    wire [CORE_QUEUE_ADDRW-1:0] ibuf_waddr_s = mem_req_tag_s[MEM_BATCH_BITS +: CORE_QUEUE_ADDRW];

    wire mem_req_fire_s = mem_req_vld_s && mem_req_rdy_s;

    always @(posedge clk_i) begin
        if (core_req_fire) begin
            if (core_req_rw) begin
                `TRACE(2, ("%t: %s core-req-wr: vld=%b, addr=", $time, INSTANCE_ID, core_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", core_req_addr, CORE_REQS)
                `TRACE(2, (", be="))
                `TRACE_ARRAY1D(2, "0x%h", core_req_be, CORE_REQS)
                `TRACE(2, (", data="))
                `TRACE_ARRAY1D(2, "0x%0h", core_req_data, CORE_REQS)
            end else begin
                `TRACE(2, ("%t: %s core-req-rd: vld=%b, addr=", $time, INSTANCE_ID, core_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", core_req_addr, CORE_REQS)
            end
            `TRACE(2, (", tag=0x%0h (#%0d)\n", core_req_tag, req_dbg_uuid))
        end
        if (core_resp_vld && core_resp_rdy) begin
            `TRACE(2, ("%t: %s core-resp: vld=%b, sop=%b, eop=%b, data=", $time, INSTANCE_ID, core_resp_mask, core_resp_sop, core_resp_eop))
            `TRACE_ARRAY1D(2, "0x%0h", core_resp_data, CORE_REQS)
            `TRACE(2, (", tag=0x%0h (#%0d)\n", core_resp_tag, resp_dbg_uuid))
        end
        if (| mem_req_fire_s) begin
            if (| mem_req_rw_s) begin
                `TRACE(2, ("%t: %s mem-req-wr: vld=%b, addr=", $time, INSTANCE_ID, mem_req_mask_s))
                `TRACE_ARRAY1D(2, "0x%h", mem_req_addr_s, CORE_CHANNELS)
                `TRACE(2, (", be="))
                `TRACE_ARRAY1D(2, "0x%h", mem_req_be_s, CORE_CHANNELS)
                `TRACE(2, (", data="))
                `TRACE_ARRAY1D(2, "0x%0h", mem_req_data_s, CORE_CHANNELS)
            end else begin
                `TRACE(2, ("%t: %s mem-req-rd: vld=%b, addr=", $time, INSTANCE_ID, mem_req_mask_s))
                `TRACE_ARRAY1D(2, "0x%h", mem_req_addr_s, CORE_CHANNELS)
            end
            `TRACE(2, (", ibuf_idx=%0d, batch_idx=%0d (#%0d)\n", ibuf_waddr_s, req_batch_idx, mem_req_dbg_uuid))
        end
        if (mem_resp_vld_s && mem_resp_rdy_s) begin
            `TRACE(2, ("%t: %s mem-resp: vld=%b, data=", $time, INSTANCE_ID, mem_resp_mask_s))
            `TRACE_ARRAY1D(2, "0x%0h", mem_resp_data_s, CORE_CHANNELS)
            `TRACE(2, (", ibuf_idx=%0d, batch_idx=%0d (#%0d)\n", ibuf_raddr, resp_batch_idx, mem_resp_dbg_uuid))
        end
    end
`endif

endmodule
`TRACING_ON
