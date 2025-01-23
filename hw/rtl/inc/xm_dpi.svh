`ifndef __XM_DPI_SVH__
`define __XM_DPI_SVH__

// c++ function to decode risc-v instruction
import "DPI-C" function string riscv_decode_instruction(input longint pc, input int inst);
import "DPI-C" function void print_char(input byte c);

`endif /* __XM_DPI_SVH__ */