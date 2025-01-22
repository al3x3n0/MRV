`ifndef XM_MACRO_SVH
`define XM_MACRO_SVH

`define STRING          string

`define XM_CLOG2(x)    $clog2(x)
`define XM_FLOG2(x)    ($clog2(x) - (((1 << $clog2(x)) > (x)) ? 1 : 0))
`define XM_LOG2UP(x)   (((x) > 1) ? $clog2(x) : 1)
`define XM_IS_POW2(x)   (((x) != 0) && (0 == ((x) & ((x) - 1))))
`define XM_IS_DIVISBLE(n, d) (((n) % (d)) == 0)

`define XM_ABS(x)      (((x) < 0) ? (-(x)) : (x));
`define XM_MIN(x, y)   (((x) < (y)) ? (x) : (y))
`define XM_MAX(x, y)   (((x) > (y)) ? (x) : (y))

`define XM_CLAMP(x, lo, hi)   (((x) > (hi)) ? (hi) : (((x) < (lo)) ? (lo) : (x)))

`define XM_UP(x)       (((x) > 0) ? (x) : 1)

`define XM_CDIV(n,d)   ((n + d - 1) / (d))

// size(x): 0 -> 0, 1 -> 1, 2 -> 2, 3 -> 2, 4-> 2, 5 -> 2
`define XM_TO_OUT_BUF_SIZE(s)    `XM_MIN(s & 7, 2)

// reg(x): 0 -> 0, 1 -> 1, 2 -> 0, 3 -> 1, 4 -> 2, 5 > 3
`define XM_TO_OUT_BUF_REG(s)     (((s & 7) < 2) ? (s & 7) : ((s & 7) - 2))

// lut(x): (x & 8) != 0
`define XM_TO_OUT_BUF_LUTRAM(s)  ((s & 8) != 0)

`define XM_ARB_SEL_BITS(I, O)  ((I > O) ? `XM_CLOG2(`XM_CDIV(I, O)) : 0)

`define STATIC_ASSERT(cond, msg) \
    /* verilator lint_off GENUNNAMED */ \
    if (!(cond)) $error msg; \
    /* verilator lint_on GENUNNAMED */ \

`define ERROR(msg) \
    $error msg

`define ASSERT(cond, msg) \
    assert(cond) else $error msg

`define RUNTIME_ASSERT(cond, msg) \
    always_ff @(posedge clk_i) begin   \
        if (!rst_i) begin         \
            `ASSERT(cond, msg);   \
        end                       \
    end

`ifndef TRACING_ALL
`define TRACING_ON      /* verilator tracing_on */
`define TRACING_OFF     /* verilator tracing_off */
`else
`define TRACING_ON
`define TRACING_OFF
`endif

`define IGNORE_UNOPTFLAT_BEGIN /* verilator lint_off UNOPTFLAT */
`define IGNORE_UNOPTFLAT_END  /* verilator lint_off UNOPTFLAT */
`define IGNORE_UNUSED_BEGIN   /* verilator lint_off UNUSED */
`define IGNORE_UNUSED_END     /* verilator lint_on UNUSED */

`define XM_UNUSED_PARAM(x)  /* verilator lint_off UNUSED */ \
                         localparam  __``x = x; \
                         /* verilator lint_on UNUSED */

`define XM_UNUSED_SPARAM(x) /* verilator lint_off UNUSED */ \
                         localparam `STRING __``x = x; \
                         /* verilator lint_on UNUSED */

`define XM_UNUSED_VAR(x)   /* verilator lint_off GENUNNAMED */ \
                        if (1) begin \
                            /* verilator lint_off UNUSED */ \
                            wire [$bits(x)-1:0] __unused = x; \
                            /* verilator lint_on UNUSED */ \
                        end \
                        /* verilator lint_on GENUNNAMED */

`define XM_UNUSED_PIN(x)   /* verilator lint_off PINCONNECTEMPTY */ \
                        . x () \
                        /* verilator lint_on PINCONNECTEMPTY */

`define SFORMATF(x) $sformatf x

`define POP_COUNT_EX(out, in, model) \
    xrv_popcount #( \
        .N ($bits(in)), \
        .MODEL (model) \
    ) __``out``__ ( \
        .data_in  (in), \
        .data_out (out) \
    )

`define POP_COUNT(out, in) `POP_COUNT_EX(out, in, 1)

`define XM_BUFFER_EX(dst, src, ena, RSTW, latency) \
    xrv_pipe_register #( \
        .DATA_WIDTH_P   ($bits(dst)), \
        .RESET_WIDTH_P  (RSTW), \
        .DEPTH_P        (latency) \
    ) __``dst``__ ( \
        .clk_i      (clk_i), \
        .rst_i      (rst_i), \
        .en_i       (ena), \
        .data_i     (src), \
        .data_o     (dst) \
    )

`define XM_BUFFER(dst, src) `XM_BUFFER_EX(dst, src, 1'b1, 0, 1)

`define MAX_FANOUT 8
`define PRESERVE_NET

`define RESET_RELAY_EX(dst, src, size, fanout)  \
    wire [size-1:0] dst;                        \
    xrv_reset_relay #(.N(size), .MAX_FANOUT(fanout)) __``dst ( \
        .clk_i      (clk_i),                         \
        .rst_i      (src),                         \
        .rst_o      (dst)                          \
    )

`define RESET_RELAY_EN(dst, src, enable) \
    `RESET_RELAY_EX (dst, src, 1, ((enable) ? 0 : -1))

`define RESET_RELAY(dst, src) \
    `RESET_RELAY_EX (dst, src, 1, 0)

`define PLATFORM_MEMORY_BANKS 2


`endif /* XM_MACRO_SVH */