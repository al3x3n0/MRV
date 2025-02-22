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

module xrv_vx_ibuffer import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = ""
) (
    input wire          clk_i,
    input wire          rst_i,

`ifdef PERF_ENABLE
    output wire [VX_PERF_CTR_BITS-1:0] perf_stalls,
`endif

    // inputs
    xrv_vx_decode_if.slave  decode_if,

    // outputs
    xrv_vx_ibuffer_if.master ibuffer_if [PER_ISSUE_WARPS]
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam DATAW = UUID_WIDTH_P+ NUM_THREADS_P + PC_WIDTH_P + 1 + VX_EX_BITS + VX_INST_OP_BITS + VX_INST_ARGS_BITS + (VX_NR_BITS * 4);

    wire [PER_ISSUE_WARPS-1:0] ibuf_ready_in;
    assign decode_if.ready = ibuf_ready_in[decode_if.data.wid];

    for (genvar w = 0; w < PER_ISSUE_WARPS; ++w) begin : g_instr_bufs
        xrv_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (IBUF_SIZE_P),
            .OUT_REG (1)
        ) instr_buf (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .valid_in   (decode_if.valid && decode_if.data.wid == ISSUE_WIS_W'(w)),
            .data_in    ({
                decode_if.data.uuid,
                decode_if.data.tmask,
                decode_if.data.PC,
                decode_if.data.ex_type,
                decode_if.data.op_type,
                decode_if.data.op_args,
                decode_if.data.wb,
                decode_if.data.rd,
                decode_if.data.rs1,
                decode_if.data.rs2,
                decode_if.data.rs3
            }),
            .ready_in (ibuf_ready_in[w]),
            .valid_out(ibuffer_if[w].valid),
            .data_out (ibuffer_if[w].data),
            .ready_out(ibuffer_if[w].ready)
        );
    `ifndef L1_ENABLE
        assign decode_if.ibuf_pop[w] = ibuffer_if[w].valid && ibuffer_if[w].ready;
    `endif
    end

`ifdef PERF_ENABLE
    reg [VX_PERF_CTR_BITS-1:0] perf_ibf_stalls;

    wire decode_if_stall = decode_if.valid && ~decode_if.ready;

    always @(posedge clk_i) begin
        if (rst_i) begin
            perf_ibf_stalls <= '0;
        end else begin
            perf_ibf_stalls <= perf_ibf_stalls + VX_PERF_CTR_BITS'(decode_if_stall);
        end
    end

    assign perf_stalls = perf_ibf_stalls;
`endif

endmodule
