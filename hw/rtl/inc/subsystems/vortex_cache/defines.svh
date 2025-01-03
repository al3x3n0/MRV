`ifndef XRV_CACHE_DEFINES_SVH
`define XRV_CACHE_DEFINES_SVH

`include "xm_macro.svh"

`define CACHE_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, uuid_width) \
        (uuid_width + `XM_CLOG2(mshr_size) + `XM_CLOG2(`XM_CDIV(num_banks, mem_ports)))

`define CACHE_BYPASS_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, tag_width) \
        (`XM_CLOG2(`XM_CDIV(num_reqs, mem_ports)) + `XM_CLOG2(line_size / word_size) + tag_width)

`define CACHE_NC_MEM_TAG_WIDTH(mshr_size, num_banks, num_reqs, mem_ports, line_size, word_size, tag_width, uuid_width) \
        (`XM_MAX(`CACHE_MEM_TAG_WIDTH(mshr_size, num_banks, mem_ports, uuid_width), `CACHE_BYPASS_TAG_WIDTH(num_reqs, mem_ports, line_size, word_size, tag_width)) + 1)

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
    assign dst.req_data.byteen = '1; \
    assign dst.req_data.flags = src.req_data.flags; \
    assign dst.req_data.tag = src.req_data.tag; \
    assign src.req_rdy = dst.req_rdy; \
    assign src.resp_vld = dst.resp_vld; \
    assign src.resp_data.data = dst.resp_data.data; \
    assign src.resp_data.tag = dst.resp_data.tag; \
    assign dst.resp_rdy = src.resp_rdy

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