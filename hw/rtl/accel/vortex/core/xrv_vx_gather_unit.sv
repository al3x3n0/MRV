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

module xrv_vx_gather_unit import xrv_vx_gpu_pkg::*; #(
    parameter BLOCK_SIZE    = 1,
    parameter NUM_LANES_P   = 1,
    parameter OUT_BUF       = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P    = "inv",
    parameter NUM_THREADS_P = "inv",
    parameter NUM_WARPS_P   = "inv",
    parameter WID_WIDTH_P   = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P   = `XM_CLOG2(NUM_THREADS_P)
) (
    input  wire         clk_i,
    input  wire         rst_i,

    xrv_vx_commit_if.slave  commit_in_if [BLOCK_SIZE],
    xrv_vx_commit_if.master commit_out_if [ISSUE_WIDTH_P]
);
    `STATIC_ASSERT (`IS_DIVISBLE(ISSUE_WIDTH_P, BLOCK_SIZE), ("invalid parameter"))
    `STATIC_ASSERT (`IS_DIVISBLE(NUM_THREADS_P, NUM_LANES_P), ("invalid parameter"))
    localparam BLOCK_SIZE_W = `XM_LOG2UP(BLOCK_SIZE);
    localparam PID_BITS     = `XM_CLOG2(NUM_THREADS_P / NUM_LANES_P);
    localparam PID_WIDTH    = `XM_UP(PID_BITS);
    localparam DATA_WIDTH_P = UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P + 1 + RF_ADDR_WIDTH_P + NUM_LANES_P * XLEN_P + PID_WIDTH + 1 + 1;
    localparam DATA_WIS_OFF = DATA_WIDTH_P - (UUID_WIDTH_P + WID_WIDTH_P);

    wire [BLOCK_SIZE-1:0] commit_in_valid;
    wire [BLOCK_SIZE-1:0][DATA_WIDTH_P-1:0] commit_in_data;
    wire [BLOCK_SIZE-1:0] commit_in_ready;
    wire [BLOCK_SIZE-1:0][ISSUE_ISW_W-1:0] commit_in_isw;

    for (genvar i = 0; i < BLOCK_SIZE; ++i) begin : g_commit_in
        assign commit_in_valid[i] = commit_in_if[i].valid;
        assign commit_in_data[i] = commit_in_if[i].data;
        assign commit_in_if[i].ready = commit_in_ready[i];
        if (BLOCK_SIZE != ISSUE_WIDTH_P) begin : g_commit_in_isw_partial
            if (BLOCK_SIZE != 1) begin : g_block
                assign commit_in_isw[i] = {commit_in_data[i][DATA_WIS_OFF+BLOCK_SIZE_W +: (ISSUE_ISW_W-BLOCK_SIZE_W)], BLOCK_SIZE_W'(i)};
            end else begin : g_no_block
                assign commit_in_isw[i] = commit_in_data[i][DATA_WIS_OFF +: ISSUE_ISW_W];
            end
        end else begin : g_commit_in_isw_full
            assign commit_in_isw[i] = BLOCK_SIZE_W'(i);
        end
    end

    reg [ISSUE_WIDTH_P-1:0] commit_out_valid;
    reg [ISSUE_WIDTH_P-1:0][DATA_WIDTH_P-1:0] commit_out_data;
    wire [ISSUE_WIDTH_P-1:0] commit_out_ready;

    always @(*) begin
        commit_out_valid = '0;
        for (integer i = 0; i < ISSUE_WIDTH_P; ++i) begin
            commit_out_data[i] = 'x;
        end
        for (integer i = 0; i < BLOCK_SIZE; ++i) begin
            commit_out_valid[commit_in_isw[i]] = commit_in_valid[i];
            commit_out_data[commit_in_isw[i]] = commit_in_data[i];
        end
    end

    for (genvar i = 0; i < BLOCK_SIZE; ++i) begin : g_commit_in_ready
        assign commit_in_ready[i] = commit_out_ready[commit_in_isw[i]];
    end

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin: g_out_bufs
        xrv_vx_commit_if #(
            .NUM_LANES_P (NUM_LANES_P)
        ) commit_tmp_if();

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .SIZE           (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
        ) out_buf (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .valid_in   (commit_out_valid[i]),
            .ready_in   (commit_out_ready[i]),
            .data_in    (commit_out_data[i]),
            .data_out   (commit_tmp_if.data),
            .valid_out  (commit_tmp_if.valid),
            .ready_out  (commit_tmp_if.ready)
        );

        assign commit_out_if[i].valid = commit_tmp_if.valid;
        assign commit_out_if[i].data = {
            commit_tmp_if.data.uuid,
            commit_tmp_if.data.wid,
            commit_tmp_if.data.tmask,
            commit_tmp_if.data.PC,
            commit_tmp_if.data.wb,
            commit_tmp_if.data.rd,
            commit_tmp_if.data.data
        };
        assign commit_tmp_if.ready = commit_out_if[i].ready;
    end

endmodule
