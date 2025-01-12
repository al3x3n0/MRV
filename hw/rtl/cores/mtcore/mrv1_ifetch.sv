module mrv1_ifetch
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_RESET_ADDR = 'h2000,
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter NUM_BARR_P = 8,
    parameter ifq_size_p = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ifq_addr_width_lp = $clog2(ifq_size_p),
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter IMEM_TAG_WIDTH_P = PC_WIDTH_P + TID_WIDTH_LP,
    parameter BARR_ID_WIDTH_LP = $clog2(NUM_BARR_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                clk_i,
    input  logic                                rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                simt_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    // IFETCH <-> IMEM interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                imem_req_vld_o,
    input  logic                                imem_req_rdy_i,
    output logic [31:0]                         imem_req_addr_o,
    output logic [IMEM_TAG_WIDTH_P-1:0]         imem_req_tag_o,
    input  logic                                imem_resp_vld_i,
    input  logic [IMEM_TAG_WIDTH_P-1:0]         imem_resp_tag_i,
    input  logic [31:0]                         imem_resp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                fetch_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                ifetch_insn_vld_o,
    output logic [31:0]                         ifetch_insn_data_o,
    output logic [PC_WIDTH_P-1:0]               ifetch_insn_pc_o,
    output logic [TID_WIDTH_LP-1:0]             ifetch_insn_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_THREADS_P-1:0]             decode_rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [TID_WIDTH_LP-1:0]              decode_tid_i,
    input logic                                 decode_is_branch_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [TID_WIDTH_LP-1:0]              exec_tid_i,
    input logic                                 exec_b_pc_vld_i,
    input logic [PC_WIDTH_P-1:0]                exec_b_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                th_stall_vld_i,
    input  logic [TID_WIDTH_LP-1:0]             th_stall_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                th_ctl_vld_i,
    input  logic [TID_WIDTH_LP-1:0]             th_ctl_tid_i,
    input  logic                                th_ctl_tspawn_vld_i,
    input  logic [PC_WIDTH_P-1:0]               th_ctl_tspawn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 th_ctl_barrier_vld_i,
    input logic [BARR_ID_WIDTH_LP-1:0]          th_ctl_barrier_id_i,
    input logic [TID_WIDTH_LP-1:0]              th_ctl_barrier_size_m1_i
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0]                   sched_rdy_li;
    logic                                       sched_fetch_req_lo;
    logic [PC_WIDTH_P-1:0]                      sched_pc_lo;
    logic [TID_WIDTH_LP-1:0]                    sched_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    assign imem_req_vld_o = sched_fetch_req_lo;
    assign imem_req_addr_o = sched_pc_lo;
    assign imem_req_tag_o = {sched_pc_lo, sched_tid_lo};
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction fetch queue
    ////////////////////////////////////////////////////////////////////////////////
    logic [TID_WIDTH_LP-1:0]        ifq_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [TID_WIDTH_LP-1:0]        fetch_tid_li;
    logic [PC_WIDTH_P-1:0]          fetch_pc_li;
    assign {fetch_pc_li, fetch_tid_li} = imem_resp_tag_i;

    logic decode_is_branch_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            decode_is_branch_q <= 1'b0;
        end else begin
            decode_is_branch_q <= decode_is_branch_i;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0]                   ifq_i_data_vld_lo;
    logic [NUM_THREADS_P-1:0][31:0]             ifq_i_data_lo;
    logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]   ifq_pc_lo;
    logic [NUM_THREADS_P-1:0]                   decode_th_rdy_li;
    ////////////////////////////////////////////////////////////////////////////////
    generate
    for (genvar i = 0; i < NUM_THREADS_P; i++) begin
        ////////////////////////////////////////////////////////////////////////////////
        logic ifq_empty_lo;
        logic ifq_full_lo;
        logic ifq_almost_full_lo;
        ////////////////////////////////////////////////////////////////////////////////
        wire tid_match_w = ifetch_insn_tid_o == TID_WIDTH_LP'(i);
        wire fetch_tid_match_w = fetch_tid_li == TID_WIDTH_LP'(i);
        assign sched_rdy_li[i] = ~ifq_full_lo;
        assign decode_th_rdy_li[i] = ifq_i_data_vld_lo[i] & decode_rdy_i[i];
        wire ifq_enqueue_li = imem_resp_vld_i & ~ifq_full_lo & fetch_tid_match_w;
        always_comb begin
            $display("[IFQ] imem_resp_vld_i=%b ifq_enqueue_li=%b fetch_tid_match_w=%b ifq_full_lo=%b data=%h pc=%h",
                imem_resp_vld_i, ifq_enqueue_li, fetch_tid_match_w, ifq_full_lo, imem_resp_data_i, fetch_pc_li);
        end
        wire ifq_dequeue_li = tid_match_w & ifetch_insn_vld_o;
        ////////////////////////////////////////////////////////////////////////////////
        xrv1_ifq ifq_i (
            .clk_i                  (clk_i),
            .rst_i                  (rst_i | decode_is_branch_q),
            ////////////////////////////////////////////////////////////////////////////////
            .enqueue_i              (ifq_enqueue_li),
            .dequeue_i              (ifq_dequeue_li),
            ////////////////////////////////////////////////////////////////////////////////
            .fetch_data_i           (imem_resp_data_i),
            .fetch_pc_i             (fetch_pc_li),
            ////////////////////////////////////////////////////////////////////////////////
            .fetch_data_vld_o       (ifq_i_data_vld_lo[i]),
            .fetch_data_o           (ifq_i_data_lo[i]),
            .fetch_pc_o             (ifq_pc_lo[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .empty_o                (ifq_empty_lo),
            .full_o                 (ifq_full_lo),
            .almost_full_o          (ifq_almost_full_lo)
            ////////////////////////////////////////////////////////////////////////////////
        );
    end
    endgenerate
    ////////////////////////////////////////////////////////////////////////////////
    assign ifetch_insn_data_o = ifq_i_data_lo[ifetch_insn_tid_o];
    assign ifetch_insn_pc_o = ifq_pc_lo[ifetch_insn_tid_o];

    ////////////////////////////////////////////////////////////////////////////////
    // Thread scheduler
    ////////////////////////////////////////////////////////////////////////////////
    logic issue_tid_vld_lo;
    mrv1_rr_th_scheduler #(
        .NUM_THREADS_P(NUM_THREADS_P)
    ) decode_th_sched_i (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .sched_rdy_i    (decode_th_rdy_li),
        .sched_vld_o    (ifetch_insn_vld_o),
        .sched_tid_o    (ifetch_insn_tid_o)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction Fetch Scheduler
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_th_sched #(
        .CORE_RESET_ADDR            (CORE_RESET_ADDR),
        .NUM_THREADS_P              (NUM_THREADS_P),
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) th_sched_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .simt_en_i                  (simt_en_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_done_i               (imem_resp_vld_i),
        .fetch_tid_i                (fetch_tid_li),
        .fetch_pc_i                 (fetch_pc_li),
        ////////////////////////////////////////////////////////////////////////////////
        .decode_tid_i               (decode_tid_i),
        .decode_is_branch_i         (decode_is_branch_i),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_tid_i                 (exec_tid_i),
        .exec_b_pc_vld_i            (exec_b_pc_vld_i),
        .exec_b_pc_i                (exec_b_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sched_rdy_i                (sched_rdy_li),
        .sched_vld_o                (sched_fetch_req_lo),
        .sched_tid_o                (sched_tid_lo),
        .sched_pc_o                 (sched_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // IMT Control
        ////////////////////////////////////////////////////////////////////////////////
        .th_stall_vld_i              ('0), // FIXME
        .th_stall_tid_i              ('0), // FIXME
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_i                (th_ctl_vld_i),
        .th_ctl_tid_i                (th_ctl_tid_i),
        .th_ctl_tspawn_vld_i         (th_ctl_tspawn_vld_i),
        .th_ctl_tspawn_pc_i          (th_ctl_tspawn_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_barrier_vld_i        (th_ctl_barrier_vld_i),
        .th_ctl_barrier_id_i         (th_ctl_barrier_id_i),
        .th_ctl_barrier_size_m1_i    (th_ctl_barrier_size_m1_i)
        ////////////////////////////////////////////////////////////////////////////////
    );

    always_comb begin
        if (imem_req_vld_o) begin
            $display("[IMEM_REQ] pc=%h", imem_req_addr_o);
        end
        if (imem_resp_vld_i) begin
            $display("[IMEM_RESP] pc=%h data=%h", fetch_pc_li, imem_resp_data_i);
        end
        $display("[IMEM] decode_rdy_i=%b insn_vld=%h pc=%h insn_data=%h",
            decode_rdy_i, ifetch_insn_vld_o, ifetch_insn_pc_o, ifetch_insn_data_o);
    end 

endmodule
