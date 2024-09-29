#define XLEN 32

#define TEST_CASE_1 1

#define ALIGNMENT 2

#define RVMODEL_BOOT

#define RVMODEL_IO_INIT
//RVTEST_IO_WRITE_STR
#define RVMODEL_IO_WRITE_STR(_R, _STR)
//RVTEST_IO_CHECK
#define RVMODEL_IO_CHECK()
//RVTEST_IO_ASSERT_GPR_EQ
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
//RVTEST_IO_ASSERT_SFPR_EQ
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
//RVTEST_IO_ASSERT_DFPR_EQ
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)


#define RVMODEL_HALT      \
  la t5, rvtest_sig_begin; \
  addi t5, t5, 4;          \
  la t6, sig_begin;       \
  sw t5, 0(t6);           \
  la t5, rvtest_sig_end;   \
  addi t5, t5, -4;        \
  la t6, sig_end;         \
  sw t5, 0(t6);           \
  nop; nop; nop; \
  nop; nop; nop; \
  wfi;                    \
  self_loop: j self_loop

#define RVMODEL_DATA_SECTION \
    .pushsection .tohost,"aw",@progbits;                            \
    .align 8; .global tohost; tohost: .dword 0;                     \
    .popsection;                                                    \
    .pushsection .fromhost,"aw",@progbits;                          \
    .align 8; .global fromhost; fromhost: .dword 0;                 \
    .popsection;                                                    \
    .pushsection .sig_begin,"aw",@progbits;                         \
    .align 8; .global sig_begin; sig_begin: .dword 0;               \
    .popsection;                                                    \
    .pushsection .sig_end,"aw",@progbits;                           \
    .align 8; .global sig_end; sig_end: .dword 0;                   \
    .popsection;                                                    \
    .align 8; .global begin_regstate; begin_regstate:               \
    .word 128;                                                      \
    .align 8; .global end_regstate; end_regstate:                   \
    .word 4;

#define RVMODEL_DATA_BEGIN                                              \
  RVMODEL_DATA_SECTION                                                        \
  .align 4;\
  .global begin_signature; begin_signature:

  //RV_COMPLIANCE_DATA_END
#define RVMODEL_DATA_END                                                      \
  .align 4; .global end_signature; end_signature:  
