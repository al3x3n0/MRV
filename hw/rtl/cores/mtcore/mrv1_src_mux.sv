module mrv1_src_mux #(
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32
) (
    input xrv_exe_src0_sel_e            src0_sel_i,
    input xrv_exe_src1_sel_e            src1_sel_i,
    input logic [DATA_WIDTH_P-1:0]      rs0_data_i,
    input logic [DATA_WIDTH_P-1:0]      rs1_data_i,
    input logic [DATA_WIDTH_P-1:0]      insn_imm0_i,
    input logic [DATA_WIDTH_P-1:0]      insn_imm1_i,
    input logic [PC_WIDTH_P-1:0]        insn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]     src0_data_o,
    output logic [DATA_WIDTH_P-1:0]     src1_data_o,
    output logic [DATA_WIDTH_P-1:0]     src2_data_o
);

    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        // SRC0 Muxing
        ////////////////////////////////////////////////////////////////////////////////
        case (src0_sel_i)
            XRV_SRC0_RS0:   src0_data_o = rs0_data_i;
            XRV_SRC0_RS1:   src0_data_o = rs1_data_i;
            XRV_SRC0_PC:    src0_data_o = insn_pc_i;
            XRV_SRC0_IMM:   src0_data_o = insn_imm0_i;
            default:        src0_data_o = rs0_data_i;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
        // SRC1 Muxing
        ////////////////////////////////////////////////////////////////////////////////
        case (src1_sel_i)
            XRV_SRC1_RS0:   src1_data_o = rs0_data_i;
            XRV_SRC1_RS1:   src1_data_o = rs1_data_i;
            XRV_SRC1_IMM:   src1_data_o = insn_imm1_i;
            default:        src1_data_o = rs0_data_i;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
        // SRC2
        ////////////////////////////////////////////////////////////////////////////////
        assign src2_data_o = rs1_data_i;
    end

endmodule   
