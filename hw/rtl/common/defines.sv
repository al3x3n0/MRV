`define DEFAULT_CPU_RESET_ADDRESS 'h0
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

`ifndef CPU_RESET_ADDRESS
    `define CPU_RESET_ADDRESS `DEFAULT_CPU_RESET_ADDRESS
`endif

`define REPEAT_MACRO(n,d,arg) `_REPEAT_MACRO_``n(d,arg)
`define _REPEAT_MACRO_0(d,arg) d(0,arg)
`define _REPEAT_MACRO_1(d,arg) `_REPEAT_MACRO_0(d,arg)d(1,arg)
`define _REPEAT_MACRO_2(d,arg) `_REPEAT_MACRO_1(d,arg)d(2,arg)
`define _REPEAT_MACRO_3(d,arg) `_REPEAT_MACRO_2(d,arg)d(3,arg)

`define CASE_READ_REGISTER(n,addr) n: val = core_i[n].cpu_read_register(addr);