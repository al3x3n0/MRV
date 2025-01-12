#include <boost/python.hpp>
#include <boost/python/enum.hpp>

#include <iostream>

#include "mrv1_soc.hpp"

BOOST_PYTHON_MODULE(libmrv1_rv_soc_sim_top_dut)
{
    using namespace boost::python;

    class_<mrv1_soc, boost::noncopyable>("MRV1", init<>())
        .def("release_reset", &mrv1_soc::release_reset)
        .def("get_reset_status", &mrv1_soc::get_reset_status)
        .def("tick", &mrv1_soc::tick)
        .def("soc_print_params", &mrv1_soc::soc_print_parameters)
        .def("get_ticks_number", &mrv1_soc::get_ticks_number)
        .def("read_arch_register", &mrv1_soc::read_arch_reg)
        .def("write_arch_register", &mrv1_soc::write_arch_reg)
        .def("load_elf", &mrv1_soc::load_elf)
        .def("run_simulation", &mrv1_soc::run_simulation)
        .def("read_byte", &mrv1_soc::read_u8)
        .def("read_short", &mrv1_soc::read_u16)
        .def("read_word", &mrv1_soc::read_u32)
        .def("dump_signature", &mrv1_soc::dump_signature)
        .def("is_sim_finished", &mrv1_soc::is_simulation_finished)
        .def("get_reg_val", &mrv1_soc::get_reg_val_u32);
}