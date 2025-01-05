
get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
message("Calling cmake script for ${TB_NAME} target")

set(RV_IDECODER_VERILATOR_EXTRA_ARGS "")

###############################################################################
# process cmake options as top level parameters
set(RV_IDECODER_DEBUG_LEVEL "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GDEBUG_LEVEL=${RV_IDECODER_DEBUG_LEVEL}")

set(RV_IDECODER_RV_XLEN "32" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_XLEN=${RV_IDECODER_RV_XLEN}")

set(RV_IDECODER_RV_HAS_M_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_M_EXT=${RV_IDECODER_RV_HAS_M_EXT}")

set(RV_IDECODER_RV_HAS_A_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_A_EXT=${RV_IDECODER_RV_HAS_A_EXT}")

set(RV_IDECODER_RV_HAS_F_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_F_EXT=${RV_IDECODER_RV_HAS_F_EXT}")

set(RV_IDECODER_RV_HAS_D_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_D_EXT=${RV_IDECODER_RV_HAS_D_EXT}")

set(RV_IDECODER_RV_HAS_ZICSR_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_ZICSR_EXT=${RV_IDECODER_RV_HAS_ZICSR_EXT}")

set(RV_IDECODER_RV_HAS_ZIFENCEI_EXT "0" CACHE STRING "")
list(APPEND RV_IDECODER_VERILATOR_EXTRA_ARGS "-GRV_HAS_ZIFENCEI_EXT=${RV_IDECODER_RV_HAS_ZIFENCEI_EXT}")
###############################################################################

###############################################################################
# prepare rv instruction decoder
file(GLOB RV_IDECODER_SV_SRC
    "${RTL_SRC_DIR}/inc/pkg/*.sv"
    "${TB_SRC_DIR}/${TB_NAME}/*.sv"
    "${RTL_SRC_DIR}/cores/ucore/*.sv"
    )

set(RV_IDECODER_LIBDUT_CPP_SRC
    "${SW_SRC_DIR}/src/sim/idecoder/rv_idecoder.cpp"
    "${SW_SRC_DIR}/src/sim/idecoder/python_export.cpp"
    )

ADD_VERILATED_TARGET(
    "idecoder"
    "rv_idecoder_sim_top"
    "${RV_IDECODER_SV_SRC}"
    "${RV_IDECODER_LIBDUT_CPP_SRC}"
    "${RV_IDECODER_VERILATOR_EXTRA_ARGS}"
    "${RTL_INC_DIR}"
    ""
    )

install(FILES "${SW_SRC_DIR}/src/sim/idecoder/rv_idecoder.py"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION "lib/.."
    )
###############################################################################