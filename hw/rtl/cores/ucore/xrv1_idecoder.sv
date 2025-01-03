import xrv1_pkg::*;

module xrv_idecoder
#(
    parameter integer XRV_XLEN = 32,
    parameter integer DEBUG_LEVEL = 0,

    parameter bit XRV_HAS_M_EXT = 0,
    parameter bit XRV_HAS_A_EXT = 0,
    parameter bit XRV_HAS_F_EXT = 0,
    parameter bit XRV_HAS_D_EXT = 0,

    parameter bit XRV_HAS_ZICSR_EXT = 0,
    parameter bit XRV_HAS_ZIFENCEI_EXT = 0
) (
    ///////////////////////////////////////////////////////////////////////////
    // load/store logics
    // requires lsu
    output logic                                lsu_req_vld_o,
    // writes register in regfile
    output logic                                lsu_req_w_en_o,
    // size of operation
    output xrv_ls_data_size_e                   lsu_req_size_o,
    // is operation signed
    output logic                                lsu_req_signed_o,
    ///////////////////////////////////////////////////////////////////////////


    ///////////////////////////////////////////////////////////////////////////
    // regfile logics
    // rs0 is needed
    output logic                                rs0_vld_o,
    // rs1 is needed
    output logic                                rs1_vld_o,
    // rd is needed
    output logic                                rd_vld_o,
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // select
    xrv_exe_src0_sel_e src0_sel_o,
    xrv_exe_src1_sel_e src1_sel_o,
    xrv_imm0_sel_e     imm0_sel_o,
    xrv_imm1_sel_e     imm1_sel_o,
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // alu signals
    output logic [XRV_ALU_OP_WIDTH-1:0]         alu_opc_o,
    output logic                                alu_req_vld_o,
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // branch interface
    output logic                                b_req_vld_o,
    output logic                                b_is_branch_o,
    output logic                                b_is_jump_o,
    output logic                                j_pc_vld_o,
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    output logic                                mul_req_vld_o,
    output logic [1:0]                          mul_opc_o,
    output logic                                div_req_vld_o,
    output logic [1:0]                          div_opc_o,
    ///////////////////////////////////////////////////////////////////////////

    output logic                                insn_illegal_o,

    input logic [31:0]                          insn_i
);  
    rv_inst inst;
    assign inst = insn_i;

    always_comb begin
        lsu_req_vld_o    = 'b0;
        lsu_req_w_en_o   = 'b0;
        lsu_req_size_o   = LS_B;
        lsu_req_signed_o = 'b0;

        insn_illegal_o = 'b0;

        rs0_vld_o = 'b0;
        rs1_vld_o = 'b0;
        rd_vld_o  = 'b1;

        src0_sel_o = XRV_SRC0_RS0;
        src1_sel_o = XRV_SRC1_RS1;
        imm0_sel_o = XRV_IMM0_ZERO;
        imm1_sel_o = XRV_IMM1_I;

        alu_opc_o = 'b0;
        alu_req_vld_o = 'b0;

        b_req_vld_o = 'b0;
        b_is_branch_o = 'b0;
        b_is_jump_o = 'b0;
        j_pc_vld_o = 'b0;


        case (inst.r_type.opcode[6:2])

            XRV_LUI: begin
                src0_sel_o    = XRV_SRC0_IMM;
                src1_sel_o    = XRV_SRC1_IMM;
                imm0_sel_o    = XRV_IMM0_ZERO;
                imm1_sel_o    = XRV_IMM1_U;

                alu_req_vld_o = 1'b1;
                alu_opc_o     = XRV_ALU_ADD;
            end
            XRV_AUIPC: begin
                src0_sel_o    = XRV_SRC0_PC;
                src1_sel_o    = XRV_SRC1_IMM;
                imm1_sel_o    = XRV_IMM1_U;

                alu_req_vld_o = 1'b1;
                alu_opc_o     = XRV_ALU_ADD;
            end

            XRV_JAL: begin
                b_req_vld_o = 'b1;
                b_is_jump_o  = 1'b1;
            end
            XRV_JALR: begin
                b_req_vld_o = 'b1;
                b_is_jump_o = 'b1;
                j_pc_vld_o  = 'b1;

                rs0_vld_o   = 'b1;
                src0_sel_o = XRV_SRC0_RS0;
            end

            XRV_BRANCH: begin
                rs0_vld_o     = 1'b1;
                rs1_vld_o     = 1'b1;
                rd_vld_o      = 1'b0;

                b_req_vld_o   = 1'b1;
                b_is_branch_o = 1'b1;

                case (inst.b_type.funct3)
                    3'b000: alu_opc_o = XRV_ALU_EQ;
                    3'b001: alu_opc_o = XRV_ALU_NE;
                    3'b100: alu_opc_o = XRV_ALU_LTS;
                    3'b101: alu_opc_o = XRV_ALU_GES;
                    3'b110: alu_opc_o = XRV_ALU_LTU;
                    3'b111: alu_opc_o = XRV_ALU_GEU;
                    default: alu_opc_o = XRV_ALU_EQ;
                endcase
            end

            XRV_LOAD: begin
                lsu_req_vld_o = 'b1;
                case (inst.i_type.funct3[1:0])
                    LS_B: lsu_req_size_o = LS_B;
                    LS_H: lsu_req_size_o = LS_H;
                    LS_W: lsu_req_size_o = LS_W;
                    LS_D: begin
                        if (XRV_XLEN == 64) begin
                            lsu_req_size_o = LS_D;
                        end else begin
                            insn_illegal_o = 'b1;
                        end
                    end
                endcase
                lsu_req_signed_o = ~inst.i_type.funct3[2];
                rs0_vld_o = 'b1;
                src0_sel_o = XRV_SRC0_RS0;
                imm0_sel_o = XRV_IMM0_ZERO;
                src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_o = XRV_IMM1_I;
            end
            XRV_STORE: begin
                lsu_req_vld_o = 'b1;
                lsu_req_w_en_o = 'b1;
                case (inst.s_type.funct3[1:0])
                    LS_B: lsu_req_size_o = LS_B;
                    LS_H: lsu_req_size_o = LS_H;
                    LS_W: lsu_req_size_o = LS_W;
                    LS_D: begin
                        if (XRV_XLEN == 64) begin
                            lsu_req_size_o = LS_D;
                        end else begin
                            insn_illegal_o = 'b1;
                        end
                    end
                endcase
                rs0_vld_o = 'b1;
                rs1_vld_o = 'b1;
                rd_vld_o  = 'b0;
                src0_sel_o = XRV_SRC0_RS0;
                imm0_sel_o = XRV_IMM0_ZERO;
                src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_o = XRV_IMM1_S;
            end
            
            XRV_ARITH_IMM: begin
                rs0_vld_o = 'b1;
                rs1_vld_o = 'b0;
                rd_vld_o  = 'b1;

                src0_sel_o = XRV_SRC0_RS0;
                imm0_sel_o = XRV_IMM0_ZERO;
                src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_o = XRV_IMM1_I;

                alu_req_vld_o = 'b1;

                case (inst.i_type.funct3)
                    XRV_ALU_FUNCT_3_ADD:  alu_opc_o = XRV_ALU_ADD;
                    XRV_ALU_FUNCT_3_SLL: begin
                        alu_opc_o = XRV_ALU_SLL;
                        if (XRV_XLEN == 64) begin
                            insn_illegal_o = (inst.r_type.funct7[6:1] != 6'b0);
                        end else begin
                            insn_illegal_o = (inst.r_type.funct7 != 7'b0);
                        end
                    end
                    XRV_ALU_FUNCT_3_SLT:  alu_opc_o = XRV_ALU_SLTS;
                    XRV_ALU_FUNCT_3_SLTU: alu_opc_o = XRV_ALU_SLTU;
                    XRV_ALU_FUNCT_3_XOR:  alu_opc_o = XRV_ALU_XOR;
                    XRV_ALU_FUNCT_3_SRL: begin
                        case (inst.r_type.funct7)
                            XRV_ALU_FUNCT_7_ORDINARY_OP: alu_opc_o = XRV_ALU_SRL;
                            XRV_ALU_FUNCT_7_REVERSE_OP:  alu_opc_o = XRV_ALU_SRA;
                            default: insn_illegal_o = 'b1;
                        endcase
                    end
                    XRV_ALU_FUNCT_3_OR:   alu_opc_o = XRV_ALU_OR;
                    XRV_ALU_FUNCT_3_AND:  alu_opc_o = XRV_ALU_AND;
                endcase
            end

            XRV_ARITH: begin
                rs0_vld_o = 'b1;
                rs1_vld_o = 'b1;
                rd_vld_o  = 'b1;

                src0_sel_o = XRV_SRC0_RS0;
                imm0_sel_o = XRV_IMM0_ZERO;
                src1_sel_o = XRV_SRC1_RS1;
                imm1_sel_o = XRV_IMM1_I;

                alu_req_vld_o = 'b1;

                if (inst.r_type.funct7 == XRV_ALU_FUNCT_7_ORDINARY_OP) begin
                    case (inst.r_type.funct3)
                        XRV_ALU_FUNCT_3_ADD:  alu_opc_o = XRV_ALU_ADD;
                        XRV_ALU_FUNCT_3_SLL:  alu_opc_o = XRV_ALU_SLL;
                        XRV_ALU_FUNCT_3_SLT:  alu_opc_o = XRV_ALU_SLTS;
                        XRV_ALU_FUNCT_3_SLTU: alu_opc_o = XRV_ALU_SLTU;
                        XRV_ALU_FUNCT_3_XOR:  alu_opc_o = XRV_ALU_XOR;
                        XRV_ALU_FUNCT_3_SRL:  alu_opc_o = XRV_ALU_SRL;
                        XRV_ALU_FUNCT_3_OR:   alu_opc_o = XRV_ALU_OR;
                        XRV_ALU_FUNCT_3_AND:  alu_opc_o = XRV_ALU_AND;
                    endcase
                end
                else if (inst.r_type.funct7 == XRV_ALU_FUNCT_7_REVERSE_OP) begin
                    case (inst.r_type.funct3)
                        XRV_ALU_FUNCT_3_ADD: alu_opc_o = XRV_ALU_SUB;
                        XRV_ALU_FUNCT_3_SRL: alu_opc_o = XRV_ALU_SRA;
                        default: insn_illegal_o = 'b1;
                    endcase
                end
                else if (inst.r_type.funct7 == XRV_ALU_FUNCT_7_MUL_DIV_OP) begin
                    if (XRV_HAS_M_EXT == 1) begin
                        if (inst.r_type.funct3[2]) begin
                            div_req_vld_o = 1'b1;
                            div_opc_o     = inst.r_type.funct3[1:0];
                        end
                        else begin
                            mul_req_vld_o = 1'b1;
                            mul_opc_o     = inst.r_type.funct3[1:0];
                        end
                    end else begin
                        insn_illegal_o = 'b1;
                    end
                end else begin
                    insn_illegal_o = 'b1;
                end
            end
            
            XRV_FENCE: begin
                rs0_vld_o = 1'b1;
                rs1_vld_o = 1'b1;

                alu_req_vld_o = 1'b1;
                alu_opc_o = XRV_ALU_ADD;
                src0_sel_o = XRV_SRC0_RS0;
                imm0_sel_o = XRV_IMM0_ZERO;
                src1_sel_o = XRV_SRC1_RS1;
                imm1_sel_o = XRV_IMM1_I;
            end
            
            XRV_SYSTEM: begin
                if (insn_i[14:12] == 3'b000) begin
`ifdef SIM_ENABLED
                    // For now we will finish simulation on any system instruction
                    // with funct3 == 0
                    $finish;
`endif
                end
            end

            XRV_AMO: begin
                if (XRV_HAS_A_EXT == 1) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end

            XRV_ARITH_64: begin
                if (XRV_XLEN == 64) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end
            XRV_ARITH_64_IMM: begin
                if (XRV_XLEN == 64) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end
            
            XRV_LOAD_FP: begin
                if (XRV_HAS_F_EXT == 1) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end
            XRV_STORE_FP: begin
                if (XRV_HAS_F_EXT == 1) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end
            XRV_ARITH_FP: begin
                if (XRV_HAS_F_EXT == 1) begin
                end else begin
                    insn_illegal_o = 'b1;
                end
            end

            default: begin
                insn_illegal_o = 'b1;
            end

        endcase
    end
endmodule