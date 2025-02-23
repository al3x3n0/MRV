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

module xrv_vx_dispatch import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P        = "inv",
    parameter PC_WIDTH_P    = PC_WIDTH_P,
    parameter NUM_THREADS_P = "inv",
    parameter NUM_WARPS_P   = "inv",
    parameter WID_WIDTH_P   = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P   = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P  = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P     = "inv",
    parameter PER_ISSUE_WARPS_P = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P       = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P = `XM_UP(ISSUE_WIS_P)
) (
    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output wire [`PERF_CTR_BITS-1:0] perf_stalls [VX_NUM_EX_UNITS],
`endif
    // inputs
    xrv_vx_operands_if.slave    operands_if,

    // outputs
    xrv_vx_dispatch_if.master   dispatch_if [VX_NUM_EX_UNITS]
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)

    localparam DATAW = UUID_WIDTH_P + ISSUE_WIS_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + VX_NR_BITS + (3 * NUM_THREADS_P * XLEN_P) + TID_WIDTH_P;

    wire [NUM_THREADS_P-1:0][TID_WIDTH_P-1:0] tids;
    for (genvar i = 0; i < NUM_THREADS_P; ++i) begin : g_tids
        assign tids[i] = TID_WIDTH_P'(i);
    end

    wire [TID_WIDTH_P-1:0] last_active_tid;

    xrv_find_first #(
        .N              (NUM_THREADS_P),
        .DATA_WIDTH_P   (TID_WIDTH_P),
        .REVERSE_P      (1)
    ) last_tid_select (
        .vld_i      (operands_if.data.tmask),
        .data_i     (tids),
        .data_o     (last_active_tid),
        `XM_UNUSED_PIN (vld_o)
    );

    wire [VX_NUM_EX_UNITS-1:0] operands_rdy_in;
    assign operands_if.rdy = operands_rdy_in[operands_if.data.ex_type];

    for (genvar i = 0; i < VX_NUM_EX_UNITS; ++i) begin : g_buffers
        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (DATAW),
            .SIZE_P         (2),
            .OUT_REG        (1)
        ) buffer (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (operands_if.vld && (operands_if.data.ex_type == VX_EX_BITS'(i))),
            .rdy_i          (operands_rdy_in[i]),
            .data_i         ({
                operands_if.data.uuid,
                operands_if.data.wis,
                operands_if.data.tmask,
                operands_if.data.PC,
                operands_if.data.op_type,
                operands_if.data.op_args,
                operands_if.data.wb,
                operands_if.data.rd,
                last_active_tid,
                operands_if.data.rs1_data,
                operands_if.data.rs2_data,
                operands_if.data.rs3_data
            }),
            .data_o         (dispatch_if[i].data),
            .vld_o          (dispatch_if[i].vld),
            .rdy_o          (dispatch_if[i].rdy)
        );
    end

`ifdef PERF_ENABLE
    reg [VX_NUM_EX_UNITS-1:0][`PERF_CTR_BITS-1:0] perf_stalls_r;

    wire operands_if_stall = operands_if.vld && ~operands_if.rdy;

    for (genvar i = 0; i < VX_NUM_EX_UNITS; ++i) begin : g_perf_stalls
        always @(posedge clk_i) begin
            if (rst_i) begin
                perf_stalls_r[i] <= '0;
            end else begin
                perf_stalls_r[i] <= perf_stalls_r[i] + `PERF_CTR_BITS'(operands_if_stall && operands_if.data.ex_type == VX_EX_BITS'(i));
            end
        end
        assign perf_stalls[i] = perf_stalls_r[i];
    end
`endif

endmodule
