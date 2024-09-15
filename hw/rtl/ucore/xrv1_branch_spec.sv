import xrv1_pkg::*;

module xrv1_branch_spec
(
    ////////////////////////////////////////////////////////////////////////////////
    input logic [31:0]              insn_i,
    input logic [31:0]              insn_pc_i,
    input logic                     insn_rv16_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                    spec_pc_vld_o,
    output logic [31:0]             spec_pc_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    wire c01_w              = insn_i[1:0] == 2'b01;
    wire [2:0] rv16_func3_w = insn_i[15:13];
    ////////////////////////////////////////////////////////////////////////////////
    wire rv16_beqz_w = c01_w & rv16_func3_w == 3'b110;
    wire rv16_bnez_w = c01_w & rv16_func3_w == 3'b111;
    wire rv16_jal_w  = c01_w & rv16_func3_w == 3'b001;
    wire rv16_j_w    = c01_w & rv16_func3_w == 3'b101;
    ////////////////////////////////////////////////////////////////////////////////
    wire [6:0] opcode_w = insn_i[6:0];
    ////////////////////////////////////////////////////////////////////////////////
    wire rv16_is_branch_w = rv16_beqz_w | rv16_bnez_w;
    wire rv16_is_jump_w   = rv16_jal_w | rv16_j_w;
    wire rv32_is_branch_w = opcode_w == {XRV_BRANCH, 2'b11};
    wire rv32_is_jump_w   = opcode_w == {XRV_JAL,    2'b11};
    ////////////////////////////////////////////////////////////////////////////////
    wire rv16_spec_pc_vld_w = rv16_is_branch_w | rv16_is_jump_w;
    wire rv32_spec_pc_vld_w = rv32_is_branch_w | rv32_is_jump_w;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] imm_cj_type_w = {
        {20{insn_i[12]}},
        insn_i[12],
        insn_i[8],
        insn_i[10:9],
        insn_i[6],
        insn_i[7],
        insn_i[2],
        insn_i[11],
        insn_i[5:3],
        1'b0
    };
    wire [31:0] imm_cb_type_w = {
        {23{insn_i[12]}},
        insn_i[12],
        insn_i[6:5],
        insn_i[2],
        insn_i[11:10],
        insn_i[4:3],
        1'b0
    };
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] imm_b_type_w = {
        {19{insn_i[31]}},
        insn_i[31],
        insn_i[7],
        insn_i[30:25],
        insn_i[11:8],
        1'b0
    };
    wire [31:0] imm_j_type_w = {
        {12{insn_i[31]}},
        insn_i[19:12],
        insn_i[20],
        insn_i[30:21],
        1'b0
    };
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] spec_branch_tgt_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (rv16_is_branch_w)
            spec_branch_tgt_r = insn_pc_i + imm_cb_type_w;
        else if (rv16_is_jump_w)
            spec_branch_tgt_r = insn_pc_i + imm_cj_type_w;
        else if (rv32_is_branch_w)
            spec_branch_tgt_r = insn_pc_i + imm_b_type_w;
        else if (rv32_is_jump_w)
            spec_branch_tgt_r = insn_pc_i + imm_j_type_w;
        else
            spec_branch_tgt_r = insn_pc_i + 'd4;
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign spec_pc_o = spec_branch_tgt_r;
    assign spec_pc_vld_o = (rv32_spec_pc_vld_w & ~insn_rv16_i) | rv16_spec_pc_vld_w;
    ////////////////////////////////////////////////////////////////////////////////

endmodule
