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

`include "xrv_vx_define.vh"

module xrv_vx_pe_switch import xrv_vx_gpu_pkg::*; #(
    parameter PE_COUNT          = 0,
    parameter NUM_LANES_P         = 0,
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
    localparam PID_BITS    = `XM_CLOG2(`NUM_THREADS / NUM_LANES_P);
    localparam PID_WIDTH   = `XM_UP(PID_BITS);
    localparam REQ_DATA_WIDTH_P   = `UUID_WIDTH + WID_WIDTH_P + NUM_LANES_P + `PC_BITS + `INST_ALU_BITS + $bits(op_args_t) + 1 + `NR_BITS + `NT_WIDTH + (3 * NUM_LANES_P * `XLEN) + PID_WIDTH + 1 + 1;
    localparam RSP_DATA_WIDTH_P   = `UUID_WIDTH + WID_WIDTH_P + NUM_LANES_P + `PC_BITS + `NR_BITS + 1 + NUM_LANES_P * `XLEN + PID_WIDTH + 1 + 1;

    wire [PE_COUNT-1:0] pe_req_valid;
    wire [PE_COUNT-1:0][REQ_DATA_WIDTH_P-1:0] pe_req_data;
    wire [PE_COUNT-1:0] pe_req_ready;

    xrv_tream_switch #(
        .DATA_WIDTH_P       (REQ_DATA_WIDTH_P),
        .NUM_INPUTS  (1),
        .NUM_OUTPUTS (PE_COUNT),
        .OUT_BUF     (REQ_OUT_BUF)
    ) req_switch (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .sel_in    (pe_sel),
        .valid_in  (execute_in_if.valid),
        .ready_in  (execute_in_if.ready),
        .data_in   (execute_in_if.data),
        .data_out  (pe_req_data),
        .valid_out (pe_req_valid),
        .ready_out (pe_req_ready)
    );

    for (genvar i = 0; i < PE_COUNT; ++i) begin : g_execute_out_if
        assign execute_out_if[i].valid = pe_req_valid[i];
        assign execute_out_if[i].data = pe_req_data[i];
        assign pe_req_ready[i] = execute_out_if[i].ready;
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [PE_COUNT-1:0] pe_rsp_valid;
    wire [PE_COUNT-1:0][RSP_DATA_WIDTH_P-1:0] pe_rsp_data;
    wire [PE_COUNT-1:0] pe_rsp_ready;

    for (genvar i = 0; i < PE_COUNT; ++i) begin : g_commit_in_if
        assign pe_rsp_valid[i] = commit_in_if[i].valid;
        assign pe_rsp_data[i] = commit_in_if[i].data;
        assign commit_in_if[i].ready = pe_rsp_ready[i];
    end

    xrv_vx_stream_arb #(
        .NUM_INPUTS (PE_COUNT),
        .DATA_WIDTH_P      (RSP_DATA_WIDTH_P),
        .ARBITER    (ARBITER),
        .OUT_BUF    (RSP_OUT_BUF)
    ) rsp_arb (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .valid_in  (pe_rsp_valid),
        .ready_in  (pe_rsp_ready),
        .data_in   (pe_rsp_data),
        .data_out  (commit_out_if.data),
        .valid_out (commit_out_if.valid),
        .ready_out (commit_out_if.ready),
        `UNUSED_PIN (sel_out)
    );

endmodule
