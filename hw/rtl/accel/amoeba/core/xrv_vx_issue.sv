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

module xrv_vx_issue import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 64,
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = 4,
    parameter NUM_WARPS_P           = 4,
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter PER_ISSUE_WARPS_P     = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P           = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P     = `XM_UP(ISSUE_WIS_P),
    parameter ISSUE_ISW_P           = `XM_CLOG2(ISSUE_WIDTH_P),
    parameter ISSUE_ISW_WIDTH_P     = `XM_UP(ISSUE_ISW_P)
) (
    `SCOPE_IO_DECL

    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output issue_perf_t     issue_perf,
`endif

    xrv_vx_decode_if.slave      decode_if,
    xrv_vx_writeback_if.slave   writeback_if [ISSUE_WIDTH_P],
    xrv_vx_dispatch_if.master   dispatch_if [VX_NUM_EX_UNITS * ISSUE_WIDTH_P]
);
    `include "accel/vortex/issue_utils.svh"

    `STATIC_ASSERT ((ISSUE_WIDTH_P <= NUM_WARPS_P), ("invld parameter"))

`ifdef PERF_ENABLE
    issue_perf_t per_issue_perf [ISSUE_WIDTH_P];
    `PERF_COUNTER_ADD (issue_perf, per_issue_perf, ibf_stalls, VX_PERF_CTR_BITS, ISSUE_WIDTH_P, (ISSUE_WIDTH_P > 2))
    `PERF_COUNTER_ADD (issue_perf, per_issue_perf, scb_stalls, VX_PERF_CTR_BITS, ISSUE_WIDTH_P, (ISSUE_WIDTH_P > 2))
    `PERF_COUNTER_ADD (issue_perf, per_issue_perf, opd_stalls, VX_PERF_CTR_BITS, ISSUE_WIDTH_P, (ISSUE_WIDTH_P > 2))
    for (genvar i = 0; i < VX_NUM_EX_UNITS; ++i) begin : g_issue_perf_units_uses
        `PERF_COUNTER_ADD (issue_perf, per_issue_perf, units_uses[i], VX_PERF_CTR_BITS, ISSUE_WIDTH_P, (ISSUE_WIDTH_P > 2))
    end
    for (genvar i = 0; i < `NUM_SFU_UNITS; ++i) begin : g_issue_perf_sfu_uses
        `PERF_COUNTER_ADD (issue_perf, per_issue_perf, sfu_uses[i], VX_PERF_CTR_BITS, ISSUE_WIDTH_P, (ISSUE_WIDTH_P > 2))
    end
`endif

    wire [ISSUE_ISW_WIDTH_P-1:0] decode_isw = wid_to_isw(decode_if.data.wid);
    wire [ISSUE_WIS_WIDTH_P-1:0] decode_wis = wid_to_wis(decode_if.data.wid);

    wire [ISSUE_WIDTH_P-1:0] decode_rdy_in;
    assign decode_if.rdy = decode_rdy_in[decode_isw];

    `SCOPE_IO_SWITCH (ISSUE_WIDTH_P);

    for (genvar issue_id = 0; issue_id < ISSUE_WIDTH_P; ++issue_id) begin : g_slices
        xrv_vx_decode_if #(
            .NUM_WARPS_P (PER_ISSUE_WARPS_P),
            .PC_WIDTH_P     (PC_WIDTH_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P)
        ) per_issue_decode_if();

        xrv_vx_dispatch_if #(
            .XLEN_P         (XLEN_P),
            .NUM_WARPS_P    (PER_ISSUE_WARPS_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P)
        ) per_issue_dispatch_if [VX_NUM_EX_UNITS]();

        assign per_issue_decode_if.vld = decode_if.vld && (decode_isw == ISSUE_ISW_WIDTH_P'(issue_id));
        assign per_issue_decode_if.data.uuid = decode_if.data.uuid;
        assign per_issue_decode_if.data.wid = decode_wis;
        assign per_issue_decode_if.data.tmask = decode_if.data.tmask;
        assign per_issue_decode_if.data.PC = decode_if.data.PC;
        assign per_issue_decode_if.data.ex_type = decode_if.data.ex_type;
        assign per_issue_decode_if.data.op_type = decode_if.data.op_type;
        assign per_issue_decode_if.data.op_args = decode_if.data.op_args;
        assign per_issue_decode_if.data.wb = decode_if.data.wb;
        assign per_issue_decode_if.data.rd = decode_if.data.rd;
        assign per_issue_decode_if.data.rs1 = decode_if.data.rs1;
        assign per_issue_decode_if.data.rs2 = decode_if.data.rs2;
        assign per_issue_decode_if.data.rs3 = decode_if.data.rs3;
        assign decode_rdy_in[issue_id] = per_issue_decode_if.rdy;
    `ifndef L1_ENABLE
        assign decode_if.ibuf_pop[issue_id * PER_ISSUE_WARPS_P +: PER_ISSUE_WARPS_P] = per_issue_decode_if.ibuf_pop;
    `endif

        xrv_vx_issue_slice #(
            .INSTANCE_ID    (`SFORMATF(("%s%0d", INSTANCE_ID, issue_id))),
            .ISSUE_ID       (issue_id),
            ////////////////////////////////////////////////////////////////////////////////
            .XLEN_P         (XLEN_P),
            .NUM_THREADS_P  (NUM_THREADS_P),
            .NUM_WARPS_P    (NUM_WARPS_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P),
            ////////////////////////////////////////////////////////////////////////////////
            .ISSUE_WIDTH_P  (ISSUE_WIDTH_P),
            .PER_ISSUE_WARPS_P(PER_ISSUE_WARPS_P)
        ) issue_slice (
            `SCOPE_IO_BIND(issue_id)
            .clk_i          (clk_i),
            .rst_i        (rst_i),
        `ifdef PERF_ENABLE
            .issue_perf   (per_issue_perf[issue_id]),
        `endif
            .decode_if    (per_issue_decode_if),
            .writeback_if (writeback_if[issue_id]),
            .dispatch_if  (per_issue_dispatch_if)
        );

        // Assign transposed dispatch_if
        for (genvar ex_id = 0; ex_id < VX_NUM_EX_UNITS; ++ex_id) begin : g_dispatch_if
            `ASSIGN_VX_IF(dispatch_if[ex_id * ISSUE_WIDTH_P + issue_id], per_issue_dispatch_if[ex_id]);
        end
     end

endmodule
