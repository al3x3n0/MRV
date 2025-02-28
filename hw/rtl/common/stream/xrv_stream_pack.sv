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
module xrv_stream_pack #(
    parameter NUM_REQS_P      = 1,
    parameter DATA_WIDTH    = 1,
    parameter TAG_WIDTH     = 1,
    parameter TAG_SEL_BITS  = 0,
    parameter `STRING ARBITER = "P",
    parameter OUT_BUF       = 0
) (
    input wire                          clk_i,
    input wire                          rst_i,

    // input
    input wire [NUM_REQS_P-1:0]           vld_in,
    input wire [NUM_REQS_P-1:0][DATA_WIDTH-1:0] data_in,
    input wire [NUM_REQS_P-1:0][TAG_WIDTH-1:0] tag_in,
    output wire [NUM_REQS_P-1:0]          rdy_in,

    // output
    output wire                         vld_out,
    output wire [NUM_REQS_P-1:0]          mask_out,
    output wire [NUM_REQS_P-1:0][DATA_WIDTH-1:0] data_out,
    output wire [TAG_WIDTH-1:0]         tag_out,
    input wire                          rdy_out
);
    if (NUM_REQS_P > 1) begin : g_pack

        localparam LOG_NUM_REQS_P = `XM_CLOG2(NUM_REQS_P);

        wire [LOG_NUM_REQS_P-1:0] grant_index;
        wire grant_vld;
        wire grant_rdy;

        xrv_generic_arbiter #(
            .NUM_REQS_P (NUM_REQS_P),
            .TYPE     (ARBITER)
        ) arbiter (
            .clk_i         (clk_i),
            .rst_i       (rst_i),
            .requests    (vld_in),
            .grant_vld (grant_vld),
            .grant_index (grant_index),
            `XM_UNUSED_PIN  (grant_onehot),
            .grant_rdy (grant_rdy)
        );

        wire [TAG_WIDTH-1:0] tag_sel = tag_in[grant_index];

        wire [NUM_REQS_P-1:0] tag_matches;

        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_tag_matches
            assign tag_matches[i] = (tag_in[i][TAG_SEL_BITS-1:0] == tag_sel[TAG_SEL_BITS-1:0]);
        end

        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_rdy_in
            assign rdy_in[i] = grant_rdy & tag_matches[i];
        end

        wire [NUM_REQS_P-1:0] mask_sel = vld_in & tag_matches;

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (NUM_REQS_P + TAG_WIDTH + (NUM_REQS_P * DATA_WIDTH)),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
        ) out_buf (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .vld_i      (grant_vld),
            .data_i     ({mask_sel, tag_sel, data_in}),
            .rdy_i      (grant_rdy),
            .vld_o      (vld_out),
            .data_o     ({mask_out, tag_out, data_out}),
            .rdy_o      (rdy_out)
        );

    end else begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        assign vld_out = vld_in;
        assign mask_out  = 1'b1;
        assign data_out  = data_in;
        assign tag_out   = tag_in;
        assign rdy_in  = rdy_out;

    end

endmodule
`TRACING_ON
