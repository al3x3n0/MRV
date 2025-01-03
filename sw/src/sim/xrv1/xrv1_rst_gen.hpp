#include <systemc.h>

//-----------------------------------------------------------------
// Module
//-----------------------------------------------------------------
SC_MODULE(xrv1_rst_gen)
{
public:
    sc_in <bool>    clk;
    sc_signal<bool> rst;

    void thread(void) 
    {
        rst.write(true);
        wait();
        rst.write(false);
    }

    SC_HAS_PROCESS(xrv1_rst_gen);
    xrv1_rst_gen(sc_module_name name): sc_module(name)
    {
        SC_CTHREAD(thread, clk);   
    }
};
