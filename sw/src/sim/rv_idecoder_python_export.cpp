#include <boost/python.hpp>
#include <boost/python/enum.hpp>

#include <iostream>

#include "rv_idecoder.hpp"

BOOST_PYTHON_MODULE(librv_idecoder_sim_top_dut)
{
    using namespace boost::python;

    class_<rv_idecoder, boost::noncopyable>("RV_IDECODER", init<>())
    .def("check_m_ext_enabled", &rv_idecoder::check_m_ext_enabled)
    .def("tick", &rv_idecoder::tick);
}