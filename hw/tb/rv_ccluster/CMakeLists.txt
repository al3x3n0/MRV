get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
message("Calling cmake script for ${TB_NAME} target")

set(CACHE_RTL_SRC_DIR "${RTL_SRC_DIR}/subsystems/vortex_cache")
set(CACHE_RTL_INC_DIR "${RTL_SRC_DIR}/inc/subsystems/vortex_cache")

set(CCLUSTER_RTL_SRC_DIR "${RTL_SRC_DIR}/subsystems/xrv_cores_cluster")

set(MRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(MRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/mtcore")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/ucore")
set(MRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

file(GLOB XRV_CCLUSTER_SV_SRC
    "${CCLUSTER_RTL_SRC_DIR}/*.sv"
    "${CACHE_RTL_SRC_DIR}/*.sv"
    "${RTL_SRC_DIR}/common/*.sv"
    "${RTL_SRC_DIR}/common/arb/*.sv"
    "${RTL_SRC_DIR}/common/axi/*.sv"
    "${RTL_SRC_DIR}/common/buffers/*.sv"
    "${RTL_SRC_DIR}/common/utils/*.sv"
    "${RTL_SRC_DIR}/common/stream/*.sv"
    "${RTL_SRC_DIR}/common/mem/*.sv"
    "${RTL_SRC_DIR}/common/comm/*.sv"
    ###############################################################################
    "${MRV1_TB_SRC_DIR}/*.sv"
    "${MRV1_RTL_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_ialigner.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_ifq.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_iqueue.sv"    
    )   

#ADD_VERILATED_TARGET(
#    "xrv_ccluster"
#    "xrv_cores_cluster_axi"
#    "${XRV_CCLUSTER_SV_SRC}"
#    ""
#    ""
#    "${HW_SRC_DIR}/hw/;${RTL_SRC_DIR}/inc;${RTL_SRC_DIR}/caches"
#    ""
#    )