module xra_lrf
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter NUM_GPRS_P = 4,
    parameter NUM_PE_SRC_P = 2,
    ////////////////////////////////////////////////////////////////////////////////
    parameter RF_ADDR_WIDTH_LP = `XM_CLOG2(NUM_GPRS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            clk_i,
    input  logic                                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // -> Issue
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_PE_SRC_P-1:0][RF_ADDR_WIDTH_LP-1:0]   rs_addr_i,
    output logic [NUM_PE_SRC_P-1:0][DATA_WIDTH_P-1:0]       rs_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    // <- Writeback
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            rd_wr_en_i,
    input  logic [RF_ADDR_WIDTH_LP-1:0]                     rd_addr_i,                           
    input  logic [DATA_WIDTH_P-1:0]                         rd_data_i
);

    logic [NUM_GPRS_P-1:0][DATA_WIDTH_P-1:0] rf_mem;

    for (int i = 0; i < NUM_PE_SRC_P; i++) begin
        assign rs_data_o[i] = rf_mem[rs_addr_i[i]];
    end

    always_ff @(posedge clk_i) begin
        if (rd_wr_en_i) begin
            rf_mem[rd_addr_i] <= rd_data_i;
        end
    end

endmodule