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

`include "xrv_vx_define.vh"

module xrv_vx_sfu_unit import xrv_vx_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID       = "",
    parameter CORE_ID                   = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P                = "inv",
    parameter NUM_THREADS_P             = "inv",
    parameter NUM_WARPS_P               = "inv",
    parameter WID_WIDTH_P               = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P               = `XM_CLOG2(NUM_THREADS_P),
    parameter DV_STACK_SIZE_WIDTH_P     = "inv"
) (
    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if.slave    mem_perf_if,
    xrv_vx_pipeline_perf_if.slave pipeline_perf_if,
`endif

    input base_dcrs_t       base_dcrs,

    // Inputs
    xrv_vx_dispatch_if.slave    dispatch_if [ISSUE_WIDTH_P],

`ifdef EXT_F_ENABLE
    xrv_vx_fpu_csr_if.slave     fpu_csr_if [NUM_FPU_BLOCKS_P],
`endif
    xrv_vx_commit_csr_if.slave  commit_csr_if,
    xrv_vx_sched_csr_if.slave   sched_csr_if,

    // Outputs
    xrv_vx_commit_if.master     commit_if [ISSUE_WIDTH_P],
    xrv_vx_warp_ctl_if.master   warp_ctl_if
);
    `UNUSED_SPARAM (INSTANCE_ID)
    localparam BLOCK_SIZE   = 1;
    localparam NUM_LANES_P    = NUM_SFU_LANES_P;
    localparam PE_COUNT     = 2;
    localparam PE_SEL_BITS  = `XM_CLOG2(PE_COUNT);
    localparam PE_IDX_WCTL  = 0;
    localparam PE_IDX_CSRS  = 1;

    xrv_vx_execute_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) per_block_execute_if[BLOCK_SIZE]();

    xrv_vx_commit_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) per_block_commit_if[BLOCK_SIZE]();

    xrv_vx_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES_P  (NUM_LANES_P),
        .OUT_BUF    (3)
    ) dispatch_unit (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );

    xrv_vx_execute_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) pe_execute_if[PE_COUNT]();

    xrv_vx_commit_if#(
        .NUM_LANES_P (NUM_LANES_P)
    ) pe_commit_if[PE_COUNT]();

    reg [PE_SEL_BITS-1:0] pe_select;
    always @(*) begin
        pe_select = PE_IDX_WCTL;
        if (`INST_SFU_IS_CSR(per_block_execute_if[0].data.op_type))
            pe_select = PE_IDX_CSRS;
    end

    xrv_vx_pe_switch #(
        .PE_COUNT       (PE_COUNT),
        .NUM_LANES_P    (NUM_LANES_P),
        .ARBITER        ("R"),
        .REQ_OUT_BUF    (0),
        .RSP_OUT_BUF    (3)
    ) pe_switch (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .pe_sel         (pe_select),
        .execute_in_if  (per_block_execute_if[0]),
        .commit_out_if  (per_block_commit_if[0]),
        .execute_out_if (pe_execute_if),
        .commit_in_if   (pe_commit_if)
    );

    xrv_vx_wctl_unit #(
        .INSTANCE_ID    (`SFORMATF(("%s-wctl", INSTANCE_ID))),
        .NUM_LANES_P    (NUM_LANES_P)
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .PC_WIDTH_P     (PC_WIDTH_P)
        ////////////////////////////////////////////////////////////////////////////////
    ) wctl_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .execute_if     (pe_execute_if[PE_IDX_WCTL]),
        .warp_ctl_if    (warp_ctl_if),
        .commit_if      (pe_commit_if[PE_IDX_WCTL])
    );

    xrv_vx_csr_unit #(
        .INSTANCE_ID (`SFORMATF(("%s-csr", INSTANCE_ID))),
        .CORE_ID   (CORE_ID),
        .NUM_LANES_P (NUM_LANES_P)
    ) csr_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .base_dcrs      (base_dcrs),
        .execute_if     (pe_execute_if[PE_IDX_CSRS]),

    `ifdef PERF_ENABLE
        .mem_perf_if     (mem_perf_if),
        .pipeline_perf_if(pipeline_perf_if),
    `endif

    `ifdef EXT_F_ENABLE
        .fpu_csr_if     (fpu_csr_if),
    `endif

        .sched_csr_if   (sched_csr_if),
        .commit_csr_if  (commit_csr_if),
        .commit_if      (pe_commit_if[PE_IDX_CSRS])
    );

    xrv_vx_gather_unit #(
        .BLOCK_SIZE     (BLOCK_SIZE),
        .NUM_LANES_P    (NUM_LANES_P),
        .OUT_BUF        (3),
        ////////////////////////////////////////////////////////////////////////////////
        .PC_WIDTH_P     (PC_WIDTH_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P)
        ////////////////////////////////////////////////////////////////////////////////
    ) gather_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .commit_in_if   (per_block_commit_if),
        .commit_out_if  (commit_if)
    );

endmodule
