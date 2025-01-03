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
module xrv_bits_concat #(
    parameter L = 1,
    parameter R = 1
) (
    input  logic [`XM_UP(L)-1:0] left_i,
    input  logic [`XM_UP(R)-1:0] right_i,
    output logic [(L+R)-1:0]     data_o
);
    if (L == 0) begin : g_right_only
        `XM_UNUSED_VAR (left_i)
        assign data_o = right_i;
    end else if (R == 0) begin : g_left_only
        `XM_UNUSED_VAR (right_i)
        assign data_o = left_i;
    end else begin : g_concat
        assign data_o = {left_i, right_i};
    end

endmodule
`TRACING_ON
