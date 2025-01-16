`ifndef XM_RV_PKG_VH
`define XM_RV_PKG_VH

package xm_rv_pkg;

    // 
    localparam int RV_INSN_WIDTH = 32;
    //
    const int RV_INSN_COMPRESSED_WIDTH = 16;
    // number of architecture integer registers
    integer RV_REGISTER_INT_NUM = 32;


    typedef enum bit [1:0] {
        LS_B  = 2'b00,
        LS_H  = 2'b01,
        LS_W  = 2'b10,
        LS_D  = 2'b11
    } rv_ls_data_size_e;
endpackage

`endif // XM_RV_PKG_VH