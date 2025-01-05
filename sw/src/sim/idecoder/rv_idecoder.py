#!/usr/bin/env python3

import sys
import argparse
import lib.libidecoder_rv_idecoder_sim_top_dut as libdut

def main():
    
    # xrv1 --signature=<sig_path> --elf=<elf_path> --verbose=<num>
    parser = argparse.ArgumentParser()
    parser.add_argument('--bytes', help='bytes of instruction', required=True)
    args = parser.parse_args()

    bytes = int(args.bytes, 16)

    dut = libdut.RV_IDECODER()
    res = dut.decode(bytes)
    print(f"Instructon {bytes} is valid {res}")

    bytes = bytes + 1
    res = dut.decode(bytes)
    print(f"Instructon {bytes} is valid {res}")
    
if __name__ == "__main__":
    main()
