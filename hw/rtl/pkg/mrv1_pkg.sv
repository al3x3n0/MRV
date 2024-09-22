package mrv1_pkg;

    import xrv1_pkg::*;

    typedef enum bit [2:0] {
        MRV_FU_TYPE_INT     = 3'b000,
        MRV_FU_TYPE_MEM     = 3'b001,
        MRV_FU_TYPE_MUL     = 3'b010,
        MRV_FU_TYPE_SYS     = 3'b011,
        MRV_FU_TYPE_DIV     = 3'b100
    } mrv_fu_type_e;

    localparam MRV_NUM_FU = 5;
    localparam MRV_OPC_WIDTH_P = 7;

    ////////////////////////////////////////////////////////////////////////////////
    localparam MRV_INT_FU_OP_WIDTH = 7;
    typedef enum bit [MRV_INT_FU_OP_WIDTH-1:0] {
        MRV_INT_FU_ADD   = 7'b0011000,
        MRV_INT_FU_SUB   = 7'b0011001,
        MRV_INT_FU_ADDU  = 7'b0011010,
        MRV_INT_FU_SUBU  = 7'b0011011,
        MRV_INT_FU_ADDR  = 7'b0011100,
        MRV_INT_FU_SUBR  = 7'b0011101,
        MRV_INT_FU_ADDUR = 7'b0011110,
        MRV_INT_FU_SUBUR = 7'b0011111,
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_XOR = 7'b0101111,
        MRV_INT_FU_OR  = 7'b0101110,
        MRV_INT_FU_AND = 7'b0010101,
        ////////////////////////////////////////////////////////////////////////////////
        // Shifts
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_SRA = 7'b0100100,
        MRV_INT_FU_SRL = 7'b0100101,
        MRV_INT_FU_ROR = 7'b0100110,
        MRV_INT_FU_SLL = 7'b0100111,
        ////////////////////////////////////////////////////////////////////////////////
        // bit manipulation
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_BEXT  = 7'b0101000,
        MRV_INT_FU_BEXTU = 7'b0101001,
        MRV_INT_FU_BINS  = 7'b0101010,
        MRV_INT_FU_BCLR  = 7'b0101011,
        MRV_INT_FU_BSET  = 7'b0101100,
        MRV_INT_FU_BREV  = 7'b1001001,
        ////////////////////////////////////////////////////////////////////////////////
        // Bit counting
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_FF1 = 7'b0110110,
        MRV_INT_FU_FL1 = 7'b0110111,
        MRV_INT_FU_CNT = 7'b0110100,
        MRV_INT_FU_CLB = 7'b0110101,
        ////////////////////////////////////////////////////////////////////////////////
        // Sign-/zero-extensions
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_EXTS = 7'b0111110,
        MRV_INT_FU_EXT  = 7'b0111111,
        ////////////////////////////////////////////////////////////////////////////////
        // Comparisons
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_LTS = 7'b0000000,
        MRV_INT_FU_LTU = 7'b0000001,
        MRV_INT_FU_LES = 7'b0000100,
        MRV_INT_FU_LEU = 7'b0000101,
        MRV_INT_FU_GTS = 7'b0001000,
        MRV_INT_FU_GTU = 7'b0001001,
        MRV_INT_FU_GES = 7'b0001010,
        MRV_INT_FU_GEU = 7'b0001011,
        MRV_INT_FU_EQ  = 7'b0001100,
        MRV_INT_FU_NE  = 7'b0001101,
        ////////////////////////////////////////////////////////////////////////////////
        // Set Lower Than operations
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_SLTS  = 7'b0000010,
        MRV_INT_FU_SLTU  = 7'b0000011,
        MRV_INT_FU_SLETS = 7'b0000110,
        MRV_INT_FU_SLETU = 7'b0000111,
        ////////////////////////////////////////////////////////////////////////////////
        // Absolute value
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_ABS   = 7'b0010100,
        MRV_INT_FU_CLIP  = 7'b0010110,
        MRV_INT_FU_CLIPU = 7'b0010111,
        ////////////////////////////////////////////////////////////////////////////////
        // Insert/extract
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_INS = 7'b0101101,
        ////////////////////////////////////////////////////////////////////////////////
        // min/max
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_MIN  = 7'b0010000,
        MRV_INT_FU_MINU = 7'b0010001,
        MRV_INT_FU_MAX  = 7'b0010010,
        MRV_INT_FU_MAXU = 7'b0010011,
        ////////////////////////////////////////////////////////////////////////////////
        // Shuffle
        ////////////////////////////////////////////////////////////////////////////////
        MRV_INT_FU_SHUF  = 7'b0111010,
        MRV_INT_FU_SHUF2 = 7'b0111011,
        MRV_INT_FU_PCKLO = 7'b0111000,
        MRV_INT_FU_PCKHI = 7'b0111001
    } mrv_int_fu_op_e;

    ////////////////////////////////////////////////////////////////////////////////
    localparam MRV_MUL_FU_OP_WIDTH = 4;
    typedef enum bit [MRV_MUL_FU_OP_WIDTH-1:0] {
        MRV_MUL_FUL_MUL = 4'b0000
    } mrv_mul_fu_op_e;

    ////////////////////////////////////////////////////////////////////////////////
    localparam MRV_SYS_FU_OP_WIDTH = 7;
    typedef enum bit [MRV_SYS_FU_OP_WIDTH-1:0] {
        MRV_SYS_FU_CSR_READ = 7'b00,
        MRV_SYS_FU_CSR_WRITE = 7'b01,
        MRV_SYS_FU_CSR_SET = 7'b10,
        MRV_SYS_FU_CSR_CLR = 7'b11,
        MRV_SYS_FU_TSPAWN = 7'b0000100
    } mrv_sys_fu_op_e;

    typedef enum bit [2:0] {
        MRV_VEC_MODE32 = 3'b000,
        MRV_VEC_MODE16 = 3'b001,
        MRV_VEC_MODE8  = 3'b010,
        MRV_VEC_MODE4  = 3'b011,
        MRV_VEC_MODE2  = 3'b100
    } mrv_vec_mode_e;

endpackage