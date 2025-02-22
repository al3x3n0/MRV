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

    parameter XLEN_P    = "inv"
) (
    input  wire             clk_i,
    input  wire             rst_i,

    // inputs
    xrv_vx_dispatch_if.slave    dispatch_if [ISSUE_WIDTH_P],

    // outputs
    xrv_vx_execute_if.master    execute_if [BLOCK_SIZE]

);
    `STATIC_ASSERT (`XM_IS_DIVISBLE(ISSUE_WIDTH_P, BLOCK_SIZE), ("invalid parameter"))
    `STATIC_ASSERT (`XM_IS_DIVISBLE(NUM_THREADS_P, NUM_LANES), ("invalid parameter"))
    localparam BLOCK_SIZE_W = `XM_LOG2UP(BLOCK_SIZE);
    localparam NUM_PACKETS  = NUM_THREADS_P / NUM_LANES;
    localparam PID_BITS     = `XM_CLOG2(NUM_PACKETS);
    localparam PID_WIDTH    = `XM_UP(PID_BITS);
    localparam BATCH_COUNT  = ISSUE_WIDTH_P / BLOCK_SIZE;
    localparam BATCH_COUNT_W= `XM_LOG2UP(BATCH_COUNT);
    localparam ISSUE_W      = `XM_LOG2UP(ISSUE_WIDTH_P);
    localparam IN_DATAW     = UUID_WIDTH_P + ISSUE_WIS_W + NUM_THREADS_P + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + PC_WIDTH_P + VX_NR_BITS + TID_WIDTH_P + (3 * NUM_THREADS_P * XLEN_P);
    localparam OUT_DATAW    = UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + PC_WIDTH_P + VX_NR_BITS + TID_WIDTH_P + (3 * NUM_LANES * XLEN_P);

    localparam DATA_TMASK_OFF = IN_DATAW - (UUID_WIDTH_P + ISSUE_WIS_W + NUM_THREADS_P);
    localparam DATA_REGS_OFF = 0;

    wire [ISSUE_WIDTH_P-1:0] dispatch_valid;
    wire [ISSUE_WIDTH_P-1:0][IN_DATAW-1:0] dispatch_data;
    wire [ISSUE_WIDTH_P-1:0] dispatch_ready;

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_dispatch_data
        assign dispatch_valid[i] = dispatch_if[i].valid;
        assign dispatch_data[i] = dispatch_if[i].data;
        assign dispatch_if[i].ready = dispatch_ready[i];
    end

    wire [BLOCK_SIZE-1:0] block_ready;
    wire [BLOCK_SIZE-1:0][NUM_LANES-1:0] block_tmask;
    wire [BLOCK_SIZE-1:0][2:0][NUM_LANES-1:0][XLEN_P-1:0] block_regs;
    wire [BLOCK_SIZE-1:0] block_done;

    wire batch_done = (& block_done);

    // batch select logic

    logic [BATCH_COUNT_W-1:0] batch_idx;

    if (BATCH_COUNT != 1) begin : g_batch_idx
        wire [BATCH_COUNT_W-1:0] batch_idx_n;
        wire [BATCH_COUNT-1:0] valid_batches;
        for (genvar i = 0; i < BATCH_COUNT; ++i) begin : g_valid_batches
            assign valid_batches[i] = | dispatch_valid[i * BLOCK_SIZE +: BLOCK_SIZE];
        end

        xrv_generic_arbiter #(
            .NUM_REQS    (BATCH_COUNT),
            .TYPE        ("P")
        ) batch_sel (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .requests       (valid_batches),
            .grant_index    (batch_idx_n),
            `XM_UNUSED_PIN     (grant_onehot),
            `XM_UNUSED_PIN     (grant_valid),
            .grant_ready    (batch_done)
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
        wire valid_p, ready_p;

        assign valid_p = dispatch_valid[issue_idx];
        assign block_tmask[block_idx] = dispatch_data[issue_idx][DATA_TMASK_OFF +: NUM_THREADS_P];
        assign block_regs[block_idx][0] = dispatch_data[issue_idx][DATA_REGS_OFF + 2 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_regs[block_idx][1] = dispatch_data[issue_idx][DATA_REGS_OFF + 1 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_regs[block_idx][2] = dispatch_data[issue_idx][DATA_REGS_OFF + 0 * NUM_THREADS_P * XLEN_P +: NUM_THREADS_P * XLEN_P];
        assign block_ready[block_idx] = ready_p;
        assign block_done[block_idx]  = ready_p || ~valid_p;

        wire [ISSUE_ISW_W-1:0] isw;
        if (BATCH_COUNT != 1) begin : g_isw_batch
            if (BLOCK_SIZE != 1) begin : g_block
                assign isw = {batch_idx, BLOCK_SIZE_W'(block_idx)};
            end else begin : g_no_block
                assign isw = batch_idx;
            end
        end else begin : g_isw
            assign isw = block_idx;
        end

        wire [WID_WIDTH_P-1:0] block_wid = wis_to_wid(dispatch_data[issue_idx][DATA_TMASK_OFF+NUM_THREADS_P +: ISSUE_WIS_W], isw);

        logic [OUT_DATAW-1:0] execute_data, execute_data_w;

        xrv_elastic_buffer #(
            .DATAW   (OUT_DATAW),
            .SIZE    (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
            .OUT_REG (`XM_TO_OUT_BUF_REG(OUT_BUF))
        ) buf_out (
            .clk_i       (clk_i),
            .rst_i     (rst_i),
            .valid_in  (valid_p),
            .ready_in  (ready_p),
            .data_in   ({
                dispatch_data[issue_idx][IN_DATAW-1 : DATA_TMASK_OFF+NUM_THREADS_P+ISSUE_WIS_W],
                block_wid,
                block_tmask[block_idx],
                dispatch_data[issue_idx][DATA_TMASK_OFF-1 : DATA_REGS_OFF + 3 * NUM_THREADS_P * XLEN_P],
                block_regs[block_idx][0],
                block_regs[block_idx][1],
                block_regs[block_idx][2]}),
            .data_out  (execute_data),
            .valid_out (execute_if[block_idx].valid),
            .ready_out (execute_if[block_idx].ready)
        );
        assign execute_if[block_idx].data = execute_data;
    end

    reg [ISSUE_WIDTH_P-1:0] ready_in;
    always @(*) begin
        ready_in = 0;
        for (integer block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
            ready_in[issue_indices[block_idx]] = block_ready[block_idx];
        end
    end
    assign dispatch_ready = ready_in;

endmodule
