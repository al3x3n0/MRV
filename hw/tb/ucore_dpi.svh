export "DPI-C" task read_register;
task read_register
(
    input int reg_addr,
    output int val
);
    val = xrv1_sim_top.core_i.rf.read_reg(reg_addr);
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
