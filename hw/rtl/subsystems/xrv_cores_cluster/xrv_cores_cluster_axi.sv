// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "subsystems/vortex_cache/defines.svh"
`include "subsystems/xrv_ccluster/defines.svh"
`include "xm_macro.svh"


module xrv_cores_cluster_axi #(
    ///////////////////////////////////////////////////////////////////////////////
    // Core configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P         = 8,
    parameter XLEN_P                = 32,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P          = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Socket configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_SOCKETS_P         = 4,
    parameter SOCKET_SIZE_P         = 4,
    ////////////////////////////////////////////////////////////////////////////////
    parameter L1D_NUM_REQS_P        = 1, // FIXME
    parameter L1D_NUM_BANKS_P       = `XM_MIN(L1D_NUM_REQS_P, 16),
    parameter L1_NUM_MEM_PORTS_P    = `XM_MIN(L1D_NUM_BANKS_P, `PLATFORM_MEMORY_BANKS),
    parameter L2_NUM_REQS_P	        = NUM_SOCKETS_P * L1_NUM_MEM_PORTS_P,
    parameter L1_LINE_SIZE_P        = 64,
    parameter L2_WORD_SIZE_P	    = L1_LINE_SIZE_P,
    ////////////////////////////////////////////////////////////////////////////////
    // L2 Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter L2_LINE_SIZE_P        = 64,
    // Cache Size
    parameter L2_CACHE_SIZE_P       = 1048576,
    // Number of Banks
    parameter L2_NUM_BANKS_P        = `XM_MIN(L2_NUM_REQS_P, 16),
    // Core Response Queue Size
    parameter L2_CRSQ_SIZE_P        = 2,
    // Miss Handling Register Size
    parameter L2_MSHR_SIZE_P        = 16,
    // Memory Request Queue Size
    parameter L2_MREQ_SIZE_P        = 4,
    // Memory Response Queue Size
    parameter L2_MRSQ_SIZE_P        = 4,
    // Number of Associative Ways
    parameter L2_NUM_WAYS_P         = 8,
    // Enable Cache Writeback
    parameter L2_HAS_WRITEBACK_P    = 0,
    // Enable Cache Dirty bytes
    parameter L2_HAS_DIRTY_BYTES_P  = L2_HAS_WRITEBACK_P,
    // Replacement Policy
    parameter L2_REPL_POLICY_P      = 1,
    // Number of Memory Ports
    parameter L2_NUM_MEM_PORTS_P    = `XM_MIN(L2_NUM_BANKS_P, `PLATFORM_MEMORY_BANKS),
    ////////////////////////////////////////////////////////////////////////////////
    // L1D Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Cache Units
    parameter NUM_L1I_CACHES_P      = `XM_UP(SOCKET_SIZE_P / 4),
    // Cache Size
    parameter L1I_SIZE_P            = 16384,
    // Core Response Queue Size
    parameter L1I_CRSQ_SIZE_P       = 2,
    // Miss Handling Register Size
    parameter L1I_MSHR_SIZE_P       = 16,
    // Memory Request Queue Size
    parameter L1I_MREQ_SIZE_P       = 4,
    // Memory Response Queue Size
    parameter L1I_MRSQ_SIZE_P       = 0,
    // Number of Associative Ways
    parameter L1I_NUM_WAYS_P        = 4,
    // Replacement Policy
    parameter L1I_REPL_POLICY_P     = 1,
    parameter L1I_NUM_MEM_PORTS_P   = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // L1D Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Cache Units
    parameter NUM_L1D_CACHES_P      = `XM_UP(SOCKET_SIZE_P / 4),
    // Cache Size
    parameter L1D_SIZE_P            = 16384,
    // Core Response Queue Size
    parameter L1D_CRSQ_SIZE_P       = 2,
    // Miss Handling Register Size
    parameter L1D_MSHR_SIZE_P       = 16,
    // Memory Request Queue Size
    parameter L1D_MREQ_SIZE_P       = 4,
    // Memory Response Queue Size
    parameter L1D_MRSQ_SIZE_P       = 4,
    // Number of Associative Ways
    parameter L1D_NUM_WAYS_P        = 4,
    // Enable Cache Writeback
    parameter L1D_HAS_WRITEBACK_P   = 0,
    // Enable Cache Dirty bytes
    parameter L1D_HAS_DIRTY_BYTES_P = L1D_HAS_WRITEBACK_P,
    // Replacement Policy
    parameter L1D_REPL_POLICY_P     = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP          = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CCLUSTER_CACHE_LOCALPARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    // Cluster configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter CLUSTER_NUM_MEM_PORTS_P = L2_NUM_MEM_PORTS_P,
    parameter CLUSTER_MEM_TAG_WIDTH_P = `CACHE_NC_MEM_TAG_WIDTH(L2_MSHR_SIZE_P, L2_NUM_BANKS_P, L2_NUM_REQS_P, L2_NUM_MEM_PORTS_P, L2_LINE_SIZE_P, L2_WORD_SIZE_P, L2_TAG_WIDTH_LP, UUID_WIDTH_P),
    parameter CLUSTER_MEM_ADDR_WIDTH_P = (MEM_ADDR_WIDTH_P - `XM_CLOG2(L2_LINE_SIZE_P)),
    parameter CLUSTER_MEM_DATA_WIDTH_P = (L2_LINE_SIZE_P * 8),
    parameter CLUSTER_MEM_BYTEEN_WIDTH_P = L2_LINE_SIZE_P,
    ////////////////////////////////////////////////////////////////////////////////
    // AXI configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter AXI_DATA_WIDTH_P      = (L2_LINE_SIZE_P * 8),
    parameter AXI_ADDR_WIDTH_P      = MEM_ADDR_WIDTH_P,
    parameter AXI_TID_WIDTH_P       = CLUSTER_MEM_TAG_WIDTH_P,
    parameter AXI_NUM_BANKS_P       = 1
)(
    // Clock
    input  wire                         clk_i,
    input  wire                         rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // AXI write request address channel
    ////////////////////////////////////////////////////////////////////////////////
    output wire                         m_axi_awvld [AXI_NUM_BANKS_P],
    input wire                          m_axi_awrdy [AXI_NUM_BANKS_P],
    output wire [AXI_ADDR_WIDTH_P-1:0]    m_axi_awaddr [AXI_NUM_BANKS_P],
    output wire [AXI_TID_WIDTH_P-1:0]     m_axi_awid [AXI_NUM_BANKS_P],
    output wire [7:0]                   m_axi_awlen [AXI_NUM_BANKS_P],
    output wire [2:0]                   m_axi_awsize [AXI_NUM_BANKS_P],
    output wire [1:0]                   m_axi_awburst [AXI_NUM_BANKS_P],
    output wire [1:0]                   m_axi_awlock [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_awcache [AXI_NUM_BANKS_P],
    output wire [2:0]                   m_axi_awprot [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_awqos [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_awregion [AXI_NUM_BANKS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // AXI write request data channel
    ////////////////////////////////////////////////////////////////////////////////
    output wire                         m_axi_wvld [AXI_NUM_BANKS_P],
    input wire                          m_axi_wrdy [AXI_NUM_BANKS_P],
    output wire [AXI_DATA_WIDTH_P-1:0]    m_axi_wdata [AXI_NUM_BANKS_P],
    output wire [AXI_DATA_WIDTH_P/8-1:0]  m_axi_wstrb [AXI_NUM_BANKS_P],
    output wire                         m_axi_wlast [AXI_NUM_BANKS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // AXI write response channel
    ////////////////////////////////////////////////////////////////////////////////
    input wire                          m_axi_bvld [AXI_NUM_BANKS_P],
    output wire                         m_axi_brdy [AXI_NUM_BANKS_P],
    input wire [AXI_TID_WIDTH_P-1:0]      m_axi_bid [AXI_NUM_BANKS_P],
    input wire [1:0]                    m_axi_bresp [AXI_NUM_BANKS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // AXI read request channel
    ////////////////////////////////////////////////////////////////////////////////
    output wire                         m_axi_arvld [AXI_NUM_BANKS_P],
    input wire                          m_axi_arrdy [AXI_NUM_BANKS_P],
    output wire [AXI_ADDR_WIDTH_P-1:0]    m_axi_araddr [AXI_NUM_BANKS_P],
    output wire [AXI_TID_WIDTH_P-1:0]     m_axi_arid [AXI_NUM_BANKS_P],
    output wire [7:0]                   m_axi_arlen [AXI_NUM_BANKS_P],
    output wire [2:0]                   m_axi_arsize [AXI_NUM_BANKS_P],
    output wire [1:0]                   m_axi_arburst [AXI_NUM_BANKS_P],
    output wire [1:0]                   m_axi_arlock [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_arcache [AXI_NUM_BANKS_P],
    output wire [2:0]                   m_axi_arprot [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_arqos [AXI_NUM_BANKS_P],
    output wire [3:0]                   m_axi_arregion [AXI_NUM_BANKS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // AXI read response channel
    ////////////////////////////////////////////////////////////////////////////////
    input wire                          m_axi_rvld [AXI_NUM_BANKS_P],
    output wire                         m_axi_rrdy [AXI_NUM_BANKS_P],
    input wire [AXI_DATA_WIDTH_P-1:0]     m_axi_rdata [AXI_NUM_BANKS_P],
    input wire                          m_axi_rlast [AXI_NUM_BANKS_P],
    input wire [AXI_TID_WIDTH_P-1:0]      m_axi_rid [AXI_NUM_BANKS_P],
    input wire [1:0]                    m_axi_rresp [AXI_NUM_BANKS_P]
);
    localparam DST_LDATAW = `XM_CLOG2(AXI_DATA_WIDTH_P);
    localparam SRC_LDATAW = `XM_CLOG2(CLUSTER_MEM_DATA_WIDTH_P);
    localparam SUB_LDATAW = DST_LDATAW - SRC_LDATAW;
    localparam VX_MEM_TAG_A_WIDTH  = CLUSTER_MEM_TAG_WIDTH_P + `XM_MAX(SUB_LDATAW, 0);
    localparam VX_MEM_ADDR_A_WIDTH = CLUSTER_MEM_ADDR_WIDTH_P - SUB_LDATAW;

    wire                            mem_req_vld [CLUSTER_NUM_MEM_PORTS_P];
    wire                            mem_req_rw [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_BYTEEN_WIDTH_P-1:0] mem_req_be [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_ADDR_WIDTH_P-1:0]   mem_req_addr [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_DATA_WIDTH_P-1:0]   mem_req_data [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_TAG_WIDTH_P-1:0]    mem_req_tag [CLUSTER_NUM_MEM_PORTS_P];
    wire                            mem_req_rdy [CLUSTER_NUM_MEM_PORTS_P];

    wire                            mem_resp_vld [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_DATA_WIDTH_P-1:0]   mem_resp_data [CLUSTER_NUM_MEM_PORTS_P];
    wire [CLUSTER_MEM_TAG_WIDTH_P-1:0]    mem_resp_tag [CLUSTER_NUM_MEM_PORTS_P];
    wire                            mem_resp_rdy [CLUSTER_NUM_MEM_PORTS_P];

    xrv_cores_cluster_top #(
        ///////////////////////////////////////////////////////////////////////////////
        // Core configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_THREADS_P              (NUM_THREADS_P),
        .XLEN_P                     (XLEN_P),
        .MEM_ADDR_WIDTH_P           (MEM_ADDR_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .UUID_WIDTH_P               (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        // Socket configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_SOCKETS_P              (NUM_SOCKETS_P),
        .SOCKET_SIZE_P              (SOCKET_SIZE_P),
        ////////////////////////////////////////////////////////////////////////////////
        // L2 Cache configuration
        ////////////////////////////////////////////////////////////////////////////////
        .L2_LINE_SIZE_P             (L2_LINE_SIZE_P),
        .L2_CACHE_SIZE_P            (L2_CACHE_SIZE_P),
        .L2_NUM_BANKS_P             (L2_NUM_BANKS_P),
        .L2_CRSQ_SIZE_P             (L2_CRSQ_SIZE_P),
        .L2_MSHR_SIZE_P             (L2_MSHR_SIZE_P),
        .L2_MREQ_SIZE_P             (L2_MREQ_SIZE_P),
        .L2_MRSQ_SIZE_P             (L2_MRSQ_SIZE_P),
        .L2_NUM_WAYS_P              (L2_NUM_WAYS_P),
        .L2_HAS_WRITEBACK_P         (L2_HAS_WRITEBACK_P),
        .L2_HAS_DIRTY_BYTES_P       (L2_HAS_DIRTY_BYTES_P),
        .L2_REPL_POLICY_P           (L2_REPL_POLICY_P),
        .L2_NUM_MEM_PORTS_P         (L2_NUM_MEM_PORTS_P),
        ////////////////////////////////////////////////////////////////////////////////
        // L1D Cache configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_L1I_CACHES_P          (NUM_L1I_CACHES_P),
        .L1I_SIZE_P                (L1I_SIZE_P),
        .L1I_CRSQ_SIZE_P           (L1I_CRSQ_SIZE_P),
        .L1I_MSHR_SIZE_P           (L1I_MSHR_SIZE_P),
        .L1I_MREQ_SIZE_P           (L1I_MREQ_SIZE_P),
        .L1I_MRSQ_SIZE_P           (L1I_MRSQ_SIZE_P),
        .L1I_NUM_WAYS_P            (L1I_NUM_WAYS_P),
        .L1I_REPL_POLICY_P         (L1I_REPL_POLICY_P),
        .L1I_NUM_MEM_PORTS_P       (L1I_NUM_MEM_PORTS_P),
        ////////////////////////////////////////////////////////////////////////////////
        // L1D Cache configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_L1D_CACHES_P          (NUM_L1D_CACHES_P),
        .L1D_SIZE_P                (L1D_SIZE_P),
        .L1D_NUM_BANKS_P           (L1D_NUM_BANKS_P),
        .L1D_CRSQ_SIZE_P           (L1D_CRSQ_SIZE_P),
        .L1D_MSHR_SIZE_P           (L1D_MSHR_SIZE_P),
        .L1D_MREQ_SIZE_P           (L1D_MREQ_SIZE_P),
        .L1D_MRSQ_SIZE_P           (L1D_MRSQ_SIZE_P),
        .L1D_NUM_WAYS_P            (L1D_NUM_WAYS_P),
        .L1D_HAS_WRITEBACK_P       (L1D_HAS_WRITEBACK_P),
        .L1D_HAS_DIRTY_BYTES_P     (L1D_HAS_DIRTY_BYTES_P),
        .L1D_REPL_POLICY_P         (L1D_REPL_POLICY_P)
        ////////////////////////////////////////////////////////////////////////////////
    ) cluster_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .mem_req_vld                (mem_req_vld),
        .mem_req_rw                 (mem_req_rw),
        .mem_req_be             (mem_req_be),
        .mem_req_addr               (mem_req_addr),
        .mem_req_data               (mem_req_data),
        .mem_req_tag                (mem_req_tag),
        .mem_req_rdy                (mem_req_rdy),
        ////////////////////////////////////////////////////////////////////////////////
        .mem_resp_vld               (mem_resp_vld),
        .mem_resp_data              (mem_resp_data),
        .mem_resp_tag               (mem_resp_tag),
        .mem_resp_rdy               (mem_resp_rdy)
    );

    wire                                mem_req_vld_a [CLUSTER_NUM_MEM_PORTS_P];
    wire                                mem_req_rw_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [(AXI_DATA_WIDTH_P/8)-1:0]     mem_req_be_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [VX_MEM_ADDR_A_WIDTH-1:0]      mem_req_addr_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [AXI_DATA_WIDTH_P-1:0]         mem_req_data_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [VX_MEM_TAG_A_WIDTH-1:0]       mem_req_tag_a [CLUSTER_NUM_MEM_PORTS_P];
    wire                                mem_req_rdy_a [CLUSTER_NUM_MEM_PORTS_P];

    wire                                mem_resp_vld_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [AXI_DATA_WIDTH_P-1:0]         mem_resp_data_a [CLUSTER_NUM_MEM_PORTS_P];
    wire [VX_MEM_TAG_A_WIDTH-1:0]       mem_resp_tag_a [CLUSTER_NUM_MEM_PORTS_P];
    wire                                mem_resp_rdy_a [CLUSTER_NUM_MEM_PORTS_P];

    // Adjust memory data width to match AXI interface
    for (genvar i = 0; i < CLUSTER_NUM_MEM_PORTS_P; i++) begin : g_mem_adapter
        xrv_mem_data_adapter #(
            .SRC_DATA_WIDTH         (CLUSTER_MEM_DATA_WIDTH_P),
            .DST_DATA_WIDTH         (AXI_DATA_WIDTH_P),
            .SRC_ADDR_WIDTH         (CLUSTER_MEM_ADDR_WIDTH_P),
            .DST_ADDR_WIDTH         (VX_MEM_ADDR_A_WIDTH),
            .SRC_TAG_WIDTH          (CLUSTER_MEM_TAG_WIDTH_P),
            .DST_TAG_WIDTH          (VX_MEM_TAG_A_WIDTH),
            .REQ_OUT_BUF            (0),
            .RSP_OUT_BUF            (0)
        ) mem_data_adapter (
            ////////////////////////////////////////////////////////////////////////////////
            .clk_i                  (clk_i),
            .rst_i                  (rst_i),
            ////////////////////////////////////////////////////////////////////////////////
            .mem_req_vld_in         (mem_req_vld[i]),
            .mem_req_addr_in        (mem_req_addr[i]),
            .mem_req_rw_in          (mem_req_rw[i]),
            .mem_req_be_in      (mem_req_be[i]),
            .mem_req_data_in        (mem_req_data[i]),
            .mem_req_tag_in         (mem_req_tag[i]),
            .mem_req_rdy_in         (mem_req_rdy[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .mem_resp_vld_in        (mem_resp_vld[i]),
            .mem_resp_data_in       (mem_resp_data[i]),
            .mem_resp_tag_in        (mem_resp_tag[i]),
            .mem_resp_rdy_in        (mem_resp_rdy[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .mem_req_vld_out        (mem_req_vld_a[i]),
            .mem_req_addr_out       (mem_req_addr_a[i]),
            .mem_req_rw_out         (mem_req_rw_a[i]),
            .mem_req_be_out     (mem_req_be_a[i]),
            .mem_req_data_out       (mem_req_data_a[i]),
            .mem_req_tag_out        (mem_req_tag_a[i]),
            .mem_req_rdy_out        (mem_req_rdy_a[i]),
            ////////////////////////////////////////////////////////////////////////////////
            .mem_resp_vld_out       (mem_resp_vld_a[i]),
            .mem_resp_data_out      (mem_resp_data_a[i]),
            .mem_resp_tag_out       (mem_resp_tag_a[i]),
            .mem_resp_rdy_out       (mem_resp_rdy_a[i])
        );
    end

    xrv_axi_adapter #(
        .DATA_WIDTH_P       (AXI_DATA_WIDTH_P),
        .ADDR_WIDTH_IN_P    (VX_MEM_ADDR_A_WIDTH),
        .ADDR_WIDTH_OUT_P   (AXI_ADDR_WIDTH_P),
        .TAG_WIDTH_IN_P     (VX_MEM_TAG_A_WIDTH),
        .TAG_WIDTH_OUT_P    (AXI_TID_WIDTH_P),
        .NUM_PORTS_IN_P     (CLUSTER_NUM_MEM_PORTS_P),
        .NUM_BANKS_OUT_P    (AXI_NUM_BANKS_P),
        .INTERLEAVE_P       (0),
        .REQ_OUT_BUF        ((CLUSTER_NUM_MEM_PORTS_P > 1) ? 2 : 0),
        .RSP_OUT_BUF        ((CLUSTER_NUM_MEM_PORTS_P > 1 || AXI_NUM_BANKS_P > 1) ? 2 : 0)
    ) axi_adapter (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .mem_req_vld        (mem_req_vld_a),
        .mem_req_rw         (mem_req_rw_a),
        .mem_req_be     (mem_req_be_a),
        .mem_req_addr       (mem_req_addr_a),
        .mem_req_data       (mem_req_data_a),
        .mem_req_tag        (mem_req_tag_a),
        .mem_req_rdy        (mem_req_rdy_a),
        ////////////////////////////////////////////////////////////////////////////////
        .mem_resp_vld       (mem_resp_vld_a),
        .mem_resp_data      (mem_resp_data_a),
        .mem_resp_tag       (mem_resp_tag_a),
        .mem_resp_rdy       (mem_resp_rdy_a),
        ////////////////////////////////////////////////////////////////////////////////
        .m_axi_awvld        (m_axi_awvld),
        .m_axi_awrdy        (m_axi_awrdy),
        .m_axi_awaddr       (m_axi_awaddr),
        .m_axi_awid         (m_axi_awid),
        .m_axi_awlen        (m_axi_awlen),
        .m_axi_awsize       (m_axi_awsize),
        .m_axi_awburst      (m_axi_awburst),
        .m_axi_awlock       (m_axi_awlock),
        .m_axi_awcache      (m_axi_awcache),
        .m_axi_awprot       (m_axi_awprot),
        .m_axi_awqos        (m_axi_awqos),
        .m_axi_awregion     (m_axi_awregion),
        ////////////////////////////////////////////////////////////////////////////////
        .m_axi_wvld         (m_axi_wvld),
        .m_axi_wrdy         (m_axi_wrdy),
        .m_axi_wdata        (m_axi_wdata),
        .m_axi_wstrb        (m_axi_wstrb),
        .m_axi_wlast        (m_axi_wlast),
        ////////////////////////////////////////////////////////////////////////////////
        .m_axi_bvld         (m_axi_bvld),
        .m_axi_brdy         (m_axi_brdy),
        .m_axi_bid          (m_axi_bid),
        .m_axi_bresp        (m_axi_bresp),
        ////////////////////////////////////////////////////////////////////////////////
        .m_axi_arvld        (m_axi_arvld),
        .m_axi_arrdy        (m_axi_arrdy),
        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arid         (m_axi_arid),
        .m_axi_arlen        (m_axi_arlen),
        .m_axi_arsize       (m_axi_arsize),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_arlock       (m_axi_arlock),
        .m_axi_arcache      (m_axi_arcache),
        .m_axi_arprot       (m_axi_arprot),
        .m_axi_arqos        (m_axi_arqos),
        .m_axi_arregion     (m_axi_arregion),
        ////////////////////////////////////////////////////////////////////////////////
        .m_axi_rvld         (m_axi_rvld),
        .m_axi_rrdy         (m_axi_rrdy),
        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rlast        (m_axi_rlast),
        .m_axi_rid          (m_axi_rid),
        .m_axi_rresp        (m_axi_rresp)
    );

endmodule
