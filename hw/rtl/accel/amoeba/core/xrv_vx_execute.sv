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
`include "accel/vortex/xrv_vx_scope.vh"

module xrv_vx_execute import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    parameter CORE_ID               = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_ALU_BLOCKS_P      = "inv",
    parameter NUM_LSU_BLOCKS_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = "inv"
) (
    `SCOPE_IO_DECL

    input wire              clk_i,
    input wire              rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input wire              vx_mode_en_i,
    ////////////////////////////////////////////////////////////////////////////////
`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if.slave    mem_perf_if,
    xrv_vx_pipeline_perf_if.slave pipeline_perf_if,
`endif

    input xrv_vx_base_dcrs_if   base_dcrs,

    // Dcache interface
    xrv_vx_lsu_mem_if.master    lsu_mem_if [NUM_LSU_BLOCKS_P],

    // dispatch interface
    xrv_vx_dispatch_if.slave    dispatch_if [VX_NUM_EX_UNITS * ISSUE_WIDTH_P],

    // commit interface
    xrv_vx_commit_if.master     commit_if [VX_NUM_EX_UNITS * ISSUE_WIDTH_P],

    // scheduler interfaces
    xrv_vx_sched_csr_if.slave   sched_csr_if,
    xrv_vx_branch_ctl_if.master branch_ctl_if [NUM_ALU_BLOCKS_P],
    xrv_vx_warp_ctl_if.master   warp_ctl_if,

    // commit interface
    xrv_vx_commit_csr_if.slave  commit_csr_if
);

`ifdef EXT_F_ENABLE
    xrv_vx_fpu_csr_if fpu_csr_if[`NUM_FPU_BLOCKS]();
`endif

    xra_array #(
        .INSTANCE_ID (`SFORMATF(("%s-xra", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P                 (XLEN_P),
        .VX_NUM_WARPS_P         (NUM_WARPS_P),
        .VX_NUM_THREADS_P       (NUM_THREADS_P),
        .VX_NUM_LSU_BLOCKS_P    (NUM_LSU_BLOCKS_P)
    ) xra_unit (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .vx_mode_en_i       (vx_mode_en_i),
        ////////////////////////////////////////////////////////////////////////////////
        .vx_int_dispatch_if (dispatch_if[VX_EX_ALU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_int_commit_if   (commit_if[VX_EX_ALU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_branch_ctl_if   (branch_ctl_if),
        ////////////////////////////////////////////////////////////////////////////////
        .vx_lsu_dispatch_if (dispatch_if[VX_EX_LSU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_lsu_commit_if   (commit_if[VX_EX_LSU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_lsu_mem_if      (lsu_mem_if)
        ////////////////////////////////////////////////////////////////////////////////
`ifdef EXT_F_ENABLE
        .vx_fpu_dispatch_if (dispatch_if[VX_EX_FPU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_fpu_commit_if   (commit_if[VX_EX_FPU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .vx_fpu_csr_if      (fpu_csr_if)
`endif
    );

    xrv_vx_sfu_unit #(
        .INSTANCE_ID (`SFORMATF(("%s-sfu", INSTANCE_ID))),
        .CORE_ID (CORE_ID)
        ////////////////////////////////////////////////////////////////////////////////

    ) sfu_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
    `ifdef PERF_ENABLE
        .mem_perf_if    (mem_perf_if),
        .pipeline_perf_if (pipeline_perf_if),
    `endif
        .base_dcrs      (base_dcrs),
        .dispatch_if    (dispatch_if[VX_EX_SFU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
        .commit_if      (commit_if[VX_EX_SFU * ISSUE_WIDTH_P +: ISSUE_WIDTH_P]),
    `ifdef EXT_F_ENABLE
        .fpu_csr_if     (fpu_csr_if),
    `endif
        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),
        .warp_ctl_if    (warp_ctl_if)
    );

endmodule
