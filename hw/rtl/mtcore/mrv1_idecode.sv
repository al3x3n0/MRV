module mrv1_idecode
#(
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 2,
    parameter rf_addr_width_p = 5,
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
    input logic [twid_width_lp-1:0]             insn_twid_i,
    input logic                                 insn_vld_i,
    ////////////////////////////////////////////////////////////////////////////////
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


endmodule