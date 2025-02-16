module xra_retire #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter RETIRE_WIDTH_P = 1,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = "inv",
    parameter NUM_FU_P = "inv",
    parameter NUM_RS_P = 2,
    ////////////////////////////////////////////////////////////////////////////////
    parameter RF_ADDR_WIDTH_LP = `XM_CLOG2(NUM_GPRS),
    parameter DST_WIDTH_LP = `XM_MAX(MTRA_DST_NUM, RF_ADDR_WIDTH_LP),
    parameter IQ_SZ_LP = (1 << ITAG_WIDTH_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            clk_i,
    input  logic                                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_FU_P-1:0]                             fu_done_i,
    input  logic [NUM_FU_P-1:0][DATA_WIDTH_P-1:0]           fu_wb_data_i,
    input  logic [NUM_FU_P-1:0][ITAG_WIDTH_P-1:0]           fu_itag_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            iq_retire_rdy_i,
    input  logic [ITAG_WIDTH_P-1:0]                         iq_retire_itag_i,
    output logic [ITAG_WIDTH_P-1:0]                         retire_cnt_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [IQ_SZ_LP-1:0]                             iq_vld_i,
    input  logic [IQ_SZ_LP-1:0]                             iq_dst_vld_i,
    input  logic [IQ_SZ_LP-1:0][DST_WIDTH_LP-1:0]           iq_dst_i,
    input  logic [IQ_SZ_LP-1:0]                             iq_dst_is_lrf_i,
    input  logic [NUM_RS_P-1:0][IQ_SZ_LP-1:0]               iq_rs_conflict_i,
    ////////////////////////////////////////////////////////////////////////////////
    // -> MTRA Mesh
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [MTRA_DST_NUM-1:0]                         out_buf_rdy_i,
    output logic [MTRA_DST_NUM-1:0]                         out_buf_data_rdy_o,
    output logic [MTRA_DST_NUM-1:0]                         out_buf_data_vld_o,
    output logic [MTRA_DST_NUM-1:0][DATA_WIDTH_P-1:0]       out_buf_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    // -> LRF
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                            wb_rd_wr_en_o,
    output logic [RF_ADDR_WIDTH_LP-1:0]                     wb_rd_addr_o,                           
    output logic [DATA_WIDTH_P-1:0]                         wb_rd_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    // -> Exec Bypass
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0][NUM_RS_P-1:0]                          rs_conflict_o,
    output logic [NUM_THREADS_P-1:0][NUM_RS_P-1:0]                          rs_byp_en_o,
    output logic [NUM_THREADS_P-1:0][NUM_RS_P-1:0][DATA_WIDTH_P-1:0]        rs_byp_data_o,
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [RF_ADDR_WIDTH_LP-1:0]          wb_rd_addr_r;
    logic                                wb_data_vld_r;
    logic [DATA_WIDTH_P-1:0]             wb_data_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [TID_WIDTH_LP-1:0]                                ret_tid_r;
    logic [NUM_THREADS_P-1:0]                               ret_rdy_r;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]             ret_cnt_r;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Retirement buffer
    ////////////////////////////////////////////////////////////////////////////////
    logic [IQ_SZ_LP-1:0]                      ret_buf_vld_q, ret_buf_vld_n;
    logic [IQ_SZ_LP-1:0][DATA_WIDTH_P-1:0]    ret_buf_data_q, ret_buf_data_n;
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
    logic [IQ_SZ_LP-1:0][ITAG_WIDTH_P-1:0] tmp0_ptr;
    logic [NUM_FU_P-1:0] fu_tid_match;
    logic [IQ_SZ_LP-1:0][MTRA_DST_NUM-1:0] has_dst_w;
    logic [MTRA_DST_NUM-1:0] data_vld_n;

    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        ret_buf_vld_n = ret_buf_vld_q;
        ret_buf_data_n = ret_buf_data_q;
        wb_data_vld_r[i] = 1'b0;
        wb_rd_addr_r[i] = '0;
        wb_data_r[i] = '0;
        ret_rdy_r[i] = '0;
        ret_cnt_r[i] = '0;
        tmp0_ptr = '0;
        ////////////////////////////////////////////////////////////////////////////////
        for (int j = 0; j < NUM_FU_P; j++) begin
            if (fu_done_i[j]) begin
                ret_buf_vld_n[fu_itag_i[j]]  = 1'b1;
                ret_buf_data_n[fu_itag_i[j]] = fu_wb_data_i[j];
            end
        end
        ////////////////////////////////////////////////////////////////////////////////
        // Count instruction ready to retire
        ////////////////////////////////////////////////////////////////////////////////
        for (int j = 0; j < IQ_SZ_LP; j++) begin
            tmp0_ptr[j] = iq_retire_itag_i + ITAG_WIDTH_P'(j);
            if (~ret_buf_vld_n[tmp0_ptr[j]]) begin
                break;
            end

            if (iq_dst_vld_i[tmp0_ptr[j]]) begin

                for (int k = 0; k < MTRA_DST_NUM; k++) begin
                    if (iq_dst_i[i][j][k] && out_buf_rdy_i[k] && ~data_vld_n[k]) begin
                        data_vld_n[k] = ~iq_dst_is_lrf_i[tmp0_ptr[j]];
                        data_o[k] = ret_buf_data_n[tmp0_ptr[j]];
                        break;
                    end
                end

                if (wb_data_vld_r) begin
                    break;
                end
                wb_data_vld_r = 1'b1;
                wb_rd_addr_r = iq_rd_addr_i[i][tmp0_ptr[j]];
                wb_data_r = ret_buf_data_n[tmp0_ptr[j]];
            end
            ret_rdy_r = 1'b1;
            ret_cnt_r = ret_cnt_r + 1'b1;
            ret_buf_vld_n[tmp0_ptr[j]] = 1'b0;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign retire_cnt_o = ret_cnt_r;


    ////////////////////////////////////////////////////////////////////////////////
    assign wb_rd_addr_o     = wb_rd_addr_r;
    assign lrf_data_vld_o   = wb_data_vld_r && retire_vld_w;
    assign lrf_data_o       = wb_data_r;
    assign retire_tid_o     = ret_tid_r;
    ////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        for (int i = 0; i < NUM_FU_P; i++) begin
            if (fu_done_i[i]) begin
                $display("[RETIRE] T%d: FU[%d] itag=%h data=%h", fu_tid_i[i], i, fu_itag_i[i], fu_wb_data_i[i]);
            end
        end
        if (lrf_data_vld_o) begin
            $display("[WRITEBACK] T%d: r[%d] <- %h iq_rd_addr_i=%h", lrf_tid_o, wb_rd_addr_o, lrf_data_o, iq_rd_addr_i);
        end
    end

endmodule
