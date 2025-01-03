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
module xrv_find_first #(
    parameter N       = 1,
    parameter DATA_WIDTH_P   = 1,
    parameter REVERSE_P = 0
) (
    input  logic [N-1:0][DATA_WIDTH_P-1:0]  data_i,
    input  logic [N-1:0]                    vld_i,
    output logic [DATA_WIDTH_P-1:0]         data_o,
    output logic                            vld_o
);
    localparam LOGN = `XM_CLOG2(N);
    localparam TL   = (1 << LOGN) - 1;
    localparam TN   = (1 << (LOGN+1)) - 1;

`IGNORE_UNOPTFLAT_BEGIN
    logic s_n [TN];
    logic [DATA_WIDTH_P-1:0] d_n [TN];
`IGNORE_UNOPTFLAT_END

    for (genvar i = 0; i < N; ++i) begin : g_reverse
        assign s_n[TL+i] = REVERSE_P ? vld_i[N-1-i] : vld_i[i];
        assign d_n[TL+i] = REVERSE_P ? data_i[N-1-i] : data_i[i];
    end

    if (TL < (TN-N)) begin : g_fill
        for (genvar i = TL+N; i < TN; ++i) begin : g_i
            assign s_n[i] = 0;
            assign d_n[i] = '0;
        end
    end

    for (genvar j = 0; j < LOGN; ++j) begin : g_scan
        localparam I = 1 << j;
        for (genvar i = 0; i < I; ++i) begin : g_i
            localparam K = I+i-1;
            assign s_n[K] = s_n[2*K+1] | s_n[2*K+2];
            assign d_n[K] = s_n[2*K+1] ? d_n[2*K+1] : d_n[2*K+2];
        end
    end

    assign vld_o = s_n[0];
    assign data_o  = d_n[0];

endmodule
`TRACING_ON
