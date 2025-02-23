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

module xrv_vx_fetch import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter PC_WIDTH_P            = XLEN_P,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter IBUF_SIZE_P           = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    // ICache 
    ////////////////////////////////////////////////////////////////////////////////
    parameter ICACHE_WORD_SIZE_P	= 4,
    parameter ICACHE_ADDR_WIDTH_P	= (MEM_ADDR_WIDTH_P - `XM_CLOG2(ICACHE_WORD_SIZE_P)),
    parameter ICACHE_TAG_ID_BITS_P	= WID_WIDTH_P,
    parameter ICACHE_TAG_WIDTH_P	= (UUID_WIDTH_P + ICACHE_TAG_ID_BITS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    `SCOPE_IO_DECL

    input  wire                 clk_i,
    input  wire                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Icache interface
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_if.master         icache_bus_if,
    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_schedule_if.slave    schedule_if,
    xrv_vx_fetch_if.master      fetch_if
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    `XM_UNUSED_VAR (rst_i)

    wire icache_req_vld;
    wire [ICACHE_ADDR_WIDTH_P-1:0] icache_req_addr;
    wire [ICACHE_TAG_WIDTH_P-1:0] icache_req_tag;
    wire icache_req_rdy;

    wire [UUID_WIDTH_P-1:0] resp_uuid;
    wire [WID_WIDTH_P-1:0] req_tag, resp_tag;

    wire icache_req_fire = icache_req_vld && icache_req_rdy;

    assign req_tag = schedule_if.data.wid;

    assign {resp_uuid, resp_tag} = icache_bus_if.resp_data.tag;

    wire [PC_WIDTH_P-1:0] resp_PC;
    wire [NUM_THREADS_P-1:0] resp_tmask;

    xrv_vx_dp_ram #(
        .DATAW      (PC_WIDTH_P + NUM_THREADS_P),
        .SIZE       (NUM_WARPS_P),
        .RDW_MODE   ("R")
    ) tag_store (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .read       (1'b1),
        .write      (icache_req_fire),
        .wren       (1'b1),
        .waddr      (req_tag),
        .wdata      ({schedule_if.data.PC, schedule_if.data.tmask}),
        .raddr      (resp_tag),
        .rdata      ({resp_PC, resp_tmask})
    );

`ifndef L1_ENABLE
    // Ensure that the ibuffer doesn't fill up.
    // This resolves potential deadlock if ibuffer fills and the LSU stalls the execute stage due to pending dcache requests.
    // This issue is particularly prevalent when the icache and dcache are disabled and both requests share the same bus.
    wire [NUM_WARPS_P-1:0] pending_ibuf_full;
    generate
    for (genvar i = 0; i < NUM_WARPS_P; ++i) begin : g_pending_reads
        xrv_pending_size #(
            .SIZE_P (IBUF_SIZE_P)
        ) pending_reads (
            .clk_i  (clk_i),
            .rst_i  (rst_i),
            .incr   (icache_req_fire && schedule_if.data.wid == i),
            .decr   (fetch_if.ibuf_pop[i]),
            `XM_UNUSED_PIN (empty),
            `XM_UNUSED_PIN (alm_empty),
            .full   (pending_ibuf_full[i]),
            `XM_UNUSED_PIN (alm_full),
            `XM_UNUSED_PIN (size)
        );
    end
    endgenerate
    wire ibuf_rdy = ~pending_ibuf_full[schedule_if.data.wid];
`else
    wire ibuf_rdy = 1'b1;
`endif

    `RUNTIME_ASSERT((!schedule_if.vld || schedule_if.data.PC != 0),
        ("%t: *** %s invld PC=0x%0h, wid=%0d, tmask=%b (#%0d)", $time, INSTANCE_ID, {schedule_if.data.PC, 1'b0}, schedule_if.data.wid, schedule_if.data.tmask, schedule_if.data.uuid))

    // Icache Request

    assign icache_req_vld = schedule_if.vld && ibuf_rdy;
    assign icache_req_addr  = schedule_if.data.PC[1 +: ICACHE_ADDR_WIDTH_P];
    assign icache_req_tag   = {schedule_if.data.uuid, req_tag};
    assign schedule_if.rdy = icache_req_rdy && ibuf_rdy;

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (ICACHE_ADDR_WIDTH_P + ICACHE_TAG_WIDTH_P),
        .SIZE_P         (2),
        .OUT_REG        (1) // external bus should be registered
    ) req_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (icache_req_vld),
        .rdy_i      (icache_req_rdy),
        .data_i     ({icache_req_addr, icache_req_tag}),
        .data_o     ({icache_bus_if.req_data.addr, icache_bus_if.req_data.tag}),
        .vld_o      (icache_bus_if.req_vld),
        .rdy_o      (icache_bus_if.req_rdy)
    );

    assign icache_bus_if.req_data.flags  = '0;
    assign icache_bus_if.req_data.rw     = 0;
    assign icache_bus_if.req_data.byteen = '1;
    assign icache_bus_if.req_data.data   = '0;

    // Icache Response

    assign fetch_if.vld = icache_bus_if.resp_vld;
    assign fetch_if.data.tmask = resp_tmask;
    assign fetch_if.data.wid   = resp_tag;
    assign fetch_if.data.PC    = resp_PC;
    assign fetch_if.data.instr = icache_bus_if.resp_data.data;
    assign fetch_if.data.uuid  = resp_uuid;
    assign icache_bus_if.resp_rdy = fetch_if.rdy;

`ifdef SCOPE
`ifdef DBG_SCOPE_FETCH
    `SCOPE_IO_SWITCH (1);
    wire schedule_fire = schedule_if.vld && schedule_if.rdy;
    wire icache_bus_req_fire = icache_bus_if.req_vld && icache_bus_if.req_rdy;
    wire icache_bus_resp_fire = icache_bus_if.resp_vld && icache_bus_if.resp_rdy;
    `NEG_EDGE (rst_i_negedge, rst_i);
    `SCOPE_TAP_EX (0, 1, 6, 3, (
            UUID_WIDTH_P + WID_WIDTH_P+ NUM_THREADS_P + PC_WIDTH_P +
            UUID_WIDTH_P + ICACHE_WORD_SIZE_P + ICACHE_ADDR_WIDTH_P +
            UUID_WIDTH_P + (ICACHE_WORD_SIZE_P * 8)
        ), {
            schedule_if.vld,
            schedule_if.rdy,
            icache_bus_if.req_vld,
            icache_bus_if.req_rdy,
            icache_bus_if.resp_vld,
            icache_bus_if.resp_rdy
        }, {
            schedule_fire,
            icache_bus_req_fire,
            icache_bus_resp_fire
        },{
            schedule_if.data.uuid, schedule_if.data.wid, schedule_if.data.tmask, schedule_if.data.PC,
            icache_bus_if.req_data.tag.uuid, icache_bus_if.req_data.byteen, icache_bus_if.req_data.addr,
            icache_bus_if.resp_data.tag.uuid, icache_bus_if.resp_data.data
        },
        rst_i_negedge, 1'b0, 4096
    );
`else
    `SCOPE_IO_UNUSED(0)
`endif
`endif

`ifdef CHIPSCOPE
`ifdef DBG_SCOPE_FETCH
    ila_fetch ila_fetch_inst (
        .clk_i    (clk_i),
        .probe0 ({schedule_if.vld, schedule_if.data, schedule_if.rdy}),
        .probe1 ({icache_bus_if.req_vld, icache_bus_if.req_data, icache_bus_if.req_rdy}),
        .probe2 ({icache_bus_if.resp_vld, icache_bus_if.resp_data, icache_bus_if.resp_rdy})
    );
`endif
`endif

`ifdef DBG_TRACE_MEM
    always @(posedge clk_i) begin
        if (schedule_if.vld && schedule_if.rdy) begin
            `TRACE(1, ("%t: %s req: wid=%0d, PC=0x%0h, tmask=%b (#%0d)\n", $time, INSTANCE_ID, schedule_if.data.wid, {schedule_if.data.PC, 1'b0}, schedule_if.data.tmask, schedule_if.data.uuid))
        end
        if (fetch_if.vld && fetch_if.rdy) begin
            `TRACE(1, ("%t: %s resp: wid=%0d, PC=0x%0h, tmask=%b, instr=0x%0h (#%0d)\n", $time, INSTANCE_ID, fetch_if.data.wid, {fetch_if.data.PC, 1'b0}, fetch_if.data.tmask, fetch_if.data.instr, fetch_if.data.uuid))
        end
    end
`endif

endmodule
