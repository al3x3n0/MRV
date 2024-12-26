module mtra_issue_ctrl
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_OP_SOURCES_P = 5,
    ////////////////////////////////////////////////////////////////////////////////
    parameter OP_SRC_IDX_WIDTH_LP = $clog2(NUM_OP_SOURCES_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_THREADS_P-1:0]                             th_active_i,
    input logic [NUM_THREADS_P-1:0][OP_SRC_IDX_WIDTH_LP-1:0]    op_src_sel_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_THREADS_P-1:0]                            own_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                            left_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                            right_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                            top_data_vld_i,
    input  logic [NUM_THREADS_P-1:0]                            bottom_data_vld_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0]                            own_data_req_o,
    output logic [NUM_THREADS_P-1:0]                            left_data_req_o,
    output logic [NUM_THREADS_P-1:0]                            right_data_req_o,
    output logic [NUM_THREADS_P-1:0]                            top_data_req_o,
    output logic [NUM_THREADS_P-1:0]                            bottom_data_req_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        unique case (op_src_sel_i)
            '1: own_data_req_o = 1'b1;
            '2: left_data_req_o = 1'b1;
            '3: right_data_req_o = 1'b1;
            '4: top_data_req_o = 1'b1;
            '5: bottom_data_req_o = 1'b1;
            default: ;
        endcase
    end

    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0] issue_tbl_q, issue_tbl_q_n;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i)  begin
            issue_tbl_q <= 0;
        end else begin
            issue_tbl_q <= issue_tbl_q_n;
        end
    end

endmodule