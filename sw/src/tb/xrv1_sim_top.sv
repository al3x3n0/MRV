module xrv1_sim_top
(
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                       imem_req_vld;
    logic                       imem_req_rdy;
    logic [31:0]                imem_req_addr;
    logic                       imem_resp_vld;
    logic [31:0]                imem_resp_data;
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                       dmem_req_vld;
    logic                       dmem_req_rdy;
    logic                       dmem_resp_err;
    logic [31:0]                dmem_req_addr;
    logic                       dmem_req_w_en;
    logic [3:0]                 dmem_req_w_be;
    logic [31:0]                dmem_req_w_data;
    logic                       dmem_resp_vld;
    logic [31:0]                dmem_resp_r_data;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // XRV1 core instance
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_core core_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld),
        .imem_req_rdy_i             (imem_req_rdy),
        .imem_req_addr_o            (imem_req_addr),
        .imem_resp_vld_i            (imem_resp_vld),
        .imem_resp_data_i           (imem_resp_data),
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
    xrv1_sim_tcm tcm_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_i             (imem_req_vld),
        .imem_req_rdy_o             (imem_req_rdy),
        .imem_req_addr_i            (imem_req_addr),
        .imem_resp_vld_o            (imem_resp_vld),
        .imem_resp_data_o           (imem_resp_data),
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
