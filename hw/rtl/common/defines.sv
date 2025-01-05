`define DEFAULT_CPU_RESET_ADDRESS 'h0
`define DEFAULT_RAM_SIZE_BITS 16
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

`ifndef CPU_RESET_ADDRESS
    `define CPU_RESET_ADDRESS `DEFAULT_CPU_RESET_ADDRESS
`endif

`ifndef CPU_RAM_SIZE_BITS
    `define CPU_RAM_SIZE_BITS `DEFAULT_RAM_SIZE_BITS
`endif

`ifndef RV_XLEN
    `define RV_XLEN `DEFAULT_RV_XLEN
`endif

`define REPEAT_MACRO(n,d,arg) `_REPEAT_MACRO_``n(d,arg)
`define _REPEAT_MACRO_0(d,arg) d(0,arg)
`define _REPEAT_MACRO_1(d,arg) `_REPEAT_MACRO_0(d,arg)d(1,arg)
`define _REPEAT_MACRO_2(d,arg) `_REPEAT_MACRO_1(d,arg)d(2,arg)
`define _REPEAT_MACRO_3(d,arg) `_REPEAT_MACRO_2(d,arg)d(3,arg)

`define CASE_READ_REGISTER(n,addr) n: val = core_i[n].cpu_read_register(addr);