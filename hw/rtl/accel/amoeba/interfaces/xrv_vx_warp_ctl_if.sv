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

`include "xm_macro.svh"

interface xrv_vx_warp_ctl_if import amoeba_gpu_pkg::*; #(
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P - 1,
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter NUM_BARRIERS_P    = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter BAR_ID_WIDTH_P    = `XM_CLOG2(NUM_BARRIERS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DV_STACK_SIZE_P       = `XM_UP(NUM_THREADS_P-1),
    parameter DV_STACK_SIZE_WIDTH_P = `XM_UP(`XM_CLOG2(DV_STACK_SIZE_P))
);

    wire        vld;
    wire [WID_WIDTH_P-1:0] wid;

    logic tmc_vld;
    logic [NUM_THREADS_P-1:0] tmc_tmask;

    logic wspawn_vld;
    logic [NUM_WARPS_P-1:0] wspawn_wmask;
    logic [PC_WIDTH_P-1:0] wspawn_pc;

    logic split_vld;
    logic split_is_dvg;
    logic [NUM_THREADS_P-1:0] split_then_tmask;
    logic [NUM_THREADS_P-1:0] split_else_tmask;
    logic [PC_WIDTH_P-1:0] split_next_pc;

    logic sjoin_vld;
    logic [DV_STACK_SIZE_WIDTH_P-1:0] sjoin_stack_ptr;

    logic                   barrier_vld;
    logic [BAR_ID_WIDTH_P-1:0] barrier_id;
    logic                   barrier_is_global;
`ifdef GBAR_ENABLE
    logic [`XM_MAX(WID_WIDTH_P, CORE_ID_WIDTH_P)-1:0] barrier_size_m1;
`else
    logic [WID_WIDTH_P-1:0]   barrier_size_m1;
`endif
    logic                   barrier_is_noop;

    wire [WID_WIDTH_P-1:0] dvstack_wid;
    wire [DV_STACK_SIZE_WIDTH_P-1:0] dvstack_ptr;

    modport master (
        output vld,
        output wid,

        output tmc_vld,
        output tmc_tmask,

        output wspawn_vld,
        output wspawn_wmask,
        output wspawn_pc,

        output split_vld,
        output split_is_dvg,
        output split_then_tmask,
        output split_else_tmask,
        output split_next_pc,

        output sjoin_vld,
        output sjoin_stack_ptr,

        output barrier_vld,
        output barrier_id,
        output barrier_is_global,
        output barrier_size_m1,
        output barrier_is_noop,

        output dvstack_wid,
        input  dvstack_ptr
    );

    modport slave (
        input vld,
        input wid,

        input tmc_vld,
        input tmc_tmask,

        input wspawn_vld,
        input wspawn_wmask,
        input wspawn_pc,

        input split_vld,
        input split_is_dvg,
        input split_then_tmask,
        input split_else_tmask,
        input split_next_pc,

        input sjoin_vld,
        input sjoin_stack_ptr,

        input barrier_vld,
        input barrier_id,
        input barrier_is_global,
        input barrier_size_m1,
        input barrier_is_noop,

        input dvstack_wid,
        output dvstack_ptr
    );

endinterface
