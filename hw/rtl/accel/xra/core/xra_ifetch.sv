module xra_ifetch
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 8,
    parameter INSTR_WIDTH_P = 32
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        clk_i,
    input  logic                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        imem_wr_en_i,
    input  logic [PC_WIDTH_P-1:0]       imem_wr_addr_i,
    input  logic [INSTR_WIDTH_P-1:0]    imem_wr_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [INSTR_WIDTH_P-1:0]    instr_data_o,
    output logic [PC_WIDTH_P-1:0]       instr_pc_o,
    output logic                        instr_vld_o
);

    logic [PC_WIDTH_P-1:0] pc_r, pc_n;
    always_comb begin
        pc_n = pc_r + 1'b1;
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
        end else begin
            pc_r <= pc_n;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    // IMem
    ////////////////////////////////////////////////////////////////////////////////
    logic [INSTR_WIDTH_P-1:0] imem_data_lo;
    xrv_mem_r1w1 #(
        .DEPTH_P                    (PC_WIDTH_P**2),
        .DATA_WIDTH_P               (INSTR_WIDTH_P)
    ) imem_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .rd_addr_i                  (pc_r),
        .rd_data_o                  (imem_data_lo),
        .wr_en_i                    (imem_wr_en_i),
        .wr_addr_i                  (imem_wr_addr_i),
        .wr_data_i                  (imem_wr_data_i)
    );

endmodule