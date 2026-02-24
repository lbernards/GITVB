---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : imm_gen.vhd
-- Module Name    : Immediate Generator
-- Description    : RISC-V RV32I Immediate Generator
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : ID
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library packages;
use packages.cpu_types_pkg.all;

entity imm_gen is
  port(
    --
    i_id_imm_type     : in imm_type_t;
    i_id_instruction  : in std_logic_vector(31 downto 0);
    --
    o_id_imm          : out std_logic_vector(31 downto 0)
  );
end entity;


architecture generation of imm_gen is

  -- interface signals
  signal imm_type_s    : imm_type_t;
  signal instruction_s : std_logic_vector(31 downto 0);

  -- immediates per type
  signal I_imm_s       : std_logic_vector(31 downto 0);
  signal S_imm_s       : std_logic_vector(31 downto 0);
  signal B_imm_s       : std_logic_vector(31 downto 0);
  signal U_imm_s       : std_logic_vector(31 downto 0);
  signal J_imm_s       : std_logic_vector(31 downto 0);

  -- signal for final imm
  signal imm_s         : std_logic_vector(31 downto 0);

begin

  -- input
  imm_type_s      <= i_id_imm_type;
  instruction_s   <= i_id_instruction;
  -- output
  o_id_imm        <= imm_s;

  -------------------------------------------
  -- Generating imm
  -------------------------------------------
  I_imm_s <= (31 downto 12 => instruction_s(31)) &
             instruction_s(31 downto 20);

  S_imm_s <= (31 downto 12 => instruction_s(31)) &
             instruction_s(31 downto 25) &
             instruction_s(11 downto 7);

  B_imm_s <= (31 downto 13 => instruction_s(31)) &
             instruction_s(31) &
             instruction_s(7)  &
             instruction_s(30 downto 25) &
             instruction_s(11 downto 8)  &
             '0';

  U_imm_s <= instruction_s(31 downto 12) &
             (11 downto 0 => '0');

  J_imm_s <= (31 downto 21 => instruction_s(31)) &
             instruction_s(31) &
             instruction_s(19 downto 12) &
             instruction_s(20) &
             instruction_s(30 downto 21) &
             '0';

  -- Selection mux
  imm_s   <= I_imm_s when imm_type_s = IMM_I else
             S_imm_s when imm_type_s = IMM_S else
             B_imm_s when imm_type_s = IMM_B else
             U_imm_s when imm_type_s = IMM_U else
             J_imm_s when imm_type_s = IMM_J else
             (others => '0');

end architecture;