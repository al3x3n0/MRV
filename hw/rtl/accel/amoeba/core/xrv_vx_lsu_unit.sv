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

module xrv_vx_lsu_unit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter LSU_LINE_SIZE_P       = "inv",
    parameter NUM_LSU_BLOCKS_P      = ISSUE_WIDTH_P,
    parameter NUM_LSU_LANES_P       = NUM_THREADS_P
) (
    `SCOPE_IO_DECL

    input wire              clk_i,
    input wire              rst_i,

    // Inputs
    xrv_vx_dispatch_if.slave    dispatch_if [ISSUE_WIDTH_P],

    // Outputs
    xrv_vx_commit_if.master     commit_if [ISSUE_WIDTH_P],
    xrv_vx_lsu_mem_if.master    lsu_mem_if [NUM_LSU_BLOCKS_P]
);
    localparam BLOCK_SIZE = NUM_LSU_BLOCKS_P;
    localparam NUM_LANES  = NUM_LSU_LANES_P;

    `SCOPE_IO_SWITCH (BLOCK_SIZE);

    xrv_vx_execute_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) per_block_execute_if[BLOCK_SIZE]();

    xrv_vx_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (3),
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

    xrv_vx_commit_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) per_block_commit_if[BLOCK_SIZE]();

    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : g_slices
        xrv_vx_lsu_slice #(
            .INSTANCE_ID        (`SFORMATF(("%s%0d", INSTANCE_ID, block_idx))),
            ////////////////////////////////////////////////////////////////////////////////
            .XLEN_P             (XLEN_P),
            .NUM_THREADS_P      (NUM_THREADS_P),
            .NUM_WARPS_P        (NUM_WARPS_P),
            .UUID_WIDTH_P       (UUID_WIDTH_P),
            ////////////////////////////////////////////////////////////////////////////////
            .LSU_LINE_SIZE_P    (LSU_LINE_SIZE_P),
            .NUM_LSU_BLOCKS_P   (ISSUE_WIDTH_P)
        ) lsu_slice(
            `SCOPE_IO_BIND  (block_idx)
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .execute_if     (per_block_execute_if[block_idx]),
            .commit_if      (per_block_commit_if[block_idx]),
            .lsu_mem_if     (lsu_mem_if[block_idx])
        );
    end

    xrv_vx_gather_unit #(
        .BLOCK_SIZE     (BLOCK_SIZE),
        .NUM_LANES_P    (NUM_LANES),
        .OUT_BUF        (3),
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
