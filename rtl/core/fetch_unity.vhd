---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : fetch_unity.vhd
-- Module Name    : Fetch Unity
-- Description    : Interface between the core and i$
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : F/ID
-- AUTHOR         : Lucas O. Bernardes
-- TODO: Test and verify if i$ stall is a bottleneck for the core
-- if it's the bottleneck make a fetch buffer.
---------------------------------------------------------------

library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity fetch_unity is
  port(

    i_clk              : in std_logic;
    i_nrst             : in std_logic;

    i_flush            : in std_logic;
    -- f interfce
    i_f_stall       : in std_logic;
    o_f_icache_stall : out std_logic;

    --i$ interface
    -- request channel
    o_i1_req_valid     : out std_logic;
    o_i1_req_addr      : out std_logic_vector(31 downto 0);
    i_i1_req_ready     : in std_logic; -- Is the instruction in i1 cache?
    -- response channel
    i_i2_rsp_valid  : in std_logic;
    i_i2_rsp_instr  : in std_logic_vector(31 downto 0);
    o_i2_rsp_ready  : out std_logic;

    -- f/id interface
    i_id_external_stall : in std_logic;
    o_id_cache_stall    : out std_logic;
    o_id_instr          : out std_logic_vector(31 downto 0);
    o_id_valid_instr    : out std_logic;

    -- Branch interface
    i_ex_branch_req   : in std_logic;
    i_ex_stall        : in std_logic;
    i_ex_branch_addr  : in std_logic_vector(31 downto 0)
  );
end entity;

architecture request of fetch_unity is

  signal clk_s              : std_logic;
  signal nrst_s             : std_logic;
  --f
  signal f_stall_s          : std_logic;
  signal f_unity_stall_s    : std_logic;

  -- branching signals
  signal ex_branch_req_s  : std_logic;
  signal ex_branch_addr_s : std_logic_vector(31 downto 0);
  -- i$
  --req
  signal i1_req_valid_s   : std_logic;
  signal i1_req_addr_s    : std_logic_vector(31 downto 0);
  -- rsponse
  signal i2_rsp_valid_s   : std_logic;
  signal i2_rsp_instr_s   : std_logic_vector(31 downto 0);
  signal i2_rsp_ready_s   : std_logic;
  -- id signals
  signal id_instr_s          : std_logic_vector(31 downto 0);
  signal id_valid_instr_s    : std_logic;
  signal id_external_stall_s : std_logic;
  signal id_stall_s          : std_logic;

  -- control signals
  signal i1_fire_s                      : std_logic;
  signal i1_req_ready_s                 : std_logic;
  signal f_addr_d, f_addr_q             : std_logic_vector(31 downto 0);
  signal increased_addr_s               : unsigned(31 downto 0);
  signal ex_stall_s                     : std_logic;
  signal i2_fire_s                      : std_logic;
  signal request_done_d, request_done_q : std_logic;

begin

  clk_s  <= i_clk;
  nrst_s <= i_nrst;

  o_f_icache_stall <= f_unity_stall_s;
  f_stall_s       <= i_f_stall;

  ex_branch_req_s    <= i_ex_branch_req;
  ex_branch_addr_s   <= i_ex_branch_addr;
  ex_stall_s         <= i_ex_stall;

  o_i1_req_valid     <= i1_req_valid_s;
  o_i1_req_addr      <= i1_req_addr_s;
  i1_req_ready_s     <= i_i1_req_ready;
  --
  i2_rsp_valid_s     <= i_i2_rsp_valid;
  i2_rsp_instr_s     <= i_i2_rsp_instr;
  o_i2_rsp_ready     <= i2_rsp_ready_s;

  id_external_stall_s <= i_id_external_stall;
  o_id_instr          <= id_instr_s;
  o_id_valid_instr    <= id_valid_instr_s;
  o_id_cache_stall    <= id_stall_s;


  ------------------------------------------------
  -- i$ handshake
  ------------------------------------------------
  i1_req_valid_s <= '1' when ex_branch_req_s = '1' and ex_stall_s = '0' else
                    '1' when f_stall_s = '0' else
                    '0';

  i1_fire_s <= i1_req_valid_s and i1_req_ready_s;

  i2_rsp_ready_s <= '0' when id_external_stall_s = '1' else
                    '1';

  i2_fire_s <= i2_rsp_ready_s and i2_rsp_valid_s;

  ------------------------------------------------
  -- Address generation
  ------------------------------------------------
  increased_addr_s <= unsigned(i1_req_addr_s(31 downto 2) & "00") + x"000_0004";

  f_addr_d <= ex_branch_addr_s when ex_branch_req_s = '1' and ex_stall_s = '0' else
              f_addr_q         when f_stall_s = '1' else
              std_logic_vector(increased_addr_s);

  ------------------------------------------------
  -- addr attribution
  ------------------------------------------------
  i1_req_addr_s   <= ex_branch_addr_s when ex_branch_req_s = '1' else
                     f_addr_q;

  id_instr_s <= i2_rsp_instr_s;

  id_valid_instr_s <= '1' when i2_fire_s = '1' else
                      '0';

  ------------------------------------------------
  -- Request control logic
  ------------------------------------------------
  request_done_d <= '0' when f_stall_s = '0' else

  ------------------------------------------------
  -- Stall management
  ------------------------------------------------

  id_stall_s <= '1' when i2_fire_s = '0' else
                '0';

  f_unity_stall_s  <= '1' when i1_fire_s = '0' else
                      '0';

  p_addr_inc : process(clk_s, nrst_s)
  begin
    if nrst_s = '0' then
      f_addr_q <= (others => '0');

    elsif rising_edge(clk_s) then
      f_addr_q <= f_addr_d;

    end if;
  end process;
end architecture;