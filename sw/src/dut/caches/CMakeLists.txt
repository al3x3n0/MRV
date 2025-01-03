set(CACHE_RTL_SRC_DIR "${RTL_SRC_DIR}/subsystems/vortex_cache")
set(CACHE_RTL_INC_DIR "${RTL_SRC_DIR}/inc/subsystems/vortex_cache")

set(VERILATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/verilated_caches")

file(GLOB XRV_CACHE_SV_SRC
    "${CACHE_RTL_SRC_DIR}/*.sv"
    "${RTL_SRC_DIR}/common/arb/*.sv"
    "${RTL_SRC_DIR}/common/buffers/*.sv"
    "${RTL_SRC_DIR}/common/utils/*.sv"
    "${RTL_SRC_DIR}/common/stream/*.sv"
    "${RTL_SRC_DIR}/common/mem/*.sv"
    "${RTL_SRC_DIR}/common/comm/*.sv")

add_library(verilated_cache SHARED)
verilate(verilated_cache
    ""
    COVERAGE
    TRACE
    TOP_MODULE "xrv_cache_top"
    PREFIX "${VERILATOR_PREFIX_NAME}"
    SOURCES ${XRV_CACHE_SV_SRC}
    VERILATOR_ARGS "${VERILATOR_EXTRA_ARGS}"
    INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/hw/" "${RTL_SRC_DIR}/inc" "${RTL_SRC_DIR}/caches"
)
