mport xrvs_pkg::*;

module mrv1_core
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_ID = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_TW_P = 4,
    parameter wid_width_lp = $clog2(num_warps_p),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter rf_addr_width_p = 5,
    parameter ITAG_WIDTH_P = 3
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                    clk_i,
    input  logic                    rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        imem_req_vld_o,
    input  logic                                        imem_req_rdy_i,
    output logic [31:0]                                 imem_req_addr_o,
    input  logic                                        imem_resp_vld_i,
    input  logic [31:0]                                 imem_resp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dmem_req_vld_o,
    input  logic                                        dmem_req_rdy_i,
    input  logic                                        dmem_resp_err_i,
    output logic [DATA_WIDTH_P-1:0]                     dmem_req_addr_o,
    output logic                                        dmem_req_w_en_o,
    output logic [3:0]                                  dmem_req_w_be_o,
    output logic [DATA_WIDTH_P-1:0]                     dmem_req_w_data_o,
    input  logic                                        dmem_resp_vld_i,
    input  logic [DATA_WIDTH_P-1:0]                     dmem_resp_r_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT Fetching
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        fetch_en_i,
    input  logic                                        simt_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        ext_insn_vld_i,
    input  logic [31:0]                                 ext_insn_i,
    input  logic [31:0]                                 ext_insn_pc_i,
    input  logic [wid_width_lp-1:0]                     ext_insn_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        ext_insn_vld_o,
    output logic [31:0]                                 ext_insn_o,
    output logic [31:0]                                 ext_insn_pc_o,
    output logic [wid_width_lp-1:0]                     ext_insn_twid_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        simt_alu_rdy_i,
    input  logic                                        simt_mul_rdy_i,
    input  logic                                        simt_lsu_rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        lane_alu_rdy_o,
    output logic                                        lane_mul_rdy_o,
    output logic                                        lane_lsu_rdy_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction issue stage
    ////////////////////////////////////////////////////////////////////////////////    
    logic [DATA_WIDTH_P-1:0]        rf_rs0_data_lo;
    logic [DATA_WIDTH_P-1:0]        rf_rs1_data_lo;
    logic [wid_width_lp-1:0]        issue_twid_lo;
    logic [rf_addr_width_p-1:0]     issue_rs0_addr_lo;
    logic [rf_addr_width_p-1:0]     issue_rs1_addr_lo;
    logic [rf_addr_width_p-1:0]     issue_rd_addr_lo;
    logic                           issue_rd_vld_lo;
    logic                           issue_rs0_vld_lo;
    logic                           issue_rs1_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]        issue_src0_data_lo;
    logic [DATA_WIDTH_P-1:0]        issue_src1_data_lo;
    logic [DATA_WIDTH_P-1:0]        issue_src2_data_lo;
    logic [ITAG_WIDTH_P-1:0]        issue_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_issue #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) issue_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> ISSUE interface
        ////////////////////////////////////////////////////////////////////////////////
        .decode_rdy_o               (idecode_rdy_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_i                     (idecode_insn_li),
        .insn_pc_i                  (idecode_insn_pc_li),
        .insn_vld_i                 (idecode_insn_vld_li),
        .insn_is_rv16_i             (idecode_insn_compressed_li),
        .insn_illegal_i             (idecode_insn_illegal_li),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_illegal_o             (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .j_pc_vld_o                 (idecode_j_pc_vld_lo),
        .j_pc_o                     (idecode_j_pc_lo),
        .insn_next_pc_o             (idecode_next_pc_lo),
        .exec_b_flush_i             (exec_b_pc_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_vld_i               (wb_data_vld_lo),
        .retire_rd_addr_vld_i       (iq_retire_rd_addr_vld_lo),
        .retire_rd_addr_i           (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> RF interface
        ////////////////////////////////////////////////////////////////////////////////
        .rf_twid_o                  (issue_twid_lo),
        .rs0_addr_o                 (issue_rs0_addr_lo),
        .rs0_data_i                 (rf_rs0_data_lo),
        .rs1_addr_o                 (issue_rs1_addr_lo),
        .rs0_data_i                 (rf_rs1_data_lo),
        .rd_addr_o                  (issue_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_vld_o                   (issue_rd_vld_lo),
        .rs0_vld_o                  (issue_rs0_vld_lo),
        .rs1_vld_o                  (issue_rs1_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_i              (ret_rs_conflict_lo),
        .rs0_byp_en_i               (ret_rs_byp_en_lo[0]),
        .rs1_byp_en_i               (ret_rs_byp_en_lo[1]),
        .rs0_byp_data_i             (ret_rs_byp_data_lo[0]),
        .rs1_byp_data_i             (ret_rs_byp_data_lo[1]),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE interface
        ////////////////////////////////////////////////////////////////////////////////
        .exec_src0_o                (issue_src0_data_lo),
        .exec_src1_o                (issue_src1_data_lo),
        .exec_src2_o                (issue_src2_data_lo),
        .exec_itag_o                (issue_itag_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(ALU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .alu_rdy_i                  (alu_rdy_lo),
        .alu_req_vld_o              (issue_alu_req_lo),
        .alu_opc_o                  (issue_alu_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> BRANCH interface
        ////////////////////////////////////////////////////////////////////////////////
        .b_rdy_i                    (b_rdy_lo),
        .b_req_vld_o                (issue_b_req_vld_lo),
        .b_is_branch_o              (issue_b_is_branch_lo),
        .b_is_jump_o                (issue_b_is_jump_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> EXE(CSR) interface
        ////////////////////////////////////////////////////////////////////////////////
        .csr_rdy_i                  (csr_rdy_lo),
        .csr_req_vld_o              (issue_csr_req_vld_lo),
        .csr_opc_o                  (issue_csr_opc_lo),
        .csr_addr_o                 (issue_csr_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(MUL) interface
        ////////////////////////////////////////////////////////////////////////////////
        .mul_rdy_i                  (mul_rdy_lo),
        .mul_req_vld_o              (issue_mul_req_lo),
        .mul_opc_o                  (issue_mul_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> EXE(LSU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_rdy_i                  (lsu_rdy_lo),
        .lsu_req_vld_o              (issue_lsu_req_lo),
        .lsu_req_w_en_o             (issue_lsu_w_en_lo),
        .lsu_req_size_o             (issue_lsu_size_lo),
        .lsu_req_signed_o           (issue_lsu_signed_lo)
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(DIV/REM) interface
        ////////////////////////////////////////////////////////////////////////////////
        //.div_rdy_i                 (div_rdy_lo),
        //.div_req_vld_o             (issue_div_req_vld_lo),
        //.div_opc_o                 (issue_div_opc_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Register File
    ////////////////////////////////////////////////////////////////////////////////
    logic [twid_width_lp-1:0]       wb_twid_lo;
    logic [rf_addr_width_p-1:0]     wb_rd_addr_lo;
    logic [DATA_WIDTH_P-1:0]        wb_data_lo;
    logic                           wb_data_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_rf #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P)
    ) rf_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .twid_i                     (issue_twid_lo),
        .rs0_addr_i                 (issue_rs0_addr_lo),
        .rs0_data_o                 (rf_rs0_data_lo),
        .rs1_addr_i                 (issue_rs1_addr_lo),
        .rs1_data_o                 (rf_rs1_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_twid_i                  (wb_twid_lo),
        .rd_w_en_i                  (wb_data_vld_lo),
        .rd_addr_i                  (wb_rd_addr_lo),
        .rd_data_i                  (wb_data_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Execution stage
    ////////////////////////////////////////////////////////////////////////////////    
    logic [num_fu_lp-1:0]                       exec_fu_done_lo;
    logic [num_fu_lp-1:0][twid_width_lp-1:0]    exec_fu_twid_lo;
    logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]     exec_fu_wb_itag_lo;
    logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]     exec_fu_wb_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_exec #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) exec_i (
        .exec_src0_data_i(),
        .exec_src1_data_i(),
        .exec_itag_i(),
        .exec_twid_i(),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_done_o(exec_fu_done_lo),
        .exec_fu_res_data_o(exec_fu_twid_lo),
        .exec_fu_itag_o(exec_fu_wb_itag_lo),
        .exec_fu_twid_o(exec_fu_wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_req_i(),
        .alu_rdy_o(),
        .alu_opc_i(),
        .alu_cmp_res_o(),
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Retire Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_fu_lp-1:0]                       ret_fu_done_q;
    logic [num_fu_lp-1:0][twid_width_lp-1:0]    ret_fu_twid_q;
    logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]     ret_fu_wb_itag_q;
    logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]     ret_fu_wb_data_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w) begin
            ret_fu_done_q           <= 'b0;
            ret_fu_twid_q           <= 'b0;
            ret_fu_wb_itag_q        <= 'b0;
            ret_fu_wb_data_q        <= 'b0;
        end
        else begin
            ret_fu_done_q           <= exec_fu_done_lo;
            ret_fu_twid_q           <= exec_fu_twid_lo;
            ret_fu_wb_itag_q        <= exec_fu_wb_itag_lo;
            ret_fu_wb_data_q        <= exec_fu_wb_data_lo;

        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_retire #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) wback (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i | rst_down_w),
        ////////////////////////////////////////////////////////////////////////////////
        // Exec -> Retire
        ////////////////////////////////////////////////////////////////////////////////
        .fu_done_i                      (ret_fu_done_q),
        .fu_wb_data_i                   (ret_fu_wb_data_q),
        .fu_itag_i                      (ret_fu_wb_itag_q),
        .fu_twid_i                      (ret_fu_twid_q),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> WBACK
        ////////////////////////////////////////////////////////////////////////////////
        .issue_itag_i                   (iq_issue_itag_lo),
        .retire_rdy_i                   (iq_retire_rdy_lo),
        .retire_cnt_o                   (ret_retire_cnt_lo),
        .retire_itag_i                  (iq_retire_itag_lo),
        .retire_rd_addr_i               (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // WBACK <-> RF
        ////////////////////////////////////////////////////////////////////////////////
        .wb_twid_o                      (wb_twid_lo),
        .wb_rd_addr_o                   (wb_rd_addr_lo),
        .wb_data_vld_o                  (wb_data_vld_lo),
        .wb_data_o                      (wb_data_lo),
        .rs_conflict_i                  (iq_rs_conflict_lo),
        .rs_conflict_o                  (ret_rs_conflict_lo),
        .rs_byp_en_o                    (ret_rs_byp_en_lo),
        .rs_byp_data_o                  (ret_rs_byp_data_lo),
        .iqueue_vld_i                   (iq_vld_lo),
        .iqueue_rd_vld_i                (iq_rd_vld_lo),
        .iqueue_rd_addr_i               (iq_rd_addr_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule