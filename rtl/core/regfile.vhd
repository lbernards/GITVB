library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity regfile is

  port(
    i_clock      : in std_logic;
    i_nreset     : in std_logic;
    -- Reading data from regfle
    i_id_read_en    : in std_logic;
    i_id_rs1        : in std_logic_vector(4 downto 0);
    i_id_rs2        : in std_logic_vector(4 downto 0);
    o_ex_valid_data : out std_logic;
    o_ex_rv1        : out std_logic_vector(31 downto 0);
    o_ex_rv2        : out std_logic_vector(31 downto 0);
    -- writing data from wb
    i_wb_rd         : in std_logic_vector(4 downto 0);
    i_wb_write_en   : in std_logic;
    i_wb_data       : in std_logic_vector(31 downto 0);
    -- Pipeline control
    o_id_stall      : out std_logic;
  );

end entity;

architecture reg_sw of regfile is

  signal clk_s              : std_logic;
  signal nrst_s             : std_logic;
  --Reading data from regfile signals
  signal id_read_en_s       : std_logic;
  signal id_rs1_s           : std_logic_vector(4 downto 0);
  signal id_rs2_s           : std_logic_vector(4 downto 0);
  signal id_valid_read_s    : std_logic;
  signal ex_valid_data_s    : std_logic;
  signal ex_rv1_s           : std_logic_vector(31 downto 0);
  signal ex_rv2_s           : std_logic_vector(31 downto 0);
  -- Writing in regfile signals
  signal wb_write_en_s      : std_logic;
  signal wb_rd_s            : std_logic_vector(4 downto 0);
  signal wb_data_s       : std_logic_vector(31 downto 0);

  -- Regfile type and signal declaration. Since I don't have any compiler for SRAM,
  -- I will be doing it thist way.
  type t_regfile is array (0 to 31) of std_logic_vector(31 downto 0);
  signal regfile_s : t_regfile := (others => (others => '0'));

  -- Operation signals
  signal id_stall_s : std_logic;
  signal stall_s    : std_logic;

begin

  -- Input signals
  clk_s      <= i_clock;
  nrst_s     <= i_nreset;
  -------------------------------------------
  -- Reading signals
  -------------------------------------------
  -- Input
  id_read_en_s    <= i_id_read_en;
  id_rs1_s        <= i_rs1;
  id_rs2_s        <= i_rs2;
  -- Output
  o_ex_valid_data <= ex_valid_data_s;
  o_ex_rv1        <= ex_rv1_s;
  o_ex_rv2        <= ex_rv2_s;

  -------------------------------------------
  -- Writing signals
  -------------------------------------------
  wb_write_en_s   <= i_wb_write_en;
  wb_rd_s         <= i_wb_rd;
  wb_data_s       <= i_wb_data;

  -------------------------------------------
  -- Stall management
  -------------------------------------------
  -- If read/write the same register in the cycle
  -- then stall the pipeline from read (id), write priority
  -- Ex.: ADD t0, t1, t2
  --      ADD t3, t0, t2    (requested t0 from instruction before)

  -- TODO: In the future must implement a bypass from wb directly to ex
  -- so there will be no usuless bubble. Still thinking the best and
  -- safest way to do it.

  id_stall_s <= '0' when nrst_s = '0' else
                '0' when id_read_en_s = '0' else
                '0' when wb_write_en_s = '0' else
                '0' when wb_rd_s /= id_rs1_s and wb_rd_s /= id_rs2_s else
                '1';

  stall_s <= id_stall_s;

  o_id_stall <= id_stall_s;

  -------------------------------------------
  -- Writing in regfile process
  -------------------------------------------
  p_reg_write : process(clk_s, nrst_s)
  begin

    if nrst_s = '0' then --Dangerous for ASIC!! Be careful
      for i in 1 to 31 loop
        regfile_s(i) <= (others => '0');
      end loop;

    elsif rising_edge(clk_s) then
      if wb_write_en_s = '1' and wb_rd_s /= "00000"then
        regfile_s(to_integer(unsigned(wb_rd_s))) <=  wb_data_s;
      end if;
    end if;
  end process;

  -------------------------------------------
  -- Reading in regfile process
  -------------------------------------------
  p_reg_read : process(clk_s, nrst_s)
  begin

    if nrst_s = '0' then
      ex_valid_data_s <= '0';
      ex_rv1_s        <= (others => '0');
      ex_rv2_s        <= (others => '0');

    elsif rising_edge(clk_s) then
      if id_valid_read_s = '1' then
        ex_rv1_s <= regfile_s(to_integer(unsigned(id_rs1_s)));
        ex_rv2_s <= regfile_s(to_integer(unsigned(id_rs2_s)));
      end if;

      ex_valid_data_s <= id_valid_read_s;
    end if;
  end process;

  id_valid_read_s <= '0' when id_stall_s = '1' else
                     '0' when id_read_en_s = '0' else
                     '1';

end architecture;