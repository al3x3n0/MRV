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
module xrv_stream_unpack #(
    parameter NUM_REQS_P      = 1,
    parameter DATA_WIDTH    = 1,
    parameter TAG_WIDTH     = 1,
    parameter OUT_BUF       = 0
) (
    input wire                          clk_i,
    input wire                          rst_i,

    // input
    input wire                          vld_in,
    input wire [NUM_REQS_P-1:0]           mask_in,
    input wire [NUM_REQS_P-1:0][DATA_WIDTH-1:0] data_in,
    input wire [TAG_WIDTH-1:0]          tag_in,
    output wire                         rdy_in,

    // output
    output wire [NUM_REQS_P-1:0]          vld_out,
    output wire [NUM_REQS_P-1:0][DATA_WIDTH-1:0] data_out,
    output wire [NUM_REQS_P-1:0][TAG_WIDTH-1:0] tag_out,
    input wire  [NUM_REQS_P-1:0]          rdy_out
);
    if (NUM_REQS_P > 1) begin : g_unpack

        reg [NUM_REQS_P-1:0] rem_mask_r;
        wire [NUM_REQS_P-1:0] rdy_out_w;

        wire [NUM_REQS_P-1:0] rem_mask_n = rem_mask_r & ~rdy_out_w;
        wire sent_all = ~(| (mask_in & rem_mask_n));

        always @(posedge clk_i) begin
            if (rst_i) begin
                rem_mask_r <= '1;
            end else begin
                if (vld_in) begin
                    rem_mask_r <= sent_all ? '1 : rem_mask_n;
                end
            end
        end

        assign rdy_in = sent_all;

        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_outbuf
            xrv_elastic_buffer #(
                .DATA_WIDTH_P   (DATA_WIDTH + TAG_WIDTH),
                .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
            ) out_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_in && mask_in[i] && rem_mask_r[i]),
                .rdy_i          (rdy_out_w[i]),
                .data_i         ({data_in[i],  tag_in}),
                .data_o         ({data_out[i], tag_out[i]}),
                .vld_o          (vld_out[i]),
                .rdy_o          (rdy_out[i])
            );
        end

    end else begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        `XM_UNUSED_VAR (mask_in)
        assign vld_out = vld_in;
        assign data_out  = data_in;
        assign tag_out   = tag_in;
        assign rdy_in  = rdy_out;

    end

endmodule
`TRACING_ON
