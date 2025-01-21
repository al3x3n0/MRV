import mrv1_pkg::*;
import xrv1_pkg::*;


module mrv1_lsu #(
    parameter XLEN_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_THREADS_P = "inv"
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        clk_i,
    input  logic                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        lsu_rdy_o,
    input logic [ITAG_WIDTH_P-1:0]      exec_itag_i,
    input logic [TID_WIDTH_LP-1:0]      exec_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        dmem_req_vld_o,
    input  logic                        dmem_req_rdy_i,
    input  logic                        dmem_resp_err_i,
    output logic [ADDR_WIDTH_P-1:0]     dmem_req_addr_o,
    output logic                        dmem_req_w_en_o,
    output logic [DATA_BE_WIDTH_P-1:0]  dmem_req_w_be_o,
    output logic [DMEM_TAG_WIDTH_P-1:0] dmem_req_tag_o,
    output logic [DATA_WIDTH_P-1:0]     dmem_req_w_data_o,
    input  logic                        dmem_resp_vld_i,
    input  logic [DMEM_TAG_WIDTH_P-1:0] dmem_resp_tag_i,
    input  logic [DATA_WIDTH_P-1:0]     dmem_resp_r_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU request
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        lsu_req_i,
    input  logic                        lsu_req_w_en_i,
    input  logic [ADDR_WIDTH_P-1:0]     lsu_req_addr_base_i,
    input  logic [ADDR_WIDTH_P-1:0]     lsu_req_addr_offset_i,
    input  logic [1:0]                  lsu_req_size_i,
    input  logic                        lsu_req_signed_i,
    input  logic [DATA_WIDTH_P-1:0]     lsu_req_w_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Write back interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        lsu_done_o,
    output logic [DATA_WIDTH_P-1:0]     lsu_wb_data_o,
    output logic [ITAG_WIDTH_P-1:0]     lsu_itag_o,
    output logic [TID_WIDTH_LP-1:0]     lsu_tid_o
    ////////////////////////////////////////////////////////////////////////////////
);
    localparam PC_WIDTH_P = XLEN_P;
    localparam ADDR_WIDTH_P = XLEN_P;
    localparam DATA_WIDTH_P = XLEN_P;
    localparam DATA_BE_WIDTH_P = DATA_WIDTH_P >> 3;
    localparam DATA_BE_WIDTH_LOG = $clog2(DATA_BE_WIDTH_P);
    localparam TID_WIDTH_LP = $clog2(NUM_THREADS_P);
    localparam DMEM_TAG_WIDTH_P = ITAG_WIDTH_P + TID_WIDTH_LP;
    ////////////////////////////////////////////////////////////////////////////////
    wire dmem_req_accept_w = dmem_req_rdy_i & dmem_req_vld_o;
    wire lsu_accept_w = lsu_req_i & lsu_rdy_o;

    ////////////////////////////////////////////////////////////////////////////////
    // LSU request address calculation
    ////////////////////////////////////////////////////////////////////////////////
    wire [XLEN_P-1:0] lsu_req_addr_w = lsu_req_addr_base_i + lsu_req_addr_offset_i;
    wire [XLEN_P-1:0] lsu_req_addr_algn_w = {lsu_req_addr_w[XLEN_P-1:DATA_BE_WIDTH_LOG-1], {(DATA_BE_WIDTH_LOG-1){1'b0}}};
    wire [DATA_BE_WIDTH_LOG-1:0]  lsu_req_offset_w = lsu_req_addr_w[DATA_BE_WIDTH_LOG-1:0];

    ////////////////////////////////////////////////////////////////////////////////
    // Check whether access is unaligned
    ////////////////////////////////////////////////////////////////////////////////
    wire         w_ls_acc_w = lsu_req_size_i == LS_W;
    wire         h_ls_acc_w = lsu_req_size_i == LS_H;
    wire         b_ls_acc_w = lsu_req_size_i == LS_B;
    wire         d_ls_acc_w = lsu_req_size_i == LS_D;
    ////////////////////////////////////////////////////////////////////////////////
    wire         unaligned_d_acc_w = (XLEN_P == 32) ? 1'b0 : d_ls_acc_w & lsu_req_addr_w[2:0] != 3'b000;
    wire         unaligned_w_acc_w = w_ls_acc_w & lsu_req_addr_w[1:0] != 2'b00;
    wire         unaligned_h_acc_w = h_ls_acc_w & lsu_req_addr_w[1:0] == 2'b11;
    wire         unaligned_acc_w = unaligned_w_acc_w | unaligned_h_acc_w | unaligned_d_acc_w;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // DMEM read response
    ////////////////////////////////////////////////////////////////////////////////
    logic [ITAG_WIDTH_P-1:0] dmem_resp_itag_li;
    logic [TID_WIDTH_LP-1:0] dmem_resp_tid_li;
    assign {
        dmem_resp_itag_li,
        dmem_resp_tid_li
    } = dmem_resp_tag_i;

    logic                                           sched_req_vld_lo;
    logic [TID_WIDTH_LP-1:0]                        sched_req_tid_lo;
    logic [NUM_THREADS_P-1:0]                       mem_req_rdy_li;
    logic [NUM_THREADS_P-1:0]                       sched_req_rdy_li;

    logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]     mem_commit_data_lo;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]     mem_commit_itag_lo;
    logic [NUM_THREADS_P-1:0]                       mem_commit_rdy_lo;
    logic                                           mem_commit_vld_lo;
    logic [TID_WIDTH_LP-1:0]                        mem_commit_tid_lo;

    logic [NUM_THREADS_P-1:0]                       dmem_req_vld_lo;
    logic [NUM_THREADS_P-1:0][ADDR_WIDTH_P-1:0]     dmem_req_addr_lo;
    logic [NUM_THREADS_P-1:0]                       dmem_req_w_en_lo;
    logic [NUM_THREADS_P-1:0][DATA_BE_WIDTH_P-1:0]  dmem_req_w_be_lo;
    logic [NUM_THREADS_P-1:0][ITAG_WIDTH_P-1:0]     dmem_req_itag_lo;
    logic [NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]     dmem_req_w_data_lo;

    generate
    for (genvar i = 0; i < NUM_THREADS_P; i++) begin;
        wire lsu_req_vld_li = lsu_req_i && exec_tid_i == TID_WIDTH_LP'(i);
        wire dmem_resp_vld_li = dmem_resp_vld_i && dmem_resp_tid_li == TID_WIDTH_LP'(i);
        wire mem_commit_vld_li = mem_commit_vld_lo && mem_commit_tid_lo == TID_WIDTH_LP'(i);
        wire sched_req_vld_li = sched_req_vld_lo && sched_req_tid_lo == TID_WIDTH_LP'(i);
        assign mem_req_rdy_li[i] = dmem_req_rdy_i && dmem_req_vld_lo[i];

        mrv1_mem_queue #(
            .XLEN_P                     (ADDR_WIDTH_P),
            .ITAG_WIDTH_P               (ITAG_WIDTH_P),
            .NUM_THREADS_P              (NUM_THREADS_P)
        ) q_i (
            .clk_i                      (clk_i),
            .rst_i                      (rst_i),
            ////////////////////////////////////////////////////////////////////////////////
            .lsu_req_vld_i              (lsu_req_vld_li),
            .lsu_req_w_en_i             (lsu_req_w_en_i),
            .lsu_req_addr_i             (lsu_req_addr_algn_w),
            .lsu_req_size_i             (lsu_req_size_i),
            .lsu_req_offset_i           (lsu_req_offset_w),
            .lsu_req_unalgn_i           (unaligned_acc_w),
            .lsu_req_signed_i           (lsu_req_signed_i),
            .lsu_req_w_data_i           (lsu_req_w_data_i),
            .lsu_req_itag_i             (exec_itag_i),
            //////////////////////////////////////////////////////////
            .dmem_req_rdy_i             (dmem_req_rdy_i),
            .dmem_req_vld_o             (dmem_req_vld_lo[i]),
            .dmem_req_addr_o            (dmem_req_addr_lo[i]),
            .dmem_req_wnr_o             (dmem_req_w_en_lo[i]),
            .dmem_req_itag_o            (dmem_req_itag_lo[i]),
            .dmem_req_w_be_o            (dmem_req_w_be_lo[i]),
            .dmem_req_w_data_o          (dmem_req_w_data_lo[i]),
            //////////////////////////////////////////////////////////
            .dmem_resp_vld_i            (dmem_resp_vld_li),
            .dmem_resp_itag_i           (dmem_resp_itag_li),
            .dmem_resp_r_data_i         (dmem_resp_r_data_i),
            //////////////////////////////////////////////////////////
            .mem_sched_req_rdy_o        (sched_req_rdy_li[i]),
            .mem_sched_req_vld_i        (sched_req_vld_li),
            //////////////////////////////////////////////////////////
            .mem_commit_data_o          (mem_commit_data_lo[i]),
            .mem_commit_itag_o          (mem_commit_itag_lo[i]),
            .mem_commit_rdy_o           (mem_commit_rdy_lo[i]),
            .mem_commit_vld_i           (mem_commit_vld_li)
        );
    end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////
    assign lsu_rdy_o            = 1'b1; // ???
    ////////////////////////////////////////////////////////////////////////////////
    // Commit MUX
    ////////////////////////////////////////////////////////////////////////////////
    assign lsu_done_o           = mem_commit_vld_lo;
    assign lsu_wb_data_o        = mem_commit_data_lo[mem_commit_tid_lo];
    assign lsu_itag_o           = mem_commit_itag_lo[mem_commit_tid_lo];
    assign lsu_tid_o            = mem_commit_tid_lo;
    ////////////////////////////////////////////////////////////////////////////////
    // DMEM Request MUX
    ////////////////////////////////////////////////////////////////////////////////
    assign dmem_req_vld_o       = sched_req_vld_lo;
    assign dmem_req_addr_o      = dmem_req_addr_lo[sched_req_tid_lo];
    assign dmem_req_w_en_o      = dmem_req_w_en_lo[sched_req_tid_lo];
    assign dmem_req_w_be_o      = dmem_req_w_be_lo[sched_req_tid_lo];
    assign dmem_req_tag_o       = {dmem_req_itag_lo[sched_req_tid_lo], sched_req_tid_lo};
    assign dmem_req_w_data_o    = dmem_req_w_data_lo[sched_req_tid_lo];

    ////////////////////////////////////////////////////////////////////////////////
    mrv1_rr_th_scheduler #(
        .NUM_THREADS_P              (NUM_THREADS_P)
    ) req_sched_i (
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sched_rdy_i                (mem_req_rdy_li),
        .sched_vld_o                (sched_req_vld_lo),
        .sched_tid_o                (sched_req_tid_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
    // LSU -> Commit 
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_rr_th_scheduler #(
        .NUM_THREADS_P              (NUM_THREADS_P)
    ) commit_sched_i (
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sched_rdy_i                (mem_commit_rdy_lo),
        .sched_vld_o                (mem_commit_vld_lo),
        .sched_tid_o                (mem_commit_tid_lo)
    );

    always_comb begin
        if (dmem_req_vld_o) begin
            $display("[DMEM] vld=%b addr=%h wnr=%b", dmem_req_vld_o, dmem_req_addr_o, dmem_req_w_en_o);
        end
    end

endmodule