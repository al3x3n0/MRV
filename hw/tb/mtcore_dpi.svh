export "DPI-C" task read_register;
task read_register
(
    input int reg_addr,
    output int val
);
    val = xrv1_sim_top.core_i.rf_i.read_reg(0, reg_addr);
endtask