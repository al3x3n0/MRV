module mtra_ifetch
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P = 8,
    parameter PC_WIDTH_P = 8,
    parameter INSTR_WIDTH_P = 32,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            clk_i,
    input  logic                                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            imem_wr_en_i,
    input  logic [PC_WIDTH_P-1:0]                           imem_wr_addr_i,
    input  logic [INSTR_WIDTH_P-1:0]                        imem_wr_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_THREADS_P-1:0][INSTR_WIDTH_P-1:0]     instr_data_o,
    output logic [NUM_THREADS_P-1:0][PC_WIDTH_P-1:0]        instr_pc_o,
    output logic [NUM_THREADS_P-1:0]                        instr_vld_o
);
    ////////////////////////////////////////////////////////////////////////////////
    // Thread Scheduler
    ////////////////////////////////////////////////////////////////////////////////
    logic                       th_sched_vld_lo;
    logic [TID_WIDTH_LP-1:0]    th_sched_tid_lo;
    logic [PC_WIDTH_P-1:0]      th_sched_pc_lo;

    mtra_th_sched #(
        .NUM_THREADS_P          (NUM_THREADS_P),
        .PC_WIDTH_P             (PC_WIDTH_P)
    ) th_sched_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .th_spawn_tid_i         (),
        .th_spawn_vld_i         (),
        .th_spawn_pc_i          (),
        .sched_vld_o            (th_sched_vld_lo),
        .sched_tid_o            (th_sched_tid_lo),
        .sched_pc_o             (th_sched_pc_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // IMem
    ////////////////////////////////////////////////////////////////////////////////
    logic [INSTR_WIDTH_P-1:0] imem_data_lo;
    xrv_mem_r1w1 #(
        .DEPTH_P                    (PC_WIDTH_P**2),
        .DATA_WIDTH_P               (INSTR_WIDTH_P)
    ) imem_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_addr_i                  (th_sched_pc_lo),
        .rd_data_o                  (imem_data_lo),
        .wr_en_i                    (imem_wr_en_i),
        .wr_addr_i                  (imem_wr_addr_i),
        .wr_data_i                  (imem_wr_data_i)
    );

    generate
    for (genvar i = 0; i < NUM_THREADS_P; i++) begin
        xrv_queue #(
            .q_size_p               (2),
            .data_width_p           (INSTR_WIDTH_P),
        ) (
            .clk_i                  (clk_i),
            .rst_i                  (rst_i),
            ////////////////////////////////////////////////////////////////////////////////
            .enq_i                  (),
            .deq_i                  (),
            .data_i                 (),
            .data_vld_o             (),
            .data_o                 (),
            .full_o                 (),
            .empty_o                (),
            .size_o                 ()
        );
    end
    endgenerate

endmodule