module mrv1_idecode #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter rf_addr_width_p = 5
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        insn_vld_i,
    input  logic [31:0]                                 insn_i,
    input  logic [31:0]                                 insn_pc_i,
    input  logic [twid_width_lp-1:0]                    insn_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        insn_illegal_o,
    output logic [31:0]                                 insn_next_pc_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dec_vld_o,
    output logic [31:0]                                 dec_pc_o,
    output logic [wid_width_lp-1:0]                     dec_twid_o,
    output mrv_fu_type_e                                dec_fu_type_o,
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
    output logic [rf_addr_width_p-1:0]                  dec_rd_addr_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    wire insn_is_rv16_w = insn_i[1:0] != 2'b11;
    ////////////////////////////////////////////////////////////////////////////////
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
    xrv_rv_idecoder #(
        .rf_addr_width_p            (rf_addr_width_p)
    ) decoder_i (
        ////////////////////////////////////////////////////////////////////////////////
        .insn_vld_i                 (insn_vld_i),
        .insn_i                     (insn_li),
        .insn_pc_i                  (insn_pc_i),
        .insn_twid_i                (insn_twid_i),
        .insn_is_rv16_i             (insn_is_rv16_w),
        .insn_illegal_i             (insn_illegal_li),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_illegal_o             (insn_illegal_o),
        .insn_next_pc_o             (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_pc_o                   (dec_pc_o),
        .dec_twid_o                 (dec_twid_o),
        .dec_fu_type_o              (dec_fu_type_o),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_src0_sel_o             (dec_src0_sel_o),
        .dec_src1_sel_o             (dec_src1_sel_o),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_imm0_o                 (dec_imm0_o),
        .dec_imm1_o                 (dec_imm1_o),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_rs0_vld_o              (dec_rs0_vld_o),
        .dec_rs0_addr_o             (dec_rs0_addr_o),
        .dec_rs1_vld_o              (dec_rs1_vld_o),
        .dec_rs1_addr_o             (dec_rs1_addr_o),
        .dec_rd_vld_o               (dec_rd_vld_o),
        .dec_rd_addr_o              (dec_rd_addr_o)
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule