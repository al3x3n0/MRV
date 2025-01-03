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
module xrv_pipe_register #(
    parameter DATA_WIDTH_P                          = 1,
    parameter RESET_WIDTH_P                         = 0,
    parameter DEPTH_P                               = 1,
    parameter [`XM_UP(RESET_WIDTH_P)-1:0] INIT_VALUE   = {`XM_UP(RESET_WIDTH_P){1'b0}}
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic                        en_i,
    input  logic [DATA_WIDTH_P-1:0]     data_i,
    output logic [DATA_WIDTH_P-1:0]     data_o
);
    if (DEPTH_P == 0) begin : g_passthru
        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        `XM_UNUSED_VAR (en_i)
        assign data_o = data_i;
    end else if (DEPTH_P == 1) begin : g_depth1
        if (RESET_WIDTH_P == 0) begin : g_no_rst_i
            `XM_UNUSED_VAR (rst_i)
            reg [DATA_WIDTH_P-1:0] value;

            always_ff @(posedge clk_i) begin
                if (en_i) begin
                    value <= data_i;
                end
            end
            assign data_o = value;
        end else if (RESET_WIDTH_P < DATA_WIDTH_P) begin : g_partial_rst_i
            reg [DATA_WIDTH_P-RESET_WIDTH_P-1:0] value_d;
            reg [RESET_WIDTH_P-1:0]       value_r;

            always_ff @(posedge clk_i) begin
                if (rst_i) begin
                    value_r <= INIT_VALUE;
                end else if (en_i) begin
                    value_r <= data_i[DATA_WIDTH_P-1:DATA_WIDTH_P-RESET_WIDTH_P];
                end
            end

            always_ff @(posedge clk_i) begin
                if (en_i) begin
                    value_d <= data_i[DATA_WIDTH_P-RESET_WIDTH_P-1:0];
                end
            end
            assign data_o = {value_r, value_d};
        end else begin : g_full_rst_i
            reg [DATA_WIDTH_P-1:0] value;

            always_ff @(posedge clk_i) begin
                if (rst_i) begin
                    value <= INIT_VALUE;
                end else if (en_i) begin
                    value <= data_i;
                end
            end
            assign data_o = value;
        end
    end else begin : g_recursive
        logic [DEPTH_P:0][DATA_WIDTH_P-1:0] data_delayed;
        assign data_delayed[0] = data_i;

        for (genvar i = 1; i <= DEPTH_P; ++i) begin : g_pipe_reg
            xrv_pipe_register #(
                .DATA_WIDTH_P  (DATA_WIDTH_P),
                .RESET_WIDTH_P (RESET_WIDTH_P),
                .INIT_VALUE (INIT_VALUE)
            ) pipe_reg (
                .clk_i      (clk_i),
                .rst_i      (rst_i),
                .en_i       (en_i),
                .data_i     (data_delayed[i-1]),
                .data_o     (data_delayed[i])
            );
        end
        assign data_o = data_delayed[DEPTH_P];
    end

endmodule
`TRACING_ON
