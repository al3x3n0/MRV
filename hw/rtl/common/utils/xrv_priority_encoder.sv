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
module xrv_priority_encoder #(
    parameter N       = 1,
    parameter REVERSE_P  = 0,
    parameter MODEL   = 1,
    parameter LN      = `XM_LOG2UP(N)
) (
    input  logic [N-1:0]  data_i,
    output logic [N-1:0]  onehot_o,
    output logic [LN-1:0] index_o,
    output logic          vld_o
);
    logic [N-1:0] reversed;

    if (REVERSE_P  != 0) begin : g_reverse
        for (genvar i = 0; i < N; ++i) begin : g_i
            assign reversed[N-i-1] = data_i[i];
        end
    end else begin : g_no_reverse
        assign reversed = data_i;
    end

    if (N == 1) begin : g_n1

        assign onehot_o = reversed;
        assign index_o  = '0;
        assign vld_o  = reversed;

    end else if (N == 2) begin : g_n2

        assign onehot_o = {reversed[1] && ~reversed[0], reversed[0]};
        assign index_o  = ~reversed[0];
        assign vld_o  = (| reversed);

    end else if (MODEL == 1) begin : g_model1

    `IGNORE_UNOPTFLAT_BEGIN
        logic [N-1:0] higher_pri_regs;
    `IGNORE_UNOPTFLAT_END

        assign higher_pri_regs[0] = 1'b0;
        for (genvar i = 1; i < N; ++i) begin : g_higher_pri_regs
            assign higher_pri_regs[i] = higher_pri_regs[i-1] | reversed[i-1];
        end
        assign onehot_o[N-1:0] = reversed[N-1:0] & ~higher_pri_regs[N-1:0];

        xrv_lzc #(
            .N          (N),
            .REVERSE_P     (1)
        ) lzc (
            .data_i     (reversed),
            .data_o     (index_o),
            .vld_o      (vld_o)
        );

    end else if (MODEL == 2) begin : g_model2

        logic [N-1:0] scan_lo;

        xrv_scan #(
            .N          (N),
            .OP         ("|")
        ) scan (
            .data_i     (reversed),
            .data_o     (scan_lo)
        );

        xrv_lzc #(
            .N          (N),
            .REVERSE_P     (1)
        ) lzc (
            .data_i     (reversed),
            .data_o     (index_o),
            .vld_o      (vld_o)
        );

        assign onehot_o = scan_lo & {(~scan_lo[N-2:0]), 1'b1};

    end else if (MODEL == 3) begin : g_model3

        assign onehot_o = reversed & -reversed;

        xrv_lzc #(
            .N          (N),
            .REVERSE_P     (1)
        ) lzc (
            .data_i     (reversed),
            .data_o     (index_o),
            .vld_o      (vld_o)
        );

    end else begin : g_model0

        logic [LN-1:0] index_w;
        logic [N-1:0]  onehot_w;

        always_comb begin
            index_w  = 'x;
            onehot_w = 'x;
            for (integer i = N-1; i >= 0; --i) begin
                if (reversed[i]) begin
                    index_w  = LN'(i);
                    onehot_w = N'(1) << i;
                end
            end
        end

        assign index_o  = index_w;
        assign onehot_o = onehot_w;
        assign vld_o  = (| reversed);

    end

endmodule
`TRACING_ON
