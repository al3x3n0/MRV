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

`include "subsystems/vortex_cache/defines.svh"


module xrv_cache #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 32,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    // Size of cache in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_SIZE_P              = 65536,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Word requests per cycle
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS_P                = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of memory ports
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_MEM_PORTS_P           = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of line inside a bank in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter LINE_SIZE_P               = 64,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of banks
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_BANKS_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of associative ways
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WAYS_P                = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of a word in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter WORD_SIZE_P               = 16,
    ////////////////////////////////////////////////////////////////////////////////
    // Core Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter CRSQ_SIZE_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Miss Reserv Queue Knob
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_SIZE_P               = 16,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MRSQ_SIZE_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Request Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MREQ_SIZE_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeable
    ////////////////////////////////////////////////////////////////////////////////
    parameter IS_WRITEABLE_P            = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable dirty bytes on writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_DIRTY_BYTES_P         = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Replacement policy
    ////////////////////////////////////////////////////////////////////////////////
    parameter REPL_POLICY           = `CACHE_REPL_CYCLIC,
    ////////////////////////////////////////////////////////////////////////////////
    // Request debug identifier
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P            = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // core request tag size
    ////////////////////////////////////////////////////////////////////////////////
    parameter TAG_WIDTH_P           = UUID_WIDTH_P + 1,
    ////////////////////////////////////////////////////////////////////////////////
    // core request flags
    ////////////////////////////////////////////////////////////////////////////////
    parameter FLAGS_WIDTH_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Core response output register
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_OUT_BUF          = 3,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request output register
    ////////////////////////////////////////////////////////////////////////////////
    parameter MEM_OUT_BUF           = 3,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS
    ////////////////////////////////////////////////////////////////////////////////
 ) (
    // PERF
`ifdef PERF_ENABLE
    output cache_perf_t     cache_perf,
`endif
    ////////////////////////////////////////////////////////////////////////////////
    input logic                 clk_i,
    input logic                 rst_i,
    xrv_cache_if.slave          core_bus_if [NUM_REQS_P],
    xrv_cache_if.master         mem_bus_if  [NUM_MEM_PORTS_P]
);

    `STATIC_ASSERT(NUM_BANKS_P == (1 << $clog2(NUM_BANKS_P)), ("invld parameter: number of banks must be power of 2"))
    `STATIC_ASSERT(IS_WRITEABLE_P || !HAS_WRITEBACK_P, ("invld parameter: writeback requires write enable"))
    `STATIC_ASSERT(HAS_WRITEBACK_P || !HAS_DIRTY_BYTES_P, ("invld parameter: dirty bytes require writeback"))
    `STATIC_ASSERT(NUM_BANKS_P >= NUM_MEM_PORTS_P, ("invld parameter: number of banks must be greater or equal to number of memory ports"))

    localparam REQ_SEL_WIDTH   = `XM_UP(CACHE_REQ_SEL_BITS_LP);
    localparam WORD_SEL_WIDTH  = `XM_UP(CACHE_WORD_SEL_BITS_LP);
    localparam MSHR_ADDR_WIDTH = `XM_LOG2UP(MSHR_SIZE_P);
    localparam MEM_TAG_WIDTH_LP   = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE_P, NUM_BANKS_P, NUM_MEM_PORTS_P, UUID_WIDTH_P);
    localparam WORDS_PER_LINE  = LINE_SIZE_P / WORD_SIZE_P;
    localparam WORD_WIDTH_LP      = WORD_SIZE_P * 8;
    localparam WORD_SEL_BITS   = $clog2(WORDS_PER_LINE);
    localparam BANK_SEL_BITS   = $clog2(NUM_BANKS_P);
    localparam BANK_SEL_WIDTH  = `XM_UP(BANK_SEL_BITS);
    localparam LINE_ADDR_WIDTH = (CACHE_WORD_ADDR_WIDTH_LP - BANK_SEL_BITS - WORD_SEL_BITS);
    localparam CORE_REQ_DATA_WIDTH_LP  = LINE_ADDR_WIDTH + 1 + WORD_SEL_WIDTH + WORD_SIZE_P + WORD_WIDTH_LP + TAG_WIDTH_P + `XM_UP(FLAGS_WIDTH_P);
    localparam CORE_RESP_DATA_WIDTH_LP  = WORD_WIDTH_LP + TAG_WIDTH_P;
    localparam BANK_MEM_TAG_WIDTH_LP = UUID_WIDTH_P + MSHR_ADDR_WIDTH;
    localparam MEM_REQ_DATAW   = (CACHE_LINE_ADDR_WIDTH_LP + 1 + LINE_SIZE_P + CACHE_LINE_WIDTH_LP + BANK_MEM_TAG_WIDTH_LP + `XM_UP(FLAGS_WIDTH_P));
    localparam MEM_RESP_DATA_WIDTH_LP   = CACHE_LINE_WIDTH_LP + MEM_TAG_WIDTH_LP;
    localparam NUM_MEM_PORTS_P_SEL_BITS = $clog2(NUM_MEM_PORTS_P);
    localparam NUM_MEM_PORTS_P_SEL_WIDTH = `XM_UP(NUM_MEM_PORTS_P_SEL_BITS);
    localparam MEM_ARB_SEL_BITS = $clog2(`XM_CDIV(NUM_BANKS_P, NUM_MEM_PORTS_P));
    localparam MEM_ARB_SEL_WIDTH = `XM_UP(MEM_ARB_SEL_BITS);

    localparam CORE_RESP_REG_DISABLE_LP = (NUM_BANKS_P != 1) || (NUM_REQS_P != 1);
    localparam MEM_REQ_REG_DISABLE_LP  = (NUM_BANKS_P != 1);

    localparam REQ_XBAR_BUF = (NUM_REQS_P > 4) ? 2 : 0;

`ifdef PERF_ENABLE
    logic [NUM_BANKS_P-1:0] perf_read_miss_per_bank;
    logic [NUM_BANKS_P-1:0] perf_write_miss_per_bank;
    logic [NUM_BANKS_P-1:0] perf_mshr_stall_per_bank;
`endif

    xrv_cache_if #(
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (TAG_WIDTH_P)
    ) core_bus2_if[NUM_REQS_P]();

    logic [`XM_UP(UUID_WIDTH_P)-1:0]  flush_uuid;
    logic [NUM_BANKS_P-1:0]         per_bank_flush_begin;
    logic [NUM_BANKS_P-1:0]         per_bank_flush_end;

    logic [NUM_BANKS_P-1:0] per_bank_core_req_fire;

    ////////////////////////////////////////////////////////////////////////////////
    // Cache flush
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_flush #(
        .NUM_REQS_P             (NUM_REQS_P),
        .NUM_BANKS_P            (NUM_BANKS_P),
        .UUID_WIDTH_P           (UUID_WIDTH_P),
        .TAG_WIDTH_P            (TAG_WIDTH_P),
        .BANK_SEL_LATENCY_P     (`XM_TO_OUT_BUF_REG(REQ_XBAR_BUF)) // bank xbar latency
    ) flush_unit (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .core_bus_in_if         (core_bus_if),
        .core_bus_out_if        (core_bus2_if),
        .bank_req_fire_i        (per_bank_core_req_fire),
        .flush_begin_o          (per_bank_flush_begin),
        .flush_uuid_o           (flush_uuid),
        .flush_end_i            (per_bank_flush_end)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Memory response gather
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_if #(
        .DATA_SIZE_P    (LINE_SIZE_P),
        .TAG_WIDTH_P    (MEM_TAG_WIDTH_LP)
    ) mem_bus_tmp_if[NUM_MEM_PORTS_P]();

    logic [NUM_MEM_PORTS_P-1:0]                             mem_bus_tmp_resp_vld;
    logic [NUM_MEM_PORTS_P-1:0][MEM_RESP_DATA_WIDTH_LP-1:0] mem_bus_tmp_resp_data;
    logic [NUM_MEM_PORTS_P-1:0]                             mem_bus_tmp_resp_rdy;

    logic [NUM_MEM_PORTS_P-1:0]                             mem_resp_queue_vld;
    logic [NUM_MEM_PORTS_P-1:0][MEM_RESP_DATA_WIDTH_LP-1:0] mem_resp_queue_data;
    logic [NUM_MEM_PORTS_P-1:0]                             mem_resp_queue_rdy;

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_resp_queue
        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (MEM_RESP_DATA_WIDTH_LP),
            .SIZE_P         (MRSQ_SIZE_P),
            .OUT_REG        (MRSQ_SIZE_P > 2)
        ) mem_resp_queue_i (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (mem_bus_tmp_resp_vld[i]),
            .data_i         (mem_bus_tmp_resp_data[i]),
            .rdy_i          (mem_bus_tmp_resp_rdy[i]),
            .vld_o          (mem_resp_queue_vld[i]),
            .data_o         (mem_resp_queue_data[i]),
            .rdy_o          (mem_resp_queue_rdy[i])
        );
    end

    logic [NUM_MEM_PORTS_P-1:0][MEM_RESP_DATA_WIDTH_LP-MEM_ARB_SEL_BITS-1:0] mem_resp_queue_data_s;
    logic [NUM_MEM_PORTS_P-1:0][BANK_SEL_WIDTH-1:0] mem_resp_queue_sel;

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_resp_queue_data_s
        wire [BANK_MEM_TAG_WIDTH_LP-1:0] mem_resp_tag_s = mem_resp_queue_data[i][MEM_TAG_WIDTH_LP-1:MEM_ARB_SEL_BITS];
        wire [CACHE_LINE_WIDTH_LP-1:0] mem_resp_data_s = mem_resp_queue_data[i][MEM_RESP_DATA_WIDTH_LP-1:MEM_TAG_WIDTH_LP];
        assign mem_resp_queue_data_s[i] = {mem_resp_data_s, mem_resp_tag_s};
    end

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_resp_queue_sel
        if (NUM_BANKS_P > 1) begin : g_multibanks
            if (NUM_BANKS_P != NUM_MEM_PORTS_P) begin : g_arb_sel
                xrv_bits_concat #(
                    .L (MEM_ARB_SEL_BITS),
                    .R (NUM_MEM_PORTS_P_SEL_BITS)
                ) mem_resp_sel_concat (
                    .left_i     (mem_resp_queue_data[i][MEM_ARB_SEL_BITS-1:0]),
                    .right_i    (NUM_MEM_PORTS_P_SEL_WIDTH'(i)),
                    .data_o     (mem_resp_queue_sel[i])
                );
            end else begin : g_no_arb_sel
                assign mem_resp_queue_sel[i] = NUM_MEM_PORTS_P_SEL_WIDTH'(i);
            end
        end else begin : g_singlebank
            assign mem_resp_queue_sel[i] = 0;
        end
    end

    logic [NUM_BANKS_P-1:0] per_bank_mem_resp_vld;
    logic [NUM_BANKS_P-1:0][MEM_RESP_DATA_WIDTH_LP-MEM_ARB_SEL_BITS-1:0] per_bank_mem_resp_pdata;
    logic [NUM_BANKS_P-1:0] per_bank_mem_resp_rdy;

    xrv_stream_omega #(
        .NUM_INPUTS_P       (NUM_MEM_PORTS_P),
        .NUM_OUTPUTS_P      (NUM_BANKS_P),
        .DATA_WIDTH_P       (MEM_RESP_DATA_WIDTH_LP-MEM_ARB_SEL_BITS),
        .ARBITER_TYPE_P     ("R"),
        .OUT_BUF            (3)
    ) mem_resp_xbar_i (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .vld_i              (mem_resp_queue_vld),
        .data_i             (mem_resp_queue_data_s),
        .sel_i              (mem_resp_queue_sel),
        .rdy_i              (mem_resp_queue_rdy),
        .vld_o              (per_bank_mem_resp_vld),
        .data_o             (per_bank_mem_resp_pdata),
        `XM_UNUSED_PIN      (sel_o),
        .rdy_o              (per_bank_mem_resp_rdy),
        `XM_UNUSED_PIN      (collisions_o)
    );

    logic [NUM_BANKS_P-1:0][CACHE_LINE_WIDTH_LP-1:0] per_bank_mem_resp_data;
    logic [NUM_BANKS_P-1:0][BANK_MEM_TAG_WIDTH_LP-1:0] per_bank_mem_resp_tag;

    for (genvar i = 0; i < NUM_BANKS_P; ++i) begin : g_per_bank_mem_resp_data
        assign {
            per_bank_mem_resp_data[i],
            per_bank_mem_resp_tag[i]
        } = per_bank_mem_resp_pdata[i];
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Core requests dispatch
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_BANKS_P-1:0]                                 per_bank_core_req_vld;
    logic [NUM_BANKS_P-1:0][CACHE_LINE_ADDR_WIDTH_LP-1:0]   per_bank_core_req_addr;
    logic [NUM_BANKS_P-1:0]                                 per_bank_core_req_rw;
    logic [NUM_BANKS_P-1:0][WORD_SEL_WIDTH-1:0]             per_bank_core_req_wsel;
    logic [NUM_BANKS_P-1:0][WORD_SIZE_P-1:0]                per_bank_core_req_be;
    logic [NUM_BANKS_P-1:0][CACHE_WORD_WIDTH_LP-1:0]        per_bank_core_req_data;
    logic [NUM_BANKS_P-1:0][TAG_WIDTH_P-1:0]                per_bank_core_req_tag;
    logic [NUM_BANKS_P-1:0][REQ_SEL_WIDTH-1:0]              per_bank_core_req_idx;
    logic [NUM_BANKS_P-1:0][`XM_UP(FLAGS_WIDTH_P)-1:0]        per_bank_core_req_flags;
    logic [NUM_BANKS_P-1:0]                                 per_bank_core_req_rdy;

    logic [NUM_BANKS_P-1:0]                                 per_bank_core_resp_vld;
    logic [NUM_BANKS_P-1:0][CACHE_WORD_WIDTH_LP-1:0]        per_bank_core_resp_data;
    logic [NUM_BANKS_P-1:0][TAG_WIDTH_P-1:0]                per_bank_core_resp_tag;
    logic [NUM_BANKS_P-1:0][REQ_SEL_WIDTH-1:0]              per_bank_core_resp_idx;
    logic [NUM_BANKS_P-1:0]                                 per_bank_core_resp_rdy;

    logic [NUM_BANKS_P-1:0]                                 per_bank_mem_req_vld;
    logic [NUM_BANKS_P-1:0][CACHE_LINE_ADDR_WIDTH_LP-1:0]   per_bank_mem_req_addr;
    logic [NUM_BANKS_P-1:0]                                 per_bank_mem_req_rw;
    logic [NUM_BANKS_P-1:0][LINE_SIZE_P-1:0]                per_bank_mem_req_be;
    logic [NUM_BANKS_P-1:0][CACHE_LINE_WIDTH_LP-1:0]        per_bank_mem_req_data;
    logic [NUM_BANKS_P-1:0][BANK_MEM_TAG_WIDTH_LP-1:0]      per_bank_mem_req_tag;
    logic [NUM_BANKS_P-1:0][`XM_UP(FLAGS_WIDTH_P)-1:0]        per_bank_mem_req_flags;
    logic [NUM_BANKS_P-1:0]                                 per_bank_mem_req_rdy;

    logic [NUM_REQS_P-1:0]                               core_req_vld;
    logic [NUM_REQS_P-1:0][CACHE_WORD_ADDR_WIDTH_LP-1:0] core_req_addr;
    logic [NUM_REQS_P-1:0]                               core_req_rw;
    logic [NUM_REQS_P-1:0][WORD_SIZE_P-1:0]              core_req_be;
    logic [NUM_REQS_P-1:0][CACHE_WORD_WIDTH_LP-1:0]      core_req_data;
    logic [NUM_REQS_P-1:0][TAG_WIDTH_P-1:0]              core_req_tag;
    logic [NUM_REQS_P-1:0][`XM_UP(FLAGS_WIDTH_P)-1:0]    core_req_flags;
    logic [NUM_REQS_P-1:0]                               core_req_rdy;

    logic [NUM_REQS_P-1:0][LINE_ADDR_WIDTH-1:0] core_req_line_addr;
    logic [NUM_REQS_P-1:0][BANK_SEL_WIDTH-1:0]  core_req_bid;
    logic [NUM_REQS_P-1:0][WORD_SEL_WIDTH-1:0]  core_req_wsel;

    logic [NUM_REQS_P-1:0][CORE_REQ_DATA_WIDTH_LP-1:0]  core_req_data_in;
    logic [NUM_BANKS_P-1:0][CORE_REQ_DATA_WIDTH_LP-1:0] core_req_data_out;

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req
        assign core_req_vld[i]              = core_bus2_if[i].req_vld;
        assign core_req_rw[i]               = core_bus2_if[i].req_data.rw;
        assign core_req_be[i]               = core_bus2_if[i].req_data.be;
        assign core_req_addr[i]             = core_bus2_if[i].req_data.addr;
        assign core_req_data[i]             = core_bus2_if[i].req_data.data;
        assign core_req_tag[i]              = core_bus2_if[i].req_data.tag;
        assign core_req_flags[i]            = `XM_UP(FLAGS_WIDTH_P)'(core_bus2_if[i].req_data.flags);
        assign core_bus2_if[i].req_rdy      = core_req_rdy[i];
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req_wsel
        if (WORDS_PER_LINE > 1) begin : g_wsel
            assign core_req_wsel[i] = core_req_addr[i][0 +: WORD_SEL_BITS];
        end else begin : g_no_wsel
            assign core_req_wsel[i] = '0;
        end
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req_line_addr
        assign core_req_line_addr[i] = core_req_addr[i][(BANK_SEL_BITS + WORD_SEL_BITS) +: LINE_ADDR_WIDTH];
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req_bid
        if (NUM_BANKS_P > 1) begin : g_multibanks
            assign core_req_bid[i] = core_req_addr[i][WORD_SEL_BITS +: BANK_SEL_BITS];
        end else begin : g_singlebank
            assign core_req_bid[i] = '0;
        end
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req_data_in
        assign core_req_data_in[i] = {
            core_req_line_addr[i],
            core_req_rw[i],
            core_req_wsel[i],
            core_req_be[i],
            core_req_data[i],
            core_req_tag[i],
            core_req_flags[i]
        };
    end

    assign per_bank_core_req_fire = per_bank_core_req_vld & per_bank_mem_req_rdy;

`ifdef PERF_ENABLE
    logic [`PERF_CTR_BITS-1:0] perf_collisions;
`endif

    xrv_stream_xbar #(
        .NUM_INPUTS_P       (NUM_REQS_P),
        .NUM_OUTPUTS_P      (NUM_BANKS_P),
        .DATA_WIDTH_P       (CORE_REQ_DATA_WIDTH_LP),
        .PERF_CTR_BITS      (`PERF_CTR_BITS),
        .ARBITER_TYPE_P     ("R"),
        .OUT_BUF            (REQ_XBAR_BUF)
    ) req_xbar (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
    `ifdef PERF_ENABLE
        .collisions(perf_collisions),
    `else
        `XM_UNUSED_PIN(collisions_o),
    `endif
        .vld_i              (core_req_vld),
        .data_i             (core_req_data_in),
        .sel_i              (core_req_bid),
        .rdy_i              (core_req_rdy),
        .vld_o              (per_bank_core_req_vld),
        .data_o             (core_req_data_out),
        .sel_o              (per_bank_core_req_idx),
        .rdy_o              (per_bank_core_req_rdy)
    );

    for (genvar i = 0; i < NUM_BANKS_P; ++i) begin : g_core_req_data_out
        assign {
            per_bank_core_req_addr[i],
            per_bank_core_req_rw[i],
            per_bank_core_req_wsel[i],
            per_bank_core_req_be[i],
            per_bank_core_req_data[i],
            per_bank_core_req_tag[i],
            per_bank_core_req_flags[i]
        } = core_req_data_out[i];
    end

    // Banks access ///////////////////////////////////////////////////////////

    for (genvar bank_id = 0; bank_id < NUM_BANKS_P; ++bank_id) begin : g_banks
        xrv_cache_bank #(
            .BANK_ID_P      (bank_id),
            .INSTANCE_ID    (`SFORMATF(("%s-bank%0d", INSTANCE_ID, bank_id))),
            .LINE_SIZE_P    (LINE_SIZE_P),
            .NUM_BANKS_P    (NUM_BANKS_P),
            .NUM_WAYS_P     (NUM_WAYS_P),
            .WORD_SIZE_P    (WORD_SIZE_P),
            .NUM_REQS_P     (NUM_REQS_P),
            .IS_WRITEABLE_P   (IS_WRITEABLE_P),
            .HAS_WRITEBACK_P      (HAS_WRITEBACK_P),
            .HAS_DIRTY_BYTES_P    (HAS_DIRTY_BYTES_P),
            .REPL_POLICY    (REPL_POLICY),
            .CRSQ_SIZE_P    (CRSQ_SIZE_P),
            .MSHR_SIZE_P    (MSHR_SIZE_P),
            .MREQ_SIZE_P    (MREQ_SIZE_P),
            .MRSQ_SIZE_P    (MRSQ_SIZE_P),
            .UUID_WIDTH_P   (UUID_WIDTH_P),
            .TAG_WIDTH_P    (TAG_WIDTH_P),
            .FLAGS_WIDTH_P    (FLAGS_WIDTH_P),
            .CORE_OUT_REG   (CORE_RESP_REG_DISABLE_LP ? 0 : 1),
            .MEM_OUT_REG    (MEM_REQ_REG_DISABLE_LP ? 0 : 1)
        ) bank (
            .clk_i                  (clk_i),
            .rst_i                  (rst_i),

        `ifdef PERF_ENABLE
            .perf_read_miss         (perf_read_miss_per_bank[bank_id]),
            .perf_write_miss        (perf_write_miss_per_bank[bank_id]),
            .perf_mshr_stall        (perf_mshr_stall_per_bank[bank_id]),
        `endif
            ////////////////////////////////////////////////////////////////////////////////
            // Core -> Cache request
            ////////////////////////////////////////////////////////////////////////////////
            .core_req_vld_i         (per_bank_core_req_vld[bank_id]),
            .core_req_addr_i        (per_bank_core_req_addr[bank_id]),
            .core_req_rw_i          (per_bank_core_req_rw[bank_id]),
            .core_req_wsel_i        (per_bank_core_req_wsel[bank_id]),
            .core_req_be_i          (per_bank_core_req_be[bank_id]),
            .core_req_data_i        (per_bank_core_req_data[bank_id]),
            .core_req_tag_i         (per_bank_core_req_tag[bank_id]),
            .core_req_idx_i         (per_bank_core_req_idx[bank_id]),
            .core_req_flags_i       (per_bank_core_req_flags[bank_id]),
            .core_req_rdy_o         (per_bank_core_req_rdy[bank_id]),
            ////////////////////////////////////////////////////////////////////////////////
            // Cache -> Core response
            ////////////////////////////////////////////////////////////////////////////////
            .core_resp_vld_o         (per_bank_core_resp_vld[bank_id]),
            .core_resp_data_o        (per_bank_core_resp_data[bank_id]),
            .core_resp_tag_o         (per_bank_core_resp_tag[bank_id]),
            .core_resp_idx_o         (per_bank_core_resp_idx[bank_id]),
            .core_resp_rdy_i         (per_bank_core_resp_rdy[bank_id]),
            ////////////////////////////////////////////////////////////////////////////////
            // Cache -> Memory request
            ////////////////////////////////////////////////////////////////////////////////
            .mem_req_vld_o           (per_bank_mem_req_vld[bank_id]),
            .mem_req_addr_o          (per_bank_mem_req_addr[bank_id]),
            .mem_req_rw_o            (per_bank_mem_req_rw[bank_id]),
            .mem_req_be_o            (per_bank_mem_req_be[bank_id]),
            .mem_req_data_o          (per_bank_mem_req_data[bank_id]),
            .mem_req_tag_o           (per_bank_mem_req_tag[bank_id]),
            .mem_req_flags_o         (per_bank_mem_req_flags[bank_id]),
            .mem_req_rdy_i           (per_bank_mem_req_rdy[bank_id]),
            ////////////////////////////////////////////////////////////////////////////////
            // Memory -> Cache response
            ////////////////////////////////////////////////////////////////////////////////
            .mem_resp_vld_i         (per_bank_mem_resp_vld[bank_id]),
            .mem_resp_data_i        (per_bank_mem_resp_data[bank_id]),
            .mem_resp_tag_i         (per_bank_mem_resp_tag[bank_id]),
            .mem_resp_rdy_o         (per_bank_mem_resp_rdy[bank_id]),
            ////////////////////////////////////////////////////////////////////////////////
            // Flush request
            ////////////////////////////////////////////////////////////////////////////////
            .flush_begin_i            (per_bank_flush_begin[bank_id]),
            .flush_uuid_i             (flush_uuid),
            .flush_end_o              (per_bank_flush_end[bank_id])
        );
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Core responses gather
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_BANKS_P-1:0][CORE_RESP_DATA_WIDTH_LP-1:0]    core_resp_data_in;
    logic [NUM_REQS_P-1:0][CORE_RESP_DATA_WIDTH_LP-1:0]     core_resp_data_out;

    logic [NUM_REQS_P-1:0]                                  core_resp_vld_s;
    logic [NUM_REQS_P-1:0][CACHE_WORD_WIDTH_LP-1:0]         core_resp_data_s;
    logic [NUM_REQS_P-1:0][TAG_WIDTH_P-1:0]                 core_resp_tag_s;
    logic [NUM_REQS_P-1:0]                                  core_resp_rdy_s;

    for (genvar i = 0; i < NUM_BANKS_P; ++i) begin : g_core_resp_data_in
        assign core_resp_data_in[i] = {per_bank_core_resp_data[i], per_bank_core_resp_tag[i]};
    end

    xrv_stream_xbar #(
        .NUM_INPUTS_P       (NUM_BANKS_P),
        .NUM_OUTPUTS_P      (NUM_REQS_P),
        .DATA_WIDTH_P       (CORE_RESP_DATA_WIDTH_LP),
        .ARBITER_TYPE_P     ("R")
    ) resp_xbar (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        `XM_UNUSED_PIN      (collisions_o),
        .vld_i              (per_bank_core_resp_vld),
        .data_i             (core_resp_data_in),
        .sel_i              (per_bank_core_resp_idx),
        .rdy_i              (per_bank_core_resp_rdy),
        .vld_o              (core_resp_vld_s),
        .data_o             (core_resp_data_out),
        .rdy_o              (core_resp_rdy_s),
        `XM_UNUSED_PIN      (sel_o)
    );

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_resp_data_s
        assign {core_resp_data_s[i], core_resp_tag_s[i]} = core_resp_data_out[i];
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_resp_buf
        xrv_elastic_buffer #(
            .DATA_WIDTH_P       (CACHE_WORD_WIDTH_LP + TAG_WIDTH_P),
            .SIZE_P             (CORE_RESP_REG_DISABLE_LP ? `XM_TO_OUT_BUF_SIZE(CORE_OUT_BUF) : 0),
            .OUT_REG            (`XM_TO_OUT_BUF_REG(CORE_OUT_BUF))
        ) core_resp_buf (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .vld_i              (core_resp_vld_s[i]),
            .rdy_i              (core_resp_rdy_s[i]),
            .data_i             ({core_resp_data_s[i], core_resp_tag_s[i]}),
            .data_o             ({core_bus2_if[i].resp_data.data, core_bus2_if[i].resp_data.tag}),
            .vld_o              (core_bus2_if[i].resp_vld),
            .rdy_o              (core_bus2_if[i].resp_rdy)
        );
    end

    // Memory request arbitration /////////////////////////////////////////////

    logic [NUM_BANKS_P-1:0][MEM_REQ_DATAW-1:0] per_bank_mem_req_pdata;
    for (genvar i = 0; i < NUM_BANKS_P; ++i) begin : g_per_bank_mem_req_pdata
        assign per_bank_mem_req_pdata[i] = {
            per_bank_mem_req_rw[i],
            per_bank_mem_req_addr[i],
            per_bank_mem_req_data[i],
            per_bank_mem_req_be[i],
            per_bank_mem_req_flags[i],
            per_bank_mem_req_tag[i]
        };
    end

    logic [NUM_MEM_PORTS_P-1:0] mem_req_vld;
    logic [NUM_MEM_PORTS_P-1:0][MEM_REQ_DATAW-1:0] mem_req_pdata;
    logic [NUM_MEM_PORTS_P-1:0] mem_req_rdy;
    logic [NUM_MEM_PORTS_P-1:0][MEM_ARB_SEL_WIDTH-1:0] mem_req_sel_out;

    xrv_stream_arb #(
        .NUM_INPUTS_P       (NUM_BANKS_P),
        .NUM_OUTPUTS_P      (NUM_MEM_PORTS_P),
        .DATA_WIDTH_P       (MEM_REQ_DATAW),
        .ARBITER_TYPE_P     ("R")
    ) mem_req_arb (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .vld_i              (per_bank_mem_req_vld),
        .data_i             (per_bank_mem_req_pdata),
        .rdy_i              (per_bank_mem_req_rdy),
        .vld_o              (mem_req_vld),
        .data_o             (mem_req_pdata),
        .rdy_o              (mem_req_rdy),
        .sel_o              (mem_req_sel_out)
    );

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_req_buf
        logic                               mem_req_rw;
        logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]     mem_req_addr;
        logic [CACHE_LINE_WIDTH_LP-1:0]          mem_req_data;
        logic [LINE_SIZE_P-1:0]             mem_req_be;
        logic [`XM_UP(FLAGS_WIDTH_P)-1:0]        mem_req_flags;
        logic [BANK_MEM_TAG_WIDTH_LP-1:0]   mem_req_tag;

        assign {
            mem_req_rw,
            mem_req_addr,
            mem_req_data,
            mem_req_be,
            mem_req_flags,
            mem_req_tag
        } = mem_req_pdata[i];

        logic [CACHE_MEM_ADDR_WIDTH_LP-1:0] mem_req_addr_w;
        logic [MEM_TAG_WIDTH_LP-1:0] mem_req_tag_w;
        logic [`XM_UP(FLAGS_WIDTH_P)-1:0] mem_req_flags_w;

        if (NUM_BANKS_P > 1) begin : g_mem_req_tag_multibanks
            if (NUM_BANKS_P != NUM_MEM_PORTS_P) begin : g_arb_sel
                logic [CACHE_BANK_SEL_BITS_LP-1:0] mem_req_bank_id;
                xrv_bits_concat #(
                    .L          (MEM_ARB_SEL_BITS),
                    .R          (NUM_MEM_PORTS_P_SEL_BITS)
                ) bank_id_concat (
                    .left_i     (mem_req_sel_out[i]),
                    .right_i    (NUM_MEM_PORTS_P_SEL_WIDTH'(i)),
                    .data_o     (mem_req_bank_id)
                );
                assign mem_req_addr_w = CACHE_MEM_ADDR_WIDTH_LP'({mem_req_addr, mem_req_bank_id});
                assign mem_req_tag_w = {mem_req_tag, mem_req_sel_out[i]};
            end else begin : g_no_arb_sel
                `XM_UNUSED_VAR (mem_req_sel_out)
                assign mem_req_addr_w = CACHE_MEM_ADDR_WIDTH_LP'({mem_req_addr, NUM_MEM_PORTS_P_SEL_WIDTH'(i)});
                assign mem_req_tag_w = MEM_TAG_WIDTH_LP'(mem_req_tag);
            end
        end else begin : g_mem_req_tag
            `XM_UNUSED_VAR (mem_req_sel_out)
            assign mem_req_addr_w = CACHE_MEM_ADDR_WIDTH_LP'(mem_req_addr);
            assign mem_req_tag_w = MEM_TAG_WIDTH_LP'(mem_req_tag);
        end

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (1 + LINE_SIZE_P + CACHE_MEM_ADDR_WIDTH_LP + CACHE_LINE_WIDTH_LP + MEM_TAG_WIDTH_LP + `XM_UP(FLAGS_WIDTH_P)),
            .SIZE_P         (MEM_REQ_REG_DISABLE_LP ? `XM_TO_OUT_BUF_SIZE(MEM_OUT_BUF) : 0),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(MEM_OUT_BUF))
        ) mem_req_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (mem_req_vld[i]),
            .rdy_i          (mem_req_rdy[i]),
            .data_i         ({mem_req_rw,                    mem_req_be,                    mem_req_addr_w,                  mem_req_data,                    mem_req_tag_w,                  mem_req_flags}),
            .data_o         ({mem_bus_tmp_if[i].req_data.rw, mem_bus_tmp_if[i].req_data.be, mem_bus_tmp_if[i].req_data.addr, mem_bus_tmp_if[i].req_data.data, mem_bus_tmp_if[i].req_data.tag, mem_req_flags_w}),
            .vld_o          (mem_bus_tmp_if[i].req_vld),
            .rdy_o          (mem_bus_tmp_if[i].req_rdy)
        );

        if (FLAGS_WIDTH_P != 0) begin : g_mem_req_flags
            assign mem_bus_tmp_if[i].req_data.flags = mem_req_flags_w;
        end else begin : g_no_mem_req_flags
            assign mem_bus_tmp_if[i].req_data.flags = '0;
            `XM_UNUSED_VAR (mem_req_flags_w)
        end

        if (IS_WRITEABLE_P) begin : g_mem_bus_if
            `ASSIGN_XRV_CACHE_IF (mem_bus_if[i], mem_bus_tmp_if[i]);
        end else begin : g_mem_bus_if_ro
            `ASSIGN_XRV_CACHE_RO_IF (mem_bus_if[i], mem_bus_tmp_if[i]);
        end
    end

`ifdef PERF_ENABLE
    logic [NUM_REQS_P-1:0]  perf_core_reads_per_req;
    logic [NUM_REQS_P-1:0]  perf_core_writes_per_req;
    logic [NUM_REQS_P-1:0]  perf_cresp_stall_per_req;
    logic [NUM_MEM_PORTS_P-1:0] perf_mem_stall_per_port;

    `BUFFER(perf_core_reads_per_req, core_req_vld & core_req_rdy & ~core_req_rw);
    `BUFFER(perf_core_writes_per_req, core_req_vld & core_req_rdy & core_req_rw);

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_perf_cresp_stall_per_req
        assign perf_cresp_stall_per_req[i] = core_bus_if[i].resp_vld && ~core_bus_if[i].resp_rdy;
    end

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_perf_mem_stall_per_port
        assign perf_mem_stall_per_port[i] = mem_bus_if[i].req_vld && ~mem_bus_if[i].req_rdy;
    end

    // per cycle: read misses, write misses, msrq stalls, pipeline stalls
    logic [$clog2(NUM_REQS_P+1)-1:0]  perf_core_reads_per_cycle;
    logic [$clog2(NUM_REQS_P+1)-1:0]  perf_core_writes_per_cycle;
    logic [$clog2(NUM_REQS_P+1)-1:0]  perf_cresp_stall_per_cycle;
    logic [$clog2(NUM_BANKS_P+1)-1:0] perf_read_miss_per_cycle;
    logic [$clog2(NUM_BANKS_P+1)-1:0] perf_write_miss_per_cycle;
    logic [$clog2(NUM_BANKS_P+1)-1:0] perf_mshr_stall_per_cycle;
    logic [$clog2(NUM_MEM_PORTS_P+1)-1:0] perf_mem_stall_per_cycle;

    `POP_COUNT(perf_core_reads_per_cycle, perf_core_reads_per_req);
    `POP_COUNT(perf_core_writes_per_cycle, perf_core_writes_per_req);
    `POP_COUNT(perf_read_miss_per_cycle, perf_read_miss_per_bank);
    `POP_COUNT(perf_write_miss_per_cycle, perf_write_miss_per_bank);
    `POP_COUNT(perf_mshr_stall_per_cycle, perf_mshr_stall_per_bank);
    `POP_COUNT(perf_cresp_stall_per_cycle, perf_cresp_stall_per_req);
    `POP_COUNT(perf_mem_stall_per_cycle, perf_mem_stall_per_port);

    logic [`PERF_CTR_BITS-1:0] perf_core_reads;
    logic [`PERF_CTR_BITS-1:0] perf_core_writes;
    logic [`PERF_CTR_BITS-1:0] perf_read_misses;
    logic [`PERF_CTR_BITS-1:0] perf_write_misses;
    logic [`PERF_CTR_BITS-1:0] perf_mshr_stalls;
    logic [`PERF_CTR_BITS-1:0] perf_mem_stalls;
    logic [`PERF_CTR_BITS-1:0] perf_cresp_stalls;

    always @(posedge clk_i) begin
        if (rst_i) begin
            perf_core_reads   <= '0;
            perf_core_writes  <= '0;
            perf_read_misses  <= '0;
            perf_write_misses <= '0;
            perf_mshr_stalls  <= '0;
            perf_mem_stalls   <= '0;
            perf_cresp_stalls  <= '0;
        end else begin
            perf_core_reads   <= perf_core_reads   + `PERF_CTR_BITS'(perf_core_reads_per_cycle);
            perf_core_writes  <= perf_core_writes  + `PERF_CTR_BITS'(perf_core_writes_per_cycle);
            perf_read_misses  <= perf_read_misses  + `PERF_CTR_BITS'(perf_read_miss_per_cycle);
            perf_write_misses <= perf_write_misses + `PERF_CTR_BITS'(perf_write_miss_per_cycle);
            perf_mshr_stalls  <= perf_mshr_stalls  + `PERF_CTR_BITS'(perf_mshr_stall_per_cycle);
            perf_mem_stalls   <= perf_mem_stalls   + `PERF_CTR_BITS'(perf_mem_stall_per_cycle);
            perf_cresp_stalls  <= perf_cresp_stalls  + `PERF_CTR_BITS'(perf_cresp_stall_per_cycle);
        end
    end

    assign cache_perf.reads        = perf_core_reads;
    assign cache_perf.writes       = perf_core_writes;
    assign cache_perf.read_misses  = perf_read_misses;
    assign cache_perf.write_misses = perf_write_misses;
    assign cache_perf.bank_stalls  = perf_collisions;
    assign cache_perf.mshr_stalls  = perf_mshr_stalls;
    assign cache_perf.mem_stalls   = perf_mem_stalls;
    assign cache_perf.cresp_stalls  = perf_cresp_stalls;
`endif

endmodule
