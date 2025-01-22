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
module xrv_reset_relay #(
    parameter N          = 1,
    parameter MAX_FANOUT = 0
) (
    input wire          clk_i,
    input wire          rst_i,
    output wire [N-1:0] rst_o
);
    if (MAX_FANOUT >= 0 && N > (MAX_FANOUT + MAX_FANOUT/2)) begin : g_relay
        localparam F = `XM_UP(MAX_FANOUT);
        localparam R = N / F;
        `PRESERVE_NET reg [R-1:0] rst_i_r;
        for (genvar i = 0; i < R; ++i) begin : g_rst_i_r
            always @(posedge clk_i) begin
                rst_i_r[i] <= rst_i;
            end
        end
        for (genvar i = 0; i < N; ++i) begin : g_rst_o
            assign rst_o[i] = rst_i_r[i / F];
        end
    end else begin : g_passthru
        `XM_UNUSED_VAR (clk_i)
        assign rst_o = {N{rst_i}};
    end

endmodule
`TRACING_ON
