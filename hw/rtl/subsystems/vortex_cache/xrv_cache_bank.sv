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


module xrv_cache_bank #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID       = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter BANK_ID_P                 = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_DEFAULT_PARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    // Core Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter CRSQ_SIZE_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Miss Reserv Queue Knob
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_SIZE_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Request Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MREQ_SIZE_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MRSQ_SIZE_P               = 4,
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
    parameter REPL_POLICY               = `CACHE_REPL_CYCLIC,
    ////////////////////////////////////////////////////////////////////////////////
    // Request debug identifier
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P              = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // core request tag size
    ////////////////////////////////////////////////////////////////////////////////
    parameter TAG_WIDTH_P               = UUID_WIDTH_P + 1,
    ////////////////////////////////////////////////////////////////////////////////
    // core request flags
    ////////////////////////////////////////////////////////////////////////////////
    parameter FLAGS_WIDTH_P               = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Core response output register
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_OUT_REG              = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request output register
    ////////////////////////////////////////////////////////////////////////////////
    parameter MEM_OUT_REG               = 0,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_ADDR_WIDTH_LP        = $clog2(MSHR_SIZE_P),
    parameter MEM_TAG_WIDTH_LP        = UUID_WIDTH_P + MSHR_ADDR_WIDTH_LP,
    parameter REQ_SEL_WIDTH_LP          = `XM_UP(CACHE_REQ_SEL_BITS_LP),
    parameter WORD_SEL_WIDTH_LP         = `XM_UP(CACHE_WORD_SEL_BITS_LP)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     clk_i,
    input logic                                     rst_i,
    ////////////////////////////////////////////////////////////////////////////////
`ifdef PERF_ENABLE
    output logic                                    perf_read_miss_o,
    output logic                                    perf_write_miss_o,
    output logic                                    perf_mshr_stall_o,
`endif
    ////////////////////////////////////////////////////////////////////////////////
    // Core Request
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     core_req_vld_i,
    input logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]      core_req_addr_i,
    input logic                                     core_req_rw_i,         // write enable
    input logic [WORD_SEL_WIDTH_LP-1:0]             core_req_wsel_i,       // select the word in a cacheline, e.g. word size = 4 bytes, cacheline size = 64 bytes, it should have log(64/4)= 4 bits
    input logic [WORD_SIZE_P-1:0]                   core_req_be_i,     // which bytes in data to write
    input logic [CACHE_WORD_WIDTH_LP-1:0]           core_req_data_i,       // data to be written
    input logic [TAG_WIDTH_P-1:0]                   core_req_tag_i,        // identifier of the request (request id)
    input logic [REQ_SEL_WIDTH_LP-1:0]              core_req_idx_i,        // index of the request in the core request array
    input logic [`XM_UP(FLAGS_WIDTH_P)-1:0]           core_req_flags_i,
    output logic                                    core_req_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Core Response
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                    core_resp_vld_o,
    output logic [CACHE_WORD_WIDTH_LP-1:0]          core_resp_data_o,
    output logic [TAG_WIDTH_P-1:0]                  core_resp_tag_o,
    output logic [REQ_SEL_WIDTH_LP-1:0]             core_resp_idx_o,
    input  logic                                    core_resp_rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                    mem_req_vld_o,
    output logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]     mem_req_addr_o,
    output logic                                    mem_req_rw_o,
    output logic [LINE_SIZE_P-1:0]                  mem_req_be_o,
    output logic [CACHE_LINE_WIDTH_LP-1:0]          mem_req_data_o,
    output logic [MEM_TAG_WIDTH_LP-1:0]           mem_req_tag_o,
    output logic [`XM_UP(FLAGS_WIDTH_P)-1:0]          mem_req_flags_o,
    input  logic                                    mem_req_rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory response
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     mem_resp_vld_i,
    input logic [CACHE_LINE_WIDTH_LP-1:0]           mem_resp_data_i,
    input logic [MEM_TAG_WIDTH_LP-1:0]            mem_resp_tag_i,
    output logic                                    mem_resp_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Cache flush
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     flush_begin_i,
    input logic [`XM_UP(UUID_WIDTH_P)-1:0]          flush_uuid_i,
    output logic                                    flush_end_o
);

    localparam PIPELINE_STAGES = 2;

`IGNORE_UNUSED_BEGIN
    logic [`XM_UP(UUID_WIDTH_P)-1:0] req_uuid_sel, req_uuid_st0, req_uuid_st1;
`IGNORE_UNUSED_END

    logic                                   cresp_queue_stall;
    logic                                   mshr_alm_full;
    logic                                   mreq_queue_empty;
    logic                                   mreq_queue_alm_full;

    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]    mem_resp_addr;

    logic                                   replay_vld;
    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]    replay_addr;
    logic                                   replay_rw;
    logic [WORD_SEL_WIDTH_LP-1:0]           replay_wsel;
    logic [WORD_SIZE_P-1:0]                 replay_be;
    logic [CACHE_WORD_WIDTH_LP-1:0]         replay_data;
    logic [TAG_WIDTH_P-1:0]                 replay_tag;
    logic [REQ_SEL_WIDTH_LP-1:0]            replay_idx;
    logic [MSHR_ADDR_WIDTH_LP-1:0]          replay_id;
    logic                                   replay_rdy;


    logic                                   vld_sel, vld_st0, vld_st1;
    logic                                   is_init_st0;
    logic                                   is_creq_st0, is_creq_st1;
    logic                                   is_fill_st0, is_fill_st1;
    logic                                   is_flush_st0, is_flush_st1;
    logic [CACHE_WAY_SEL_WIDTH_LP-1:0]      flush_way_st0, evict_way_st0;
    logic [CACHE_WAY_SEL_WIDTH_LP-1:0]      way_idx_st0, way_idx_st1;

    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]    addr_sel, addr_st0, addr_st1;
    logic [CACHE_LINE_SEL_BITS_LP-1:0]      line_idx_st0, line_idx_st1;
    logic [CACHE_TAG_SEL_BITS_LP-1:0]       line_tag_st0, line_tag_st1;
    logic [CACHE_TAG_SEL_BITS_LP-1:0]       evict_tag_st0, evict_tag_st1;
    logic                                   rw_sel, rw_st0, rw_st1;
    logic [WORD_SEL_WIDTH_LP-1:0]           word_idx_sel, word_idx_st0, word_idx_st1;
    logic [WORD_SIZE_P-1:0]                 be_sel, be_st0, be_st1;
    logic [REQ_SEL_WIDTH_LP-1:0]            req_idx_sel, req_idx_st0, req_idx_st1;
    logic [TAG_WIDTH_P-1:0]                 tag_sel, tag_st0, tag_st1;
    logic [CACHE_WORD_WIDTH_LP-1:0]         write_word_st0, write_word_st1;
    logic [CACHE_LINE_WIDTH_LP-1:0]         data_sel, data_st0, data_st1;
    logic [MSHR_ADDR_WIDTH_LP-1:0]          mshr_id_st0, mshr_id_st1;
    logic [MSHR_ADDR_WIDTH_LP-1:0]          replay_id_st0;
    logic                                   is_dirty_st0, is_dirty_st1;
    logic                                   is_replay_st0, is_replay_st1;
    logic                                   is_hit_st0, is_hit_st1;
    logic [`XM_UP(FLAGS_WIDTH_P)-1:0]         flags_sel, flags_st0, flags_st1;
    logic                                   mshr_pending_st0, mshr_pending_st1;
    logic [MSHR_ADDR_WIDTH_LP-1:0]          mshr_previd_st0, mshr_previd_st1;
    logic                                   mshr_empty;

    logic flush_vld;
    logic init_vld;
    logic [CACHE_LINE_SEL_BITS_LP-1:0] flush_sel;
    logic [CACHE_WAY_SEL_WIDTH_LP-1:0] flush_way;
    logic flush_rdy;

    // ensure we have no pending memory request in the bank
    logic no_pending_req = ~vld_st0 && ~vld_st1 && mreq_queue_empty;

    xrv_bank_flush #(
        .BANK_ID_P              (BANK_ID_P),
        .LINE_SIZE_P            (LINE_SIZE_P),
        .NUM_BANKS_P            (NUM_BANKS_P),
        .NUM_WAYS_P             (NUM_WAYS_P),
        .HAS_WRITEBACK_P        (HAS_WRITEBACK_P)
    ) flush_unit (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .flush_begin            (flush_begin_i),
        .flush_end              (flush_end_o),
        .flush_init             (init_vld),
        .flush_vld              (flush_vld),
        .flush_line             (flush_sel),
        .flush_way              (flush_way),
        .flush_rdy              (flush_rdy),
        .mshr_empty             (mshr_empty),
        .bank_empty             (no_pending_req)
    );

    logic pipe_stall = cresp_queue_stall;

    // inputs arbitration:
    // mshr replay has highest priority to maximize utilization since there is no miss.
    // handle memory responses next to prevent deadlock with potential memory request from a miss.
    // flush has precedence over core requests to ensure that the cache is in a consistent state.
    logic replay_grant = ~init_vld;
    logic replay_enable = replay_grant && replay_vld;

    logic fill_grant  = ~init_vld && ~replay_enable;
    logic fill_enable = fill_grant && mem_resp_vld_i;

    logic flush_grant  = ~init_vld && ~replay_enable && ~fill_enable;
    logic flush_enable = flush_grant && flush_vld;

    logic creq_grant  = ~init_vld && ~replay_enable && ~fill_enable && ~flush_enable;
    logic creq_enable = creq_grant && core_req_vld_i;

    assign replay_rdy = replay_grant
                       && ~(!HAS_WRITEBACK_P && replay_rw && mreq_queue_alm_full) // needed for writethrough
                       && ~pipe_stall;

    assign mem_resp_rdy_o = fill_grant
                        && ~(HAS_WRITEBACK_P && mreq_queue_alm_full) // needed for writeback
                        && ~pipe_stall;

    assign flush_rdy = flush_grant
                      && ~(HAS_WRITEBACK_P && mreq_queue_alm_full) // needed for writeback
                      && ~pipe_stall;

    assign core_req_rdy_o = creq_grant
                         && ~mreq_queue_alm_full // needed for fill requests
                         && ~mshr_alm_full // needed for mshr allocation
                         && ~pipe_stall;

    logic init_fire     = init_vld;
    logic replay_fire   = replay_vld && replay_rdy;
    logic mem_resp_fire  = mem_resp_vld_i && mem_resp_rdy_o;
    logic flush_fire    = flush_vld && flush_rdy;
    logic core_req_fire = core_req_vld_i && core_req_rdy_o;

    logic [MSHR_ADDR_WIDTH_LP-1:0] mem_resp_id = mem_resp_tag_i[MSHR_ADDR_WIDTH_LP-1:0];

    logic [TAG_WIDTH_P-1:0] mem_resp_tag_s;
    if (TAG_WIDTH_P > MEM_TAG_WIDTH_LP) begin : g_mem_resp_tag_s_pad
        assign mem_resp_tag_s = {mem_resp_tag_i, (TAG_WIDTH_P-MEM_TAG_WIDTH_LP)'(1'b0)};
    end else begin : g_mem_resp_tag_s_cut
        assign mem_resp_tag_s = mem_resp_tag_i[MEM_TAG_WIDTH_LP-1 -: TAG_WIDTH_P];
        `XM_UNUSED_VAR (mem_resp_tag_i)
    end

    logic [TAG_WIDTH_P-1:0] flush_tag;
    if (UUID_WIDTH_P != 0) begin : g_flush_tag_uuid
        assign flush_tag = {flush_uuid_i, (TAG_WIDTH_P-UUID_WIDTH_P)'(1'b0)};
    end else begin : g_flush_tag_0
        `XM_UNUSED_VAR (flush_uuid_i)
        assign flush_tag = '0;
    end

    assign vld_sel   = init_fire || replay_fire || mem_resp_fire || flush_fire || core_req_fire;
    assign rw_sel      = replay_vld ? replay_rw : core_req_rw_i;
    assign be_sel  = replay_vld ? replay_be : core_req_be_i;
    assign addr_sel    = (init_vld | flush_vld) ? CACHE_LINE_ADDR_WIDTH_LP'(flush_sel) :
                            (replay_vld ? replay_addr : (mem_resp_vld_i ? mem_resp_addr : core_req_addr_i));
    assign word_idx_sel= replay_vld ? replay_wsel : core_req_wsel_i;
    assign req_idx_sel = replay_vld ? replay_idx : core_req_idx_i;
    assign tag_sel     = (init_vld | flush_vld) ? (flush_vld ? flush_tag : '0) :
                            (replay_vld ? replay_tag : (mem_resp_vld_i ? mem_resp_tag_s : core_req_tag_i));
    assign flags_sel   = core_req_vld_i ? core_req_flags_i : '0;

    if (IS_WRITEABLE_P) begin : g_data_sel
        for (genvar i = 0; i < CACHE_LINE_WIDTH_LP; ++i) begin : g_i
            if (i < CACHE_WORD_WIDTH_LP) begin : g_lo
                assign data_sel[i] = replay_vld ? replay_data[i] : (mem_resp_vld_i ? mem_resp_data_i[i] : core_req_data_i[i]);
            end else begin : g_hi
                assign data_sel[i] = mem_resp_data_i[i]; // only the memory response fills the upper words of data_sel
            end
        end
    end else begin : g_data_sel_ro
        assign data_sel = mem_resp_data_i;
        `XM_UNUSED_VAR (core_req_data_i)
        `XM_UNUSED_VAR (replay_data)
    end

    if (UUID_WIDTH_P != 0) begin : g_req_uuid_sel
        assign req_uuid_sel = tag_sel[TAG_WIDTH_P-1 -: UUID_WIDTH_P];
    end else begin : g_req_uuid_sel_0
        assign req_uuid_sel = '0;
    end

    logic is_init_sel   = init_vld;
    logic is_creq_sel   = creq_enable || replay_enable;
    logic is_fill_sel   = fill_enable;
    logic is_flush_sel  = flush_enable;
    logic is_replay_sel = replay_enable;

    xrv_pipe_register #(
        .DATA_WIDTH_P   (1 + 1 + 1 + 1 + 1 + 1 + `XM_UP(FLAGS_WIDTH_P) + CACHE_WAY_SEL_WIDTH_LP + CACHE_LINE_ADDR_WIDTH_LP + CACHE_LINE_WIDTH_LP + 1 + WORD_SIZE_P + WORD_SEL_WIDTH_LP + REQ_SEL_WIDTH_LP + TAG_WIDTH_P + MSHR_ADDR_WIDTH_LP),
        .RESET_WIDTH_P  (1)
    ) pipe_reg0 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (~pipe_stall),
        .data_i     ({vld_sel, is_init_sel, is_fill_sel, is_flush_sel, is_creq_sel, is_replay_sel, flags_sel, flush_way,     addr_sel, data_sel, rw_sel, be_sel, word_idx_sel, req_idx_sel, tag_sel, replay_id}),
        .data_o     ({vld_st0, is_init_st0, is_fill_st0, is_flush_st0, is_creq_st0, is_replay_st0, flags_st0, flush_way_st0, addr_st0, data_st0, rw_st0, be_st0, word_idx_st0, req_idx_st0, tag_st0, replay_id_st0})
    );

    if (UUID_WIDTH_P != 0) begin : g_req_uuid_st0
        assign req_uuid_st0 = tag_st0[TAG_WIDTH_P-1 -: UUID_WIDTH_P];
    end else begin : g_req_uuid_st0_0
        assign req_uuid_st0 = '0;
    end

    logic is_read_st0  = is_creq_st0 && ~rw_st0;
    logic is_write_st0 = is_creq_st0 && rw_st0;

    logic do_init_st0  = vld_st0 && is_init_st0;
    logic do_flush_st0 = vld_st0 && is_flush_st0;
    logic do_read_st0  = vld_st0 && is_read_st0;
    logic do_write_st0 = vld_st0 && is_write_st0;
    logic do_fill_st0  = vld_st0 && is_fill_st0;

    logic is_read_st1  = is_creq_st1 && ~rw_st1;
    logic is_write_st1 = is_creq_st1 && rw_st1;

    logic do_read_st1  = vld_st1 && is_read_st1;
    logic do_write_st1 = vld_st1 && is_write_st1;

    assign line_idx_st0 = addr_st0[CACHE_LINE_SEL_BITS_LP-1:0];
    assign line_tag_st0 = `CACHE_LINE_ADDR_TAG(addr_st0);

    assign write_word_st0 = data_st0[CACHE_WORD_WIDTH_LP-1:0];

    logic do_lookup_st0 = do_read_st0 || do_write_st0;
    logic do_lookup_st1 = do_read_st1 || do_write_st1;

    logic [CACHE_WAY_SEL_WIDTH_LP-1:0] victim_way_st0;
    logic [NUM_WAYS_P-1:0] tag_matches_st0;

    ////////////////////////////////////////////////////////////////////////////////
    // Replacement policy
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_repl #(
        .LINE_SIZE_P        (LINE_SIZE_P),
        .NUM_BANKS_P        (NUM_BANKS_P),
        .NUM_WAYS_P         (NUM_WAYS_P),
        .REPL_POLICY        (REPL_POLICY)
    ) cache_repl (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .stall              (pipe_stall),
        .hit_vld            (do_lookup_st1 && is_hit_st1 && ~pipe_stall),
        .hit_line           (line_idx_st1),
        .hit_way            (way_idx_st1),
        .repl_vld           (do_fill_st0 && ~pipe_stall),
        .repl_line          (line_idx_st0),
        .repl_way           (victim_way_st0)
    );

    assign evict_way_st0 = is_fill_st0 ? victim_way_st0 : flush_way_st0;

    ////////////////////////////////////////////////////////////////////////////////
    // TAGS
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_tags #(
        .LINE_SIZE_P        (LINE_SIZE_P),
        .NUM_BANKS_P        (NUM_BANKS_P),
        .NUM_WAYS_P         (NUM_WAYS_P),
        .WORD_SIZE_P        (WORD_SIZE_P),
        .HAS_WRITEBACK_P    (HAS_WRITEBACK_P)
    ) cache_tags (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .do_init_i          (do_init_st0),
        .do_flush_i         (do_flush_st0 && ~pipe_stall),
        .do_fill_i          (do_fill_st0 && ~pipe_stall),
        .do_rd_i            (do_read_st0 && ~pipe_stall),
        .do_wr_i            (do_write_st0 && ~pipe_stall),
        .line_idx_i         (line_idx_st0),
        .line_tag_i         (line_tag_st0),
        .evict_way_i        (evict_way_st0),
        ////////////////////////////////////////////////////////////////////////////////
        .tag_matches_o      (tag_matches_st0),
        .evict_dirty_o      (is_dirty_st0),
        .evict_tag_o        (evict_tag_st0)
    );

    logic [CACHE_WAY_SEL_WIDTH_LP-1:0] hit_idx_st0;
    xrv_onehot_encoder #(
        .N (NUM_WAYS_P)
    ) way_idx_enc (
        .data_i         (tag_matches_st0),
        .data_o         (hit_idx_st0),
        `XM_UNUSED_PIN  (vld_o)
    );

    assign way_idx_st0 = is_creq_st0 ? hit_idx_st0 : evict_way_st0;
    assign is_hit_st0 = (| tag_matches_st0);

    logic [MSHR_ADDR_WIDTH_LP-1:0] mshr_alloc_id_st0;
    assign mshr_id_st0 = is_replay_st0 ? replay_id_st0 : mshr_alloc_id_st0;

    xrv_pipe_register #(
        .DATA_WIDTH_P  (1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + `XM_UP(FLAGS_WIDTH_P) + CACHE_WAY_SEL_WIDTH_LP + CACHE_TAG_SEL_BITS_LP + CACHE_TAG_SEL_BITS_LP + CACHE_LINE_SEL_BITS_LP + CACHE_LINE_WIDTH_LP + WORD_SIZE_P + WORD_SEL_WIDTH_LP + REQ_SEL_WIDTH_LP + TAG_WIDTH_P + MSHR_ADDR_WIDTH_LP + MSHR_ADDR_WIDTH_LP + 1),
        .RESET_WIDTH_P (1)
    ) pipe_reg1 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (~pipe_stall),
        .data_i     ({vld_st0, is_fill_st0, is_flush_st0, is_creq_st0, is_replay_st0, is_dirty_st0, is_hit_st0, rw_st0, flags_st0, way_idx_st0, evict_tag_st0, line_tag_st0, line_idx_st0, data_st0, be_st0, word_idx_st0, req_idx_st0, tag_st0, mshr_id_st0, mshr_previd_st0, mshr_pending_st0}),
        .data_o     ({vld_st1, is_fill_st1, is_flush_st1, is_creq_st1, is_replay_st1, is_dirty_st1, is_hit_st1, rw_st1, flags_st1, way_idx_st1, evict_tag_st1, line_tag_st1, line_idx_st1, data_st1, be_st1, word_idx_st1, req_idx_st1, tag_st1, mshr_id_st1, mshr_previd_st1, mshr_pending_st1})
    );

    if (UUID_WIDTH_P != 0) begin : g_req_uuid_st1
        assign req_uuid_st1 = tag_st1[TAG_WIDTH_P-1 -: UUID_WIDTH_P];
    end else begin : g_req_uuid_st1_0
        assign req_uuid_st1 = '0;
    end

    assign addr_st1 = {line_tag_st1, line_idx_st1};

    // ensure mshr replay always get a hit
    `RUNTIME_ASSERT (~(vld_st1 && is_replay_st1 && ~is_hit_st1), ("%t: missed mshr replay", $time))

    assign write_word_st1 = data_st1[CACHE_WORD_WIDTH_LP-1:0];
    `XM_UNUSED_VAR (data_st1)

    logic [CACHE_WORDS_PER_LINE_LP-1:0][CACHE_WORD_WIDTH_LP-1:0] read_data_st1;
    logic [LINE_SIZE_P-1:0] evict_be_st1;

    ////////////////////////////////////////////////////////////////////////////////
    // Cache bank data storage
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_data #(
        .LINE_SIZE_P        (LINE_SIZE_P),
        .NUM_BANKS_P        (NUM_BANKS_P),
        .NUM_WAYS_P         (NUM_WAYS_P),
        .WORD_SIZE_P        (WORD_SIZE_P),
        .IS_WRITEABLE_P     (IS_WRITEABLE_P),
        .HAS_WRITEBACK_P    (HAS_WRITEBACK_P),
        .HAS_DIRTY_BYTES_P  (HAS_DIRTY_BYTES_P)
    ) cache_data (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .stall              (pipe_stall),
        .init_i             (do_init_st0),
        .do_fill_i          (do_fill_st0 && ~pipe_stall),
        .do_flush_i         (do_flush_st0 && ~pipe_stall),
        .do_rd_i            (do_read_st0 && ~pipe_stall),
        .do_wr_i            (do_write_st0 && ~pipe_stall),
        .evict_way_i        (evict_way_st0),
        .tag_matches_i      (tag_matches_st0),
        .line_idx_i         (line_idx_st0),
        .fill_data_i        (data_st0),
        .wr_word_i          (write_word_st0),
        .word_idx_i         (word_idx_st0),
        .wr_be_i            (be_st0),
        .way_idx_i          (way_idx_st1),
        .rd_data_o          (read_data_st1),
        .evict_be_o         (evict_be_st1)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // only allocate MSHR entries for non-replay core requests
    ////////////////////////////////////////////////////////////////////////////////
    logic mshr_allocate_st0 = vld_st0 && is_creq_st0 && ~is_replay_st0;
    logic mshr_finalize_st1 = vld_st1 && is_creq_st1 && ~is_replay_st1;

    ////////////////////////////////////////////////////////////////////////////////
    // release allocated mshr entry if we had a hit
    ////////////////////////////////////////////////////////////////////////////////
    logic mshr_release_st1;
    if (HAS_WRITEBACK_P) begin : g_mshr_release
        assign mshr_release_st1 = is_hit_st1;
    end else begin : g_mshr_release_ro
        ////////////////////////////////////////////////////////////////////////////////
        // we need to keep missed write requests in MSHR if there is already a pending entry to the same address.
        // this ensures that missed write requests are replayed locally in case a pending fill arrives without the write content.
        // this can happen when writes are sent to memory late, when a related fill was already in flight.
        ////////////////////////////////////////////////////////////////////////////////
        assign mshr_release_st1 = is_hit_st1 || (rw_st1 && ~mshr_pending_st1);
    end

    logic mshr_release_fire = mshr_finalize_st1 && mshr_release_st1 && ~pipe_stall;

    logic [1:0] mshr_dequeue;
    `POP_COUNT(mshr_dequeue, {replay_fire, mshr_release_fire});

    xrv_pending_size #(
        .SIZE_P         (MSHR_SIZE_P),
        .DECR_WIDTH_P   (2)
    ) mshr_pending_size (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .incr           (core_req_fire),
        .decr           (mshr_dequeue),
        .empty          (mshr_empty),
        `XM_UNUSED_PIN  (alm_empty),
        .full           (mshr_alm_full),
        `XM_UNUSED_PIN  (alm_full),
        `XM_UNUSED_PIN  (size)
    );

    xrv_cache_mshr #(
        .INSTANCE_ID            (`SFORMATF(("%s-mshr", INSTANCE_ID))),
        .BANK_ID_P              (BANK_ID_P),
        .LINE_SIZE_P            (LINE_SIZE_P),
        .NUM_BANKS_P            (NUM_BANKS_P),
        .MSHR_SIZE_P            (MSHR_SIZE_P),
        .HAS_WRITEBACK_P        (HAS_WRITEBACK_P),
        .UUID_WIDTH_P           (UUID_WIDTH_P),
        .DATA_WIDTH             (WORD_SEL_WIDTH_LP + WORD_SIZE_P + CACHE_WORD_WIDTH_LP + TAG_WIDTH_P + REQ_SEL_WIDTH_LP)
    ) cache_mshr (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .deq_req_uuid           (req_uuid_sel),
        .alc_req_uuid           (req_uuid_st0),
        .fin_req_uuid           (req_uuid_st1),
        ////////////////////////////////////////////////////////////////////////////////
        // memory fill
        ////////////////////////////////////////////////////////////////////////////////
        .fill_vld               (mem_resp_fire),
        .fill_id                (mem_resp_id),
        .fill_addr              (mem_resp_addr),
        ////////////////////////////////////////////////////////////////////////////////
        // dequeue
        ////////////////////////////////////////////////////////////////////////////////
        .dequeue_vld            (replay_vld),
        .dequeue_addr           (replay_addr),
        .dequeue_rw             (replay_rw),
        .dequeue_data           ({replay_wsel, replay_be, replay_data, replay_tag, replay_idx}),
        .dequeue_id             (replay_id),
        .dequeue_rdy            (replay_rdy),
        ////////////////////////////////////////////////////////////////////////////////
        // allocate
        ////////////////////////////////////////////////////////////////////////////////
        .allocate_vld           (mshr_allocate_st0 && ~pipe_stall),
        .allocate_addr          (addr_st0),
        .allocate_rw            (rw_st0),
        .allocate_data          ({word_idx_st0, be_st0, write_word_st0, tag_st0, req_idx_st0}),
        .allocate_id            (mshr_alloc_id_st0),
        .allocate_pending       (mshr_pending_st0),
        .allocate_previd        (mshr_previd_st0),
        `XM_UNUSED_PIN          (allocate_rdy_o),
        ////////////////////////////////////////////////////////////////////////////////
        // finalize
        ////////////////////////////////////////////////////////////////////////////////
        .finalize_vld           (mshr_finalize_st1 && ~pipe_stall),
        .finalize_is_release    (mshr_release_st1),
        .finalize_is_pending    (mshr_pending_st1),
        .finalize_id            (mshr_id_st1),
        .finalize_previd        (mshr_previd_st1)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // schedule core response
    ////////////////////////////////////////////////////////////////////////////////
    logic cresp_queue_vld, cresp_queue_rdy;
    logic [CACHE_WORD_WIDTH_LP-1:0] cresp_queue_data;
    logic [REQ_SEL_WIDTH_LP-1:0] cresp_queue_idx;
    logic [TAG_WIDTH_P-1:0] cresp_queue_tag;

    assign cresp_queue_vld = do_read_st1 && is_hit_st1;
    assign cresp_queue_idx   = req_idx_st1;
    assign cresp_queue_data  = read_data_st1[word_idx_st1];
    assign cresp_queue_tag   = tag_st1;

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (TAG_WIDTH_P + CACHE_WORD_WIDTH_LP + REQ_SEL_WIDTH_LP),
        .SIZE_P         (CRSQ_SIZE_P),
        .OUT_REG        (CORE_OUT_REG)
    ) core_resp_queue (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .vld_i          (cresp_queue_vld),
        .rdy_i          (cresp_queue_rdy),
        .data_i         ({cresp_queue_tag, cresp_queue_data, cresp_queue_idx}),
        .data_o         ({core_resp_tag_o, core_resp_data_o, core_resp_idx_o}),
        .vld_o          (core_resp_vld_o),
        .rdy_o          (core_resp_rdy_i)
    );

    assign cresp_queue_stall = cresp_queue_vld && ~cresp_queue_rdy;

    // schedule memory request

    logic mreq_queue_push, mreq_queue_pop;
    logic [CACHE_LINE_WIDTH_LP-1:0] mreq_queue_data;
    logic [LINE_SIZE_P-1:0] mreq_queue_be;
    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0] mreq_queue_addr;
    logic [MEM_TAG_WIDTH_LP-1:0] mreq_queue_tag;
    logic mreq_queue_rw;
    logic [`XM_UP(FLAGS_WIDTH_P)-1:0] mreq_queue_flags;

    logic is_fill_or_flush_st1 = is_fill_st1 || (is_flush_st1 && HAS_WRITEBACK_P);
    logic do_fill_or_flush_st1 = vld_st1 && is_fill_or_flush_st1;
    logic do_writeback_st1 = do_fill_or_flush_st1 && is_dirty_st1;
    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0] evict_addr_st1 = {evict_tag_st1, line_idx_st1};

    if (IS_WRITEABLE_P) begin : g_mreq_queue
        if (HAS_WRITEBACK_P) begin : g_wb
            if (HAS_DIRTY_BYTES_P) begin : g_dirty_bytes
                // ensure dirty bytes match the tag info
                logic has_dirty_bytes = (| evict_be_st1);
                `RUNTIME_ASSERT (~do_fill_or_flush_st1 || (is_dirty_st1 == has_dirty_bytes), ("%t: missmatch dirty bytes: dirty_line=%b, dirty_bytes=%b, addr=0x%0h", $time, is_dirty_st1, has_dirty_bytes, `CACHE_BANK_TO_FULL_ADDR(addr_st1, BANK_ID_P)))
            end
            // issue a fill request on a read/write miss
            // issue a writeback on a dirty line eviction
            assign mreq_queue_push = ((do_lookup_st1 && ~is_hit_st1 && ~mshr_pending_st1)
                                   || do_writeback_st1)
                                  && ~pipe_stall;
            assign mreq_queue_addr = is_fill_or_flush_st1 ? evict_addr_st1 : addr_st1;
            assign mreq_queue_rw = is_fill_or_flush_st1;
            assign mreq_queue_data = read_data_st1;
            assign mreq_queue_be = is_fill_or_flush_st1 ? evict_be_st1 : '1;
            `XM_UNUSED_VAR (write_word_st1)
            `XM_UNUSED_VAR (be_st1)
        end else begin : g_wt
            logic [LINE_SIZE_P-1:0] line_be;
            xrv_demux #(
                .DATA_WIDTH_P   (WORD_SIZE_P),
                .N              (CACHE_WORDS_PER_LINE_LP)
            ) be_demux (
                .sel_i          (word_idx_st1),
                .data_i         (be_st1),
                .data_o         (line_be)
            );
            // issue a fill request on a read miss
            // issue a memory write on a write request
            assign mreq_queue_push = ((do_read_st1 && ~is_hit_st1 && ~mshr_pending_st1)
                                  || do_write_st1)
                                  && ~pipe_stall;
            assign mreq_queue_addr = addr_st1;
            assign mreq_queue_rw = rw_st1;
            assign mreq_queue_data = {CACHE_WORDS_PER_LINE_LP{write_word_st1}};
            assign mreq_queue_be = rw_st1 ? line_be : '1;
            `XM_UNUSED_VAR (is_fill_or_flush_st1)
            `XM_UNUSED_VAR (do_writeback_st1)
            `XM_UNUSED_VAR (evict_addr_st1)
            `XM_UNUSED_VAR (evict_be_st1)
        end
    end else begin : g_mreq_queue_ro
        // issue a fill request on a read miss
        assign mreq_queue_push = (do_read_st1 && ~is_hit_st1 && ~mshr_pending_st1)
                              && ~pipe_stall;
        assign mreq_queue_addr = addr_st1;
        assign mreq_queue_rw = 0;
        assign mreq_queue_data = '0;
        assign mreq_queue_be = '1;
        `XM_UNUSED_VAR (do_writeback_st1)
        `XM_UNUSED_VAR (evict_addr_st1)
        `XM_UNUSED_VAR (evict_be_st1)
        `XM_UNUSED_VAR (write_word_st1)
        `XM_UNUSED_VAR (be_st1)
    end

    if (UUID_WIDTH_P != 0) begin : g_mreq_queue_tag_uuid
        assign mreq_queue_tag = {req_uuid_st1, mshr_id_st1};
    end else begin : g_mreq_queue_tag
        assign mreq_queue_tag = mshr_id_st1;
    end

    assign mreq_queue_pop = mem_req_vld_o && mem_req_rdy_i;
    assign mreq_queue_flags = flags_st1;

    xrv_fifo_queue #(
        .DATA_WIDTH_P   (1 + CACHE_LINE_ADDR_WIDTH_LP + LINE_SIZE_P + CACHE_LINE_WIDTH_LP + MEM_TAG_WIDTH_LP + `XM_UP(FLAGS_WIDTH_P)),
        .DEPTH_P        (MREQ_SIZE_P),
        .ALM_FULL_P     (MREQ_SIZE_P - PIPELINE_STAGES),
        .OUT_REG        (MEM_OUT_REG)
    ) mem_req_queue (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .push           (mreq_queue_push),
        .pop            (mreq_queue_pop),
        .data_i         ({mreq_queue_rw, mreq_queue_addr, mreq_queue_be, mreq_queue_data, mreq_queue_tag, mreq_queue_flags}),
        .data_o         ({mem_req_rw_o, mem_req_addr_o, mem_req_be_o, mem_req_data_o, mem_req_tag_o, mem_req_flags_o}),
        .empty          (mreq_queue_empty),
        .alm_full       (mreq_queue_alm_full),
        `XM_UNUSED_PIN  (full),
        `XM_UNUSED_PIN  (alm_empty),
        `XM_UNUSED_PIN  (size)
    );

    assign mem_req_vld_o = ~mreq_queue_empty;

    `XM_UNUSED_VAR (do_lookup_st0)

///////////////////////////////////////////////////////////////////////////////

`ifdef PERF_ENABLE
    assign perf_read_miss  = do_read_st1 && ~is_hit_st1;
    assign perf_write_miss = do_write_st1 && ~is_hit_st1;
    assign perf_mshr_stall = mshr_alm_full;
`endif

`ifdef DBG_TRACE_CACHE
    logic cresp_queue_fire = cresp_queue_vld && cresp_queue_rdy;
    logic input_stall = (replay_vld || mem_resp_vld || core_req_vld || flush_vld)
                   && ~(replay_fire || mem_resp_fire || core_req_fire || flush_fire);

    logic [XLEN_P-1:0] mem_resp_full_addr = `CACHE_BANK_TO_FULL_ADDR(mem_resp_addr, BANK_ID_P);
    logic [XLEN_P-1:0] replay_full_addr = `CACHE_BANK_TO_FULL_ADDR(replay_addr, BANK_ID_P);
    logic [XLEN_P-1:0] core_req_full_addr = `CACHE_BANK_TO_FULL_ADDR(core_req_addr_i, BANK_ID_P);
    logic [XLEN_P-1:0] full_addr_st0 = `CACHE_BANK_TO_FULL_ADDR(addr_st0, BANK_ID_P);
    logic [XLEN_P-1:0] full_addr_st1 = `CACHE_BANK_TO_FULL_ADDR(addr_st1, BANK_ID_P);
    logic [XLEN_P-1:0] mreq_queue_full_addr = `CACHE_BANK_TO_FULL_ADDR(mreq_queue_addr, BANK_ID_P);

    always @(posedge clk_i) begin
        if (input_stall || pipe_stall) begin
            `TRACE(4, ("%t: *** %s stall: crsq=%b, mreq=%b, mshr=%b\n", $time, INSTANCE_ID,
                cresp_queue_stall, mreq_queue_alm_full, mshr_alm_full))
        end
        if (mem_resp_fire) begin
            `TRACE(2, ("%t: %s fill-resp: addr=0x%0h, mshr_id=%0d, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                mem_resp_full_addr, mem_resp_id, mem_resp_data, req_uuid_sel))
        end
        if (replay_fire) begin
            `TRACE(2, ("%t: %s mshr-pop: addr=0x%0h, tag=0x%0h, req_idx=%0d (#%0d)\n", $time, INSTANCE_ID,
                replay_full_addr, replay_tag, replay_idx, req_uuid_sel))
        end
        if (core_req_fire) begin
            if (core_req_rw) begin
                `TRACE(2, ("%t: %s core-wr-req: addr=0x%0h, tag=0x%0h, req_idx=%0d, be=0x%h, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                    core_req_full_addr, core_req_tag, core_req_idx, core_req_be_i, core_req_data, req_uuid_sel))
            end else begin
                `TRACE(2, ("%t: %s core-rd-req: addr=0x%0h, tag=0x%0h, req_idx=%0d (#%0d)\n", $time, INSTANCE_ID,
                    core_req_full_addr, core_req_tag, core_req_idx, req_uuid_sel))
            end
        end
        if (do_init_st0) begin
            `TRACE(3, ("%t: %s tags-init: addr=0x%0h, line=%0d\n", $time, INSTANCE_ID, full_addr_st0, line_idx_st0))
        end
        if (do_fill_st0 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s tags-fill: addr=0x%0h, way=%0d, line=%0d, dirty=%b (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st0, evict_way_st0, line_idx_st0, is_dirty_st0, req_uuid_st0))
        end
        if (do_flush_st0 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s tags-flush: addr=0x%0h, way=%0d, line=%0d, dirty=%b (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st0, evict_way_st0, line_idx_st0, is_dirty_st0, req_uuid_st0))
        end
        if (do_lookup_st0 && ~pipe_stall) begin
            if (is_hit_st0) begin
                `TRACE(3, ("%t: %s tags-hit: addr=0x%0h, rw=%b, way=%0d, line=%0d, tag=0x%0h (#%0d)\n", $time, INSTANCE_ID,
                    full_addr_st0, rw_st0, way_idx_st0, line_idx_st0, line_tag_st0, req_uuid_st0))
            end else begin
                `TRACE(3, ("%t: %s tags-miss: addr=0x%0h, rw=%b, way=%0d, line=%0d, tag=0x%0h (#%0d)\n", $time, INSTANCE_ID,
                    full_addr_st0, rw_st0, way_idx_st0, line_idx_st0, line_tag_st0, req_uuid_st0))
            end
        end
        if (do_fill_st0 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s data-fill: addr=0x%0h, way=%0d, line=%0d, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st0, way_idx_st0, line_idx_st0, data_st0, req_uuid_st0))
        end
        if (do_flush_st0 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s data-flush: addr=0x%0h, way=%0d, line=%0d (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st0, way_idx_st0, line_idx_st0, req_uuid_st0))
        end
        if (do_read_st1 && is_hit_st1 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s data-read: addr=0x%0h, way=%0d, line=%0d, wsel=%0d, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st1, way_idx_st1, line_idx_st1, word_idx_st1, cresp_queue_data, req_uuid_st1))
        end
        if (do_write_st1 && is_hit_st1 && ~pipe_stall) begin
            `TRACE(3, ("%t: %s data-write: addr=0x%0h, way=%0d, line=%0d, wsel=%0d, be=0x%h, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st1, way_idx_st1, line_idx_st1, word_idx_st1, be_st1, write_word_st1, req_uuid_st1))
        end
        if (cresp_queue_fire) begin
            `TRACE(2, ("%t: %s core-rd-resp: addr=0x%0h, tag=0x%0h, req_idx=%0d, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                full_addr_st1, cresp_queue_tag, cresp_queue_idx, cresp_queue_data, req_uuid_st1))
        end
        if (mreq_queue_push) begin
            if (!HAS_WRITEBACK_P && do_write_st1) begin
                `TRACE(2, ("%t: %s writethrough: addr=0x%0h, be=0x%h, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                    mreq_queue_full_addr, mreq_queue_be, mreq_queue_data, req_uuid_st1))
            end else if (HAS_WRITEBACK_P && do_writeback_st1) begin
                `TRACE(2, ("%t: %s writeback: addr=0x%0h, be=0x%h, data=0x%h (#%0d)\n", $time, INSTANCE_ID,
                    mreq_queue_full_addr, mreq_queue_be, mreq_queue_data, req_uuid_st1))
            end else begin
                `TRACE(2, ("%t: %s fill-req: addr=0x%0h, mshr_id=%0d (#%0d)\n", $time, INSTANCE_ID,
                    mreq_queue_full_addr, mshr_id_st1, req_uuid_st1))
            end
        end
    end
`endif

endmodule
