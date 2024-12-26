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
        LS_W = 2'b10,
        LS_D = 2'b11
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
        XRV_ARITH_64_IMM = 5'b00110,
        XRV_ARITH     = 5'b01100, //includes mul/div
        XRV_ARITH_64  = 5'b01110,
        XRV_FENCE     = 5'b00011,
        XRV_AMO       = 5'b01011,
        XRV_SYSTEM    = 5'b11100,
        //end of RV32I
        XRV_VECTOR    = 5'b10101,
        XRV_CUSTOM    = 5'b11110,
        XRV_ARITH_FP  = 5'b10000
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

    typedef enum logic [6:0] {
        XRV_ALU_FUNCT_7_ORDINARY_OP = 7'b0000000,
        XRV_ALU_FUNCT_7_MUL_DIV_OP  = 7'b0000001,
        XRV_ALU_FUNCT_7_REVERSE_OP  = 7'b0100000
    } xrv_alu_funct7_e;

    typedef enum logic [2:0] {
        XRV_ALU_FUNCT_3_ADD  = 3'b000,
        XRV_ALU_FUNCT_3_SLL  = 3'b001,
        XRV_ALU_FUNCT_3_SLT  = 3'b010,
        XRV_ALU_FUNCT_3_SLTU = 3'b011,
        XRV_ALU_FUNCT_3_XOR  = 3'b100,
        XRV_ALU_FUNCT_3_SRL  = 3'b101,
        XRV_ALU_FUNCT_3_OR   = 3'b110,
        XRV_ALU_FUNCT_3_AND  = 3'b111
    } xrv_alu_funct3_e;

    typedef struct packed {
        bit [6:0] funct7;
        bit [4:0] rs2;
        bit [4:0] rs1;
        bit [2:0] funct3;
        bit [4:0] rd;
        bit [6:0] opcode;
    } r_type_inst;

    typedef struct packed {
        bit [11:0] imm;
        bit [4:0]  rs1;
        bit [2:0]  funct3;
        bit [4:0]  rd;
        bit [6:0]  opcode;
    } i_type_inst;

    typedef struct packed {
        bit [6:0] imm_11_5;
        bit [4:0] rs2;
        bit [4:0] rs1;
        bit [2:0] funct3;
        bit [4:0] imm_4_0;
        bit [6:0] opcode;
    } s_type_inst;

    typedef struct packed {
        bit [0:0] imm_12;
        bit [5:0] imm_10_5;
        bit [4:0] rs2;
        bit [4:0] rs1;
        bit [2:0] funct3;
        bit [3:0] imm_4_1;
        bit [0:0] imm_11;
        bit [6:0] opcode;
    } b_type_inst;

    typedef struct packed {
        bit [19:0] imm;
        bit [4:0]  rd;
        bit [6:0]  opcode;
    } u_type_inst;

    typedef struct packed {
        bit [0:0] imm_20;
        bit [9:0] imm_10_1;
        bit [0:0] imm_11;
        bit [7:0] imm_19_12;
        bit [4:0] rd;
        bit [6:0] opcode;
    } j_type_inst;

    typedef union packed {
        r_type_inst r_type;
        i_type_inst i_type;
        s_type_inst s_type;
        b_type_inst b_type;
        u_type_inst u_type;
        j_type_inst j_type;
    } rv_inst;

endpackage
