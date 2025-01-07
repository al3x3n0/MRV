get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
message("Calling cmake script for ${TB_NAME} target")

set(CACHE_RTL_SRC_DIR "${RTL_SRC_DIR}/subsystems/vortex_cache")
set(CACHE_RTL_INC_DIR "${RTL_SRC_DIR}/inc/subsystems/vortex_cache")

file(GLOB XRV_CACHE_SV_SRC
    "${CACHE_RTL_SRC_DIR}/*.sv"
    "${RTL_SRC_DIR}/common/arb/*.sv"
    "${RTL_SRC_DIR}/common/buffers/*.sv"
    "${RTL_SRC_DIR}/common/utils/*.sv"
    "${RTL_SRC_DIR}/common/stream/*.sv"
    "${RTL_SRC_DIR}/common/mem/*.sv"
    "${RTL_SRC_DIR}/common/comm/*.sv")

ADD_VERILATED_TARGET(
    "xrv_cache"
    "xrv_cache_top"
    "${XRV_CACHE_SV_SRC}"
    ""
    ""
    "${HW_SRC_DIR}/hw/;${RTL_SRC_DIR}/inc;${RTL_SRC_DIR}/caches"
    ""
    )