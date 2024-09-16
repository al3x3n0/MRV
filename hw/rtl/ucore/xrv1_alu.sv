import xrv1_pkg::*;

module xrv1_alu
#(
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = "inv"
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     alu_req_i,
    output logic                                    alu_rdy_o,
    input logic [XRV_ALU_OP_WIDTH-1:0]              alu_opc_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]                  alu_src0_i,
    input logic [DATA_WIDTH_P-1:0]                  alu_src1_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                    alu_done_o,
    output logic [DATA_WIDTH_P-1:0]                 alu_res_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [ITAG_WIDTH_P-1:0]                  alu_itag_i,
    output logic [ITAG_WIDTH_P-1:0]                 alu_itag_o,
    ////////////////////////////////////////////////////////////////////////////////
    // ALU -> BRANCH
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                    alu_cmp_res_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    assign alu_rdy_o     = 1'b1;
    assign alu_done_o    = alu_req_i;
    assign alu_itag_o    = alu_itag_i;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Add/Sub
    ////////////////////////////////////////////////////////////////////////////////
    wire sub_w = alu_opc_i inside {
        XRV_ALU_SUB,
        XRV_ALU_LTU, XRV_ALU_LTS,
        XRV_ALU_GEU, XRV_ALU_GES,
        XRV_ALU_SLTU, XRV_ALU_SLTS};
    wire unsigned_w = alu_opc_i inside {XRV_ALU_SLTU, XRV_ALU_LTU, XRV_ALU_GEU};
    ////////////////////////////////////////////////////////////////////////////////
    wire [32:0] adder_op0_w = {~unsigned_w & alu_src0_i[31], alu_src0_i};
    wire [32:0] tmp_adder_op1_w = {~unsigned_w & alu_src1_i[31], alu_src1_i};
    wire [32:0] adder_op1_w = sub_w ? ~tmp_adder_op1_w : tmp_adder_op1_w;
    wire [32:0] add_sub_res_w = adder_op0_w + adder_op1_w + {32'b0, sub_w};
    ////////////////////////////////////////////////////////////////////////////////

    logic [31:0] lshf_data_lo;
    logic [31:0] rshf_data_lo;

    xrv1_shifter shifter_i (
        .data_i         (alu_src0_i),
        .shamt_i        (alu_src1_i[4:0]),
        .arith_i        (alu_opc_i == XRV_ALU_SRA),
        .lshift_i       (alu_opc_i == XRV_ALU_SLL),
        .lshf_data_o    (lshf_data_lo),
        .rshf_data_o    (rshf_data_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Logic ops
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] alu_or_w  = alu_src0_i | alu_src1_i;
    wire [31:0] alu_xor_w = alu_src0_i ^ alu_src1_i;
    wire [31:0] alu_and_w = alu_src0_i & alu_src1_i;
    ////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        $display("alu_opc=%d alu_src0_i=%h alu_src1_i=%h alu_cmp_res_o=%d",
            alu_opc_i, alu_src0_i, alu_src1_i, alu_cmp_res_o);
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Comparison ops
    ////////////////////////////////////////////////////////////////////////////////
    wire alu_neq_w  = (|alu_xor_w);
    ////////////////////////////////////////////////////////////////////////////////
        always_comb begin
        case (alu_opc_i)
            XRV_ALU_EQ:  alu_cmp_res_o = ~alu_neq_w;
            XRV_ALU_NE:  alu_cmp_res_o = alu_neq_w;
            XRV_ALU_LTS: alu_cmp_res_o = add_sub_res_w[32];
            XRV_ALU_LTU: alu_cmp_res_o = add_sub_res_w[32];
            XRV_ALU_GES: alu_cmp_res_o = ~add_sub_res_w[32] | ~alu_neq_w;
            XRV_ALU_GEU: alu_cmp_res_o = ~add_sub_res_w[32] | ~alu_neq_w;
            default: alu_cmp_res_o = '0;
        endcase
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Result mux
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (alu_opc_i)
            XRV_ALU_ADD:     alu_res_o = add_sub_res_w[31:0];
            XRV_ALU_SUB:     alu_res_o = add_sub_res_w[31:0];
            XRV_ALU_SLTU:    alu_res_o = {31'b0, add_sub_res_w[32]};
            XRV_ALU_AND:     alu_res_o = alu_and_w;
            XRV_ALU_OR:      alu_res_o = alu_or_w;
            XRV_ALU_XOR:     alu_res_o = alu_xor_w;
            XRV_ALU_SLL:     alu_res_o = lshf_data_lo;
            XRV_ALU_SRA:     alu_res_o = rshf_data_lo;
            XRV_ALU_SRL:     alu_res_o = rshf_data_lo;
            default:         alu_res_o = '0;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule
