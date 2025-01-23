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
module xrv_bits_remove #(
    parameter N   = 2,
    parameter S   = 1,
    parameter POS = 0
) (
    input wire [N-1:0]          data_i,
    output wire [`XM_UP(S)-1:0] sel_o,
    output wire [N-S-1:0]       data_o
);
    `STATIC_ASSERT (((0 == S) || ((POS + S) <= N)), ("invalid parameter"))

    if (S == 0) begin : g_passthru
        assign sel_o = 0;
        assign data_o = data_i;
    end else if (POS == 0) begin : g_pos_0
        assign sel_o = data_i[0 +: S];
        assign data_o = data_i[N-1:S];
    end else if ((POS + S) == N) begin : g_pos_N
        assign sel_o = data_i[POS +: S];
        assign data_o = data_i[POS-1:0];
    end else begin : g_pos
        assign sel_o = data_i[POS +: S];
        assign data_o = {data_i[N-1:(POS+S)], data_i[POS-1:0]};
    end

    `XM_UNUSED_VAR (data_i)

endmodule
`TRACING_ON
