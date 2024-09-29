module mrv1_ifbuf #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P            = 32,
    parameter NUM_THREADS_P         = 8,
    parameter IF_BUF_SIZE_P         = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter IF_BUF_ADDR_WIDTH_LP  = $clog2(IF_BUF_SIZE_P),
    parameter TID_WIDTH_LP          = $clog2(NUM_THREADS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            clk_i,
    input  logic                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            enqueue_i,
    input  logic                            dequeue_i,
    output logic                            empty_o,
    output logic                            full_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            fetch_data_vld_i,
    input  logic [31:0]                     fetch_data_i,
    input  logic [PC_WIDTH_P-1:0]           fetch_pc_i,
    input  logic [TID_WIDTH_LP-1:0]         fetch_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                            fetch_data_vld_o,
    output logic [31:0]                     fetch_data_o,
    output logic [PC_WIDTH_P-1:0]           fetch_pc_o,
    output logic [TID_WIDTH_LP-1:0]         fetch_tid_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // IFetch buffer
    ////////////////////////////////////////////////////////////////////////////////
    logic [IF_BUF_SIZE_P-1:0][31:0]                 ifq_insn_data_q;
    logic [IF_BUF_SIZE_P-1:0][PC_WIDTH_P-1:0]       ifq_insn_pc_q;
    logic [IF_BUF_SIZE_P-1:0][TID_WIDTH_LP-1:0]     ifq_insn_tid_q;
    logic [IF_BUF_SIZE_P-1:0]                       ifq_insn_vld_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [IF_BUF_ADDR_WIDTH_LP:0]                  ifq_size_q;
    logic [IF_BUF_ADDR_WIDTH_LP:0]                  ifq_size_n_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [IF_BUF_ADDR_WIDTH_LP-1:0]                ifq_w_ptr_q;
    logic [IF_BUF_ADDR_WIDTH_LP-1:0]                ifq_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////
    wire [IF_BUF_ADDR_WIDTH_LP:0] ifq_w_ptr_p1_w = ifq_w_ptr_q + 1'b1;
    wire [IF_BUF_ADDR_WIDTH_LP:0] ifq_r_ptr_p1_w = ifq_r_ptr_q + 1'b1;
    ////////////////////////////////////////////////////////////////////////////////
    wire [IF_BUF_ADDR_WIDTH_LP-1:0] ifq_w_ptr_n_wrp_w = (ifq_w_ptr_p1_w == IF_BUF_SIZE_P ? '0 : IF_BUF_ADDR_WIDTH_LP'(ifq_w_ptr_p1_w));
    wire [IF_BUF_ADDR_WIDTH_LP-1:0] ifq_r_ptr_n_wrp_w = (ifq_r_ptr_p1_w == IF_BUF_SIZE_P ? '0 : IF_BUF_ADDR_WIDTH_LP'(ifq_r_ptr_p1_w));
    ////////////////////////////////////////////////////////////////////////////////
    wire [IF_BUF_ADDR_WIDTH_LP-1:0] ifq_w_ptr_n_w = enqueue_i ? ifq_w_ptr_n_wrp_w : ifq_w_ptr_q;
    wire [IF_BUF_ADDR_WIDTH_LP-1:0] ifq_r_ptr_n_w = dequeue_i ? ifq_r_ptr_n_wrp_w : ifq_r_ptr_q;
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] fetch_data_0_w  = ifq_insn_data_q[ifq_r_ptr_q];
    wire [31:0] fetch_data_1_w  = ifq_insn_data_q[ifq_r_ptr_n_wrp_w];
    wire fetch_data_0_vld_w     = ifq_insn_vld_q[ifq_r_ptr_q];
    wire fetch_data_1_vld_w     = ifq_insn_vld_q[ifq_r_ptr_n_wrp_w];
    ////////////////////////////////////////////////////////////////////////////////
    assign fetch_pc_o           = ifq_insn_pc_q[ifq_r_ptr_q];
    assign fetch_tid_o          = ifq_insn_tid_q[ifq_w_ptr_q];
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_ialigner ialigner_i (
    ////////////////////////////////////////////////////////////////////////////////
        .i_data_0_i             (fetch_data_0_w),
        .i_data_0_vld_i         (fetch_data_0_vld_w),
        .i_data_1_i             (fetch_data_1_w),
        .i_data_1_vld_i         (fetch_data_1_vld_w),
        .unalgn_pc_i            (fetch_pc_o[1]), //FIXME
        ////////////////////////////////////////////////////////////////////////////////
        .i_data_o               (fetch_data_o),
        .i_data_vld_o           (fetch_data_vld_o)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ifq_size_q                          <= 'b0;
            ifq_w_ptr_q                         <= 'b0;
            ifq_r_ptr_q                         <= 'b0;
            ifq_insn_vld_q                      <= 'b0;
        end
        else begin
            if (dequeue_i) begin
                ifq_insn_vld_q[ifq_r_ptr_q]     <= 1'b0;
            end
            if (enqueue_i) begin
                ifq_insn_data_q[ifq_w_ptr_q]    <= fetch_data_i;
                ifq_insn_pc_q[ifq_w_ptr_q]      <= fetch_pc_i;
                ifq_insn_tid_q[ifq_w_ptr_q]     <= fetch_tid_i;
                ifq_insn_vld_q[ifq_w_ptr_q]     <= 1'b1;
            end
            ifq_size_q                          <= ifq_size_n_r;
            ifq_w_ptr_q                         <= ifq_w_ptr_n_w;
            ifq_r_ptr_q                         <= ifq_r_ptr_n_w;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign empty_o       = ifq_size_q == '0;
    assign full_o        = ifq_size_q == {IF_BUF_ADDR_WIDTH_LP+1}'(IF_BUF_SIZE_P);

endmodule