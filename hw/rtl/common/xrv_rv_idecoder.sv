import mrv1_pkg::*;

module xrv_rv_idecoder
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_TW_P = 8,
    parameter rf_addr_width_p = 5,
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        insn_vld_i,
    input  logic [31:0]                                 insn_i,
    input  logic [31:0]                                 insn_pc_i,
    input  logic [twid_width_lp-1:0]                    insn_twid_i,
    input  logic                                        insn_is_rv16_i,
    input  logic                                        insn_illegal_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        insn_illegal_o,
    output logic [31:0]                                 insn_next_pc_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [31:0]                                 dec_pc_o,
    output logic [wid_width_lp-1:0]                     dec_twid_o,
    ////////////////////////////////////////////////////////////////////////////////
    output mrv_fu_type_e                                dec_fu_type_o,
    ////////////////////////////////////////////////////////////////////////////////
    output xrv_exe_src0_sel_e                           dec_src0_sel_o,
    output xrv_exe_src1_sel_e                           dec_src1_sel_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [data_width_p-1:0]                     dec_imm0_o,
    output logic [data_width_p-1:0]                     dec_imm1_o,
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
    wire [6:0]  func7_w         = insn_i[31:25];
    wire [2:0]  func3_w         = insn_i[14:12];
    wire [4:0]  opcode_w        = insn_i[6:2];
    ////////////////////////////////////////////////////////////////////////////////
    assign dec_rs0_addr     = insn_i[19:15];
    assign dec_rs1_addr     = insn_i[24:20];
    assign dec_rd_addr      = insn_i[11:7];
    ////////////////////////////////////////////////////////////////////////////////
    wire rs0_x0_w = dec_rs0_addr == '0;
    wire rs1_x0_w = dec_rs1_addr == '0;
    ////////////////////////////////////////////////////////////////////////////////
    // Immediate decoding
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] imm_i_type_w = {{20 {insn_i[31]}}, insn_i[31:20]};
    wire [31:0] imm_z_type_w = {20'b0, insn_i[31:20]};
    wire [31:0] imm_s_type_w = {{20 {insn_i[31]}}, insn_i[31:25], insn_i[11:7]};
    wire [31:0] imm_b_type_w = {{19 {insn_i[31]}}, insn_i[31], insn_i[7], insn_i[30:25], insn_i[11:8], 1'b0};
    wire [31:0] imm_u_type_w = {insn_i[31:12], 12'b0};
    wire [31:0] imm_j_type_w = {{12{insn_i[31]}}, insn_i[19:12], insn_i[20], insn_i[30:21], 1'b0};
    ////////////////////////////////////////////////////////////////////////////////
    xrv_imm0_sel_e      imm0_sel_r;
    xrv_imm1_sel_e      imm1_sel_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        // Immediate muxing
        ////////////////////////////////////////////////////////////////////////////////
        case (imm0_sel_r)
            XRV_IMM0_Z:         dec_imm0 = imm_z_type_w;
            XRV_IMM0_ZERO:      dec_imm0 = 'd0;
            default:            dec_imm0 = 'd0;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
        case (imm1_sel_r)
            XRV_IMM1_I:         dec_imm1 = imm_i_type_w;
            XRV_IMM1_S:         dec_imm1 = imm_s_type_w;
            XRV_IMM1_U:         dec_imm1 = imm_u_type_w;
            default:            dec_imm1 = imm_i_type_w;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction decoding
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        dec.src0_sel_o          = XRV_SRC0_RS0;
        dec_src1_sel_o          = XRV_SRC1_RS1;
        dec_imm1_sel_o          = XRV_IMM1_I;
        ////////////////////////////////////////////////////////////////////////////////
        dec_rs0_vld_o_o         = 1'b0;
        dec_rs1_vld_o_o         = 1'b0;
        dec_rd_vld_o            = 1'b1;
        ////////////////////////////////////////////////////////////////////////////////
        dec_alu.req_o           = 1'b0;
        dec_alu_opc_o_o         = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        dec_b_is_branch_o       = 'b0;
        dec_b_is_jump_o         = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        dec_csr_opc_o           = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        dec_lsu_req_o           = 'b0;
        dec_lsu_w_en_o          = 'b0;
        dec_lsu_size_o          = 'b0;
        dec_lsu_sign_o          = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        dec_mul_req_o           = 'b0;
        dec_mul_opc_o           = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        dec_div_req_o           = 'b0;
        dec_div_opc_o           = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        insn_illegal_o          = 'b0;
        ////////////////////////////////////////////////////////////////////////////////

        case (opcode_w)
            ////////////////////////////////////////////////////////////////////////////////
            // ALU instructions
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LUI: begin
                dec_src0_sel_o      = XRV_SRC0_IMM;
                dec_src1_sel_o      = XRV_SRC1_IMM;
                imm0_sel_r          = XRV_IMM0_ZERO;
                imm1_sel_r          = XRV_IMM1_U;
                dec_alu_opc_o       = XRV_ALU_ADD;
                dec_fu_type_o       = MRV_FU_TYPE_ALU;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_AUIPC: begin
                dec_src0_sel        = XRV_SRC0_PC;
                dec_src1_sel        = XRV_SRC1_IMM;
                imm1_sel_r          = XRV_IMM1_U;
                dec_alu_opc_o       = XRV_ALU_ADD;
                dec_fu_type_o       = MRV_FU_TYPE_ALU;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH_IMM: begin
                dec_src0_sel        = XRV_SRC0_RS0;
                dec_src1_sel        = XRV_SRC1_IMM;
                imm1_sel_r          = XRV_IMM1_I;
                dec_rs0_vld_o       = 1'b1;
                dec_fu_type_o       = MRV_FU_TYPE_ALU;
                case (func3_w)
                    3'b000: dec_alu_opc_o = XRV_ALU_ADD;
                    3'b010: dec_alu_opc_o = XRV_ALU_SLTS;
                    3'b011: dec_alu_opc_o = XRV_ALU_SLTU;
                    3'b100: dec_alu_opc_o = XRV_ALU_XOR;
                    3'b110: dec_alu_opc_o = XRV_ALU_OR;
                    3'b111: dec_alu_opc_o = XRV_ALU_AND;
                    3'b001: begin
                        dec_alu_opc_o = XRV_ALU_SLL;  // Shift Left Logical by Immediate
                        insn_illegal_o = func7_w != 7'b0;
                    end
                    3'b101: begin
                        if (func7_w == 7'b0)
                            dec_alu_opc_o = XRV_ALU_SRL;  // Shift Right Logical by Immediate
                        else if (func7_w == 7'b0100000)
                            dec_alu_opc_o = XRV_ALU_SRA;  // Shift Right Arithmetically by Immediate
                        else
                            insn_illegal_o = 1'b1;
                    end
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH: begin
                ////////////////////////////////////////////////////////////////////////////////
                dec_rs0_vld_o = 1'b1;
                dec_rs1_vld_o = 1'b1;
                dec_fu_type_o = MRV_FU_TYPE_ALU;
                ////////////////////////////////////////////////////////////////////////////////
                if (func7_w == 7'd0) begin
                    case (func3_w)
                        3'b000: dec_alu_opc_o = XRV_ALU_ADD;
                        3'b001: dec_alu_opc_o = XRV_ALU_SLL;
                        3'b010: dec_alu_opc_o = XRV_ALU_SLTS;
                        3'b011: dec_alu_opc_o = XRV_ALU_SLTU;
                        3'b100: dec_alu_opc_o = XRV_ALU_XOR;
                        3'b101: dec_alu_opc_o = XRV_ALU_SRL;
                        3'b110: dec_alu_opc_o = XRV_ALU_OR;
                        3'b111: dec_alu_opc_o = XRV_ALU_AND;
                    endcase
                end
                else if (func7_w == 7'd32) begin
                    if (func3_w == 3'b000)
                        dec_alu_opc_o = XRV_ALU_SUB;
                    else if (func3_w == 3'b101)
                        dec_alu_opc_o = XRV_ALU_SRA;
                    else
                        insn_illegal_o = 1'b1;
                end
                else if (func7_w == 7'd1) begin
                    if (func3_w[2]) begin
                        dec_div_req = 1'b1;
                        dec_div_opc     = func3_w[1:0];
                    end
                    else begin
                        dec_mul_req_o = 1'b1;
                        dec_mul_opc_o = func3_w[1:0];
                    end
                end
                else begin
                    // FIXME ILLEGAL
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JAL: begin
                b_req_vld_o = 1'b1;
                dec_b_is_jump  = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JALR: begin
                dec_rs0_vld_o   = 1'b1;
                b_req_vld_o = 1'b1;
                dec_b_is_jump = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_BRANCH: begin
                dec_rs0_vld_o     = 1'b1;
                dec_rs1_vld_o     = 1'b1;
                dec_rd_vld      = 1'b0;
                b_req_vld_o   = 1'b1;
                dec_b_is_branch = 1'b1;
                ////////////////////////////////////////////////////////////////////////////////
                case (func3_w)
                    3'b000: dec_alu_opc_o   = XRV_ALU_EQ;
                    3'b001: dec_alu_opc_o   = XRV_ALU_NE;
                    3'b100: dec_alu_opc_o   = XRV_ALU_LTS;
                    3'b101: dec_alu_opc_o   = XRV_ALU_GES;
                    3'b110: dec_alu_opc_o   = XRV_ALU_LTU;
                    3'b111: dec_alu_opc_o   = XRV_ALU_GEU;
                    default: dec_alu_opc_o  = XRV_ALU_EQ;
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LOAD: begin
                ////////////////////////////////////////////////////////////////////////////////
                dec_rs0_vld_o   = 1'b1;
                dec_src1_sel    = XRV_SRC1_IMM;
                imm1_sel_r      = XRV_IMM1_I;
                dec_fu_type_o   = MRV_FU_TYPE_LSU;
                dec_lsu_w_en    = 1'b0;
                dec_lsu_size    = func3_w[1:0];
                dec_lsu_signed  = ~func3_w[2];
                ////////////////////////////////////////////////////////////////////////////////
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_STORE: begin
                ////////////////////////////////////////////////////////////////////////////////
                dec_rs0_vld_o   = 1'b1;
                dec_rs1_vld_o   = 1'b1;
                dec_rd_vld      = 1'b0;
                dec_src1_sel    = XRV_SRC1_IMM;
                imm1_sel_r      = XRV_IMM1_S;
                dec_fu_type_o   = MRV_FU_TYPE_LSU;
                dec_lsu_w_en    = 1'b1;
                dec_lsu_size    = func3_w[1:0];
                ////////////////////////////////////////////////////////////////////////////////
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_FENCE: begin
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_SYSTEM: begin
                if (insn_i[14:12] == 3'b000) begin
                end
                else begin
                    dec_fu_type_o = MRV_FU_TYPE_CSR;
                    imm0_sel_r = XRV_IMM0_Z;
                    imm1_sel_r = XRV_IMM1_I;
                    dec_src0_sel = func3_w[2] ? XRV_SRC0_IMM : XRV_SRC0_RS0;
                    dec_rs0_vld_o  = ~func3_w[2];
                    if (func3_w[1:0] == 2'b01)
                        dec_csr.opc = XRV_CSR_WRITE;
                    else if (func3_w[1:0] == 2'b10 & ~rs0_x0_w)
                        dec_csr.opc = XRV_CSR_SET;
                    else if (func3_w[1:0] == 2'b11 & ~rs0_x0_w)
                        dec_csr.opc = XRV_CSR_CLR;
                    else
                        dec_csr.opc = XRV_CSR_READ;
                    dec_csr.addr = insn_i[31:20];
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            default: insn_illegal_o = 1'b1;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////


endmodule

