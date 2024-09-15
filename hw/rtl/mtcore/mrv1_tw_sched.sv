////////////////////////////////////////////////////////////////////////////////
// Unified Thread/Warp Scheduler
////////////////////////////////////////////////////////////////////////////////

module mrv1_tw_sched
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter is_simt_master_p = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_TW_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter warp_size_p = 8,
    parameter num_barriers_p = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter wid_width_lp = $clog2(NUM_TW_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          clk_i,
    input  logic                          rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT mode enabled
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          simt_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          fetch_done_i,
    input  logic [wid_width_lp-1:0]       fetch_twid_i,
    input  logic [31:0]                   fetch_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    // J From DEC stage
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [wid_width_lp-1:0]       dec_twid_i,
    input  logic                          dec_j_pc_vld_i,
    input  logic [31:0]                   dec_j_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    // B from EXEC stage
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [wid_width_lp-1:0]       exec_twid_i,
    input  logic                          exec_b_pc_vld_i,
    input  logic [31:0]                   exec_b_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT Warp Control
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          join_vld_i,
    input  logic [wid_width_lp-1:0]       join_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          wstall_vld_i,
    input  logic [wid_width_lp-1:0]       wstall_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          twctl_vld_i,
    input  logic [wid_width_lp-1:0]       twctl_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          twctl_tmc_vld_i,
    input  logic [warp_size_p-1:0]        twctl_tmc_tmask_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          twctl_wspawn_vld_i,
    input  logic [num_warps_lp-1:0]       twctl_wspawn_wmask_i,
    input  logic [31:0]                   twctl_wspawn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                          twctl_split_vld_i,
    input  logic                          twctl_split_diverged_i,
    input  logic [warp_size_p-1:0]        twctl_split_then_mask_i,
    input  logic [warp_size_p-1:0]        twctl_split_else_mask_i,
    input  logic [31:0]                   twctl_split_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                           twctl_barrier_vld_i,
    input logic [barrier_id_width_lp-1:0] twctl_barrier_id_i,
    input logic [wid_width_lp-1:0]        twctl_barrier_size_m1_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                          sched_vld_o,
    output logic [wid_width_lp-1:0]       sched_twid_o,
    output logic [31:0]                   sched_pc_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // Interleaved Unified Thread/Warp (IUTW) is a basic execution unit
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_TW_P-1:0]                                    active_tws_q, active_tws_n_q;
    logic [NUM_TW_P-1:0]                     sched_table_q, sched_table_n_q;
    logic [NUM_TW_P-1:0]                                    stalled_tws_q;
    logic [NUM_TW_P-1:0][warp_size_p-1:0]                   tmasks_q;
    logic [NUM_TW_P-1:0][31:0]                              tws_pcs_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_barriers_p-1:0][NUM_TW_P-1:0]                barrier_stall_mask_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                                                      sched_vld_r;
    logic [wid_width_lp-1:0]                                   scheduled_twid_r;
    ////////////////////////////////////////////////////////////////////////////////
    // Active T/W Control
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        active_tws_n_q = active_tws_q;
        if (twctl_vld_i) begin
            if (twctl_wspawn_vld_i) begin
                active_tws_n_q = twctl_wspawn_wmask_i;
            end
            if (twctl_tmc_vld_i) begin
                active_tws_n_q[twctl_twid_i] = (|twctl_tmc_tmask_i);
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Scheduler Logic
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        sched_vld_r = 1'b0;
        //thread_mask      = 0;
        //warp_pc          = 0;
        //warp_to_schedule = 0;
        for (integer i = 0; i < NUM_TW_P; ++i) begin
            if (schedule_ready[i]) begin
                sched_vld_r = 1'b1;
                //thread_mask = 0;//use_wspawn[i] ? `NUM_THREADS'(1) : thread_masks[i];
                //warp_pc = use_wspawn[i] ? use_wspawn_pc : warp_pcs[i];
                //warp_to_schedule = 0;//`NW_BITS'(i);
                break;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        sched_table_n_q = sched_table_q;
        if (simt_en_i & twctl_vld_i & twctl_tmc_vld_i) begin
            sched_table_n_q[twctl_twid_i] = (|twctl_tmc_tmask_i);
        end
        if (sched_vld_r/*scheduled_warp*//*FIXME*/) begin // remove scheduled warp (round-robin)
            sched_table_n_q[scheduled_twid_r] = 0;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT-only logic
    ////////////////////////////////////////////////////////////////////////////////
    generate
    if (is_simt_master_p == 1) begin
        always_ff @(posedge clk_i) begin
            if (rst_i) begin
                ////////////////////////////////////////////////////////////////////////////////
                for (integer i = 0; i < num_barriers_p; i++) begin
                    barrier_stall_mask_q[i] <= 0;
                end
                tmasks_q[0]     <= 1; // Activating first thread in first warp
                didnt_split_q   <= 0;
            end else begin
                ////////////////////////////////////////////////////////////////////////////////
                if (twctl_vld_i & twctl_barrier_vld_i) begin
                    stalled_warps_q[twctl_twid_i] <= 0;
                    if (reached_barrier_limit) begin
                        barrier_stall_mask_q[twctl_barrier_id_i] <= 0;
                    end
                end else begin
                    barrier_stall_mask_q[twctl_barrier_id_i][twctl_twid_i] <= 1;
                end else if (twctl_vld_i && twctl_tmc_vld_i) begin
                    thread_masks[twctl_twid_i] <= twctl_tmc_tmask_i;
                    stalled_warps[twctl_twid_i] <= 0;
                end else if (join_vld_i & ~didnt_split_q) begin
                    if (!join_fall) begin
                        tws_pcs_q[join_twid_i] <= join_pc;
                    end
                    tmasks_q[join_twid_i] <= join_tm;
                    didnt_split_q <= 0;
                end else if (twctl_vld_i & twctl_split_vld_i) begin
                    stalled_warps_q[twctl_twid_i] <= 0;
                    if (twctl_split_diverged_i) begin
                        tmasks_q[twctl_twid_i] <= twctl_split_then_mask_i;
                        didnt_split_q <= 0;
                    end
                    else begin
                        didnt_split_q <= 1;
                    end
                end
            end
        end
    end
    endgenerate
    ////////////////////////////////////////////////////////////////////////////////
    // Common S(IMT) logic
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ////////////////////////////////////////////////////////////////////////////////
            use_wspawn_pc_q     <= 0;
            use_wspawn_q        <= 0;
            tws_pcs_q[0]       <= 0;//`STARTUP_ADDR;
            active_tws_q[0]   <= 1; // Activating first warp
            sched_tbl_q[0] <= 1; // set first warp as ready
            stalled_warps_q     <= 0;
            fetch_lock_q        <= 0;
	        ////////////////////////////////////////////////////////////////////////////////
            for (integer i = 1; i < NUM_TW_P; i++) begin
                tws_pcs_q[i]       <= 0;
                active_tws_q[i]   <= 0;
                sched_tbl_q[i] <= 0;
            end
            ////////////////////////////////////////////////////////////////////////////////
        end else begin
            ////////////////////////////////////////////////////////////////////////////////
            if (wctl_vld_i & wctl_wspawn_vld_i) begin
                use_wspawn_q    <= wctl_wspawn_wmask_i & ~{NUM_TW_P{1'b1}};
                use_wspawn_pc_q <= wctl_wspawn_pc_i;
            end
            ////////////////////////////////////////////////////////////////////////////////
            if (use_wspawn[warp_to_schedule] && scheduled_warp) begin
                use_wspawn_q[warp_to_schedule]   <= 0;
                tmasks_q[warp_to_schedule] <= 1;
            end
            if (wstall_vld_i) begin
                stalled_warps_q[wstall_wid_i] <= 1;
            end
            ////////////////////////////////////////////////////////////////////////////////
            // Branch
            ////////////////////////////////////////////////////////////////////////////////
            if (branch_vld_i) begin
                if (branch_taken_i) begin
                    tws_pcs_q[branch_wid_i] <= branch_tgt_i;
                end
                stalled_warps_q[branch_wid_i] <= 0;
            end

            active_tws_q <= active_tws_n_q;
            ////////////////////////////////////////////////////////////////////////////////
            // reset 'schedule_table' when it goes to zero
            ////////////////////////////////////////////////////////////////////////////////
	        sched_table_q <= (| sched_tbl_n_q) ? sched_tbl_n_q:active_tws_n_q;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Lock TW until instruction decode to resolve branches
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (scheduled_warp) begin
            fetch_lock_q[warp_to_schedule] <= 1;
        end
        if (ifetch_rsp_fire) begin
            fetch_lock_q[ifetch_rsp_if.wid] <= 0;
            tws_pcs_q[ifetch_rsp_if.wid] <= ifetch_rsp_if.PC + 4;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////


endmodule
