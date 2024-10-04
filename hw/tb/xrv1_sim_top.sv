`include "rtl/common/defines.sv"

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
    xrv1_core #(.CORE_RESET_ADDR(`CPU_RESET_ADDRESS)) core_i (
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
    xrv1_sim_tcm #(.itcm_size_p(1 << `CPU_RAM_SIZE_BITS), .dtcm_size_p(1 << `CPU_RAM_SIZE_BITS)) tcm_i (
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

export "DPI-C" task read_register;
task read_register
(
    input int reg_addr,
    output int val
);
    val = xrv1_sim_top.core_i.rf.read_reg(reg_addr);
endtask

export "DPI-C" task get_ram_size_bits;
task get_ram_size_bits
(
    output int bits
);
    bits = xrv1_sim_top.tcm_i.itcm_size_p;
endtask

export "DPI-C" task write_u8;
task write_u8
(
    input int addr,
    input byte data
);
    xrv1_sim_top.tcm_i.itcm_i.write_u8(addr, data);
endtask

export "DPI-C" task read_u8;
task read_u8
(
    input int addr,
    output byte data
);
    data = xrv1_sim_top.tcm_i.itcm_i.read_u8(addr);
endtask

export "DPI-C" task get_imem_resp_vld;
task get_imem_resp_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_imem_resp_vld();
endtask

export "DPI-C" task get_imem_resp_data;
task get_imem_resp_data
(
    output int data
);
    data = xrv1_sim_top.core_i.get_imem_resp_data();
endtask

export "DPI-C" task get_imem_req_vld;
task get_imem_req_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_imem_req_vld();
endtask

export "DPI-C" task get_ifetch_insn_data;
task get_ifetch_insn_data
(
    output int data
);
    data = xrv1_sim_top.core_i.get_ifetch_insn_data();
endtask


export "DPI-C" task get_ifetch_insn_pc;
task get_ifetch_insn_pc
(
    output int pc
);
    pc = xrv1_sim_top.core_i.get_ifetch_insn_pc();
endtask

export "DPI-C" task get_ifetch_insn_vld;
task get_ifetch_insn_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_ifetch_insn_vld();
endtask

export "DPI-C" task get_if_dec_insn_data;
task get_if_dec_insn_data
(
    output int data
);
    data = xrv1_sim_top.core_i.get_if_dec_insn_data();
endtask

export "DPI-C" task get_if_dec_insn_pc;
task get_if_dec_insn_pc
(
    output int pc
);
    pc = xrv1_sim_top.core_i.get_if_dec_insn_pc();
endtask

export "DPI-C" task get_if_dec_insn_vld;
task get_if_dec_insn_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_if_dec_insn_vld();
endtask

export "DPI-C" task get_wb_data_vld;
task get_wb_data_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_wb_data_vld();
endtask

export "DPI-C" task get_wb_data;
task get_wb_data
(
    output int data
);
    data = xrv1_sim_top.core_i.get_wb_data();
endtask

export "DPI-C" task get_wb_rd_addr;
task get_wb_rd_addr
(
    output byte addr
);
    addr = xrv1_sim_top.core_i.get_wb_rd_addr();
endtask

export "DPI-C" task get_idecode_issue_vld;
task get_idecode_issue_vld
(
    output byte valid
);
    valid = xrv1_sim_top.core_i.get_idecode_issue_vld();
endtask

export "DPI-C" task get_idecode_itag;
task get_idecode_itag
(
    output byte itag
);
    itag = xrv1_sim_top.core_i.get_idecode_itag();
endtask

export "DPI-C" task get_ret_retire_cnt;
task get_ret_retire_cnt
(
    output byte cnt
);
    cnt = xrv1_sim_top.core_i.get_ret_retire_cnt();
endtask

export "DPI-C" task get_iq_retire_itag;
task get_iq_retire_itag
(
    output byte itag
);
    itag = xrv1_sim_top.core_i.get_iq_retire_itag();
endtask

endmodule
