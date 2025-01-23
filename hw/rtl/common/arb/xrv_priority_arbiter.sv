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
module xrv_priority_arbiter #(
    parameter NUM_REQS_P     = 1,
    parameter LOG_NUM_REQS_P = `XM_LOG2UP(NUM_REQS_P)
) (
    input  wire [NUM_REQS_P-1:0]      requests,
    output wire [LOG_NUM_REQS_P-1:0]  grant_index,
    output wire [NUM_REQS_P-1:0]      grant_onehot,
    output wire                     grant_vld
);
    if (NUM_REQS_P == 1) begin : g_passthru

        assign grant_index  = '0;
        assign grant_onehot = requests;
        assign grant_vld  = requests[0];

    end else begin : g_encoder

        xrv_priority_encoder #(
            .N (NUM_REQS_P)
        ) priority_encoder (
            .data_i     (requests),
            .index_o    (grant_index),
            .onehot_o   (grant_onehot),
            .vld_o      (grant_vld)
        );

    end

endmodule
`TRACING_ON
