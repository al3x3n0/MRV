cmake_minimum_required(VERSION 3.0)
project(xrv1)

set(CMAKE_CXX_STANDARD 11)

set(VERILATOR_DIR "/usr/share/verilator/include")

set(SYSTEMC_DIR "/usr/local/systemc-2.3.1")
set(SYSTEMC_INC_DIR "${SYSTEMC_DIR}/include")
set(SYSTEMC_LIB_DIR "${SYSTEMC_DIR}/lib-linux64")

set(ISA_SIM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/isa_sim")

set(HW_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../hw")
set(RTL_SRC_DIR "${HW_SRC_DIR}/rtl")

set(XRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(XRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/ucore")
set(XRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

set(VERILATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/verilated_dir")

file(GLOB XRV1_SV_SRC
    "${XRV1_TB_SRC_DIR}/*.sv"
    "${XRV1_RTL_SRC_DIR}/*.sv"
    "${XRV1_RTL_INC_DIR}/*.sv"
    )

add_custom_target(
    verilated
    COMMAND
        SYSTEMC_INCLUDE=${SYSTEMC_INC_DIR}
        SYSTEMC_LIBDIR=${SYSTEMC_LIB_DIR}
        verilator
            -y ${XRV1_RTL_SRC_DIR}
            -y ${XRV1_TB_SRC_DIR}
            -y ${XRV1_RTL_INC_DIR}
            -CFLAGS "-fPIC -std=gnu++11"
            --Mdir ${VERILATED_DIR}
            --sc
            +incdir+${XRV1_RTL_INC_DIR}
            --top-module xrv1_sim_top
            --pins-sc-uint
            --trace
            xrv1_pkg.sv
            xrv1_sim_top.sv
    #
    DEPENDS ${XRV1_SV_SRC}
)

INCLUDE_DIRECTORIES(
    ${VERILATED_DIR}
    ${SYSTEMC_INC_DIR}
    ${VERILATOR_DIR}
    ${VERILATOR_DIR}/vltstd
    #
    ${CMAKE_CURRENT_SOURCE_DIR}/external
    #
    ${ISA_SIM_DIR}
    )

LINK_DIRECTORIES(${SYSTEMC_LIB_DIR})

file(GLOB SRC_VERILATED
    "${VERILATED_DIR}/*.cpp"
    "${VERILATOR_DIR}/verilated.cpp"
    "${VERILATOR_DIR}/verilated_vcd_c.cpp"
    "${VERILATOR_DIR}/verilated_vcd_sc.cpp"
    )

add_library(xrv1_verilated SHARED ${SRC_VERILATED})
add_dependencies(xrv1_verilated verilated)



set(XRV1_TB_SRC
    "src/sim/main.cpp"
    "src/sim/xrv1_tb.cpp"
    "src/sim/xrv1_top.cpp"
    "src/sim/elf_loader.cpp"
    #
    "${ISA_SIM_DIR}/riscv_inst_dump.cpp"
    )

add_executable(xrv1_tb ${XRV1_TB_SRC})
target_link_libraries(xrv1_tb xrv1_verilated systemc)

