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

module xra_lsu_slice import #(
    parameter `STRING INSTANCE_ID = ""
    ////////////////////////////////////////////////////////////////////////////////
) (
    `SCOPE_IO_DECL
    input wire              clk_i,
    input wire              rst_i,

    ////////////////////////////////////////////////////////////////////////////////
    xra_vx_lsu_mem_if.slave     xra2lsu_mem_if [XRA_NUM_COLS_P],

    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_execute_if.slave     execute_if,
    xrv_vx_commit_if.master     vx_commit_if,
    xrv_vx_lsu_mem_if.master    vx_lsu_mem_if
);
    localparam RESP_ARB_DATA_WIDTH_LP = VX_UUID_WIDTH_P + VX_WID_WIDTH_P + XRA_NUM_COLS_P + PC_WIDTH_P+ `NR_BITS + 1 + XRA_NUM_COLS_P * XLEN_P + PID_WIDTH + 1 + 1;
    localparam LSUQ_SIZEW   = `XM_LOG2UP(`LSUQ_IN_SIZE);
    localparam REQ_ASHIFT   = `XM_CLOG2(LSU_WORD_SIZE);
    localparam MEM_ASHIFT   = `XM_CLOG2(`MEM_BLOCK_SIZE);
    localparam MEM_ADDRW    = `MEM_ADDR_WIDTH - MEM_ASHIFT;

    // tag_id = wid + PC + wb + rd + op_type + align + fence
    localparam TAG_ID_WIDTH = VX_WID_WIDTH_P + PC_WIDTH_P+ 1 + `NR_BITS + `INST_LSU_BITS + (XRA_NUM_COLS_P * REQ_ASHIFT) + 1;

    // tag = uuid + tag_id
    localparam TAG_WIDTH = VX_UUID_WIDTH_P + TAG_ID_WIDTH;

    xrv_vx_commit_if #(
        .XRA_NUM_COLS_P (XRA_NUM_COLS_P)
    ) commit_rsp_if();

    xrv_vx_commit_if #(
        .XRA_NUM_COLS_P (XRA_NUM_COLS_P)
    ) commit_no_rsp_if();

    `UNUSED_VAR (execute_if.data.rs3_data)
    `UNUSED_VAR (execute_if.data.tid)

    // full address calculation

    wire req_is_fence, rsp_is_fence;

    // schedule memory request
    wire                            mem_req_valid;
    wire [XRA_NUM_COLS_P-1:0]          mem_req_mask;
    wire                            mem_req_rw;
    wire [XRA_NUM_COLS_P-1:0][LSU_ADDR_WIDTH-1:0] mem_req_addr;
    wire [XRA_NUM_COLS_P-1:0][LSU_WORD_SIZE-1:0] mem_req_byteen;
    reg  [XRA_NUM_COLS_P-1:0][LSU_WORD_SIZE*8-1:0] mem_req_data;
    wire [TAG_WIDTH-1:0]            mem_req_tag;
    wire                            mem_req_ready;

    wire                            mem_rsp_valid;
    wire [XRA_NUM_COLS_P-1:0]          mem_rsp_mask;
    wire [XRA_NUM_COLS_P-1:0][LSU_WORD_SIZE*8-1:0] mem_rsp_data;
    wire [TAG_WIDTH-1:0]            mem_rsp_tag;
    wire                            mem_rsp_ready;

    wire mem_req_fire = mem_req_valid && mem_req_ready;
    wire mem_rsp_fire = mem_rsp_valid && mem_rsp_ready;

    wire no_rsp_buf_valid, no_rsp_buf_ready;

    // fence handling

    reg fence_lock;

    assign req_is_fence = `INST_LSU_IS_FENCE(execute_if.data.op_type);

    always @(posedge clk_i) begin
        if (rst_i) begin
            fence_lock <= 0;
        end else begin
            if (mem_req_fire && req_is_fence) begin
                fence_lock <= 1;
            end
            if (mem_rsp_fire && rsp_is_fence) begin
                fence_lock <= 0;
            end
        end
    end

    wire req_skip = req_is_fence;
    wire no_rsp_buf_enable = (mem_req_rw && ~execute_if.data.wb) || req_skip;

    assign mem_req_valid = execute_if.valid
                        && ~req_skip
                        && ~(no_rsp_buf_enable && ~no_rsp_buf_ready)
                        && ~fence_lock;

    assign no_rsp_buf_valid = execute_if.valid
                           && no_rsp_buf_enable
                           && (req_skip || mem_req_ready)
                           && ~fence_lock;

    assign execute_if.ready = (mem_req_ready || req_skip)
                           && ~(no_rsp_buf_enable && ~no_rsp_buf_ready)
                           && ~fence_lock;

    assign mem_req_mask = execute_if.data.tmask;
    assign mem_req_rw = execute_if.data.op_args.lsu.is_store;

    // address formatting

    wire [XRA_NUM_COLS_P-1:0][REQ_ASHIFT-1:0] req_align;


    // memory misalignment not supported!
    for (genvar i = 0; i < XRA_NUM_COLS_P; ++i) begin : g_missalign
        wire lsu_req_fire = execute_if.valid && execute_if.ready;
        `RUNTIME_ASSERT((~lsu_req_fire || ~execute_if.data.tmask[i] || req_is_fence || (full_addr[i] % (1 << `INST_LSU_WSIZE(execute_if.data.op_type))) == 0),
            ("%t: misaligned memory access, wid=%0d, PC=0x%0h, addr=0x%0h, wsize=%0d! (#%0d)",
                $time, execute_if.data.wid, {execute_if.data.PC, 1'b0}, full_addr[i], `INST_LSU_WSIZE(execute_if.data.op_type), execute_if.data.uuid))
    end

    // pack memory request tag
    assign mem_req_tag = {
        execute_if.data.uuid,
        execute_if.data.wid,
        execute_if.data.PC,
        execute_if.data.wb,
        execute_if.data.rd,
        execute_if.data.op_type,
        req_align,
        req_is_fence
    };

    wire                                    lsu_mem_req_valid;
    wire                                    lsu_mem_req_rw;
    wire [XRA_NUM_COLS_P-1:0]                    lsu_mem_req_mask;
    wire [XRA_NUM_COLS_P-1:0][LSU_WORD_SIZE-1:0] lsu_mem_req_byteen;
    wire [XRA_NUM_COLS_P-1:0][LSU_ADDR_WIDTH-1:0] lsu_mem_req_addr;
    wire [XRA_NUM_COLS_P-1:0][`MEM_REQ_FLAGS_WIDTH-1:0] lsu_mem_req_flags;
    wire [XRA_NUM_COLS_P-1:0][(LSU_WORD_SIZE*8)-1:0] lsu_mem_req_data;
    wire [LSU_TAG_WIDTH-1:0]                lsu_mem_req_tag;
    wire                                    lsu_mem_req_ready;

    wire                                    lsu_mem_rsp_valid;
    wire [XRA_NUM_COLS_P-1:0]                    lsu_mem_rsp_mask;
    wire [XRA_NUM_COLS_P-1:0][(LSU_WORD_SIZE*8)-1:0] lsu_mem_rsp_data;
    wire [LSU_TAG_WIDTH-1:0]                lsu_mem_rsp_tag;
    wire                                    lsu_mem_rsp_ready;

    xrv_mem_scheduler #(
        .INSTANCE_ID        (`SFORMATF(("%s-memsched", INSTANCE_ID))),
        .CORE_REQS          (XRA_NUM_COLS_P),
        .MEM_CHANNELS       (XRA_NUM_COLS_P),
        .WORD_SIZE          (LSU_WORD_SIZE),
        .LINE_SIZE          (LSU_WORD_SIZE),
        .ADDR_WIDTH         (LSU_ADDR_WIDTH),
        .FLAGS_WIDTH        (`MEM_REQ_FLAGS_WIDTH),
        .TAG_WIDTH          (TAG_WIDTH),
        .CORE_QUEUE_SIZE    (`LSUQ_IN_SIZE),
        .MEM_QUEUE_SIZE     (`LSUQ_OUT_SIZE),
        .UUID_WIDTH         (VX_UUID_WIDTH_P),
        .RSP_PARTIAL        (1),
        .MEM_OUT_BUF        (0),
        .CORE_OUT_BUF       (0)
    ) mem_scheduler (
        .clk_i              (clk_i),
        .rst_i              (rst_i),

        // Input request
        .core_req_valid     (mem_req_valid),
        .core_req_rw        (mem_req_rw),
        .core_req_mask      (mem_req_mask),
        .core_req_byteen    (mem_req_byteen),
        .core_req_addr      (mem_req_addr),
        .core_req_flags     (mem_req_flags),
        .core_req_data      (mem_req_data),
        .core_req_tag       (mem_req_tag),
        .core_req_ready     (mem_req_ready),
        `UNUSED_PIN         (core_req_empty),
        `UNUSED_PIN         (core_req_wr_notify),

        // Output response
        .core_rsp_valid (mem_rsp_valid),
        .core_rsp_mask  (mem_rsp_mask),
        .core_rsp_data  (mem_rsp_data),
        .core_rsp_tag   (mem_rsp_tag),
        .core_rsp_ready (mem_rsp_ready),

        // Memory request
        .mem_req_valid  (lsu_mem_req_valid),
        .mem_req_rw     (lsu_mem_req_rw),
        .mem_req_mask   (lsu_mem_req_mask),
        .mem_req_byteen (lsu_mem_req_byteen),
        .mem_req_addr   (lsu_mem_req_addr),
        .mem_req_flags  (lsu_mem_req_flags),
        .mem_req_data   (lsu_mem_req_data),
        .mem_req_tag    (lsu_mem_req_tag),
        .mem_req_ready  (lsu_mem_req_ready),

        // Memory response
        .mem_rsp_valid  (lsu_mem_rsp_valid),
        .mem_rsp_mask   (lsu_mem_rsp_mask),
        .mem_rsp_data   (lsu_mem_rsp_data),
        .mem_rsp_tag    (lsu_mem_rsp_tag),
        .mem_rsp_ready  (lsu_mem_rsp_ready)
    );

    assign lsu_mem_if.req_valid = lsu_mem_req_valid;
    assign lsu_mem_if.req_data.mask = lsu_mem_req_mask;
    assign lsu_mem_if.req_data.rw = lsu_mem_req_rw;
    assign lsu_mem_if.req_data.byteen = lsu_mem_req_byteen;
    assign lsu_mem_if.req_data.addr = lsu_mem_req_addr;
    assign lsu_mem_if.req_data.flags = lsu_mem_req_flags;
    assign lsu_mem_if.req_data.data = lsu_mem_req_data;
    assign lsu_mem_if.req_data.tag = lsu_mem_req_tag;
    assign lsu_mem_req_ready = lsu_mem_if.req_ready;

    assign lsu_mem_rsp_valid = lsu_mem_if.rsp_valid;
    assign lsu_mem_rsp_mask = lsu_mem_if.rsp_data.mask;
    assign lsu_mem_rsp_data = lsu_mem_if.rsp_data.data;
    assign lsu_mem_rsp_tag = lsu_mem_if.rsp_data.tag;
    assign lsu_mem_if.rsp_ready = lsu_mem_rsp_ready;

    wire [VX_UUID_WIDTH_P-1:0] rsp_uuid;
    wire [VX_WID_WIDTH_P-1:0] rsp_wid;
    wire [`PC_BITS-1:0] rsp_pc;
    wire rsp_wb;
    wire [`NR_BITS-1:0] rsp_rd;
    wire [`INST_LSU_BITS-1:0] rsp_op_type;
    wire [XRA_NUM_COLS_P-1:0][REQ_ASHIFT-1:0] rsp_align;
    `UNUSED_VAR (rsp_op_type)

    // unpack memory response tag
    assign {
        rsp_uuid,
        rsp_wid,
        rsp_pc,
        rsp_wb,
        rsp_rd,
        rsp_op_type,
        rsp_align,
        rsp_is_fence
    } = mem_rsp_tag;

    // load response formatting

    reg [XRA_NUM_COLS_P-1:0][XLEN_P-1:0] rsp_data;

`ifdef XLEN_64
`ifdef EXT_F_ENABLE
    // apply nan-boxing to flw outputs
    wire rsp_is_float = rsp_rd[5];
`else
    wire rsp_is_float = 0;
`endif
`endif

    ////////////////////////////////////////////////////////////////////////////////
    // commit
    ////////////////////////////////////////////////////////////////////////////////
    xrv_elastic_buffer #(
        .DATAW (VX_UUID_WIDTH_P + VX_WID_WIDTH_P + XRA_NUM_COLS_P + PC_WIDTH_P+ 1 + `NR_BITS + (XRA_NUM_COLS_P * XLEN_P)),
        .SIZE  (2)
    ) rsp_buf (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .valid_in  (mem_rsp_valid),
        .ready_in  (mem_rsp_ready),
        .data_in   ({rsp_uuid, rsp_wid, mem_rsp_mask, rsp_pc, rsp_wb, rsp_rd, rsp_data}),
        .data_out  ({commit_rsp_if.data.uuid, commit_rsp_if.data.wid, commit_rsp_if.data.tmask, commit_rsp_if.data.PC, commit_rsp_if.data.wb, commit_rsp_if.data.rd, commit_rsp_if.data.data}),
        .valid_out (commit_rsp_if.valid),
        .ready_out (commit_rsp_if.ready)
    );

    xrv_elastic_buffer #(
        .DATAW (VX_UUID_WIDTH_P + VX_WID_WIDTH_P + XRA_NUM_COLS_P + PC_WIDTH_P),
        .SIZE  (2)
    ) no_rsp_buf (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .valid_in  (no_rsp_buf_valid),
        .ready_in  (no_rsp_buf_ready),
        .data_in   ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC}),
        .data_out  ({commit_no_rsp_if.data.uuid, commit_no_rsp_if.data.wid, commit_no_rsp_if.data.tmask, commit_no_rsp_if.data.PC}),
        .valid_out (commit_no_rsp_if.valid),
        .ready_out (commit_no_rsp_if.ready)
    );

    assign commit_no_rsp_if.data.rd   = '0;
    assign commit_no_rsp_if.data.wb   = 1'b0;
    assign commit_no_rsp_if.data.data = commit_rsp_if.data.data; // arbiter MUX optimization

    xrv_stream_arb #(
        .NUM_INPUTS (2),
        .DATAW      (RESP_ARB_DATA_WIDTH_LP),
        .ARBITER    ("P"), // prioritize commit_rsp_if
        .OUT_BUF    (3)
    ) rsp_arb (
        .clk_i       (clk_i),
        .rst_i     (rst_i),
        .valid_in  ({commit_no_rsp_if.valid, commit_rsp_if.valid}),
        .ready_in  ({commit_no_rsp_if.ready, commit_rsp_if.ready}),
        .data_in   ({commit_no_rsp_if.data, commit_rsp_if.data}),
        .data_out  (commit_if.data),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready),
        `UNUSED_PIN (sel_out)
    );

`ifdef DBG_TRACE_MEM
    always @(posedge clk_i) begin
        if (execute_if.valid && fence_lock) begin
            `TRACE(2, ("%t: *** %s fence wait\n", $time, INSTANCE_ID))
        end
        if (mem_req_fire) begin
            if (mem_req_rw) begin
                `TRACE(2, ("%t: %s Wr Req: wid=%0d, PC=0x%0h, tmask=%b, addr=", $time, INSTANCE_ID, execute_if.data.wid, {execute_if.data.PC, 1'b0}, mem_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", full_addr, XRA_NUM_COLS_P)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", mem_req_flags, XRA_NUM_COLS_P)
                `TRACE(2, (", byteen=0x%0h, data=", mem_req_byteen))
                `TRACE_ARRAY1D(2, "0x%0h", mem_req_data, XRA_NUM_COLS_P)
                `TRACE(2, (", tag=0x%0h (#%0d)\n", mem_req_tag, execute_if.data.uuid))
            end else begin
                `TRACE(2, ("%t: %s Rd Req: wid=%0d, PC=0x%0h, tmask=%b, addr=", $time, INSTANCE_ID, execute_if.data.wid, {execute_if.data.PC, 1'b0}, mem_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", full_addr, XRA_NUM_COLS_P)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", mem_req_flags, XRA_NUM_COLS_P)
                `TRACE(2, (", byteen=0x%0h, rd=%0d, tag=0x%0h (#%0d)\n", mem_req_byteen, execute_if.data.rd, mem_req_tag, execute_if.data.uuid))
            end
        end
        if (mem_rsp_fire) begin
            `TRACE(2, ("%t: %s Rsp: wid=%0d, PC=0x%0h, tmask=%b, rd=%0d, data=",
                $time, INSTANCE_ID, rsp_wid, {rsp_pc, 1'b0}, mem_rsp_mask, rsp_rd))
            `TRACE_ARRAY1D(2, "0x%0h", mem_rsp_data, XRA_NUM_COLS_P)
            `TRACE(2, (", tag=0x%0h (#%0d)\n", mem_rsp_tag, rsp_uuid))
        end
    end
`endif

`ifdef SCOPE
`ifdef DBG_SCOPE_LSU
    `SCOPE_IO_SWITCH (1);
    `NEG_EDGE (rst_i_negedge, rst_i);
    `SCOPE_TAP_EX (0, 3, 4, 2, (
            1 + XRA_NUM_COLS_P * (XLEN_P + LSU_WORD_SIZE + LSU_WORD_SIZE * 8) + VX_UUID_WIDTH_P + XRA_NUM_COLS_P * LSU_WORD_SIZE * 8 + VX_UUID_WIDTH_P
        ), {
            mem_req_valid,
            mem_req_ready,
            mem_rsp_valid,
            mem_rsp_ready
        }, {
            mem_req_fire,
            mem_rsp_fire
        }, {
            mem_req_rw,
            full_addr,
            mem_req_byteen,
            mem_req_data,
            execute_if.data.uuid,
            rsp_data,
            rsp_uuid
        },
        rst_i_negedge, 1'b0,	4096
    );
`else
    `SCOPE_IO_UNUSED(0)
`endif
`endif

`ifdef CHIPSCOPE
`ifdef DBG_SCOPE_LSU
    ila_lsu ila_lsu_inst (
        .clk_i    (clk_i),
        .probe0 ({execute_if.valid, execute_if.data, execute_if.ready}),
        .probe1 ({lsu_mem_if.req_valid, lsu_mem_if.req_data, lsu_mem_if.req_ready}),
        .probe2 ({lsu_mem_if.rsp_valid, lsu_mem_if.rsp_data, lsu_mem_if.rsp_ready})
    );
`endif
`endif

endmodule
