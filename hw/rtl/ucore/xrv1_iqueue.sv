module xrv1_iqueue
#(
    parameter rf_addr_width_p = 5,
    parameter ITAG_WIDTH_P = "inv",
    parameter iqueue_size_lp = (1 << ITAG_WIDTH_P),
    parameter num_rs_lp = 2
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                             clk_i,
    input logic                                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                            issue_rdy_o,
    input logic                                             issue_vld_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                            retire_rdy_o,
    input logic [ITAG_WIDTH_P-1:0]                          retire_cnt_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [num_rs_lp-1:0][rf_addr_width_p-1:0]        issue_rs_addr_i,
    input logic [num_rs_lp-1:0]                             issue_rs_vld_i,
    input logic [rf_addr_width_p-1:0]                       issue_rd_addr_i,
    input logic                                             issue_rd_vld_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [ITAG_WIDTH_P-1:0]                         issue_itag_o,
    output logic [ITAG_WIDTH_P-1:0]                         retire_itag_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                            retire_rd_addr_vld_o,
    output logic [rf_addr_width_p-1:0]                      retire_rd_addr_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [num_rs_lp-1:0][iqueue_size_lp-1:0]        rs_conflict_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [iqueue_size_lp-1:0]                       iqueue_vld_o,
    output logic [iqueue_size_lp-1:0]                       iqueue_rd_vld_o,
    output logic [iqueue_size_lp-1:0][rf_addr_width_p-1:0]  iqueue_rd_addr_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // IQueue data
    ////////////////////////////////////////////////////////////////////////////////
    logic [iqueue_size_lp-1:0]                              iqueue_vld_r;
    logic [iqueue_size_lp-1:0]                              iqueue_rd_vld_r;
    logic [iqueue_size_lp-1:0][rf_addr_width_p-1:0]         iqueue_rd_addr_r;
    ////////////////////////////////////////////////////////////////////////////////
    assign iqueue_vld_o     = iqueue_vld_r;
    assign iqueue_rd_vld_o  = iqueue_rd_vld_r;
    assign iqueue_rd_addr_o = iqueue_rd_addr_r;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // IQueue control
    ////////////////////////////////////////////////////////////////////////////////
    logic [ITAG_WIDTH_P:0] iq_sz_q, iq_sz_n_r;
    logic [ITAG_WIDTH_P-1:0] issue_ptr_r, issue_ptr_n;
    logic [ITAG_WIDTH_P-1:0] retire_ptr_r, retire_ptr_n;
    ////////////////////////////////////////////////////////////////////////////////
    wire iqueue_full = iq_sz_q == iqueue_size_lp;
    wire iqueue_empty = iq_sz_q == 'b0;
    ////////////////////////////////////////////////////////////////////////////////
    assign retire_rdy_o = ~iqueue_empty;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            issue_ptr_r         <= 'b0;
            retire_ptr_r        <= 'b0;
            iq_sz_q             <= 'b0;
            iqueue_vld_r        <= 'b0;
            iqueue_rd_vld_r     <= 'b0;
            iqueue_rd_addr_r    <= 'b0;
        end
        else begin
            issue_ptr_r       <= issue_ptr_n;
            retire_ptr_r      <= retire_ptr_n;
            iq_sz_q           <= iq_sz_n_r;
            iqueue_vld_r      <= iqueue_vld_n_r;
            iqueue_rd_vld_r   <= iqueue_rd_vld_n_r;
            if (issue_vld_i) begin
                iqueue_rd_addr_r[issue_ptr_r] <= issue_rd_addr_i;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    logic [iqueue_size_lp-1:0] iqueue_vld_n_r;
    logic [iqueue_size_lp-1:0] iqueue_rd_vld_n_r;
    logic [ITAG_WIDTH_P-1:0] tmp_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        iq_sz_n_r = iq_sz_q;
        issue_ptr_n = issue_ptr_r;
        retire_ptr_n = retire_ptr_r;
        iqueue_vld_n_r = iqueue_vld_r;
        iqueue_rd_vld_n_r = iqueue_rd_vld_r;
        for (tmp_r = 0; tmp_r < retire_cnt_i; tmp_r = tmp_r + 1'b1) begin
            iqueue_vld_n_r[retire_ptr_n] = 1'b0;
            iqueue_rd_vld_n_r[retire_ptr_n] = 1'b0;
            retire_ptr_n = retire_ptr_n + 1'b1;
            iq_sz_n_r = iq_sz_n_r - 1'b1;
        end
        if (issue_vld_i) begin
            iqueue_vld_n_r[issue_ptr_r] = 1'b1;
            iqueue_rd_vld_n_r[issue_ptr_r] = issue_rd_vld_i;
            issue_ptr_n = issue_ptr_r + 1'b1;
            iq_sz_n_r = iq_sz_n_r + 1'b1;
        end
        $display("iq_sz_n_r: %d retire_cnt_i:%d retire_ptr_n:%d",
            iq_sz_n_r, retire_cnt_i, retire_ptr_n);
    end
    ////////////////////////////////////////////////////////////////////////////////
    genvar i, j;
    generate
        for (j=0; j < num_rs_lp; j=j+1) begin
            for (i=0; i < iqueue_size_lp; i=i+1) begin
                assign rs_conflict_o[j][i] = issue_rs_vld_i[j]
                    & iqueue_vld_r[i]
                    & iqueue_rd_vld_r[i]
                    & issue_rs_addr_i[j] == iqueue_rd_addr_r[i];
            end
        end
    endgenerate
    /////////////////////////////////////////////////////////////////////////
    assign issue_rdy_o   = ~iqueue_full;
    assign issue_itag_o  = issue_ptr_r;
    assign retire_itag_o = retire_ptr_r;
    ////////////////////////////////////////////////////////////////////////////////
    assign retire_rd_addr_vld_o = iqueue_rd_vld_r[retire_ptr_r];
    assign retire_rd_addr_o     = iqueue_rd_addr_r[retire_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////

endmodule
