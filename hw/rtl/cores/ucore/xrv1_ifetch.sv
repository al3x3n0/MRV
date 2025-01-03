module xrv1_ifetch
#(
    parameter ifq_size_p = 3,
    parameter ifq_addr_width_lp = $clog2(ifq_size_p),
    parameter ifq_default_reset_addr
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    input logic                                 rst_down_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 decode_rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 exec_b_pc_vld_i,
    input logic [31:0]                          exec_b_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 dec_j_pc_vld_i,
    input logic [31:0]                          dec_j_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                ifetch_insn_vld_o,
    output logic [31:0]                         ifetch_insn_data_o,
    output logic [31:0]                         ifetch_insn_pc_o,
    output logic                                ifetch_insn_compressed_o,
    output logic                                ifetch_insn_illegal_o,
    ////////////////////////////////////////////////////////////////////////////////
    // IFETCH <-> IMEM interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                imem_req_vld_o,
    input  logic                                imem_req_rdy_i,
    output logic [31:0]                         imem_req_addr_o,
    input  logic                                imem_resp_vld_i,
    input  logic [31:0]                         imem_resp_data_i
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] rv16_insn_expanded_lo;
    logic        insn_is_rv16_lo;
    logic        rv16_insn_illegal_lo;

    ////////////////////////////////////////////////////////////////////////////////
    // Address of fetched instruction
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] fetch_addr_q;
    logic [31:0] fetch_addr_r;
    logic fetch_next;

    ////////////////////////////////////////////////////////////////////////////////
    // Fetch address increment
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0]  fetch_addr_n_w = {fetch_addr_q [31:2], 2'b00} + 'd4;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Fetched instruction scan
    ////////////////////////////////////////////////////////////////////////////////
    logic           spec_pc_vld_0_lo, spec_pc_vld_1_lo;
    logic [31:0]    spec_pc_0_lo, spec_pc_1_lo;
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_branch_spec b_spec_0 (
        .insn_i                 (imem_resp_data_i),
        .insn_pc_i              ({fetch_addr_q[31:2], 2'b00}),
        .insn_rv16_i            (1'b0),
        .spec_pc_vld_o          (spec_pc_vld_0_lo),
        .spec_pc_o              (spec_pc_0_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_branch_spec b_spec_1 (
        .insn_i                 ({16'b0, imem_resp_data_i[31:16]}),
        .insn_pc_i              ({fetch_addr_q[31:1], 1'b0}),
        .insn_rv16_i            (1'b1),
        .spec_pc_vld_o          (spec_pc_vld_1_lo),
        .spec_pc_o              (spec_pc_1_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    wire rv16_high_w = imem_resp_data_i[17:16] != 2'b11;
    wire spec_pc_vld_w = (~fetch_addr_q[1] & spec_pc_vld_0_lo) |
        (fetch_addr_q[1] & rv16_high_w & spec_pc_vld_1_lo);
    wire [31:0] spec_pc_w = fetch_addr_q[1] ? spec_pc_1_lo : spec_pc_0_lo;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Fetch address calculation
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (rst_down_i)
            fetch_addr_r = ifq_default_reset_addr;
        else if (exec_b_pc_vld_i)
            fetch_addr_r = exec_b_pc_i;
        else if (dec_j_pc_vld_i)
            fetch_addr_r = dec_j_pc_i;
        else if (fetch_next)
            fetch_addr_r = (spec_pc_vld_w & imem_resp_vld_i) ?  spec_pc_w : fetch_addr_n_w;
        else
            fetch_addr_r = fetch_addr_q;
        $display("fetch_addr_r=%h rst_down_i=%d", fetch_addr_r, rst_down_i);
    end

    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i)
            fetch_addr_q <= ifq_default_reset_addr;
        else if (exec_b_pc_vld_i)
            fetch_addr_q <= exec_b_pc_i;
        else if (dec_j_pc_vld_i)
            fetch_addr_q <= dec_j_pc_i;
        else
            fetch_addr_q <= fetch_addr_r;
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction fetch queue
    ////////////////////////////////////////////////////////////////////////////////
    logic                       ifq_byp_en;
    ////////////////////////////////////////////////////////////////////////////////
    logic                       ifq_empty_lo;
    logic                       ifq_full_lo;
    logic                       ifq_almost_full_lo;
    logic                       ifq_enqueue_li;
    logic                       ifq_dequeue_li;
    logic [31:0]                ifq_i_data_lo;
    logic                       ifq_i_data_vld_lo;
    logic [31:0]                ifq_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_ifq ifq_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i | dec_j_pc_vld_i | exec_b_pc_vld_i),
        ////////////////////////////////////////////////////////////////////////////////
        .enqueue_i              (ifq_enqueue_li),
        .dequeue_i              (ifq_dequeue_li),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_i           (imem_resp_data_i),
        .fetch_pc_i             (fetch_addr_q),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_vld_o       (ifq_i_data_vld_lo),
        .fetch_data_o           (ifq_i_data_lo),
        .fetch_pc_o             (ifq_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .empty_o                (ifq_empty_lo),
        .full_o                 (ifq_full_lo),
        .almost_full_o          (ifq_almost_full_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////
    assign ifq_enqueue_li = imem_resp_vld_i & ~ifq_byp_en & ~ifq_full_lo;
    assign ifq_dequeue_li = decode_rdy_i & ifq_i_data_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    assign fetch_next = ifq_enqueue_li | ifq_byp_en;

    ////////////////////////////////////////////////////////////////////////////////
    // Queue bypass
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                byp_algn_i_data_lo;
    logic                       byp_algn_i_data_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_ialigner ialigner_i (
        ////////////////////////////////////////////////////////////////////////////////
        .i_data_0_i             (imem_resp_data_i),
        .i_data_0_vld_i         (imem_resp_vld_i),
        .i_data_1_i             ('0),
        .i_data_1_vld_i         ('0),
        .unalgn_pc_i            (fetch_addr_q[1]),
        ////////////////////////////////////////////////////////////////////////////////
        .i_data_o               (byp_algn_i_data_lo),
        .i_data_vld_o           (byp_algn_i_data_vld_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////
    assign ifq_byp_en = decode_rdy_i & byp_algn_i_data_vld_lo & ifq_empty_lo;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // RVC decompression
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] algn_i_data_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (ifq_byp_en) begin
            algn_i_data_r     = byp_algn_i_data_lo;
            ifetch_insn_vld_o = byp_algn_i_data_vld_lo;
            ifetch_insn_pc_o  = fetch_addr_q;
        end
        else begin
            algn_i_data_r     = ifq_i_data_lo;
            ifetch_insn_vld_o = ifq_i_data_vld_lo;
            ifetch_insn_pc_o  = ifq_pc_lo;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    xrv1_rv16_expander rv16_expander_i (
        .insn_i             (algn_i_data_r),
        .insn_o             (ifetch_insn_data_o),
        .illegal_insn_o     (ifetch_insn_illegal_o)
    );
    ////////////////////////////////////////////////////////////////////////////////
    assign ifetch_insn_compressed_o = algn_i_data_r[1:0] != 2'b11;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // IMEM interface control
    ////////////////////////////////////////////////////////////////////////////////
    assign imem_req_vld_o = ~(ifq_full_lo & ~ifq_dequeue_li);
    assign imem_req_addr_o = {fetch_addr_r[31:2], 2'b00};
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        $display("imem_rd_vld=%d add=%h", imem_req_vld_o, imem_req_addr_o);
    end

endmodule
