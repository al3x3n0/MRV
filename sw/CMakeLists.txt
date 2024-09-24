cmake_minimum_required(VERSION 3.16)

project(xrv1)

set(CMAKE_CXX_STANDARD 17)

find_package(verilator)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# Let's define top module name and verilator preix.
# We need those in DPI functions
set(DESIGN_TOP_MODULE_NAME "xrv1_sim_top")
set(VERILATOR_PREFIX_NAME "Vxrv1_sim_top")
set(OUTPUT_BINARY "xrv1_tb")

add_compile_definitions(TOP_MODULE=\"${DESIGN_TOP_MODULE_NAME}\")
add_compile_definitions(VERILATOR_PREFIX=\"${VERILATOR_PREFIX_NAME}\")


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
    "${XRV1_RTL_INC_DIR}/*.sv"
    )

set(XRV1_TB_SRC
    "src/sim/main.cpp"
    "src/sim/xrv1_tb.cpp"
    "src/sim/xrv1_top.cpp"
    "src/sim/elf_loader.cpp"
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

add_executable(${OUTPUT_BINARY} ${XRV1_TB_SRC})

# For available options see:
# - https://verilator.org/guide/latest/verilating.html#verilate-in-cmake
# - https://veripool.org/guide/latest/exe_verilator.html
# Example project:
# - https://github.com/k0nze/verilator_systemc_template
verilate(${OUTPUT_BINARY}
    SYSTEMC
    COVERAGE
    TRACE
    TOP_MODULE "${DESIGN_TOP_MODULE_NAME}"
    PREFIX "${VERILATOR_PREFIX_NAME}"
    SOURCES ${XRV1_SV_SRC}
    )

verilator_link_systemc(${OUTPUT_BINARY})
