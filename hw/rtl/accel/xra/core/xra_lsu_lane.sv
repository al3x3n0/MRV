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

module xra_lsu_lane #(
    parameter `STRING INSTANCE_ID = ""
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
    localparam NUM_LANES_P      = VX_NUM_THREADS_P;
    localparam RESP_ARB_DATA_WIDTH_LP    = VX_UUID_WIDTH_P + VX_WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P+ `NR_BITS + 1 + NUM_LANES_P * XLEN_P;
    localparam LSUQ_SIZEW       = `XM_LOG2UP(`LSUQ_IN_SIZE);
    localparam REQ_ASHIFT       = `XM_CLOG2(LSU_WORD_SIZE);
    localparam MEM_ASHIFT       = `XM_CLOG2(`MEM_BLOCK_SIZE);
    localparam MEM_ADDRW        = `MEM_ADDR_WIDTH - MEM_ASHIFT;

    // tag_id = wid + PC + wb + rd + op_type + align + fence
    localparam TAG_ID_WIDTH = VX_WID_WIDTH_P + PC_WIDTH_P+ 1 + `NR_BITS + `INST_LSU_BITS + (NUM_LANES_P * REQ_ASHIFT) + PID_WIDTH + LSUQ_SIZEW + 1;

    // tag = uuid + tag_id
    localparam TAG_WIDTH = VX_UUID_WIDTH_P + TAG_ID_WIDTH;

    xrv_vx_commit_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) commit_rsp_if();

    xrv_vx_commit_if #(
        .NUM_LANES_P (NUM_LANES_P)
    ) commit_no_rsp_if();

    `UNUSED_VAR (execute_if.data.rs3_data)
    `UNUSED_VAR (execute_if.data.tid)

    // full address calculation

    wire req_is_fence, rsp_is_fence;

    wire [XLEN_P-1:0] full_addr;
    assign full_addr = execute_if.data.rs1_data + `SEXT(XLEN_P, execute_if.data.op_args.lsu.offset);

    // address type calculation
    wire [`MEM_REQ_FLAGS_WIDTH-1:0] mem_req_flags;

    wire [MEM_ADDRW-1:0] block_addr = full_addr[MEM_ASHIFT +: MEM_ADDRW];
    // is I/O address
    wire [MEM_ADDRW-1:0] io_addr_start = MEM_ADDRW'(XLEN_P'(`IO_BASE_ADDR) >> MEM_ASHIFT);
    wire [MEM_ADDRW-1:0] io_addr_end = MEM_ADDRW'(XLEN_P'(`IO_END_ADDR) >> MEM_ASHIFT);
    assign mem_req_flags[`MEM_REQ_FLAG_FLUSH] = req_is_fence;
    assign mem_req_flags[`MEM_REQ_FLAG_IO] = (block_addr >= io_addr_start) && (block_addr < io_addr_end);
    // is local memory address
    wire [MEM_ADDRW-1:0] lmem_addr_start = MEM_ADDRW'(XLEN_P'(`LMEM_BASE_ADDR) >> MEM_ASHIFT);
    wire [MEM_ADDRW-1:0] lmem_addr_end = MEM_ADDRW'((XLEN_P'(`LMEM_BASE_ADDR) + XLEN_P'(1 << `LMEM_LOG_SIZE)) >> MEM_ASHIFT);
    assign mem_req_flags[`MEM_REQ_FLAG_LOCAL] = (block_addr >= lmem_addr_start) && (block_addr < lmem_addr_end);

    // schedule memory request

    wire                            mem_req_valid;
    wire [NUM_LANES_P-1:0]          mem_req_mask;
    wire                            mem_req_rw;
    wire [NUM_LANES_P-1:0][LSU_ADDR_WIDTH-1:0] mem_req_addr;
    wire [NUM_LANES_P-1:0][LSU_WORD_SIZE-1:0] mem_req_byteen;
    reg  [NUM_LANES_P-1:0][LSU_WORD_SIZE*8-1:0] mem_req_data;
    wire [TAG_WIDTH-1:0]            mem_req_tag;
    wire                            mem_req_ready;

    wire                            mem_rsp_valid;
    wire [NUM_LANES_P-1:0]            mem_rsp_mask;
    wire [NUM_LANES_P-1:0][LSU_WORD_SIZE*8-1:0] mem_rsp_data;
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

    wire [REQ_ASHIFT-1:0] req_align;

    assign req_align = full_addr[REQ_ASHIFT-1:0];
    assign mem_req_addr = full_addr[`MEM_ADDR_WIDTH-1:REQ_ASHIFT];

    // byte enable formatting
    reg [LSU_WORD_SIZE-1:0] mem_req_byteen_w;
    always @(*) begin
        mem_req_byteen_w = '0;
        case (`INST_LSU_WSIZE(execute_if.data.op_type))
            0: begin // 8-bit
                mem_req_byteen_w[req_align] = 1'b1;
            end
            1: begin // 16 bit
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:1], 1'b0}] = 1'b1;
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:1], 1'b1}] = 1'b1;
            end
        `ifdef XLEN_64
            2: begin // 32 bit
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:2], 2'b00}] = 1'b1;
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:2], 2'b01}] = 1'b1;
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:2], 2'b10}] = 1'b1;
                mem_req_byteen_w[{req_align[REQ_ASHIFT-1:2], 2'b11}] = 1'b1;
            end
        `endif
            // 3: 64 bit
            default : mem_req_byteen_w = {LSU_WORD_SIZE{1'b1}};
        endcase
    end
    assign mem_req_byteen = mem_req_byteen_w;

    // memory misalignment not supported!
    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_missalign
        wire lsu_req_fire = execute_if.valid && execute_if.ready;
        `RUNTIME_ASSERT((~lsu_req_fire || ~execute_if.data.tmask[i] || req_is_fence || (full_addr[i] % (1 << `INST_LSU_WSIZE(execute_if.data.op_type))) == 0),
            ("%t: misaligned memory access, wid=%0d, PC=0x%0h, addr=0x%0h, wsize=%0d! (#%0d)",
                $time, execute_if.data.wid, {execute_if.data.PC, 1'b0}, full_addr[i], `INST_LSU_WSIZE(execute_if.data.op_type), execute_if.data.uuid))
    end

    // store data formatting
    always @(*) begin
        mem_req_data = execute_if.data.rs2_data;
        case (req_align)
            1: mem_req_data[XLEN_P-1:8]  = execute_if.data.rs2_data[XLEN_P-9:0];
            2: mem_req_data[XLEN_P-1:16] = execute_if.data.rs2_data[XLEN_P-17:0];
            3: mem_req_data[XLEN_P-1:24] = execute_if.data.rs2_data[XLEN_P-25:0];
        `ifdef XLEN_64
            4: mem_req_data[XLEN_P-1:32] = execute_if.data.rs2_data[XLEN_P-33:0];
            5: mem_req_data[XLEN_P-1:40] = execute_if.data.rs2_data[XLEN_P-41:0];
            6: mem_req_data[XLEN_P-1:48] = execute_if.data.rs2_data[XLEN_P-49:0];
            7: mem_req_data[XLEN_P-1:56] = execute_if.data.rs2_data[XLEN_P-57:0];
        `endif
            default:;
        endcase
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

    wire [VX_UUID_WIDTH_P-1:0] rsp_uuid;
    wire [VX_WID_WIDTH_P-1:0] rsp_wid;
    wire [VX_PC_WIDTH_P-1:0] rsp_pc;
    wire rsp_wb;
    wire [`NR_BITS-1:0] rsp_rd;
    wire [`INST_LSU_BITS-1:0] rsp_op_type;
    wire [NUM_LANES_P-1:0][REQ_ASHIFT-1:0] rsp_align;
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
        pkt_raddr,
        rsp_is_fence
    } = mem_rsp_tag;

    // load response formatting
    reg [XLEN_P-1:0] rsp_data;

`ifdef XLEN_64
`ifdef EXT_F_ENABLE
    // apply nan-boxing to flw outputs
    wire rsp_is_float = rsp_rd[5];
`else
    wire rsp_is_float = 0;
`endif
`endif

`ifdef XLEN_64
    wire [63:0] rsp_data64 = mem_rsp_data;
    wire [31:0] rsp_data32 = (rsp_align[2] ? mem_rsp_data[63:32] : mem_rsp_data[31:0]);
`else
    wire [31:0] rsp_data32 = mem_rsp_data;
`endif
    wire [15:0] rsp_data16 = rsp_align[1] ? rsp_data32[31:16] : rsp_data32[15:0];
    wire [7:0]  rsp_data8  = rsp_align[0] ? rsp_data16[15:8] : rsp_data16[7:0];

    always @(*) begin
        case (`INST_LSU_FMT(rsp_op_type))
        `INST_FMT_B:  rsp_data = XLEN_P'(signed'(rsp_data8));
        `INST_FMT_H:  rsp_data = XLEN_P'(signed'(rsp_data16));
        `INST_FMT_BU: rsp_data = XLEN_P'(unsigned'(rsp_data8));
        `INST_FMT_HU: rsp_data = XLEN_P'(unsigned'(rsp_data16));
    `ifdef XLEN_64
        `INST_FMT_W:  rsp_data = rsp_is_float ? (XLEN_P'(rsp_data32) | 64'hffffffff00000000) : XLEN_P'(signed'(rsp_data32));
        `INST_FMT_WU: rsp_data = XLEN_P'(unsigned'(rsp_data32));
        `INST_FMT_D:  rsp_data = XLEN_P'(signed'(rsp_data64));
    `else
        `INST_FMT_W:  rsp_data = XLEN_P'(signed'(rsp_data32));
    `endif
        default: rsp_data = 'x;
        endcase
    end

endmodule
