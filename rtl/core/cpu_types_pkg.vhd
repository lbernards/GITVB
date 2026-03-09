---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : cpu_types_pkg.vhd
-- Module Name    : CPU packages
-- Description    : Packages used in our core, for control signals.
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

package cpu_types_pkg is

  type alu_op_t is (
    ALU_ADD,
    ALU_SUB,
    ALU_AND,
    ALU_OR,
    ALU_XOR,
    ALU_SLT,
    ALU_SLTU,
    ALU_SLL,
    ALU_SRL,
    ALU_SRA,
    ALU_PCJ,  -- For jal
    ALU_PCJR, -- For jalr
    ALU_NOP
  );

  type alu_src2_t is (
    SRC2_REG,
    SRC2_IMM
  );

  type branch_t is (
    B_EQ,
    B_NE,
    B_LT,
    B_GE,
    B_LTU,
    B_GEU,
    B_NONE
  );

  type wb_sel_t is (
    WB_NONE,
    WB_ALU,
    WB_MEM,
    WB_PC,
    WB_UP
  );

  type mem_size_t is (
    MEM_BYTE,
    MEM_HALF,
    MEM_WORD
  );

  type exception_cause_t is (
    EXC_NONE,
    EXC_ILLEGAL_INSTR,
    EXC_ECALL_M,
    EXC_BREAKPOINT
  );

  type alu_src1_t is (
    SRC1_REG,
    SRC1_PC
  );

  -- Control record ID/EX
  type id_ex_control_t is record
    alu_op       : alu_op_t;
    alu_src1     : alu_src1_t;
    alu_src2     : alu_src2_t;
    branch_type  : branch_t;
    jump_req     : std_logic;
    reg_write    : std_logic;
    mem_read     : std_logic;
    mem_write    : std_logic;
    mem_size     : mem_size_t;
    mem_unsigned : std_logic; -- 1 = unsigned load;
    wb_sel       : wb_sel_t;
    exception    : exception_cause_t;
  end record;

  type imm_type_t is (
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J,
    IMM_NONE
  );

end package;