module xrv1_ifq
#(
    parameter ifq_size_p = 3,
    parameter ifq_addr_width_lp = $clog2(ifq_size_p)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                 clk_i,
    input logic                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                 enqueue_i,
    input logic                 dequeue_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [31:0]          fetch_data_i,
    input logic [31:0]          fetch_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                fetch_data_vld_o,
    output logic [31:0]         fetch_data_o,
    output logic [31:0]         fetch_pc_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                empty_o,
    output logic                full_o,
    output logic                almost_full_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [ifq_size_p-1:0][31:0]                ifq_insn_data_q;
    logic [ifq_size_p-1:0][31:0]                ifq_insn_pc_q;
    logic [ifq_size_p-1:0]                      ifq_insn_vld_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [ifq_addr_width_lp:0]                 ifq_size_q;
    logic [ifq_addr_width_lp:0]                 ifq_size_n_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [ifq_addr_width_lp-1:0]               ifq_w_ptr_q;
    logic [ifq_addr_width_lp-1:0]               ifq_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////
    wire [ifq_addr_width_lp:0] ifq_w_ptr_p1_w = ifq_w_ptr_q + 1'b1;
    wire [ifq_addr_width_lp:0] ifq_r_ptr_p1_w = ifq_r_ptr_q + 1'b1;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    wire [ifq_addr_width_lp-1:0] ifq_w_ptr_n_wrp_w = (ifq_w_ptr_p1_w == ifq_size_p ? '0 : ifq_addr_width_lp'(ifq_w_ptr_p1_w));
    wire [ifq_addr_width_lp-1:0] ifq_r_ptr_n_wrp_w = (ifq_r_ptr_p1_w == ifq_size_p ? '0 : ifq_addr_width_lp'(ifq_r_ptr_p1_w));
    ////////////////////////////////////////////////////////////////////////////////
    wire [ifq_addr_width_lp-1:0] ifq_w_ptr_n_w = enqueue_i ? ifq_w_ptr_n_wrp_w : ifq_w_ptr_q;
    wire [ifq_addr_width_lp-1:0] ifq_r_ptr_n_w = dequeue_i ? ifq_r_ptr_n_wrp_w : ifq_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (enqueue_i & ~dequeue_i)
            ifq_size_n_r = ifq_size_q + 1'b1;
        else if (~enqueue_i & dequeue_i)
            ifq_size_n_r = ifq_size_q - 1'b1;
        else
            ifq_size_n_r = ifq_size_q;
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ifq_size_q     <= 'b0;
            ifq_w_ptr_q    <= 'b0;
            ifq_r_ptr_q    <= 'b0;
        end
        else begin
            ifq_size_q  <= ifq_size_n_r;
            ifq_w_ptr_q <= ifq_w_ptr_n_w;
            ifq_r_ptr_q <= ifq_r_ptr_n_w;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ifq_insn_vld_q <= 'b0;
        end
        else begin
            if (dequeue_i & ~(full_o & enqueue_i)) begin
                ifq_insn_vld_q[ifq_r_ptr_q]  <= 1'b0;
            end
            if (enqueue_i) begin
                ifq_insn_data_q[ifq_w_ptr_q] <= fetch_data_i;
                ifq_insn_pc_q[ifq_w_ptr_q]   <= fetch_pc_i;
                ifq_insn_vld_q[ifq_w_ptr_q]  <= 1'b1;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    assign fetch_pc_o = ifq_insn_pc_q[ifq_r_ptr_q];
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] fetch_data_0_w = ifq_insn_data_q[ifq_r_ptr_q];
    wire [31:0] fetch_data_1_w = ifq_insn_data_q[ifq_r_ptr_n_wrp_w];
    wire fetch_data_0_vld_w = ifq_insn_vld_q[ifq_r_ptr_q];
    wire fetch_data_1_vld_w = ifq_insn_vld_q[ifq_r_ptr_n_wrp_w];
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        $display("ifq_size_q=%d r_ptr=%d w_ptr=%d e=%d d=%d af=%d",
            ifq_size_q, ifq_r_ptr_q, ifq_w_ptr_q, enqueue_i, dequeue_i, almost_full_o);
        $display("ifq[0]=%h", ifq_insn_pc_q[0]);
        $display("ifq[1]=%h", ifq_insn_pc_q[1]);
        $display("ifq[2]=%h", ifq_insn_pc_q[2]);
    end

    ////////////////////////////////////////////////////////////////////////////////
    xrv1_ialigner ialigner_i (
        ////////////////////////////////////////////////////////////////////////////////
        .i_data_0_i             (fetch_data_0_w),
        .i_data_0_vld_i         (fetch_data_0_vld_w),
        .i_data_1_i             (fetch_data_1_w),
        .i_data_1_vld_i         (fetch_data_1_vld_w),
        .unalgn_pc_i            (fetch_pc_o[1]),
        ////////////////////////////////////////////////////////////////////////////////
        .i_data_o               (fetch_data_o),
        .i_data_vld_o           (fetch_data_vld_o)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    assign empty_o       = ifq_size_q == '0;
    assign full_o        = ifq_size_q == 'd3;
    assign almost_full_o = ifq_size_q == 'd2;
    ////////////////////////////////////////////////////////////////////////////////

endmodule
