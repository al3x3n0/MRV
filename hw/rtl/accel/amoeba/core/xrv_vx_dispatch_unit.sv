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

module xrv_vx_dispatch_unit import amoeba_gpu_pkg::*; #(
    parameter BLOCK_SIZE = 1,
    parameter NUM_LANES  = 1,
    parameter OUT_BUF    = 0,
    parameter MAX_FANOUT = `MAX_FANOUT,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P,
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P     = "inv",
    parameter PER_ISSUE_WARPS_P = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P       = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P = `XM_UP(ISSUE_WIS_P),
    parameter ISSUE_ISW_P       = `XM_CLOG2(ISSUE_WIDTH_P),
    parameter ISSUE_ISW_WIDTH_P = `XM_UP(ISSUE_ISW_P)
) (
    input  wire             clk_i,
    input  wire             rst_i,

    // inputs
    xrv_vx_dispatch_if.slave    dispatch_if [ISSUE_WIDTH_P],

    // outputs
    xrv_vx_execute_if.master    execute_if [BLOCK_SIZE]

);
    `include "accel/vortex/issue_utils.svh"

    `STATIC_ASSERT (`XM_IS_DIVISBLE(ISSUE_WIDTH_P, BLOCK_SIZE), ("invld parameter"))
    `STATIC_ASSERT (`XM_IS_DIVISBLE(NUM_THREADS_P, NUM_LANES), ("invld parameter"))
    localparam BLOCK_SIZE_W = `XM_LOG2UP(BLOCK_SIZE);
    localparam NUM_PACKETS  = NUM_THREADS_P / NUM_LANES;
    localparam PID_BITS     = `XM_CLOG2(NUM_PACKETS);
    localparam PID_WIDTH    = `XM_UP(PID_BITS);
    localparam BATCH_COUNT  = ISSUE_WIDTH_P / BLOCK_SIZE;
    localparam BATCH_COUNT_W= `XM_LOG2UP(BATCH_COUNT);
    localparam ISSUE_W      = `XM_LOG2UP(ISSUE_WIDTH_P);
    localparam IN_DATAW     = UUID_WIDTH_P + ISSUE_WIS_WIDTH_P + NUM_THREADS_P + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + PC_WIDTH_P + VX_NR_BITS + TID_WIDTH_P + (3 * NUM_THREADS_P * XLEN_P);
    localparam OUT_DATAW    = UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + PC_WIDTH_P + VX_NR_BITS + TID_WIDTH_P + (3 * NUM_LANES * XLEN_P);

    localparam DATA_TMASK_OFF = IN_DATAW - (UUID_WIDTH_P + ISSUE_WIS_WIDTH_P + NUM_THREADS_P);
    localparam DATA_REGS_OFF = 0;

    wire [ISSUE_WIDTH_P-1:0] dispatch_vld;
    wire [ISSUE_WIDTH_P-1:0][IN_DATAW-1:0] dispatch_data;
    wire [ISSUE_WIDTH_P-1:0] dispatch_rdy;

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_dispatch_data
        assign dispatch_vld[i] = dispatch_if[i].vld;
        assign dispatch_data[i] = dispatch_if[i].data;
        assign dispatch_if[i].rdy = dispatch_rdy[i];
    end

    wire [BLOCK_SIZE-1:0] block_rdy;
    wire [BLOCK_SIZE-1:0][NUM_LANES-1:0] block_tmask;
    wire [BLOCK_SIZE-1:0][2:0][NUM_LANES-1:0][XLEN_P-1:0] block_regs;
    wire [BLOCK_SIZE-1:0] block_done;

    wire batch_done = (& block_done);

    // batch select logic

    logic [BATCH_COUNT_W-1:0] batch_idx;

    if (BATCH_COUNT != 1) begin : g_batch_idx
        wire [BATCH_COUNT_W-1:0] batch_idx_n;
        wire [BATCH_COUNT-1:0] vld_batches;
        for (genvar i = 0; i < BATCH_COUNT; ++i) begin : g_vld_batches
            assign vld_batches[i] = | dispatch_vld[i * BLOCK_SIZE +: BLOCK_SIZE];
        end

        xrv_generic_arbiter #(
            .NUM_REQS_P     (BATCH_COUNT),
            .TYPE           ("P")
        ) batch_sel (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .requests       (vld_batches),
            .grant_index    (batch_idx_n),
            `XM_UNUSED_PIN     (grant_onehot),
            `XM_UNUSED_PIN     (grant_vld),
            .grant_rdy    (batch_done)
        );

        always @(posedge clk_i) begin
            if (rst_i) begin
                batch_idx <= '0;
            end else if (batch_done) begin
                batch_idx <= batch_idx_n;
            end
        end
    end else begin : g_batch_idx_0
        assign batch_idx = 0;
        `XM_UNUSED_VAR (batch_done)
    end

    wire [BLOCK_SIZE-1:0][ISSUE_W-1:0] issue_indices;
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : g_issue_indices
        assign issue_indices[block_idx] = ISSUE_W'(batch_idx * BLOCK_SIZE) + ISSUE_W'(block_idx);
    end

    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : g_blocks

        wire [ISSUE_W-1:0] issue_idx = issue_indices[block_idx];
        wire vld_p, rdy_p;

        assign vld_p = dispatch_vld[issue_idx];
        assign block_tmask[block_idx] = dispatch_data[issue_idx][DATA_TMASK_OFF +: NUM_THREADS_P];
        assign block_regs[block_idx][0] = dispatch_data[issue_idx][DATA_REGS_OFF + 2 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_regs[block_idx][1] = dispatch_data[issue_idx][DATA_REGS_OFF + 1 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_regs[block_idx][2] = dispatch_data[issue_idx][DATA_REGS_OFF + 0 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_rdy[block_idx] = rdy_p;
        assign block_done[block_idx]  = rdy_p || ~vld_p;

        wire [ISSUE_ISW_WIDTH_P-1:0] isw;
        if (BATCH_COUNT != 1) begin : g_isw_batch
            if (BLOCK_SIZE != 1) begin : g_block
                assign isw = {batch_idx, BLOCK_SIZE_W'(block_idx)};
            end else begin : g_no_block
                assign isw = batch_idx;
            end
        end else begin : g_isw
            assign isw = block_idx;
        end

        wire [WID_WIDTH_P-1:0] block_wid = wis_to_wid(dispatch_data[issue_idx][DATA_TMASK_OFF+NUM_THREADS_P +: ISSUE_WIS_WIDTH_P], isw);

        logic [OUT_DATAW-1:0] execute_data, execute_data_w;

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (OUT_DATAW),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
        ) buf_out (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .vld_i      (vld_p),
            .rdy_i      (rdy_p),
            .data_i     ({
                dispatch_data[issue_idx][IN_DATAW-1 : DATA_TMASK_OFF+NUM_THREADS_P+ISSUE_WIS_WIDTH_P],
                block_wid,
                block_tmask[block_idx],
                dispatch_data[issue_idx][DATA_TMASK_OFF-1 : DATA_REGS_OFF + 3 * NUM_THREADS_P * XLEN_P],
                block_regs[block_idx][0],
                block_regs[block_idx][1],
                block_regs[block_idx][2]}),
            .data_o     (execute_data),
            .vld_o      (execute_if[block_idx].vld),
            .rdy_o      (execute_if[block_idx].rdy)
        );
        assign execute_if[block_idx].data = execute_data;
    end

    reg [ISSUE_WIDTH_P-1:0] rdy_in;
    always @(*) begin
        rdy_in = 0;
        for (integer block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
            rdy_in[issue_indices[block_idx]] = block_rdy[block_idx];
        end
    end
    assign dispatch_rdy = rdy_in;

endmodule
