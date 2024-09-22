////////////////////////////////////////////////////////////////////////////////
// Use cv32e40p ALU (w/o DIV/REM) as xPE INT FU
// https://github.com/openhwgroup/cv32e40p/blob/master/rtl/cv32e40p_alu.sv
////////////////////////////////////////////////////////////////////////////////

module mrv1_int_fu
#(
    parameter PC_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_THREADS_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]      exec_src0_data_i,
    input logic [DATA_WIDTH_P-1:0]      exec_src1_data_i,
    input logic [DATA_WIDTH_P-1:0]      exec_src2_data_i,
    input logic [PC_WIDTH_P-1:0]        exec_pc_i,
    input logic [ITAG_WIDTH_P-1:0]      exec_itag_i,
    input logic [TID_WIDTH_LP-1:0]      exec_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input mrv_int_fu_op_e               int_fu_opc_i,
    input mrv_vec_mode_e                int_fu_vec_mode_i,
    input logic [4:0]                   int_fu_bmask0_i,
    input logic [4:0]                   int_fu_bmask1_i,
    input logic [1:0]                   int_fu_imm_vec_ext_i,
    input logic                         int_fu_req_i,
    output logic                        int_fu_rdy_o,
    output logic [DATA_WIDTH_P-1:0]     int_fu_res_o,
    output logic                        int_fu_done_o,
    output logic [ITAG_WIDTH_P-1:0]     int_fu_itag_o,
    output logic [TID_WIDTH_LP-1:0]     int_fu_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Branches
    ////////////////////////////////////////////////////////////////////////////////
    input logic                         b_is_branch_i,
    input logic                         b_is_jump_i,
    output logic                        b_pc_vld_o,
    output logic [PC_WIDTH_P-1:0]       b_pc_o,
    output logic [TID_WIDTH_LP-1:0]     b_tid_o
);
    ////////////////////////////////////////////////////////////////////////////////
    assign int_fu_rdy_o     = 1'b1;
    assign int_fu_done_o    = int_fu_req_i;
    assign int_fu_itag_o    = exec_itag_i;
    ////////////////////////////////////////////////////////////////////////////////

    logic [DATA_WIDTH_P-1:0] exec_src0_data_rev;
    logic [DATA_WIDTH_P-1:0] exec_src0_data_neg;
    logic [DATA_WIDTH_P-1:0] exec_src0_data_neg_rev;

    assign exec_src0_data_neg = ~exec_src0_data_i;

    ////////////////////////////////////////////////////////////////////////////////
    // bit reverse exec_src0_data for left shifts and bit counting
    ////////////////////////////////////////////////////////////////////////////////
    generate
        genvar k;
        for (k = 0; k < DATA_WIDTH_P; k++) begin : gen_exec_src0_data_rev
            assign exec_src0_data_rev[k] = exec_src0_data_i[DATA_WIDTH_P-1-k];
        end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////
    // bit reverse exec_src0_data_neg for left shifts and bit counting
    ////////////////////////////////////////////////////////////////////////////////
    generate
        genvar m;
        for (m = 0; m < DATA_WIDTH_P; m++) begin : gen_exec_src0_data_neg_rev
            assign exec_src0_data_neg_rev[m] = exec_src0_data_neg[DATA_WIDTH_P-m];
        end
    endgenerate

    logic [DATA_WIDTH_P-1:0] exec_src1_data_neg = ~exec_src1_data_i;
    logic [DATA_WIDTH_P-1:0] bmask;

    //////////////////////////////////////////////////////////////////////////////////////////
    // Partitioned Adder
    //////////////////////////////////////////////////////////////////////////////////////////
    logic adder_op_b_negate;
    logic [DATA_WIDTH_P-1:0] adder_op_a, adder_op_b;
    logic [DATA_WIDTH_P+3:0] adder_in_a, adder_in_b;
    logic [DATA_WIDTH_P-1:0] adder_result;
    logic [DATA_WIDTH_P+4:0] adder_result_expanded;

    assign adder_op_b_negate = int_fu_opc_i inside {
        MRV_INT_FU_SUB,
        MRV_INT_FU_SUBR,
        MRV_INT_FU_SUBU,
        MRV_INT_FU_SUBUR
    };

    //////////////////////////////////////////////////////////////////////////////////////////
    assign adder_op_a = (int_fu_opc_i == MRV_INT_FU_ABS) ? exec_src0_data_neg : exec_src0_data_i;
    assign adder_op_b = adder_op_b_negate ? exec_src1_data_neg : exec_src1_data_i;
    //////////////////////////////////////////////////////////////////////////////////////////
    // prepare carry
    //////////////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        adder_in_a[0]     = 1'b1;
        adder_in_a[8:1]   = adder_op_a[7:0];
        adder_in_a[9]     = 1'b1;
        adder_in_a[17:10] = adder_op_a[15:8];
        adder_in_a[18]    = 1'b1;
        adder_in_a[26:19] = adder_op_a[23:16];
        adder_in_a[27]    = 1'b1;
        adder_in_a[35:28] = adder_op_a[31:24];

        adder_in_b[0]     = 1'b0;
        adder_in_b[8:1]   = adder_op_b[7:0];
        adder_in_b[9]     = 1'b0;
        adder_in_b[17:10] = adder_op_b[15:8];
        adder_in_b[18]    = 1'b0;
        adder_in_b[26:19] = adder_op_b[23:16];
        adder_in_b[27]    = 1'b0;
        adder_in_b[35:28] = adder_op_b[31:24];

        if (adder_op_b_negate || int_fu_opc_i inside { MRV_INT_FU_ABS, MRV_INT_FU_CLIP }) begin
            // special case for subtractions and absolute number calculations
            adder_in_b[0] = 1'b1;

            case (int_fu_vec_mode_i)
                MRV_VEC_MODE16: begin
                    adder_in_b[18] = 1'b1;
                end
                MRV_VEC_MODE8: begin
                    adder_in_b[9]  = 1'b1;
                    adder_in_b[18] = 1'b1;
                    adder_in_b[27] = 1'b1;
                end
            endcase
        end else begin
            // take care of partitioning the adder for the addition case
            case (int_fu_vec_mode_i)
                MRV_VEC_MODE16: begin
                    adder_in_a[18] = 1'b0;
                end
                MRV_VEC_MODE8: begin
                    adder_in_a[9]  = 1'b0;
                    adder_in_a[18] = 1'b0;
                    adder_in_a[27] = 1'b0;
                end
            endcase
        end
    end
    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////
    // actual adder
    //////////////////////////////////////////////////////////////////////////////////////////
    assign adder_result_expanded = $signed(adder_in_a) + $signed(adder_in_b);
    assign adder_result = {
        adder_result_expanded[35:28],
        adder_result_expanded[26:19],
        adder_result_expanded[17:10],
        adder_result_expanded[8:1]
    };

    //////////////////////////////////////////////////////////////////////////////////////////
    // normalization stage
    //////////////////////////////////////////////////////////////////////////////////////////
    logic [31:0] adder_round_value;
    logic [31:0] adder_round_result;

    assign adder_round_value = int_fu_opc_i inside {
        MRV_INT_FU_ADDR,
        MRV_INT_FU_SUBR,
        MRV_INT_FU_ADDUR,
        MRV_INT_FU_SUBUR
    } ? {1'b0, bmask[31:1]} : '0;
    assign adder_round_result = adder_result + adder_round_value;
    //////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Shift
    ////////////////////////////////////////////////////////////////////////////////
    logic        shift_left;  // should we shift left
    logic        shift_use_round;
    logic        shift_arithmetic;

    logic [31:0] shift_amt_left;  // amount of shift, if to the left
    logic [31:0] shift_amt;  // amount of shift, to the right
    logic [31:0] shift_amt_int;  // amount of shift, used for the actual shifters
    logic [31:0] shift_amt_norm;  // amount of shift, used for normalization
    logic [31:0] shift_op_a;  // input of the shifter
    logic [31:0] shift_result;
    logic [31:0] shift_right_result;
    logic [31:0] shift_left_result;
    ////////////////////////////////////////////////////////////////////////////////
    assign shift_amt = exec_src1_data_i;
    ////////////////////////////////////////////////////////////////////////////////
    // by reversing the bits of the input, we also have to reverse the order of shift amounts
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (int_fu_vec_mode_i)
        MRV_VEC_MODE16: begin
            shift_amt_left[15:0]  = shift_amt[31:16];
            shift_amt_left[31:16] = shift_amt[15:0];
        end
        ////////////////////////////////////////////////////////////////////////////////
        MRV_VEC_MODE8: begin
            shift_amt_left[7:0]   = shift_amt[31:24];
            shift_amt_left[15:8]  = shift_amt[23:16];
            shift_amt_left[23:16] = shift_amt[15:8];
            shift_amt_left[31:24] = shift_amt[7:0];
        end
        ////////////////////////////////////////////////////////////////////////////////
        default: // MRV_VEC_MODE32
            begin
                shift_amt_left[31:0] = shift_amt[31:0];
            end
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // MRV_INT_FU_FL1 and MRV_INT_FU_CBL are used for the bit counting ops later
    ////////////////////////////////////////////////////////////////////////////////
    assign shift_left = int_fu_opc_i inside {
        MRV_INT_FU_SLL,
        MRV_INT_FU_BINS,
        MRV_INT_FU_FL1,
        MRV_INT_FU_CLB,
        MRV_INT_FU_BREV
    };

    ////////////////////////////////////////////////////////////////////////////////
    assign shift_use_round = int_fu_opc_i inside {
        MRV_INT_FU_SUB,
        MRV_INT_FU_SUBR,
        MRV_INT_FU_SUBU,
        MRV_INT_FU_SUBUR,
        MRV_INT_FU_ADD,
        MRV_INT_FU_ADDR,
        MRV_INT_FU_ADDU,
        MRV_INT_FU_ADDUR
    };

    ////////////////////////////////////////////////////////////////////////////////
    assign shift_arithmetic = int_fu_opc_i inside {
        MRV_INT_FU_SRA,
        MRV_INT_FU_BEXT,
        MRV_INT_FU_ADD,
        MRV_INT_FU_ADDR,
        MRV_INT_FU_SUB,
        MRV_INT_FU_SUBR
    };

    ////////////////////////////////////////////////////////////////////////////////
    // choose the bit reversed or the normal input for shift operand a
    ////////////////////////////////////////////////////////////////////////////////
    assign shift_op_a    = shift_left ? exec_src0_data_rev :
                          (shift_use_round ? adder_round_result : exec_src0_data_i);
    assign shift_amt_int = shift_use_round ? shift_amt_norm :
                            (shift_left ? shift_amt_left : shift_amt);
    assign shift_amt_norm = {4{3'b000, int_fu_bmask1_i}};

    ////////////////////////////////////////////////////////////////////////////////
    // right shifts, we let the synthesizer optimize this
    ////////////////////////////////////////////////////////////////////////////////
    logic [63:0] shift_op_a_32;
    assign shift_op_a_32 = (int_fu_opc_i == MRV_INT_FU_ROR) ? {
        shift_op_a, shift_op_a
    } : $signed({{32{shift_arithmetic & shift_op_a[31]}}, shift_op_a});
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (int_fu_vec_mode_i)
            ////////////////////////////////////////////////////////////////////////////////
            MRV_VEC_MODE16: begin
                shift_right_result[31:16] = $signed(
                    {shift_arithmetic & shift_op_a[31], shift_op_a[31:16]}
                ) >>> shift_amt_int[19:16];
                shift_right_result[15:0] = $signed(
                    {shift_arithmetic & shift_op_a[15], shift_op_a[15:0]}
                ) >>> shift_amt_int[3:0];
            end
            ////////////////////////////////////////////////////////////////////////////////
            MRV_VEC_MODE8: begin
                shift_right_result[31:24] = $signed(
                    {shift_arithmetic & shift_op_a[31], shift_op_a[31:24]}
                ) >>> shift_amt_int[26:24];
                shift_right_result[23:16] = $signed(
                    {shift_arithmetic & shift_op_a[23], shift_op_a[23:16]}
                ) >>> shift_amt_int[18:16];
                shift_right_result[15:8] = $signed(
                    {shift_arithmetic & shift_op_a[15], shift_op_a[15:8]}
                ) >>> shift_amt_int[10:8];
                shift_right_result[7:0] = $signed(
                    {shift_arithmetic & shift_op_a[7], shift_op_a[7:0]}
                ) >>> shift_amt_int[2:0];
            end
            ////////////////////////////////////////////////////////////////////////////////
            default: // MRV_VEC_MODE32
            begin
                shift_right_result = shift_op_a_32 >> shift_amt_int[4:0];
            end
        endcase
        ;  // case (vec_mode_i)
    end
    ////////////////////////////////////////////////////////////////////////////////
    // bit reverse the shift_right_result for left shifts
    ////////////////////////////////////////////////////////////////////////////////
    genvar j;
    generate
        for (j = 0; j < 32; j++) begin : gen_shift_left_result
            assign shift_left_result[j] = shift_right_result[31-j];
        end
    endgenerate
    assign shift_result = shift_left ? shift_left_result : shift_right_result;

    //////////////////////////////////////////////////////////////////
    // Comparison
    //////////////////////////////////////////////////////////////////
    logic [ 3:0] is_equal;
    logic [ 3:0] is_greater;  // handles both signed and unsigned forms
    //////////////////////////////////////////////////////////////////
    // 8-bit vector comparisons, basic building blocks
    //////////////////////////////////////////////////////////////////
    logic [ 3:0] cmp_signed;
    logic [ 3:0] is_equal_vec;
    logic [ 3:0] is_greater_vec;

    //////////////////////////////////////////////////////////////////
    //second == comparator for CLIP instructions
    //////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0] exec_src1_data_eq = int_fu_opc_i == MRV_INT_FU_CLIPU ? '0 : exec_src1_data_neg;
    logic is_equal_clip = exec_src0_data_i == exec_src1_data_eq;
    //////////////////////////////////////////////////////////////////
    always_comb begin
        cmp_signed = 4'b0;
        unique case (int_fu_opc_i)
            MRV_INT_FU_GTS,
            MRV_INT_FU_GES,
            MRV_INT_FU_LTS,
            MRV_INT_FU_LES,
            MRV_INT_FU_SLTS,
            MRV_INT_FU_SLETS,
            MRV_INT_FU_MIN,
            MRV_INT_FU_MAX,
            MRV_INT_FU_ABS,
            MRV_INT_FU_CLIP,
            MRV_INT_FU_CLIPU: begin
                case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8:  cmp_signed[3:0] = 4'b1111;
                    MRV_VEC_MODE16: cmp_signed[3:0] = 4'b1010;
                    default:    cmp_signed[3:0] = 4'b1000;
                endcase
            end
            default: ;
        endcase
    end
    //////////////////////////////////////////////////////////////////
    // generate vector equal and greater than signals, cmp_signed decides if the
    // comparison is done signed or unsigned
    //////////////////////////////////////////////////////////////////
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_is_vec
            assign is_equal_vec[i] = (exec_src0_data_i[8*i+7:8*i] == exec_src1_data_i[8*i+7:i*8]);
            assign is_greater_vec[i] = $signed(
                {exec_src0_data_i[8*i+7] & cmp_signed[i], exec_src0_data_i[8*i+7:8*i]}
            ) > $signed(
                {exec_src1_data_i[8*i+7] & cmp_signed[i], exec_src1_data_i[8*i+7:i*8]}
            );
        end
    endgenerate

    //////////////////////////////////////////////////////////////////
    // generate the real equal and greater than signals that take the vector
    // mode into account
    //////////////////////////////////////////////////////////////////
    always_comb begin
        //////////////////////////////////////////////////////////////////
        // 32-bit mode
        //////////////////////////////////////////////////////////////////
        is_equal[3:0] = {4{is_equal_vec[3] & is_equal_vec[2] & is_equal_vec[1] & is_equal_vec[0]}};
        is_greater[3:0] = {4{is_greater_vec[3] | (is_equal_vec[3] & (is_greater_vec[2]
                                                | (is_equal_vec[2] & (is_greater_vec[1]
                                                | (is_equal_vec[1] & (is_greater_vec[0]))))))}};
        //////////////////////////////////////////////////////////////////
        case (int_fu_vec_mode_i)
            //////////////////////////////////////////////////////////////////
            MRV_VEC_MODE16: begin
                is_equal[1:0]   = {2{is_equal_vec[0] & is_equal_vec[1]}};
                is_equal[3:2]   = {2{is_equal_vec[2] & is_equal_vec[3]}};
                is_greater[1:0] = {2{is_greater_vec[1] | (is_equal_vec[1] & is_greater_vec[0])}};
                is_greater[3:2] = {2{is_greater_vec[3] | (is_equal_vec[3] & is_greater_vec[2])}};
            end
            //////////////////////////////////////////////////////////////////
            MRV_VEC_MODE8: begin
                is_equal[3:0]   = is_equal_vec[3:0];
                is_greater[3:0] = is_greater_vec[3:0];
            end
            default: ;  // see default assignment
        endcase
    end

    //////////////////////////////////////////////////////////////////
    // generate comparison result
    //////////////////////////////////////////////////////////////////
    logic [3:0] cmp_result;
    always_comb begin
        cmp_result = is_equal;
        unique case (int_fu_opc_i)
            MRV_INT_FU_EQ:
                cmp_result = is_equal;
            MRV_INT_FU_NE:
                cmp_result = ~is_equal;
            MRV_INT_FU_GTS,
            MRV_INT_FU_GTU:
                cmp_result = is_greater;
            MRV_INT_FU_GES,
            MRV_INT_FU_GEU:
                cmp_result = is_greater | is_equal;
            MRV_INT_FU_LTS,
            MRV_INT_FU_SLTS,
            MRV_INT_FU_LTU,
            MRV_INT_FU_SLTU:
                cmp_result = ~(is_greater | is_equal);
            MRV_INT_FU_SLETS,
            MRV_INT_FU_SLETU,
            MRV_INT_FU_LES,
            MRV_INT_FU_LEU:
                cmp_result = ~is_greater;
            default:;
        endcase
    end
    wire comparison_result_w = cmp_result[3];
    //////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////
    // min/max/abs handling
    //////////////////////////////////////////////////////////////////
    logic [31:0] result_minmax;
    logic [ 3:0] sel_minmax;
    logic        do_min;
    logic [31:0] minmax_b;
    //////////////////////////////////////////////////////////////////
    assign minmax_b = (int_fu_opc_i == MRV_INT_FU_ABS) ? adder_result : exec_src1_data_i;
    assign do_min = int_fu_opc_i inside {
        MRV_INT_FU_MIN,
        MRV_INT_FU_MINU,
        MRV_INT_FU_CLIP,
        MRV_INT_FU_CLIPU
    };
    assign sel_minmax[3:0] = is_greater ^ {4{do_min}};
    assign result_minmax[31:24] = (sel_minmax[3] == 1'b1) ? exec_src0_data_i[31:24] : minmax_b[31:24];
    assign result_minmax[23:16] = (sel_minmax[2] == 1'b1) ? exec_src0_data_i[23:16] : minmax_b[23:16];
    assign result_minmax[15:8] = (sel_minmax[1] == 1'b1) ? exec_src0_data_i[15:8] : minmax_b[15:8];
    assign result_minmax[7:0] = (sel_minmax[0] == 1'b1) ? exec_src0_data_i[7:0] : minmax_b[7:0];
    //////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////
    // Clip
    //////////////////////////////////////////////////////////////////
    logic [31:0] clip_result;  // result of clip and clip
    always_comb begin
        clip_result = result_minmax;
        if (int_fu_opc_i == MRV_INT_FU_CLIPU) begin
            clip_result = (exec_src0_data_i[31] || is_equal_clip) ? '0 : result_minmax;
        end else begin
            //////////////////////////////////////////////////////////////////
            //CLIP
            //////////////////////////////////////////////////////////////////
            clip_result = (adder_result_expanded[36] || is_equal_clip) ? exec_src1_data_neg : result_minmax;
        end
    end
    //////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Shuffle
    ////////////////////////////////////////////////////////////////////////////////
    logic [3:0][1:0] shuffle_byte_sel;  // select byte in register: 31:24, 23:16, 15:8, 7:0
    logic [3:0]      shuffle_reg_sel;  // select register: rD/rS2 or rS1
    logic [1:0]      shuffle_reg1_sel;  // select register rD or rS2 for next stage
    logic [1:0]      shuffle_reg0_sel;
    logic [3:0]      shuffle_through;
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] shuffle_r1, shuffle_r0;
    logic [31:0] shuffle_r1_in, shuffle_r0_in;
    logic [31:0] shuffle_result;
    logic [31:0] pack_result;
    ////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        shuffle_reg_sel  = '0;
        shuffle_reg1_sel = 2'b01;
        shuffle_reg0_sel = 2'b10;
        shuffle_through  = '1;

        unique case (int_fu_opc_i)
            MRV_INT_FU_EXT,
            MRV_INT_FU_EXTS: begin
                if (int_fu_opc_i == MRV_INT_FU_EXTS) begin 
                    shuffle_reg1_sel = 2'b11;
                end
                if (int_fu_vec_mode_i == MRV_VEC_MODE8) begin
                    shuffle_reg_sel[3:1] = 3'b111;
                    shuffle_reg_sel[0]   = 1'b0;
                end else begin
                    shuffle_reg_sel[3:2] = 2'b11;
                    shuffle_reg_sel[1:0] = 2'b00;
                end
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_PCKLO: begin
                shuffle_reg1_sel = 2'b00;
                if (int_fu_vec_mode_i == MRV_VEC_MODE8) begin
                    shuffle_through = 4'b0011;
                    shuffle_reg_sel = 4'b0001;
                    end else begin
                    shuffle_reg_sel = 4'b0011;
                end
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_PCKHI: begin
                shuffle_reg1_sel = 2'b00;
                if (int_fu_vec_mode_i == MRV_VEC_MODE8) begin
                    shuffle_through = 4'b1100;
                    shuffle_reg_sel = 4'b0100;
                    end else begin
                    shuffle_reg_sel = 4'b0011;
                end
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_SHUF2: begin
                unique case (int_fu_vec_mode_i)
                    //////////////////////////////////////////////////////////////////
                    MRV_VEC_MODE8: begin
                        shuffle_reg_sel[3] = ~exec_src1_data_i[26];
                        shuffle_reg_sel[2] = ~exec_src1_data_i[18];
                        shuffle_reg_sel[1] = ~exec_src1_data_i[10];
                        shuffle_reg_sel[0] = ~exec_src1_data_i[2];
                    end
                    //////////////////////////////////////////////////////////////////
                    MRV_VEC_MODE16: begin
                        shuffle_reg_sel[3] = ~exec_src1_data_i[17];
                        shuffle_reg_sel[2] = ~exec_src1_data_i[17];
                        shuffle_reg_sel[1] = ~exec_src1_data_i[1];
                        shuffle_reg_sel[0] = ~exec_src1_data_i[1];
                    end
                    default: ;
                endcase
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_INS: begin
                unique case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8: begin
                        shuffle_reg0_sel = 2'b00;
                        unique case (int_fu_imm_vec_ext_i)
                        2'b00: begin
                            shuffle_reg_sel[3:0] = 4'b1110;
                        end
                        2'b01: begin
                            shuffle_reg_sel[3:0] = 4'b1101;
                        end
                        2'b10: begin
                            shuffle_reg_sel[3:0] = 4'b1011;
                        end
                        2'b11: begin
                            shuffle_reg_sel[3:0] = 4'b0111;
                        end
                        endcase
                    end
                    MRV_VEC_MODE16: begin
                        shuffle_reg0_sel   = 2'b01;
                        shuffle_reg_sel[3] = ~int_fu_imm_vec_ext_i[0];
                        shuffle_reg_sel[2] = ~int_fu_imm_vec_ext_i[0];
                        shuffle_reg_sel[1] = int_fu_imm_vec_ext_i[0];
                        shuffle_reg_sel[0] = int_fu_imm_vec_ext_i[0];
                    end
                    default: ;
                endcase
            end
            default: ;
        endcase
    end

    always_comb begin
        shuffle_byte_sel = '0;
        //////////////////////////////////////////////////////////////////
        // byte selector
        //////////////////////////////////////////////////////////////////
        unique case (int_fu_opc_i)
            MRV_INT_FU_EXTS,
            MRV_INT_FU_EXT: begin
                unique case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8: begin
                        shuffle_byte_sel[3] = int_fu_imm_vec_ext_i[1:0];
                        shuffle_byte_sel[2] = int_fu_imm_vec_ext_i[1:0];
                        shuffle_byte_sel[1] = int_fu_imm_vec_ext_i[1:0];
                        shuffle_byte_sel[0] = int_fu_imm_vec_ext_i[1:0];
                    end
                    MRV_VEC_MODE16: begin
                        shuffle_byte_sel[3] = {int_fu_imm_vec_ext_i[0], 1'b1};
                        shuffle_byte_sel[2] = {int_fu_imm_vec_ext_i[0], 1'b1};
                        shuffle_byte_sel[1] = {int_fu_imm_vec_ext_i[0], 1'b1};
                        shuffle_byte_sel[0] = {int_fu_imm_vec_ext_i[0], 1'b0};
                    end
                    default: ;
                endcase
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_PCKLO: begin
                unique case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8: begin
                        shuffle_byte_sel[3] = 2'b00;
                        shuffle_byte_sel[2] = 2'b00;
                        shuffle_byte_sel[1] = 2'b00;
                        shuffle_byte_sel[0] = 2'b00;
                    end
                    MRV_VEC_MODE16: begin
                        shuffle_byte_sel[3] = 2'b01;
                        shuffle_byte_sel[2] = 2'b00;
                        shuffle_byte_sel[1] = 2'b01;
                        shuffle_byte_sel[0] = 2'b00;
                    end
                    default:;
                endcase
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_PCKHI: begin
                unique case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8: begin
                        shuffle_byte_sel[3] = 2'b00;
                        shuffle_byte_sel[2] = 2'b00;
                        shuffle_byte_sel[1] = 2'b00;
                        shuffle_byte_sel[0] = 2'b00;
                    end
                    //////////////////////////////////////////////////////////////////
                    MRV_VEC_MODE16: begin
                        shuffle_byte_sel[3] = 2'b11;
                        shuffle_byte_sel[2] = 2'b10;
                        shuffle_byte_sel[1] = 2'b11;
                        shuffle_byte_sel[0] = 2'b10;
                    end
                    default:;
                endcase
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_SHUF2, MRV_INT_FU_SHUF: begin
                unique case (int_fu_vec_mode_i)
                    MRV_VEC_MODE8: begin
                        shuffle_byte_sel[3] = exec_src1_data_i[25:24];
                        shuffle_byte_sel[2] = exec_src1_data_i[17:16];
                        shuffle_byte_sel[1] = exec_src1_data_i[9:8];
                        shuffle_byte_sel[0] = exec_src1_data_i[1:0];
                    end
                    //////////////////////////////////////////////////////////////////
                    MRV_VEC_MODE16: begin
                        shuffle_byte_sel[3] = {exec_src1_data_i[16], 1'b1};
                        shuffle_byte_sel[2] = {exec_src1_data_i[16], 1'b0};
                        shuffle_byte_sel[1] = {exec_src1_data_i[0], 1'b1};
                        shuffle_byte_sel[0] = {exec_src1_data_i[0], 1'b0};
                    end
                    default: ;
                endcase
            end
            //////////////////////////////////////////////////////////////////
            MRV_INT_FU_INS: begin
                shuffle_byte_sel[3] = 2'b11;
                shuffle_byte_sel[2] = 2'b10;
                shuffle_byte_sel[1] = 2'b01;
                shuffle_byte_sel[0] = 2'b00;
            end
            default: ;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign shuffle_r0_in = shuffle_reg0_sel[1] ? exec_src0_data_i :
        (shuffle_reg0_sel[0] ? {2{exec_src0_data_i[15:0]}} : {4{exec_src0_data_i[7:0]}});
    ////////////////////////////////////////////////////////////////////////////////
    assign shuffle_r1_in = shuffle_reg1_sel[1] ? {
        {8{exec_src0_data_i[31]}}, {8{exec_src0_data_i[23]}}, {8{exec_src0_data_i[15]}}, {8{exec_src0_data_i[7]}}
    } : (shuffle_reg1_sel[0] ? exec_src2_data_i : exec_src1_data_i);
    ////////////////////////////////////////////////////////////////////////////////
    assign shuffle_r0[31:24] = shuffle_byte_sel[3][1] ?
                                (shuffle_byte_sel[3][0] ? shuffle_r0_in[31:24] : shuffle_r0_in[23:16]) :
                                (shuffle_byte_sel[3][0] ? shuffle_r0_in[15: 8] : shuffle_r0_in[ 7: 0]);
    assign shuffle_r0[23:16] = shuffle_byte_sel[2][1] ?
                                (shuffle_byte_sel[2][0] ? shuffle_r0_in[31:24] : shuffle_r0_in[23:16]) :
                                (shuffle_byte_sel[2][0] ? shuffle_r0_in[15: 8] : shuffle_r0_in[ 7: 0]);
    assign shuffle_r0[15: 8] = shuffle_byte_sel[1][1] ?
                                (shuffle_byte_sel[1][0] ? shuffle_r0_in[31:24] : shuffle_r0_in[23:16]) :
                                (shuffle_byte_sel[1][0] ? shuffle_r0_in[15: 8] : shuffle_r0_in[ 7: 0]);
    assign shuffle_r0[ 7: 0] = shuffle_byte_sel[0][1] ?
                                (shuffle_byte_sel[0][0] ? shuffle_r0_in[31:24] : shuffle_r0_in[23:16]) :
                                (shuffle_byte_sel[0][0] ? shuffle_r0_in[15: 8] : shuffle_r0_in[ 7: 0]);
    ////////////////////////////////////////////////////////////////////////////////
    assign shuffle_r1[31:24] = shuffle_byte_sel[3][1] ?
                                (shuffle_byte_sel[3][0] ? shuffle_r1_in[31:24] : shuffle_r1_in[23:16]) :
                                (shuffle_byte_sel[3][0] ? shuffle_r1_in[15: 8] : shuffle_r1_in[ 7: 0]);
    assign shuffle_r1[23:16] = shuffle_byte_sel[2][1] ?
                                (shuffle_byte_sel[2][0] ? shuffle_r1_in[31:24] : shuffle_r1_in[23:16]) :
                                (shuffle_byte_sel[2][0] ? shuffle_r1_in[15: 8] : shuffle_r1_in[ 7: 0]);
    assign shuffle_r1[15: 8] = shuffle_byte_sel[1][1] ?
                                (shuffle_byte_sel[1][0] ? shuffle_r1_in[31:24] : shuffle_r1_in[23:16]) :
                                (shuffle_byte_sel[1][0] ? shuffle_r1_in[15: 8] : shuffle_r1_in[ 7: 0]);
    assign shuffle_r1[ 7: 0] = shuffle_byte_sel[0][1] ?
                                (shuffle_byte_sel[0][0] ? shuffle_r1_in[31:24] : shuffle_r1_in[23:16]) :
                                (shuffle_byte_sel[0][0] ? shuffle_r1_in[15: 8] : shuffle_r1_in[ 7: 0]);
    ////////////////////////////////////////////////////////////////////////////////
    assign shuffle_result[31:24] = shuffle_reg_sel[3] ? shuffle_r1[31:24] : shuffle_r0[31:24];
    assign shuffle_result[23:16] = shuffle_reg_sel[2] ? shuffle_r1[23:16] : shuffle_r0[23:16];
    assign shuffle_result[15:8] = shuffle_reg_sel[1] ? shuffle_r1[15:8] : shuffle_r0[15:8];
    assign shuffle_result[7:0] = shuffle_reg_sel[0] ? shuffle_r1[7:0] : shuffle_r0[7:0];
    ////////////////////////////////////////////////////////////////////////////////
    assign pack_result[31:24] = shuffle_through[3] ? shuffle_result[31:24] : exec_src2_data_i[31:24];
    assign pack_result[23:16] = shuffle_through[2] ? shuffle_result[23:16] : exec_src2_data_i[23:16];
    assign pack_result[15:8] = shuffle_through[1] ? shuffle_result[15:8] : exec_src2_data_i[15:8];
    assign pack_result[7:0] = shuffle_through[0] ? shuffle_result[7:0] : exec_src2_data_i[7:0];
    ////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////
    // Bit count operations
    /////////////////////////////////////////////////////////////////////
    logic [31:0] ff_input;  // either op_a_i or its bit reversed version
    logic [ 5:0] cnt_result;  // population count
    logic [ 5:0] clb_result;  // count leading bits
    logic [ 4:0] ff1_result;  // holds the index of the first '1'
    logic        ff_no_one;  // if no ones are found
    logic [ 4:0] fl1_result;  // holds the index of the last '1'
    logic [ 5:0] bitop_result;  // result of all bitop operations muxed together
    /////////////////////////////////////////////////////////////////////
    mrv1_popcnt popcnt_i (
        .in_i       (exec_src0_data_i),
        .result_o   (cnt_result)
    );
    ////////////////////////////////////////////////
    always_comb begin
        ff_input = '0;
        case (int_fu_opc_i)
            MRV_INT_FU_FF1:
            begin
                ff_input = exec_src0_data_i;
            end
            MRV_INT_FU_FL1:
            begin
                ff_input = exec_src0_data_rev;
            end
            MRV_INT_FU_CLB:
            begin
                if (exec_src0_data_i[31]) begin
                    ff_input = exec_src0_data_neg_rev;
                end
                else begin
                    ff_input = exec_src0_data_rev;
                end
            end
        endcase
    end
    /////////////////////////////////////////////////////////////////////////////////

    xrv_ff_one #(
        .DATA_WIDTH_P   (DATA_WIDTH_P)
    ) ff_one_i (
        .in_i           (ff_input),
        .first_one_o    (ff1_result),
        .no_ones_o      (ff_no_one)
    );

    /////////////////////////////////////////////////////////////////////////////////
    // special case if ff1_res is 0 (no 1 found), then we keep the 0
    // this is done in the result mux
    /////////////////////////////////////////////////////////////////////////////////
    assign fl1_result = 5'd31 - ff1_result;
    assign clb_result = ff1_result - 5'd1;
    /////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        bitop_result = '0;
        case (int_fu_opc_i)
            MRV_INT_FU_FF1:
                bitop_result = ff_no_one ? 6'd32 : {1'b0, ff1_result};
            MRV_INT_FU_FL1:
                bitop_result = ff_no_one ? 6'd32 : {1'b0, fl1_result};
            MRV_INT_FU_CNT:
                bitop_result = cnt_result;
            MRV_INT_FU_CLB: begin
                if (ff_no_one) begin
                    if (exec_src0_data_i[31]) bitop_result = 6'd31;
                    else bitop_result = '0;
                end else begin
                    bitop_result = clb_result;
                end
            end
            default: ;
        endcase
    end
    /////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////
    // Bit Manipulation
    /////////////////////////////////////////////////////////////////////////////////
    logic extract_is_signed;
    logic extract_sign;
    logic [31:0] bmask_first, bmask_inv;
    logic [31:0] bextins_and;
    logic [31:0] bextins_result, bclr_result, bset_result;
    /////////////////////////////////////////////////////////////////////////////////
    // construct bit mask for insert/extract/bclr/bset
    // bmask looks like this 00..0011..1100..00
    /////////////////////////////////////////////////////////////////////////////////
    assign bmask_first       = {32'hFFFFFFFE} << int_fu_bmask0_i;
    assign bmask             = (~bmask_first) << int_fu_bmask1_i;
    assign bmask_inv         = ~bmask;
    assign bextins_and       = (int_fu_opc_i == MRV_INT_FU_BINS) ? exec_src2_data_i : {32{extract_sign}};
    assign extract_is_signed = (int_fu_opc_i == MRV_INT_FU_BEXT);
    assign extract_sign      = extract_is_signed & shift_result[int_fu_bmask0_i];
    assign bextins_result    = (bmask & shift_result) | (bextins_and & bmask_inv);
    assign bclr_result       = exec_src0_data_i & bmask_inv;
    assign bset_result       = exec_src0_data_i | bmask;
    /////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////
    // Bit Reverse
    /////////////////////////////////////////////////////////////////////////////////
    logic [31:0] radix_2_rev;
    logic [31:0] radix_4_rev;
    logic [31:0] radix_8_rev;
    logic [31:0] reverse_result;
    logic [ 1:0] radix_mux_sel;
    /////////////////////////////////////////////////////////////////////////////////
    assign radix_mux_sel = int_fu_bmask0_i[1:0];
    generate
        /////////////////////////////////////////////////////////////////////////////////
        // radix-2 bit reverse
        /////////////////////////////////////////////////////////////////////////////////
        for (j = 0; j < 32; j++) begin : gen_radix_2_rev
            assign radix_2_rev[j] = shift_result[31-j];
        end
        /////////////////////////////////////////////////////////////////////////////////
        // radix-4 bit reverse
        /////////////////////////////////////////////////////////////////////////////////
        for (j = 0; j < 16; j++) begin : gen_radix_4_rev
            assign radix_4_rev[2*j+1:2*j] = shift_result[31-j*2:31-j*2-1];
        end
        /////////////////////////////////////////////////////////////////////////////////
        // radix-8 bit reverse
        /////////////////////////////////////////////////////////////////////////////////
        for (j = 0; j < 10; j++) begin : gen_radix_8_rev
            assign radix_8_rev[3*j+2:3*j] = shift_result[31-j*3:31-j*3-2];
        end
        assign radix_8_rev[31:30] = 2'b0;
    endgenerate
    /////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        reverse_result = '0;
        unique case (radix_mux_sel)
            2'b00:      reverse_result = radix_2_rev;
            2'b01:      reverse_result = radix_4_rev;
            2'b10:      reverse_result = radix_8_rev;
            default:    reverse_result = radix_2_rev;
        endcase
    end
    /////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////
    // Result MUX
    ////////////////////////////////////////////////////////
    always_comb begin
        int_fu_res_o = '0;
        ////////////////////////////////////////////////////////
        unique case (int_fu_opc_i)
            ////////////////////////////////////////////////////////
            // Standard Operations
            ////////////////////////////////////////////////////////
            MRV_INT_FU_AND: int_fu_res_o = exec_src0_data_i & exec_src1_data_i;
            MRV_INT_FU_OR:  int_fu_res_o = exec_src0_data_i | exec_src1_data_i;
            MRV_INT_FU_XOR: int_fu_res_o = exec_src0_data_i ^ exec_src1_data_i;
            ////////////////////////////////////////////////////////
            // Shift Operations
            ////////////////////////////////////////////////////////
            MRV_INT_FU_ADD,
            MRV_INT_FU_ADDR,
            MRV_INT_FU_ADDU,
            MRV_INT_FU_ADDUR,
            MRV_INT_FU_SUB,
            MRV_INT_FU_SUBR,
            MRV_INT_FU_SUBU,
            MRV_INT_FU_SUBUR,
            MRV_INT_FU_SLL,
            MRV_INT_FU_SRL,
            MRV_INT_FU_SRA,
            MRV_INT_FU_ROR:
            begin
                int_fu_res_o = shift_result;
            end
            ////////////////////////////////////////////////////////
            // bit manipulation instructions
            ////////////////////////////////////////////////////////
            MRV_INT_FU_BINS,
            MRV_INT_FU_BEXT,
            MRV_INT_FU_BEXTU:
            begin
                int_fu_res_o = bextins_result;
            end
            ////////////////////////////////////////////////////////
            MRV_INT_FU_BCLR: int_fu_res_o = bclr_result;
            MRV_INT_FU_BSET: int_fu_res_o = bset_result;
            ////////////////////////////////////////////////////////
            // Bit reverse instruction
            ////////////////////////////////////////////////////////
            MRV_INT_FU_BREV: int_fu_res_o = reverse_result;
            ////////////////////////////////////////////////////////
            // pack and shuffle operations
            ////////////////////////////////////////////////////////
            MRV_INT_FU_SHUF,
            MRV_INT_FU_SHUF2,
            MRV_INT_FU_PCKLO,
            MRV_INT_FU_PCKHI,
            MRV_INT_FU_EXT,
            MRV_INT_FU_EXTS,
            MRV_INT_FU_INS:
            begin
                int_fu_res_o = pack_result;
            end
            ////////////////////////////////////////////////////////
            // Min/Max/Ins
            ////////////////////////////////////////////////////////
            MRV_INT_FU_MIN,
            MRV_INT_FU_MINU,
            MRV_INT_FU_MAX,
            MRV_INT_FU_MAXU:
            MRV_INT_FU_ABS:
            begin
                int_fu_res_o = result_minmax;
            end
            ////////////////////////////////////////////////////////
            MRV_INT_FU_CLIP,
            MRV_INT_FU_CLIPU:
            begin
                int_fu_res_o = clip_result;
            end
            ////////////////////////////////////////////////////////
            // Comparison Operations
            ////////////////////////////////////////////////////////
            MRV_INT_FU_EQ,
            MRV_INT_FU_NE,
            MRV_INT_FU_GTU,
            MRV_INT_FU_GEU,
            MRV_INT_FU_LTU,
            MRV_INT_FU_LEU,
            MRV_INT_FU_GTS,
            MRV_INT_FU_GES,
            MRV_INT_FU_LTS,
            MRV_INT_FU_LES:
            begin
                int_fu_res_o[31:24] = {8{cmp_result[3]}};
                int_fu_res_o[23:16] = {8{cmp_result[2]}};
                int_fu_res_o[15:8]  = {8{cmp_result[1]}};
                int_fu_res_o[7:0]   = {8{cmp_result[0]}};
            end
            ////////////////////////////////////////////////////////
            // Non-vector comparisons
            ////////////////////////////////////////////////////////
            MRV_INT_FU_SLTS,
            MRV_INT_FU_SLTU,
            MRV_INT_FU_SLETS,
            MRV_INT_FU_SLETU:
            begin
                int_fu_res_o = {31'b0, comparison_result_w};
            end
            ////////////////////////////////////////////////////////
            MRV_INT_FU_FF1,
            MRV_INT_FU_FL1,
            MRV_INT_FU_CLB,
            MRV_INT_FU_CNT:
                int_fu_res_o = {26'h0, bitop_result[5:0]};
            ////////////////////////////////////////////////////////
            default: ;  // default case to suppress unique warning
        endcase
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Conditional branch handling
    ////////////////////////////////////////////////////////////////////////////////
    assign b_pc_vld_o = int_fu_req_i & b_is_branch_i & ~comparison_result_w;
    assign b_pc_o = exec_pc_i + exec_src0_data_i;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (int_fu_req_i & b_is_branch_i) begin
            $display("next_pc_i=%h taken=%d", b_pc_o, comparison_result_w);
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule
