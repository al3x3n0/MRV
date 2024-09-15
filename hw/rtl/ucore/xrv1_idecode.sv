import xrv1_pkg::*;

module xrv1_idecode
#(
    parameter rf_addr_width_p = 5,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 2,
    parameter num_rs_lp = 2
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // FETCH <-> DECODE interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                decode_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [31:0]                          insn_i,
    input logic [31:0]                          insn_pc_i,
    input logic                                 insn_vld_i,
    input logic                                 insn_is_rv16_i,
    input logic                                 insn_illegal_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                insn_illegal_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                j_pc_vld_o,
    output logic [31:0]                         j_pc_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [31:0]                         insn_next_pc_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 retire_vld_i,
    input logic                                 retire_rd_addr_vld_i,
    input logic [rf_addr_width_p-1:0]           retire_rd_addr_i,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE -> RF interface
    ////////////////////////////////////////////////////////////////////////////////
    // Read port 0
    ////////////////////////////////////////////////////////////////////////////////
    output logic [rf_addr_width_p-1:0]          rs0_addr_o,
    input logic [DATA_WIDTH_P-1:0]              rs0_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Read port 1
    ////////////////////////////////////////////////////////////////////////////////
    output logic [rf_addr_width_p-1:0]          rs1_addr_o,
    input logic [DATA_WIDTH_P-1:0]              rs1_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Write port 0
    ////////////////////////////////////////////////////////////////////////////////
    output logic [rf_addr_width_p-1:0]          rd_addr_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE -> Issue queue interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 issue_rdy_i,
    input logic [ITAG_WIDTH_P-1:0]              issue_itag_i,
    output logic                                issue_vld_o,
    input logic                                 exec_b_flush_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                rs0_vld_o,
    output logic                                rs1_vld_o,
    output logic                                rd_vld_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [num_rs_lp-1:0]                 rs_conflict_i,
    input logic                                 rs0_byp_en_i,
    input logic                                 rs1_byp_en_i,
    input logic [DATA_WIDTH_P-1:0]              rs0_byp_data_i,
    input logic [DATA_WIDTH_P-1:0]              rs1_byp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Execution units src
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]             exec_src0_o,
    output logic [DATA_WIDTH_P-1:0]             exec_src1_o,
    output logic [DATA_WIDTH_P-1:0]             exec_src2_o,
    output logic [ITAG_WIDTH_P-1:0]             exec_itag_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> ALU interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 alu_rdy_i,
    output logic                                alu_req_vld_o,
    output logic [XRV_ALU_OP_WIDTH-1:0]         alu_opc_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> BRANCH interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 b_rdy_i,
    output logic                                b_req_vld_o,
    output logic                                b_is_branch_o,
    output logic                                b_is_jump_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> CSR interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 csr_rdy_i,
    output logic                                csr_req_vld_o,
    output logic [1:0]                          csr_opc_o,
    output logic [11:0]                         csr_addr_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> LSU interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 lsu_rdy_i,
    output logic                                lsu_req_vld_o,
    output logic                                lsu_req_w_en_o,
    output logic [1:0]                          lsu_req_size_o,
    output logic                                lsu_req_signed_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> MUL/DOTP interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 mul_rdy_i,
    output logic                                mul_req_vld_o,
    output logic [1:0]                          mul_opc_o,
    ////////////////////////////////////////////////////////////////////////////////
    // DECODE <-> DIV/REM interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 div_rdy_i,
    output logic                                div_req_vld_o,
    output logic [1:0]                          div_opc_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    xrv_exe_src0_sel_e src0_sel_r;
    xrv_exe_src1_sel_e src1_sel_r;
    ////////////////////////////////////////////////////////////////////////////////
    xrv_imm0_sel_e     imm0_sel_r;
    xrv_imm1_sel_e     imm1_sel_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]       imm0_r;
    logic [31:0]       imm1_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic              j_pc_vld_r;
    always_comb begin
        if (j_pc_vld_o)
            $display("j_pc_vld_o=%d j_pc_o=%h", j_pc_vld_o, j_pc_o);
    end

    ////////////////////////////////////////////////////////////////////////////////
    wire [6:0] func7_w = insn_i[31:25];
    ////////////////////////////////////////////////////////////////////////////////
    wire [2:0] func3_w = insn_i[14:12];
    ////////////////////////////////////////////////////////////////////////////////
    wire [4:0] opcode_w = insn_i[6:2];
    ////////////////////////////////////////////////////////////////////////////////
    assign rs0_addr_o = insn_i[19:15];
    assign rs1_addr_o = insn_i[24:20];
    assign rd_addr_o  = insn_i[11:7];
    wire rs0_x0_o   = rs0_addr_o == '0;
    wire rs1_x0_o   = rs1_addr_o == '0;
    ////////////////////////////////////////////////////////////////////////////////
    wire [2:0] pc_incr_w = insn_is_rv16_i ? 3'd2 : 3'd4;
    assign insn_next_pc_o = insn_pc_i + 32'(pc_incr_w);
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // WB Stage bypass
    ////////////////////////////////////////////////////////////////////////////////
    wire [DATA_WIDTH_P-1:0] rs0_data_w = (rs0_byp_en_i & ~rs0_x0_o) ? rs0_byp_data_i : rs0_data_i;
    wire [DATA_WIDTH_P-1:0] rs1_data_w = (rs1_byp_en_i & ~rs1_x0_o) ? rs1_byp_data_i : rs1_data_i;
    ////////////////////////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////////////////////////
    // Immediate muxing
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (imm0_sel_r)
            XRV_IMM0_Z:    imm0_r = imm_z_type_w;
            XRV_IMM0_ZERO: imm0_r = 'd0;
            default:       imm0_r = 'd0;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (imm1_sel_r)
            XRV_IMM1_I:       imm1_r = imm_i_type_w;
            XRV_IMM1_S:       imm1_r = imm_s_type_w;
            XRV_IMM1_U:       imm1_r = imm_u_type_w;
            default:          imm1_r = imm_i_type_w;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // SRC0 Muxing
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (src0_sel_r)
            XRV_SRC0_RS0: exec_src0_o = rs0_data_w;
            XRV_SRC0_RS1: exec_src0_o = rs1_data_w;
            XRV_SRC0_PC:  exec_src0_o = insn_pc_i;
            XRV_SRC0_IMM: exec_src0_o = imm0_r;
            default:      exec_src0_o = rs0_data_w;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // SRC1 Muxing
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (src1_sel_r)
            XRV_SRC1_RS0: exec_src1_o = rs0_data_w;
            XRV_SRC1_RS1: exec_src1_o = rs1_data_w;
            XRV_SRC1_IMM: exec_src1_o = imm1_r;
            default:      exec_src1_o = rs0_data_w;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign exec_src2_o = rs1_data_w;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction decoding
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        src0_sel_r = XRV_SRC0_RS0;
        src1_sel_r = XRV_SRC1_RS1;
        ////////////////////////////////////////////////////////////////////////////////
        imm1_sel_r = XRV_IMM1_I;
        ////////////////////////////////////////////////////////////////////////////////
        rs0_vld_o     = 1'b0;
        rs1_vld_o     = 1'b0;
        rd_vld_o      = 1'b1;
        ////////////////////////////////////////////////////////////////////////////////
        alu_req_vld_o = 1'b0;
        alu_opc_o     = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        b_req_vld_o   = 'b0;
        b_is_branch_o = 'b0;
        b_is_jump_o    = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        j_pc_vld_r     = 1'b0;
        ////////////////////////////////////////////////////////////////////////////////
        csr_req_vld_o = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        lsu_req_vld_o    = 'b0;
        lsu_req_w_en_o   = 'b0;
        lsu_req_size_o   = 'b0;
        lsu_req_signed_o = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        mul_req_vld_o    = 'b0;
        mul_opc_o        = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        div_req_vld_o    = 'b0;
        div_opc_o        = 'b0;
        ////////////////////////////////////////////////////////////////////////////////
        insn_illegal_o   = 'b0;
        ////////////////////////////////////////////////////////////////////////////////

        case (opcode_w)
            ////////////////////////////////////////////////////////////////////////////////
            // ALU instructions
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LUI: begin
                src0_sel_r    = XRV_SRC0_IMM;
                src1_sel_r    = XRV_SRC1_IMM;
                imm0_sel_r    = XRV_IMM0_ZERO;
                imm1_sel_r    = XRV_IMM1_U;
                alu_req_vld_o = 1'b1;
                alu_opc_o     = XRV_ALU_ADD;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_AUIPC: begin
                src0_sel_r    = XRV_SRC0_PC;
                src1_sel_r    = XRV_SRC1_IMM;
                imm1_sel_r    = XRV_IMM1_U;
                alu_req_vld_o = 1'b1;
                alu_opc_o     = XRV_ALU_ADD;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH_IMM: begin
                src0_sel_r    = XRV_SRC0_RS0;
                src1_sel_r    = XRV_SRC1_IMM;
                imm1_sel_r    = XRV_IMM1_I;
                rs0_vld_o     = 1'b1;
                alu_req_vld_o = 1'b1;
                case (func3_w)
                    3'b000: alu_opc_o = XRV_ALU_ADD;
                    3'b010: alu_opc_o = XRV_ALU_SLTS;
                    3'b011: alu_opc_o = XRV_ALU_SLTU;
                    3'b100: alu_opc_o = XRV_ALU_XOR;
                    3'b110: alu_opc_o = XRV_ALU_OR;
                    3'b111: alu_opc_o = XRV_ALU_AND;
                    3'b001: begin
                        alu_opc_o = XRV_ALU_SLL;  // Shift Left Logical by Immediate
                        insn_illegal_o = func7_w != 7'b0;
                    end
                    3'b101: begin
                        if (func7_w == 7'b0)
                            alu_opc_o = XRV_ALU_SRL;  // Shift Right Logical by Immediate
                        else if (func7_w == 7'b0100000)
                            alu_opc_o = XRV_ALU_SRA;  // Shift Right Arithmetically by Immediate
                        else
                            insn_illegal_o = 1'b1;
                    end
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_ARITH: begin
                ////////////////////////////////////////////////////////////////////////////////
                rs0_vld_o = 1'b1;
                rs1_vld_o = 1'b1;
                alu_req_vld_o = 1'b1;
                ////////////////////////////////////////////////////////////////////////////////
                if (func7_w == 7'd0) begin
                    case (func3_w)
                        3'b000: alu_opc_o = XRV_ALU_ADD;
                        3'b001: alu_opc_o = XRV_ALU_SLL;
                        3'b010: alu_opc_o = XRV_ALU_SLTS;
                        3'b011: alu_opc_o = XRV_ALU_SLTU;
                        3'b100: alu_opc_o = XRV_ALU_XOR;
                        3'b101: alu_opc_o = XRV_ALU_SRL;
                        3'b110: alu_opc_o = XRV_ALU_OR;
                        3'b111: alu_opc_o = XRV_ALU_AND;
                    endcase
                end
                else if (func7_w == 7'd32) begin
                    if (func3_w == 3'b000)
                        alu_opc_o = XRV_ALU_SUB;
                    else if (func3_w == 3'b101)
                        alu_opc_o = XRV_ALU_SRA;
                    else
                        insn_illegal_o = 1'b1;
                end
                else if (func7_w == 7'd1) begin
                    if (func3_w[2]) begin
                        div_req_vld_o = 1'b1;
                        div_opc_o     = func3_w[1:0];
                    end
                    else begin
                        mul_req_vld_o = 1'b1;
                        mul_opc_o     = func3_w[1:0];
                    end
                end
                else begin
                    // FIXME ILLEGAL
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JAL: begin
                b_req_vld_o = 1'b1;
                b_is_jump_o  = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_JALR: begin
                rs0_vld_o   = 1'b1;
                b_req_vld_o = 1'b1;
                b_is_jump_o = 1'b1;
                j_pc_vld_r  = 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_BRANCH: begin
                rs0_vld_o     = 1'b1;
                rs1_vld_o     = 1'b1;
                rd_vld_o      = 1'b0;
                b_req_vld_o   = 1'b1;
                b_is_branch_o = 1'b1;
                ////////////////////////////////////////////////////////////////////////////////
                case (func3_w)
                    3'b000: alu_opc_o = XRV_ALU_EQ;
                    3'b001: alu_opc_o = XRV_ALU_NE;
                    3'b100: alu_opc_o = XRV_ALU_LTS;
                    3'b101: alu_opc_o = XRV_ALU_GES;
                    3'b110: alu_opc_o = XRV_ALU_LTU;
                    3'b111: alu_opc_o = XRV_ALU_GEU;
                    default: alu_opc_o = XRV_ALU_EQ;
                endcase
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_LOAD: begin
                ////////////////////////////////////////////////////////////////////////////////
                rs0_vld_o  = 1'b1;
                ////////////////////////////////////////////////////////////////////////////////
                src1_sel_r = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_I;
                ////////////////////////////////////////////////////////////////////////////////
                lsu_req_vld_o    = 1'b1;
                lsu_req_w_en_o   = 1'b0;
                lsu_req_size_o   = func3_w[1:0];
                lsu_req_signed_o = ~func3_w[2];
                ////////////////////////////////////////////////////////////////////////////////
            end
            ////////////////////////////////////////////////////////////////////////////////
            XRV_STORE: begin
                ////////////////////////////////////////////////////////////////////////////////
                rs0_vld_o  = 1'b1;
                rs1_vld_o  = 1'b1;
                ////////////////////////////////////////////////////////////////////////////////
                rd_vld_o   = 1'b0;
                ////////////////////////////////////////////////////////////////////////////////
                src1_sel_r = XRV_SRC1_IMM;
                imm1_sel_r = XRV_IMM1_S;
                ////////////////////////////////////////////////////////////////////////////////
                lsu_req_vld_o  = 1'b1;
                lsu_req_w_en_o = 1'b1;
                lsu_req_size_o = func3_w[1:0];
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
                    csr_req_vld_o = 1'b1;
                    imm0_sel_r = XRV_IMM0_Z;
                    imm1_sel_r = XRV_IMM1_I;
                    src0_sel_r = func3_w[2] ? XRV_SRC0_IMM : XRV_SRC0_RS0;
                    rs0_vld_o  = ~func3_w[2];
                    if (func3_w[1:0] == 2'b01)
                        csr_opc_o = XRV_CSR_WRITE;
                    else if (func3_w[1:0] == 2'b10 & ~rs0_x0_o)
                        csr_opc_o = XRV_CSR_SET;
                    else if (func3_w[1:0] == 2'b11 & ~rs0_x0_o)
                        csr_opc_o = XRV_CSR_CLR;
                    else
                        csr_opc_o = XRV_CSR_READ;
                    csr_addr_o = insn_i[31:20];
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            default: insn_illegal_o = 1'b1;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Branch target forwarding to FETCH
    ////////////////////////////////////////////////////////////////////////////////
    assign j_pc_o = rs0_data_w + imm_i_type_w;
    assign j_pc_vld_o = j_pc_vld_r & insn_vld_i & issue_rdy_i;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Issue logic
    ////////////////////////////////////////////////////////////////////////////////
    wire issue_alu_w = alu_req_vld_o & alu_rdy_i;
    wire issue_b_w   = b_req_vld_o & b_rdy_i;
    wire issue_lsu_w = lsu_req_vld_o & lsu_rdy_i;
    wire issue_mul_w = mul_req_vld_o & mul_rdy_i;
    wire issue_div_w = div_req_vld_o & div_rdy_i;
    wire issue_csr_w = csr_req_vld_o & csr_rdy_i;
    ////////////////////////////////////////////////////////////////////////////////
    wire issue_fu_w =
        issue_alu_w |
        issue_b_w |
        issue_lsu_w |
        issue_mul_w |
        issue_div_w |
        issue_csr_w;
    ////////////////////////////////////////////////////////////////////////////////
    assign issue_vld_o  = insn_vld_i
        & issue_fu_w
        & ~(|rs_conflict_i)
        & issue_rdy_i
        & ~exec_b_flush_i;
    assign decode_rdy_o = ~insn_vld_i | issue_vld_o;
    ////////////////////////////////////////////////////////////////////////////////
    assign exec_itag_o = issue_itag_i;
    ////////////////////////////////////////////////////////////////////////////////

endmodule

