---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : decoder.vhd
-- Module Name    : Decoder
-- Description    : RISC-V RV32I Decoder
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : ID
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library packages;
use packages.cpu_types_pkg.all;


entity decoder is
  port(
    -- Instruction fetched from i_cache
    i_id_instruction : in std_logic_vector(31 downto 0);
    i_id_bubble      : in std_logic;
    -- Reg indexes
    o_id_rs1         : out std_logic_vector(4 downto 0);
    o_id_rs2         : out std_logic_vector(4 downto 0);
    o_id_rd          : out std_logic_vector(4 downto 0);
    -- Control signals output
    o_id_ctrl        : out id_ex_control_t;
    o_id_imm_type    : out imm_type_t
  );
end entity;

architecture decode of decoder is

  -- Fetched instructions
  signal instruction_s   : std_logic_vector(31 downto 0);

  -- Extracted data and instruction signals
  signal opcode_s     : std_logic_vector(6 downto 0);
  signal rd_s         : std_logic_vector(4 downto 0);
  signal funct3_s     : std_logic_vector(2 downto 0);
  signal rs1_s        : std_logic_vector(4 downto 0);
  signal rs2_s        : std_logic_vector(4 downto 0);
  signal funct7_s     : std_logic_vector(6 downto 0);
  signal immed_type_s : std_logic_vector(11 downto 0);

  -- control signal
  signal ctrl_s          : id_ex_control_t;
  signal imm_type_s      : imm_type_t;
  signal bubble_s        : std_logic;

begin

  -- Input
  instruction_s <= i_id_instruction;
  bubble_s      <= i_id_bubble;

  -- Output
  o_id_rs1      <= rs1_s;
  o_id_rs2      <= rs2_s;
  o_id_rd       <= rd_s;
  o_id_ctrl     <= ctrl_s;
  o_id_imm_type <= imm_type_s;

  ---------------------------------------------
  -- Instruction split
  -------------------------------------------
  opcode_s        <= instruction_s(6 downto 0);
  rd_s            <= instruction_s(11 downto 7);
  funct3_s        <= instruction_s(14 downto 12);
  rs1_s           <= instruction_s(19 downto 15);
  rs2_s           <= instruction_s(24 downto 20);
  funct7_s        <= instruction_s(31 downto 25);
  immed_type_s    <= instruction_s(31 downto 20);

  -------------------------------------------
  -- Main deecoder
  -------------------------------------------
  p_decoding : process(all)
  begin

    imm_type_s <= IMM_NONE;
    -- Default values for control (NOP-safe)
    ctrl_s.alu_op       <= ALU_NOP;
    ctrl_s.alu_src1     <= SRC1_REG;
    ctrl_s.alu_src2     <= SRC2_REG;
    ctrl_s.branch_type  <= B_NONE;
    ctrl_s.jump_req     <= '0';
    ctrl_s.reg_write    <= '0';
    ctrl_s.mem_read     <= '0';
    ctrl_s.mem_write    <= '0';
    ctrl_s.mem_size     <= MEM_WORD;
    ctrl_s.mem_unsigned <= '0';
    ctrl_s.wb_sel       <= WB_NONE;
    ctrl_s.exception    <= EXC_NONE;

    if bubble_s = '0' then
      case opcode_s is

        when "0110011" => -- R-type
          ctrl_s.reg_write   <= '1';
          ctrl_s.alu_src2    <= SRC2_REG;
          ctrl_s.wb_sel      <= WB_ALU;

          case funct3_s is
            when "000" =>     -- SUB and ADD
              if funct7_s = "0100000" then
                ctrl_s.alu_op <= ALU_SUB;
              elsif funct7_s = "0000000" then
                ctrl_s.alu_op <= ALU_ADD;
              else
                ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "100" => --XOR
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_XOR;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "110" => -- OR
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_OR;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "111" => -- AND
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_AND;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "001" =>
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_SLL;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "010" =>
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_SLT;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "011" =>
              if funct7_s = (others => '0') then
                ctrl_s.alu_op <= ALU_SLTU;
              else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "101" =>     -- SRL and SRA
              if funct7_s = "0100000" then
                ctrl_s.alu_op <= ALU_SRA;
              elsif funct7_s = "0000000" then
                ctrl_s.alu_op <= ALU_SRL;
              else
                ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when others => ctrl_s.exception <= EXC_ILLEGAL_INSTR;
          end case;

        when "0010011" => -- I-type
          ctrl_s.reg_write   <= '1';
          ctrl_s.alu_src2    <= SRC2_IMM;
          ctrl_s.wb_sel      <= WB_ALU;
          imm_type_s         <= IMM_I;

          case funct3_s is
            when "000" => ctrl_s.alu_op <= ALU_ADD;
            when "100" => ctrl_s.alu_op <= ALU_XOR;
            when "110" => ctrl_s.alu_op <= ALU_OR;
            when "111" => ctrl_s.alu_op <= ALU_AND;
            when "010" => ctrl_s.alu_op <= ALU_SLT;
            when "011" => ctrl_s.alu_op <= ALU_SLTU;

            when "001" =>
              if funct7_s = "0000000" then
                ctrl_s.alu_op <= ALU_SLL;
              else
                ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            when "101" =>
            if funct7_s = "0000000" then
              ctrl_s.alu_op <= ALU_SRL;
            elsif funct7_s = "0100000" then
              ctrl_s.alu_op <= ALU_SRA;
              else
                ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;
            when others => ctrl_s.exception <= EXC_ILLEGAL_INSTR;
          end case;

        when "0000011" => -- Load type
          ctrl_s.alu_op      <= ALU_ADD;
          ctrl_s.alu_src2    <= SRC2_IMM;
          ctrl_s.reg_write   <= '1';
          ctrl_s.mem_read    <= '1';
          ctrl_s.wb_sel      <= WB_MEM;
          imm_type_s         <= IMM_I;

          case funct3_s is
            when "000" =>
              ctrl_s.mem_size     <= MEM_BYTE;
              ctrl_s.mem_unsigned <= '0';
            when "001" =>
              ctrl_s.mem_size     <= MEM_HALF;
              ctrl_s.mem_unsigned <= '0';
            when "010" =>
              ctrl_s.mem_size     <= MEM_WORD;
              ctrl_s.mem_unsigned <= '0';
            when "100" =>
              ctrl_s.mem_size     <= MEM_BYTE;
              ctrl_s.mem_unsigned <= '1';
            when "101" =>
              ctrl_s.mem_size     <= MEM_HALF;
              ctrl_s.mem_unsigned <= '1';
            when others => ctrl_s.exception <= EXC_ILLEGAL_INSTR;
          end case;

        when "0100011" => -- S-type
          ctrl_s.alu_op    <= ALU_ADD;
          ctrl_s.alu_src2  <= SRC2_IMM;
          ctrl_s.mem_write <= '1';
          ctrl_s.wb_sel    <= WB_NONE;
          imm_type_s       <= IMM_S;

          case funct3_s is
            when "000"  => ctrl_s.mem_size  <= MEM_BYTE;
            when "001"  => ctrl_s.mem_size  <= MEM_HALF;
            when "010"  => ctrl_s.mem_size  <= MEM_WORD;
            when others => ctrl_s.exception <= EXC_ILLEGAL_INSTR;
          end case;

        when "1100011" => -- B-type
          ctrl_s.alu_op   <= ALU_SUB;
          ctrl_s.alu_src2 <= SRC2_REG;
          ctrl_s.wb_sel   <= WB_NONE;
          imm_type_s      <= IMM_B;

          case funct3_s is
            when "000"  => ctrl_s.branch_type <= B_EQ;
            when "001"  => ctrl_s.branch_type <= B_NE;
            when "100"  => ctrl_s.branch_type <= B_LT;
            when "101"  => ctrl_s.branch_type <= B_GE;
            when "110"  => ctrl_s.branch_type <= B_LTU;
            when "111"  => ctrl_s.branch_type <= B_GEU;
            when others => ctrl_s.exception   <= EXC_ILLEGAL_INSTR;
          end case;

        when "1101111" => --JAL
          imm_type_s <= IMM_J;
          ctrl_s.jump_req    <= '1';
          ctrl_s.reg_write   <= '1';
          ctrl_s.wb_sel      <= WB_PC;
          ctrl_s.alu_op      <= ALU_PCJ;
          ctrl_s.alu_src1    <= SRC1_PC;

        when"1100111" => -- JALR
          imm_type_s <= IMM_I;
          ctrl_s.jump_req    <= '1';
          ctrl_s.reg_write   <= '1';
          ctrl_s.wb_sel      <= WB_PC;
          ctrl_s.alu_op      <= ALU_PCJR;
          ctrl_s.alu_src1    <= SRC1_PC;
          ctrl_s.alu_src2    <= SRC2_IMM;

        when "0110111" => -- LUI
          ctrl_s.reg_write <= '1';
          ctrl_s.wb_sel    <= WB_UP;
          imm_type_s       <= IMM_U;

        when "0010111" => -- auipc
          ctrl_s.reg_write <= '1';
          ctrl_s.alu_src1  <= SRC1_PC;
          ctrl_s.alu_src2  <= SRC2_IMM;
          imm_type_s       <= IMM_U;
          ctrl_s.alu_op    <= ALU_ADD;
          ctrl_s.wb_sel    <= WB_ALU;

          when "1110011" => -- SYSTEM
            if funct3_s = "000" and
              rs1_s = "00000" and
              rd_s  = "00000" then

              if immed_type_s = (others => '0') then
                ctrl_s.exception <= EXC_ECALL_M;
              elsif immed_type_s = "000000000001" then
                ctrl_s.exception <= EXC_BREAKPOINT;
              else
                ctrl_s.exception <= EXC_ILLEGAL_INSTR;
              end if;

            else
              ctrl_s.exception <= EXC_ILLEGAL_INSTR;
            end if;

        when others =>
          ctrl_s.exception <= EXC_ILLEGAL_INSTR;

      end case;
    end if;

  end process;
end architecture;