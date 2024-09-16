////////////////////////////////////////////////////////////////////////////////
// Issue-stage thread selector
////////////////////////////////////////////////////////////////////////////////

module mrv1_th_issue
#(
    parameter NUM_THREADS_P = 8,
    parameter ISSUE_WIDTH_P = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter tid_width_lp = $clog2(NUM_THREADS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        clk_i,
    input  logic                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_THREADS_P-1:0]          issue_rdy_i,
    output logic [tid_width_lp-1:0]    issue_tid_o
    ////////////////////////////////////////////////////////////////////////////////
);

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
    ////////////////////////////////////////////////////////////////////////////////
    wire issue_any_w = (|issue_tbl_q);
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        issue_tbl_q_n = issue_any_w ? issue_tbl_q : issue_rdy_i;
        for (int i = 0; i < NUM_THREADS_P; i++) begin
            if (issue_tbl_q_n[i]) begin
                issue_tid_o = tid_width_lp'(i);
                issue_tbl_q_n[i] = 0;
                break;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule