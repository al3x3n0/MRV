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
module xrv_mem_data_adapter #(
    parameter SRC_DATA_WIDTH = 1,
    parameter SRC_ADDR_WIDTH = 1,
    parameter DST_DATA_WIDTH = 1,
    parameter DST_ADDR_WIDTH = 1,
    parameter SRC_TAG_WIDTH  = 1,
    parameter DST_TAG_WIDTH  = 1,
    parameter REQ_OUT_BUF    = 0,
    parameter RSP_OUT_BUF    = 0
) (
    input wire                          clk_i,
    input wire                          rst_i,

    input wire                          mem_req_vld_in,
    input wire [SRC_ADDR_WIDTH-1:0]     mem_req_addr_in,
    input wire                          mem_req_rw_in,
    input wire [SRC_DATA_WIDTH/8-1:0]   mem_req_be_in,
    input wire [SRC_DATA_WIDTH-1:0]     mem_req_data_in,
    input wire [SRC_TAG_WIDTH-1:0]      mem_req_tag_in,
    output wire                         mem_req_rdy_in,

    output wire                         mem_resp_vld_in,
    output wire [SRC_DATA_WIDTH-1:0]    mem_resp_data_in,
    output wire [SRC_TAG_WIDTH-1:0]     mem_resp_tag_in,
    input wire                          mem_resp_rdy_in,

    output wire                         mem_req_vld_out,
    output wire [DST_ADDR_WIDTH-1:0]    mem_req_addr_out,
    output wire                         mem_req_rw_out,
    output wire [DST_DATA_WIDTH/8-1:0]  mem_req_be_out,
    output wire [DST_DATA_WIDTH-1:0]    mem_req_data_out,
    output wire [DST_TAG_WIDTH-1:0]     mem_req_tag_out,
    input wire                          mem_req_rdy_out,

    input wire                          mem_resp_vld_out,
    input wire [DST_DATA_WIDTH-1:0]     mem_resp_data_out,
    input wire [DST_TAG_WIDTH-1:0]      mem_resp_tag_out,
    output wire                         mem_resp_rdy_out
);
    localparam DST_DATA_SIZE = (DST_DATA_WIDTH / 8);
    localparam DST_LDATAW = `XM_CLOG2(DST_DATA_WIDTH);
    localparam SRC_LDATAW = `XM_CLOG2(SRC_DATA_WIDTH);
    localparam D = `XM_ABS(DST_LDATAW - SRC_LDATAW);
    localparam P = 2**D;

    localparam EXPECTED_TAG_WIDTH = SRC_TAG_WIDTH + ((DST_LDATAW > SRC_LDATAW) ? D : 0);

    `STATIC_ASSERT(DST_TAG_WIDTH >= EXPECTED_TAG_WIDTH, ("invld DST_TAG_WIDTH parameter, current=%0d, expected=%0d", DST_TAG_WIDTH, EXPECTED_TAG_WIDTH))

    wire                         mem_req_vld_out_w;
    wire [DST_ADDR_WIDTH-1:0]    mem_req_addr_out_w;
    wire                         mem_req_rw_out_w;
    wire [DST_DATA_WIDTH/8-1:0]  mem_req_be_out_w;
    wire [DST_DATA_WIDTH-1:0]    mem_req_data_out_w;
    wire [DST_TAG_WIDTH-1:0]     mem_req_tag_out_w;
    wire                         mem_req_rdy_out_w;

    wire                         mem_resp_vld_in_w;
    wire [SRC_DATA_WIDTH-1:0]    mem_resp_data_in_w;
    wire [SRC_TAG_WIDTH-1:0]     mem_resp_tag_in_w;
    wire                         mem_resp_rdy_in_w;

    `XM_UNUSED_VAR (mem_req_tag_in)
    `XM_UNUSED_VAR (mem_resp_tag_out)

    if (DST_LDATAW > SRC_LDATAW) begin : g_wider_dst_data

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)

        wire [D-1:0] req_idx = mem_req_addr_in[D-1:0];
        wire [D-1:0] resp_idx = mem_resp_tag_out[D-1:0];

        wire [SRC_ADDR_WIDTH-D-1:0] mem_req_addr_in_qual = mem_req_addr_in[SRC_ADDR_WIDTH-1:D];

        wire [P-1:0][SRC_DATA_WIDTH-1:0] mem_resp_data_out_w = mem_resp_data_out;

        if (DST_ADDR_WIDTH < (SRC_ADDR_WIDTH - D)) begin : g_mem_req_addr_out_w_src
            `XM_UNUSED_VAR (mem_req_addr_in_qual)
            assign mem_req_addr_out_w = mem_req_addr_in_qual[DST_ADDR_WIDTH-1:0];
        end else if (DST_ADDR_WIDTH > (SRC_ADDR_WIDTH - D)) begin : g_mem_req_addr_out_w_dst
            assign mem_req_addr_out_w = DST_ADDR_WIDTH'(mem_req_addr_in_qual);
        end else begin : g_mem_req_addr_out_w
            assign mem_req_addr_out_w = mem_req_addr_in_qual;
        end

        xrv_demux #(
            .DATA_WIDTH_P   (SRC_DATA_WIDTH/8),
            .N (P)
        ) req_be_demux (
            .sel_i          (req_idx),
            .data_i         (mem_req_be_in),
            .data_o         (mem_req_be_out_w)
        );

        xrv_demux #(
            .DATA_WIDTH_P   (SRC_DATA_WIDTH),
            .N (P)
        ) req_data_demux (
            .sel_i          (req_idx),
            .data_i         (mem_req_data_in),
            .data_o         (mem_req_data_out_w)
        );

        assign mem_req_vld_out_w  = mem_req_vld_in;
        assign mem_req_rw_out_w     = mem_req_rw_in;
        assign mem_req_tag_out_w    = DST_TAG_WIDTH'({mem_req_tag_in, req_idx});
        assign mem_req_rdy_in     = mem_req_rdy_out_w;

        assign mem_resp_vld_in_w   = mem_resp_vld_out;
        assign mem_resp_data_in_w    = mem_resp_data_out_w[resp_idx];
        assign mem_resp_tag_in_w     = SRC_TAG_WIDTH'(mem_resp_tag_out[DST_TAG_WIDTH-1:D]);
        assign mem_resp_rdy_out    = mem_resp_rdy_in_w;

    end else if (DST_LDATAW < SRC_LDATAW) begin : g_wider_src_data

        reg [D-1:0] req_ctr, resp_ctr;

        reg [P-1:0][DST_DATA_WIDTH-1:0] mem_resp_data_out_r, mem_resp_data_out_n;

        wire mem_req_out_fire = mem_req_vld_out && mem_req_rdy_out;
        wire mem_resp_in_fire = mem_resp_vld_out && mem_resp_rdy_out;

        wire [P-1:0][DST_DATA_WIDTH-1:0] mem_req_data_in_w = mem_req_data_in;
        wire [P-1:0][DST_DATA_SIZE-1:0] mem_req_be_in_w = mem_req_be_in;

        always @(*) begin
            mem_resp_data_out_n = mem_resp_data_out_r;
            if (mem_resp_in_fire) begin
                mem_resp_data_out_n[resp_ctr] = mem_resp_data_out;
            end
        end

        always @(posedge clk_i) begin
            if (rst_i) begin
                req_ctr <= '0;
                resp_ctr <= '0;
            end else begin
                if (mem_req_out_fire) begin
                    req_ctr <= req_ctr + 1;
                end
                if (mem_resp_in_fire) begin
                    resp_ctr <= resp_ctr + 1;
                end
            end
            mem_resp_data_out_r <= mem_resp_data_out_n;
        end

        reg [DST_TAG_WIDTH-1:0] mem_resp_tag_in_r;
        wire [DST_TAG_WIDTH-1:0] mem_resp_tag_in_x;

        always @(posedge clk_i) begin
            if (mem_resp_in_fire) begin
                mem_resp_tag_in_r <= mem_resp_tag_out;
            end
        end
        assign mem_resp_tag_in_x = (resp_ctr != 0) ? mem_resp_tag_in_r : mem_resp_tag_out;
        `RUNTIME_ASSERT(!mem_resp_in_fire || (mem_resp_tag_in_x == mem_resp_tag_out),
            ("%t: *** out-of-order memory reponse! cur=0x%0h, expected=0x%0h", $time, mem_resp_tag_in_x, mem_resp_tag_out))

        wire [SRC_ADDR_WIDTH+D-1:0] mem_req_addr_in_qual = {mem_req_addr_in, req_ctr};

        if (DST_ADDR_WIDTH < (SRC_ADDR_WIDTH + D)) begin : g_mem_req_addr_out_w_src
            `XM_UNUSED_VAR (mem_req_addr_in_qual)
            assign mem_req_addr_out_w = mem_req_addr_in_qual[DST_ADDR_WIDTH-1:0];
        end else if (DST_ADDR_WIDTH > (SRC_ADDR_WIDTH + D)) begin : g_mem_req_addr_out_w_dst
            assign mem_req_addr_out_w = DST_ADDR_WIDTH'(mem_req_addr_in_qual);
        end else begin : g_mem_req_addr_out_w
            assign mem_req_addr_out_w = mem_req_addr_in_qual;
        end

        assign mem_req_vld_out_w  = mem_req_vld_in;
        assign mem_req_rw_out_w     = mem_req_rw_in;
        assign mem_req_be_out_w = mem_req_be_in_w[req_ctr];
        assign mem_req_data_out_w   = mem_req_data_in_w[req_ctr];
        assign mem_req_tag_out_w    = DST_TAG_WIDTH'(mem_req_tag_in);
        assign mem_req_rdy_in     = mem_req_rdy_out_w && (req_ctr == (P-1));

        assign mem_resp_vld_in_w   = mem_resp_vld_out && (resp_ctr == (P-1));
        assign mem_resp_data_in_w    = mem_resp_data_out_n;
        assign mem_resp_tag_in_w     = SRC_TAG_WIDTH'(mem_resp_tag_out);
        assign mem_resp_rdy_out    = mem_resp_rdy_in_w;

    end else begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)

        if (DST_ADDR_WIDTH < SRC_ADDR_WIDTH) begin : g_mem_req_addr_out_w_src
            `XM_UNUSED_VAR (mem_req_addr_in)
            assign mem_req_addr_out_w = mem_req_addr_in[DST_ADDR_WIDTH-1:0];
        end else if (DST_ADDR_WIDTH > SRC_ADDR_WIDTH) begin : g_mem_req_addr_out_w_dst
            assign mem_req_addr_out_w = DST_ADDR_WIDTH'(mem_req_addr_in);
        end else begin : g_mem_req_addr_out_w
            assign mem_req_addr_out_w = mem_req_addr_in;
        end

        assign mem_req_vld_out_w  = mem_req_vld_in;
        assign mem_req_rw_out_w     = mem_req_rw_in;
        assign mem_req_be_out_w = mem_req_be_in;
        assign mem_req_data_out_w   = mem_req_data_in;
        assign mem_req_tag_out_w    = DST_TAG_WIDTH'(mem_req_tag_in);
        assign mem_req_rdy_in     = mem_req_rdy_out_w;

        assign mem_resp_vld_in_w   = mem_resp_vld_out;
        assign mem_resp_data_in_w    = mem_resp_data_out;
        assign mem_resp_tag_in_w     = SRC_TAG_WIDTH'(mem_resp_tag_out);
        assign mem_resp_rdy_out    = mem_resp_rdy_in_w;

    end

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (1 + DST_DATA_SIZE + DST_ADDR_WIDTH + DST_DATA_WIDTH + DST_TAG_WIDTH),
        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(REQ_OUT_BUF)),
        .OUT_REG        (`XM_TO_OUT_BUF_REG(REQ_OUT_BUF))
    ) req_out_buf (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .vld_i          (mem_req_vld_out_w),
        .rdy_i          (mem_req_rdy_out_w),
        .data_i         ({mem_req_rw_out_w, mem_req_be_out_w, mem_req_addr_out_w, mem_req_data_out_w, mem_req_tag_out_w}),
        .data_o         ({mem_req_rw_out,   mem_req_be_out,   mem_req_addr_out,   mem_req_data_out,   mem_req_tag_out}),
        .vld_o          (mem_req_vld_out),
        .rdy_o          (mem_req_rdy_out)
    );

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (SRC_DATA_WIDTH + SRC_TAG_WIDTH),
        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(RSP_OUT_BUF)),
        .OUT_REG        (`XM_TO_OUT_BUF_REG(RSP_OUT_BUF))
    ) resp_in_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (mem_resp_vld_in_w),
        .rdy_i      (mem_resp_rdy_in_w),
        .data_i     ({mem_resp_data_in_w, mem_resp_tag_in_w}),
        .data_o     ({mem_resp_data_in,   mem_resp_tag_in}),
        .vld_o      (mem_resp_vld_in),
        .rdy_o      (mem_resp_rdy_in)
    );

endmodule
`TRACING_ON
