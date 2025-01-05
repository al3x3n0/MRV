# What is it

This repo contains several cores available for simulation. These targets are:
```
    mrv_soc
    rv_cache
    rv_idecoder
    xrv_soc
```

# How to build

To build this project cmake is used. Sample set of commands:
```
mkdir build && cd build
cmake [cmake options] <...>/MRV/sw
make
```

To select which targets to build, use **PROJECTS_TO_BUILD** variable. Setting it to ALL builds all the projects.
```
cmake -DPROJECTS_TO_BUILD="rv_idecoder;xrv_soc" -DRV_IDECODER_DEBUG_LEVEL=7 ../MRV/ && make && cmake --install . --prefix=./install
```

## Existing cmake options
- -DCPU_RESET_ADDRESS=<val>, default is **OFF**
- -DCPU_RAM_SIZE_BITS=<val>, default is **OFF**
- -DPROJECTS_TO_BUILD=<val>, default is **ALL**
- -DRV_IDECODER_DEBUG_LEVEL=<val>, default is **0**
- -DRV_IDECODER_RV_XLEN=<val>, default is **32**
- -DRV_IDECODER_RV_HAS_M_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_A_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_A_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_F_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_D_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_ZICSR_EXT=<val>, default is **0**
- -DRV_IDECODER_RV_HAS_ZIFENCEI_EXT=<val>, default is **0**

## SoC related options

### CPU_RESET_ADDRESS
This option if set allows you to override the default reset address of the CPU. The proper value is a hex one without any leading modifiers.
I.e. -DCPU_RESET_ADDRESS=3000 would set reset addres of the core to 0x3000.


### CPU_RAM_SIZE_BITS
This option allows you to override the default RAM size. The proper value is number of available bits for RAM address.
I.e. -DCPU_RAM_SIZE_BITS=22 would configure ram to (1<<22) bytes of size.


## RV instruction decoder related options

### RV_IDECODER_DEBUG_LEVEL
Sets debug level for rv instruction decoder test bench.

### RV_IDECODER_RV_XLEN
Configures rv instruction decoder xlen.

### RV_IDECODER_RV_HAS_M_EXT
Configures rv instruction decoder to enable M-extension.

### RV_IDECODER_RV_HAS_A_EXT
Configures rv instruction decoder to enable A-extension.

### RV_IDECODER_RV_HAS_F_EXT
Configures rv instruction decoder to enable F-extension.

### RV_IDECODER_RV_HAS_D_EXT
Configures rv instruction decoder to enable D-extension.

### RV_IDECODER_RV_HAS_ZICSR_EXT
Configures rv instruction decoder to enable ZIcsr-extension.

### RV_IDECODER_RV_HAS_ZIFENCEI_EXT
Configures rv instruction decoder to enable ZFencei-extension.
