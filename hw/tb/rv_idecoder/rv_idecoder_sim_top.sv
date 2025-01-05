import xrv1_pkg::*;

module rv_idecoder_sim_top #(
    parameter integer DEBUG_LEVEL = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter RV_XLEN = 32,
    ////////////////////////////////////////////////////////////////////////////////
    parameter bit RV_HAS_M_EXT = 0,
    parameter bit RV_HAS_A_EXT = 0,
    parameter bit RV_HAS_F_EXT = 0,
    parameter bit RV_HAS_D_EXT = 0,

    parameter bit RV_HAS_ZICSR_EXT = 0,
    parameter bit RV_HAS_ZIFENCEI_EXT = 0
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    input logic [31:0]                          inst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                lsu_req_vld_o,
    output logic                                lsu_req_w_en_o,
    output xrv_ls_data_size_e                   lsu_req_size_o,
    output logic                                lsu_req_signed_o,
    output logic                                rs0_vld_o,
    output logic                                rs1_vld_o,
    output logic                                rd_vld_o,
    output xrv_exe_src0_sel_e                   src0_sel_o,
    output xrv_exe_src1_sel_e                   src1_sel_o,
    output xrv_imm0_sel_e                       imm0_sel_o,
    output xrv_imm1_sel_e                       imm1_sel_o,
    output logic [XRV_ALU_OP_WIDTH-1:0]         alu_opc_o,
    output logic                                alu_req_vld_o,
    output logic                                b_req_vld_o,
    output logic                                b_is_branch_o,
    output logic                                b_is_jump_o,
    output logic                                j_pc_vld_o,
    output logic                                mul_req_vld_o,
    output logic [1:0]                          mul_opc_o,
    output logic                                div_req_vld_o,
    output logic [1:0]                          div_opc_o,
    output logic                                insn_illegal_o
);
    generate
        if (DEBUG_LEVEL > 0) initial begin
            $display("RV instruction decoder configured with: \
                     \tDEBUG LEVEL         %4d \
                     \tRV_XLEN             %4d \
                     \tRV_HAS_M_EXT        %4d \
                     \tRV_HAS_A_EXT        %4d \
                     \tRV_HAS_F_EXT        %4d \
                     \tRV_HAS_D_EXT        %4d \
                     \tRV_HAS_ZICSR_EXT    %4d \
                     \tRV_HAS_ZIFENCEI_EXT %4d",
                     DEBUG_LEVEL, RV_XLEN, RV_HAS_M_EXT,
                     RV_HAS_A_EXT, RV_HAS_F_EXT, RV_HAS_D_EXT,
                     RV_HAS_ZICSR_EXT, RV_HAS_ZIFENCEI_EXT);
        end
    endgenerate

    xrv_idecoder #(
        .DEBUG_LEVEL(DEBUG_LEVEL),
        .XRV_XLEN(RV_XLEN),
        .XRV_HAS_M_EXT(RV_HAS_M_EXT),
        .XRV_HAS_A_EXT(RV_HAS_A_EXT),
        .XRV_HAS_F_EXT(RV_HAS_F_EXT),
        .XRV_HAS_D_EXT(RV_HAS_D_EXT),
        .XRV_HAS_ZICSR_EXT(RV_HAS_ZICSR_EXT),
        .XRV_HAS_ZIFENCEI_EXT(RV_HAS_ZIFENCEI_EXT)
    ) decoder (
        .lsu_req_vld_o(lsu_req_vld_o),
        .lsu_req_w_en_o(lsu_req_w_en_o),
        .lsu_req_size_o(lsu_req_size_o),
        .lsu_req_signed_o(lsu_req_signed_o),

        .rs0_vld_o(rs0_vld_o),
        .rs1_vld_o(rs1_vld_o),
        .rd_vld_o(rd_vld_o),

        .src0_sel_o(src0_sel_o),
        .src1_sel_o(src1_sel_o),
        .imm0_sel_o(imm0_sel_o),
        .imm1_sel_o(imm1_sel_o),

        .alu_opc_o(alu_opc_o),
        .alu_req_vld_o(alu_req_vld_o),

        .b_req_vld_o(b_req_vld_o),
        .b_is_branch_o(b_is_branch_o),
        .b_is_jump_o(b_is_jump_o),
        .j_pc_vld_o(j_pc_vld_o),
        .mul_req_vld_o(mul_req_vld_o),
        .mul_opc_o(mul_opc_o),
        .div_req_vld_o(div_req_vld_o),
        .div_opc_o(div_opc_o),
        .insn_illegal_o(insn_illegal_o),

        .insn_i(inst_i)
    );

export "DPI-C" task check_m_ext_enabled;
task check_m_ext_enabled
(
    output byte valid
);
    valid = {7'b0, decoder.XRV_HAS_M_EXT};
endtask

endmodule
