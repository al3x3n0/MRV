module mrv1_tw_ctl
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_TW_P = 8,
    parameter num_lanes_p = 4,
    parameter num_barriers_p = 8,
    parameter ITAG_WIDTH_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter wid_width_lp = $clog2(NUM_TW_P),
    parameter barrier_id_width_lp = $clog2(num_barriers_p)
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                            tw_ctl_req_i,
    output logic                                            tw_ctl_rdy_o,
    input  xrv_tw_ctl_op_e                                  tw_ctl_opc_i,
    output logic                                            tw_ctl_done_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [31:0]                                     tw_ctl_src0_i,
    input  logic [31:0]                                     tw_ctl_src1_i,
    output logic [31:0]                                     tw_ctl_wb_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    output  logic                                           tw_ctl_wspawn_vld_i,
    output  logic [NUM_TW_P-1:0]                            tw_ctl_wspawn_wmask_i,
    output  logic [31:0]                                    tw_ctl_wspawn_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output  logic                                           tw_ctl_split_vld_i,
    output  logic                                           tw_ctl_split_diverged_i,
    output  logic [num_lanes_p-1:0]                         tw_ctl_split_then_mask_i,
    output  logic [num_lanes_p-1:0]                         tw_ctl_split_else_mask_i,
    output  logic [31:0]                                    tw_ctl_split_pc_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                            tw_ctl_barrier_vld_i,
    output logic [barrier_id_width_lp-1:0]                  tw_ctl_barrier_id_i,
    output logic [wid_width_lp-1:0]                         tw_ctl_barrier_size_m1_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [ITAG_WIDTH_P-1:0]                         tw_ctl_itag_i,
    output logic [ITAG_WIDTH_P-1:0]                         tw_ctl_itag_o
    ////////////////////////////////////////////////////////////////////////////////
);

endmodule