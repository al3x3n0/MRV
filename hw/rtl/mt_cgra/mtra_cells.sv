module mtra_cells
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_COLS_P = 8,
    parameter NUM_ROWS_P = 8
    ////////////////////////////////////////////////////////////////////////////////
    parameter BE_WIDTH_LP = DATA_WIDTH_P / 8
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                                clk_i,
    input  logic                                                rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                                imem_wr_en_i,
    input  logic                                                imem_rd_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_COLS_P-1:0]                               dmem_req_vld_o,
    input  logic [NUM_COLS_P-1:0]                               dmem_req_rdy_i,
    output logic [NUM_COLS_P-1:0][DMEM_TAG_WIDTH_P-1:0]         dmem_req_tag_o,
    input  logic [NUM_COLS_P-1:0]                               dmem_resp_err_i,
    output logic [NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_req_addr_o,
    output logic [NUM_COLS_P-1:0]                               dmem_req_w_en_o,
    output logic [NUM_COLS_P-1:0][BE_WIDTH_LP-1:0]              dmem_req_w_be_o,
    output logic [NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_req_w_data_o,
    input  logic [NUM_COLS_P-1:0]                               dmem_resp_vld_i,
    input  logic [NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_resp_r_data_i,
    input  logic [NUM_COLS_P-1:0][DMEM_TAG_WIDTH_P-1:0]         dmem_resp_tag_i,
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0] cell_data_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0] cell_flags_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [-1:NUM_COLS_P][NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]  mesh_data_w  [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P][NUM_THREADS_P-1:0]                    mesh_data_vld_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P][NUM_THREADS_P-1:0]                    mesh_data_rdy_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P][NUM_THREADS_P-1:0][DATA_WIDTH_P-1:0]  mesh_flags_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P][NUM_THREADS_P-1:0]                    mesh_flags_vld_w [-1:NUM_ROWS_P];   

    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]                               dmem_req_vld_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]                               dmem_req_rdy_li;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][DMEM_TAG_WIDTH_P-1:0]         dmem_req_tag_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_req_addr_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]                               dmem_req_w_en_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][BE_WIDTH_LP-1:0]              dmem_req_w_be_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_req_w_data_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]                               dmem_resp_vld_li;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][DATA_WIDTH_P-1:0]             dmem_resp_r_data_li;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0][DMEM_TAG_WIDTH_P-1:0]         dmem_resp_tag_li;

    ////////////////////////////////////////////////////////////////////////////////
    // Reconfigurable Cells
    ////////////////////////////////////////////////////////////////////////////////
    generate
        for (i = 0; i < NUM_ROWS_P; i++) begin
            for (j = 0; j < NUM_COLS_P; j++) begin
                mtra_rcell #(
                    ////////////////////////////////////////////////////////////////////////////////
                    .ROW_ID_P               (i),
                    .COL_ID_P               (j),
                    ////////////////////////////////////////////////////////////////////////////////
                    .NUM_THREADS_P          (NUM_THREADS_P),
                    .DATA_WIDTH_P           (DATA_WIDTH_P)
                ) rc_i (
                    .clk_i                  (clk_i),
                    .rst_i                  (rst_i),
                    ////////////////////////////////////////////////////////////////////////////////
                    .own_data_i             (mesh_data_w[i][j]),
                    .left_data_i            (mesh_data_w[i][j-1]),
                    .right_data_i           (mesh_data_w[i][j+1]),
                    .top_data_i             (mesh_data_w[i-1][j]),
                    .bottom_data_i          (mesh_data_w[i+1][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .own_flags_i            (mesh_flags_w[i][j]),
                    .left_flags_i           (mesh_flags_w[i][j-1]),
                    .right_flags_i          (mesh_flags_w[i][j+1]),
                    .top_flags_i            (mesh_flags_w[i-1][j]),
                    .bottom_flags_i         (mesh_flags_w[i+1][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .own_data_vld_i         (mesh_data_vld_w[i][j]),
                    .left_data_vld_i        (mesh_data_vld_w[i][j-1]),
                    .right_data_vld_i       (mesh_data_vld_w[i][j+1]),
                    .top_data_vld_i         (mesh_data_vld_w[i-1][j]),
                    .bottom_data_vld_i      (mesh_data_vld_w[i+1][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .own_data_vld_i         (mesh_data_vld_w[i][j]),
                    .left_data_vld_i        (mesh_data_vld_w[i][j-1]),
                    .right_data_vld_i       (mesh_data_vld_w[i][j+1]),
                    .top_data_vld_i         (mesh_data_vld_w[i-1][j]),
                    .bottom_data_vld_i      (mesh_data_vld_w[i+1][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .own_flags_vld_i        (mesh_flags_vld_w[i][j]),
                    .left_flags_vld_i       (mesh_flags_vld_w[i][j-1]),
                    .right_flags_vld_i      (mesh_flags_vld_w[i][j+1]),
                    .top_flags_vld_i        (mesh_flags_vld_w[i-1][j]),
                    .bottom_flags_vld_i     (mesh_flags_vld_w[i+1][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .data_o                 (cell_data_lo[i][j]),
                    .flags_o                (cell_flags_lo[i][j]),
                    ////////////////////////////////////////////////////////////////////////////////
                    .dmem_req_vld_o         (dmem_req_vld_lo[i][j]),
                    .dmem_req_rdy_i         (dmem_req_rdy_li[i][j]),
                    .dmem_req_tag_o         (dmem_req_tag_lo[i][j]),
                    .dmem_resp_err_i        (),
                    .dmem_req_addr_o        (dmem_req_addr_lo[i][j]),
                    .dmem_req_w_en_o        (dmem_req_w_en_lo[i][j]),
                    .dmem_req_w_be_o        (dmem_req_w_be_lo[i][j]),
                    .dmem_req_w_data_o      (dmem_req_w_data_lo[i][j]),
                    .dmem_resp_vld_i        (dmem_resp_vld_li[i][j]),
                    .dmem_resp_r_data_i     (dmem_resp_r_data_li[i][j]),
                    .dmem_resp_tag_i        (dmem_resp_tag_li[i][j])
                    ////////////////////////////////////////////////////////////////////////////////
                );
            end
        end  
    endgenerate

endmodule