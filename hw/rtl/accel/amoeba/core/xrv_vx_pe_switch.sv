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

module xrv_vx_pe_switch import amoeba_gpu_pkg::*; #(
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P,
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter PE_COUNT          = 0,
    parameter NUM_LANES_P       = 0,
    parameter REQ_OUT_BUF       = 0,
    parameter RSP_OUT_BUF       = 0,
    parameter `STRING ARBITER   = "R",
    parameter PE_SEL_BITS       = `XM_CLOG2(PE_COUNT)
) (
    input wire          clk_i,
    input wire          rst_i,
    input wire [`XM_UP(PE_SEL_BITS)-1:0] pe_sel,
    xrv_vx_execute_if.slave execute_in_if,
    xrv_vx_commit_if.master commit_out_if,
    xrv_vx_execute_if.master execute_out_if[PE_COUNT],
    xrv_vx_commit_if .slave commit_in_if[PE_COUNT]
);
    localparam PID_BITS    = `XM_CLOG2(NUM_THREADS_P / NUM_LANES_P);
    localparam PID_WIDTH   = `XM_UP(PID_BITS);
    localparam REQ_DATA_WIDTH_P   = UUID_WIDTH_P+ WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P+ VX_INST_ALU_BITS + $bits(op_args_t) + 1 + VX_NR_BITS + TID_WIDTH_P+ (3 * NUM_LANES_P * XLEN_P) + PID_WIDTH + 1 + 1;
    localparam RSP_DATA_WIDTH_P   = UUID_WIDTH_P+ WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P+ VX_NR_BITS + 1 + NUM_LANES_P * XLEN_P + PID_WIDTH + 1 + 1;

    wire [PE_COUNT-1:0] pe_req_vld;
    wire [PE_COUNT-1:0][REQ_DATA_WIDTH_P-1:0] pe_req_data;
    wire [PE_COUNT-1:0] pe_req_rdy;

    xrv_tream_switch #(
        .DATA_WIDTH_P       (REQ_DATA_WIDTH_P),
        .NUM_INPUTS  (1),
        .NUM_OUTPUTS (PE_COUNT),
        .OUT_BUF     (REQ_OUT_BUF)
    ) req_switch (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .sel_in    (pe_sel),
        .vld_in  (execute_in_if.vld),
        .rdy_in  (execute_in_if.rdy),
        .data_in   (execute_in_if.data),
        .data_out  (pe_req_data),
        .vld_out (pe_req_vld),
        .rdy_out (pe_req_rdy)
    );

    for (genvar i = 0; i < PE_COUNT; ++i) begin : g_execute_out_if
        assign execute_out_if[i].vld = pe_req_vld[i];
        assign execute_out_if[i].data = pe_req_data[i];
        assign pe_req_rdy[i] = execute_out_if[i].rdy;
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [PE_COUNT-1:0] pe_rsp_vld;
    wire [PE_COUNT-1:0][RSP_DATA_WIDTH_P-1:0] pe_rsp_data;
    wire [PE_COUNT-1:0] pe_rsp_rdy;

    for (genvar i = 0; i < PE_COUNT; ++i) begin : g_commit_in_if
        assign pe_rsp_vld[i] = commit_in_if[i].vld;
        assign pe_rsp_data[i] = commit_in_if[i].data;
        assign commit_in_if[i].rdy = pe_rsp_rdy[i];
    end

    xrv_vx_stream_arb #(
        .NUM_INPUTS (PE_COUNT),
        .DATA_WIDTH_P      (RSP_DATA_WIDTH_P),
        .ARBITER    (ARBITER),
        .OUT_BUF    (RSP_OUT_BUF)
    ) rsp_arb (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .vld_in  (pe_rsp_vld),
        .rdy_in  (pe_rsp_rdy),
        .data_in   (pe_rsp_data),
        .data_out  (commit_out_if.data),
        .vld_out (commit_out_if.vld),
        .rdy_out (commit_out_if.rdy),
        `XM_UNUSED_PIN (sel_out)
    );

endmodule
