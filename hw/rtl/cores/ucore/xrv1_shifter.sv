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

    logic shifting_bit;
    assign shifting_bit = (lshift_i) ? 0 :
                          (arith_i)  ? data_i[DATA_WIDTH_P-1] :
                                       0;

    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        foreach (data_i[i])
            rev_data_r[i] = data_i[DATA_WIDTH_P-1-i];
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//2
        case ({lshift_i, shamt_i[0]})
            0: shiftx1 = data_i[DATA_WIDTH_P-1:0];
            1: shiftx1 = {{1{shifting_bit}},data_i[DATA_WIDTH_P-1:1]};
            2: shiftx1 = rev_data_r[DATA_WIDTH_P-1:0];
            3: shiftx1 = {{1{shifting_bit}}, rev_data_r[DATA_WIDTH_P-1:1]};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//2
        case (shamt_i[2:1])
            0: shiftx2 = shiftx1[DATA_WIDTH_P-1:0];
            1: shiftx2 = {{2{shifting_bit}},shiftx1[DATA_WIDTH_P-1:2]};
            2: shiftx2 = {{4{shifting_bit}},shiftx1[DATA_WIDTH_P-1:4]};
            3: shiftx2 = {{6{shifting_bit}},shiftx1[DATA_WIDTH_P-1:6]};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin//8
        case (shamt_i[4:3])
            0: shiftx8 = shiftx2[DATA_WIDTH_P-1:0];
            1: shiftx8 = {{8{shifting_bit}},shiftx2[DATA_WIDTH_P-1:8]};
            2: shiftx8 = {{16{shifting_bit}},shiftx2[DATA_WIDTH_P-1:16]};
            3: shiftx8 = {{24{shifting_bit}},shiftx2[DATA_WIDTH_P-1:24]};
        endcase
    end
    assign rshf_data_o = shiftx8;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        foreach (data_i[i])
            lshf_data_o[i] = shiftx8[DATA_WIDTH_P-1-i];
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule
