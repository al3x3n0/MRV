module xrv1_ialigner
(
    ////////////////////////////////////////////////////////////////////////////////
    input logic [31:0]      i_data_0_i,
    input logic             i_data_0_vld_i,
    input logic [31:0]      i_data_1_i,
    input logic             i_data_1_vld_i,
    input logic             unalgn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [31:0]     i_data_o,
    output logic            i_data_vld_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (unalgn_pc_i) begin
            i_data_o = { i_data_1_i[15:0], i_data_0_i[31:16] };
            if (i_data_0_i[17:16] == 2'b11)
                i_data_vld_o = i_data_0_vld_i & i_data_1_vld_i;
            else
                i_data_vld_o = i_data_0_vld_i;
        end
        else begin
            i_data_o = i_data_0_i;
            i_data_vld_o = i_data_0_vld_i;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule