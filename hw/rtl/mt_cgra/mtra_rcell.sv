module mtra_rcell
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
    parameter BE_WIDTH_LP = DATA_WIDTH_P / 8
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                                    clk_i,
    input  logic                                                    rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              own_data_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              left_data_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              right_data_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              top_data_i,
    input  logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              bottom_data_i,
    input  logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               own_flags_i,
    input  logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               left_flags_i,
    input  logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               right_flags_i,
    input  logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               top_flags_i,
    input  logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               bottom_flags_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_THREADS_P-1:0]                                own_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                left_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                right_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                top_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                bottom_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                own_flags_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                left_flags_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                right_flags_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                top_flags_vld_i,
    input  logic [NUM_THREADS_P-1:0]                                bottom_flags_vld_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]              data_o,
    output logic [NUM_THREADS_P-1:0][NUM_FLAGS_P-1:0]               flags_o,
    output logic [NUM_THREADS_P-1:0]                                data_vld_o,
    output logic [NUM_THREADS_P-1:0]                                flags_vld_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                                    dmem_req_vld_o,
    input  logic                                                    dmem_req_rdy_i,
    output logic [DMEM_TAG_WIDTH_P-1:0]                             dmem_req_tag_o,
    input  logic                                                    dmem_resp_err_i,
    output logic [DATA_WIDTH_P-1:0]                                 dmem_req_addr_o,
    output logic                                                    dmem_req_w_en_o,
    output logic [BE_WIDTH_LP-1:0]                                  dmem_req_w_be_o,
    output logic [DATA_WIDTH_P-1:0]                                 dmem_req_w_data_o,
    input  logic                                                    dmem_resp_vld_i,
    input  logic [DATA_WIDTH_P-1:0]                                 dmem_resp_r_data_i,
    input  logic [DMEM_TAG_WIDTH_P-1:0]                             dmem_resp_tag_i
    ////////////////////////////////////////////////////////////////////////////////

);
    ////////////////////////////////////////////////////////////////////////////////
    // IFetch
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0][INSTR_WIDTH_P-1:0]    instr_data_lo;
    logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]       instr_pc_lo;
    logic [NUM_THREADS_P-1:0]                       instr_vld_lo;

    mtra_ifetch #(
        .NUM_THREADS_P              (NUM_THREADS_P)
    ) if_i (
        .clk_i                      (),
        .rst_i                      (),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_wr_en_i               (),
        .imem_wr_addr_i             (),
        .imem_wr_data_i             (),
        .instr_data_o               (instr_data_lo),
        .instr_pc_o                 (instr_pc_lo),
        .instr_vld_o                (instr_vld_lo)
    );

    mtra_lrf #(
        .DATA_WIDTH_P (DATA_WIDTH_P)
    ) lrf_i (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
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
        if (rst_i /* rst_down_w */) begin
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

endmodule