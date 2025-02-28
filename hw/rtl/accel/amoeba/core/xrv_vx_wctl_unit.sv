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

module xrv_vx_wctl_unit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID       = "",
    parameter NUM_LANES_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P              = 1,
    parameter XLEN_P                    = 64,
    parameter PC_WIDTH_P                = XLEN_P - 1,
    parameter NUM_THREADS_P             = 4,
    parameter NUM_WARPS_P               = 4,
    parameter NUM_BARRIERS_P            = 4,
    parameter WID_WIDTH_P               = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P               = `XM_CLOG2(NUM_THREADS_P),
    parameter BAR_ID_WIDTH_P            = `XM_CLOG2(NUM_BARRIERS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DV_STACK_SIZE_P           = `XM_UP(NUM_THREADS_P-1),
    parameter DV_STACK_SIZE_WIDTH_P     = `XM_UP(`XM_CLOG2(DV_STACK_SIZE_P))
) (
    input wire              clk_i,
    input wire              rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_execute_if.slave     execute_if,
    xrv_vx_warp_ctl_if.master   warp_ctl_if,
    xrv_vx_commit_if.master     commit_if
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam LANE_BITS        = `XM_CLOG2(NUM_LANES_P);
    localparam TMC_BITS_LP      = 1 + NUM_THREADS_P;
    localparam WSPAWN_BITS_LP   = 1 + NUM_WARPS_P + PC_WIDTH_P;
    localparam SPLIT_BITS_LP    = 1 + 1 + NUM_THREADS_P + NUM_THREADS_P + PC_WIDTH_P;
    localparam JOIN_BITS_LP     = 1 + DV_STACK_SIZE_WIDTH_P;
    localparam BARRIER_BITS_LP  = 1 + BAR_ID_WIDTH_P + 1 + WID_WIDTH_P + 1; // FIXME
    localparam WCTL_WIDTH_LP    = TMC_BITS_LP + WSPAWN_BITS_LP + SPLIT_BITS_LP + JOIN_BITS_LP + BARRIER_BITS_LP;
    localparam DATA_WIDTH_P     = UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P + VX_NR_BITS + 1 + WCTL_WIDTH_LP + DV_STACK_SIZE_WIDTH_P;

    `XM_UNUSED_VAR (execute_if.data.rs3_data)

    logic tmc_vld, tmc_vld_r;
    logic [NUM_THREADS_P-1:0] tmc_tmask, tmc_tmask_r;

    logic wspawn_vld, wspawn_vld_r;
    logic [NUM_WARPS_P-1:0] wspawn_wmask, wspawn_wmask_r;
    logic [PC_WIDTH_P-1:0] wspawn_pc, wspawn_pc_r;

    logic split_vld, split_vld_r;
    logic split_is_dvg, split_is_dvg_r;
    logic [NUM_THREADS_P-1:0] split_then_tmask, split_then_tmask_r;
    logic [NUM_THREADS_P-1:0] split_else_tmask, split_else_tmask_r;
    logic [PC_WIDTH_P-1:0] split_next_pc, split_next_pc_r;

    logic sjoin_vld, sjoin_vld_r;
    logic [DV_STACK_SIZE_WIDTH_P-1:0] sjoin_stack_ptr, sjoin_stack_ptr_r;

    logic                   barrier_vld, barrier_vld_r;
    logic [BAR_ID_WIDTH_P-1:0] barrier_id, barrier_id_r;
    logic                   barrier_is_global, barrier_is_global_r;
`ifdef GBAR_ENABLE
    logic [`XM_MAX(WID_WIDTH_P, CORE_ID_WIDTH_P)-1:0] barrier_size_m1, barrier_size_m1_r;
`else
    logic [WID_WIDTH_P-1:0]   barrier_size_m1, barrier_size_m1_r;
`endif
    logic                   barrier_is_noop, barrier_is_noop_r;

    wire is_wspawn = (execute_if.data.op_type == VX_INST_SFU_WSPAWN);
    wire is_tmc    = (execute_if.data.op_type == VX_INST_SFU_TMC);
    wire is_pred   = (execute_if.data.op_type == VX_INST_SFU_PRED);
    wire is_split  = (execute_if.data.op_type == VX_INST_SFU_SPLIT);
    wire is_join   = (execute_if.data.op_type == VX_INST_SFU_JOIN);
    wire is_bar    = (execute_if.data.op_type == VX_INST_SFU_BAR);

    wire [`XM_UP(LANE_BITS)-1:0] tid;
    if (LANE_BITS != 0) begin : g_tid
        assign tid = execute_if.data.tid[0 +: LANE_BITS];
    end else begin : g_no_tid
        assign tid = 0;
    end

    wire [XLEN_P-1:0] rs1_data = execute_if.data.rs1_data[tid];
    wire [XLEN_P-1:0] rs2_data = execute_if.data.rs2_data[tid];
    `XM_UNUSED_VAR (rs1_data)

    wire not_pred = execute_if.data.op_args.wctl.is_neg;

    wire [NUM_LANES_P-1:0] taken;
    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_taken
        assign taken[i] = (execute_if.data.rs1_data[i][0] ^ not_pred);
    end

    reg [NUM_THREADS_P-1:0] then_tmask_r, then_tmask_n;
    reg [NUM_THREADS_P-1:0] else_tmask_r, else_tmask_n;
    always @(*) begin
        then_tmask_n = taken & execute_if.data.tmask;
        else_tmask_n = ~taken & execute_if.data.tmask;
    end
    always @(posedge clk_i) begin
        if (execute_if.vld) begin
            then_tmask_r <= then_tmask_n;
            else_tmask_r <= else_tmask_n;
        end
    end
    wire has_then = (then_tmask_n != 0);
    wire has_else = (else_tmask_n != 0);

    // tmc / pred

    wire [NUM_THREADS_P-1:0] pred_mask = has_then ? then_tmask_n : rs2_data[NUM_THREADS_P-1:0];
    assign tmc_vld = (is_tmc || is_pred);
    assign tmc_tmask = is_pred ? pred_mask : rs1_data[NUM_THREADS_P-1:0];

    // split

    wire [`XM_CLOG2(NUM_THREADS_P+1)-1:0] then_tmask_cnt, else_tmask_cnt;
    `POP_COUNT(then_tmask_cnt, then_tmask_n);
    `POP_COUNT(else_tmask_cnt, else_tmask_n);
    wire then_first = (then_tmask_cnt >= else_tmask_cnt);
    wire [NUM_THREADS_P-1:0] taken_tmask = then_first ? then_tmask_n : else_tmask_n;
    wire [NUM_THREADS_P-1:0] ntaken_tmask = then_first ? else_tmask_n : then_tmask_n;

    assign split_vld      = is_split;
    assign split_is_dvg     = has_then && has_else;
    assign split_then_tmask = taken_tmask;
    assign split_else_tmask = ntaken_tmask;
    assign split_next_pc    = execute_if.data.PC + PC_WIDTH_P'(2);

    assign warp_ctl_if.dvstack_wid = execute_if.data.wid;
    wire [DV_STACK_SIZE_WIDTH_P-1:0] dvstack_ptr;

    // join

    assign sjoin_vld      = is_join;
    assign sjoin_stack_ptr  = rs1_data[DV_STACK_SIZE_WIDTH_P-1:0];

    // barrier
    assign barrier_vld    = is_bar;
    assign barrier_id       = rs1_data[BAR_ID_WIDTH_P-1:0];
`ifdef GBAR_ENABLE
    assign barrier_is_global = rs1_data[31];
`else
    assign barrier_is_global = 1'b0;
`endif
    assign barrier_size_m1  = rs2_data[$bits(barrier_size_m1)-1:0] - $bits(barrier_size_m1)'(1);
    assign barrier_is_noop  = (rs2_data[$bits(barrier_size_m1)-1:0] == $bits(barrier_size_m1)'(1));

    // wspawn

    for (genvar i = 0; i < NUM_WARPS_P; ++i) begin : g_wspawn_wmask
        assign wspawn_wmask[i] = (i < rs1_data[WID_WIDTH_P:0]) && (i != execute_if.data.wid);
    end
    assign wspawn_vld = is_wspawn;
    assign wspawn_pc    = rs2_data[1 +: PC_WIDTH_P];

    // response

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (DATA_WIDTH_P),
        .SIZE_P         (2)
    ) rsp_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (execute_if.vld),
        .rdy_i      (execute_if.rdy),
        .data_i     ({
            execute_if.data.uuid,
            execute_if.data.wid,
            execute_if.data.tmask,
            execute_if.data.PC,
            execute_if.data.rd,
            execute_if.data.wb,
            {
                tmc_vld, tmc_tmask,
                wspawn_vld, wspawn_wmask, wspawn_pc,
                split_vld, split_is_dvg, split_then_tmask, split_else_tmask, split_next_pc,
                sjoin_vld, sjoin_stack_ptr,
                {
                    barrier_vld,
                    barrier_id,
                    barrier_is_global,
                    barrier_size_m1,
                    barrier_is_noop
                }
            },
            warp_ctl_if.dvstack_ptr}),
        .data_o     ({
            commit_if.data.uuid,
            commit_if.data.wid,
            commit_if.data.tmask,
            commit_if.data.PC,
            commit_if.data.rd,
            commit_if.data.wb,
            {
                tmc_vld_r, tmc_tmask_r,
                wspawn_vld_r, wspawn_wmask_r, wspawn_pc_r,
                split_vld_r, split_is_dvg_r, split_then_tmask_r, split_else_tmask_r, split_next_pc_r,
                sjoin_vld_r, sjoin_stack_ptr_r,
                {
                    barrier_vld_r,
                    barrier_id_r,
                    barrier_is_global_r,
                    barrier_size_m1_r,
                    barrier_is_noop_r
                }
            },
            dvstack_ptr}),
        .vld_o      (commit_if.vld),
        .rdy_o      (commit_if.rdy)
    );

    assign warp_ctl_if.vld              = commit_if.vld && commit_if.rdy;
    assign warp_ctl_if.wid              = commit_if.data.wid;
    assign warp_ctl_if.tmc_vld          = tmc_vld_r;
    assign warp_ctl_if.tmc_tmask        = tmc_tmask_r;
    assign warp_ctl_if.wspawn_vld       = wspawn_vld_r;
    assign warp_ctl_if.wspawn_wmask     = wspawn_wmask_r;
    assign warp_ctl_if.wspawn_pc        = wspawn_pc_r;
    assign warp_ctl_if.split_vld        = split_vld_r;
    assign warp_ctl_if.split_is_dvg     = split_is_dvg_r;
    assign warp_ctl_if.split_then_tmask = split_then_tmask_r;
    assign warp_ctl_if.split_else_tmask = split_else_tmask_r;
    assign warp_ctl_if.split_next_pc    = split_next_pc_r;    
    assign warp_ctl_if.sjoin_vld        = sjoin_vld_r;
    assign warp_ctl_if.sjoin_stack_ptr  = sjoin_stack_ptr_r;
    assign warp_ctl_if.barrier_vld      = barrier_vld_r;
    assign warp_ctl_if.barrier_id       = barrier_id_r;
    assign warp_ctl_if.barrier_is_global = barrier_is_global_r;
    assign warp_ctl_if.barrier_size_m1  = barrier_size_m1_r;
    assign warp_ctl_if.barrier_is_noop  = barrier_is_noop_r;

    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_commit_if
        assign commit_if.data.data[i] = XLEN_P'(dvstack_ptr);
    end

endmodule
