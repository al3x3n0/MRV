#include <boost/python.hpp>
#include <boost/python/enum.hpp>

#include <iostream>

#include "xrv1_soc.hpp"

BOOST_PYTHON_MODULE(libdut)
{
    using namespace boost::python;

    class_<xrv1_soc, boost::noncopyable>("XRV1", init<>())
        .def("release_reset", &xrv1_soc::release_reset)
        .def("get_reset_status", &xrv1_soc::get_reset_status)
        .def("tick", &xrv1_soc::tick)
        .def("get_ticks_number", &xrv1_soc::get_ticks_number)
        .def("load_elf", &xrv1_soc::load_elf)
        .def("run_simulation", &xrv1_soc::run_simulation)
        .def("read_byte", &xrv1_soc::read_u8)
        .def("read_short", &xrv1_soc::read_u16)
        .def("read_word", &xrv1_soc::read_u32)
        .def("dump_signature", &xrv1_soc::dump_signature)
        .def("is_sim_finished", &xrv1_soc::is_simulation_finished)
        .def("get_reg_val", &xrv1_soc::get_reg_val_u32);
}