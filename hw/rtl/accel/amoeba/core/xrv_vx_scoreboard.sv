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

module xrv_vx_scoreboard import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 64,
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = 4,
    parameter NUM_WARPS_P           = 4,
    parameter UUID_WIDTH_P          = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = `XM_UP(NUM_WARPS_P / 8),
    parameter PER_ISSUE_WARPS_P     = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P           = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P     = `XM_UP(ISSUE_WIS_P)
) (
    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output reg [VX_PERF_CTR_BITS-1:0] perf_stalls,
    output reg [VX_NUM_EX_UNITS-1:0][VX_PERF_CTR_BITS-1:0] perf_units_uses,
    output reg [VX_NUM_SFU_UNITS-1:0][VX_PERF_CTR_BITS-1:0] perf_sfu_uses,
`endif

    xrv_vx_writeback_if.slave   writeback_if,
    xrv_vx_ibuffer_if.slave     ibuffer_if [PER_ISSUE_WARPS_P],
    xrv_vx_scoreboard_if.master scoreboard_if
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam NUM_SRC_OPDS = 3;
    localparam NUM_OPDS = NUM_SRC_OPDS + 1;
    localparam DATAW = UUID_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P + VX_EX_BITS + VX_INST_OP_BITS + VX_INST_ARGS_BITS + (VX_NR_BITS * 4) + 1;

    xrv_vx_ibuffer_if #(
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) staging_if [PER_ISSUE_WARPS_P]();
    reg [PER_ISSUE_WARPS_P-1:0] operands_rdy;

`ifdef PERF_ENABLE
    reg [PER_ISSUE_WARPS_P-1:0][VX_NUM_EX_UNITS-1:0] perf_inuse_units_per_cycle;
    wire [VX_NUM_EX_UNITS-1:0] perf_units_per_cycle, perf_units_per_cycle_r;

    reg [PER_ISSUE_WARPS_P-1:0][VX_NUM_SFU_UNITS-1:0] perf_inuse_sfu_per_cycle;
    wire [VX_NUM_SFU_UNITS-1:0] perf_sfu_per_cycle, perf_sfu_per_cycle_r;

    xrv_reduce #(
        .DATAW_IN (VX_NUM_EX_UNITS),
        .N  (PER_ISSUE_WARPS_P),
        .OP ("|")
    ) perf_units_reduce (
        .data_in  (perf_inuse_units_per_cycle),
        .data_out (perf_units_per_cycle)
    );

    xrv_reduce #(
        .DATAW_IN (VX_NUM_SFU_UNITS),
        .N  (PER_ISSUE_WARPS_P),
        .OP ("|")
    ) perf_sfu_reduce (
        .data_in  (perf_inuse_sfu_per_cycle),
        .data_out (perf_sfu_per_cycle)
    );

    `BUFFER_EX(perf_units_per_cycle_r, perf_units_per_cycle, 1'b1, 0, `CDIV(PER_ISSUE_WARPS_P, `MAX_FANOUT));
    `BUFFER_EX(perf_sfu_per_cycle_r, perf_sfu_per_cycle, 1'b1, 0, `CDIV(PER_ISSUE_WARPS_P, `MAX_FANOUT));

    wire [PER_ISSUE_WARPS_P-1:0] stg_vld_in;
    for (genvar w = 0; w < PER_ISSUE_WARPS_P; ++w) begin : g_stg_vld_in
        assign stg_vld_in[w] = staging_if[w].vld;
    end

    wire perf_stall_per_cycle = (|stg_vld_in) && ~(|(stg_vld_in & operands_rdy));

    always @(posedge clk_i) begin : g_perf_stalls
        if (rst_i) begin
            perf_stalls <= '0;
        end else begin
            perf_stalls <= perf_stalls + VX_PERF_CTR_BITS'(perf_stall_per_cycle);
        end
    end

    for (genvar i = 0; i < VX_NUM_EX_UNITS; ++i) begin : g_perf_units_uses
        always @(posedge clk_i) begin
            if (rst_i) begin
                perf_units_uses[i] <= '0;
            end else begin
                perf_units_uses[i] <= perf_units_uses[i] + VX_PERF_CTR_BITS'(perf_units_per_cycle_r[i]);
            end
        end
    end

    for (genvar i = 0; i < VX_NUM_SFU_UNITS; ++i) begin : g_perf_sfu_uses
        always @(posedge clk_i) begin
            if (rst_i) begin
                perf_sfu_uses[i] <= '0;
            end else begin
                perf_sfu_uses[i] <= perf_sfu_uses[i] + VX_PERF_CTR_BITS'(perf_sfu_per_cycle_r[i]);
            end
        end
    end
`endif

    for (genvar w = 0; w < PER_ISSUE_WARPS_P; ++w) begin : g_staging_bufs
        xrv_pipe_buffer #(
            .DATA_WIDTH_P (DATAW)
        ) staging_buf (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .vld_i      (ibuffer_if[w].vld),
            .data_i     (ibuffer_if[w].data),
            .rdy_i      (ibuffer_if[w].rdy),
            .vld_o      (staging_if[w].vld),
            .data_o     (staging_if[w].data),
            .rdy_o      (staging_if[w].rdy)
        );
    end

    for (genvar w = 0; w < PER_ISSUE_WARPS_P; ++w) begin : g_scoreboard
        reg [VX_NUM_REGS-1:0] inuse_regs;

        reg [NUM_OPDS-1:0] operands_busy, operands_busy_n;

        wire ibuffer_fire = ibuffer_if[w].vld && ibuffer_if[w].rdy;

        wire staging_fire = staging_if[w].vld && staging_if[w].rdy;

        wire writeback_fire = writeback_if.vld
                           && (writeback_if.data.wis == ISSUE_WIS_WIDTH_P'(w));

        wire [NUM_OPDS-1:0][VX_NR_BITS-1:0] ibuf_opds, stg_opds;
        assign ibuf_opds = {ibuffer_if[w].data.rs3, ibuffer_if[w].data.rs2, ibuffer_if[w].data.rs1, ibuffer_if[w].data.rd};
        assign stg_opds = {staging_if[w].data.rs3, staging_if[w].data.rs2, staging_if[w].data.rs1, staging_if[w].data.rd};

    `ifdef PERF_ENABLE
        reg [VX_NUM_REGS-1:0][VX_EX_WIDTH-1:0] inuse_units;
        reg [VX_NUM_REGS-1:0][VX_SFU_WIDTH-1:0] inuse_sfu;

        always @(*) begin
            perf_inuse_units_per_cycle[w] = '0;
            perf_inuse_sfu_per_cycle[w] = '0;
            for (integer i = 0; i < NUM_OPDS; ++i) begin
                if (staging_if[w].vld && operands_busy[i]) begin
                    perf_inuse_units_per_cycle[w][inuse_units[stg_opds[i]]] = 1;
                    if (inuse_units[stg_opds[i]] == `EX_SFU) begin
                        perf_inuse_sfu_per_cycle[w][inuse_sfu[stg_opds[i]]] = 1;
                    end
                end
            end
        end
    `endif

        always @(*) begin
            for (integer i = 0; i < NUM_OPDS; ++i) begin
                operands_busy_n[i] = operands_busy[i];
                if (ibuffer_fire) begin
                    operands_busy_n[i] = inuse_regs[ibuf_opds[i]];
                end
                if (writeback_fire) begin
                    if (ibuffer_fire) begin
                        if (writeback_if.data.rd == ibuf_opds[i]) begin
                            operands_busy_n[i] = 0;
                        end
                    end else begin
                        if (writeback_if.data.rd == stg_opds[i]) begin
                            operands_busy_n[i] = 0;
                       end
                    end
                end
                if (staging_fire && staging_if[w].data.wb && staging_if[w].data.rd == ibuf_opds[i]) begin
                    operands_busy_n[i] = 1;
                end
            end
        end

        always @(posedge clk_i) begin
            if (rst_i) begin
                inuse_regs <= '0;
            end else begin
                if (writeback_fire) begin
                    inuse_regs[writeback_if.data.rd] <= 0;
                end
                if (staging_fire && staging_if[w].data.wb) begin
                    inuse_regs[staging_if[w].data.rd] <= 1;
                end
            end
            operands_busy <= operands_busy_n;
            operands_rdy[w] <= ~(| operands_busy_n);
        `ifdef PERF_ENABLE
            if (staging_fire && staging_if[w].data.wb) begin
                inuse_units[staging_if[w].data.rd] <= staging_if[w].data.ex_type;
                if (staging_if[w].data.ex_type == `EX_SFU) begin
                    inuse_sfu[staging_if[w].data.rd] <= op_to_sfu_type(staging_if[w].data.op_type);
                end
            end
        `endif
        end

    `ifdef SIMULATION
        reg [31:0] timeout_ctr;

        always @(posedge clk_i) begin
            if (rst_i) begin
                timeout_ctr <= '0;
            end else begin
                if (staging_if[w].vld && ~staging_if[w].rdy) begin
                `ifdef DBG_TRACE_PIPELINE
                    `TRACE(4, ("%t: *** %s-stall: wid=%0d, PC=0x%0h, tmask=%b, cycles=%0d, inuse=%b (#%0d)\n",
                        $time, INSTANCE_ID, w, {staging_if[w].data.PC, 1'b0}, staging_if[w].data.tmask, timeout_ctr,
                        operands_busy, staging_if[w].data.uuid))
                `endif
                    timeout_ctr <= timeout_ctr + 1;
                end else if (ibuffer_fire) begin
                    timeout_ctr <= '0;
                end
            end
        end

        `RUNTIME_ASSERT((timeout_ctr < `STALL_TIMEOUT),
                        ("%t: *** %s timeout: wid=%0d, PC=0x%0h, tmask=%b, cycles=%0d, inuse=%b (#%0d)",
                            $time, INSTANCE_ID, w, {staging_if[w].data.PC, 1'b0}, staging_if[w].data.tmask, timeout_ctr,
                            operands_busy, staging_if[w].data.uuid))

        `RUNTIME_ASSERT(~writeback_fire || inuse_regs[writeback_if.data.rd] != 0,
            ("%t: *** %s invld writeback register: wid=%0d, PC=0x%0h, tmask=%b, rd=%0d (#%0d)",
                $time, INSTANCE_ID, w, {writeback_if.data.PC, 1'b0}, writeback_if.data.tmask, writeback_if.data.rd, writeback_if.data.uuid))
    `endif

    end

    wire [PER_ISSUE_WARPS_P-1:0] arb_vld_in;
    wire [PER_ISSUE_WARPS_P-1:0][DATAW-1:0] arb_data_in;
    wire [PER_ISSUE_WARPS_P-1:0] arb_rdy_in;

    for (genvar w = 0; w < PER_ISSUE_WARPS_P; ++w) begin : g_arb_data_in
        assign arb_vld_in[w] = staging_if[w].vld && operands_rdy[w];
        assign arb_data_in[w] = staging_if[w].data;
        assign staging_if[w].rdy = arb_rdy_in[w] && operands_rdy[w];
    end

    xrv_stream_arb #(
        .NUM_INPUTS_P   (PER_ISSUE_WARPS_P),
        .DATA_WIDTH_P   (DATAW),
        .ARBITER_TYPE_P ("C"),
        .OUT_BUF        (3)
    ) out_arb (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .vld_i  (arb_vld_in),
        .rdy_i  (arb_rdy_in),
        .data_i (arb_data_in),
        .data_o ({
            scoreboard_if.data.uuid,
            scoreboard_if.data.tmask,
            scoreboard_if.data.PC,
            scoreboard_if.data.ex_type,
            scoreboard_if.data.op_type,
            scoreboard_if.data.op_args,
            scoreboard_if.data.wb,
            scoreboard_if.data.rd,
            scoreboard_if.data.rs1,
            scoreboard_if.data.rs2,
            scoreboard_if.data.rs3
        }),
        .vld_o  (scoreboard_if.vld),
        .rdy_o  (scoreboard_if.rdy),
        .sel_o  (scoreboard_if.data.wis)
    );

endmodule
