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

module xrv_vx_lsu_slice import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 64,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    parameter MEM_BLOCK_SIZE_P      = 64,
    parameter PC_WIDTH_P            = XLEN_P - 1,
    parameter NUM_THREADS_P         = 4,
    parameter NUM_WARPS_P           = 4,
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    // LSU 
    ////////////////////////////////////////////////////////////////////////////////
    parameter LSU_WORD_SIZE_P       = XLEN_P / 8,
    // LSU line size
    parameter LSU_LINE_SIZE_P       = "inv",
    // Size of LSU Core Request Queue
    parameter LSUQ_IN_SIZE_P        = (2 * (NUM_THREADS_P / NUM_LSU_LANES_P)),
    // Size of LSU Memory Request Queue
    parameter LSUQ_OUT_SIZE_P       =  `XM_MAX(LSUQ_IN_SIZE_P, LSU_LINE_SIZE_P / (XLEN_P / 8)),
    parameter LSU_ADDR_WIDTH_P	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(LSU_WORD_SIZE_P)),
    parameter LSU_MEM_BATCHES_P     = 1,
    parameter LSU_TAG_ID_BITS_P     = (`XM_CLOG2(LSUQ_IN_SIZE_P) + `XM_CLOG2(LSU_MEM_BATCHES_P)),
    parameter LSU_TAG_WIDTH_P       = (UUID_WIDTH_P + LSU_TAG_ID_BITS_P),
    parameter LSU_NUM_REQS_P        = NUM_LSU_BLOCKS_P * NUM_LSU_LANES_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_LSU_BLOCKS_P      = "inv",
    parameter NUM_LSU_LANES_P       = NUM_THREADS_P
) (
    `SCOPE_IO_DECL

    input wire              clk_i,
    input wire              rst_i,

    // Inputs
    xrv_vx_execute_if.slave     execute_if,

    // Outputs
    xrv_vx_commit_if.master     commit_if,
    xrv_vx_lsu_mem_if.master    lsu_mem_if
);
    localparam NUM_LANES    = NUM_LSU_LANES_P;
    localparam PID_BITS     = `XM_CLOG2(NUM_THREADS_P / NUM_LANES);
    localparam PID_WIDTH    = `XM_UP(PID_BITS);
    localparam RSP_ARB_DATAW= UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + PC_WIDTH_P + VX_NR_BITS + 1 + NUM_LANES * XLEN_P;// + PID_WIDTH + 1 + 1;
    localparam LSUQ_SIZEW   = `XM_LOG2UP(LSUQ_IN_SIZE_P);
    localparam REQ_ASHIFT   = `XM_CLOG2(LSU_WORD_SIZE_P);
    localparam MEM_ASHIFT   = `XM_CLOG2(MEM_BLOCK_SIZE_P);
    localparam MEM_ADDRW    = MEM_ADDR_WIDTH_P - MEM_ASHIFT;

    // tag_id = wid + PC + wb + rd + op_type + align + pid + pkt_addr + fence
    localparam TAG_ID_WIDTH = WID_WIDTH_P + PC_WIDTH_P + 1 + VX_NR_BITS + VX_INST_LSU_BITS + (NUM_LANES * REQ_ASHIFT) + 1;// + PID_WIDTH + LSUQ_SIZEW;

    // tag = uuid + tag_id
    localparam TAG_WIDTH = UUID_WIDTH_P + TAG_ID_WIDTH;

    xrv_vx_commit_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) commit_resp_if();

    xrv_vx_commit_if #(
        .NUM_LANES_P    (NUM_LANES),
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) commit_no_resp_if();

    `XM_UNUSED_VAR (execute_if.data.rs3_data)
    `XM_UNUSED_VAR (execute_if.data.tid)

    // full address calculation

    wire req_is_fence, resp_is_fence;

    wire [NUM_LANES-1:0][XLEN_P-1:0] full_addr;
    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_full_addr
        assign full_addr[i] = execute_if.data.rs1_data[i] + `XM_SEXT(XLEN_P, execute_if.data.op_args.lsu.offset);
    end

    // address type calculation

    wire [NUM_LANES-1:0][VX_MEM_REQ_FLAGS_WIDTH-1:0] mem_req_flags;
    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_req_flags
        wire [MEM_ADDRW-1:0] block_addr = full_addr[i][MEM_ASHIFT +: MEM_ADDRW];
        // is I/O address
        //wire [MEM_ADDRW-1:0] io_addr_start = MEM_ADDRW'(XLEN_P'(`IO_BASE_ADDR) >> MEM_ASHIFT);
        //wire [MEM_ADDRW-1:0] io_addr_end = MEM_ADDRW'(XLEN_P'(`IO_END_ADDR) >> MEM_ASHIFT);
        assign mem_req_flags[i][VX_MEM_REQ_FLAG_FLUSH] = req_is_fence;
        //assign mem_req_flags[i][`MEM_REQ_FLAG_IO] = (block_addr >= io_addr_start) && (block_addr < io_addr_end);
    `ifdef LMEM_ENABLE
        // is local memory address
        wire [MEM_ADDRW-1:0] lmem_addr_start = MEM_ADDRW'(XLEN_P'(`LMEM_BASE_ADDR) >> MEM_ASHIFT);
        wire [MEM_ADDRW-1:0] lmem_addr_end = MEM_ADDRW'((XLEN_P'(`LMEM_BASE_ADDR) + XLEN_P'(1 << `LMEM_LOG_SIZE)) >> MEM_ASHIFT);
        assign mem_req_flags[i][`MEM_REQ_FLAG_LOCAL] = (block_addr >= lmem_addr_start) && (block_addr < lmem_addr_end);
    `endif
    end

    // schedule memory request

    wire                            mem_req_vld;
    wire [NUM_LANES-1:0]            mem_req_mask;
    wire                            mem_req_rw;
    wire [NUM_LANES-1:0][LSU_ADDR_WIDTH_P-1:0] mem_req_addr;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE_P-1:0] mem_req_be;
    reg  [NUM_LANES-1:0][LSU_WORD_SIZE_P*8-1:0] mem_req_data;
    wire [TAG_WIDTH-1:0]            mem_req_tag;
    wire                            mem_req_rdy;

    wire                            mem_resp_vld;
    wire [NUM_LANES-1:0]            mem_resp_mask;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE_P*8-1:0] mem_resp_data;
    wire [TAG_WIDTH-1:0]            mem_resp_tag;
    wire                            mem_resp_rdy;

    wire mem_req_fire = mem_req_vld && mem_req_rdy;
    wire mem_resp_fire = mem_resp_vld && mem_resp_rdy;
    wire no_resp_buf_vld, no_resp_buf_rdy;

    // fence handling

    reg fence_lock;

    assign req_is_fence = `VX_INST_LSU_IS_FENCE(execute_if.data.op_type);

    always @(posedge clk_i) begin
        if (rst_i) begin
            fence_lock <= 0;
        end else begin
            if (mem_req_fire && req_is_fence/* && execute_if.data.eop*/) begin
                fence_lock <= 1;
            end
            if (mem_resp_fire && resp_is_fence/* && mem_resp_eop_pkt*/) begin
                fence_lock <= 0;
            end
        end
    end

    wire req_skip = req_is_fence/* && ~execute_if.data.eop*/;
    wire no_resp_buf_enable = (mem_req_rw && ~execute_if.data.wb) || req_skip;

    assign mem_req_vld = execute_if.vld
                        && ~req_skip
                        && ~(no_resp_buf_enable && ~no_resp_buf_rdy)
                        && ~fence_lock;

    assign no_resp_buf_vld = execute_if.vld
                           && no_resp_buf_enable
                           && (req_skip || mem_req_rdy)
                           && ~fence_lock;

    assign execute_if.rdy = (mem_req_rdy || req_skip)
                           && ~(no_resp_buf_enable && ~no_resp_buf_rdy)
                           && ~fence_lock;

    assign mem_req_mask = execute_if.data.tmask;
    assign mem_req_rw = execute_if.data.op_args.lsu.is_store;

    // address formatting

    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] req_align;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_req_addr
        assign req_align[i] = full_addr[i][REQ_ASHIFT-1:0];
        assign mem_req_addr[i] = full_addr[i][MEM_ADDR_WIDTH_P-1:REQ_ASHIFT];
    end

    // byte enable formatting
    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_req_be_w
        reg [LSU_WORD_SIZE_P-1:0] mem_req_be_w;
        always @(*) begin
            mem_req_be_w = '0;
            case (`VX_INST_LSU_WSIZE(execute_if.data.op_type))
                0: begin // 8-bit
                    mem_req_be_w[req_align[i]] = 1'b1;
                end
                1: begin // 16 bit
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:1], 1'b0}] = 1'b1;
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:1], 1'b1}] = 1'b1;
                end
            `ifdef XLEN_64
                2: begin // 32 bit
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:2], 2'b00}] = 1'b1;
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:2], 2'b01}] = 1'b1;
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:2], 2'b10}] = 1'b1;
                    mem_req_be_w[{req_align[i][REQ_ASHIFT-1:2], 2'b11}] = 1'b1;
                end
            `endif
                // 3: 64 bit
                default : mem_req_be_w = {LSU_WORD_SIZE_P{1'b1}};
            endcase
        end
        assign mem_req_be[i] = mem_req_be_w;
    end

    // memory misalignment not supported!
    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_missalign
        wire lsu_req_fire = execute_if.vld && execute_if.rdy;
        `RUNTIME_ASSERT((~lsu_req_fire || ~execute_if.data.tmask[i] || req_is_fence || (full_addr[i] % (1 << `VX_INST_LSU_WSIZE(execute_if.data.op_type))) == 0),
            ("%t: misaligned memory access, wid=%0d, PC=0x%0h, addr=0x%0h, wsize=%0d! (#%0d)",
                $time, execute_if.data.wid, {execute_if.data.PC, 1'b0}, full_addr[i], `VX_INST_LSU_WSIZE(execute_if.data.op_type), execute_if.data.uuid))
    end

    // store data formatting
    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_req_data
        always @(*) begin
            mem_req_data[i] = execute_if.data.rs2_data[i];
            case (req_align[i])
                1: mem_req_data[i][XLEN_P-1:8]  = execute_if.data.rs2_data[i][XLEN_P-9:0];
                2: mem_req_data[i][XLEN_P-1:16] = execute_if.data.rs2_data[i][XLEN_P-17:0];
                3: mem_req_data[i][XLEN_P-1:24] = execute_if.data.rs2_data[i][XLEN_P-25:0];
            //`ifdef XLEN_64
                4: mem_req_data[i][XLEN_P-1:32] = execute_if.data.rs2_data[i][XLEN_P-33:0];
                5: mem_req_data[i][XLEN_P-1:40] = execute_if.data.rs2_data[i][XLEN_P-41:0];
                6: mem_req_data[i][XLEN_P-1:48] = execute_if.data.rs2_data[i][XLEN_P-49:0];
                7: mem_req_data[i][XLEN_P-1:56] = execute_if.data.rs2_data[i][XLEN_P-57:0];
            //`endif
                default:;
            endcase
        end
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

    wire                                    lsu_mem_req_vld;
    wire                                    lsu_mem_req_rw;
    wire [NUM_LANES-1:0]                    lsu_mem_req_mask;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE_P-1:0] lsu_mem_req_be;
    wire [NUM_LANES-1:0][LSU_ADDR_WIDTH_P-1:0] lsu_mem_req_addr;
    wire [NUM_LANES-1:0][VX_MEM_REQ_FLAGS_WIDTH-1:0] lsu_mem_req_flags;
    wire [NUM_LANES-1:0][(LSU_WORD_SIZE_P*8)-1:0] lsu_mem_req_data;
    wire [LSU_TAG_WIDTH_P-1:0]                lsu_mem_req_tag;
    wire                                    lsu_mem_req_rdy;

    wire                                    lsu_mem_resp_vld;
    wire [NUM_LANES-1:0]                    lsu_mem_resp_mask;
    wire [NUM_LANES-1:0][(LSU_WORD_SIZE_P*8)-1:0] lsu_mem_resp_data;
    wire [LSU_TAG_WIDTH_P-1:0]                lsu_mem_resp_tag;
    wire                                    lsu_mem_resp_rdy;

    xrv_mem_scheduler #(
        .INSTANCE_ID    (`SFORMATF(("%s-memsched", INSTANCE_ID))),
        .CORE_REQS      (NUM_LANES),
        .MEM_CHANNELS   (NUM_LANES),
        .WORD_SIZE      (LSU_WORD_SIZE_P),
        .LINE_SIZE      (LSU_WORD_SIZE_P),
        .ADDR_WIDTH     (LSU_ADDR_WIDTH_P),
        .FLAGS_WIDTH    (VX_MEM_REQ_FLAGS_WIDTH),
        .TAG_WIDTH      (TAG_WIDTH),
        .CORE_QUEUE_SIZE    (LSUQ_IN_SIZE_P),
        .MEM_QUEUE_SIZE     (LSUQ_OUT_SIZE_P),
        .UUID_WIDTH     (UUID_WIDTH_P),
        .RSP_PARTIAL    (1),
        .MEM_OUT_BUF    (0),
        .CORE_OUT_BUF   (0)
    ) mem_scheduler (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        // Input request
        .core_req_vld (mem_req_vld),
        .core_req_rw    (mem_req_rw),
        .core_req_mask  (mem_req_mask),
        .core_req_be(mem_req_be),
        .core_req_addr  (mem_req_addr),
        .core_req_flags (mem_req_flags),
        .core_req_data  (mem_req_data),
        .core_req_tag   (mem_req_tag),
        .core_req_rdy (mem_req_rdy),
        `XM_UNUSED_PIN (core_req_empty),
        `XM_UNUSED_PIN (core_req_wr_notify),

        // Output response
        .core_resp_vld (mem_resp_vld),
        .core_resp_mask  (mem_resp_mask),
        .core_resp_data  (mem_resp_data),
        .core_resp_tag   (mem_resp_tag),
        .core_resp_rdy (mem_resp_rdy),

        // Memory request
        .mem_req_vld  (lsu_mem_req_vld),
        .mem_req_rw     (lsu_mem_req_rw),
        .mem_req_mask   (lsu_mem_req_mask),
        .mem_req_be (lsu_mem_req_be),
        .mem_req_addr   (lsu_mem_req_addr),
        .mem_req_flags  (lsu_mem_req_flags),
        .mem_req_data   (lsu_mem_req_data),
        .mem_req_tag    (lsu_mem_req_tag),
        .mem_req_rdy  (lsu_mem_req_rdy),

        // Memory response
        .mem_resp_vld  (lsu_mem_resp_vld),
        .mem_resp_mask   (lsu_mem_resp_mask),
        .mem_resp_data   (lsu_mem_resp_data),
        .mem_resp_tag    (lsu_mem_resp_tag),
        .mem_resp_rdy  (lsu_mem_resp_rdy)
    );

    assign lsu_mem_if.req_vld = lsu_mem_req_vld;
    assign lsu_mem_if.req_data.mask = lsu_mem_req_mask;
    assign lsu_mem_if.req_data.rw = lsu_mem_req_rw;
    assign lsu_mem_if.req_data.be = lsu_mem_req_be;
    assign lsu_mem_if.req_data.addr = lsu_mem_req_addr;
    assign lsu_mem_if.req_data.flags = lsu_mem_req_flags;
    assign lsu_mem_if.req_data.data = lsu_mem_req_data;
    assign lsu_mem_if.req_data.tag = lsu_mem_req_tag;
    assign lsu_mem_req_rdy = lsu_mem_if.req_rdy;

    assign lsu_mem_resp_vld = lsu_mem_if.resp_vld;
    assign lsu_mem_resp_mask = lsu_mem_if.resp_data.mask;
    assign lsu_mem_resp_data = lsu_mem_if.resp_data.data;
    assign lsu_mem_resp_tag = lsu_mem_if.resp_data.tag;
    assign lsu_mem_if.resp_rdy = lsu_mem_resp_rdy;

    wire [UUID_WIDTH_P-1:0] resp_uuid;
    wire [WID_WIDTH_P-1:0] resp_wid;
    wire [PC_WIDTH_P-1:0] resp_pc;
    wire resp_wb;
    wire [VX_NR_BITS-1:0] resp_rd;
    wire [VX_INST_LSU_BITS-1:0] resp_op_type;
    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] resp_align;
    `XM_UNUSED_VAR (resp_op_type)

    // unpack memory response tag
    assign {
        resp_uuid,
        resp_wid,
        resp_pc,
        resp_wb,
        resp_rd,
        resp_op_type,
        resp_align,
        resp_is_fence
    } = mem_resp_tag;

    // load response formatting

    reg [NUM_LANES-1:0][XLEN_P-1:0] resp_data;

`ifdef XLEN_64
`ifdef EXT_F_ENABLE
    // apply nan-boxing to flw outputs
    wire resp_is_float = resp_rd[5];
`else
    wire resp_is_float = 0;
`endif
`endif

    for (genvar i = 0; i < NUM_LANES; i++) begin : g_resp_data
    //`ifdef XLEN_64
        wire [63:0] resp_data64 = mem_resp_data[i];
        wire [31:0] resp_data32 = (resp_align[i][2] ? mem_resp_data[i][63:32] : mem_resp_data[i][31:0]);
    //`else FIXME
    //    wire [31:0] resp_data32 = mem_resp_data[i];
    //`endif
        wire [15:0] resp_data16 = resp_align[i][1] ? resp_data32[31:16] : resp_data32[15:0];
        wire [7:0]  resp_data8  = resp_align[i][0] ? resp_data16[15:8] : resp_data16[7:0];

        always @(*) begin
            case (`VX_INST_LSU_FMT(resp_op_type))
            VX_INST_FMT_B:  resp_data[i] = XLEN_P'(signed'(resp_data8));
            VX_INST_FMT_H:  resp_data[i] = XLEN_P'(signed'(resp_data16));
            VX_INST_FMT_BU: resp_data[i] = XLEN_P'(unsigned'(resp_data8));
            VX_INST_FMT_HU: resp_data[i] = XLEN_P'(unsigned'(resp_data16));
        `ifdef XLEN_64
            VX_INST_FMT_W:  resp_data[i] = resp_is_float ? (XLEN_P'(resp_data32) | 64'hffffffff00000000) : XLEN_P'(signed'(resp_data32));
            VX_INST_FMT_WU: resp_data[i] = XLEN_P'(unsigned'(resp_data32));
            VX_INST_FMT_D:  resp_data[i] = XLEN_P'(signed'(resp_data64));
        `else
            VX_INST_FMT_W:  resp_data[i] = XLEN_P'(signed'(resp_data32));
        `endif
            default: resp_data[i] = 'x;
            endcase
        end
    end

    // commit

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + PC_WIDTH_P + 1 + VX_NR_BITS + (NUM_LANES * XLEN_P)),
        .SIZE_P         (2)
    ) resp_buf (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .vld_i  (mem_resp_vld),
        .rdy_i  (mem_resp_rdy),
        .data_i ({resp_uuid, resp_wid, mem_resp_mask, resp_pc, resp_wb, resp_rd, resp_data/*, resp_pid, mem_resp_sop_pkt, mem_resp_eop_pkt*/}),
        .data_o ({commit_resp_if.data.uuid, commit_resp_if.data.wid, commit_resp_if.data.tmask, commit_resp_if.data.PC, commit_resp_if.data.wb, commit_resp_if.data.rd, commit_resp_if.data.data/*, commit_resp_if.data.pid, commit_resp_if.data.sop, commit_resp_if.data.eop*/}),
        .vld_o  (commit_resp_if.vld),
        .rdy_o  (commit_resp_if.rdy)
    );

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES + PC_WIDTH_P),
        .SIZE_P         (2)
    ) no_resp_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (no_resp_buf_vld),
        .rdy_i      (no_resp_buf_rdy),
        .data_i     ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC/*, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop*/}),
        .data_o     ({commit_no_resp_if.data.uuid, commit_no_resp_if.data.wid, commit_no_resp_if.data.tmask, commit_no_resp_if.data.PC/*, commit_no_resp_if.data.pid, commit_no_resp_if.data.sop, commit_no_resp_if.data.eop*/}),
        .vld_o      (commit_no_resp_if.vld),
        .rdy_o      (commit_no_resp_if.rdy)
    );

    assign commit_no_resp_if.data.rd   = '0;
    assign commit_no_resp_if.data.wb   = 1'b0;
    assign commit_no_resp_if.data.data = commit_resp_if.data.data; // arbiter MUX optimization

    xrv_stream_arb #(
        .NUM_INPUTS_P   (2),
        .DATA_WIDTH_P   (RSP_ARB_DATAW),
        .ARBITER_TYPE_P ("P"), // prioritize commit_resp_if
        .OUT_BUF        (3)
    ) resp_arb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .vld_i          ({commit_no_resp_if.vld, commit_resp_if.vld}),
        .rdy_i          ({commit_no_resp_if.rdy, commit_resp_if.rdy}),
        .data_i         ({commit_no_resp_if.data, commit_resp_if.data}),
        .data_o         (commit_if.data),
        .vld_o          (commit_if.vld),
        .rdy_o          (commit_if.rdy),
        `XM_UNUSED_PIN  (sel_o)
    );

`ifdef DBG_TRACE_MEM
    always @(posedge clk_i) begin
        if (execute_if.vld && fence_lock) begin
            `TRACE(2, ("%t: *** %s fence wait\n", $time, INSTANCE_ID))
        end
        if (mem_req_fire) begin
            if (mem_req_rw) begin
                `TRACE(2, ("%t: %s Wr Req: wid=%0d, PC=0x%0h, tmask=%b, addr=", $time, INSTANCE_ID, execute_if.data.wid, {execute_if.data.PC, 1'b0}, mem_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", full_addr, NUM_LANES)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", mem_req_flags, NUM_LANES)
                `TRACE(2, (", be=0x%0h, data=", mem_req_be))
                `TRACE_ARRAY1D(2, "0x%0h", mem_req_data, NUM_LANES)
                `TRACE(2, (", sop=%b, eop=%b, tag=0x%0h (#%0d)\n", execute_if.data.sop, execute_if.data.eop, mem_req_tag, execute_if.data.uuid))
            end else begin
                `TRACE(2, ("%t: %s Rd Req: wid=%0d, PC=0x%0h, tmask=%b, addr=", $time, INSTANCE_ID, execute_if.data.wid, {execute_if.data.PC, 1'b0}, mem_req_mask))
                `TRACE_ARRAY1D(2, "0x%h", full_addr, NUM_LANES)
                `TRACE(2, (", flags="))
                `TRACE_ARRAY1D(2, "%b", mem_req_flags, NUM_LANES)
                `TRACE(2, (", be=0x%0h, rd=%0d, sop=%b, eop=%b, tag=0x%0h (#%0d)\n", mem_req_be, execute_if.data.rd, execute_if.data.sop, execute_if.data.eop, mem_req_tag, execute_if.data.uuid))
            end
        end
        if (mem_resp_fire) begin
            `TRACE(2, ("%t: %s Rsp: wid=%0d, PC=0x%0h, tmask=%b, rd=%0d, sop=%b, eop=%b, data=",
                $time, INSTANCE_ID, resp_wid, {resp_pc, 1'b0}, mem_resp_mask, resp_rd, mem_resp_sop, mem_resp_eop))
            `TRACE_ARRAY1D(2, "0x%0h", mem_resp_data, NUM_LANES)
            `TRACE(2, (", tag=0x%0h (#%0d)\n", mem_resp_tag, resp_uuid))
        end
    end
`endif

`ifdef SCOPE
`ifdef DBG_SCOPE_LSU
    `SCOPE_IO_SWITCH (1);
    `NEG_EDGE (rst_i_negedge, rst_i);
    `SCOPE_TAP_EX (0, 3, 4, 2, (
            1 + NUM_LANES * (XLEN_P + LSU_WORD_SIZE_P + LSU_WORD_SIZE_P * 8) + UUID_WIDTH_P + NUM_LANES * LSU_WORD_SIZE_P * 8 + UUID_WIDTH_P
        ), {
            mem_req_vld,
            mem_req_rdy,
            mem_resp_vld,
            mem_resp_rdy
        }, {
            mem_req_fire,
            mem_resp_fire
        }, {
            mem_req_rw,
            full_addr,
            mem_req_be,
            mem_req_data,
            execute_if.data.uuid,
            resp_data,
            resp_uuid
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
        .probe0 ({execute_if.vld, execute_if.data, execute_if.rdy}),
        .probe1 ({lsu_mem_if.req_vld, lsu_mem_if.req_data, lsu_mem_if.req_rdy}),
        .probe2 ({lsu_mem_if.resp_vld, lsu_mem_if.resp_data, lsu_mem_if.resp_rdy})
    );
`endif
`endif

endmodule
