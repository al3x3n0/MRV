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

module xrv_vx_alu_unit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_ALU_BLOCKS_P      = ISSUE_WIDTH_P,
    parameter NUM_ALU_LANES_P       = NUM_THREADS_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter EXT_M_ENABLED_P       = 0
) (
    input wire              clk_i,
    input wire              rst_i,

    // Inputs
    xrv_vx_dispatch_if.slave    dispatch_if [ISSUE_WIDTH_P],

    // Outputs
    xrv_vx_commit_if.master     commit_if [ISSUE_WIDTH_P],
    xrv_vx_branch_ctl_if.master branch_ctl_if [NUM_ALU_BLOCKS_P]
);

    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam BLOCK_SIZE   = NUM_ALU_BLOCKS_P;
    localparam NUM_LANES    = NUM_ALU_LANES_P;
    localparam PARTIAL_BW   = (BLOCK_SIZE != ISSUE_WIDTH_P) || (NUM_LANES != NUM_THREADS_P);
    localparam PE_COUNT     = 1 + EXT_M_ENABLED_P;
    localparam PE_SEL_BITS  = `XM_CLOG2(PE_COUNT);
    localparam PE_IDX_INT   = 0;
    localparam PE_IDX_MDV   = PE_IDX_INT + EXT_M_ENABLED_P;

    xrv_vx_execute_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) per_block_execute_if[BLOCK_SIZE]();

    xrv_vx_commit_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) per_block_commit_if[BLOCK_SIZE]();

    xrv_vx_dispatch_unit #(
        .BLOCK_SIZE     (BLOCK_SIZE),
        .NUM_LANES      (NUM_LANES),
        .OUT_BUF        (PARTIAL_BW ? 3 : 0),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P         (XLEN_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P  (ISSUE_WIDTH_P)
    ) dispatch_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .dispatch_if    (dispatch_if),
        .execute_if     (per_block_execute_if)
    );

    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : g_alus

        xrv_vx_execute_if #(
            .NUM_LANES_P    (NUM_LANES),
            .XLEN_P         (XLEN_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .NUM_WARPS_P    (NUM_WARPS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P)
        ) pe_execute_if[PE_COUNT]();

        xrv_vx_commit_if#(
            .NUM_LANES_P    (NUM_LANES),
            .XLEN_P         (XLEN_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .NUM_WARPS_P    (NUM_WARPS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P)
        ) pe_commit_if[PE_COUNT]();

        reg [`XM_UP(PE_SEL_BITS)-1:0] pe_select;
        always @(*) begin
            pe_select = PE_IDX_INT;
            if (EXT_M_ENABLED_P && (per_block_execute_if[block_idx].data.op_args.alu.xtype == VX_ALU_TYPE_MULDIV))
                pe_select = PE_IDX_MDV;
        end

        xrv_vx_pe_switch #(
            .PE_COUNT    (PE_COUNT),
            .NUM_LANES_P (NUM_LANES),
            .ARBITER     ("R"),
            .REQ_OUT_BUF (0),
            .RSP_OUT_BUF (PARTIAL_BW ? 1 : 3)
        ) pe_switch (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .pe_sel             (pe_select),
            .execute_in_if      (per_block_execute_if[block_idx]),
            .commit_out_if      (per_block_commit_if[block_idx]),
            .execute_out_if     (pe_execute_if),
            .commit_in_if       (pe_commit_if)
        );

        xrv_vx_alu_int #(
            .INSTANCE_ID    (`SFORMATF(("%s-int%0d", INSTANCE_ID, block_idx))),
            .BLOCK_IDX      (block_idx),
            .NUM_LANES      (NUM_LANES),
            ////////////////////////////////////////////////////////////////////////////////
            .XLEN_P         (XLEN_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .NUM_WARPS_P    (NUM_WARPS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P),
            ////////////////////////////////////////////////////////////////////////////////
            .NUM_ALU_BLOCKS_P(NUM_ALU_BLOCKS_P)
        ) alu_int (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .execute_if (pe_execute_if[PE_IDX_INT]),
            .branch_ctl_if (branch_ctl_if[block_idx]),
            .commit_if  (pe_commit_if[PE_IDX_INT])
        );

        if (EXT_M_ENABLED_P) begin
            xrv_vx_alu_muldiv #(
                .INSTANCE_ID (`SFORMATF(("%s-muldiv%0d", INSTANCE_ID, block_idx))),
                .NUM_LANES (NUM_LANES)
            ) muldiv_unit (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .execute_if     (pe_execute_if[PE_IDX_MDV]),
                .commit_if      (pe_commit_if[PE_IDX_MDV])
            );
        end
    end

    xrv_vx_gather_unit #(
        .BLOCK_SIZE     (BLOCK_SIZE),
        .NUM_LANES_P    (NUM_LANES),
        .OUT_BUF        (PARTIAL_BW ? 3 : 0),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P  (ISSUE_WIDTH_P)
    ) gather_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .commit_in_if   (per_block_commit_if),
        .commit_out_if  (commit_if)
    );

endmodule
