`ifndef MTRA_PKG_VH
`define MTRA_PKG_VH

package mtra_pkg;

    typedef enum bit [2:0] {
        MTRA_SRC_ZERO       = 3d'0,
        MTRA_SRC_SELF       = 3d'1,
        MTRA_SRC_LEFT       = 3d'2,
        MTRA_SRC_RIGHT      = 3d'3,
        MTRA_SRC_TOP        = 3d'4,
        MTRA_SRC_BOTTOM     = 3d'5
    } mtra_src_type_e;

    localparam MTRA_DST_SELF    = 5b'00001;
    localparam MTRA_DST_LEFT    = 5b'00010;
    localparam MTRA_DST_RIGHT   = 5b'00100;
    localparam MTRA_DST_TOP     = 5b'01000;
    localparam MTRA_DST_BOTTOM  = 5b'10000;
    localparam MTRA_DST_NUM     = '5;

endpackage

`endif /* MTRA_PKG_VH */