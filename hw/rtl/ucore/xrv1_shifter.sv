module xrv1_shifter
#(
    parameter DATA_WIDTH_P = 32
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]              data_i,
    input logic [4:0]                           shamt_i,
    input logic                                 arith_i,
    input logic                                 lshift_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]             rshf_data_o,
    output logic [DATA_WIDTH_P-1:0]             lshf_data_o
    ////////////////////////////////////////////////////////////////////////////////
);

    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0] shiftx8, shiftx2, shiftx1;
    logic [DATA_WIDTH_P-1:0] rev_data_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        foreach (data_i[i])
            rev_data_r[i] = data_i[31-i];
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//2
        case ({lshift_i, shamt_i[0]})
            0: shiftx1 = data_i[31:0];
            1: shiftx1 = {{1{arith_i}},data_i[31:1]};
            2: shiftx1 = rev_data_r[31:0];
            3: shiftx1 = {{1{arith_i}}, rev_data_r[31:1]};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//2
        case (shamt_i[2:1])
            0: shiftx2 = shiftx1[31:0];
            1: shiftx2 = {{2{arith_i}},shiftx1[31:2]};
            2: shiftx2 = {{4{arith_i}},shiftx1[31:4]};
            3: shiftx2 = {{6{arith_i}},shiftx1[31:6]};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//8
        case (shamt_i[4:3])
            0: shiftx8 = shiftx2[31:0];
            1: shiftx8 = {{8{arith_i}},shiftx2[31:8]};
            2: shiftx8 = {{16{arith_i}},shiftx2[31:16]};
            3: shiftx8 = {{24{arith_i}},shiftx2[31:24]};
        endcase
    end
    assign rshf_data_o = shiftx8;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        foreach (data_i[i])
            lshf_data_o[i] = shiftx8[31-i];
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule