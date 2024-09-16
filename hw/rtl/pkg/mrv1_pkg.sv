package mrv1_pkg;

    typedef enum bit [1:0] {
        MRV_FU_TYPE_ALU     = 2'b00,
        MRV_FU_TYPE_LSU     = 2'b01,
        MRV_FU_TYPE_CSR     = 2'b10,
    } mrv_fu_type_e;

endpackage