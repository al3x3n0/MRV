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
module xrv_bits_insert #(
    parameter N   = 1,
    parameter S   = 1,
    parameter POS = 0
) (
    input wire [N-1:0]          data_i,
    input wire [`XM_UP(S)-1:0]  ins_i,
    output wire [N+S-1:0]       data_o
);
    if (S == 0) begin : g_passthru
        `XM_UNUSED_VAR (ins_i)
        assign data_o = data_i;
    end else begin : g_insert
        if (POS == 0) begin : g_pos_0
            assign data_o = {data_i, ins_i};
        end else if (POS == N) begin : g_pos_N
            assign data_o = {ins_i, data_i};
        end else begin : g_pos
            assign data_o = {data_i[N-1:POS], ins_i, data_i[POS-1:0]};
        end
    end

endmodule
`TRACING_ON
