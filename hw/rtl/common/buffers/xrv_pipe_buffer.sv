// Copyright 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// A pipelined elastic buffer operates at full bandwidth where push can happen if the buffer is not empty but is going empty
// It has the following benefits:
// + Full-bandwidth throughput
// + use only one register for storage
// + data_o is fully registered
// It has the following limitations:
// + rdy_i and rdy_o are coupled
////////////////////////////////////////////////////////////////////////////////


module xrv_pipe_buffer #(
    parameter DATA_WIDTH_P  = 1,
    parameter RESET_WIDTH_P = 0,
    parameter DEPTH_P  = 1
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic                        vld_i,
    output logic                        rdy_i,
    input  logic [DATA_WIDTH_P-1:0]     data_i,
    output logic [DATA_WIDTH_P-1:0]     data_o,
    input  logic                        rdy_o,
    output logic                        vld_o
);
    if (DEPTH_P == 0) begin : g_passthru
        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        assign rdy_i  = rdy_o;
        assign vld_o = vld_i;
        assign data_o  = data_i;
    end else begin : g_register
        logic [DEPTH_P:0] valid;
    `IGNORE_UNOPTFLAT_BEGIN
        logic ready [DEPTH_P+1];
    `IGNORE_UNOPTFLAT_END
        logic [DEPTH_P:0][DATA_WIDTH_P-1:0] data;

        assign valid[0] = vld_i;
        assign data[0]  = data_i;
        assign rdy_i = ready[0];

        for (genvar i = 0; i < DEPTH_P; ++i) begin : g_pipe_regs
            assign ready[i] = (ready[i+1] || ~valid[i+1]);
            xrv_pipe_register #(
                .DATA_WIDTH_P       (1 + DATA_WIDTH_P),
                .RESET_WIDTH_P      (1 + RESET_WIDTH_P)
            ) pipe_register_i (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .en_i               (ready[i]),
                .data_i             ({valid[i], data[i]}),
                .data_o             ({valid[i+1], data[i+1]})
            );
        end

        assign vld_o = valid[DEPTH_P];
        assign data_o = data[DEPTH_P];
        assign ready[DEPTH_P] = rdy_o;
    end

endmodule
