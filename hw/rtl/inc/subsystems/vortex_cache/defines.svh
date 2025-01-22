`ifndef XRV_CACHE_DEFINES_SVH
`define XRV_CACHE_DEFINES_SVH

`include "xm_macro.svh"

`define CACHE_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, uuid_width) \
        (uuid_width + `XM_CLOG2(mshr_size) + `XM_CLOG2(`XM_CDIV(num_banks, mem_ports)))

`define CACHE_BYPASS_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, tag_width) \
        (`XM_CLOG2(`XM_CDIV(num_reqs, mem_ports)) + `XM_CLOG2(line_size / word_size) + tag_width)

`define CACHE_NC_MEM_TAG_WIDTH(mshr_size, num_banks, num_reqs, mem_ports, line_size, word_size, tag_width, uuid_width) \
        (`XM_MAX(`CACHE_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, uuid_width), `CACHE_BYPASS_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, tag_width)) + 1)

`define CACHE_CLUSTER_CORE_ARB_TAG(tag_width, num_inputs, num_caches) \
        (tag_width + `XM_ARB_SEL_BITS(num_inputs, `XM_UP(num_caches)))

`define CACHE_CLUSTER_MEM_ARB_TAG(tag_width, num_caches) \
        (tag_width + `XM_ARB_SEL_BITS(`XM_UP(num_caches), 1))

`define CACHE_CLUSTER_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, num_caches, uuid_width) \
        `CACHE_CLUSTER_MEM_ARB_TAG(`CACHE_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, uuid_width), num_caches)

`define CACHE_CLUSTER_BYPASS_MEM_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, tag_width, num_inputs, num_caches) \
        `CACHE_CLUSTER_MEM_ARB_TAG(`CACHE_BYPASS_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, `CACHE_CLUSTER_CORE_ARB_TAG(tag_width, num_inputs, num_caches)), num_caches)

`define CACHE_CLUSTER_NC_MEM_TAG_WIDTH(mshr_size, num_banks, num_reqs, mem_ports, line_size, word_size, tag_width, num_inputs, num_caches, uuid_width) \
        `CACHE_CLUSTER_MEM_ARB_TAG(`CACHE_NC_MEM_TAG_WIDTH(mshr_size, num_banks, num_reqs, mem_ports, line_size, word_size, `CACHE_CLUSTER_CORE_ARB_TAG(tag_width, num_inputs, num_caches), uuid_width), num_caches)

`define CACHE_LINE_ADDR_TAG(x)     x[CACHE_LINE_ADDR_WIDTH_LP-1 :CACHE_LINE_SEL_BITS_LP]

`define CACHE_BANK_TO_FULL_ADDR(x, b) {x, (XLEN_P-$bits(x))'(b << (XLEN_P-$bits(x)-CACHE_BANK_SEL_BITS_LP))}
`define CACHE_MEM_TO_FULL_ADDR(x)     {x, (XLEN_P-$bits(x))'(0)}

`define PERF_CACHE_ADD(dst, src, count) \
    `PERF_COUNTER_ADD (dst, src, reads, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, writes, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, read_misses, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, write_misses, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, bank_stalls, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, mshr_stalls, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, mem_stalls, `PERF_CTR_BITS, count, (count > 1)) \
    `PERF_COUNTER_ADD (dst, src, cresp_stalls, `PERF_CTR_BITS, count, (count > 1))

`define CACHE_REPL_RANDOM  0
`define CACHE_REPL_CYCLIC  1
`define CACHE_REPL_PLRU    2

`define ASSIGN_XRV_CACHE_IF(dst, src) \
    assign dst.req_vld  = src.req_vld; \
    assign dst.req_data   = src.req_data; \
    assign src.req_rdy  = dst.req_rdy; \
    assign src.resp_vld  = dst.resp_vld; \
    assign src.resp_data   = dst.resp_data; \
    assign dst.resp_rdy  = src.resp_rdy

`define ASSIGN_XRV_CACHE_RO_IF(dst, src) \
    assign dst.req_vld = src.req_vld; \
    assign dst.req_data.rw = 0; \
    assign dst.req_data.addr = src.req_data.addr; \
    assign dst.req_data.data = '0; \
    assign dst.req_data.be = '1; \
    assign dst.req_data.flags = src.req_data.flags; \
    assign dst.req_data.tag = src.req_data.tag; \
    assign src.req_rdy = dst.req_rdy; \
    assign src.resp_vld = dst.resp_vld; \
    assign src.resp_data.data = dst.resp_data.data; \
    assign src.resp_data.tag = dst.resp_data.tag; \
    assign dst.resp_rdy = src.resp_rdy

`define ASSIGN_XRV_CACHE_IF_EX(dst, src, TD, TS, UUID) \
    assign dst.req_vld = src.req_vld; \
    assign dst.req_data.rw = src.req_data.rw; \
    assign dst.req_data.addr = src.req_data.addr; \
    assign dst.req_data.data = src.req_data.data; \
    assign dst.req_data.be = src.req_data.be; \
    assign dst.req_data.flags = src.req_data.flags; \
    /* verilator lint_off GENUNNAMED */ \
    if (TD != TS) begin \
        if (UUID != 0) begin \
            if (TD > TS) begin \
                assign dst.req_data.tag = {src.req_data.tag.uuid, {(TD-TS){1'b0}}, src.req_data.tag.value}; \
            end else begin \
                assign dst.req_data.tag = {src.req_data.tag.uuid, src.req_data.tag.value[TD-UUID-1:0]}; \
            end \
        end else begin \
            if (TD > TS) begin \
                assign dst.req_data.tag = {{(TD-TS){1'b0}}, src.req_data.tag}; \
            end else begin \
                assign dst.req_data.tag = src.req_data.tag[TD-1:0]; \
            end \
        end \
    end else begin \
        assign dst.req_data.tag = src.req_data.tag; \
    end \
    /* verilator lint_on GENUNNAMED */ \
    assign src.req_rdy = dst.req_rdy; \
    assign src.resp_vld = dst.resp_vld; \
    assign src.resp_data.data = dst.resp_data.data; \
    /* verilator lint_off GENUNNAMED */ \
    if (TD != TS) begin \
        if (UUID != 0) begin \
            if (TD > TS) begin \
                assign src.resp_data.tag = {dst.resp_data.tag.uuid, dst.resp_data.tag.value[TS-UUID-1:0]}; \
            end else begin \
                assign src.resp_data.tag = {dst.resp_data.tag.uuid, {(TS-TD){1'b0}}, dst.resp_data.tag.value}; \
            end \
        end else begin \
            if (TD > TS) begin \
                assign src.resp_data.tag = dst.resp_data.tag[TS-1:0]; \
            end else begin \
                assign src.resp_data.tag = {{(TS-TD){1'b0}}, dst.resp_data.tag}; \
            end \
        end \
    end else begin \
        assign src.resp_data.tag = dst.resp_data.tag; \
    end \
    /* verilator lint_on GENUNNAMED */ \
    assign dst.resp_rdy = src.resp_rdy

`define INIT_XRV_CACHE_IF(itf) \
    assign itf.req_vld = 0; \
    assign itf.req_data = '0; \
    `XM_UNUSED_VAR (itf.req_rdy) \
    `XM_UNUSED_VAR (itf.resp_vld) \
    `XM_UNUSED_VAR (itf.resp_data) \
    assign itf.resp_rdy = 0;

`define UNUSED_XRV_CACHE_IF(itf) \
    `XM_UNUSED_VAR (itf.req_vld) \
    `XM_UNUSED_VAR (itf.req_data) \
    assign itf.req_rdy = 0; \
    assign itf.resp_vld = 0; \
    assign itf.resp_data  = '0; \
    `XM_UNUSED_VAR (itf.resp_rdy)

`define XRV_CACHE_LOCALPARAMS parameter CACHE_REQ_SEL_BITS_LP = `XM_CLOG2(NUM_REQS_P), \
    parameter CACHE_WORD_WIDTH_LP = (8 * WORD_SIZE_P), \
    parameter CACHE_LINE_WIDTH_LP = (8 * LINE_SIZE_P), \
    parameter CACHE_BANK_SIZE_LP = (CACHE_SIZE_P / NUM_BANKS_P), \
    parameter CACHE_WAY_SEL_BITS_LP = `XM_CLOG2(NUM_WAYS_P), \
    parameter CACHE_WAY_SEL_WIDTH_LP = `XM_UP(CACHE_WAY_SEL_BITS_LP), \
    parameter CACHE_LINES_PER_BANK_LP = (CACHE_BANK_SIZE_LP / (LINE_SIZE_P * NUM_WAYS_P)), \
    parameter CACHE_WORDS_PER_LINE_LP = (LINE_SIZE_P / WORD_SIZE_P), \
    parameter CACHE_WORD_ADDR_WIDTH_LP = (MEM_ADDR_WIDTH_P - `XM_CLOG2(WORD_SIZE_P)), \
    parameter CACHE_MEM_ADDR_WIDTH_LP = (MEM_ADDR_WIDTH_P - `XM_CLOG2(LINE_SIZE_P)), \
    parameter CACHE_LINE_ADDR_WIDTH_LP = (CACHE_MEM_ADDR_WIDTH_LP - `XM_CLOG2(NUM_BANKS_P)), \
    parameter CACHE_WORD_SEL_BITS_LP = `XM_CLOG2(CACHE_WORDS_PER_LINE_LP), \
    parameter CACHE_WORD_SEL_ADDR_START_LP = 0, \
    parameter CACHE_WORD_SEL_ADDR_END_LP = (CACHE_WORD_SEL_ADDR_START_LP + CACHE_WORD_SEL_BITS_LP-1), \
    parameter CACHE_BANK_SEL_BITS_LP = `XM_CLOG2(NUM_BANKS_P), \
    parameter CACHE_BANK_SEL_ADDR_START_LP = (1+CACHE_WORD_SEL_ADDR_END_LP), \
    parameter CACHE_BANK_SEL_ADDR_END_LP = (CACHE_BANK_SEL_ADDR_START_LP+CACHE_BANK_SEL_BITS_LP-1), \
    parameter CACHE_LINE_SEL_BITS_LP = `XM_CLOG2(CACHE_LINES_PER_BANK_LP), \
    parameter CACHE_LINE_SEL_ADDR_START_LP = (1+CACHE_BANK_SEL_ADDR_END_LP), \
    parameter CACHE_LINE_SEL_ADDR_END_LP = (CACHE_LINE_SEL_ADDR_START_LP+CACHE_LINE_SEL_BITS_LP-1), \
    parameter CACHE_TAG_SEL_BITS_LP = (CACHE_WORD_ADDR_WIDTH_LP-1-CACHE_LINE_SEL_ADDR_END_LP), \
    parameter CACHE_TAG_SEL_ADDR_START_LP = (1+CACHE_LINE_SEL_ADDR_END_LP), \
    parameter CACHE_TAG_SEL_ADDR_END_LP = (CACHE_WORD_ADDR_WIDTH_LP-1)

`define XRV_CACHE_DEFAULT_PARAMS parameter CACHE_SIZE_P = 65536, \
    parameter NUM_REQS_P = 4, \
    parameter NUM_MEM_PORTS_P = 1, \
    parameter LINE_SIZE_P = 64, \
    parameter NUM_BANKS_P = 4, \
    parameter NUM_WAYS_P = 4, \
    parameter WORD_SIZE_P = 16


`define LMEM_ENABLED            0
`define MEM_REQ_FLAG_FLUSH      0
`define MEM_REQ_FLAG_IO         1
`define MEM_REQ_FLAG_LOCAL      2 // shoud be last since optional
`define MEM_REQ_FLAGS_WIDTH     (`MEM_REQ_FLAG_LOCAL + `LMEM_ENABLED)

`define PERF_CTR_BITS           44

`endif