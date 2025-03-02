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

module xrv_vx_issue_slice import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    parameter ISSUE_ID              = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 64,
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = 4,
    parameter NUM_WARPS_P           = 4,
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = "inv",
    parameter PER_ISSUE_WARPS_P     = "inv"
) (
    `SCOPE_IO_DECL

    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output issue_perf_t     issue_perf,
`endif

    xrv_vx_decode_if.slave      decode_if,
    xrv_vx_writeback_if.slave   writeback_if,
    xrv_vx_dispatch_if.master   dispatch_if [VX_NUM_EX_UNITS]
);
    `XM_UNUSED_PARAM (ISSUE_ID)

    xrv_vx_ibuffer_if #(
        .XLEN_P        (XLEN_P),
        .NUM_THREADS_P (NUM_THREADS_P),
        .UUID_WIDTH_P  (UUID_WIDTH_P)
    ) ibuffer_if [PER_ISSUE_WARPS_P]();

    xrv_vx_scoreboard_if #(
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .PC_WIDTH_P     (PC_WIDTH_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P  (ISSUE_WIDTH_P)
    ) scoreboard_if();

    xrv_vx_operands_if #(
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P  (ISSUE_WIDTH_P)
    ) operands_if();

    xrv_vx_ibuffer #(
        .INSTANCE_ID (`SFORMATF(("%s-ibuffer", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P             (XLEN_P),
        .NUM_WARPS_P        (NUM_WARPS_P),
        .NUM_THREADS_P      (NUM_THREADS_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P      (ISSUE_WIDTH_P),
        .PER_ISSUE_WARPS_P  (PER_ISSUE_WARPS_P)
    ) ibuffer (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
     `ifdef PERF_ENABLE
        .perf_stalls    (issue_perf.ibf_stalls),
     `endif
        .decode_if      (decode_if),
        .ibuffer_if     (ibuffer_if)
    );

    xrv_vx_scoreboard #(
        .INSTANCE_ID (`SFORMATF(("%s-scoreboard", INSTANCE_ID))),
        .XLEN_P             (XLEN_P),
        .NUM_THREADS_P      (NUM_THREADS_P),
        .NUM_WARPS_P        (NUM_WARPS_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P      (ISSUE_WIDTH_P),
        .PER_ISSUE_WARPS_P  (PER_ISSUE_WARPS_P)
    ) scoreboard (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
    `ifdef PERF_ENABLE
        .perf_stalls    (issue_perf.scb_stalls),
        .perf_units_uses(issue_perf.units_uses),
        .perf_sfu_uses  (issue_perf.sfu_uses),
    `endif
        .writeback_if   (writeback_if),
        .ibuffer_if     (ibuffer_if),
        .scoreboard_if  (scoreboard_if)
    );

    xrv_vx_operands #(
        .INSTANCE_ID (`SFORMATF(("%s-operands", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P             (XLEN_P),
        .NUM_THREADS_P      (NUM_THREADS_P),
        .NUM_WARPS_P        (NUM_WARPS_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P      (ISSUE_WIDTH_P),
        .PER_ISSUE_WARPS_P  (PER_ISSUE_WARPS_P)
    ) operands (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
     `ifdef PERF_ENABLE
        .perf_stalls    (issue_perf.opd_stalls),
     `endif
        .writeback_if   (writeback_if),
        .scoreboard_if  (scoreboard_if),
        .operands_if    (operands_if)
    );

    xrv_vx_dispatch #(
        .INSTANCE_ID    (`SFORMATF(("%s-dispatch", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P             (XLEN_P),
        .NUM_THREADS_P      (NUM_THREADS_P),
        .NUM_WARPS_P        (NUM_WARPS_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P      (ISSUE_WIDTH_P),
        .PER_ISSUE_WARPS_P  (PER_ISSUE_WARPS_P)
    ) dispatch (
        .clk_i            (clk_i),
        .rst_i          (rst_i),
    `ifdef PERF_ENABLE
        `XM_UNUSED_PIN     (perf_stalls),
    `endif
        .operands_if    (operands_if),
        .dispatch_if    (dispatch_if)
    );

`ifdef SCOPE
`ifdef DBG_SCOPE_ISSUE
    `SCOPE_IO_SWITCH (1);
    wire decode_fire = decode_if.valid && decode_if.ready;
    wire operands_fire = operands_if.valid && operands_if.ready;
    `NEG_EDGE (rst_i_negedge, rst_i);
    `SCOPE_TAP_EX (0, 2, 4, 3, (
            `UUID_WIDTH + WID_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P+ `EX_BITS + VX_INST_OP_BITS + 1 + VX_NR_BITS * 4 +
            `UUID_WIDTH + ISSUE_WIS_W + NUM_THREADS_P + PC_WIDTH_P+ `EX_BITS + VX_INST_OP_BITS + 1 + VX_NR_BITS + (3 * XLEN_P) +
            `UUID_WIDTH + ISSUE_WIS_W + NUM_THREADS_P + VX_NR_BITS + (NUM_THREADS_P * XLEN_P)
        ), {
            decode_if.valid,
            decode_if.ready,
            operands_if.valid,
            operands_if.ready
        }, {
            decode_fire,
            operands_fire,
            writeback_if.valid // ack-free
        }, {
            decode_if.data.uuid,
            decode_if.data.wid,
            decode_if.data.tmask,
            decode_if.data.PC,
            decode_if.data.ex_type,
            decode_if.data.op_type,
            decode_if.data.wb,
            decode_if.data.rd,
            decode_if.data.rs1,
            decode_if.data.rs2,
            decode_if.data.rs3,
            operands_if.data.uuid,
            operands_if.data.wis,
            operands_if.data.tmask,
            operands_if.data.PC,
            operands_if.data.ex_type,
            operands_if.data.op_type,
            operands_if.data.wb,
            operands_if.data.rd,
            operands_if.data.rs1_data[0],
            operands_if.data.rs2_data[0],
            operands_if.data.rs3_data[0],
            writeback_if.data.uuid,
            writeback_if.data.wis,
            writeback_if.data.tmask,
            writeback_if.data.rd,
            writeback_if.data.data
        },
        rst_i_negedge, 1'b0, 4096
    );
`else
    `SCOPE_IO_UNUSED(0)
`endif
`endif

`ifdef CHIPSCOPE
`ifdef DBG_SCOPE_ISSUE
    ila_issue ila_issue_inst (
        .clk_i    (clk_i),
        .probe0 ({decode_if.valid, decode_if.data, decode_if.ready}),
        .probe1 ({scoreboard_if.valid, scoreboard_if.data, scoreboard_if.ready}),
        .probe2 ({operands_if.valid, operands_if.data, operands_if.ready}),
        .probe3 ({writeback_if.valid, writeback_if.data})
    );
`endif
`endif

`ifdef DBG_TRACE_PIPELINE
    always @(posedge clk_i) begin
        if (operands_if.valid && operands_if.ready) begin
            `TRACE(1, ("%t: %s: wid=%0d, PC=0x%0h, ex=", $time, INSTANCE_ID, wis_to_wid(operands_if.data.wis, ISSUE_ID), {operands_if.data.PC, 1'b0}))
            trace_ex_type(1, operands_if.data.ex_type);
            `TRACE(1, (", op="))
            trace_ex_op(1, operands_if.data.ex_type, operands_if.data.op_type, operands_if.data.op_args);
            `TRACE(1, (", tmask=%b, wb=%b, rd=%0d, rs1_data=", operands_if.data.tmask, operands_if.data.wb, operands_if.data.rd))
            `TRACE_ARRAY1D(1, "0x%0h", operands_if.data.rs1_data, NUM_THREADS_P)
            `TRACE(1, (", rs2_data="))
            `TRACE_ARRAY1D(1, "0x%0h", operands_if.data.rs2_data, NUM_THREADS_P)
            `TRACE(1, (", rs3_data="))
            `TRACE_ARRAY1D(1, "0x%0h", operands_if.data.rs3_data, NUM_THREADS_P)
            trace_op_args(1, operands_if.data.ex_type, operands_if.data.op_type, operands_if.data.op_args);
            `TRACE(1, (" (#%0d)\n", operands_if.data.uuid))
        end
    end
`endif

endmodule
