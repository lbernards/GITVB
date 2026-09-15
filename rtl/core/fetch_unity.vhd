library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity fetch_buffer is
  port(

    -- f interfce
    i_f_branch_req   : in std_logic;
    i_f_branch_addr  : in std_logic_vector(31 downto 0);
    --i$ interface
    -- request channel
    o_i1_req_valid     : out std_logic;
    o_i1_req_addr      : out std_logic_vector(31 downto 0);
    -- response channel
    i_i2_rsp_valid  : in std_logic;
    i_i2_rsp_instr  : in std_logic_vector(31 downto 0);
    o_i2_rsp_ready  : out std_logic;

    -- f/id interface
    o_id_instr       : out std_logic_vector(31 downto 0);
    o_id_valid_instr : out std_logic
  );
end entity;

architecture request of fetch_buffer is
  --f
  signal f_branch_req_s  : std_logic;
  signal f_branch_addr_s : std_logic_vector(31 downto 0);
  -- i$
  --req
  signal i1_req_valid_s   : std_logic;
  signal i1_req_addr_s    : std_logic_vector(31 downto 0);
  -- rsponse
  signal i2_rsp_valid_s   : std_logic;
  signal i2_rsp_instr_s   : std_logic_vector(31 downto 0);
  signal i2_rsp_ready_s   : std_logic;
  -- id signals
  signal id_instr_s       : std_logic_vector(31 downto 0);
  signal id_valid_instr_s : std_logic;

  -- control signals


begin

  f_branch_req_s   <= i_f_branch_req;
  f_branch_addr_s  <= i_f_branch_addr;

  o_i1_req_valid   <= i1_req_valid_s;
  o_i1_req_addr    <= i1_req_addr_s;
  --
  i2_rsp_valid_s   <= i_i2_rsp_valid;
  i2_rsp_instr_s   <= i_i2_rsp_instr;
  o_i2_rsp_ready   <= i2_rsp_ready_s;

  o_id_instr       <= id_instr_s;
  o_id_valid_instr <= id_valid_instr_s;


end architecture;