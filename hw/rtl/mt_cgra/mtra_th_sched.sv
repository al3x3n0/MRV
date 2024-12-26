module mtra_th_sched
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P = 8,
    parameter PC_WIDTH_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)

) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [TID_WIDTH_LP-1:0]                     th_spawn_tid_i,
    input  logic                                        th_spawn_vld_i,
    input  logic [PC_WIDTH_P-1:0]                       th_spawn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        sched_vld_o,
    output logic [TID_WIDTH_LP-1:0]                     sched_tid_o,
    output logic [PC_WIDTH_P-1:0]                       sched_pc_o
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_THREADS_P-1:0]                           active_threads_q, active_threads_n_q;
    logic [NUM_THREADS_P-1:0]                           sched_tbl_q, sched_tbl_n_q;
    logic [NUM_THREADS_P-1:0]                           stalled_threads_q, stalled_threads_n_q;
    logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]           thread_pcs_q;
    logic [NUM_THREADS_P-1:0]                           use_tspawn_r;

    ////////////////////////////////////////////////////////////////////////////////
    // Thread Spawn/Stall
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        use_tspawn_r = 'b0;
        active_threads_n_q = active_threads_q;
        if (th_spawn_vld_i) begin
            for (int i = 0; i < NUM_THREADS_P; ++i) begin
                if (~active_threads_n_q[i]) begin
                    active_threads_n_q[i] = 1'b1;
                    use_tspawn_r[i] = 1'b1;
                    break;
                end
            end
        end
        ////////////////////////////////////////////////////////////////////////////////
        stalled_threads_n_q = stalled_threads_q;
        if (th_stall_vld_i) begin
            stalled_threads_n_q[th_stall_tid_i] = 1'b1;
        end
        ////////////////////////////////////////////////////////////////////////////////
    end
    logic [NUM_THREADS_P-1:0] ready_threads_w = active_threads_n_q & ~stalled_threads_n_q;

    ////////////////////////////////////////////////////////////////////////////////
    // Scheduler Logic
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        sched_tbl_n_q   = sched_tbl_q;
        sched_vld_o     = 1'b0;
        sched_pc_o      = 'b0;
        sched_tid_o     = 'b0;
        for (int i = 0; i < NUM_THREADS_P; ++i) begin
            if (ready_threads_w[i] && sched_tbl_n_q[i]) begin
                sched_vld_o = 1'b1;
                sched_pc_o = use_tspawn_r[i] ? th_spawn_pc_i : thread_pcs_q[i];
                sched_tid_o = TID_WIDTH_LP'(i);
                sched_tbl_n_q[i] = 1'b0;
                break;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ////////////////////////////////////////////////////////////////////////////////
            thread_pcs_q[0]             <= 0;   //`STARTUP_ADDR;
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
            if (th_stall_vld_i) begin
                stalled_threads_q[th_stall_tid_i] <= 1'b1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            // Branch
            ////////////////////////////////////////////////////////////////////////////////
            if (exec_b_pc_vld_i) begin
                thread_pcs_q[exec_tid_i]       <= exec_b_pc_i;
                stalled_threads_q[exec_tid_i]  <= 1'b0;
            end
            ////////////////////////////////////////////////////////////////////////////////
            active_threads_q    <= active_threads_n_q;
	        sched_tbl_q       <= (|sched_tbl_n_q) ? sched_tbl_n_q : active_threads_n_q;
        end
    end

endmodule