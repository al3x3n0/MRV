module mrv1_ifetch
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter NUM_BARR_P = 8,
    parameter ifq_size_p = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ifq_addr_width_lp = $clog2(ifq_size_p),
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter IMEM_TAG_WIDTH_P = TID_WIDTH_LP,
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
    logic                                       sched_fetch_req_lo;
    logic [PC_WIDTH_P-1:0]                      sched_pc_lo;
    logic [TID_WIDTH_LP-1:0]                    sched_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [PC_WIDTH_P-1:0]                      fetch_pc_q;
    logic [TID_WIDTH_LP-1:0]                    fetch_tid_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
        end else begin
            fetch_pc_q          <= sched_pc_lo;
            fetch_tid_q         <= sched_tid_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction fetch queue
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    ifq_data_lo;
    logic                           ifq_data_vld_lo;
    logic [PC_WIDTH_P-1:0]          ifq_pc_lo;
    logic [TID_WIDTH_LP-1:0]        ifq_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic ifq_enqueue_li; /* FIXME */
    logic ifq_dequeue_li;
    logic ifq_empty_lo;
    logic ifq_full_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_ifbuf #(
        .NUM_THREADS_P              (NUM_THREADS_P),
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) ifq_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i | exec_b_pc_vld_i),
        ////////////////////////////////////////////////////////////////////////////////
        .enqueue_i                  (ifq_enqueue_li),
        .dequeue_i                  (ifq_dequeue_li),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_vld_i           (imem_resp_vld_i),
        .fetch_data_i               (imem_resp_data_i),
        .fetch_pc_i                 (fetch_pc_q /* FIXME */),
        .fetch_tid_i                (imem_resp_tag_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_vld_o           (ifetch_insn_vld_o),
        .fetch_data_o               (ifetch_insn_data_o),
        .fetch_pc_o                 (ifetch_insn_pc_o),
        .fetch_tid_o                (ifetch_insn_tid_o),
        ////////////////////////////////////////////////////////////////////////////////
        .empty_o                    (ifq_empty_lo),
        .full_o                     (ifq_full_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Thread Scheduler
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_th_sched #(
        .NUM_THREADS_P              (NUM_THREADS_P),
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) th_sched_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .simt_en_i                  (simt_en_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_done_i               (/* FIXME */),
        .fetch_tid_i                (/* FIXME */),
        .fetch_pc_i                 (/* FIXME */),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_tid_i                 (exec_tid_i),
        .exec_b_pc_vld_i            (exec_b_pc_vld_i),
        .exec_b_pc_i                (exec_b_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sched_vld_o                (sched_fetch_req_lo),
        .sched_tid_o                (sched_tid_lo),
        .sched_pc_o                 (sched_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // IMT Control
        ////////////////////////////////////////////////////////////////////////////////
        .th_stall_vld_i              (/*FIXME*/),
        .th_stall_tid_i              (/*FIXME*/),
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

endmodule
