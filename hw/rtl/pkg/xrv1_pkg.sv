package xrv1_pkg;

    ////////////////////////////////////////////////////////////////////////////////
    localparam XRV_ALU_OPS_NUM = 20;
    localparam XRV_ALU_OP_WIDTH = $clog2(XRV_ALU_OPS_NUM);
    ////////////////////////////////////////////////////////////////////////////////
    typedef enum bit [XRV_ALU_OP_WIDTH-1:0] {
        ////////////////////////////////////////////////////////////////////////////////
        // Logic ops
        ////////////////////////////////////////////////////////////////////////////////
        XRV_ALU_XOR = 'd0,
        XRV_ALU_OR  = 'd1,
        XRV_ALU_AND = 'd2,
        ////////////////////////////////////////////////////////////////////////////////
        // Arithmetic
        ////////////////////////////////////////////////////////////////////////////////
        XRV_ALU_ADD = 'd3,
        XRV_ALU_SUB = 'd4,
        ////////////////////////////////////////////////////////////////////////////////
        // Shifts
        ////////////////////////////////////////////////////////////////////////////////
        // Shifts
        XRV_ALU_SRA = 'd5,
        XRV_ALU_SRL = 'd6,
        XRV_ALU_SLL = 'd7,
        ////////////////////////////////////////////////////////////////////////////////
        // Comparisons
        ////////////////////////////////////////////////////////////////////////////////
        XRV_ALU_LTS = 'd8,
        XRV_ALU_LTU = 'd9,
        XRV_ALU_LES = 'd10,
        XRV_ALU_LEU = 'd11,
        XRV_ALU_GTS = 'd12,
        XRV_ALU_GTU = 'd13,
        XRV_ALU_GES = 'd14,
        XRV_ALU_GEU = 'd15,
        XRV_ALU_EQ  = 'd16,
        XRV_ALU_NE  = 'd17,
        ////////////////////////////////////////////////////////////////////////////////
        XRV_ALU_SLTS  = 'd18,
        XRV_ALU_SLTU  = 'd19
    } xrv_alu_op_e;

    typedef enum bit [1:0] {
        XRV_MUL_MUL    = 2'b00,
        XRV_MUL_MULH   = 2'b01,
        XRV_MUL_MULHSU = 2'b10,
        XRV_MUL_MULHU  = 2'b11
    } xrv_mul_op_e;

    typedef enum bit [1:0] {
        XRV_DIV_DIVU  = 2'b00,
        XRV_DIV_DIV   = 2'b01,
        XRV_DIV_REMU  = 2'b10,
        XRV_DIV_REM   = 2'b11
    } xrv_div_op_e;

    typedef enum bit [1:0] {
        XRV_CSR_READ  = 2'b00,
        XRV_CSR_WRITE = 2'b01,
        XRV_CSR_SET   = 2'b10,
        XRV_CSR_CLR   = 2'b11
    } xrv_csr_op_e;

    typedef enum bit [1:0] {
        LS_B = 2'b00,
        LS_H = 2'b01,
        LS_W = 2'b10
    } xrv_ls_data_size_e;

    typedef enum bit [2:0] {
        XRV_VEC_MODE32 = 3'b000,
        XRV_VEC_MODE16 = 3'b001,
        XRV_VEC_MODE8  = 3'b010,
        XRV_VEC_MODE4  = 3'b011,
        XRV_VEC_MODE2  = 3'b100
    } xrv_vec_mode_e;

    typedef enum bit [4:0] {
        XRV_LUI       = 5'b01101,
        XRV_AUIPC     = 5'b00101,
        XRV_JAL       = 5'b11011,
        XRV_JALR      = 5'b11001,
        XRV_BRANCH    = 5'b11000,
        XRV_LOAD      = 5'b00000,
        XRV_LOAD_FP   = 5'b00001,
        XRV_STORE     = 5'b01000,
        XRV_STORE_FP  = 5'b01001, // FIXME
        XRV_ARITH_IMM = 5'b00100,
        XRV_ARITH     = 5'b01100, //includes mul/div
        XRV_FENCE     = 5'b00011,
        XRV_AMO       = 5'b01011,
        XRV_SYSTEM    = 5'b11100,
        //end of RV32I
        XRV_VECTOR    = 5'b10101,
        XRV_CUSTOM    = 5'b11110
    } xrv_opcode_e;

    typedef enum logic [1:0] {
        XRV_SRC0_RS0 = 'd0,
        XRV_SRC0_RS1,
        XRV_SRC0_PC,
        XRV_SRC0_IMM
    } xrv_exe_src0_sel_e;

    typedef enum logic [1:0] {
        XRV_SRC1_RS0 = 'd0,
        XRV_SRC1_RS1,
        XRV_SRC1_IMM
    } xrv_exe_src1_sel_e;

    typedef enum logic [1:0] {
        XRV_IMM0_Z = 'd0,
        XRV_IMM0_ZERO
    } xrv_imm0_sel_e;

    typedef enum logic [1:0] {
        XRV_IMM1_I = 'd0,
        XRV_IMM1_S,
        XRV_IMM1_U
    } xrv_imm1_sel_e;

    typedef enum bit [11:0] {
        XRV_CSR_MTVEC = 12'h305
    } xrv_csr_e;

endpackage
