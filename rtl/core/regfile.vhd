---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : regfile.vhd
-- Module Name    : Register File
-- Description    : RV32I 32x32 register file. Pure storage - no hazard
--                  logic. Bypass is resolved externally by hazard_unit
--                  and injected via i_bypass_rv* ports.
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : ID (read), WB (write)
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity regfile is
  port(
    i_clock           : in  std_logic;
    i_nreset          : in  std_logic;

    -- Read interface (ID stage)
    i_id_read_en      : in  std_logic; -- remove (goes to pipeline reg)
    i_id_rs1          : in  std_logic_vector(4 downto 0);
    i_id_rs2          : in  std_logic_vector(4 downto 0);
    o_id_rv1          : out std_logic_vector(31 downto 0); --remove
    o_id_rv2          : out std_logic_vector(31 downto 0); -- remove

    -- Write interface (WB stage)
    i_wb_rd           : in  std_logic_vector(4 downto 0);
    i_wb_write_en     : in  std_logic;
    i_wb_data         : in  std_logic_vector(31 downto 0);

    -- Bypass interface (resolved by hazard_unit)
    -- hazard_unit selects the most recent value among all forwarding
    -- candidates. When _en is asserted, _data is used instead of
    -- the register file output.
    i_bypass_rv1_en   : in  std_logic;
    i_bypass_rv2_en   : in  std_logic;
    i_bypass_rv_data  : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of regfile is

  -------------------------------------------
  -- Input interface signals
  -------------------------------------------
  signal clk_s              : std_logic;
  signal nrst_s             : std_logic;
  -- Read
  signal id_read_en_s       : std_logic;
  signal id_rs1_s           : std_logic_vector(4 downto 0);
  signal id_rs2_s           : std_logic_vector(4 downto 0);
  -- Write
  signal wb_rd_s            : std_logic_vector(4 downto 0);
  signal wb_write_en_s      : std_logic;
  signal wb_data_s          : std_logic_vector(31 downto 0);
  -- Bypass
  signal bypass_rv1_en_s    : std_logic;
  signal bypass_rv2_en_s    : std_logic;
  signal bypass_rv_data_s   : std_logic_vector(31 downto 0);

  -------------------------------------------
  -- Internal signals
  -------------------------------------------
  -- Register file: 32 registers of 32 bits.
  -- Implemented as flip-flops (small, timing-critical, simple r/w).
  -- x0 is never written (enforced in write process).
  -- No reset on the array: relies on software initialization.
  type t_regfile is array (0 to 31) of std_logic_vector(31 downto 0);
  signal regfile_s : t_regfile;

  signal id_rv1_s : std_logic_vector(31 downto 0);
  signal id_rv2_s : std_logic_vector(31 downto 0);

begin

  -------------------------------------------
  -- Input connections
  -------------------------------------------
  clk_s             <= i_clock;
  nrst_s            <= i_nreset;
  id_read_en_s      <= i_id_read_en;
  id_rs1_s          <= i_id_rs1;
  id_rs2_s          <= i_id_rs2;
  wb_rd_s           <= i_wb_rd;
  wb_write_en_s     <= i_wb_write_en;
  wb_data_s         <= i_wb_data;
  bypass_rv1_en_s   <= i_bypass_rv1_en;
  bypass_rv2_en_s   <= i_bypass_rv2_en;
  bypass_rv_data_s  <= i_bypass_rv_data;

  -------------------------------------------
  -- Output connections
  -------------------------------------------
  o_id_rv1        <= id_rv1_s;
  o_id_rv2        <= id_rv2_s;

  -------------------------------------------
  -- Write process (WB stage)
  -- Synchronous write, x0 protected.
  -- No reset: undefined at power-on by design.
  -------------------------------------------
  p_reg_write : process(clk_s)
  begin
    if rising_edge(clk_s) then
      if wb_write_en_s = '1' and wb_rd_s /= "00000" then
        regfile_s(to_integer(unsigned(wb_rd_s))) <= wb_data_s;
      end if;
    end if;
  end process;

  -------------------------------------------
  -- Combinational read with bypass mux
  -- Priority (low to high):
  --   regfile -> bypass (resolved by hazard_unit)
  -- x0 always reads as zero.
  -------------------------------------------
  id_rv1_s <= (others => '0')   when id_rs1_s = "00000"      else
              bypass_rv_data_s  when bypass_rv1_en_s = '1'   else
              regfile_s(to_integer(unsigned(id_rs1_s)));

  id_rv2_s <= (others => '0')   when id_rs2_s = "00000"      else
              bypass_rv_data_s  when bypass_rv2_en_s = '1'   else
              regfile_s(to_integer(unsigned(id_rs2_s)));

end architecture;