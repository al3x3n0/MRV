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
    input  logic [wid_width_lp-1:0]                     ext_insn_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        ext_insn_vld_o,
    output logic [31:0]                                 ext_insn_o,
    output logic [31:0]                                 ext_insn_pc_o,
    output logic [wid_width_lp-1:0]                     ext_insn_tid_o,
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
    // Instruction Fetch Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_b_pc_vld_lo;
    logic [31:0]                    exec_b_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_th_ctl_vld_lo;
    logic [tid_width_lp-1:0]        exec_th_ctl_tid_lo;
    logic                           exec_th_ctl_tspawn_vld_lo;
    logic [31:0]                    exec_th_ctl_tspawn_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_ifetch #(
        .NUM_TW_P (NUM_TW_P)
    ) if_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_en_i                 (fetch_en_i),
        ////////////////////////////////////////////////////////////////////////////////
        .ifetch_insn_vld_o          (ifetch_data_vld_lo),
        .ifetch_insn_data_o         (ifetch_data_lo),
        .ifetch_insn_pc_o           (ifetch_pc_lo),
        .ifetch_insn_tid_o          (ifetch_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // IFETCH <-> IMEM interface
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld_o),
        .imem_req_rdy_i             (imem_req_rdy_i),
        .imem_req_addr_o            (imem_req_addr_o),
        .imem_resp_vld_i            (imem_resp_vld_i),
        .imem_resp_data_i           (imem_resp_data_i),
        ////////////////////////////////////////////////////////////////////////////////
        // IMT Control
        ////////////////////////////////////////////////////////////////////////////////
        .wstall_vld_i               (/*FIXME*/),
        .wstall_tid_i               (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_i               (exec_th_ctl_vld_lo),
        .th_ctl_tid_i               (exec_th_ctl_tid_lo),
        .th_ctl_tspawn_vld_i        (exec_th_ctl_tspawn_vld_lo),
        .th_ctl_tspawn_pc_i         (exec_th_ctl_tspawn_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_barrier_vld_i       (/*FIXME*/),
        .th_ctl_barrier_id_i        (/*FIXME*/),
        .th_ctl_barrier_size_m1_i   (/*FIXME*/)
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // IDecode Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic                                        dec_vld_lo;
    logic [31:0]                                 dec_pc_lo;
    logic [wid_width_lp-1:0]                     dec_tid_lo;
    xrv_exe_src0_sel_e                           dec_src0_sel_lo;
    xrv_exe_src1_sel_e                           dec_src1_sel_lo;
    logic [data_width_p-1:0]                     dec_imm0_lo;
    logic [data_width_p-1:0]                     dec_imm1_lo;
    logic                                        dec_rs0_vld_lo;
    logic [rf_addr_width_p-1:0]                  dec_rs0_addr_lo;
    logic                                        dec_rs1_vld_lo;
    logic [rf_addr_width_p-1:0]                  dec_rs1_addr_lo;
    logic                                        dec_rd_vld_lo;
    logic [rf_addr_width_p-1:0]                  dec_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_idecode #(
        .DATA_WIDTH_P (DATA_WIDTH_P)
    ) id_i (
        ////////////////////////////////////////////////////////////////////////////////
        .insn_vld_i                 (fa_ifetch_data_vld_w),
        .insn_i                     (fa_ifetch_data_w),
        .insn_pc_i                  (fa_ifetch_pc_w),
        .insn_tid_i                 (fa_ifetch_tid_w),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_illegal_o             (/*FIXME*/),
        .insn_next_pc_o             (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_pc_o                   (dec_pc_lo),
        .dec_tid_o                  (dec_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_src0_sel_o             (dec_src0_sel_lo),
        .dec_src1_sel_o             (dec_src1_sel_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_imm0_o                 (dec_imm0_lo),
        .dec_imm1_o                 (dec_imm1_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_rs0_vld_o              (dec_rs0_vld_lo),
        .dec_rs0_addr_o             (dec_rs0_addr_lo),
        .dec_rs1_vld_o              (dec_rs1_vld_lo),
        .dec_rs1_addr_o             (dec_rs1_addr_lo),
        .dec_rd_vld_o               (dec_rd_vld_lo),
        .dec_rd_addr_o              (dec_rd_addr_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    logic                           dec_vld_q;
    logic [31:0]                    dec_pc_q;
    logic [wid_width_lp-1:0]        dec_tid_q;
    mrv_fu_type_e                   dec_fu_type_q;
    xrv_exe_src0_sel_e              dec_src0_sel_q;
    xrv_exe_src1_sel_e              dec_src1_sel_q;
    logic [DATA_WIDTH_P-1:0]        dec_imm0_q;
    logic [DATA_WIDTH_P-1:0]        dec_imm1_q;
    logic                           dec_rs0_vld_q;
    logic [rf_addr_width_p-1:0]     dec_rs0_addr_q;
    logic                           dec_rs1_vld_q;
    logic [rf_addr_width_p-1:0]     dec_rs1_addr_q;
    logic                           dec_rd_vld_q;
    logic [rf_addr_width_p-1:0]     dec_rd_addr_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w) begin
            dec_vld_q           <= 'b0;
            dec_pc_q            <= 'b0;
            dec_tid_q           <= 'b0;
            dec_fu_type_q       <= 'b0;
            dec_src0_sel_q      <= 'b0;
            dec_src1_sel_q      <= 'b0;
            dec_imm0_q          <= 'b0;
            dec_imm1_q          <= 'b0;
            dec_rs0_vld_q       <= 'b0;
            dec_rs0_addr_q      <= 'b0;
            dec_rs1_vld_q       <= 'b0;
            dec_rs1_addr_q      <= 'b0;
            dec_rd_vld_q        <= 'b0;
            dec_rd_addr_q       <= 'b0;
        end
        else begin
            dec_vld_q           <= dec_vld_lo;
            dec_pc_q            <= dec_pc_lo;
            dec_tid_q           <= dec_tid_lo;
            dec_fu_type_q       <= dec_fu_type_lo;
            dec_src0_sel_q      <= dec_src0_sel_lo;
            dec_src1_sel_q      <= dec_src1_sel_lo;
            dec_imm0_q          <= dec_imm0_lo;
            dec_imm1_q          <= dec_imm1_lo;
            dec_rs0_vld_q       <= dec_rs0_vld_lo;
            dec_rs0_addr_q      <= dec_rs0_addr_lo;
            dec_rs1_vld_q       <= dec_rs1_vld_lo;
            dec_rs1_addr_q      <= dec_rs1_addr_lo;
            dec_rd_vld_q        <= dec_rd_vld_lo;
            dec_rd_addr_q       <= dec_rd_addr_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction issue stage
    ////////////////////////////////////////////////////////////////////////////////    
    logic [DATA_WIDTH_P-1:0]            rf_rs0_data_lo;
    logic [DATA_WIDTH_P-1:0]            rf_rs1_data_lo;
    logic [wid_width_lp-1:0]            issue_tid_lo;
    logic [rf_addr_width_p-1:0]         issue_rs0_addr_lo;
    logic [rf_addr_width_p-1:0]         issue_rs1_addr_lo;
    logic [rf_addr_width_p-1:0]         issue_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]            issue_src0_data_lo;
    logic [DATA_WIDTH_P-1:0]            issue_src1_data_lo;
    logic [DATA_WIDTH_P-1:0]            issue_src2_data_lo;
    logic [ITAG_WIDTH_P-1:0]            issue_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_fu_lp-1:0]               exec_fu_rdy_lo;
    logic [num_fu_lp-1:0]               exec_fu_req_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                               issue_lsu_req_w_en_lo;
    logic [1:0]                         issue_lsu_req_size_lo;
    logic                               issue_lsu_req_signed_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_issue #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) issue_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> ISSUE interface
        ////////////////////////////////////////////////////////////////////////////////
        .decode_rdy_o                   (idecode_rdy_lo),
        .dec_vld_i                      (),
        .dec_pc_i                       (dec_pc_q),
        .dec_tid_i                      (dec_tid_q),
        .dec_fu_type_i                  (dec_fu_type_q),
        .dec_src0_sel_i                 (dec_src0_sel_q),
        .dec_src1_sel_i                 (dec_src1_sel_q),
        .dec_imm0_i                     (dec_imm0_q),
        .dec_imm1_i                     (dec_imm1_q),
        .dec_rs0_vld_i                  (dec_rs0_vld_q),
        .dec_rs0_addr_i                 (dec_rs0_addr_q),
        .dec_rs1_vld_i                  (dec_rs1_vld_q),
        .dec_rs1_addr_i                 (dec_rs1_addr_q),
        .dec_rd_vld_i                   (dec_rd_vld_q),
        .dec_rd_addr_i                  (dec_rd_addr_q),      
        ////////////////////////////////////////////////////////////////////////////////
        .j_pc_vld_o                     (idecode_j_pc_vld_lo),
        .j_pc_o                         (idecode_j_pc_lo),
        .insn_next_pc_o                 (idecode_next_pc_lo),
        .exec_b_flush_i                 (exec_b_pc_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_vld_i                   (wb_data_vld_lo),
        .retire_rd_addr_vld_i           (iq_retire_rd_addr_vld_lo),
        .retire_rd_addr_i               (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> RF interface
        ////////////////////////////////////////////////////////////////////////////////
        .rf_tid_o                      (issue_tid_lo),
        .rs0_addr_o                     (issue_rs0_addr_lo),
        .rs0_data_i                     (rf_rs0_data_lo),
        .rs1_addr_o                     (issue_rs1_addr_lo),
        .rs0_data_i                     (rf_rs1_data_lo),
        .rd_addr_o                      (issue_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_i                  (ret_rs_conflict_lo),
        .rs0_byp_en_i                   (ret_rs_byp_en_lo[0]),
        .rs1_byp_en_i                   (ret_rs_byp_en_lo[1]),
        .rs0_byp_data_i                 (ret_rs_byp_data_lo[0]),
        .rs1_byp_data_i                 (ret_rs_byp_data_lo[1]),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> EXE interface
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_rdy_i                  (exec_fu_rdy_lo),
        .exec_fu_req_o                  (exec_fu_req_lo),
        .issue_src0_data_o              (issue_src0_data_lo),
        .issue_src1_data_o              (issue_src1_data_lo),
        .issue_src2_data_o              (issue_src2_data_lo),
        .issue_itag_o                   (issue_itag_lo),
        .issue_tid_o                    (issue_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(ALU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .alu_req_vld_o                  (issue_alu_req_lo),
        .alu_opc_o                      (issue_alu_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> BRANCH interface
        ////////////////////////////////////////////////////////////////////////////////
        .b_req_vld_o                    (issue_b_req_vld_lo),
        .b_is_branch_o                  (issue_b_is_branch_lo),
        .b_is_jump_o                    (issue_b_is_jump_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(CSR) interface
        ////////////////////////////////////////////////////////////////////////////////
        .csr_req_vld_o                  (issue_csr_req_vld_lo),
        .csr_opc_o                      (issue_csr_opc_lo),
        .csr_addr_o                     (issue_csr_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(MUL) interface
        ////////////////////////////////////////////////////////////////////////////////
        .mul_req_vld_o                  (issue_mul_req_lo),
        .mul_opc_o                      (issue_mul_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(LSU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .issue_lsu_w_en_o               (issue_lsu_w_en_lo),
        .issue_lsu_size_o               (issue_lsu_size_lo),
        .issue_lsu_signed_o             (issue_lsu_signed_lo)
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXE(DIV/REM) interface
        ////////////////////////////////////////////////////////////////////////////////
        //.div_req_vld_o                (issue_div_req_vld_lo),
        //.div_opc_o                    (issue_div_opc_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]            issue_src0_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src1_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src2_data_q;
    logic [ITAG_WIDTH_P-1:0]            issue_itag_q;
    logic [tid_width_lp-1:0]           issue_tid_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w) begin
            issue_src0_data_q           <= 'b0;
            issue_src1_data_q           <= 'b0;
            issue_src2_data_q           <= 'b0;
            issue_itag_q                <= 'b0;
            issue_tid_q                <= 'b0;
        end
        else begin
            issue_src0_data_q           <= issue_src0_data_lo;
            issue_src1_data_q           <= issue_src1_data_lo;
            issue_src2_data_q           <= issue_src2_data_lo;
            issue_itag_q                <= issue_itag_lo;
            issue_tid_q                <= issue_tid_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Register File
    ////////////////////////////////////////////////////////////////////////////////
    logic [tid_width_lp-1:0]       wb_tid_lo;
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
        .tid_i                     (issue_tid_lo),
        .rs0_addr_i                 (issue_rs0_addr_lo),
        .rs0_data_o                 (rf_rs0_data_lo),
        .rs1_addr_i                 (issue_rs1_addr_lo),
        .rs1_data_o                 (rf_rs1_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_tid_i                  (wb_tid_lo),
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
    logic [num_fu_lp-1:0][tid_width_lp-1:0]    exec_fu_tid_lo;
    logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]     exec_fu_wb_itag_lo;
    logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]     exec_fu_wb_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_exec #(
        .NUM_TW_P (NUM_TW_P),
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) exec_i (
        .exec_src0_data_i       (issue_src0_data_q),
        .exec_src1_data_i       (issue_src1_data_q),
        .exec_itag_i            (issue_itag_q),
        .exec_tid_i             (issue_tid_q),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_rdy_o          (exec_fu_rdy_lo),
        .exec_fu_req_i          (exec_fu_req_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_done_o         (exec_fu_done_lo),
        .exec_fu_res_data_o     (exec_fu_tid_lo),
        .exec_fu_itag_o         (exec_fu_wb_itag_lo),
        .exec_fu_tid_o          (exec_fu_wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_opc_i              (),
        .alu_cmp_res_o          (),
        ////////////////////////////////////////////////////////////////////////////////
        .b_is_branch_i          (exec_b_is_branch_li),
        .b_is_jump_i            (exec_b_is_jump_li),
        .b_pc_vld_o             (exec_b_pc_vld_lo),
        .b_pc_o                 (exec_b_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_o           (exec_th_ctl_vld_lo),
        .th_ctl_tid_o           (exec_th_ctl_tid_lo),
        .th_ctl_tspawn_vld_o    (exec_th_ctl_tspawn_vld_lo),
        .th_ctl_tspawn_pc_o     (exec_th_ctl_tspawn_pc_lo),
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Retire Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_fu_lp-1:0]                       exec_fu_done_q;
    logic [num_fu_lp-1:0][tid_width_lp-1:0]     exec_fu_tid_q;
    logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]     exec_fu_wb_itag_q;
    logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]     exec_fu_wb_data_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w) begin
            exec_fu_done_q              <= 'b0;
            exec_fu_tid_q               <= 'b0;
            exec_fu_wb_itag_q           <= 'b0;
            exec_fu_wb_data_q           <= 'b0;
        end
        else begin
            exec_fu_done_q              <= exec_fu_done_lo;
            exec_fu_tid_q               <= exec_fu_tid_lo;
            exec_fu_wb_itag_q           <= exec_fu_wb_itag_lo;
            exec_fu_wb_data_q           <= exec_fu_wb_data_lo;
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
        .fu_done_i                      (exec_fu_done_q),
        .fu_wb_data_i                   (exec_fu_wb_data_q),
        .fu_itag_i                      (exec_fu_wb_itag_q),
        .fu_tid_i                       (exec_fu_tid_q),
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
        .wb_tid_o                       (wb_tid_lo),
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