////////////////////////////////////////////////////////////////////////////////
// IMT Scheduler
////////////////////////////////////////////////////////////////////////////////

module mrv1_th_sched
#(
    ////////////////////////////////////////////////////////////////////////////////
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
    input  logic                                fetch_done_i,
    input  logic [TID_WIDTH_LP-1:0]             fetch_tid_i,
    input  logic [PC_WIDTH_P-1:0]               fetch_pc_i,
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
    logic [NUM_THREADS_P-1:0]                                    active_threads_q, active_threads_n_q;
    logic [NUM_THREADS_P-1:0]                                    sched_tbl_q, sched_tbl_n_q;
    logic [NUM_THREADS_P-1:0]                                    stalled_threads_q, stalled_threads_n_q;
    logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]                    thread_pcs_q;
    logic [NUM_THREADS_P-1:0]                                    use_tspawn_r;
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_BARR_P-1:0][NUM_THREADS_P-1:0]                barrier_stall_mask_q;

    ////////////////////////////////////////////////////////////////////////////////
    // Thread Spawn/Stall
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        use_tspawn_r = 'b0;
        active_threads_n_q = active_threads_q;
        if (th_ctl_vld_i && th_ctl_tspawn_vld_i) begin
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
                sched_pc_o = use_tspawn_r[i] ? th_ctl_tspawn_pc_i : thread_pcs_q[i];
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

    ////////////////////////////////////////////////////////////////////////////////
    // Lock TW until instruction decode to resolve branches
    ////////////////////////////////////////////////////////////////////////////////
    //always_ff @(posedge clk_i) begin
    //    if (scheduled_warp) begin
    //        fetch_lock_q[warp_to_schedule] <= 1;
    //    end
    //    if (ifetch_rsp_fire) begin
    //        fetch_lock_q[ifetch_rsp_if.wid] <= 0;
    //        thread_pcs_q[ifetch_rsp_if.wid] <= ifetch_rsp_if.PC + 4;
    //   end
    //end
    ////////////////////////////////////////////////////////////////////////////////


endmodule
