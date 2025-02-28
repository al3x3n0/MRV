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
`include "pkg/amoeba_gpu_pkg.sv"

module xrv_vx_commit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P     = "inv",
    parameter PER_ISSUE_WARPS_P = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P       = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P = `XM_UP(ISSUE_WIS_P),
    parameter ISSUE_ISW_P       = `XM_CLOG2(ISSUE_WIDTH_P),
    parameter ISSUE_ISW_WIDTH_P = `XM_UP(ISSUE_ISW_P)
) (
    input wire                      clk_i,
    input wire                      rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_commit_if.slave          commit_if [VX_NUM_EX_UNITS * ISSUE_WIDTH_P],
    xrv_vx_writeback_if.master      writeback_if [ISSUE_WIDTH_P],
    xrv_vx_commit_csr_if.master     commit_csr_if,
    xrv_vx_commit_sched_if.master   commit_sched_if
);
    `include "accel/vortex/issue_utils.svh"

    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam DATA_WIDTH_P = UUID_WIDTH_P + WID_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P + 1 + VX_NR_BITS + NUM_THREADS_P * XLEN_P;// + 1 + 1 + 1;
    localparam COMMIT_SIZEW = `XM_CLOG2(NUM_THREADS_P + 1);
    localparam COMMIT_ALL_SIZEW = COMMIT_SIZEW + ISSUE_WIDTH_P - 1;

    // commit arbitration

    xrv_vx_commit_if #(
        .NUM_LANES_P    (NUM_THREADS_P),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) commit_arb_if[ISSUE_WIDTH_P]();

    wire [ISSUE_WIDTH_P-1:0] per_issue_commit_fire;
    wire [ISSUE_WIDTH_P-1:0][WID_WIDTH_P-1:0] per_issue_commit_wid;
    wire [ISSUE_WIDTH_P-1:0][NUM_THREADS_P-1:0] per_issue_commit_tmask;

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_commit_arbs

        wire [VX_NUM_EX_UNITS-1:0]            vld_in;
        wire [VX_NUM_EX_UNITS-1:0][DATA_WIDTH_P-1:0] data_in;
        wire [VX_NUM_EX_UNITS-1:0]            rdy_in;

        for (genvar j = 0; j < VX_NUM_EX_UNITS; ++j) begin : g_data_in
            assign vld_in[j] = commit_if[j * ISSUE_WIDTH_P + i].vld;
            assign data_in[j]  = commit_if[j * ISSUE_WIDTH_P + i].data;
            assign commit_if[j * ISSUE_WIDTH_P + i].rdy = rdy_in[j];
        end

        xrv_stream_arb #(
            .NUM_INPUTS_P   (VX_NUM_EX_UNITS),
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .ARBITER_TYPE_P ("P"),
            .OUT_BUF        (1)
        ) commit_arb (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .vld_i      (vld_in),
            .rdy_i      (rdy_in),
            .data_i     (data_in),
            .data_o     (commit_arb_if[i].data),
            .vld_o      (commit_arb_if[i].vld),
            .rdy_o      (commit_arb_if[i].rdy),
            `XM_UNUSED_PIN (sel_o)
        );

        assign per_issue_commit_fire[i] = commit_arb_if[i].vld && commit_arb_if[i].rdy;
        assign per_issue_commit_tmask[i]= {NUM_THREADS_P{per_issue_commit_fire[i]}} & commit_arb_if[i].data.tmask;
        assign per_issue_commit_wid[i]  = commit_arb_if[i].data.wid;
    end

    // CSRs update

    wire [ISSUE_WIDTH_P-1:0][COMMIT_SIZEW-1:0] commit_size, commit_size_r;
    wire [COMMIT_ALL_SIZEW-1:0] commit_size_all_r, commit_size_all_rr;
    wire commit_fire_any, commit_fire_any_r, commit_fire_any_rr;

    assign commit_fire_any = (| per_issue_commit_fire);

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_commit_size
        wire [COMMIT_SIZEW-1:0] count;
        `POP_COUNT(count, per_issue_commit_tmask[i]);
        assign commit_size[i] = count;
    end

    xrv_pipe_register #(
        .DATA_WIDTH_P  (1 + ISSUE_WIDTH_P * COMMIT_SIZEW),
        .RESET_WIDTH_P (1)
    ) commit_size_reg1 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     ({commit_fire_any, commit_size}),
        .data_o     ({commit_fire_any_r, commit_size_r})
    );

    xrv_reduce #(
        .DATA_WIDTH_IN_P (COMMIT_SIZEW),
        .DATA_WIDTH_OUT_P (COMMIT_ALL_SIZEW),
        .N  (ISSUE_WIDTH_P),
        .OP ("+")
    ) commit_size_reduce (
        .data_in  (commit_size_r),
        .data_out (commit_size_all_r)
    );

    xrv_pipe_register #(
        .DATA_WIDTH_P  (1 + COMMIT_ALL_SIZEW),
        .RESET_WIDTH_P (1)
    ) commit_size_reg2 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     ({commit_fire_any_r, commit_size_all_r}),
        .data_o     ({commit_fire_any_rr, commit_size_all_rr})
    );

    reg [VX_PERF_CTR_BITS-1:0] instret;
    always @(posedge clk_i) begin
       if (rst_i) begin
            instret <= '0;
        end else begin
            if (commit_fire_any_rr) begin
                instret <= instret + VX_PERF_CTR_BITS'(commit_size_all_rr);
            end
        end
    end
    assign commit_csr_if.instret = instret;

    // Track committed instructions

    reg [NUM_WARPS_P-1:0] committed_warps;

    always_comb begin
        committed_warps = 0;
        for (integer i = 0; i < ISSUE_WIDTH_P; ++i) begin
            if (per_issue_commit_fire[i]) begin
                committed_warps[per_issue_commit_wid[i]] = 1;
            end
        end
    end

    xrv_pipe_register #(
        .DATA_WIDTH_P  (NUM_WARPS_P),
        .RESET_WIDTH_P (NUM_WARPS_P)
    ) committed_pipe_reg (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     (committed_warps),
        .data_o     ({commit_sched_if.committed_warps})
    );

    // Writeback

    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_writeback
        assign writeback_if[i].vld        = commit_arb_if[i].vld && commit_arb_if[i].data.wb;
        assign writeback_if[i].data.uuid    = commit_arb_if[i].data.uuid;
        assign writeback_if[i].data.wis     = wid_to_wis(commit_arb_if[i].data.wid);
        assign writeback_if[i].data.PC      = commit_arb_if[i].data.PC;
        assign writeback_if[i].data.tmask   = commit_arb_if[i].data.tmask;
        assign writeback_if[i].data.rd      = commit_arb_if[i].data.rd;
        assign writeback_if[i].data.data    = commit_arb_if[i].data.data;
        assign commit_arb_if[i].rdy       = 1'b1; // writeback has no backpressure
    end

`ifdef DBG_TRACE_PIPELINE
    for (genvar i = 0; i < ISSUE_WIDTH_P; ++i) begin : g_trace
        for (genvar j = 0; j < VX_NUM_EX_UNITS; ++j) begin : g_j
            always @(posedge clk_i) begin
                if (commit_if[j * ISSUE_WIDTH_P + i].vld && commit_if[j * ISSUE_WIDTH_P + i].rdy) begin
                    `TRACE(1, ("%t: %s: wid=%0d, PC=0x%0h, ex=", $time, INSTANCE_ID, commit_if[j * ISSUE_WIDTH_P + i].data.wid, {commit_if[j * ISSUE_WIDTH_P + i].data.PC, 1'b0}))
                    trace_ex_type(1, j);
                    `TRACE(1, (", tmask=%b, wb=%0d, rd=%0d, data=", commit_if[j * ISSUE_WIDTH_P + i].data.tmask, commit_if[j * ISSUE_WIDTH_P + i].data.wb, commit_if[j * ISSUE_WIDTH_P + i].data.rd))
                    `TRACE_ARRAY1D(1, "0x%0h", commit_if[j * ISSUE_WIDTH_P + i].data.data, NUM_THREADS_P)
                    `TRACE(1, (" (#%0d)\n", commit_if[j * ISSUE_WIDTH_P + i].data.uuid))
                end
            end
        end
    end
`endif

endmodule
