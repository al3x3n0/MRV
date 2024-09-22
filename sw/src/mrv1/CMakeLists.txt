set(MRV1_TB_SRC_DIR "${HW_SRC_DIR}/tb")
set(MRV1_RTL_SRC_DIR "${RTL_SRC_DIR}/mtcore")
set(MRV1_RTL_INC_DIR "${RTL_SRC_DIR}/pkg")

set(VERILATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/verilated/mrv1")

file(GLOB MRV1_SV_SRC
    "${MRV1_TB_SRC_DIR}/*.sv"
    "${MRV1_RTL_SRC_DIR}/*.sv"
    "${MRV1_RTL_INC_DIR}/*.sv")

add_custom_target(
    verilated_mrv1
    COMMAND
        SYSTEMC_INCLUDE=${SYSTEMC_INC_DIR}
        SYSTEMC_LIBDIR=${SYSTEMC_LIB_DIR}
        verilator
            -y ${COMMON_RTL_SRC_DIR}
            -y ${MRV1_RTL_SRC_DIR}
            -y ${XRV1_RTL_SRC_DIR}
            -y ${MRV1_TB_SRC_DIR}
            -y ${MRV1_RTL_INC_DIR}
            -CFLAGS "-fPIC -std=gnu++11"
            --Mdir ${VERILATED_DIR}
            --sc
            +incdir+${MRV1_RTL_INC_DIR}
            --top-module mrv1_sim_top
            --pins-sc-uint
            --trace
            --cc
            xrv1_pkg.sv
            mrv1_pkg.sv
            mrv1_sim_top.sv
    #
    DEPENDS ${MRV1_SV_SRC}
)

file(GLOB SRC_VERILATED
    "${VERILATED_DIR}/*.cpp"
    "${VERILATOR_DIR}/verilated.cpp"
    "${VERILATOR_DIR}/verilated_vcd_c.cpp"
    "${VERILATOR_DIR}/verilated_vcd_sc.cpp"
    )

add_library(mrv1 SHARED ${SRC_VERILATED})
add_dependencies(mrv1 verilated_mrv1)
