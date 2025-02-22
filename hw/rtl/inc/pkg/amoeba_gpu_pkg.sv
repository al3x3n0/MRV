// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef VX_GPU_PKG_VH
`define VX_GPU_PKG_VH

`include "xm_macro.svh"

`define ASSIGN_VX_IF(dst, src) \
    assign dst.valid = src.valid; \
    assign dst.data  = src.data; \
    assign src.ready = dst.ready

package amoeba_gpu_pkg;

    localparam VX_LMEM_ENABLED            = 0;
    localparam VX_MEM_REQ_FLAG_FLUSH      = 0;
    localparam VX_MEM_REQ_FLAG_IO         = 1;
    localparam VX_MEM_REQ_FLAG_LOCAL      = 2; // shoud be last since optional
    localparam VX_MEM_REQ_FLAGS_WIDTH     = (VX_MEM_REQ_FLAG_LOCAL + VX_LMEM_ENABLED);

    // Device identification //////////////////////////////////////////////////////

    localparam VX_VENDOR_ID           = 0;
    localparam VX_ARCHITECTURE_ID     = 0;
    localparam VX_IMPLEMENTATION_ID   = 0;

    // Device configuration registers /////////////////////////////////////////////
    localparam VX_CSR_ADDR_BITS                = 12;
    localparam VX_DCR_ADDR_BITS                = 12;

    localparam VX_DCR_BASE_STATE_BEGIN         = 12'h001;
    localparam VX_DCR_BASE_STARTUP_ADDR0       = 12'h001;
    localparam VX_DCR_BASE_STARTUP_ADDR1       = 12'h002;
    localparam VX_DCR_BASE_STARTUP_ARG0        = 12'h003;
    localparam VX_DCR_BASE_STARTUP_ARG1        = 12'h004;
    localparam VX_DCR_BASE_MPM_CLASS           = 12'h005;
    localparam VX_DCR_BASE_STATE_END           = 12'h006;

    `define VX_DCR_BASE_STATE(addr)         ((addr) - VX_DCR_BASE_STATE_BEGIN)
    `define VX_DCR_BASE_STATE_COUNT         (VX_DCR_BASE_STATE_END-VX_DCR_BASE_STATE_BEGIN)

    // Machine Performance-monitoring counters classes ////////////////////////////

    localparam VX_DCR_MPM_CLASS_NONE           = 0;
    localparam VX_DCR_MPM_CLASS_CORE           = 1;
    localparam VX_DCR_MPM_CLASS_MEM            = 2;

    // User Floating-Point CSRs ///////////////////////////////////////////////////

    localparam VX_CSR_FFLAGS                   = 12'h001;
    localparam VX_CSR_FRM                      = 12'h002;
    localparam VX_CSR_FCSR                     = 12'h003;

    localparam VX_CSR_SATP                     = 12'h180;

    localparam VX_CSR_PMPCFG0                  = 12'h3A0;
    localparam VX_CSR_PMPADDR0                 = 12'h3B0;

    localparam VX_CSR_MSTATUS                  = 12'h300;
    localparam VX_CSR_MISA                     = 12'h301;
    localparam VX_CSR_MEDELEG                  = 12'h302;
    localparam VX_CSR_MIDELEG                  = 12'h303;
    localparam VX_CSR_MIE                      = 12'h304;
    localparam VX_CSR_MTVEC                    = 12'h305;

    localparam VX_CSR_MSCRATCH                 = 12'h340;
    localparam VX_CSR_MEPC                     = 12'h341;
    localparam VX_CSR_MCAUSE                   = 12'h342;

    localparam VX_CSR_MNSTATUS                 = 12'h744;

    localparam VX_CSR_MPM_BASE                 = 12'hB00;
    localparam VX_CSR_MPM_BASE_H               = 12'hB80;
    localparam VX_CSR_MPM_USER                 = 12'hB03;
    localparam VX_CSR_MPM_USER_H               = 12'hB83;

    // Machine Performance-monitoring core counters (Standard) ////////////////////

    localparam VX_CSR_MCYCLE                   = 12'hB00;
    localparam VX_CSR_MCYCLE_H                 = 12'hB80;
    localparam VX_CSR_MPM_RESERVED             = 12'hB01;
    localparam VX_CSR_MPM_RESERVED_H           = 12'hB81;
    localparam VX_CSR_MINSTRET                 = 12'hB02;
    localparam VX_CSR_MINSTRET_H               = 12'hB82;

    // Machine Performance-monitoring core counters (class 1) /////////////////////

    // PERF: pipeline
    localparam VX_CSR_MPM_SCHED_ID             = 12'hB03;
    localparam VX_CSR_MPM_SCHED_ID_H           = 12'hB83;
    localparam VX_CSR_MPM_SCHED_ST             = 12'hB04;
    localparam VX_CSR_MPM_SCHED_ST_H           = 12'hB84;
    localparam VX_CSR_MPM_IBUF_ST              = 12'hB05;
    localparam VX_CSR_MPM_IBUF_ST_H            = 12'hB85;
    localparam VX_CSR_MPM_SCRB_ST              = 12'hB06;
    localparam VX_CSR_MPM_SCRB_ST_H            = 12'hB86;
    localparam VX_CSR_MPM_OPDS_ST              = 12'hB07;
    localparam VX_CSR_MPM_OPDS_ST_H            = 12'hB87;
    localparam VX_CSR_MPM_SCRB_ALU             = 12'hB08;
    localparam VX_CSR_MPM_SCRB_ALU_H           = 12'hB88;
    localparam VX_CSR_MPM_SCRB_FPU             = 12'hB09;
    localparam VX_CSR_MPM_SCRB_FPU_H           = 12'hB89;
    localparam VX_CSR_MPM_SCRB_LSU             = 12'hB0A;
    localparam VX_CSR_MPM_SCRB_LSU_H           = 12'hB8A;
    localparam VX_CSR_MPM_SCRB_SFU             = 12'hB0B;
    localparam VX_CSR_MPM_SCRB_SFU_H           = 12'hB8B;
    localparam VX_CSR_MPM_SCRB_CSRS            = 12'hB0C;
    localparam VX_CSR_MPM_SCRB_CSRS_H          = 12'hB8C;
    localparam VX_CSR_MPM_SCRB_WCTL            = 12'hB0D;
    localparam VX_CSR_MPM_SCRB_WCTL_H          = 12'hB8D;
    // PERF: memory
    localparam VX_CSR_MPM_IFETCHES             = 12'hB0E;
    localparam VX_CSR_MPM_IFETCHES_H           = 12'hB8E;
    localparam VX_CSR_MPM_LOADS                = 12'hB0F;
    localparam VX_CSR_MPM_LOADS_H              = 12'hB8F;
    localparam VX_CSR_MPM_STORES               = 12'hB10;
    localparam VX_CSR_MPM_STORES_H             = 12'hB90;
    localparam VX_CSR_MPM_IFETCH_LT            = 12'hB11;
    localparam VX_CSR_MPM_IFETCH_LT_H          = 12'hB91;
    localparam VX_CSR_MPM_LOAD_LT              = 12'hB12;
    localparam VX_CSR_MPM_LOAD_LT_H            = 12'hB92;

    // Machine Performance-monitoring memory counters (class 2) ///////////////////

    // PERF: icache
    localparam VX_CSR_MPM_ICACHE_READS         = 12'hB03;     // total reads
    localparam VX_CSR_MPM_ICACHE_READS_H       = 12'hB83;
    localparam VX_CSR_MPM_ICACHE_MISS_R        = 12'hB04;     // read misses
    localparam VX_CSR_MPM_ICACHE_MISS_R_H      = 12'hB84;
    localparam VX_CSR_MPM_ICACHE_MSHR_ST       = 12'hB05;     // MSHR stalls
    localparam VX_CSR_MPM_ICACHE_MSHR_ST_H     = 12'hB85;
    // PERF: dcache
    localparam VX_CSR_MPM_DCACHE_READS         = 12'hB06;     // total reads
    localparam VX_CSR_MPM_DCACHE_READS_H       = 12'hB86;
    localparam VX_CSR_MPM_DCACHE_WRITES        = 12'hB07;     // total writes
    localparam VX_CSR_MPM_DCACHE_WRITES_H      = 12'hB87;
    localparam VX_CSR_MPM_DCACHE_MISS_R        = 12'hB08;     // read misses
    localparam VX_CSR_MPM_DCACHE_MISS_R_H      = 12'hB88;
    localparam VX_CSR_MPM_DCACHE_MISS_W        = 12'hB09;     // write misses
    localparam VX_CSR_MPM_DCACHE_MISS_W_H      = 12'hB89;
    localparam VX_CSR_MPM_DCACHE_BANK_ST       = 12'hB0A;     // bank conflicts
    localparam VX_CSR_MPM_DCACHE_BANK_ST_H     = 12'hB8A;
    localparam VX_CSR_MPM_DCACHE_MSHR_ST       = 12'hB0B;     // MSHR stalls
    localparam VX_CSR_MPM_DCACHE_MSHR_ST_H     = 12'hB8B;
    // PERF: l2cache
    localparam VX_CSR_MPM_L2CACHE_READS        = 12'hB0C;     // total reads
    localparam VX_CSR_MPM_L2CACHE_READS_H      = 12'hB8C;
    localparam VX_CSR_MPM_L2CACHE_WRITES       = 12'hB0D;     // total writes
    localparam VX_CSR_MPM_L2CACHE_WRITES_H     = 12'hB8D;
    localparam VX_CSR_MPM_L2CACHE_MISS_R       = 12'hB0E;     // read misses
    localparam VX_CSR_MPM_L2CACHE_MISS_R_H     = 12'hB8E;
    localparam VX_CSR_MPM_L2CACHE_MISS_W       = 12'hB0F;     // write misses
    localparam VX_CSR_MPM_L2CACHE_MISS_W_H     = 12'hB8F;
    localparam VX_CSR_MPM_L2CACHE_BANK_ST      = 12'hB10;     // bank conflicts
    localparam VX_CSR_MPM_L2CACHE_BANK_ST_H    = 12'hB90;
    localparam VX_CSR_MPM_L2CACHE_MSHR_ST      = 12'hB11;     // MSHR stalls
    localparam VX_CSR_MPM_L2CACHE_MSHR_ST_H    = 12'hB91;
    // PERF: l3cache
    localparam VX_CSR_MPM_L3CACHE_READS        = 12'hB12;     // total reads
    localparam VX_CSR_MPM_L3CACHE_READS_H      = 12'hB92;
    localparam VX_CSR_MPM_L3CACHE_WRITES       = 12'hB13;     // total writes
    localparam VX_CSR_MPM_L3CACHE_WRITES_H     = 12'hB93;
    localparam VX_CSR_MPM_L3CACHE_MISS_R       = 12'hB14;     // read misses
    localparam VX_CSR_MPM_L3CACHE_MISS_R_H     = 12'hB94;
    localparam VX_CSR_MPM_L3CACHE_MISS_W       = 12'hB15;     // write misses
    localparam VX_CSR_MPM_L3CACHE_MISS_W_H     = 12'hB95;
    localparam VX_CSR_MPM_L3CACHE_BANK_ST      = 12'hB16;     // bank conflicts
    localparam VX_CSR_MPM_L3CACHE_BANK_ST_H    = 12'hB96;
    localparam VX_CSR_MPM_L3CACHE_MSHR_ST      = 12'hB17;     // MSHR stalls
    localparam VX_CSR_MPM_L3CACHE_MSHR_ST_H    = 12'hB97;
    // PERF: memory
    localparam VX_CSR_MPM_MEM_READS            = 12'hB18;     // total reads
    localparam VX_CSR_MPM_MEM_READS_H          = 12'hB98;
    localparam VX_CSR_MPM_MEM_WRITES           = 12'hB19;     // total writes
    localparam VX_CSR_MPM_MEM_WRITES_H         = 12'hB99;
    localparam VX_CSR_MPM_MEM_LT               = 12'hB1A;     // memory latency
    localparam VX_CSR_MPM_MEM_LT_H             = 12'hB9A;
    localparam VX_CSR_MPM_MEM_BANK_CNTR        = 12'hB1E;     // memory bank requests
    localparam VX_CSR_MPM_MEM_BANK_CNTR_H      = 12'hB9E;
    localparam VX_CSR_MPM_MEM_BANK_TICK        = 12'hB1F;     // memory ticks
    localparam VX_CSR_MPM_MEM_BANK_TICK_H      = 12'hB9F;
    // PERF: lmem
    localparam VX_CSR_MPM_LMEM_READS           = 12'hB1B;     // memory reads
    localparam VX_CSR_MPM_LMEM_READS_H         = 12'hB9B;
    localparam VX_CSR_MPM_LMEM_WRITES          = 12'hB1C;     // memory writes
    localparam VX_CSR_MPM_LMEM_WRITES_H        = 12'hB9C;
    localparam VX_CSR_MPM_LMEM_BANK_ST         = 12'hB1D;     // bank conflicts
    localparam VX_CSR_MPM_LMEM_BANK_ST_H       = 12'hB9D;

    // Machine Performance-monitoring memory counters (class 3) ///////////////////
    // <Add your own counters: use addresses hB03..B1F, hB83..hB9F>

    // Machine Information Registers //////////////////////////////////////////////

    localparam VX_CSR_MVENDORID                = 12'hF11;
    localparam VX_CSR_MARCHID                  = 12'hF12;
    localparam VX_CSR_MIMPID                   = 12'hF13;
    localparam VX_CSR_MHARTID                  = 12'hF14;

    // Vector CSRs

    localparam VX_CSR_VSTART                   = 12'h008;
    localparam VX_CSR_VXSAT                    = 12'h009;
    localparam VX_CSR_VXRM                     = 12'h00A;
    localparam VX_CSR_VCSR                     = 12'h00F;
    localparam VX_CSR_VL                       = 12'hC20;
    localparam VX_CSR_VTYPE                    = 12'hC21;
    localparam VX_CSR_VLENB                    = 12'hC22;
    localparam VX_CSR_VCYCLE                   = 12'hC00;
    localparam VX_CSR_VTIME                    = 12'hC01;
    localparam VX_CSR_VINSTRET                 = 12'hC02;

    // GPGU CSRs

    localparam VX_CSR_THREAD_ID                = 12'hCC0;
    localparam VX_CSR_WARP_ID                  = 12'hCC1;
    localparam VX_CSR_CORE_ID                  = 12'hCC2;
    localparam VX_CSR_ACTIVE_WARPS             = 12'hCC3;
    localparam VX_CSR_ACTIVE_THREADS           = 12'hCC4;     // warning! this value is also used in LLVM

    localparam VX_CSR_NUM_THREADS              = 12'hFC0;
    localparam VX_CSR_NUM_WARPS                = 12'hFC1;
    localparam VX_CSR_NUM_CORES                = 12'hFC2;
    localparam VX_CSR_LOCAL_MEM_BASE           = 12'hFC3;


    localparam VX_OFFSET_BITS     = 12;
    localparam VX_IMM_BITS        = 64; // FIXME XLEN_P

    ///////////////////////////////////////////////////////////////////////////////
    localparam VX_INST_LUI        = 7'b0110111;
    localparam VX_INST_AUIPC      = 7'b0010111;
    localparam VX_INST_JAL        = 7'b1101111;
    localparam VX_INST_JALR       = 7'b1100111;
    localparam VX_INST_B          = 7'b1100011; // branch instructions
    localparam VX_INST_L          = 7'b0000011; // load instructions
    localparam VX_INST_S          = 7'b0100011; // store instructions
    localparam VX_INST_I          = 7'b0010011; // immediate instructions
    localparam VX_INST_R          = 7'b0110011; // register instructions
    localparam VX_INST_FENCE      = 7'b0001111; // Fence instructions
    localparam VX_INST_SYS        = 7'b1110011; // system instructions

    // RV64I instruction specific opcodes (for any W instruction)
    localparam VX_INST_I_W        = 7'b0011011; // W type immediate instructions
    localparam VX_INST_R_W        = 7'b0111011; // W type register instructions

    localparam VX_INST_FL         = 7'b0000111; // float load instruction
    localparam VX_INST_FS         = 7'b0100111; // float store  instruction
    localparam VX_INST_FMADD      = 7'b1000011;
    localparam VX_INST_FMSUB      = 7'b1000111;
    localparam VX_INST_FNMSUB     = 7'b1001011;
    localparam VX_INST_FNMADD     = 7'b1001111;
    localparam VX_INST_FCI        = 7'b1010011; // float common instructions

    // Custom extension opcodes
    localparam VX_INST_EXT1       = 7'b0001011; // 0x0B
    localparam VX_INST_EXT2       = 7'b0101011; // 0x2B
    localparam VX_INST_EXT3       = 7'b1011011; // 0x5B
    localparam VX_INST_EXT4       = 7'b1111011; // 0x7B

    // Opcode extensions
    localparam VX_INST_R_F7_MUL     = 7'b0000001;
    localparam VX_INST_R_F7_ZICOND  = 7'b0000111;

    ///////////////////////////////////////////////////////////////////////////////

    localparam VX_INST_FRM_RNE    = 3'b000;  // round to nearest even
    localparam VX_INST_FRM_RTZ    = 3'b001;  // round to zero
    localparam VX_INST_FRM_RDN    = 3'b010;  // round to -inf
    localparam VX_INST_FRM_RUP    = 3'b011;  // round to +inf
    localparam VX_INST_FRM_RMM    = 3'b100;  // round to nearest max magnitude
    localparam VX_INST_FRM_DYN    = 3'b111;  // dynamic mode
    localparam VX_INST_FRM_BITS   = 3;

    ///////////////////////////////////////////////////////////////////////////////

    localparam VX_INST_OP_BITS    = 4;
    localparam VX_INST_ARGS_BITS  = $bits(op_args_t);
    localparam VX_INST_FMT_BITS   = 2;

    ///////////////////////////////////////////////////////////////////////////////

    localparam VX_INST_ALU_ADD         = 4'b0000;
    //localparam VX_INST_ALU_UNUSED    = 4'b0001;
    localparam VX_INST_ALU_LUI         = 4'b0010;
    localparam VX_INST_ALU_AUIPC       = 4'b0011;
    localparam VX_INST_ALU_SLTU        = 4'b0100;
    localparam VX_INST_ALU_SLT         = 4'b0101;
    //localparam VX_INST_ALU_UNUSED    = 4'b0110;
    localparam VX_INST_ALU_SUB         = 4'b0111;
    localparam VX_INST_ALU_SRL         = 4'b1000;
    localparam VX_INST_ALU_SRA         = 4'b1001;
    localparam VX_INST_ALU_CZEQ        = 4'b1010;
    localparam VX_INST_ALU_CZNE        = 4'b1011;
    localparam VX_INST_ALU_AND         = 4'b1100;
    localparam VX_INST_ALU_OR          = 4'b1101;
    localparam VX_INST_ALU_XOR         = 4'b1110;
    localparam VX_INST_ALU_SLL         = 4'b1111;


    localparam VX_ALU_TYPE_BITS        = 2;
    localparam VX_ALU_TYPE_ARITH       = 0;
    localparam VX_ALU_TYPE_BRANCH      = 1;
    localparam VX_ALU_TYPE_MULDIV      = 2;
    localparam VX_ALU_TYPE_OTHER       = 3;

    localparam VX_INST_ALU_BITS        = 4;

    `define VX_INST_ALU_CLASS(op)   op[3:2]
    `define VX_INST_ALU_SIGNED(op)  op[0]
    `define VX_INST_ALU_IS_SUB(op)  op[1]
    `define VX_INST_ALU_IS_CZERO(op) (op[3:1] == 3'b101)

    localparam VX_INST_BR_EQ           = 4'b0000;
    localparam VX_INST_BR_NE           = 4'b0010;
    localparam VX_INST_BR_LTU          = 4'b0100;
    localparam VX_INST_BR_GEU          = 4'b0110;
    localparam VX_INST_BR_LT           = 4'b0101;
    localparam VX_INST_BR_GE           = 4'b0111;
    localparam VX_INST_BR_JAL          = 4'b1000;
    localparam VX_INST_BR_JALR         = 4'b1001;
    localparam VX_INST_BR_ECALL        = 4'b1010;
    localparam VX_INST_BR_EBREAK       = 4'b1011;
    localparam VX_INST_BR_URET         = 4'b1100;
    localparam VX_INST_BR_SRET         = 4'b1101;
    localparam VX_INST_BR_MRET         = 4'b1110;
    localparam VX_INST_BR_OTHER        = 4'b1111;
    localparam VX_INST_BR_BITS         = 4;

    `define VX_INST_BR_CLASS(op)        {1'b0, ~op[3]}
    `define VX_INST_BR_IS_NEG(op)       op[1]
    `define VX_INST_BR_IS_LESS(op)      op[2]
    `define VX_INST_BR_IS_STATIC(op)    op[3]

    localparam VX_INST_M_MUL           = 3'b000;
    localparam VX_INST_M_MULHU         = 3'b001;
    localparam VX_INST_M_MULH          = 3'b010;
    localparam VX_INST_M_MULHSU        = 3'b011;
    localparam VX_INST_M_DIV           = 3'b100;
    localparam VX_INST_M_DIVU          = 3'b101;
    localparam VX_INST_M_REM           = 3'b110;
    localparam VX_INST_M_REMU          = 3'b111;
    localparam VX_INST_M_BITS          = 3;

    `define VX_INST_M_SIGNED(op)    (~op[0])
    `define VX_INST_M_IS_MULX(op)   (~op[2])
    `define VX_INST_M_IS_MULH(op)   (op[1:0] != 0)
    `define VX_INST_M_SIGNED_A(op)  (op[1:0] != 1)
    `define VX_INST_M_IS_REM(op)    op[1]

    localparam VX_INST_FMT_B           = 3'b000;
    localparam VX_INST_FMT_H           = 3'b001;
    localparam VX_INST_FMT_W           = 3'b010;
    localparam VX_INST_FMT_D           = 3'b011;
    localparam VX_INST_FMT_BU          = 3'b100;
    localparam VX_INST_FMT_HU          = 3'b101;
    localparam VX_INST_FMT_WU          = 3'b110;

    localparam VX_INST_LSU_LB          = 4'b0000;
    localparam VX_INST_LSU_LH          = 4'b0001;
    localparam VX_INST_LSU_LW          = 4'b0010;
    localparam VX_INST_LSU_LD          = 4'b0011; // new for RV64I LD
    localparam VX_INST_LSU_LBU         = 4'b0100;
    localparam VX_INST_LSU_LHU         = 4'b0101;
    localparam VX_INST_LSU_LWU         = 4'b0110; // new for RV64I LWU
    localparam VX_INST_LSU_SB          = 4'b1000;
    localparam VX_INST_LSU_SH          = 4'b1001;
    localparam VX_INST_LSU_SW          = 4'b1010;
    localparam VX_INST_LSU_SD          = 4'b1011; // new for RV64I SD
    localparam VX_INST_LSU_FENCE       = 4'b1111;
    localparam VX_INST_LSU_BITS        = 4;

    `define VX_INST_LSU_FMT(op)     op[2:0]
    `define VX_INST_LSU_WSIZE(op)   op[1:0]
    `define VX_INST_LSU_IS_FENCE(op) (op[3:2] == 3)

    localparam VX_INST_FENCE_BITS      = 1;
    localparam VX_INST_FENCE_D         = 1'h0;
    localparam VX_INST_FENCE_I         = 1'h1;

    localparam VX_INST_FPU_ADD         = 4'b0000; // SUB=fmt[1]
    localparam VX_INST_FPU_MUL         = 4'b0001;
    localparam VX_INST_FPU_MADD        = 4'b0010; // SUB=fmt[1]
    localparam VX_INST_FPU_NMADD       = 4'b0011; // SUB=fmt[1]
    localparam VX_INST_FPU_DIV         = 4'b0100;
    localparam VX_INST_FPU_SQRT        = 4'b0101;
    localparam VX_INST_FPU_F2I         = 4'b1000; // fmt[0]: F32=0, F64=1, fmt[1]: I32=0, I64=1
    localparam VX_INST_FPU_F2U         = 4'b1001; // fmt[0]: F32=0, F64=1, fmt[1]: I32=0, I64=1
    localparam VX_INST_FPU_I2F         = 4'b1010; // fmt[0]: F32=0, F64=1, fmt[1]: I32=0, I64=1
    localparam VX_INST_FPU_U2F         = 4'b1011; // fmt[0]: F32=0, F64=1, fmt[1]: I32=0, I64=1
    localparam VX_INST_FPU_CMP         = 4'b1100; // frm: LE=0, LT=1, EQ=2
    localparam VX_INST_FPU_F2F         = 4'b1101; // fmt[0]: F32=0, F64=1
    localparam VX_INST_FPU_MISC        = 4'b1110; // frm: SGNJ=0, SGNJN=1, SGNJX=2, CLASS=3, MVXW=4, MVWX=5, FMIN=6, FMAX=7
    localparam VX_INST_FPU_BITS        = 4;
    `define VX_INST_FPU_IS_CLASS(op, frm) (op == VX_INST_FPU_MISC && frm == 3)
    `define VX_INST_FPU_IS_MVXW(op, frm) (op == VX_INST_FPU_MISC && frm == 4)

    localparam VX_INST_SFU_TMC         = 4'h0;
    localparam VX_INST_SFU_WSPAWN      = 4'h1;
    localparam VX_INST_SFU_SPLIT       = 4'h2;
    localparam VX_INST_SFU_JOIN        = 4'h3;
    localparam VX_INST_SFU_BAR         = 4'h4;
    localparam VX_INST_SFU_PRED        = 4'h5;
    localparam VX_INST_SFU_CSRRW       = 4'h6;
    localparam VX_INST_SFU_CSRRS       = 4'h7;
    localparam VX_INST_SFU_CSRRC       = 4'h8;
    localparam VX_INST_SFU_BITS        = 4;

    `define VX_INST_SFU_CSR(f3)     (4'h6 + 4'(f3) - 4'h1)
    `define VX_INST_SFU_IS_WCTL(op) (op <= 5)
    `define VX_INST_SFU_IS_CSR(op)  (op >= 6 && op <= 8)

    ///////////////////////////////////////////////////////////////////////////////
    localparam VX_NUM_IREGS         = 32;
    localparam VX_NRI_BITS          = `XM_CLOG2(VX_NUM_IREGS);
    localparam VX_NUM_REGS          = VX_NUM_IREGS; // FIXME
    localparam VX_NR_BITS           = `XM_CLOG2(VX_NUM_REGS);

    localparam VX_PERF_CTR_BITS = 44;

    //////////////////////////// Perf counter types ///////////////////////////
    typedef struct packed {
        logic [VX_PERF_CTR_BITS-1:0] reads;
        logic [VX_PERF_CTR_BITS-1:0] writes;
        logic [VX_PERF_CTR_BITS-1:0] read_misses;
        logic [VX_PERF_CTR_BITS-1:0] write_misses;
        logic [VX_PERF_CTR_BITS-1:0] bank_stalls;
        logic [VX_PERF_CTR_BITS-1:0] mshr_stalls;
        logic [VX_PERF_CTR_BITS-1:0] mem_stalls;
        logic [VX_PERF_CTR_BITS-1:0] crsp_stalls;
    } cache_perf_t;

    typedef struct packed {
        logic [VX_PERF_CTR_BITS-1:0] reads;
        logic [VX_PERF_CTR_BITS-1:0] writes;
        logic [VX_PERF_CTR_BITS-1:0] latency;
    } mem_perf_t;

    typedef struct packed {
        logic [VX_PERF_CTR_BITS-1:0] idles;
        logic [VX_PERF_CTR_BITS-1:0] stalls;
    } sched_perf_t;

    typedef struct packed {
        logic [VX_PERF_CTR_BITS-1:0] ibf_stalls;
        logic [VX_PERF_CTR_BITS-1:0] scb_stalls;
        logic [VX_PERF_CTR_BITS-1:0] opd_stalls;
        logic [VX_NUM_EX_UNITS-1:0][VX_PERF_CTR_BITS-1:0] units_uses;
        logic [VX_NUM_SFU_UNITS-1:0][VX_PERF_CTR_BITS-1:0] sfu_uses;
    } issue_perf_t;

    //////////////////////// instruction arguments ////////////////////////////

    typedef struct packed {
        logic use_PC;
        logic use_imm;
        logic is_w;
        logic [VX_ALU_TYPE_BITS-1:0] xtype;
        logic [VX_IMM_BITS-1:0] imm;
    } alu_args_t;

    typedef struct packed {
        logic [($bits(alu_args_t)-VX_INST_FRM_BITS-VX_INST_FMT_BITS)-1:0] __padding;
        logic [VX_INST_FRM_BITS-1:0] frm;
        logic [VX_INST_FMT_BITS-1:0] fmt;
    } fpu_args_t;

    typedef struct packed {
        logic [($bits(alu_args_t)-1-1-VX_OFFSET_BITS)-1:0] __padding;
        logic is_store;
        logic is_float;
        logic [VX_OFFSET_BITS-1:0] offset;
    } lsu_args_t;

    typedef struct packed {
        logic [($bits(alu_args_t)-1-VX_CSR_ADDR_BITS-5)-1:0] __padding;
        logic use_imm;
        logic [VX_CSR_ADDR_BITS-1:0] addr;
        logic [4:0] imm;
    } csr_args_t;

    typedef struct packed {
        logic [($bits(alu_args_t)-1)-1:0] __padding;
        logic is_neg;
    } wctl_args_t;

    typedef union packed {
        alu_args_t  alu;
        fpu_args_t  fpu;
        lsu_args_t  lsu;
        csr_args_t  csr;
        wctl_args_t wctl;
    } op_args_t;

`IGNORE_UNUSED_BEGIN

    ///////////////////////// Miscaellaneous functions ////////////////////////

    function logic [VX_SFU_WIDTH-1:0] op_to_sfu_type(
        input logic [VX_INST_OP_BITS-1:0] op_type
    );
        case (op_type)
        VX_INST_SFU_CSRRW,
        VX_INST_SFU_CSRRS,
        VX_INST_SFU_CSRRC: op_to_sfu_type = VX_SFU_CSRS;
        default: op_to_sfu_type = VX_SFU_WCTL;
        endcase
    endfunction

`IGNORE_UNUSED_END

////////////////////////////////// Tracing ////////////////////////////////////

`ifdef SIMULATION

`ifdef SV_DPI
    import "DPI-C" function void dpi_trace(input int level, input string format /*verilator sformat*/);
`endif

    task trace_ex_type(input int level, input [`EX_BITS-1:0] ex_type);
        case (ex_type)
            `EX_ALU: `TRACE(level, ("ALU"))
            `EX_LSU: `TRACE(level, ("LSU"))
            `EX_SFU: `TRACE(level, ("SFU"))
        `ifdef EXT_F_ENABLE
            `EX_FPU: `TRACE(level, ("FPU"))
        `endif
            default: `TRACE(level, ("?"))
        endcase
    endtask

    task trace_ex_op(input int level,
                     input [`EX_BITS-1:0] ex_type,
                     input [VX_INST_OP_BITS-1:0] op_type,
                     input amoeba_gpu_pkg::op_args_t op_args
    );
        case (ex_type)
        `EX_ALU: begin
            case (op_args.alu.xtype)
                VX_ALU_TYPE_ARITH: begin
                    if (op_args.alu.is_w) begin
                        if (op_args.alu.use_imm) begin
                            case (VX_INST_ALU_BITS'(op_type))
                                VX_INST_ALU_ADD: `TRACE(level, ("ADDIW"))
                                VX_INST_ALU_SLL: `TRACE(level, ("SLLIW"))
                                VX_INST_ALU_SRL: `TRACE(level, ("SRLIW"))
                                VX_INST_ALU_SRA: `TRACE(level, ("SRAIW"))
                                default:       `TRACE(level, ("?"))
                            endcase
                        end else begin
                            case (VX_INST_ALU_BITS'(op_type))
                                VX_INST_ALU_ADD: `TRACE(level, ("ADDW"))
                                VX_INST_ALU_SUB: `TRACE(level, ("SUBW"))
                                VX_INST_ALU_SLL: `TRACE(level, ("SLLW"))
                                VX_INST_ALU_SRL: `TRACE(level, ("SRLW"))
                                VX_INST_ALU_SRA: `TRACE(level, ("SRAW"))
                                default:       `TRACE(level, ("?"))
                            endcase
                        end
                    end else begin
                        if (op_args.alu.use_imm) begin
                            case (VX_INST_ALU_BITS'(op_type))
                                VX_INST_ALU_ADD:   `TRACE(level, ("ADDI"))
                                VX_INST_ALU_SLL:   `TRACE(level, ("SLLI"))
                                VX_INST_ALU_SRL:   `TRACE(level, ("SRLI"))
                                VX_INST_ALU_SRA:   `TRACE(level, ("SRAI"))
                                VX_INST_ALU_SLT:   `TRACE(level, ("SLTI"))
                                VX_INST_ALU_SLTU:  `TRACE(level, ("SLTIU"))
                                VX_INST_ALU_XOR:   `TRACE(level, ("XORI"))
                                VX_INST_ALU_OR:    `TRACE(level, ("ORI"))
                                VX_INST_ALU_AND:   `TRACE(level, ("ANDI"))
                                VX_INST_ALU_LUI:   `TRACE(level, ("LUI"))
                                VX_INST_ALU_AUIPC: `TRACE(level, ("AUIPC"))
                                default:         `TRACE(level, ("?"))
                            endcase
                        end else begin
                            case (VX_INST_ALU_BITS'(op_type))
                                VX_INST_ALU_ADD:   `TRACE(level, ("ADD"))
                                VX_INST_ALU_SUB:   `TRACE(level, ("SUB"))
                                VX_INST_ALU_SLL:   `TRACE(level, ("SLL"))
                                VX_INST_ALU_SRL:   `TRACE(level, ("SRL"))
                                VX_INST_ALU_SRA:   `TRACE(level, ("SRA"))
                                VX_INST_ALU_SLT:   `TRACE(level, ("SLT"))
                                VX_INST_ALU_SLTU:  `TRACE(level, ("SLTU"))
                                VX_INST_ALU_XOR:   `TRACE(level, ("XOR"))
                                VX_INST_ALU_OR:    `TRACE(level, ("OR"))
                                VX_INST_ALU_AND:   `TRACE(level, ("AND"))
                                VX_INST_ALU_CZEQ:  `TRACE(level, ("CZERO.EQZ"))
                                VX_INST_ALU_CZNE:  `TRACE(level, ("CZERO.NEZ"))
                                default:         `TRACE(level, ("?"))
                            endcase
                        end
                    end
                end
                VX_ALU_TYPE_BRANCH: begin
                    case (VX_INST_BR_BITS'(op_type))
                        VX_INST_BR_EQ:    `TRACE(level, ("BEQ"))
                        VX_INST_BR_NE:    `TRACE(level, ("BNE"))
                        VX_INST_BR_LT:    `TRACE(level, ("BLT"))
                        VX_INST_BR_GE:    `TRACE(level, ("BGE"))
                        VX_INST_BR_LTU:   `TRACE(level, ("BLTU"))
                        VX_INST_BR_GEU:   `TRACE(level, ("BGEU"))
                        VX_INST_BR_JAL:   `TRACE(level, ("JAL"))
                        VX_INST_BR_JALR:  `TRACE(level, ("JALR"))
                        VX_INST_BR_ECALL: `TRACE(level, ("ECALL"))
                        VX_INST_BR_EBREAK:`TRACE(level, ("EBREAK"))
                        VX_INST_BR_URET:  `TRACE(level, ("URET"))
                        VX_INST_BR_SRET:  `TRACE(level, ("SRET"))
                        VX_INST_BR_MRET:  `TRACE(level, ("MRET"))
                        default:        `TRACE(level, ("?"))
                    endcase
                end
                VX_ALU_TYPE_MULDIV: begin
                    if (op_args.alu.is_w) begin
                        case (VX_INST_M_BITS'(op_type))
                            VX_INST_M_MUL:  `TRACE(level, ("MULW"))
                            VX_INST_M_DIV:  `TRACE(level, ("DIVW"))
                            VX_INST_M_DIVU: `TRACE(level, ("DIVUW"))
                            VX_INST_M_REM:  `TRACE(level, ("REMW"))
                            VX_INST_M_REMU: `TRACE(level, ("REMUW"))
                            default:      `TRACE(level, ("?"))
                        endcase
                    end else begin
                        case (VX_INST_M_BITS'(op_type))
                            VX_INST_M_MUL:   `TRACE(level, ("MUL"))
                            VX_INST_M_MULH:  `TRACE(level, ("MULH"))
                            VX_INST_M_MULHSU:`TRACE(level, ("MULHSU"))
                            VX_INST_M_MULHU: `TRACE(level, ("MULHU"))
                            VX_INST_M_DIV:   `TRACE(level, ("DIV"))
                            VX_INST_M_DIVU:  `TRACE(level, ("DIVU"))
                            VX_INST_M_REM:   `TRACE(level, ("REM"))
                            VX_INST_M_REMU:  `TRACE(level, ("REMU"))
                            default:       `TRACE(level, ("?"))
                        endcase
                    end
                end
                default: `TRACE(level, ("?"))
            endcase
        end
        `EX_LSU: begin
            if (op_args.lsu.is_float) begin
                case (VX_INST_LSU_BITS'(op_type))
                    VX_INST_LSU_LW: `TRACE(level, ("FLW"))
                    VX_INST_LSU_LD: `TRACE(level, ("FLD"))
                    VX_INST_LSU_SW: `TRACE(level, ("FSW"))
                    VX_INST_LSU_SD: `TRACE(level, ("FSD"))
                    default:      `TRACE(level, ("?"))
                endcase
            end else begin
                case (VX_INST_LSU_BITS'(op_type))
                    VX_INST_LSU_LB: `TRACE(level, ("LB"))
                    VX_INST_LSU_LH: `TRACE(level, ("LH"))
                    VX_INST_LSU_LW: `TRACE(level, ("LW"))
                    VX_INST_LSU_LD: `TRACE(level, ("LD"))
                    VX_INST_LSU_LBU:`TRACE(level, ("LBU"))
                    VX_INST_LSU_LHU:`TRACE(level, ("LHU"))
                    VX_INST_LSU_LWU:`TRACE(level, ("LWU"))
                    VX_INST_LSU_SB: `TRACE(level, ("SB"))
                    VX_INST_LSU_SH: `TRACE(level, ("SH"))
                    VX_INST_LSU_SW: `TRACE(level, ("SW"))
                    VX_INST_LSU_SD: `TRACE(level, ("SD"))
                    VX_INST_LSU_FENCE:`TRACE(level,("FENCE"))
                    default:      `TRACE(level, ("?"))
                endcase
            end
        end
        `EX_SFU: begin
            case (VX_INST_SFU_BITS'(op_type))
                VX_INST_SFU_TMC:   `TRACE(level, ("TMC"))
                VX_INST_SFU_WSPAWN:`TRACE(level, ("WSPAWN"))
                VX_INST_SFU_SPLIT: begin
                    if (op_args.wctl.is_neg) begin
                        `TRACE(level, ("SPLIT.N"))
                    end else begin
                        `TRACE(level, ("SPLIT"))
                    end
                end
                VX_INST_SFU_JOIN:  `TRACE(level, ("JOIN"))
                VX_INST_SFU_BAR:   `TRACE(level, ("BAR"))
                VX_INST_SFU_PRED:  begin
                    if (op_args.wctl.is_neg) begin
                        `TRACE(level, ("PRED.N"))
                    end else begin
                        `TRACE(level, ("PRED"))
                    end
                end
                VX_INST_SFU_CSRRW: begin
                    if (op_args.csr.use_imm) begin
                        `TRACE(level, ("CSRRWI"))
                    end else begin
                        `TRACE(level, ("CSRRW"))
                    end
                end
                VX_INST_SFU_CSRRS: begin
                    if (op_args.csr.use_imm) begin
                        `TRACE(level, ("CSRRSI"))
                    end else begin
                        `TRACE(level, ("CSRRS"))
                    end
                end
                VX_INST_SFU_CSRRC: begin
                    if (op_args.csr.use_imm) begin
                        `TRACE(level, ("CSRRCI"))
                    end else begin
                        `TRACE(level, ("CSRRC"))
                    end
                end
                default:         `TRACE(level, ("?"))
            endcase
        end
    `ifdef EXT_F_ENABLE
        `EX_FPU: begin
            case (VX_INST_FPU_BITS'(op_type))
                VX_INST_FPU_ADD: begin
                    if (op_args.fpu.fmt[1]) begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FSUB.D"))
                        end else begin
                            `TRACE(level, ("FSUB.S"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FADD.D"))
                        end else begin
                            `TRACE(level, ("FADD.S"))
                        end
                    end
                end
                VX_INST_FPU_MADD: begin
                    if (op_args.fpu.fmt[1]) begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FMSUB.D"))
                        end else begin
                            `TRACE(level, ("FMSUB.S"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FMADD.D"))
                        end else begin
                            `TRACE(level, ("FMADD.S"))
                        end
                    end
                end
                VX_INST_FPU_NMADD: begin
                    if (op_args.fpu.fmt[1]) begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FNMSUB.D"))
                        end else begin
                            `TRACE(level, ("FNMSUB.S"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[0]) begin
                            `TRACE(level, ("FNMADD.D"))
                        end else begin
                            `TRACE(level, ("FNMADD.S"))
                        end
                    end
                end
                VX_INST_FPU_MUL: begin
                    if (op_args.fpu.fmt[0]) begin
                        `TRACE(level, ("FMUL.D"))
                    end else begin
                        `TRACE(level, ("FMUL.S"))
                        end
                end
                VX_INST_FPU_DIV: begin
                    if (op_args.fpu.fmt[0]) begin
                        `TRACE(level, ("FDIV.D"))
                    end else begin
                        `TRACE(level, ("FDIV.S"))
                        end
                end
                VX_INST_FPU_SQRT: begin
                    if (op_args.fpu.fmt[0]) begin
                        `TRACE(level, ("FSQRT.D"))
                    end else begin
                        `TRACE(level, ("FSQRT.S"))
                    end
                end
                VX_INST_FPU_CMP: begin
                    if (op_args.fpu.fmt[0]) begin
                        case (op_args.fpu.frm[1:0])
                        0:       `TRACE(level, ("FLE.D"))
                        1:       `TRACE(level, ("FLT.D"))
                        2:       `TRACE(level, ("FEQ.D"))
                        default: `TRACE(level, ("?"))
                        endcase
                    end else begin
                        case (op_args.fpu.frm[1:0])
                        0:       `TRACE(level, ("FLE.S"))
                        1:       `TRACE(level, ("FLT.S"))
                        2:       `TRACE(level, ("FEQ.S"))
                        default: `TRACE(level, ("?"))
                        endcase
                    end
                end
                VX_INST_FPU_F2F: begin
                    if (op_args.fpu.fmt[0]) begin
                        `TRACE(level, ("FCVT.D.S"))
                    end else begin
                        `TRACE(level, ("FCVT.S.D"))
                    end
                end
                VX_INST_FPU_F2I: begin
                    if (op_args.fpu.fmt[0]) begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.L.D"))
                        end else begin
                            `TRACE(level, ("FCVT.W.D"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.L.S"))
                        end else begin
                            `TRACE(level, ("FCVT.W.S"))
                        end
                    end
                end
                VX_INST_FPU_F2U: begin
                    if (op_args.fpu.fmt[0]) begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.LU.D"))
                        end else begin
                            `TRACE(level, ("FCVT.WU.D"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.LU.S"))
                        end else begin
                            `TRACE(level, ("FCVT.WU.S"))
                        end
                    end
                end
                VX_INST_FPU_I2F: begin
                    if (op_args.fpu.fmt[0]) begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.D.L"))
                        end else begin
                            `TRACE(level, ("FCVT.D.W"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.S.L"))
                        end else begin
                            `TRACE(level, ("FCVT.S.W"))
                        end
                    end
                end
                VX_INST_FPU_U2F: begin
                    if (op_args.fpu.fmt[0]) begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.D.LU"))
                        end else begin
                            `TRACE(level, ("FCVT.D.WU"))
                        end
                    end else begin
                        if (op_args.fpu.fmt[1]) begin
                            `TRACE(level, ("FCVT.S.LU"))
                        end else begin
                            `TRACE(level, ("FCVT.S.WU"))
                        end
                    end
                end
                VX_INST_FPU_MISC: begin
                    if (op_args.fpu.fmt[0]) begin
                        case (op_args.fpu.frm)
                            0: `TRACE(level, ("FSGNJ.D"))
                            1: `TRACE(level, ("FSGNJN.D"))
                            2: `TRACE(level, ("FSGNJX.D"))
                            3: `TRACE(level, ("FCLASS.D"))
                            4: `TRACE(level, ("FMV.X.D"))
                            5: `TRACE(level, ("FMV.D.X"))
                            6: `TRACE(level, ("FMIN.D"))
                            7: `TRACE(level, ("FMAX.D"))
                        endcase
                    end else begin
                        case (op_args.fpu.frm)
                            0: `TRACE(level, ("FSGNJ.S"))
                            1: `TRACE(level, ("FSGNJN.S"))
                            2: `TRACE(level, ("FSGNJX.S"))
                            3: `TRACE(level, ("FCLASS.S"))
                            4: `TRACE(level, ("FMV.X.S"))
                            5: `TRACE(level, ("FMV.S.X"))
                            6: `TRACE(level, ("FMIN.S"))
                            7: `TRACE(level, ("FMAX.S"))
                        endcase
                    end
                end
                default: `TRACE(level, ("?"))
            endcase
        end
    `endif
        default: `TRACE(level, ("?"))
        endcase
    endtask

    task trace_op_args(input int level,
                       input [`EX_BITS-1:0] ex_type,
                       input [VX_INST_OP_BITS-1:0] op_type,
                       input amoeba_gpu_pkg::op_args_t op_args
    );
        case (ex_type)
        `EX_ALU: begin
            `TRACE(level, (", use_PC=%b, use_imm=%b, imm=0x%0h", op_args.alu.use_PC, op_args.alu.use_imm, op_args.alu.imm))
        end
        `EX_LSU: begin
            `TRACE(level, (", offset=0x%0h", op_args.lsu.offset))
        end
        `EX_SFU: begin
            if (VX_INST_SFU_IS_CSR(op_type)) begin
                `TRACE(level, (", addr=0x%0h, use_imm=%b, imm=0x%0h", op_args.csr.addr, op_args.csr.use_imm, op_args.csr.imm))
            end
        end
    `ifdef EXT_F_ENABLE
        `EX_FPU: begin
            `TRACE(level, (", fmt=0x%0h, frm=0x%0h", op_args.fpu.fmt, op_args.fpu.frm))
        end
    `endif
        default:;
        endcase
    endtask

    task trace_base_dcr(input int level, input [`VX_DCR_ADDR_WIDTH-1:0] addr);
        case (addr)
            `VX_DCR_BASE_STARTUP_ADDR0: `TRACE(level, ("STARTUP_ADDR0"))
            `VX_DCR_BASE_STARTUP_ADDR1: `TRACE(level, ("STARTUP_ADDR1"))
            `VX_DCR_BASE_STARTUP_ARG0:  `TRACE(level, ("STARTUP_ARG0"))
            `VX_DCR_BASE_STARTUP_ARG1:  `TRACE(level, ("STARTUP_ARG1"))
            `VX_DCR_BASE_MPM_CLASS:     `TRACE(level, ("MPM_CLASS"))
            default:                    `TRACE(level, ("?"))
        endcase
    endtask

`endif

endpackage

`endif // VX_GPU_PKG_VH
