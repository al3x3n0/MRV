export "DPI-C" task read_register;
task read_register
(
    input int reg_addr,
    output int val
);
    val = 0;//rv_soc_sim_top.core_i[0].rf.read_register(reg_addr);
endtask