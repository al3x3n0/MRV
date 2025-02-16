module xra_rcell
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter NUM_FLAGS_P = 4,
    parameter PC_WIDTH_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter COL_ID_P = "inv",
    parameter ROW_ID_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter BUFFER_SIZE_P = 2,
    ////////////////////////////////////////////////////////////////////////////////
    parameter BE_WIDTH_LP = DATA_WIDTH_P / 8
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            clk_i,
    input  logic                                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [XRA_DST_NUM-1:0][DATA_WIDTH_P-1:0]        data_i,
    input  logic [XRA_DST_NUM-1:0][NUM_FLAGS_P-1:0]         flags_i,
    input  logic [XRA_DST_NUM-1:0]                          data_vld_i,
    input  logic [XRA_DST_NUM-1:0]                          flags_vld_i,
    input  logic [XRA_DST_NUM-1:0]                          data_rdy_i,
    output logic [XRA_DST_NUM-1:0]                          data_vld_o,
    output logic [XRA_DST_NUM-1:0][DATA_WIDTH_P-1:0]        data_o,
    output logic [XRA_DST_NUM-1:0]                          flags_vld_o,
    output logic [XRA_DST_NUM-1:0][NUM_FLAGS_P-1:0]         flags_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                vx_mode_en_i,
    xra_vx_lsu_mem_if.master    vx_lsu_mem_if,
    xra_vx_dispatch_if.slave    vx_dispatch_if,
    xra_vx_commit_if.master     vx_commit_if
    ////////////////////////////////////////////////////////////////////////////////

);
    ////////////////////////////////////////////////////////////////////////////////
    // IFetch
    ////////////////////////////////////////////////////////////////////////////////
    logic [INSTR_WIDTH_P-1:0]   instr_data_lo;
    logic [PC_WIDTH_P-1:0]      instr_pc_lo;
    logic                       instr_vld_lo;

    xra_ifetch #(
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) if_i (
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_wr_en_i               (),
        .imem_wr_addr_i             (),
        .imem_wr_data_i             (),
        .instr_data_o               (instr_data_lo),
        .instr_pc_o                 (instr_pc_lo),
        .instr_vld_o                (instr_vld_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_PE_SRC_P-1:0][LRF_ADDR_WIDTH_LP-1:0]     issue_rs_addr_lo;
    logic [NUM_PE_SRC_P-1:0][DATA_WIDTH_P-1:0]          issue_rs_data_li;

    ////////////////////////////////////////////////////////////////////////////////
    // LRF
    ////////////////////////////////////////////////////////////////////////////////
    xra_lrf #(
        .DATA_WIDTH_P           (DATA_WIDTH_P),
        .NUM_GPRS_P             (NUM_GPRS_P)
    ) lrf_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_addr_i              (issue_rs_addr_lo),
        .rs_data_o              (issue_rs_data_li),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_wr_en_i             (wb_rd_wr_en_lo),
        .rd_addr_i              (wb_rd_addr_lo),                           
        .rd_data_i              (wb_rd_data_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Stage 2
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]            issue_src0_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src1_data_q;
    logic [DATA_WIDTH_P-1:0]            issue_src2_data_q;
    logic [ITAG_WIDTH_P-1:0]            issue_itag_q;
    logic [TID_WIDTH_LP-1:0]            issue_tid_q;
    logic [MRV_NUM_FU-1:0]              issue_fu_req_q;
    logic [MRV_OPC_WIDTH_P-1:0]         issue_fu_opc_q;
    mrv_vec_mode_e                      issue_fu_vec_mode_q;
    logic                               issue_b_is_branch_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i /* rst_dself_w */) begin
            issue_src0_data_q           <= 'b0;
            issue_src1_data_q           <= 'b0;
            issue_src2_data_q           <= 'b0;
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
            issue_itag_q                <= issue_itag_lo;
            issue_tid_q                 <= issue_tid_lo;
            issue_fu_req_q              <= issue_fu_req_lo;
            issue_fu_opc_q              <= issue_fu_opc_lo;
            issue_fu_vec_mode_q         <= 'b0;
            issue_b_is_branch_q         <= issue_b_is_branch_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    xra_execute #(
        .DATA_WIDTH_P           (DATA_WIDTH_P),
    ) exec_i (

    );

    ////////////////////////////////////////////////////////////////////////////////
    logic [XRA_DST_NUM-1:0]                     out_buf_rdy_lo;
    logic [XRA_DST_NUM-1:0]                     out_buf_data_vld_lo;
    logic [XRA_DST_NUM-1:0][DATA_WIDTH_P-1:0]   out_buf_data_lo;

    logic                                        wb_rd_wr_en_lo;
    logic [LRF_ADDR_WIDTH_LP-1:0]                 wb_rd_addr_lo;
    logic [DATA_WIDTH_P-1:0]                     wb_rd_data_lo;

    xra_retire #(
        .DATA_WIDTH_P           (DATA_WIDTH_P),
    ) retire_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fu_done_i              (),
        .fu_wb_data_i           (),
        .fu_itag_i              (),
        .fu_tid_i               (),
        ////////////////////////////////////////////////////////////////////////////////
        // -> LRF
        ////////////////////////////////////////////////////////////////////////////////
        .lrf_data_vld_o         (lrf_data_vld_lo),
        .lrf_data_o             (lrf_data_lo),
        .lrf_tid_o              (lrf_tid_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // -> Mesh buffers
        ////////////////////////////////////////////////////////////////////////////////
        .out_buf_rdy_i          (out_buf_rdy_lo),
        .data_vld_o             (out_buf_data_vld_lo),
        .data_o                 (out_buf_data_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // -> MTRA mesh
    ////////////////////////////////////////////////////////////////////////////////
    generate
    for (int k = 0; k < XRA_DST_NUM; k++) begin
        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .SIZE_P         (BUFFER_SIZE_P),
        ) out_buf_i (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (out_buf_data_vld_lo[k]),
            .rdy_i          (out_buf_rdy_lo[k]),
            .data_i         (out_buf_data_lo[k]),
            .data_o         (data_o[k]),
            .rdy_o          (data_rdy_i[k]),
            .vld_o          (data_vld_o[k])
        );
    end
    endgenerate

endmodule