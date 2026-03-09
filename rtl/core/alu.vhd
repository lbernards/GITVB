---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : alu.vhd
-- Module Name    : ALU
-- Description    : Main ALU. Complex mathematical core operations.
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : EX
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library packages;
use packages.cpu_types_pkg.all;

entity ALU is
  port(
    -- input
    i_ex_rv1           : in std_logic_vector(31 downto 0);
    i_ex_rv2           : in std_logic_vector(31 downto 0);
    i_ex_imm           : in std_logic_vector(31 downto 0);
    i_ex_pc            : in std_logic_vector(31 downto 0);
    i_ex_ctrl          : in id_ex_control_t;
    -- output
    o_ex_alu_result    : out std_logic_vector(31 downto 0);
    o_ex_branch_target : out std_logic_vector(31 downto 0);
    o_ex_branch_taken  : out std_logic;
    o_ex_carry         : out std_logic
  );
end entity;

architecture operation of ALU is
  -- input interface signal
  signal rv1_s    : std_logic_vector(31 downto 0);
  signal rv2_s    : std_logic_vector(31 downto 0);
  signal imm_s    : unsigned(31 downto 0);
  signal pc_s     : unsigned(31 downto 0);
  signal ctrl_s   : id_ex_control_t;
  -- output interface signal
  signal result_s : std_logic_vector(31 downto 0);
  signal carry_s  : std_logic;

  -- control signals
  signal operation_s    : alu_op_t;
  signal alu_src1_s     : alu_src1_t;
  signal alu_src2_s     : alu_src2_t;
  signal branch_type_s  : branch_t;
  signal overflow_sub_s : std_logic;
  signal less_signed_s  : std_logic;
  signal sign_result1_s : std_logic;

  -- ALU 1 input signals
  signal opA_s    : unsigned(31 downto 0);
  signal opB_s    : unsigned(31 downto 0);
  signal nopB_s   : unsigned(31 downto 0);
  signal shamt_s  : integer range 0 to 31;
  -- ALU 1 output
  signal result1_s      : unsigned(32 downto 0);
  signal branch_taken_s : std_logic;
  -- ULA 2 output
  signal result2_s : unsigned(31 downto 0);


begin

  -- input
  rv1_s  <= i_ex_rv1;
  rv2_s  <= i_ex_rv2;
  imm_s  <= unsigned(i_ex_imm);
  pc_s   <= unsigned(i_ex_pc);
  ctrl_s <= i_ex_ctrl;

  -- output
  o_ex_alu_result     <= result_s;
  o_ex_carry          <= carry_s;
  o_ex_branch_target  <= std_logic_vector(result2_s);
  o_ex_branch_taken   <= branch_taken_s;

  carry_s <= result1_s(32);

  -- Alu control signals
  operation_s   <= ctrl_s.alu_op;
  alu_src1_s    <= ctrl_s.alu_src1;
  alu_src2_s    <= ctrl_s.alu_src2;
  branch_type_s <= ctrl_s.branch_type;

  -- ALU 1 input signals
  opA_s <= pc_s when alu_src1_s = SRC1_PC else
           unsigned(rv1_s);

  opB_s <= imm_s when alu_src2_s = SRC2_IMM else
           unsigned(rv2_s);

  nopB_s <= not opB_s;

  shamt_s <= to_integer(opB_s(4 downto 0));

  -- Branch logic
  branch_taken_s <= '1' when branch_type_s = B_EQ  and result1_s(31 downto 0) = (others => '0') else
                    '1' when branch_type_s = B_NE  and result1_s(31 downto 0) /= (others => '0') else
                    '1' when branch_type_s = B_LT  and less_signed_s = '1' else
                    '1' when branch_type_s = B_GE  and less_signed_s = '0' else
                    '1' when branch_type_s = B_LTU and carry_s = '0' else
                    '1' when branch_type_s = B_GEU and carry_s = '1' else
                    '0';

  -- overflow logic during subtraction: there is only overflow when signals have diff signs,
  -- AND the result signal has weird value different than A.

  sign_result1_s <= result1_s(31);

  overflow_sub_s <= '0' when (opA_s(31) = opB_s(31)) else
                    '0' when (sign_result1_s = opA_s(31)) else
                    '1';

  -- if overflow = 0 but result sign is 1 OR
  -- if overflow = 1 but result sign is 0 then A < B
  -- Else B > A
  less_signed_s <= '1' when sign_result1_s /= overflow_sub_s else
                   '0';

  ---------------------------------------------
  -- Alu 1 : calculus
  -- This ALU has the data that will be written
  -- in regfile
  ---------------------------------------------
  p_calc : process(opA_s, opB_s, nopB_s, operation_s, shamt_s)
  begin
    result1_s <= (others => '0');
    case operation_s is
      when ALU_ADD  => result1_s <= ('0' & opA_s) + ('0' & opB_s);
      when ALU_SUB => result1_s <= ('0' & opA_s) + ('0' & nopB_s) + 1;
      when ALU_XOR  => result1_s <= ('0' & opA_s) xor ('0' & opB_s);
      when ALU_OR   => result1_s <= ('0' & opA_s) or ('0' & opB_s);
      when ALU_AND  => result1_s <= ('0' & opA_s) and ('0' & opB_s);
      when ALU_SLL  => result1_s(31 downto 0) <= SHIFT_LEFT( opA_s, shamt_s);
      when ALU_SRL  => result1_s(31 downto 0) <= SHIFT_RIGHT(opA_s, shamt_s);
      when ALU_SRA  => result1_s(31 downto 0) <= unsigned(SHIFT_RIGHT(signed(opA_s), shamt_s));
      when ALU_PCJ  => result1_s(31 downto 0) <= opA_s + to_unsigned(4,32); -- ADD 4 to PC
      when ALU_PCJR => result1_s(31 downto 0) <= opA_s + to_unsigned(4,32);
      when ALU_SLT  =>
        if signed(opA_s) < signed(opB_s) then
          result1_s(0) <= '1';
        end if;

      when ALU_SLTU =>
        if opA_s < opB_s then
          result1_s(0) <= '1';
        end if;

      when others =>
        result1_s <= (others => '0');
    end case;

  end process;
  ---------------------------------------------
  -- ALU 2 : PC op
  -- This ALU has the result from PC operations
  ---------------------------------------------
  p_pc_op : process(imm_s, pc_s, operation_s, rv1_s, imm_s)
  begin
    result2_s <= (others => '0');
    case operation_s is
      when ALU_PCJR =>
        result2_s    <= unsigned(rv1_s) + imm_s;
        result2_s(0) <= '0';
      when ALU_NOP =>
        result2_s <= (others => '0');
      when others =>
        result2_s    <= pc_s + imm_s;
        result2_s(0) <= '0';
    end case;
  end process;

end architecture;