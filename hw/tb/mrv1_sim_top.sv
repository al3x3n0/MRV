module mrv1_sim_top #(
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P),
    parameter IMEM_TAG_WIDTH_P = TID_WIDTH_LP
) (
    input logic                                 clk_i,
    input logic                                 rst_i
);
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                           imem_req_vld;
    logic                           imem_req_rdy;
    logic [31:0]                    imem_req_addr;
    logic [IMEM_TAG_WIDTH_P-1:0]    imem_req_tag;
    logic                           imem_resp_vld;
    logic [31:0]                    imem_resp_data;
    logic [IMEM_TAG_WIDTH_P-1:0]    imem_resp_tag;
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                           dmem_req_vld;
    logic                           dmem_req_rdy;
    logic                           dmem_resp_err;
    logic [31:0]                    dmem_req_addr;
    logic                           dmem_req_w_en;
    logic [3:0]                     dmem_req_w_be;
    logic [31:0]                    dmem_req_w_data;
    logic                           dmem_resp_vld;
    logic [31:0]                    dmem_resp_r_data;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // MRV1 core instance
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_core #(
        .NUM_THREADS_P              (NUM_THREADS_P),
        .DATA_WIDTH_P               (DATA_WIDTH_P),
        .PC_WIDTH_P                 (PC_WIDTH_P)
    ) core_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_en_i                 (1'b1),
        .simt_en_i                  (1'b0),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld),
        .imem_req_rdy_i             (imem_req_rdy),
        .imem_req_tag_o             (imem_req_tag),
        .imem_req_addr_o            (imem_req_addr),
        .imem_resp_vld_i            (imem_resp_vld),
        .imem_resp_data_i           (imem_resp_data),
        .imem_resp_tag_i            (imem_resp_tag),
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o             (dmem_req_vld),
        .dmem_req_rdy_i             (dmem_req_rdy),
        .dmem_resp_err_i            (/*FIXME*/),
        .dmem_req_addr_o            (dmem_req_addr),
        .dmem_req_w_en_o            (dmem_req_w_en),
        .dmem_req_w_be_o            (dmem_req_w_be),
        .dmem_req_w_data_o          (dmem_req_w_data),
        .dmem_resp_vld_i            (dmem_resp_vld),
        .dmem_resp_r_data_i         (dmem_resp_r_data)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // TCM simulation model
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_sim_tcm #(
        .IMEM_TAG_WIDTH_P           (IMEM_TAG_WIDTH_P)
    ) tcm_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_i             (imem_req_vld),
        .imem_req_rdy_o             (imem_req_rdy),
        .imem_req_tag_i             (imem_req_tag),
        .imem_req_addr_i            (imem_req_addr),
        .imem_resp_vld_o            (imem_resp_vld),
        .imem_resp_data_o           (imem_resp_data),
        .imem_resp_tag_o            (imem_resp_tag),            
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_i             (dmem_req_vld),
        .dmem_req_rdy_o             (dmem_req_rdy),
        .dmem_resp_err_o            (/*FIXME*/),
        .dmem_req_addr_i            (dmem_req_addr),
        .dmem_req_w_en_i            (dmem_req_w_en),
        .dmem_req_w_be_i            (dmem_req_w_be),
        .dmem_req_w_data_i          (dmem_req_w_data),
        .dmem_resp_vld_o            (dmem_resp_vld),
        .dmem_resp_r_data_o         (dmem_resp_r_data)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule
