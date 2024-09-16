module xrv_queue #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter q_size_p = "inv",
    parameter data_width_p = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter q_addr_width_lp = $clog2(q_size_p)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            clk_i,
    input  logic                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            enq_i,
    input  logic                            deq_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [data_width_p-1:0]         data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                            data_vld_o,
    output logic [data_width_p-1:0]         data_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                            full_o,
    output logic                            empty_o,
    output logic [q_addr_width_lp:0]        size_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [q_size_p-1:0][data_width_p-1:0]    q_data_q;
    logic [q_size_p-1:0]                      q_data_vld_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [q_addr_width_lp:0]                 q_size_q, q_size_n_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [q_addr_width_lp-1:0]               q_w_ptr_q;
    logic [q_addr_width_lp-1:0]               q_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////
    wire [q_addr_width_lp:0] q_w_ptr_p1_w = q_w_ptr_q + 1'b1;
    wire [q_addr_width_lp:0] q_r_ptr_p1_w = q_r_ptr_q + 1'b1;
    ////////////////////////////////////////////////////////////////////////////////
    wire [q_addr_width_lp-1:0] q_w_ptr_n_wrp_w = (q_w_ptr_p1_w == q_size_p ? '0 : q_addr_width_lp'(q_w_ptr_p1_w));
    wire [q_addr_width_lp-1:0] q_r_ptr_n_wrp_w = (q_r_ptr_p1_w == q_size_p ? '0 : q_addr_width_lp'(q_r_ptr_p1_w));
    ////////////////////////////////////////////////////////////////////////////////
    wire [q_addr_width_lp-1:0] q_w_ptr_n_w = enq_i ? q_w_ptr_n_wrp_w : q_w_ptr_q;
    wire [q_addr_width_lp-1:0] q_r_ptr_n_w = deq_i ? q_r_ptr_n_wrp_w : q_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            q_size_q     <= 'b0;
            q_w_ptr_q    <= 'b0;
            q_r_ptr_q    <= 'b0;
            q_data_vld_q <= 'b0;
        end
        else begin
            if (deq_i) begin
                q_data_vld_q[q_r_ptr_q]     <= 1'b0;
            end
            if (enq_i) begin
                q_data_q[q_w_ptr_q]         <= data_i;
                q_data_vld_q[q_w_ptr_q]     <= 1'b1;
            end
            q_size_q                        <= q_size_n_r;
            q_w_ptr_q                       <= q_w_ptr_n_w;
            q_r_ptr_q                       <= q_r_ptr_n_w;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign data_vld_o   = q_data_vld_q[q_r_ptr_q];
    assign data_o       = q_data_q[q_r_ptr_q];
    ////////////////////////////////////////////////////////////////////////////////
    assign full_o       = q_size_q == q_size_p;
    assign empty_o      = q_size_q == 'b0;
    assign size_o       = q_size_q;
    ////////////////////////////////////////////////////////////////////////////////
endmodule