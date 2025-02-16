`ifndef XRA_PKG_VH
`define XRA_PKG_VH

package xra_pkg;

    typedef enum bit [2:0] {
        XRA_SRC_W       = 3d'0,
        XRA_SRC_E       = 3d'1,
        XRA_SRC_S       = 3d'2,
        XRA_SRC_N       = 3d'3,
        XRA_SRC_NW      = 3d'4,
        XRA_SRC_NE      = 3d'5,
        XRA_SRC_SW      = 3d'6,
        XRA_SRC_SE      = 3d'7
    } xra_src_type_e;

    localparam XRA_DST_W   = 8b'00000001;
    localparam XRA_DST_E   = 8b'00000010;
    localparam XRA_DST_N   = 8b'00000100;
    localparam XRA_DST_S   = 8b'00001000;
    localparam XRA_DST_NW  = 8b'00010000;
    localparam XRA_DST_NE  = 8b'00100000;
    localparam XRA_DST_SW  = 8b'01000000;
    localparam XRA_DST_SE  = 8b'10000000;
    localparam XRA_DST_NUM = '8;

endpackage

`endif /* XRA_PKG_VH */