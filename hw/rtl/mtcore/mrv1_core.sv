import mrv1_pkg::*;
import xrv1_pkg::*;

module mrv1_core
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_ID = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P = 4,
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter rf_addr_width_p = 5,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_RS_LP = 2,
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter IQ_SZ_LP = (1 << ITAG_WIDTH_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        imem_req_vld_o,
    input  logic                                        imem_req_rdy_i,
    output logic [PC_WIDTH_P-1:0]                       imem_req_addr_o,
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
    input  logic                                        simt_en_i
    ////////////////////////////////////////////////////////////////////////////////
    //input  logic                                        ext_insn_vld_i,
    //input  logic [31:0]                                 ext_insn_i,
    //input  logic [PC_WIDTH_P-1:0]                       ext_insn_pc_i,
    //input  logic [TID_WIDTH_LP-1:0]                     ext_insn_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    //output logic                                        ext_insn_vld_o,
    //output logic [31:0]                                 ext_insn_o,
    //output logic [PC_WIDTH_P-1:0]                       ext_insn_pc_o,
    //output logic [TID_WIDTH_LP-1:0]                     ext_insn_tid_o,
);
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction Fetch Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic                           ifetch_data_vld_lo;
    logic [31:0]                    ifetch_data_lo;
    logic [PC_WIDTH_P-1:0]          ifetch_pc_lo;
    logic [TID_WIDTH_LP-1:0]        ifetch_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_b_pc_vld_lo;
    logic [PC_WIDTH_P-1:0]          exec_b_pc_lo;
    logic [TID_WIDTH_LP-1:0]        exec_b_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_th_ctl_vld_lo;
    logic [TID_WIDTH_LP-1:0]        exec_th_ctl_tid_lo;
    logic                           exec_th_ctl_tspawn_vld_lo;
    logic [PC_WIDTH_P-1:0]          exec_th_ctl_tspawn_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_ifetch #(
        .NUM_THREADS_P              (NUM_THREADS_P),
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) if_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_en_i                 (fetch_en_i),
        .simt_en_i                  (simt_en_i),
        ////////////////////////////////////////////////////////////////////////////////
        .ifetch_insn_vld_o          (ifetch_data_vld_lo),
        .ifetch_insn_data_o         (ifetch_data_lo),
        .ifetch_insn_pc_o           (ifetch_pc_lo),
        .ifetch_insn_tid_o          (ifetch_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_tid_i                 (),
        .exec_b_pc_vld_i            (),
        .exec_b_pc_i                (),
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
        .th_stall_vld_i             (1'b0),
        .th_stall_tid_i             ('b0),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_i               (exec_th_ctl_vld_lo),
        .th_ctl_tid_i               (exec_th_ctl_tid_lo),
        .th_ctl_tspawn_vld_i        (exec_th_ctl_tspawn_vld_lo),
        .th_ctl_tspawn_pc_i         (exec_th_ctl_tspawn_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_barrier_vld_i       (1'b0),
        .th_ctl_barrier_id_i        ('b0),
        .th_ctl_barrier_size_m1_i   ('b0)
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // IDecode Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0]                   issue_rdy_lo; /* XXX ??? */
    logic                                       dec_vld_lo;
    logic [PC_WIDTH_P-1:0]                      dec_pc_lo;
    logic [TID_WIDTH_LP-1:0]                    dec_tid_lo;
    logic [MRV_NUM_FU-1:0]                      dec_fu_req_lo;
    logic [MRV_OPC_WIDTH_P-1:0]                 dec_fu_opc_lo;
    xrv_exe_src0_sel_e                          dec_src0_sel_lo;
    xrv_exe_src1_sel_e                          dec_src1_sel_lo;
    logic [DATA_WIDTH_P-1:0]                    dec_imm0_lo;
    logic [DATA_WIDTH_P-1:0]                    dec_imm1_lo;
    logic                                       dec_rs0_vld_lo;
    logic [rf_addr_width_p-1:0]                 dec_rs0_addr_lo;
    logic                                       dec_rs1_vld_lo;
    logic [rf_addr_width_p-1:0]                 dec_rs1_addr_lo;
    logic                                       dec_rd_vld_lo;
    logic [rf_addr_width_p-1:0]                 dec_rd_addr_lo;
    logic                                       dec_b_is_branch_lo;
    logic                                       dec_b_is_jump_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_idecode #(
        .PC_WIDTH_P                 (PC_WIDTH_P),
        .NUM_THREADS_P              (NUM_THREADS_P),
        .DATA_WIDTH_P               (DATA_WIDTH_P),
        .NUM_FU_P                   (MRV_NUM_FU),
        .FU_OPC_WIDTH_P             (MRV_OPC_WIDTH_P)
    ) id_i (
        ////////////////////////////////////////////////////////////////////////////////
        .insn_vld_i                 (ifetch_data_vld_lo/*fa_ifetch_data_vld_w*/),
        .insn_i                     (ifetch_data_lo/*fa_ifetch_data_w*/),
        .insn_pc_i                  (ifetch_pc_lo/*fa_ifetch_pc_w*/),
        .insn_tid_i                 (ifetch_tid_lo/*fa_ifetch_tid_w*/),
        .insn_illegal_o             (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_vld_o                  (dec_vld_lo),
        .dec_pc_o                   (dec_pc_lo),
        .dec_tid_o                  (dec_tid_lo),
        .dec_fu_req_o               (dec_fu_req_lo),
        .dec_fu_opc_o               (dec_fu_opc_lo),
        .dec_src0_sel_o             (dec_src0_sel_lo),
        .dec_src1_sel_o             (dec_src1_sel_lo),
        .dec_imm0_o                 (dec_imm0_lo),
        .dec_imm1_o                 (dec_imm1_lo),
        .dec_rs0_vld_o              (dec_rs0_vld_lo),
        .dec_rs0_addr_o             (dec_rs0_addr_lo),
        .dec_rs1_vld_o              (dec_rs1_vld_lo),
        .dec_rs1_addr_o             (dec_rs1_addr_lo),
        .dec_rd_vld_o               (dec_rd_vld_lo),
        .dec_rd_addr_o              (dec_rd_addr_lo),
        .dec_b_is_branch_o          (dec_b_is_branch_lo),
        .dec_b_is_jump_o            (dec_b_is_jump_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    logic                           dec_vld_q;
    logic [PC_WIDTH_P-1:0]          dec_pc_q;
    logic [TID_WIDTH_LP-1:0]        dec_tid_q;
    logic [MRV_NUM_FU-1:0]          dec_fu_req_q;
    logic [MRV_OPC_WIDTH_P-1:0]     dec_fu_opc_q;
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
    logic                           dec_b_is_branch_q;
    logic                           dec_b_is_jump_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            dec_vld_q           <= 'b0;
            dec_pc_q            <= 'b0;
            dec_tid_q           <= 'b0;
            dec_fu_req_q        <= 'b0;
            dec_fu_opc_q        <= 'b0;
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
            dec_b_is_branch_q   <= 'b0;
            dec_b_is_jump_q     <= 'b0;
        end
        else begin
            dec_vld_q           <= dec_vld_lo;
            dec_pc_q            <= dec_pc_lo;
            dec_tid_q           <= dec_tid_lo;
            dec_fu_req_q        <= dec_fu_req_lo;
            dec_fu_opc_q        <= dec_fu_opc_lo;
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
            dec_b_is_branch_q   <= dec_b_is_branch_lo;
            dec_b_is_jump_q     <= dec_b_is_jump_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction issue stage
    ////////////////////////////////////////////////////////////////////////////////    
    logic [DATA_WIDTH_P-1:0]            rf_rs0_data_lo;
    logic [DATA_WIDTH_P-1:0]            rf_rs1_data_lo;
    logic [PC_WIDTH_P-1:0]              issue_pc_lo;
    logic [TID_WIDTH_LP-1:0]            issue_tid_lo;
    logic [rf_addr_width_p-1:0]         issue_rs0_addr_lo;
    logic [rf_addr_width_p-1:0]         issue_rs1_addr_lo;
    logic [rf_addr_width_p-1:0]         issue_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]            issue_src0_data_lo;
    logic [DATA_WIDTH_P-1:0]            issue_src1_data_lo;
    logic [DATA_WIDTH_P-1:0]            issue_src2_data_lo;
    logic [ITAG_WIDTH_P-1:0]            issue_itag_lo;
    logic [MRV_NUM_FU-1:0]              exec_fu_rdy_lo;
    logic [MRV_NUM_FU-1:0]              issue_fu_req_lo;
    logic [MRV_OPC_WIDTH_P-1:0]         issue_fu_opc_lo;
    logic                               issue_b_is_branch_lo;
    logic                               issue_b_is_jump_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0][NUM_RS_LP-1:0]                        ret_rs_conflict_lo;
    logic [NUM_THREADS_P-1:0][NUM_RS_LP-1:0]                        ret_rs_byp_en_lo;
    logic [NUM_THREADS_P-1:0][NUM_RS_LP-1:0][DATA_WIDTH_P-1:0]      ret_rs_byp_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0]                         iq_vld_lo;
    logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0]                         iq_rd_vld_lo;
    logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0][rf_addr_width_p-1:0]    iq_rd_addr_lo;
    logic [NUM_THREADS_P-1:0][NUM_RS_LP-1:0][IQ_SZ_LP-1:0]          iq_rs_conflict_lo;
    logic [NUM_THREADS_P-1:0]                                       iq_retire_rdy_lo;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]                     iq_retire_itag_lo;
    logic [TID_WIDTH_LP-1:0]                                        ret_retire_tid_lo;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]                     ret_retire_cnt_lo;

    mrv1_issue #(
        .PC_WIDTH_P                     (PC_WIDTH_P),
        .NUM_THREADS_P                  (NUM_THREADS_P),
        .DATA_WIDTH_P                   (DATA_WIDTH_P),
        .ITAG_WIDTH_P                   (ITAG_WIDTH_P),
        .NUM_FU_P                       (MRV_NUM_FU),
        .FU_OPC_WIDTH_P                 (MRV_OPC_WIDTH_P)
    ) issue_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> ISSUE interface
        ////////////////////////////////////////////////////////////////////////////////
        .issue_rdy_o                    (issue_rdy_lo),
        .dec_vld_i                      (),
        .dec_pc_i                       (dec_pc_q),
        .dec_tid_i                      (dec_tid_q),
        .dec_fu_req_i                   (dec_fu_req_q),
        .dec_fu_opc_i                   (dec_fu_opc_q),
        .dec_b_is_branch_i              (dec_b_is_branch_q),
        .dec_b_is_jump_i                (dec_b_is_jump_q),
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
        //.j_pc_vld_o                     (idecode_j_pc_vld_lo),
        //.j_pc_o                         (idecode_j_pc_lo),
        //.insn_next_pc_o                 (idecode_next_pc_lo),
        .exec_b_flush_i                 (exec_b_pc_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_vld_i                   (wb_data_vld_lo),
        .retire_cnt_i                   (ret_retire_cnt_lo),
        .retire_tid_i                   (ret_retire_tid_lo),
        .iq_vld_o                       (iq_vld_lo),
        .iq_rd_vld_o                    (iq_rd_vld_lo),
        .iq_rd_addr_o                   (iq_rd_addr_lo),
        .iq_rs_conflict_o               (iq_rs_conflict_lo),
        .iq_retire_rdy_o                (iq_retire_rdy_lo),
        .iq_retire_itag_o               (iq_retire_itag_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> RF interface
        ////////////////////////////////////////////////////////////////////////////////
        .rf_tid_o                       (issue_tid_lo),
        .rs0_addr_o                     (issue_rs0_addr_lo),
        .rs0_data_i                     (rf_rs0_data_lo),
        .rs1_addr_o                     (issue_rs1_addr_lo),
        .rs1_data_i                     (rf_rs1_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs0_byp_en_i                   (ret_rs_byp_en_lo[0]),
        .rs1_byp_en_i                   (ret_rs_byp_en_lo[1]),
        .rs0_byp_data_i                 (ret_rs_byp_data_lo[0]),
        .rs1_byp_data_i                 (ret_rs_byp_data_lo[1]),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE <-> EXE interface
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_rdy_i                  (exec_fu_rdy_lo),
        .issue_fu_req_o                 (issue_fu_req_lo),
        .issue_fu_opc_o                 (issue_fu_opc_lo),
        .issue_src0_data_o              (issue_src0_data_lo),
        .issue_src1_data_o              (issue_src1_data_lo),
        .issue_src2_data_o              (issue_src2_data_lo),
        .issue_pc_o                     (issue_pc_lo),
        .issue_itag_o                   (issue_itag_lo),
        .issue_tid_o                    (issue_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> BRANCH interface
        ////////////////////////////////////////////////////////////////////////////////
        .issue_b_is_branch_o            (issue_b_is_branch_lo),
        .issue_b_is_jump_o              (issue_b_is_jump_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]            issue_src0_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src1_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src2_data_q;
    logic [PC_WIDTH_P-1:0]              issue_pc_q;
    logic [ITAG_WIDTH_P-1:0]            issue_itag_q;
    logic [TID_WIDTH_LP-1:0]            issue_tid_q;
    logic [MRV_NUM_FU-1:0]              issue_fu_req_q;
    logic [MRV_OPC_WIDTH_P-1:0]         issue_fu_opc_q;
    mrv_vec_mode_e                      issue_fu_vec_mode_q;
    logic                               issue_b_is_branch_q;
    logic                               issue_b_is_jump_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i /* rst_down_w */) begin
            issue_src0_data_q           <= 'b0;
            issue_src1_data_q           <= 'b0;
            issue_src2_data_q           <= 'b0;
            issue_pc_q                  <= 'b0;
            issue_itag_q                <= 'b0;
            issue_tid_q                 <= 'b0;
            issue_fu_req_q              <= 'b0;
            issue_fu_opc_q              <= 'b0;
            issue_fu_vec_mode_q         <= 'b0;
            issue_b_is_branch_q         <= 'b0;
            issue_b_is_jump_q           <= 'b0;
        end
        else begin
            issue_src0_data_q           <= issue_src0_data_lo;
            issue_src1_data_q           <= issue_src1_data_lo;
            issue_src2_data_q           <= issue_src2_data_lo;
            issue_pc_q                  <= issue_pc_lo;
            issue_itag_q                <= issue_itag_lo;
            issue_tid_q                 <= issue_tid_lo;
            issue_fu_req_q              <= issue_fu_req_lo;
            issue_fu_opc_q              <= issue_fu_opc_lo;
            issue_fu_vec_mode_q         <= 'b0;
            issue_b_is_branch_q         <= issue_b_is_branch_lo;
            issue_b_is_jump_q           <= issue_b_is_jump_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Register File
    ////////////////////////////////////////////////////////////////////////////////
    logic [TID_WIDTH_LP-1:0]        wb_tid_lo;
    logic [rf_addr_width_p-1:0]     wb_rd_addr_lo;
    logic [DATA_WIDTH_P-1:0]        wb_data_lo;
    logic                           wb_data_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_rf #(
        .NUM_THREADS_P              (NUM_THREADS_P),
        .DATA_WIDTH_P               (DATA_WIDTH_P)
    ) rf_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .tid_i                      (issue_tid_lo),
        .rs0_addr_i                 (issue_rs0_addr_lo),
        .rs0_data_o                 (rf_rs0_data_lo),
        .rs1_addr_i                 (issue_rs1_addr_lo),
        .rs1_data_o                 (rf_rs1_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_tid_i                   (wb_tid_lo),
        .rd_w_en_i                  (wb_data_vld_lo),
        .rd_addr_i                  (wb_rd_addr_lo),
        .rd_data_i                  (wb_data_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Execution stage
    ////////////////////////////////////////////////////////////////////////////////    
    logic [MRV_NUM_FU-1:0]                       exec_fu_done_lo;
    logic [MRV_NUM_FU-1:0][TID_WIDTH_LP-1:0]     exec_fu_tid_lo;
    logic [MRV_NUM_FU-1:0][ITAG_WIDTH_P-1:0]     exec_fu_wb_itag_lo;
    logic [MRV_NUM_FU-1:0][DATA_WIDTH_P-1:0]     exec_fu_wb_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_exec #(
        .PC_WIDTH_P             (PC_WIDTH_P),
        .NUM_THREADS_P          (NUM_THREADS_P),
        .DATA_WIDTH_P           (DATA_WIDTH_P),
        .ITAG_WIDTH_P           (ITAG_WIDTH_P),
        .NUM_FU_P               (MRV_NUM_FU),
        .FU_OPC_WIDTH_P         (MRV_OPC_WIDTH_P)
    ) exec_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_src0_data_i       (issue_src0_data_q),
        .exec_src1_data_i       (issue_src1_data_q),
        .exec_src2_data_i       (issue_src2_data_q),
        .exec_pc_i              (issue_pc_q),
        .exec_itag_i            (issue_itag_q),
        .exec_tid_i             (issue_tid_q),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_fu_rdy_o          (exec_fu_rdy_lo),
        .issue_fu_req_i         (issue_fu_req_q),
        .issue_fu_opc_i         (issue_fu_opc_q),
        .issue_fu_vec_mode_i    (issue_fu_vec_mode_q),
        .exec_fu_done_o         (exec_fu_done_lo),
        .exec_fu_res_data_o     (exec_fu_tid_lo),
        .exec_fu_itag_o         (exec_fu_wb_itag_lo),
        .exec_fu_tid_o          (exec_fu_wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .b_is_branch_i          (issue_b_is_branch_q),
        .b_is_jump_i            (issue_b_is_jump_q),
        .b_pc_vld_o             (exec_b_pc_vld_lo),
        .b_pc_o                 (exec_b_pc_lo),
        .b_tid_o                (exec_b_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_o           (exec_th_ctl_vld_lo),
        .th_ctl_tid_o           (exec_th_ctl_tid_lo),
        .th_ctl_tspawn_vld_o    (exec_th_ctl_tspawn_vld_lo),
        .th_ctl_tspawn_pc_o     (exec_th_ctl_tspawn_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o         (dmem_req_vld_o),
        .dmem_req_rdy_i         (dmem_req_rdy_i),
        .dmem_resp_err_i        (/* FIXME */),
        .dmem_req_addr_o        (dmem_req_addr_o),
        .dmem_req_w_en_o        (dmem_req_w_en_o),
        .dmem_req_w_be_o        (dmem_req_w_be_o),
        .dmem_req_w_data_o      (dmem_req_w_data_o),
        .dmem_resp_vld_i        (dmem_resp_vld_i),
        .dmem_resp_r_data_i     (dmem_resp_r_data_i)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Retire Stage
    ////////////////////////////////////////////////////////////////////////////////
    logic [MRV_NUM_FU-1:0]                       exec_fu_done_q;
    logic [MRV_NUM_FU-1:0][TID_WIDTH_LP-1:0]     exec_fu_tid_q;
    logic [MRV_NUM_FU-1:0][ITAG_WIDTH_P-1:0]     exec_fu_wb_itag_q;
    logic [MRV_NUM_FU-1:0][DATA_WIDTH_P-1:0]     exec_fu_wb_data_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i/* rst_down_w FIXME */) begin
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
        .NUM_THREADS_P                  (NUM_THREADS_P),
        .DATA_WIDTH_P                   (DATA_WIDTH_P),
        .ITAG_WIDTH_P                   (ITAG_WIDTH_P),
        .NUM_FU_P                       (MRV_NUM_FU),
        .NUM_RS_P                       (NUM_RS_LP)
    ) wback (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
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
        .iq_retire_rdy_i                (iq_retire_rdy_lo),
        .iq_retire_itag_i               (iq_retire_itag_lo),
        .retire_cnt_o                   (ret_retire_cnt_lo),
        .retire_tid_o                   (ret_retire_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // WBACK <-> RF
        ////////////////////////////////////////////////////////////////////////////////
        .wb_tid_o                       (wb_tid_lo),
        .wb_rd_addr_o                   (wb_rd_addr_lo),
        .wb_data_vld_o                  (wb_data_vld_lo),
        .wb_data_o                      (wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_o                  (ret_rs_conflict_lo),
        .rs_byp_en_o                    (ret_rs_byp_en_lo),
        .rs_byp_data_o                  (ret_rs_byp_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .iq_rs_conflict_i               (iq_rs_conflict_lo),
        .iq_vld_i                       (iq_vld_lo),
        .iq_rd_vld_i                    (iq_rd_vld_lo),
        .iq_rd_addr_i                   (iq_rd_addr_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule