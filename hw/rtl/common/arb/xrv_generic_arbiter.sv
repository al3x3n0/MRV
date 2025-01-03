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
module xrv_generic_arbiter #(
    parameter NUM_REQS_P     = 1,
    parameter `STRING TYPE = "P", // P: priority, R: round-robin, M: matrix, C: cyclic
    parameter LOG_NUM_REQS_P = `XM_LOG2UP(NUM_REQS_P)
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic [NUM_REQS_P-1:0]       requests,
    output logic [LOG_NUM_REQS_P-1:0]   grant_index,
    output logic [NUM_REQS_P-1:0]       grant_onehot,
    output logic                        grant_vld,
    input  logic                        grant_rdy
);
    `STATIC_ASSERT((TYPE == "P" || TYPE == "R" || TYPE == "M" || TYPE == "C"), ("invld parameter"))

    if (TYPE == "P") begin : g_priority

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        `XM_UNUSED_VAR (grant_rdy)

        xrv_priority_arbiter #(
            .NUM_REQS_P (NUM_REQS_P)
        ) priority_arbiter (
            .requests     (requests),
            .grant_vld  (grant_vld),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot)
        );

    end else if (TYPE == "R") begin : g_round_robin

        xrv_rr_arbiter #(
            .NUM_REQS       (NUM_REQS_P)
        ) rr_arbiter (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .requests       (requests),
            .grant_vld      (grant_vld),
            .grant_index    (grant_index),
            .grant_onehot   (grant_onehot),
            .grant_rdy      (grant_rdy)
        );

    end else if (TYPE == "M") begin : g_matrix

        xrv_matrix_arbiter #(
            .NUM_REQS_P (NUM_REQS_P)
        ) matrix_arbiter (
            .clk_i          (clk_i),
            .rst_i        (rst_i),
            .requests     (requests),
            .grant_vld  (grant_vld),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_rdy  (grant_rdy)
        );

    end else if (TYPE == "C") begin : g_cyclic

        xrv_cyclic_arbiter #(
            .NUM_REQS_P (NUM_REQS_P)
        ) cyclic_arbiter (
            .clk_i          (clk_i),
            .rst_i        (rst_i),
            .requests     (requests),
            .grant_vld  (grant_vld),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_rdy  (grant_rdy)
        );

    end

    `RUNTIME_ASSERT (((~(| requests) != 1) || (grant_vld && (requests[grant_index] != 0) && (grant_onehot == (NUM_REQS_P'(1) << grant_index)))), ("%t: invld arbiter grant!", $time))

endmodule
`TRACING_ON
