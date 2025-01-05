
get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
message("Calling cmake script for ${TB_NAME} target")

# Extra args to pass to verilator
set(XRV_SOC_VERILATOR_EXTRA_ARGS "")

# enable simulation mode by default
list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "-DSIM_ENABLED=1")

# enable xrv core in soc
list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "-DTB_CORE_TYPE_XRV1=1")

# if cpu reset address option is set, add such define for verilator
if (CPU_RESET_ADDRESS)
    list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "-DCPU_RESET_ADDRESS='h${CPU_RESET_ADDRESS}")
endif ()

# if cpu ram size bits option is set, add such define for verilator
if (CPU_RAM_SIZE_BITS)
    list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "-DCPU_RAM_SIZE_BITS=${CPU_RAM_SIZE_BITS}")
endif ()

###############################################################################
# prepare xrv1 core
set(XRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(XRV1_SOC_SRC_DIR "${HW_SRC_DIR}/rtl/soc/rv_soc/")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/ucore")
set(XRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

file(GLOB XRV1_SV_SRC
    "${XRV1_TB_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/*.sv"
    "${XRV1_SOC_SRC_DIR}/*.sv"
    "${HW_SRC_DIR}/rtl/common/mem/*.sv"
    )

set(XRV1_LIBDUT_CPP_SRC
    "${SW_SRC_DIR}/src/sim/xrv1/xrv1_soc.cpp"
    "${SW_SRC_DIR}/src/sim/single_core_soc.cpp"
    "${SW_SRC_DIR}/src/sim/elf_loader.cpp"
    "${SW_SRC_DIR}/src/sim/xrv1/python_export.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

#list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "--timing")

ADD_VERILATED_TARGET(
    "xrv1"
    "rv_soc_sim_top"
    "${XRV1_SV_SRC}"
    "${XRV1_LIBDUT_CPP_SRC}"
    "${XRV_SOC_VERILATOR_EXTRA_ARGS}"
    "${RTL_INC_DIR};${HW_SRC_DIR};${HW_SRC_DIR}/rtl/cores"
    "${SW_SRC_DIR}/src/;${SW_SRC_DIR}/external/"
    )

install(FILES "${SW_SRC_DIR}/dut/xrv1"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION "lib/.."
    )
###############################################################################