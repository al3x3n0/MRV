`define DEFAULT_CPU_RESET_ADDRESS 'h2000
`define DEFAULT_RAM_SIZE_BITS 16
///////////////////////////////////////////////////////////////////////////////
`define DEFAULT_RV_XLEN 32
`define DEFAULT_RV_DEBUG_LEVEL 0
///////////////////////////////////////////////////////////////////////////////
`define DEFAULT_RV_HAS_M_EXT 0
`define DEFAULT_RV_HAS_A_EXT 0
`define DEFAULT_RV_HAS_F_EXT 0
`define DEFAULT_RV_HAS_D_EXT 0
`define DEFAULT_RV_HAS_ZICSR_EXT 0
`define DEFAULT_RV_HAS_ZIFENCEI_EXT 0
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

`ifndef RV_DEBUG_LEVEL
    `define RV_DEBUG_LEVEL `DEFAULT_RV_DEBUG_LEVEL
`endif

`ifndef RV_HAS_M_EXT
    `define RV_HAS_M_EXT `DEFAULT_RV_HAS_M_EXT
`endif

`ifndef RV_HAS_A_EXT
    `define RV_HAS_A_EXT `DEFAULT_RV_HAS_A_EXT
`endif

`ifndef RV_HAS_F_EXT
    `define RV_HAS_F_EXT `DEFAULT_RV_HAS_F_EXT
`endif

`ifndef RV_HAS_D_EXT
    `define RV_HAS_D_EXT `DEFAULT_RV_HAS_D_EXT
`endif

`ifndef RV_HAS_ZICSR_EXT
    `define RV_HAS_ZICSR_EXT `DEFAULT_RV_HAS_ZICSR_EXT
`endif

`ifndef RV_HAS_ZIFENCEI_EXT
    `define RV_HAS_ZIFENCEI_EXT `DEFAULT_RV_HAS_ZIFENCEI_EXT
`endif