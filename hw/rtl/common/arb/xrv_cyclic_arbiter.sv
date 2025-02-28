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
module xrv_cyclic_arbiter #(
    parameter NUM_REQS_P     = 1,
    parameter LOG_NUM_REQS_P = `XM_LOG2UP(NUM_REQS_P)
) (
    input  wire                     clk_i,
    input  wire                     rst_i,
    input  wire [NUM_REQS_P-1:0]      requests,
    output wire [LOG_NUM_REQS_P-1:0]  grant_index,
    output wire [NUM_REQS_P-1:0]      grant_onehot,
    output wire                     grant_vld,
    input  wire                     grant_rdy
);
    if (NUM_REQS_P == 1) begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        `XM_UNUSED_VAR (grant_rdy)

        assign grant_index  = '0;
        assign grant_onehot = requests;
        assign grant_vld  = requests[0];

    end else begin : g_arbiter

        localparam IS_POW2 = (1 << LOG_NUM_REQS_P) == NUM_REQS_P;

        wire [LOG_NUM_REQS_P-1:0] grant_index_um;
        wire [NUM_REQS_P-1:0] grant_onehot_w, grant_onehot_um;
        reg [LOG_NUM_REQS_P-1:0] grant_index_r;

        always @(posedge clk_i) begin
            if (rst_i) begin
                grant_index_r <= '0;
            end else if (grant_vld && grant_rdy) begin
                if (!IS_POW2 && grant_index == LOG_NUM_REQS_P'(NUM_REQS_P-1)) begin
                    grant_index_r <= '0;
                end else begin
                    grant_index_r <= grant_index + LOG_NUM_REQS_P'(1);
                end
            end
        end

        xrv_priority_encoder #(
            .N (NUM_REQS_P)
        ) priority_encoder (
            .data_i     (requests),
            .onehot_o   (grant_onehot_um),
            .index_o    (grant_index_um),
            .vld_o      (grant_vld)
        );

        xrv_demux #(
            .DATA_WIDTH_P   (1),
            .N              (NUM_REQS_P)
        ) grant_decoder (
            .sel_i      (grant_index),
            .data_i     (1'b1),
            .data_o     (grant_onehot_w)
        );

        wire is_hit = requests[grant_index_r];

        assign grant_index  = is_hit ? grant_index_r : grant_index_um;
        assign grant_onehot = is_hit ? grant_onehot_w : grant_onehot_um;

    end

endmodule
`TRACING_ON
