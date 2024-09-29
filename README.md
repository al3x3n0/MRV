# How to build

To build this project cmake is used. Sample set of commands:
```
mkdir build && cd build
cmake [cmake options] <...>/MRV/sw
make
```
Depening on the options the outcome of the build might be either **xrv1_tb** binary file or **libdut.so** shared library, which could be imported into python3.

## Existing cmake options
- -DENABLE_SIMULATION_MODE=ON/OFF, default is **ON**
- -DCPU_RESET_ADDRESS=<val>, default is **OFF**
- -DBUILD_PYTHON_LIBRARY=ON/OFF, default is **OFF**

### ENABLE_SIMULATION_MODE
This option allows you to choose if you'd like to include simulation helper code in the design. By default this option is enabled.

### CPU_RESET_ADDRESS
This option if set allows you to override the default reset address of the CPU. The proper value is a hex one without any leading modifiers.
I.e. -DCPU_RESET_ADDRESS=3000 would set reset addres of the core to 0x3000.

### BUILD_PYTHON_LIBRARY
This option allows you to select which type of target to build. By default SystemC binary is built.
If you choose to build python3 library, you could find example script in **sw/dut/dut.py**
