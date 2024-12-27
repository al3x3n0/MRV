module xrv_mem_r1w1 #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DEPTH_P = "inv",
    parameter DATA_WIDTH_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ADDR_WIDTH_P = $clog2(DEPTH_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            clk_i,
    input  logic                            rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [ADDR_WIDTH_P-1:0]         rd_addr_i,
    output logic [DATA_WIDTH_P-1:0]         rd_data_o,
    input  logic                            wr_en_i,
    input  logic [ADDR_WIDTH_P-1:0]         wr_addr_i,
    input  logic [DATA_WIDTH_P-1:0]         wr_data_i
    ////////////////////////////////////////////////////////////////////////////////
);

    logic [ADDR_WIDTH_P-1:0][DATA_WIDTH_P-1:0] mem_q;

    always_ff @(posedge clk_i) begin
        if (wr_en_i) begin
            mem_q[wr_addr_i] <= wr_data_i;
        end
    end

    assign rd_data_o = mem_q[rd_addr_i];

endmodule