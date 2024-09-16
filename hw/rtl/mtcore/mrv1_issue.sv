import xrvs_pkg::*;

module mrv1_issue #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter rf_addr_width_p = 5,
    parameter isq_size_p = 4,
    ////////////////////////////////////////////////////////////////////////////////
    parameter num_fu_lp = 6,
    ////////////////////////////////////////////////////////////////////////////////
    parameter num_rs_lp = 2,
    parameter isq_addr_width_lp = $clog2(isq_size_p),
    parameter tid_width_lp = $clog2(NUM_THREADS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0]                         issue_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        dec_vld_i,
    input  logic [31:0]                                 dec_pc_i,
    input  logic [tid_width_lp-1:0]                    dec_tid_i,
    input  mrv_fu_type_e                                dec_fu_type_i,
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
    output logic [tid_width_lp-1:0]                    rf_tid_o,
    output logic [rf_addr_width_p-1:0]                  rs0_addr_o,
    output logic [rf_addr_width_p-1:0]                  rs1_addr_o,
    input  logic [DATA_WIDTH_P-1:0]                     rs0_data_i,
    input  logic [DATA_WIDTH_P-1:0]                     rs1_data_i,
    input  logic                                        rs0_byp_en_i,
    input  logic                                        rs1_byp_en_i,
    input  logic [DATA_WIDTH_P-1:0]                     rs0_byp_data_i,
    input  logic [DATA_WIDTH_P-1:0]                     rs1_byp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [31:0]                                 issue_pc_o,
    output logic [tid_width_lp-1:0]                     issue_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [num_fu_lp-1:0]                         exec_fu_rdy_i;
    input logic [num_fu_lp-1:0]                         issue_fu_req_o;
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]                     issue_src0_data_o,
    output logic [DATA_WIDTH_P-1:0]                     issue_src1_data_o,
    output logic [DATA_WIDTH_P-1:0]                     issue_src2_data_o,
    output logic [ITAG_WIDTH_P-1:0]                     issue_itag_o.
    ////////////////////////////////////////////////////////////////////////////////
    //alu_t                                             issue_alu_o,
    //lsu_t                                             issue_lsu_o,
    //mul_t                                             issue_mul_o,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        issue_lsu_req_w_en_o,
    output logic [1:0]                                  issue_lsu_req_size_o,
    output logic                                        issue_lsu_req_signed_o,
    ////////////////////////////////////////////////////////////////////////////////
    //csr_t                                             issue_csr_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    localparam dec_buf_width_lp =
        32 +
        $bits(xrv_exe_src0_sel_e) +
        $bits(xrv_exe_src1_sel_e) +
        2 * DATA_WIDTH_P +
        3 * rf_addr_width_p + 3 +
        $bits(xrv_alu_op_e) + 1
    ;
    ////////////////////////////////////////////////////////////////////////////////
    logic [dec_buf_width_lp-1:0] issue_insn_data_lo;
    wire [dec_buf_width_lp-1:0] decode_buf_data_li = {
        dec_pc_i,
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
    ////////////////////////////////////////////////////////////////////////////////
    generate
    for (genvar i = 0; i < NUM_THREADS_P; i++) begin
        ////////////////////////////////////////////////////////////////////////////////
        wire dec_buf_full_lo, dec_buf_empty_lo;
        wire wid_match_w = dec_tid_i == tid_width_lp'(i);
        /*FIXME*/
        wire enq_w = wid_match_w & dec_vld_i & ~dec_buf_full_lo;
        ////////////////////////////////////////////////////////////////////////////////
        logic                           dec_buf_data_vld_lo;
        logic [dec_buf_width_lp-1:0]    dec_buf_data_lo;
        logic [31:0]                    dec_buf_pc_lo;
        logic [tid_width_lp-1:0]       dec_buf_tid_lo;
        xrv_exe_src0_sel_e              dec_src0_sel_lo;
        xrv_exe_src1_sel_e              dec_src1_sel_lo;
        logic [DATA_WIDTH_P-1:0]        dec_imm0_lo;
        logic [DATA_WIDTH_P-1:0]        dec_imm1_lo;
        logic                           dec_rs0_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_rs0_addr_lo;
        logic                           dec_rs1_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_rs1_addr_lo;
        logic                           dec_rd_vld_lo;
        logic [rf_addr_width_p-1:0]     dec_rd_addr_lo;
        assign {
            dec_buf_pc_lo,
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
        dec_buf_tid_lo = tid_width_lp'(i);
        ////////////////////////////////////////////////////////////////////////////////
        // Decode buffer
        ////////////////////////////////////////////////////////////////////////////////
        xrv_queue #(
            .q_size_p       (isq_size_p),
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
        wire issue_tid_match_w = issue_tid_i == tid_width_lp'(i);
        wire ret_tid_match_w = retire_tid_i == tid_width_lp'(i);
        wire issue_vld_w = issue_vld_i & issue_tid_match_w;
        wire retire_cnt_w = ret_tid_match_w ? retire_cnt_i : 0;
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
            .retire_rdy_o               (iq_retire_rdy_lo),
            .retire_cnt_i               (/* FIXME */),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_rs_addr_i            ({dec_buf_rs1_addr_lo, dec_buf_rs0_addr_lo}),
            .issue_rs_vld_i             ({dec_buf_rs1_vld_lo, dec_buf_rs0_vld_lo}),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_rd_addr_i            (dec_buf_rd_addr_lo),
            .issue_rd_vld_i             (dec_buf_rd_vld_lo),
            ////////////////////////////////////////////////////////////////////////////////
            .issue_itag_o               (iq_issue_itag_lo[i]),
            .retire_itag_o              (iq_retire_itag_lo[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .retire_rd_addr_vld_o       (iq_retire_rd_addr_vld_lo),
            .retire_rd_addr_o           (iq_retire_rd_addr_lo),
            ////////////////////////////////////////////////////////////////////////////////
            .rs_conflict_o              (iq_rs_conflict_lo),
            .iqueue_vld_o               (iq_vld_lo),
            .iqueue_rd_vld_o            (iq_rd_vld_lo),
            .iqueue_rd_addr_o           (iq_rd_addr_lo)
        );
    end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////
    // Thread selector
    ////////////////////////////////////////////////////////////////////////////////
    logic [tid_width_lp-1:0] issue_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_tw_issue #(
        .NUM_THREADS_P(NUM_THREADS_P)
    ) issue_tw_sched_i (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .issue_rdy_i(iq_rdy_lo),
        .issue_tid_o(issue_tid_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    assign issue_insn_data_lo = dec_buf_data_lo[issue_tid_lo];
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // SRC MUX
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    issue_insn_pc_lo;
    logic [tid_width_lp-1:0]       issue_insn_tid_lo;
    xrv_exe_src0_sel_e              issue_insn_src0_sel_lo;
    xrv_exe_src1_sel_e              issue_insn_src1_sel_lo;
    logic [DATA_WIDTH_P-1:0]        issue_insn_imm0_lo;
    logic [DATA_WIDTH_P-1:0]        issue_insn_imm1_lo;
    logic                           issue_insn_s0_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rs0_addr_lo;
    logic                           issue_insn_rs1_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rs1_addr_lo;
    logic                           issue_insn_rd_vld_lo;
    logic [rf_addr_width_p-1:0]     issue_insn_rd_addr_lo;
    assign {
        issue_insn_pc_lo,
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
    mrv1_src_mux #(
        .DATA_WIDTH_P(DATA_WIDTH_P)
    ) src_mux_i (
        .src0_sel_i(issue_insn_src0_sel_lo),
        .src1_sel_i(issue_insn_src1_sel_lo)
        .rs0_data_i(rs0_data_w),
        .rs1_data_i(rs1_data_w),
        .insn_imm0_i(issue_insn_imm0_lo),
        .insn_imm1_i(issue_insn_imm1_lo),
        .insn_pc_i(issue_insn_pc_lo),
        .src0_data_o(issue_src0_data_o),
        .src1_data_o(issue_src1_data_o),
        .src2_data_o(issue_src2_data_o)
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule
