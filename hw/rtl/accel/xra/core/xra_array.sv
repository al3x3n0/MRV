module xra_array
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter VX_NUM_WARPS_P        = "inv",
    parameter VX_NUM_THREADS_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter VX_NUM_LANES_P        = VX_NUM_THREADS_P,
    parameter VX_ISSUE_WIDTH_P      = (VX_NUM_WARPS_P / 8),
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_COLS_P            = VX_NUM_LANES_P,
    parameter NUM_ROWS_P            = VX_ISSUE_WIDTH_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter VX_NUM_LSU_BLOCKS_P   = "inv"
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                clk_i,
    input  logic                rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                imem_wr_en_i,
    input  logic                imem_rd_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    // VX -> XRA
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                vx_mode_en_i,
    xrv_vx_lsu_mem_if.master    vx_lsu_mem_if [VX_NUM_LSU_BLOCKS_P],
    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_dispatch_if.slave    vx_int_dispatch_if [VX_ISSUE_WIDTH_P],
    xrv_vx_commit_if.master     vx_int_commit_if [VX_ISSUE_WIDTH_P],
    ////////////////////////////////////////////////////////////////////////////////
    xrv_vx_dispatch_if.slave    vx_lsu_dispatch_if [VX_ISSUE_WIDTH_P],
    xrv_vx_commit_if.master     vx_lsu_commit_if [VX_ISSUE_WIDTH_P]
);
    ////////////////////////////////////////////////////////////////////////////////
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]  cell_data_lo;
    logic [NUM_ROWS_P-1:0][NUM_COLS_P-1:0]  cell_flags_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [-1:NUM_COLS_P][XLEN_P-1:0]       mesh_data_w  [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P]                   mesh_data_vld_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P]                   mesh_data_rdy_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P][XLEN_P-1:0]       mesh_flags_w [-1:NUM_ROWS_P];
    logic [-1:NUM_COLS_P]                   mesh_flags_vld_w [-1:NUM_ROWS_P];   


    ////////////////////////////////////////////////////////////////////////////////
    // Reconfigurable Cells
    ////////////////////////////////////////////////////////////////////////////////
    generate
        for (i = 0; i < NUM_ROWS_P; i++) begin
            for (j = 0; j < NUM_COLS_P; j++) begin
                xra_rcell #(
                    ////////////////////////////////////////////////////////////////////////////////
                    .ROW_ID_P               (i),
                    .COL_ID_P               (j),
                    ////////////////////////////////////////////////////////////////////////////////
                    .NUM_THREADS_P          (NUM_THREADS_P),
                    .XLEN_P                 (XLEN_P)
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
                    
                    ////////////////////////////////////////////////////////////////////////////////
                );
            end
        end  
    endgenerate

endmodule