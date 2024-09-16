module mrv1_retire #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter RETIRE_WIDTH_P = 1,
    parameter NUM_TW_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = "inv",
    parameter rf_addr_width_p = 5,
    ////////////////////////////////////////////////////////////////////////////////
    parameter tid_width_lp = $clog2(NUM_TW_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter iqueue_size_lp = (1 << ITAG_WIDTH_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter num_fu_lp = 6,
    parameter num_rs_lp = 2
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                                            clk_i,
    input  logic                                                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [num_fu_lp-1:0]                                            fu_done_i,
    input  logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]                          fu_wb_data_i,
    input  logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]                          fu_itag_i,
    input  logic [num_fu_lp-1:0][tid_width_lp-1:0]                          fu_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_TW_P-1:0]                                             retire_rdy_i,
    input  logic [NUM_TW_P-1:0][ITAG_WIDTH_P-1:0]                           retire_itag_i,
    output logic [NUM_TW_P-1:0][ITAG_WIDTH_P-1:0]                           retire_cnt_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_TW_P-1:0][iqueue_size_lp-1:0]                         iq_rd_vld_i,
    input  logic [NUM_TW_P-1:0][iqueue_size_lp-1:0][rf_addr_width_p-1:0]    iq_rd_addr_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [tid_width_lp-1:0]                                         wb_tid_o,
    output logic [rf_addr_width_p-1:0]                                      wb_rd_addr_o,
    output logic                                                            wb_data_vld_o,
    output logic [DATA_WIDTH_P-1:0]                                         wb_data_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_TW_P-1:0][rf_addr_width_p-1:0]           wb_rd_addr_r;
    logic [NUM_TW_P-1:0]                                wb_data_vld_r;
    logic [NUM_TW_P-1:0][DATA_WIDTH_P-1:0]              wb_data_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [tid_width_lp-1:0]                           ret_tid_r;
    logic [NUM_TW_P-1:0]                                ret_rdy_r;
    logic [NUM_TW_P-1:0][ITAG_WIDTH_P-1:0]              ret_cnt_r;
    ////////////////////////////////////////////////////////////////////////////////
    generate
    for (genvar i = 0; i < NUM_TW_P; i++) begin
        ////////////////////////////////////////////////////////////////////////////////
        // Retirement buffer
        ////////////////////////////////////////////////////////////////////////////////
        logic [iqueue_size_lp-1:0]                      ret_buf_vld_q, ret_buf_vld_n;
        logic [iqueue_size_lp-1:0][DATA_WIDTH_P-1:0]    ret_buf_data_q, ret_buf_data_n;
        ////////////////////////////////////////////////////////////////////////////////
        always_ff @(posedge clk_i) begin
            if (rst_i)
                ret_buf_vld_q   <= '0;
            else begin
                ret_buf_vld_q   <= ret_buf_vld_n;
                ret_buf_data_q  <= ret_buf_data_n;
            end
        end
        ////////////////////////////////////////////////////////////////////////////////
        // Calculate retire count
        ////////////////////////////////////////////////////////////////////////////////
        logic [iqueue_size_lp-1:0][ITAG_WIDTH_P-1:0] tmp0_ptr;
        logic [iqueue_size_lp-1:0] tmp_ret_buf_vld;
        logic [iqueue_size_lp-1:0][DATA_WIDTH_P-1:0] tmp_ret_buf_data;
        logic [num_fu_lp-1:0] fu_tid_match;
        ////////////////////////////////////////////////////////////////////////////////
        always_comb begin
            tmp_ret_buf_vld = ret_buf_vld_q;
            tmp_ret_buf_data = ret_buf_data_q;
            wb_data_vld_r[i] = 1'b0;
            ret_rdy_r[i] = 0;
            ret_cnt_r[i] = 0;
            ////////////////////////////////////////////////////////////////////////////////
            for (int j = 0; j < num_fu_lp; j++) begin
                fu_tid_match[j] = fu_tid_i[j] == tid_width_lp'(i);
                if (fu_done_i[j] & fu_tid_match[j]) begin
                    tmp_ret_buf_vld[fu_itag_i[j]]  = 1'b1;
                    tmp_ret_buf_data[fu_itag_i[j]] = fu_wb_data_i[j];
                end
            end
            ////////////////////////////////////////////////////////////////////////////////
            // Count instruction ready to retire
            ////////////////////////////////////////////////////////////////////////////////
            for (int j = 0; j < iqueue_size_lp; j++) begin
                tmp0_ptr[j] = retire_itag_i[i] + ITAG_WIDTH_P'(j);
                if (~tmp_ret_buf_vld[tmp0_ptr[j]]) begin
                    break;
                end
                if (iq_rd_vld_i[i][tmp0_ptr[j]]) begin
                    if (wb_data_vld_r[i]) begin
                        break;
                    end
                    wb_data_vld_r[i] = 1'b1;
                    wb_rd_addr_r[i] = iq_rd_addr_i[i][tmp0_ptr[j]];
                    wb_data_r[i] = tmp_ret_buf_data[tmp0_ptr[j]];
                end
                ret_rdy_r[i] = 1'b1;
                ret_cnt_r[i] = ret_cnt_r[i] + 1'b1;
                tmp_ret_buf_vld[tmp0_ptr[j]] = 1'b0;
            end
        end
    end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////
    // Select thread for retirement
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_TW_P-1:0] sched_tbl_q, sched_tbl_q_n;
    wire sched_any_w = (|sched_tbl_q);
    
    always_ff @(posedge clk_i) begin
        if (rst_i)  begin
            sched_tbl_q <= 0;
        end else begin
            sched_tbl_q <= sched_tbl_q_n;
        end
    end

    always_comb begin
        sched_tbl_q_n = sched_any_w ? sched_tbl_q : ret_rdy_r;
        for (int i = 0; i < NUM_TW_P; i++) begin
            if (sched_tbl_q_n[i]) begin
                ret_tid_r = tid_width_lp'(i);
                sched_tbl_q_n[i] = 0;
                break;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign wb_tid_o         = ret_tid_r;
    assign wb_rd_addr_o     = wb_rd_addr_r[ret_tid_r];
    assign wb_data_vld_o    = wb_data_vld_r[ret_tid_r];
    assign wb_data_o        = wb_data_r[ret_tid_r];
    ////////////////////////////////////////////////////////////////////////////////

endmodule
