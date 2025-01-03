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

// Fast encoder using parallel prefix computation
// Adapted from BaseJump STL: http://bjump.org/data_out.html

`TRACING_OFF
module xrv_demux #(
    parameter DATA_WIDTH_P = 1,
    parameter N = 0,
    parameter MODEL = 0,
    parameter LN = `XM_LOG2UP(N)
) (
    input  logic [LN-1:0] sel_i,
    input  logic [DATA_WIDTH_P-1:0] data_i,
    output logic [N-1:0][DATA_WIDTH_P-1:0] data_o
);
    if (N > 1) begin : g_demux
        logic [N-1:0][DATA_WIDTH_P-1:0] shift;
        if (MODEL == 1) begin : g_model1
            always_comb begin
                shift = '0;
                shift[sel_i] = {DATA_WIDTH_P{1'b1}};
            end
        end else begin : g_model0
            assign shift = ((N*DATA_WIDTH_P)'({DATA_WIDTH_P{1'b1}})) << (sel_i * DATA_WIDTH_P);
        end
        assign data_o = {N{data_i}} & shift;
    end else begin : g_passthru
        `XM_UNUSED_VAR (sel_i)
        assign data_o = data_i;
    end

endmodule
`TRACING_ON
