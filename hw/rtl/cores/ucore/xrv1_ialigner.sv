module xrv1_ialigner
#(
    parameter XLEN_P = 32
)
(
    ////////////////////////////////////////////////////////////////////////////////
    input logic [XLEN_P-1:0]      i_data_0_i,
    input logic             i_data_0_vld_i,
    input logic [XLEN_P-1:0]      i_data_1_i,
    input logic             i_data_1_vld_i,
    input logic             unalgn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [XLEN_P-1:0]     i_data_o,
    output logic            i_data_vld_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (unalgn_pc_i) begin
            i_data_o = {{(XLEN_P-32){1'b0}}, i_data_1_i[15:0], i_data_0_i[31:16] };
            if (i_data_0_i[17:16] == 2'b11)
                i_data_vld_o = i_data_0_vld_i & i_data_1_vld_i;
            else
                i_data_vld_o = i_data_0_vld_i;
        end
        else begin
            i_data_o = i_data_0_i;
            i_data_vld_o = i_data_0_vld_i;
            $display("[IALIGNER] data0 %x data1 %x final data %x", i_data_0_i, i_data_1_i, i_data_o);
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

endmodule