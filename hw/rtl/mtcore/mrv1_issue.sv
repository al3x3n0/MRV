module mrv1_issue #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_RS_P = 2,
    parameter NUM_FU_P = "inv",
    parameter FU_OPC_WIDTH_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter rf_addr_width_p = 5,
    parameter DEC_BUF_SZ_P = 4,
    ////////////////////////////////////////////////////////////////////////////////
    parameter DEC_BUF_ADDR_WIDTH_LP = $clog2(DEC_BUF_SZ_P),
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter IQ_SZ_LP = (1 << ITAG_WIDTH_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0]                    issue_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        dec_vld_i,
    input  logic [PC_WIDTH_P-1:0]                       dec_pc_i,
    input  logic [TID_WIDTH_LP-1:0]                     dec_tid_i,
    input  logic [NUM_FU_P-1:0]                         dec_fu_req_i,
    input  logic [FU_OPC_WIDTH_P-1:0]                   dec_fu_opc_i,
    input  logic                                        dec_b_is_branch_i,
    input  logic                                        dec_b_is_jump_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  xrv_exe_src0_sel_e                           dec_src0_sel_i,
    input  xrv_exe_src1_sel_e                           dec_src1_sel_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [DATA_WIDTH_P-1:0]                     dec_imm0_i,
    input  logic [DATA_WIDTH_P-1:0]                     dec_imm1_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        dec_rs0_vld_i,
    input  logic [rf_addr_width_p-1:0]                  dec_rs0_addr_i,
    input  logic                                        dec_rs1_vld_i,
    input  logic [rf_addr_width_p-1:0]                  dec_rs1_addr_i,
    input  logic                                        dec_rd_vld_i,
    input  logic [rf_addr_width_p-1:0]                  dec_rd_addr_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        exec_b_flush_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [TID_WIDTH_LP-1:0]                     rf_tid_o,
    output logic [rf_addr_width_p-1:0]                  rs0_addr_o,
    output logic [rf_addr_width_p-1:0]                  rs1_addr_o,
    input  logic [DATA_WIDTH_P-1:0]                     rs0_data_i,
    input  logic [DATA_WIDTH_P-1:0]                     rs1_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_THREADS_P-1:0]                    rs0_byp_en_i,
    input  logic [NUM_THREADS_P-1:0]                    rs1_byp_en_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]  rs0_byp_data_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]  rs1_byp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0]                          iq_vld_o,
    output logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0]                          iq_rd_vld_o,
    output logic [NUM_THREADS_P-1:0][IQ_SZ_LP-1:0][rf_addr_width_p-1:0]     iq_rd_addr_o,
    output logic [NUM_THREADS_P-1:0][NUM_RS_P-1:0][IQ_SZ_LP-1:0]            iq_rs_conflict_o,
    output logic [NUM_THREADS_P-1:0]                                        iq_retire_rdy_o,
    output logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]                      iq_retire_itag_o,
    input  logic                                                            retire_vld_i,
    input  logic [TID_WIDTH_LP-1:0]                                         retire_tid_i,
    input  logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]                      retire_cnt_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_FU_P-1:0]                          exec_fu_rdy_i,
    input logic [NUM_FU_P-1:0]                          issue_fu_req_o,
    output logic [PC_WIDTH_P-1:0]                       issue_pc_o,
    output logic [FU_OPC_WIDTH_P-1:0]                   issue_fu_opc_o,
    output logic                                        issue_b_is_branch_o,
    output logic                                        issue_b_is_jump_o,
    output logic [DATA_WIDTH_P-1:0]                     issue_src0_data_o,
    output logic [DATA_WIDTH_P-1:0]                     issue_src1_data_o,
    output logic [DATA_WIDTH_P-1:0]                     issue_src2_data_o,
    output logic [ITAG_WIDTH_P-1:0]                     issue_itag_o,
    output logic [TID_WIDTH_LP-1:0]                     issue_tid_o
);
    ////////////////////////////////////////////////////////////////////////////////
    localparam dec_buf_width_lp =
        PC_WIDTH_P +
        NUM_FU_P + FU_OPC_WIDTH_P + 2 +
        $bits(xrv_exe_src0_sel_e) +
        $bits(xrv_exe_src1_sel_e) +
        2 * DATA_WIDTH_P +
        3 * rf_addr_width_p + 3
    ;
    ////////////////////////////////////////////////////////////////////////////////
    logic [dec_buf_width_lp-1:0] issue_insn_data_lo;
    wire [dec_buf_width_lp-1:0] decode_buf_data_li = {
        dec_pc_i,
        dec_fu_req_i,
        dec_fu_opc_i,
        dec_b_is_branch_i,
        dec_b_is_jump_i,
        dec_src0_sel_i,
        dec_src1_sel_i,
        dec_imm0_i,
        dec_imm1_i,
        dec_rs0_vld_i,
        dec_rs0_addr_i,
        dec_rs1_vld_i,
        dec_rs1_addr_i,
        dec_rd_vld_i,
        dec_rd_addr_i
    };

    ////////////////////////////////////////////////////////////////////////////////
    // Issue queues
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0] iq_rdy_lo;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0] iq_issue_itag_lo;
    logic [NUM_THREADS_P-1:0][dec_buf_width_lp-1:0] ths_dec_buf_data_lo;
    logic issue_any_w = (|issue_fu_req_o);
    generate
    for (genvar i = 0; i < NUM_THREADS_P; i++) begin
        ////////////////////////////////////////////////////////////////////////////////
        wire dec_buf_full_lo, dec_buf_empty_lo;
        wire wid_match_w = dec_tid_i == TID_WIDTH_LP'(i);
        /*FIXME*/
        wire enq_w = wid_match_w & dec_vld_i & ~dec_buf_full_lo;
        ////////////////////////////////////////////////////////////////////////////////
        logic                           dec_buf_data_vld_lo;
        logic [dec_buf_width_lp-1:0]    dec_buf_data_lo;
        logic [PC_WIDTH_P-1:0]          dec_buf_pc_lo;
        logic [NUM_FU_P-1:0]            dec_buf_fu_req_lo;
        logic [FU_OPC_WIDTH_P-1:0]      dec_buf_fu_opc_lo;
        logic                           dec_buf_b_is_branch_lo;
        logic                           dec_buf_b_is_jump_lo;
        logic [TID_WIDTH_LP-1:0]        dec_buf_tid_lo;
        xrv_exe_src0_sel_e              dec_buf_src0_sel_lo;
        xrv_exe_src1_sel_e              dec_buf_src1_sel_lo;
        logic [DATA_WIDTH_P-1:0]        dec_buf_imm0_lo;
        logic [DATA_WIDTH_P-1:0]        dec_buf_imm1_lo;
        logic                           dec_buf_rs0_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_buf_rs0_addr_lo;
        logic                           dec_buf_rs1_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_buf_rs1_addr_lo;
        logic                           dec_buf_rd_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_buf_rd_addr_lo;
        
        assign {
            dec_buf_pc_lo,
            dec_buf_fu_req_lo,
            dec_buf_fu_opc_lo,
            dec_buf_b_is_branch_lo,
            dec_buf_b_is_jump_lo,
            dec_buf_src0_sel_lo,
            dec_buf_src1_sel_lo,
            dec_buf_imm0_lo,
            dec_buf_imm1_lo,
            dec_buf_rs0_vld_lo,
            dec_buf_rs0_addr_lo,
            dec_buf_rs1_vld_lo,
            dec_buf_rs1_addr_lo,
            dec_buf_rd_vld_lo,
            dec_buf_rd_addr_lo
        } = dec_buf_data_lo;
        assign dec_buf_tid_lo = TID_WIDTH_LP'(i);
        assign ths_dec_buf_data_lo[i] = dec_buf_data_lo;

        ////////////////////////////////////////////////////////////////////////////////
        // Decode buffer
        ////////////////////////////////////////////////////////////////////////////////
        xrv_queue #(
            .q_size_p       (DEC_BUF_SZ_P),
            .data_width_p   (dec_buf_width_lp)
        ) dec_buf_i (
            ////////////////////////////////////////////////////////////////////////////////
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            ////////////////////////////////////////////////////////////////////////////////
            .enq_i          (enq_w),
            .deq_i          (/*FIXME*/),
            ////////////////////////////////////////////////////////////////////////////////
            .data_i         (decode_buf_data_li),
            ////////////////////////////////////////////////////////////////////////////////
            .data_vld_o     (dec_buf_data_vld_lo),
            .data_o         (dec_buf_data_lo),
            ////////////////////////////////////////////////////////////////////////////////
            .full_o         (dec_buf_full_lo),
            .empty_o        (dec_buf_empty_lo),
            .size_o         (/*FIXME*/)
            ////////////////////////////////////////////////////////////////////////////////
        );
        ////////////////////////////////////////////////////////////////////////////////
        wire issue_tid_match_w = issue_tid_o == TID_WIDTH_LP'(i);
        wire ret_tid_match_w = retire_tid_i == TID_WIDTH_LP'(i);
        wire issue_vld_w = issue_any_w & issue_tid_match_w;
        wire retire_cnt_w = ret_tid_match_w ? retire_cnt_i[i] : 0;
        ////////////////////////////////////////////////////////////////////////////////
        // Instruction Track Queue
        ////////////////////////////////////////////////////////////////////////////////
        xrv1_iqueue #(
            .ITAG_WIDTH_P (ITAG_WIDTH_P)
        ) iqueue (
            ////////////////////////////////////////////////////////////////////////////////
            .clk_i                      (clk_i),
            .rst_i                      (rst_i),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_rdy_o                (iq_rdy_lo[i]),
            .issue_vld_i                (issue_vld_w),
            ////////////////////////////////////////////////////////////////////////////////
            .retire_rdy_o               (iq_retire_rdy_o[i]),
            .retire_cnt_i               (retire_cnt_i[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_rs_addr_i            ({dec_buf_rs1_addr_lo, dec_buf_rs0_addr_lo}),
            .issue_rs_vld_i             ({dec_buf_rs1_vld_lo, dec_buf_rs0_vld_lo}),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_rd_addr_i            (dec_buf_rd_addr_lo),
            .issue_rd_vld_i             (dec_buf_rd_vld_lo),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_itag_o               (iq_issue_itag_lo[i]),
            .retire_itag_o              (iq_retire_itag_o[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .retire_rd_addr_vld_o       (iq_rd_vld_o[i]),
            .retire_rd_addr_o           (iq_rd_addr_o[i]),
            .rs_conflict_o              (iq_rs_conflict_o[i]),
            .iqueue_vld_o               (iq_vld_o[i]),
            .iqueue_rd_vld_o            (iq_rd_vld_o[i]),
            .iqueue_rd_addr_o           (iq_rd_addr_o[i])
        );
    end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////
    // Thread selector
    ////////////////////////////////////////////////////////////////////////////////
    logic [TID_WIDTH_LP-1:0] issue_tid_lo;
    mrv1_th_issue #(
        .NUM_THREADS_P(NUM_THREADS_P)
    ) issue_tw_sched_i (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .issue_rdy_i(iq_rdy_lo),
        .issue_tid_o(issue_tid_lo)
    );
    assign issue_insn_data_lo = ths_dec_buf_data_lo[issue_tid_lo];

    ////////////////////////////////////////////////////////////////////////////////
    // SRC MUX
    ////////////////////////////////////////////////////////////////////////////////
    logic [PC_WIDTH_P-1:0]          issue_insn_pc_lo;
    logic [NUM_FU_P-1:0]            issue_insn_fu_req_lo;
    xrv_exe_src0_sel_e              issue_insn_src0_sel_lo;
    xrv_exe_src1_sel_e              issue_insn_src1_sel_lo;
    logic [DATA_WIDTH_P-1:0]        issue_insn_imm0_lo;
    logic [DATA_WIDTH_P-1:0]        issue_insn_imm1_lo;
    logic                           issue_insn_rs0_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rs0_addr_lo;
    logic                           issue_insn_rs1_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rs1_addr_lo;
    logic                           issue_insn_rd_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rd_addr_lo;
    
    assign {
        issue_insn_pc_lo,
        issue_insn_fu_req_lo,
        issue_fu_opc_o,
        issue_b_is_branch_o,
        issue_b_is_jump_o,
        issue_insn_src0_sel_lo,
        issue_insn_src1_sel_lo,
        issue_insn_imm0_lo,
        issue_insn_imm1_lo,
        issue_insn_rs0_vld_lo,
        issue_insn_rs0_addr_lo,
        issue_insn_rs1_vld_lo,
        issue_insn_rs1_addr_lo,
        issue_insn_rd_vld_lo,
        issue_insn_rd_addr_lo
    } = issue_insn_data_lo;

    ////////////////////////////////////////////////////////////////////////////////
    // WB Stage bypass
    ////////////////////////////////////////////////////////////////////////////////
    wire rs0_x0_w = rs0_addr_o == '0;
    wire rs1_x0_w = rs1_addr_o == '0;
    wire [DATA_WIDTH_P-1:0] rs0_byp_data_w = rs0_byp_data_i[issue_tid_lo];
    wire [DATA_WIDTH_P-1:0] rs1_byp_data_w = rs1_byp_data_i[issue_tid_lo];
    wire rs0_byp_en_w = rs0_byp_en_i[issue_tid_lo];
    wire rs1_byp_en_w = rs1_byp_en_i[issue_tid_lo];
    wire [DATA_WIDTH_P-1:0] rs0_data_w = (rs0_byp_en_i & ~rs0_x0_w) ? rs0_byp_data_i : rs0_data_i;
    wire [DATA_WIDTH_P-1:0] rs1_data_w = (rs1_byp_en_i & ~rs1_x0_w) ? rs1_byp_data_i : rs1_data_i;

    mrv1_src_mux #(
        .PC_WIDTH_P     (PC_WIDTH_P),
        .DATA_WIDTH_P   (DATA_WIDTH_P)
    ) src_mux_i (
        .src0_sel_i     (issue_insn_src0_sel_lo),
        .src1_sel_i     (issue_insn_src1_sel_lo),
        .rs0_data_i     (rs0_data_w),
        .rs1_data_i     (rs1_data_w),
        .insn_imm0_i    (issue_insn_imm0_lo),
        .insn_imm1_i    (issue_insn_imm1_lo),
        .insn_pc_i      (issue_insn_pc_lo),
        .src0_data_o    (issue_src0_data_o),
        .src1_data_o    (issue_src1_data_o),
        .src2_data_o    (issue_src2_data_o)
    );

    assign issue_pc_o = issue_insn_pc_lo;

endmodule
