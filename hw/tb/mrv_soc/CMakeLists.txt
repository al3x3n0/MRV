
get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
message("Calling cmake script for ${TB_NAME} target")

# Extra args to pass to verilator
set(MRV_SOC_VERILATOR_EXTRA_ARGS "")

# enable simulation mode by default
list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-DSIM_ENABLED=1")

# enable mrv core in soc
list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-DTB_CORE_TYPE_MRV1=1")

# if cpu reset address option is set, add such define for verilator
if (MRV_SOC_CPU_RESET_ADDRESS)
    list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-GCPU_RESET_ADDRESS_P=${MRV_SOC_CPU_RESET_ADDRESS}")
endif ()

# if cpu ram size bits option is set, add such define for verilator
if (MRV_SOC_RAM_BITS_SIZE)
    list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-GRAM_BITS_SIZE_P=${MRV_SOC_RAM_BITS_SIZE}")
endif ()

# set debug level for mrv_soc
if (MRV_SOC_DEBUG_LEVEL)
    list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-GDEBUG_LEVEL_P=${MRV_SOC_DEBUG_LEVEL}")
endif ()

# set number of threads
if (MRV_SOC_THREAD_NUM)
    list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-GNUM_THREADS_P=${MRV_SOC_THREAD_NUM}")
endif ()

# configure cpu code xlen
if (MRV_SOC_XLEN)
    list(APPEND MRV_SOC_VERILATOR_EXTRA_ARGS "-GXLEN_P=${MRV_SOC_XLEN}")
endif ()

###############################################################################
# prepare mrv1 core
set(MRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(MRV1_SOC_SRC_DIR "${HW_SRC_DIR}/rtl/soc/rv_soc/")
set(MRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/mtcore")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/ucore")
set(MRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

file(GLOB MRV1_SV_SRC
    "${MRV1_TB_SRC_DIR}/*.sv"
    "${MRV1_RTL_SRC_DIR}/*.sv"
    "${MRV1_SOC_SRC_DIR}/*.sv"
    "${HW_SRC_DIR}/rtl/common/comm/*.sv"
    "${HW_SRC_DIR}/rtl/common/mem/*.sv"
    "${HW_SRC_DIR}/rtl/common/utils/*.sv"
    "${HW_SRC_DIR}/rtl/common/*.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_ialigner.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_ifq.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_iqueue.sv"
    )

set(MRV1_LIBDUT_CPP_SRC
    "${SW_SRC_DIR}/src/sim/mrv1/mrv1_soc.cpp"
    "${SW_SRC_DIR}/src/sim/single_core_soc.cpp"
    "${SW_SRC_DIR}/src/sim/elf_loader.cpp"
    "${SW_SRC_DIR}/src/sim/mrv1/python_export.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

#list(APPEND XRV_SOC_VERILATOR_EXTRA_ARGS "--timing")

ADD_VERILATED_TARGET(
    "mrv1"
    "rv_soc_sim_top"
    "${MRV1_SV_SRC}"
    "${MRV1_LIBDUT_CPP_SRC}"
    "${MRV_SOC_VERILATOR_EXTRA_ARGS}"
    "${RTL_INC_DIR};${HW_SRC_DIR};${HW_SRC_DIR}/rtl/cores"
    "${SW_SRC_DIR}/src/;${SW_SRC_DIR}/external/"
    )

install(FILES "${SW_SRC_DIR}/dut/mrv1"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION "lib/.."
    )
###############################################################################