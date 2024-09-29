import libdut

def main():
    verbose_level = 1
    dut = libdut.XRV1()
    elf_loaded = dut.load_elf("/tmp/asd", verbose_level)
    print("Elf loaded: {}".format(elf_loaded))
    res = dut.run_simulation(10000, verbose_level)
    dut.dump_signature("sig.txt", verbose_level)

if __name__ == "__main__":
    main()
