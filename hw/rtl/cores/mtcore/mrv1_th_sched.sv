////////////////////////////////////////////////////////////////////////////////
// IMT Scheduler
////////////////////////////////////////////////////////////////////////////////

module mrv1_th_sched
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_RESET_ADDR = 'h2000,
    parameter is_simt_master_p = 0,
    parameter PC_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter NUM_BARR_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter BARR_ID_WIDTH_LP = $clog2(NUM_BARR_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                clk_i,
    input  logic                                rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT mode enabled
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                simt_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_THREADS_P-1:0]            fetch_req_vld_i,
    input  logic [NUM_THREADS_P-1:0]            fetch_done_i,
    input  logic [TID_WIDTH_LP-1:0]             fetch_tid_i,
    input  logic [PC_WIDTH_P-1:0]               fetch_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [TID_WIDTH_LP-1:0]             decode_tid_i,
    input  logic                                decode_is_branch_i,
    ////////////////////////////////////////////////////////////////////////////////
    // B from EXEC stage
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [TID_WIDTH_LP-1:0]             exec_tid_i,
    input  logic                                exec_b_pc_vld_i,
    input  logic [PC_WIDTH_P-1:0]               exec_b_pc_i,
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
    input logic [TID_WIDTH_LP-1:0]              th_ctl_barrier_size_m1_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                sched_vld_o,
    output logic [TID_WIDTH_LP-1:0]             sched_tid_o,
    output logic [PC_WIDTH_P-1:0]               sched_pc_o
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0]                                   fetch_lock_q, fetch_lock_q_n;
    logic [NUM_THREADS_P-1:0]                                   active_threads_q, active_threads_q_n;
    logic [NUM_THREADS_P-1:0]                                   sched_tbl_q, sched_tbl_q_n;
    logic [NUM_THREADS_P-1:0]                                   stalled_threads_q, stalled_threads_q_n;
    logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]                   thread_pcs_q, thread_pcs_q_n, sched_pc_n;
    logic [NUM_THREADS_P-1:0]                                   use_tspawn_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_BARR_P-1:0][NUM_THREADS_P-1:0]                   barrier_stall_mask_q;

    ////////////////////////////////////////////////////////////////////////////////
    // Thread Spawn/Stall
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        use_tspawn_r = 'b0;
        active_threads_q_n = active_threads_q;
        if (th_ctl_vld_i && th_ctl_tspawn_vld_i) begin
            for (int i = 0; i < NUM_THREADS_P; ++i) begin
                if (~active_threads_q_n[i]) begin
                    active_threads_q_n[i] = 1'b1;
                    use_tspawn_r[i] = 1'b1;
                    break;
                end
            end
        end
        ////////////////////////////////////////////////////////////////////////////////
        stalled_threads_q_n = stalled_threads_q;
        sched_pc_n = thread_pcs_q;
        if (th_stall_vld_i) begin
            stalled_threads_q_n[th_stall_tid_i] = 1'b1;
        end
        if (decode_is_branch_i) begin
            stalled_threads_q_n[decode_tid_i] = 1'b1;
        end
        if (th_stall_vld_i) begin
            stalled_threads_q_n[th_stall_tid_i] = 1'b1;
        end
        if (exec_b_pc_vld_i) begin
            stalled_threads_q_n[exec_tid_i] = 1'b0;
            sched_pc_n[exec_tid_i] = exec_b_pc_i;
        end
        ////////////////////////////////////////////////////////////////////////////////
    end
    logic [NUM_THREADS_P-1:0] ready_threads_w;
    assign ready_threads_w = active_threads_q_n & ~stalled_threads_q_n;

    ////////////////////////////////////////////////////////////////////////////////
    // Scheduler Logic
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        thread_pcs_q_n  = thread_pcs_q;
        fetch_lock_q_n  = fetch_lock_q;
        sched_tbl_q_n   = sched_tbl_q;
        sched_vld_o     = 'b0;
        sched_pc_o      = 'b0;
        sched_tid_o     = 'b0;
        if (fetch_done_i[fetch_tid_i]) begin
            fetch_lock_q_n[fetch_tid_i] = '0;
            thread_pcs_q_n[fetch_tid_i] = fetch_pc_i + 4;
        end
        if (exec_b_pc_vld_i) begin
            thread_pcs_q_n[exec_tid_i] = exec_b_pc_i;
        end
        for (int i = 0; i < NUM_THREADS_P; ++i) begin
            if (ready_threads_w[i] && sched_tbl_q_n[i] && ~fetch_lock_q_n[i]) begin
                sched_vld_o = 1'b1;
                sched_pc_o = use_tspawn_r[i] ? th_ctl_tspawn_pc_i : thread_pcs_q_n[i];
                sched_tid_o = TID_WIDTH_LP'(i);
                sched_tbl_q_n[i] = 1'b0;
                if (fetch_req_vld_i[i]) begin
                    fetch_lock_q_n[i] = '1;
                end
                break;
            end
        end
        if (exec_b_pc_vld_i) begin
            thread_pcs_q_n[exec_tid_i] = exec_b_pc_i;
        end
        $display("fetch_done_i=%b fetch_lock_q_n=%b", fetch_done_i, fetch_lock_q_n);
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ////////////////////////////////////////////////////////////////////////////////
            thread_pcs_q[0]             <= PC_WIDTH_P'(CORE_RESET_ADDR);   //`STARTUP_ADDR;
            active_threads_q[0]         <= 1;   // Activating first thread
            sched_tbl_q[0]              <= 1;   // set first thread as ready
            stalled_threads_q           <= 0;
	        ////////////////////////////////////////////////////////////////////////////////
            for (int i = 1; i < NUM_THREADS_P; i++) begin
                thread_pcs_q[i]         <= 0;
                active_threads_q[i]     <= 0;
                sched_tbl_q[i]          <= 0;
            end
            ////////////////////////////////////////////////////////////////////////////////
        end else begin
            ////////////////////////////////////////////////////////////////////////////////
            stalled_threads_q <= stalled_threads_q_n;
            thread_pcs_q      <= thread_pcs_q_n;
            fetch_lock_q      <= fetch_lock_q_n;
            active_threads_q  <= active_threads_q_n;
	        sched_tbl_q       <= (|sched_tbl_q_n) ? sched_tbl_q_n : active_threads_q_n;
        end
    end

endmodule
