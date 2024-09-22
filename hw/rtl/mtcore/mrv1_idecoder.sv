import mrv1_pkg::*;
import xrv1_pkg::*;


module mrv1_idecoder
#(    
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter NUM_FU_P = "inv",
    parameter FU_OPC_WIDTH_P = "inv",
    parameter rf_addr_width_p = 5
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        insn_vld_i,
    input  logic [31:0]                                 insn_i,
    input  logic [PC_WIDTH_P-1:0]                       insn_pc_i,
    input  logic                                        insn_is_rv16_i,
    input  logic                                        insn_illegal_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        insn_illegal_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dec_vld_o,
    output logic [PC_WIDTH_P-1:0]                       dec_pc_o,
    output logic [NUM_FU_P-1:0]                         dec_fu_req_o,
    output logic [FU_OPC_WIDTH_P-1:0]                   dec_fu_opc_o,
    output xrv_exe_src0_sel_e                           dec_src0_sel_o,
    output xrv_exe_src1_sel_e                           dec_src1_sel_o,
    output logic [DATA_WIDTH_P-1:0]                     dec_imm0_o,
    output logic [DATA_WIDTH_P-1:0]                     dec_imm1_o,
    output logic                                        dec_rs0_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rs0_addr_o,
    output logic                                        dec_rs1_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rs1_addr_o,
    output logic                                        dec_rd_vld_o,
    output logic [rf_addr_width_p-1:0]                  dec_rd_addr_o,
    output logic                                        dec_b_is_branch_o,
    output logic                                        dec_b_is_jump_o
);
    ////////////////////////////////////////////////////////////////////////////////
    wire [6:0]  func7_w     = insn_i[31:25];
    wire [2:0]  func3_w     = insn_i[14:12];
    wire [4:0]  opcode_w    = insn_i[6:2];
    ////////////////////////////////////////////////////////////////////////////////
    wire dec_rs0_addr       = insn_i[19:15];
    wire dec_rs1_addr       = insn_i[24:20];
    wire dec_rd_addr        = insn_i[11:7];
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
            XRV_IMM0_Z:         dec_imm0_o = imm_z_type_w;
            XRV_IMM0_ZERO:      dec_imm0_o = 'd0;
            default:            dec_imm0_o = 'd0;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
        case (imm1_sel_r)
            XRV_IMM1_I:         dec_imm1_o = imm_i_type_w;
            XRV_IMM1_S:         dec_imm1_o = imm_s_type_w;
            XRV_IMM1_U:         dec_imm1_o = imm_u_type_w;
            default:            dec_imm1_o = imm_i_type_w;
        endcase
        ////////////////////////////////////////////////////////////////////////////////
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction decoding
    ////////////////////////////////////////////////////////////////////////////////
    logic lsu_w_en_r;
    logic [1:0] lsu_size_r;
    logic lsu_sign_r;

    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        dec_src0_sel_o          = XRV_SRC0_RS0;
        dec_src1_sel_o          = XRV_SRC1_RS1;
        imm1_sel_r              = XRV_IMM1_I;
        ////////////////////////////////////////////////////////////////////////////////
        dec_rs0_vld_o           = 1'b0;
        dec_rs1_vld_o           = 1'b0;
        dec_rd_vld_o            = 1'b1;
        ////////////////////////////////////////////////////////////////////////////////
        dec_fu_req_o            = 'b0;
        dec_fu_opc_o            = 'b0;
        dec_b_is_branch_o       = 'b0;
        dec_b_is_jump_o         = 'b0;
        lsu_w_en_r              = 'b0;
        lsu_size_r              = 'b0;
        lsu_sign_r              = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        insn_illegal_o          = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        case (opcode_w)
            ////////////////////////////////////////////////////////////////////////////////
            // ALU instructions
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LUI: begin
                dec_src0_sel_o = XRV_SRC0_IMM;
                dec_src1_sel_o = XRV_SRC1_IMM;
                imm0_sel_r = XRV_IMM0_ZERO;
                imm1_sel_r = XRV_IMM1_U;
                dec_fu_opc_o = MRV_INT_FU_ADD;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_AUIPC: begin
                dec_src0_sel_o = XRV_SRC0_PC;
                dec_src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_U;
                dec_fu_opc_o = MRV_INT_FU_ADD;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH_IMM: begin
                dec_src0_sel_o = XRV_SRC0_RS0;
                dec_src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_I;
                dec_rs0_vld_o = 1'b1;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
                case (func3_w)
                    3'b000: dec_fu_opc_o = MRV_INT_FU_ADD;
                    3'b010: dec_fu_opc_o = MRV_INT_FU_SLTS;
                    3'b011: dec_fu_opc_o = MRV_INT_FU_SLTU;
                    3'b100: dec_fu_opc_o = MRV_INT_FU_XOR;
                    3'b110: dec_fu_opc_o = MRV_INT_FU_OR;
                    3'b111: dec_fu_opc_o = MRV_INT_FU_AND;
                    3'b001: begin
                        dec_fu_opc_o = MRV_INT_FU_SLL;  // Shift Left Logical by Immediate
                        insn_illegal_o = func7_w != 7'b0;
                    end
                    3'b101: begin
                        if (func7_w == 7'b0)
                            dec_fu_opc_o = MRV_INT_FU_SRL;  // Shift Right Logical by Immediate
                        else if (func7_w == 7'b0100000)
                            dec_fu_opc_o = MRV_INT_FU_SRA;  // Shift Right Arithmetically by Immediate
                        else
                            insn_illegal_o = 1'b1;
                    end
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH: begin
                dec_rs0_vld_o = 1'b1;
                dec_rs1_vld_o = 1'b1;
                if (func7_w == 7'd0) begin
                    dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
                    case (func3_w)
                        3'b000: dec_fu_opc_o = MRV_INT_FU_ADD;
                        3'b001: dec_fu_opc_o = MRV_INT_FU_SLL;
                        3'b010: dec_fu_opc_o = MRV_INT_FU_SLTS;
                        3'b011: dec_fu_opc_o = MRV_INT_FU_SLTU;
                        3'b100: dec_fu_opc_o = MRV_INT_FU_XOR;
                        3'b101: dec_fu_opc_o = MRV_INT_FU_SRL;
                        3'b110: dec_fu_opc_o = MRV_INT_FU_OR;
                        3'b111: dec_fu_opc_o = MRV_INT_FU_AND;
                    endcase
                end
                else if (func7_w == 7'd32) begin
                    dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
                    if (func3_w == 3'b000)
                        dec_fu_opc_o = MRV_INT_FU_SUB;
                    else if (func3_w == 3'b101)
                        dec_fu_opc_o = MRV_INT_FU_SRA;
                    else
                        insn_illegal_o = 1'b1;
                end
                else if (func7_w == 7'd1) begin
                    if (func3_w[2]) begin
                        dec_fu_req_o[MRV_FU_TYPE_DIV] = 1'b1;
                        dec_fu_opc_o = func3_w[1:0];
                    end
                    else begin
                        dec_fu_req_o[MRV_FU_TYPE_MUL] = 1'b1;
                        dec_fu_opc_o = func3_w[1:0];
                    end
                end
                else begin
                    // FIXME ILLEGAL
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JAL: begin
                dec_b_is_jump_o  = 1'b1;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JALR: begin
                dec_rs0_vld_o = 1'b1;
                dec_b_is_jump_o = 1'b1;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_BRANCH: begin
                dec_rs0_vld_o = 1'b1;
                dec_rs1_vld_o = 1'b1;
                dec_rd_vld_o = 1'b0;
                dec_b_is_branch_o = 1'b1;
                dec_fu_req_o[MRV_FU_TYPE_INT] = 1'b1;
                case (func3_w)
                    3'b000: dec_fu_opc_o   = MRV_INT_FU_EQ;
                    3'b001: dec_fu_opc_o   = MRV_INT_FU_NE;
                    3'b100: dec_fu_opc_o   = MRV_INT_FU_LTS;
                    3'b101: dec_fu_opc_o   = MRV_INT_FU_GES;
                    3'b110: dec_fu_opc_o   = MRV_INT_FU_LTU;
                    3'b111: dec_fu_opc_o   = MRV_INT_FU_GEU;
                    default: dec_fu_opc_o  = MRV_INT_FU_EQ;
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LOAD: begin
                dec_rs0_vld_o = 1'b1;
                dec_src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_I;
                lsu_w_en_r = 1'b0;
                lsu_size_r = func3_w[1:0];
                lsu_sign_r = ~func3_w[2];
                dec_fu_req_o[MRV_FU_TYPE_MEM] = 1'b1;
                dec_fu_opc_o = {lsu_sign_r, lsu_size_r, lsu_w_en_r};
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_STORE: begin
                dec_rs0_vld_o = 1'b1;
                dec_rs1_vld_o = 1'b1;
                dec_rd_vld_o = 1'b0;
                dec_src1_sel_o = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_S;
                lsu_w_en_r = 1'b1;
                lsu_size_r = func3_w[1:0];
                dec_fu_req_o[MRV_FU_TYPE_MEM] = 1'b1;
                dec_fu_opc_o = {1'b0, lsu_size_r, lsu_w_en_r};
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_FENCE: begin
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_SYSTEM: begin
                if (insn_i[14:12] == 3'b000) begin
                end
                else begin
                    dec_fu_req_o[MRV_FU_TYPE_SYS] = 1'b1;
                    imm0_sel_r = XRV_IMM0_Z;
                    imm1_sel_r = XRV_IMM1_I;
                    dec_src0_sel_o = func3_w[2] ? XRV_SRC0_IMM : XRV_SRC0_RS0;
                    dec_rs0_vld_o  = ~func3_w[2];
                    if (func3_w[1:0] == 2'b01)
                        dec_fu_opc_o = XRV_CSR_WRITE;
                    else if (func3_w[1:0] == 2'b10 & ~rs0_x0_w)
                        dec_fu_opc_o = XRV_CSR_SET;
                    else if (func3_w[1:0] == 2'b11 & ~rs0_x0_w)
                        dec_fu_opc_o = XRV_CSR_CLR;
                    else
                        dec_fu_opc_o = XRV_CSR_READ;
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            default: insn_illegal_o = 1'b1;
        endcase
    end

    assign dec_vld_o = insn_vld_i;

endmodule
