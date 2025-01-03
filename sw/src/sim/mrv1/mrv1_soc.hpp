#ifndef __MRV1_SOC_HPP__
#define __MRV1_SOC_HPP__

#include "sim/single_core_soc.hpp"

#include <cstdint>

class mrv1_soc: public single_core_soc
{
public:
    mrv1_soc() = default;
    ~mrv1_soc() = default;

protected:
    void on_simulation_step(int verbose_lvl);
};

#endif /* __MRV1_SOC_HPP__ */
