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
module xrv_stream_switch #(
    parameter NUM_INPUTS_P          = 1,
    parameter NUM_OUTPUTS_P         = 1,
    parameter DATA_WIDTH_P          = 1,
    parameter OUT_BUF               = 0,
    parameter NUM_REQS_P            = (NUM_INPUTS_P > NUM_OUTPUTS_P) ? `XM_CDIV(NUM_INPUTS_P, NUM_OUTPUTS_P) : `XM_CDIV(NUM_OUTPUTS_P, NUM_INPUTS_P),
    parameter SEL_COUNT             = `XM_MIN(NUM_INPUTS_P, NUM_OUTPUTS_P),
    parameter LOG_NUM_REQS_P        = `XM_CLOG2(NUM_REQS_P)
) (
    input wire                              clk_i,
    input wire                              rst_i,

    input wire  [SEL_COUNT-1:0][`XM_UP(LOG_NUM_REQS_P)-1:0]  sel_i,

    input  wire [NUM_INPUTS_P-1:0]                      vld_i,
    input  wire [NUM_INPUTS_P-1:0][DATA_WIDTH_P-1:0]    data_i,
    output wire [NUM_INPUTS_P-1:0]                      rdy_i,

    output wire [NUM_OUTPUTS_P-1:0]                     vld_o,
    output wire [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0]   data_o,
    input  wire [NUM_OUTPUTS_P-1:0]                     rdy_o
);
    if (NUM_INPUTS_P > NUM_OUTPUTS_P) begin : g_input_select

        for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_out_buf

            wire [NUM_REQS_P-1:0] vld_i_w;
            wire [NUM_REQS_P-1:0][DATA_WIDTH_P-1:0] data_i_w;
            wire [NUM_REQS_P-1:0] rdy_i_w;

            for (genvar r = 0; r < NUM_REQS_P; ++r) begin : g_r
                localparam i = r * NUM_OUTPUTS_P + o;
                if (i < NUM_INPUTS_P) begin : g_valid
                    assign vld_i_w[r] = vld_i[i];
                    assign data_i_w[r]  = data_i[i];
                    assign rdy_i[i]   = rdy_i_w[r];
                end else begin : g_padding
                    assign vld_i_w[r] = 0;
                    assign data_i_w[r]  = '0;
                    `XM_UNUSED_VAR (rdy_i_w[r])
                end
            end

            xrv_elastic_buffer #(
                .DATA_WIDTH_P   (DATA_WIDTH_P),
                .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
            ) out_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_i_w[sel_i[o]]),
                .rdy_i          (rdy_i_w[sel_i[o]]),
                .data_i         (data_i_w[sel_i[o]]),
                .data_o         (data_o[o]),
                .vld_o          (vld_o[o]),
                .rdy_o          (rdy_o[o])
            );
        end

    end else if (NUM_OUTPUTS_P > NUM_INPUTS_P) begin : g_output_select

        // Inputs < Outputs

        for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_out_buf

            wire [NUM_REQS_P-1:0] rdy_o_w;

            for (genvar r = 0; r < NUM_REQS_P; ++r) begin : g_r
                localparam o = r * NUM_INPUTS_P + i;
                if (o < NUM_OUTPUTS_P) begin : g_valid
                    wire vld_o_w  = vld_i[i] && (sel_i[i] == LOG_NUM_REQS_P'(r));
                    xrv_elastic_buffer #(
                        .DATA_WIDTH_P   (DATA_WIDTH_P),
                        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                        .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
                    ) out_buf (
                        .clk_i          (clk_i),
                        .rst_i          (rst_i),
                        .vld_i          (vld_o_w),
                        .rdy_i          (rdy_o_w[r]),
                        .data_i         (data_i[i]),
                        .data_o         (data_o[o]),
                        .vld_o          (vld_o[o]),
                        .rdy_o          (rdy_o[o])
                    );
                end else begin : g_padding
                    assign rdy_o_w[r] = '0;
                end
            end

            assign rdy_i[i] = rdy_o_w[sel_i[i]];
        end

    end else begin : g_passthru

        // #Inputs == #Outputs

        `XM_UNUSED_VAR (sel_i)

        for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_out_buf
            xrv_elastic_buffer #(
                .DATA_WIDTH_P   (DATA_WIDTH_P),
                .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
            ) out_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_i[i]),
                .rdy_i          (rdy_i[i]),
                .data_i         (data_i[i]),
                .data_o         (data_o[i]),
                .vld_o          (vld_o[i]),
                .rdy_o          (rdy_o[i])
            );
        end
    end

endmodule
`TRACING_ON
