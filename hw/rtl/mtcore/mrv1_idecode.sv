module mrv1_idecode #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter NUM_FU_P = "inv",
    parameter FU_OPC_WIDTH_P = "inv",
    parameter rf_addr_width_p = 5
    ////////////////////////////////////////////////////////////////////////////////

) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        insn_vld_i,
    input  logic [31:0]                                 insn_i,
    input  logic [PC_WIDTH_P-1:0]                       insn_pc_i,
    input  logic [TID_WIDTH_LP-1:0]                     insn_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        insn_illegal_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dec_vld_o,
    output logic [PC_WIDTH_P-1:0]                       dec_pc_o,
    output logic [TID_WIDTH_LP-1:0]                     dec_tid_o,
    output logic [NUM_FU_P-1:0]                         dec_fu_req_o,
    output logic [FU_OPC_WIDTH_P-1:0]                   dec_fu_opc_o,
    ////////////////////////////////////////////////////////////////////////////////
    output xrv_exe_src0_sel_e                           dec_src0_sel_o,
    output xrv_exe_src1_sel_e                           dec_src1_sel_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]                     dec_imm0_o,
    output logic [DATA_WIDTH_P-1:0]                     dec_imm1_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dec_rs0_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rs0_addr_o,
    output logic                                        dec_rs1_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rs1_addr_o,
    output logic                                        dec_rd_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rd_addr_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dec_b_is_branch_o,
    outout logic                                        dec_b_is_jump_o
);
    ////////////////////////////////////////////////////////////////////////////////
    wire insn_is_rv16_w = insn_i[1:0] != 2'b11;
    logic [31:0]    rv16_insn_lo, insn_li;
    logic           rv16_insn_illegal_lo, insn_illegal_li;
    ////////////////////////////////////////////////////////////////////////////////
    xrv_rv16_expander rvc_expander_i (
        .insn_i             (insn_i),
        .insn_o             (rv16_insn_lo),
        .illegal_insn_o     (rv16_insn_illegal_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (insn_is_rv16_w) begin
            insn_li = rv16_insn_lo;
            insn_illegal_li = rv16_insn_illegal_lo;
        end else begin
            insn_li = insn_i;
            insn_illegal_li = 1'b0;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_idecoder #(
        .DATA_WIDTH_P               (DATA_WIDTH_P),
        .NUM_FU_P                   (NUM_FU_P),
        .FU_OPC_WIDTH_P             (FU_OPC_WIDTH_P),
        .rf_addr_width_p            (rf_addr_width_p)
    ) decoder_i (
        ////////////////////////////////////////////////////////////////////////////////
        .insn_vld_i                 (insn_vld_i),
        .insn_i                     (insn_li),
        .insn_pc_i                  (insn_pc_i),
        .insn_is_rv16_i             (insn_is_rv16_w),
        .insn_illegal_i             (insn_illegal_li),
        .insn_illegal_o             (insn_illegal_o),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_pc_o                   (dec_pc_o),
        .dec_fu_req_o               (dec_fu_req_o),
        .dec_fu_opc_o               (dec_fu_opc_o),
        .dec_src0_sel_o             (dec_src0_sel_o),
        .dec_src1_sel_o             (dec_src1_sel_o),
        .dec_imm0_o                 (dec_imm0_o),
        .dec_imm1_o                 (dec_imm1_o),
        .dec_rs0_vld_o              (dec_rs0_vld_o),
        .dec_rs0_addr_o             (dec_rs0_addr_o),
        .dec_rs1_vld_o              (dec_rs1_vld_o),
        .dec_rs1_addr_o             (dec_rs1_addr_o),
        .dec_rd_vld_o               (dec_rd_vld_o),
        .dec_rd_addr_o              (dec_rd_addr_o),
        .dec_b_is_branch_o          (dec_b_is_branch_o),
        .dec_b_is_jump_o            (dec_b_is_jump_o)
    );

    assign dec_tid_o = insn_tid_i;

endmodule