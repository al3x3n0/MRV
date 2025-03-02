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

`define ASSIGN_BLOCKED_WID(dst, src, block_idx, block_size) \
    /* verilator lint_off GENUNNAMED */ \
    if (block_size != 1) begin \
        if (block_size != NUM_WARPS_P) begin \
            assign dst = {src[WID_WIDTH_P-1:`XM_CLOG2(block_size)], `XM_CLOG2(block_size)'(block_idx)}; \
        end else begin \
            assign dst = WID_WIDTH_P'(block_idx); \
        end \
    end else begin \
        assign dst = src; \
    end \
    /* verilator lint_on GENUNNAMED */

module xrv_vx_alu_int import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter BLOCK_IDX = 0,
    parameter NUM_LANES = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_ALU_BLOCKS_P      = "inv"
) (
    input wire              clk_i,
    input wire              rst_i,

    // Inputs
    xrv_vx_execute_if.slave     execute_if,

    // Outputs
    xrv_vx_commit_if.master     commit_if,
    xrv_vx_branch_ctl_if.master branch_ctl_if
);

    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam LANE_BITS      = `XM_CLOG2(NUM_LANES);
    localparam LANE_WIDTH     = `XM_UP(LANE_BITS);
    localparam PID_BITS       = `XM_CLOG2(NUM_THREADS_P / NUM_LANES);
    localparam PID_WIDTH      = `XM_UP(PID_BITS);
    localparam SHIFT_IMM_BITS = `XM_CLOG2(XLEN_P);

    `XM_UNUSED_VAR (execute_if.data.rs3_data)

    wire [NUM_LANES-1:0][XLEN_P-1:0] add_result;
    wire [NUM_LANES-1:0][XLEN_P:0]   sub_result; // +1 bit for branch compare
    reg  [NUM_LANES-1:0][XLEN_P-1:0] shr_zic_result;
    reg  [NUM_LANES-1:0][XLEN_P-1:0] msc_result;

    wire [NUM_LANES-1:0][XLEN_P-1:0] add_result_w;
    wire [NUM_LANES-1:0][XLEN_P-1:0] sub_result_w;
    wire [NUM_LANES-1:0][XLEN_P-1:0] shr_result_w;
    reg  [NUM_LANES-1:0][XLEN_P-1:0] msc_result_w;

    reg [NUM_LANES-1:0][XLEN_P-1:0] alu_result;
    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_result_r;

`ifdef XLEN_64
    wire is_alu_w = execute_if.data.op_args.alu.is_w;
`else
    wire is_alu_w = 0;
`endif

    wire [VX_INST_ALU_BITS-1:0] alu_op = VX_INST_ALU_BITS'(execute_if.data.op_type);
    wire [VX_INST_BR_BITS-1:0]   br_op = VX_INST_BR_BITS'(execute_if.data.op_type);
    wire                    is_br_op = (execute_if.data.op_args.alu.xtype == VX_ALU_TYPE_BRANCH);
    wire                   is_sub_op = `VX_INST_ALU_IS_SUB(alu_op);
    wire                   is_signed = `VX_INST_ALU_SIGNED(alu_op);
    wire [1:0]              op_class = is_br_op ? `VX_INST_BR_CLASS(alu_op) : `VX_INST_ALU_CLASS(alu_op);

    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_in1 = execute_if.data.rs1_data;
    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_in2 = execute_if.data.rs2_data;

    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_in1_PC  = execute_if.data.op_args.alu.use_PC ? {NUM_LANES{execute_if.data.PC, 1'd0}} : alu_in1;
    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_in2_imm = execute_if.data.op_args.alu.use_imm ? {NUM_LANES{`XM_SEXT(XLEN_P, execute_if.data.op_args.alu.imm)}} : alu_in2;
    wire [NUM_LANES-1:0][XLEN_P-1:0] alu_in2_br  = (execute_if.data.op_args.alu.use_imm && ~is_br_op) ? {NUM_LANES{`XM_SEXT(XLEN_P, execute_if.data.op_args.alu.imm)}} : alu_in2;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_add_result
        assign add_result[i] = alu_in1_PC[i] + alu_in2_imm[i];
        assign add_result_w[i] = XLEN_P'($signed(alu_in1[i][31:0] + alu_in2_imm[i][31:0]));
    end

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_sub_result
        wire [XLEN_P:0] sub_in1 = {is_signed & alu_in1[i][XLEN_P-1], alu_in1[i]};
        wire [XLEN_P:0] sub_in2 = {is_signed & alu_in2_br[i][XLEN_P-1], alu_in2_br[i]};
        assign sub_result[i] = sub_in1 - sub_in2;
        assign sub_result_w[i] = XLEN_P'($signed(alu_in1[i][31:0] - alu_in2_imm[i][31:0]));
    end

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_shr_result
        wire [XLEN_P:0] shr_in1 = {is_signed && alu_in1[i][XLEN_P-1], alu_in1[i]};
        always @(*) begin
            case (alu_op[1:0])
            `ifdef EXT_ZICOND_ENABLE
                2'b10, 2'b11: begin // CZERO
                    shr_zic_result[i] = alu_in1[i] & {XLEN_P{alu_op[0] ^ (| alu_in2[i])}};
                end
            `endif
                default: begin // SRL, SRA, SRLI, SRAI
                    shr_zic_result[i] = XLEN_P'($signed(shr_in1) >>> alu_in2_imm[i][SHIFT_IMM_BITS-1:0]);
                end
            endcase
        end
        wire [32:0] shr_in1_w = {is_signed && alu_in1[i][31], alu_in1[i][31:0]};
        wire [31:0] shr_res_w = 32'($signed(shr_in1_w) >>> alu_in2_imm[i][4:0]);
        assign shr_result_w[i] = XLEN_P'($signed(shr_res_w));
    end

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_msc_result
        always @(*) begin
            case (alu_op[1:0])
                2'b00: msc_result[i] = alu_in1[i] & alu_in2_imm[i]; // AND
                2'b01: msc_result[i] = alu_in1[i] | alu_in2_imm[i]; // OR
                2'b10: msc_result[i] = alu_in1[i] ^ alu_in2_imm[i]; // XOR
                2'b11: msc_result[i] = alu_in1[i] << alu_in2_imm[i][SHIFT_IMM_BITS-1:0]; // SLL
            endcase
        end
        assign msc_result_w[i] = XLEN_P'($signed(alu_in1[i][31:0] << alu_in2_imm[i][4:0])); // SLLW
    end

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_alu_result
        wire [XLEN_P-1:0] slt_br_result = XLEN_P'({is_br_op && ~(| sub_result[i][XLEN_P-1:0]), sub_result[i][XLEN_P]});
        wire [XLEN_P-1:0] sub_slt_br_result = (is_sub_op && ~is_br_op) ? sub_result[i][XLEN_P-1:0] : slt_br_result;
        always @(*) begin
            case ({is_alu_w, op_class})
                3'b000: alu_result[i] = add_result[i];      // ADD, LUI, AUIPC
                3'b001: alu_result[i] = sub_slt_br_result;  // SUB, SLTU, SLTI, BR*
                3'b010: alu_result[i] = shr_zic_result[i];  // SRL, SRA, SRLI, SRAI, CZERO*
                3'b011: alu_result[i] = msc_result[i];      // AND, OR, XOR, SLL, SLLI
                3'b100: alu_result[i] = add_result_w[i];    // ADDIW, ADDW
                3'b101: alu_result[i] = sub_result_w[i];    // SUBW
                3'b110: alu_result[i] = shr_result_w[i];    // SRLW, SRAW, SRLIW, SRAIW
                3'b111: alu_result[i] = msc_result_w[i];    // SLLW
            endcase
        end
    end

    // branch

    wire [PC_WIDTH_P-1:0] PC_r;
    wire [VX_INST_BR_BITS-1:0] br_op_r;
    wire [PC_WIDTH_P-1:0] cbr_dest, cbr_dest_r;
    wire [LANE_WIDTH-1:0] tid, tid_r;
    wire is_br_op_r;

    assign cbr_dest = add_result[0][1 +: PC_WIDTH_P];

    if (LANE_BITS != 0) begin : g_tid
        assign tid = execute_if.data.tid[0 +: LANE_BITS];
    end else begin : g_tid_0
        assign tid = 0;
    end

    xrv_elastic_buffer #(
        .DATA_WIDTH_P (UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + VX_NR_BITS + 1 + /*PID_WIDTH + 1 + 1 +*/ (NUM_LANES * XLEN_P) + PC_WIDTH_P + PC_WIDTH_P + 1 + VX_INST_BR_BITS + LANE_WIDTH)
    ) rsp_buf (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .vld_i  (execute_if.vld),
        .rdy_i  (execute_if.rdy),
        .data_i ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.rd, execute_if.data.wb, /*execute_if.data.pid, execute_if.data.sop, execute_if.data.eop,*/ alu_result, execute_if.data.PC, cbr_dest, is_br_op, br_op, tid}),
        .data_o ({commit_if.data.uuid, commit_if.data.wid, commit_if.data.tmask, commit_if.data.rd, commit_if.data.wb, /*commit_if.data.pid, commit_if.data.sop, commit_if.data.eop,*/ alu_result_r, PC_r, cbr_dest_r, is_br_op_r, br_op_r, tid_r}),
        .vld_o  (commit_if.vld),
        .rdy_o  (commit_if.rdy)
    );

    `XM_UNUSED_VAR (br_op_r)
    wire is_br_neg  = `VX_INST_BR_IS_NEG(br_op_r);
    wire is_br_less = `VX_INST_BR_IS_LESS(br_op_r);
    wire is_br_static = `VX_INST_BR_IS_STATIC(br_op_r);

    wire [XLEN_P-1:0] br_result = alu_result_r[tid_r];
    wire is_less  = br_result[0];
    wire is_equal = br_result[1];

    wire br_enable = is_br_op_r && commit_if.vld && commit_if.rdy/* && commit_if.data.eop*/;
    wire br_taken = ((is_br_less ? is_less : is_equal) ^ is_br_neg) | is_br_static;
    wire [PC_WIDTH_P-1:0] br_dest = is_br_static ? br_result[1 +: PC_WIDTH_P] : cbr_dest_r;
    wire [WID_WIDTH_P-1:0] br_wid;
    `ASSIGN_BLOCKED_WID (br_wid, commit_if.data.wid, BLOCK_IDX, NUM_ALU_BLOCKS_P)

    xrv_pipe_register #(
        .DATA_WIDTH_P (1 + WID_WIDTH_P + 1 + PC_WIDTH_P)
    ) branch_reg (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     ({br_enable,           br_wid,            br_taken,            br_dest}),
        .data_o     ({branch_ctl_if.vld, branch_ctl_if.wid, branch_ctl_if.taken, branch_ctl_if.dest})
    );

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_commit
        assign commit_if.data.data[i] = (is_br_op_r && is_br_static) ? {(PC_r + PC_WIDTH_P'(2)), 1'd0} : alu_result_r[i];
    end

    assign commit_if.data.PC = PC_r;

`ifdef DBG_TRACE_PIPELINE
    always @(posedge clk_i) begin
        if (br_enable) begin
            `TRACE(2, ("%t: %s branch: wid=%0d, PC=0x%0h, taken=%b, dest=0x%0h (#%0d)\n",
                $time, INSTANCE_ID, br_wid, {commit_if.data.PC, 1'b0}, br_taken, {br_dest, 1'b0}, commit_if.data.uuid))
        end
    end
`endif

endmodule
