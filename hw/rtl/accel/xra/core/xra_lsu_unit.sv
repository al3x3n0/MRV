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

`include "VX_define.vh"

module xra_lsu_unit import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = ""
) (
    `SCOPE_IO_DECL
    ////////////////////////////////////////////////////////////////////////////////
    input wire              clk_i,
    input wire              rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic             vx_mode_en_i,
    // Inputs
    VX_dispatch_if.slave    dispatch_if [VX_ISSUE_WIDTH_P],

    // Outputs
    VX_commit_if.master     commit_if   [VX_ISSUE_WIDTH_P],
    VX_lsu_mem_if.master    lsu_mem_if  [VX_NUM_LSU_BLOCKS_P]
);
    localparam BLOCK_SIZE_P = VX_NUM_LSU_BLOCKS_P;
    localparam NUM_LANES_P  = VX_NUM_THREADS_P;

    `SCOPE_IO_SWITCH (BLOCK_SIZE_P);

    xrv_vx_execute_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) per_block_execute_if[BLOCK_SIZE_P]();

    xrv_vx_dispatch_unit #(
        .BLOCK_SIZE_P (BLOCK_SIZE_P),
        .NUM_LANES_P  (NUM_LANES_P),
        .OUT_BUF    (3)
    ) dispatch_unit (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );

    xrv_vx_commit_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) per_block_commit_if[BLOCK_SIZE_P]();

    for (genvar block_idx = 0; block_idx < BLOCK_SIZE_P; ++block_idx) begin : g_slices
        VX_lsu_slice #(
            .INSTANCE_ID (`SFORMATF(("%s%0d", INSTANCE_ID, block_idx)))
        ) lsu_slice(
            `SCOPE_IO_BIND  (block_idx)
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .execute_if (per_block_execute_if[block_idx]),
            .commit_if  (per_block_commit_if[block_idx]),
            .lsu_mem_if (lsu_mem_if[block_idx])
        );
    end

    VX_gather_unit #(
        .BLOCK_SIZE_P (BLOCK_SIZE_P),
        .NUM_LANES_P  (NUM_LANES_P),
        .OUT_BUF    (3)
    ) gather_unit (
        .clk_i           (clk_i),
        .rst_i         (rst_i),
        .commit_in_if  (per_block_commit_if),
        .commit_out_if (commit_if)
    );

endmodule
