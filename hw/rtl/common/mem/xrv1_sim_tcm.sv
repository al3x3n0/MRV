module xrv1_sim_tcm
#(
    parameter itcm_size_p = 1 << 16,
    parameter dtcm_size_p = 1 << 16,
    parameter itcm_addr_width_lp = $clog2(itcm_size_p),
    parameter dtcm_addr_width_lp = $clog2(dtcm_size_p)
)
(
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                    clk_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                     imem_req_vld_i,
    output logic                    imem_req_rdy_o,
    input logic [31:0]              imem_req_addr_i,
    output logic                    imem_resp_vld_o,
    output logic [31:0]             imem_resp_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic                     dmem_req_vld_i,
    output  logic                   dmem_req_rdy_o,
    output  logic                   dmem_resp_err_o,
    input logic [31:0]              dmem_req_addr_i,
    input logic                     dmem_req_w_en_i,
    input logic [3:0]               dmem_req_w_be_i,
    input logic [31:0]              dmem_req_w_data_i,
    output  logic                   dmem_resp_vld_o,
    output  logic [31:0]            dmem_resp_r_data_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // Dual-ported RAM sim model
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_sim_ram #(
        .depth_p(itcm_size_p)
    ) itcm_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        ////////////////////////////////////////////////////////////////////////////////
        .addr_0_i                   (imem_req_addr_i[itcm_addr_width_lp-1:0]),
        .addr_1_i                   (dmem_req_addr_i[dtcm_addr_width_lp-1:0]),
        .r_data_0_o                 (imem_resp_data_o),
        .r_data_1_o                 (dmem_resp_r_data_o),
        ////////////////////////////////////////////////////////////////////////////////
        .w_en_1_i                   (dmem_req_w_en_i),
        .w_data_1_i                 (dmem_req_w_data_i),
        .w_be_1_i                   (dmem_req_w_be_i)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////
    assign imem_req_rdy_o = 1'b1;
    assign dmem_req_rdy_o = 1'b1;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
	    imem_resp_vld_o <= imem_req_vld_i;
        dmem_resp_vld_o <= dmem_req_vld_i;
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule
