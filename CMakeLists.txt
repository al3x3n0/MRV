cmake_minimum_required(VERSION 3.16)

project(verilated_cores)

set(CMAKE_CXX_STANDARD 17)

###############################################################################
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/cmake")
###############################################################################

###############################################################################
# find all required packages
find_package(verilator)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# look for python and boost.python only if option is set
if (BUILD_PYTHON_LIBRARY)
    find_package (Python3 COMPONENTS Development)
    include_directories(${Python3_INCLUDE_DIRS})
    find_package(Boost COMPONENTS python3 REQUIRED)
    include_directories(${Boost_INCLUDE_DIR})
endif ()
###############################################################################

###############################################################################
# fixup for macos build to ease python import
if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
endif()
###############################################################################

###############################################################################
# options to configure cores
option(ENABLE_SIMULATION_MODE "Enable verilator simulation mode" ON)
option(CPU_RESET_ADDRESS "Set CPU reset address" OFF)
option(BUILD_PYTHON_LIBRARY "Build python module instead of just binary" OFF)
option(CPU_RAM_SIZE_BITS "Set RAM bits number" OFF)
option(CPU_ENABLE_M_EXT "Enable M extension" OFF)

# Extra args to pass to verilator
set(VERILATOR_EXTRA_ARGS "")

# if simulation option is enabled, add such define for verilator
if (ENABLE_SIMULATION_MODE)
    list(APPEND VERILATOR_EXTRA_ARGS "-DSIM_ENABLED=1")
endif ()

# if cpu reset address option is set, add such define for verilator
if (CPU_RESET_ADDRESS)
    list(APPEND VERILATOR_EXTRA_ARGS "-DCPU_RESET_ADDRESS='h${CPU_RESET_ADDRESS}")
endif ()

# if cpu ram size bits option is set, add such define for verilator
if (CPU_RAM_SIZE_BITS)
    list(APPEND VERILATOR_EXTRA_ARGS "-DCPU_RAM_SIZE_BITS=${CPU_RAM_SIZE_BITS}")
endif ()

if (CPU_ENABLE_M_EXT)
    list(APPEND VERILATOR_EXTRA_ARGS "-DRV_HAS_M_EXT=1")
endif ()
###############################################################################

###############################################################################
# setup some generic directory variables
set(ISA_SIM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/sw/external/isa_sim")
set(HW_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/hw")
set(SW_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/sw")
set(RTL_SRC_DIR "${HW_SRC_DIR}/rtl")

include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}/sw/external"
    "${CMAKE_CURRENT_SOURCE_DIR}/sw/src"
    )
###############################################################################

###############################################################################
# prepare xrv1 core
set(XRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/ucore")
set(XRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

file(GLOB XRV1_SV_SRC
    "${XRV1_TB_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/*.sv"
    )

set(XRV1_LIBDUT_CPP_SRC
    "${SW_SRC_DIR}/src/sim/xrv1/xrv1_soc.cpp"
    "${SW_SRC_DIR}/src/sim/single_core_soc.cpp"
    "${SW_SRC_DIR}/src/sim/elf_loader.cpp"
    "${SW_SRC_DIR}/src/sim/xrv1/python_export.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

set(XRV1_VERILATOR_EXTRA_ARGS ${VERILATOR_EXTRA_ARGS})
list(APPEND XRV1_VERILATOR_EXTRA_ARGS "-DTB_CORE_TYPE_XRV1=1")

ADD_VERILATED_TARGET(
    "xrv1"
    "xrv1_sim_top"
    "${XRV1_SV_SRC}"
    "${XRV1_LIBDUT_CPP_SRC}"
    "${XRV1_VERILATOR_EXTRA_ARGS}"
    )

install(FILES "${SW_SRC_DIR}/dut/xrv1"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION "lib/.."
    )
###############################################################################

###############################################################################
# prepare rv instruction decoder
file(GLOB RV_IDECODER_SV_SRC
    "${XRV1_TB_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/*.sv"
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
    "${VERILATOR_EXTRA_ARGS}"
    )

install(FILES "${SW_SRC_DIR}/dut/rv_idecoder.py"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION "lib/.."
    )
###############################################################################

###############################################################################
set(MRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(MRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/cores/mtcore")
set(MRV1_COMMON_SRC_DIR "${RTL_SRC_DIR}/common")
set(MRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg" "${RTL_SRC_DIR}/inc")

file(GLOB MRV1_SV_SRC
    "${MRV1_TB_SRC_DIR}/*.sv"
    "${MRV1_RTL_SRC_DIR}/*.sv"
    "${MRV1_COMMON_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_ialigner.sv"
    "${XRV1_RTL_SRC_DIR}/xrv1_iqueue.sv"
)

set(MRV1_LIBDUT_CPP_SRC
    "${SW_SRC_DIR}/src/sim/mrv1/mrv1_soc.cpp"
    "${SW_SRC_DIR}/src/sim/single_core_soc.cpp"
    "${SW_SRC_DIR}/src/sim/elf_loader.cpp"
    "${SW_SRC_DIR}/src/sim/mrv1/python_export.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

set(MRV1_VERILATOR_EXTRA_ARGS ${VERILATOR_EXTRA_ARGS})
list(APPEND MRV1_VERILATOR_EXTRA_ARGS "-DTB_CORE_TYPE_MRV1=1")

ADD_VERILATED_TARGET(
    "mrv1"
    "xrv1_sim_top"
    "${MRV1_SV_SRC}"
    "${MRV1_LIBDUT_CPP_SRC}"
    "${MRV1_VERILATOR_EXTRA_ARGS}"
)
###############################################################################

add_subdirectory("${SW_SRC_DIR}/src/dut/caches")