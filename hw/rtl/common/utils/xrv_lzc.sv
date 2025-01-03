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
module xrv_lzc #(
    parameter N         = 2,
    parameter REVERSE_P = 0,  // 0 -> leading zero, 1 -> trailing zero,
    parameter LOGN      = `XM_LOG2UP(N)
) (
    input  logic [N-1:0]    data_i,
    output logic [LOGN-1:0] data_o,
    output logic            vld_o
);
    if (N == 1) begin : g_passthru

        `XM_UNUSED_PARAM (REVERSE_P)

        assign data_o  = '0;
        assign vld_o = data_i;

    end else begin : g_lzc

        logic [N-1:0][LOGN-1:0] indices;

        for (genvar i = 0; i < N; ++i) begin : g_indices
            assign indices[i] = REVERSE_P ? LOGN'(i) : LOGN'(N-1-i);
        end

        xrv_find_first #(
            .N                  (N),
            .DATA_WIDTH_P       (LOGN),
            .REVERSE_P          (!REVERSE_P)
        ) find_first (
            .data_i             (indices),
            .vld_i              (data_i),
            .data_o             (data_o),
            .vld_o              (vld_o)
        );

    end

endmodule
`TRACING_ON
