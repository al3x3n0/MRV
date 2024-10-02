cmake_minimum_required(VERSION 3.16)

project(xrv1)

set(CMAKE_CXX_STANDARD 17)

find_package(verilator)

option(ENABLE_SIMULATION_MODE "Enable verilator simulation mode" ON)
option(CPU_RESET_ADDRESS "Set CPU reset address" OFF)
option(BUILD_PYTHON_LIBRARY "Build python module instead of just binary" OFF)
option(CPU_RAM_SIZE_BITS "Set RAM bits number" OFF)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# look for python and boost.python only if option is set
if (BUILD_PYTHON_LIBRARY)
    find_package (Python3 COMPONENTS Development)
    include_directories(${Python3_INCLUDE_DIRS})
    find_package(Boost COMPONENTS python3 REQUIRED)
    include_directories(${Boost_INCLUDE_DIR})
endif ()

# Let's define top module name and verilator preix.
# We need those in DPI functions
set(DESIGN_TOP_MODULE_NAME "xrv1_sim_top")
set(VERILATOR_PREFIX_NAME "Vxrv1_sim_top")
# 
set(OUTPUT_BINARY "xrv1_tb")
set(OUTPUT_LIBRARY "dut")

add_compile_definitions(TOP_MODULE=\"${DESIGN_TOP_MODULE_NAME}\")
add_compile_definitions(VERILATOR_PREFIX=\"${VERILATOR_PREFIX_NAME}\")

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
endif()

set(ISA_SIM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/isa_sim")
set(HW_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../hw")
set(RTL_SRC_DIR "${HW_SRC_DIR}/rtl")

set(XRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/ucore")
set(XRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}/external"
    )

file(GLOB XRV1_SV_SRC
    "${XRV1_TB_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/*.sv"
    "${XRV1_RTL_INC_DIR}/xrv1_pkg.sv"
    )

# sources for systemc binary
set(XRV1_LIBDUT_SC_SRC
    "src/sim/xrv1_tb.cpp"
    "src/sim/xrv1_top.cpp"
    "src/sim/elf_loader.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

set(XRV1_TB_SRC
    "src/sim/main.cpp"
    )

# sources for 
set(XRV1_LIBDUT_CPP_SRC
    "src/sim/xrv1_soc.cpp"
    "src/sim/elf_loader.cpp"
    "src/sim/python_export.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

# create shared library with cpp code
if (BUILD_PYTHON_LIBRARY)
    add_library(${OUTPUT_LIBRARY} SHARED ${XRV1_LIBDUT_CPP_SRC})
    set(VERILATOR_USE_SYSTEMC "")
else ()
    add_library(${OUTPUT_LIBRARY} SHARED ${XRV1_LIBDUT_SC_SRC})
    set(VERILATOR_USE_SYSTEMC "SYSTEMC")
    add_executable(${OUTPUT_BINARY} ${XRV1_TB_SRC})
    target_link_libraries(${OUTPUT_BINARY} ${OUTPUT_LIBRARY})
endif ()

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

# For available options see:
# - https://verilator.org/guide/latest/verilating.html#verilate-in-cmake
# - https://veripool.org/guide/latest/exe_verilator.html
# Example project:
# - https://github.com/k0nze/verilator_systemc_template
verilate(${OUTPUT_LIBRARY}
    ${VERILATOR_USE_SYSTEMC}
    COVERAGE
    TRACE
    TOP_MODULE "${DESIGN_TOP_MODULE_NAME}"
    PREFIX "${VERILATOR_PREFIX_NAME}"
    SOURCES ${XRV1_SV_SRC}
    VERILATOR_ARGS "${VERILATOR_EXTRA_ARGS}"
    INCLUDE_DIRS "../hw/"
    )

# link with lib python and boost.python
if (BUILD_PYTHON_LIBRARY)
    target_link_libraries(${OUTPUT_LIBRARY} PUBLIC ${Boost_LIBRARIES} ${Python3_LIBRARIES})
else ()
    verilator_link_systemc(${OUTPUT_LIBRARY})
endif ()