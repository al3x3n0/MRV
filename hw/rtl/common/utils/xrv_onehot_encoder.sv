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

// Fast one-hot encoder using parallel prefix computation
// Adapted from BaseJump STL: http://bjump.org/data_out.html

`TRACING_OFF
module xrv_onehot_encoder #(
    parameter N       = 1,
    parameter REVERSE = 0,
    parameter MODEL   = 1,
    parameter LN      = `XM_LOG2UP(N)
) (
    input  logic [N-1:0]    data_i,
    output logic [LN-1:0]   data_o,
    output logic            vld_o
);
    if (N == 1) begin : g_n1

        assign data_o  = 0;
        assign vld_o = data_i;

    end else if (N == 2) begin : g_n2

        assign data_o  = data_i[!REVERSE];
        assign vld_o = (| data_i);

    end else if (MODEL == 1) begin : g_model1
        localparam M = 1 << LN;
    `IGNORE_UNOPTFLAT_BEGIN
        logic [M-1:0] addr [LN];
        logic [M-1:0] v [LN+1];
    `IGNORE_UNOPTFLAT_END

        // base case, also handle padding for non-power of two inputs
        assign v[0] = REVERSE ? (M'(data_i) << (M - N)) : M'(data_i);

        for (genvar lvl = 1; lvl < (LN+1); ++lvl) begin : g_scan_l
            localparam SN = 1 << (LN - lvl);
            localparam SI = M / SN;
            for (genvar s = 0; s < SN; ++s) begin : g_scan_s
            `IGNORE_UNOPTFLAT_BEGIN
                logic [1:0] vs = {v[lvl-1][s*SI+(SI>>1)], v[lvl-1][s*SI]};
            `IGNORE_UNOPTFLAT_END
                assign v[lvl][s*SI] = (| vs);
                if (lvl == 1) begin : g_lvl_1
                    assign addr[lvl-1][s*SI +: lvl] = vs[!REVERSE];
                end else begin : g_lvl_n
                    assign addr[lvl-1][s*SI +: lvl] = {
                        vs[!REVERSE],
                        addr[lvl-2][s*SI +: lvl-1] | addr[lvl-2][s*SI+(SI>>1) +: lvl-1]
                    };
                end
            end
        end

        assign data_o = addr[LN-1][LN-1:0];
        assign vld_o = v[LN][0];

    end else if (MODEL == 2 && REVERSE == 0) begin : g_model2

        for (genvar j = 0; j < LN; ++j) begin : g_data_out
            logic [N-1:0] mask;
            for (genvar i = 0; i < N; ++i) begin : g_mask
                assign mask[i] = i[j];
            end
            assign data_o[j] = | (mask & data_i);
        end

        assign vld_o = (| data_i);

    end else begin : g_model0

        reg [LN-1:0] index_w;

        if (REVERSE != 0) begin : g_msb
            always_comb begin
                index_w = 'x;
                for (integer i = N-1; i >= 0; --i) begin
                    if (data_i[i]) begin
                        index_w = LN'(N-1-i);
                    end
                end
            end
        end else begin : g_lsb
            always_comb begin
                index_w = 'x;
                for (integer i = 0; i < N; ++i) begin
                    if (data_i[i]) begin
                        index_w = LN'(i);
                    end
                end
            end
        end

        assign data_o  = index_w;
        assign vld_o = (| data_i);
    end

endmodule
`TRACING_ON
