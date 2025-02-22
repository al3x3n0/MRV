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
    parameter `STRING INSTANCE_ID = ""
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

    localparam DATAW = UUID_WIDTH_P + ISSUE_WIS_W + NUM_THREADS_P + PC_WIDTH_P + VX_INST_OP_BITS + VX_INST_ARGS_BITS + 1 + RF_ADDR_WIDTH_P + (3 * NUM_THREADS_P * XLEN_P) + TID_WIDTH_LP;

    wire [NUM_THREADS_P-1:0][TID_WIDTH_LP-1:0] tids;
    for (genvar i = 0; i < NUM_THREADS_P; ++i) begin : g_tids
        assign tids[i] = TID_WIDTH_LP'(i);
    end

    wire [TID_WIDTH_LP-1:0] last_active_tid;

    xrv_find_first #(
        .N          (NUM_THREADS_P),
        .DATAW      (TID_WIDTH_LP),
        .REVERSE    (1)
    ) last_tid_select (
        .valid_in   (operands_if.data.tmask),
        .data_in    (tids),
        .data_out   (last_active_tid),
        `XM_UNUSED_PIN (valid_out)
    );

    wire [VX_NUM_EX_UNITS-1:0] operands_ready_in;
    assign operands_if.ready = operands_ready_in[operands_if.data.ex_type];

    for (genvar i = 0; i < VX_NUM_EX_UNITS; ++i) begin : g_buffers
        xrv_elastic_buffer #(
            .DATAW          (DATAW),
            .SIZE           (2),
            .OUT_REG        (1)
        ) buffer (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .valid_in       (operands_if.valid && (operands_if.data.ex_type == VX_EX_BITS'(i))),
            .ready_in       (operands_ready_in[i]),
            .data_in    ({
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
            .data_out   (dispatch_if[i].data),
            .valid_out  (dispatch_if[i].valid),
            .ready_out  (dispatch_if[i].ready)
        );
    end

`ifdef PERF_ENABLE
    reg [VX_NUM_EX_UNITS-1:0][`PERF_CTR_BITS-1:0] perf_stalls_r;

    wire operands_if_stall = operands_if.valid && ~operands_if.ready;

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
