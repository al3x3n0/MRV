module mrv1_ifetch
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter NUM_TW_P = 8,
    parameter ifq_size_p = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ifq_addr_width_lp = $clog2(ifq_size_p),
    parameter twid_width_lp = $clog(NUM_TW_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                clk_i,
    input  logic                                rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // IFETCH <-> IMEM interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                imem_req_vld_o,
    input  logic                                imem_req_rdy_i,
    output logic [31:0]                         imem_req_addr_o,
    input  logic                                imem_resp_vld_i,
    input  logic [31:0]                         imem_resp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                fetch_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                ifetch_insn_vld_o,
    output logic [31:0]                         ifetch_insn_data_o,
    output logic [31:0]                         ifetch_insn_pc_o,
    output logic [twid_width_lp-1:0]            ifetch_insn_twid_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [wid_width_lp-1:0]              exec_twid_i,
    input logic                                 exec_b_pc_vld_i,
    input logic [31:0]                          exec_b_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [wid_width_lp-1:0]              dec_twid_i,
    input logic                                 dec_j_pc_vld_i,
    input logic [31:0]                          dec_j_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    // SIMT Warp Control
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                join_vld_i,
    input  logic [twid_width_lp-1:0]            join_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                wstall_vld_i,
    input  logic [twid_width_lp-1:0]            wstall_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                twctl_vld_i,
    input  logic [twid_width_lp-1:0]            twctl_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                twctl_tmc_vld_i,
    input  logic [warp_size_p-1:0]              twctl_tmc_tmask_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                twctl_wspawn_vld_i,
    input  logic [num_warps_lp-1:0]             twctl_wspawn_wmask_i,
    input  logic [31:0]                         twctl_wspawn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                twctl_split_vld_i,
    input  logic                                twctl_split_diverged_i,
    input  logic [warp_size_p-1:0]              twctl_split_then_mask_i,
    input  logic [warp_size_p-1:0]              twctl_split_else_mask_i,
    input  logic [31:0]                         twctl_split_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 twctl_barrier_vld_i,
    input logic [barrier_id_width_lp-1:0]       twctl_barrier_id_i,
    input logic [twid_width_lp-1:0]             twctl_barrier_size_m1_i
    ////////////////////////////////////////////////////////////////////////////////
);

    ////////////////////////////////////////////////////////////////////////////////
    logic                                       sched_fetch_req_lo;
    logic [31:0]                                sched_pc_lo;
    logic [twid_width_lp-1:0]                   sched_twid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                                fetch_pc_q;
    logic [twid_width_lp-1:0]                   fetch_twid_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
        end else begin
            fetch_pc_q      <= sched_pc_lo;
            fetch_twid_q    <= sched_twid_lo;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction fetch queue
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    ifq_data_lo;
    logic                           ifq_data_vld_lo;
    logic [31:0]                    ifq_pc_lo;
    logic [twid_width_lp-1:0]       ifq_twid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_ifbuf #(
        .NUM_TW_P (NUM_TW_P)
    ) ifq_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i | dec_j_pc_vld_i | exec_b_pc_vld_i),
        ////////////////////////////////////////////////////////////////////////////////
        .enqueue_i                  (ifq_enqueue_li),
        .dequeue_i                  (ifq_dequeue_li),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_vld_i           (imem_resp_vld_i),
        .fetch_data_i               (imem_resp_data_i),
        .fetch_pc_i                 (fetch_pc_q),
        .fetch_twid_i               (fetch_twid_q),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_data_vld_o           (ifetch_insn_vld_o),
        .fetch_data_o               (ifetch_insn_data_o),
        .fetch_pc_o                 (ifetch_insn_pc_o),
        .fetch_twid_o               (ifetch_insn_twid_o),
        ////////////////////////////////////////////////////////////////////////////////
        .empty_o                    (ifq_empty_lo),
        .full_o                     (ifq_full_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Thread Scheduler
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_tw_sched #(
        .is_simt_master_p (is_simt_master_p),
        .NUM_TW_P (NUM_TW_P)
    ) th_sched_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_wid_i                  (dec_twid_i),
        .dec_j_pc_vld_i             (dec_j_pc_vld_i),
        .dec_j_pc_i                 (dec_j_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_wid_i                 (exec_twid_i),
        .exec_b_pc_vld_i            (exec_b_pc_vld_i),
        .exec_b_pc_i                (exec_b_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sched_vld_o                (sched_fetch_req_lo),
        .sched_twid_o               (sched_twid_lo),
        .sched_pc_o                 (sched_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // SIMT Warp Control
        ////////////////////////////////////////////////////////////////////////////////
        .join_vld_i                 (/*FIXME*/),
        .join_twid_i                (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .wstall_vld_i               (/*FIXME*/),
        .wstall_twid_i              (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .twctl_vld_i                (/*FIXME*/),
        .twctl_twid_i               (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .twctl_tmc_vld_i            (twctl_tmc_vld_i),
        .twctl_tmc_tmask_i          (twctl_tmc_tmask_i),
        ////////////////////////////////////////////////////////////////////////////////
        .twctl_wspawn_vld_i         (twctl_wspawn_vld_i),
        .twctl_wspawn_wmask_i       (twctl_wspawn_wmask_i),
        .twctl_wspawn_pc_i          (twctl_wspawn_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .twctl_split_vld_i          (twctl_split_vld_i),
        .twctl_split_diverged_i     (twctl_split_diverged_i),
        .twctl_split_then_mask_i    (twctl_split_then_mask_i),
        .twctl_split_else_mask_i    (twctl_split_else_mask_i),
        .twctl_split_pc_i           (twctl_split_pc_i),
        ////////////////////////////////////////////////////////////////////////////////
        .twctl_barrier_vld_i        (twctl_barrier_vld_i),
        .twctl_barrier_id_i         (twctl_barrier_id_i),
        .twctl_barrier_size_m1_i    (twctl_barrier_size_m1_i)
        ////////////////////////////////////////////////////////////////////////////////
    );

endmodule
