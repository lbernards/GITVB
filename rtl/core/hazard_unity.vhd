---------------------------------------------------------------
--          _____  _____  _____  ______      ______
--         |  __ \|_   _|/ ____|/ ___\ \    / /  _ \
--         | |__) | | | | (___ | |    \ \  / /| |_) |
--         |  _  /  | |  \___ \| |     \ \/ / |  _ <
--         | | \ \ _| |_ ____) | |____  \  /  | |_) |
--         |_|  \_\_____|_____/ \____/   \/   |____/
---------------------------------------------------------------
-- File name      : hazard_unit.vhd
-- Module Name    : Hazard Unit
-- Description    : Detects and resolves data hazards via forwarding.
--                  Currently implements WB->ID bypass.
-- PIPELINE       : F/ID/EX/MEM/WB
-- PIPELINE STAGE : ID (resolves before ID/EX register)
-- AUTHOR         : Lucas O. Bernardes
---------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity hazard_unit is
  port(
    -- From F stage:
    i_f_ichache_stall   : in std_logic;
    -- From ID stage: registers being read
    i_id_rs1            : in  std_logic_vector(4 downto 0);
    i_id_rs2            : in  std_logic_vector(4 downto 0);
    i_id_reg_read_en    : in  std_logic;
    -- From WB stage
    i_wb_rd             : in  std_logic_vector(4 downto 0);
    i_wb_write_en       : in  std_logic;
    -- From MEM stage
    i_mem_rd            : in std_logic_vector(4 downto 0);
    i_mem_reg_write_en  : in std_logic;
    i_mem_write_en      : in std_logic;
    i_mem_rs2           : in std_logic_vector(4 downto 0);
    i_mem_lsu_stall     : in std_logic;
    -- From EX stage
    i_ex_rs1            : in std_logic_vector(4 downto 0);
    i_ex_rs2            : in std_logic_vector(4 downto 0);
    i_ex_rd             : in std_logic_vector(4 downto 0);
    i_ex_jump_req       : in std_logic;
    i_ex_branch_taken   : in std_logic;
    i_ex_mem_read_en    : in std_logic;
    -- Regfile bypass selector
    o_id_rv1_bypass     : out std_logic;
    o_id_rv2_bypass     : out std_logic;
    -- Ex bypass selector
    o_ex_rv1_mem_bypass : out std_logic;
    o_ex_rv2_mem_bypass : out std_logic;
    o_ex_rv1_wb_bypass  : out std_logic;
    o_ex_rv2_wb_bypass  : out std_logic;
    -- Mem bypass (WB -> MEM for store after op)
    o_mem_store_bypass  : out std_logic;
    -- Flush management
    o_f_flush           : out std_logic;
    o_id_flush          : out std_logic;
    -- Stall signals
    o_ex_stall          : out std_logic;
    o_id_stall          : out std_logic;
    o_f_stall           : out std_logic;
    -- Bubble signals
    o_id_bubble         : out std_logic;
    o_ex_bubble         : out std_logic;
    o_mem_bubble        : out std_logic;
    o_wb_bubble         : out std_logic

  );
end entity;

architecture rtl of hazard_unit is

  -- input signals
  signal f_icache_stall_s   : std_logic;

  signal id_rs1_s           : std_logic_vector(4 downto 0);
  signal id_rs2_s           : std_logic_vector(4 downto 0);
  signal id_reg_read_en_s   : std_logic;

  signal ex_rs1_s           : std_logic_vector(4 downto 0);
  signal ex_rs2_s           : std_logic_vector(4 downto 0);
  signal ex_rd_s            : std_logic_vector(4 downto 0);
  signal ex_jump_req_s      : std_logic;
  signal ex_branch_taken_s  : std_logic;
  signal ex_mem_read_en_s   : std_logic;

  signal wb_rd_s            : std_logic_vector(4 downto 0);
  signal wb_write_en_s      : std_logic;

  signal mem_rd_s            : std_logic_vector(4 downto 0);
  signal mem_reg_write_en_s  : std_logic;
  signal mem_write_en_s      : std_logic;
  signal mem_rs2_s           : std_logic_vector(4 downto 0);
  signal mem_lsu_stall_s     : std_logic;
  -- Internal bypass enable signals
  signal id_rv1_bypass_s     : std_logic;
  signal id_rv2_bypass_s     : std_logic;

  signal ex_rv1_bypass_mem_s : std_logic;
  signal ex_rv2_bypass_mem_s : std_logic;
  signal ex_rv1_bypass_wb_s  : std_logic;
  signal ex_rv2_bypass_wb_s  : std_logic;

  signal mem_rv2_bypass_wb_s : std_logic;

  -- Flush control
  signal f_flush_s  : std_logic;
  signal id_flush_s : std_logic;

  -- Stall control
  signal f_stall_s              : std_logic;
  signal id_stall_s             : std_logic;
  signal id_load_hazard_stall_s : std_logic;
  signal mem_stall_s            : std_logic;
  signal ex_stall_s             : std_logic;

  -- Bubble control
  signal id_bubble_s            : std_logic;
  signal ex_bubble_s            : std_logic;
  signal mem_bubble_s           : std_logic;
  signal wb_bubble_s            : std_logic;

begin

  -----------------------------------------------------------------------------
  -- input
  -----------------------------------------------------------------------------
  f_icache_stall_s   <= i_f_ichache_stall;

  id_rs1_s           <= i_id_rs1;
  id_rs2_s           <= i_id_rs2;
  id_reg_read_en_s   <= i_id_reg_read_en;

  ex_rs1_s           <= i_ex_rs1;
  ex_rs2_s           <= i_ex_rs2;
  ex_rd_s            <= i_ex_rd;
  ex_jump_req_s      <= i_ex_jump_req;
  ex_branch_taken_s  <= i_ex_branch_taken;
  ex_mem_read_en_s   <= i_ex_mem_read_en;

  wb_rd_s            <= i_wb_rd;
  wb_write_en_s      <= i_wb_write_en;

  mem_rd_s            <= i_mem_rd;
  mem_reg_write_en_s  <= i_mem_reg_write_en;
  mem_write_en_s      <= i_mem_write_en;
  mem_rs2_s           <= i_mem_rs2;
  mem_lsu_stall_s     <= i_mem_lsu_stall;

  -----------------------------------------------------------------------------
  -- output
  -----------------------------------------------------------------------------
  o_f_flush           <= f_flush_s;
  o_f_stall           <= f_stall_s;

  o_id_rv1_bypass     <= id_rv1_bypass_s;
  o_id_rv2_bypass     <= id_rv2_bypass_s;
  o_id_flush          <= id_flush_s;
  o_id_stall          <= id_stall_s;
  o_id_bubble         <= id_bubble_s;

  o_ex_rv1_mem_bypass <= ex_rv1_bypass_mem_s;
  o_ex_rv2_mem_bypass <= ex_rv2_bypass_mem_s;
  o_ex_rv1_wb_bypass  <= ex_rv1_bypass_wb_s;
  o_ex_rv2_wb_bypass  <= ex_rv2_bypass_wb_s;
  o_ex_stall          <= ex_stall_s;
  o_ex_bubble         <= ex_bubble_s;

  o_mem_store_bypass  <= mem_rv2_bypass_wb_s;
  o_mem_bubble        <= mem_bubble_s;

  o_wb_bubble         <= wb_bubble_s;

  -----------------------------------------------------------------------------
  -- WB -> ID Bypass detection
  -- Conditions to forward WB data to rs1/rs2:
  --   1. The source register is not x0
  --   2. The destination in WB is not x0
  --   3. The source matches the WB destination
  --   4. The ID stage is performing a read
  --   5. The WB stage is performing a write
  -----------------------------------------------------------------------------
  id_rv1_bypass_s <= '0' when  (id_rs1_s     = "00000") else
                     '0' when  (wb_rd_s      = "00000") else
                     '1' when  (id_rs1_s     = i_wb_rd)  and
                               (id_reg_read_en_s  = '1') and
                               (wb_write_en_s = '1')    else
                     '0';

  id_rv2_bypass_s <= '0' when (id_rs2_s     = "00000")  else
                     '0' when (wb_rd_s      = "00000")  else
                     '1' when (id_rs2_s      = i_wb_rd)  and
                              (id_reg_read_en_s  = '1')  and
                              (wb_write_en_s = '1')     else
                     '0';

  -----------------------------------------------------------------------------
  -- MEM -> EX Bypass detection
  -- Conditions to forward MEM data to rs1/rs2:
  --   1. The source register is not x0
  --   2. The destination in MEM is not x0
  --   3. The source matches the WB destination
  --   4. The MEM stage has a data that will perform a write in regfile (done after in wb)
  -----------------------------------------------------------------------------
  ex_rv1_bypass_mem_s <= '0' when (ex_rs1_s = "00000")       else
                         '0' when (mem_rd_s = "00000")       else
                         '1' when (ex_rs1_s = mem_rd_s)       and
                                 (mem_reg_write_en_s = '1') else
                         '0';

  ex_rv2_bypass_mem_s <= '0' when (ex_rs2_s = "00000")       else
                         '0' when (mem_rd_s = "00000")       else
                         '1' when (ex_rs2_s = mem_rd_s)       and
                                  (mem_reg_write_en_s = '1') else
                         '0';

  -----------------------------------------------------------------------------
  -- WB -> EX Bypass detection
  -- Conditions to forward MEM data to rs1/rs2:
  --   1. The source register is not x0
  --   2. The destination in MEM is not x0
  --   3. The source matches the WB destination
  --   4. The WB stage has a data that will perform a write in regfile
  -----------------------------------------------------------------------------
  ex_rv1_bypass_wb_s <= '0' when (ex_rs1_s = "00000")        else
                        '0' when (wb_rd_s  = "00000")        else
                        '1' when (wb_write_en_s = '1')        and
                                 (ex_rs1_s = wb_rd_s)        else
                        '0';

  ex_rv2_bypass_wb_s <= '0' when (ex_rs2_s = "00000")        else
                        '0' when (wb_rd_s  = "00000")        else
                        '1' when (wb_write_en_s = '1')        and
                                 (ex_rs2_s = wb_rd_s)        else
                        '0';

  -----------------------------------------------------------------------------
  -- WB -> MEM Bypass detection
  -- Conditions to forward WB data to store in MEM:
  --   1. The source register is not x0
  --   2. The destination in MEM is not x0
  --   3. The RS2 in MEM matches the WB destination (data to be written in d$)
  --   4. The WB stage has a data that will perform a write in regfile
  --   5. The MEM stage will store in d$
  -----------------------------------------------------------------------------
  mem_rv2_bypass_wb_s <= '0' when (mem_rs2_s = "00000") else
                         '0' when (wb_rd_s   = "00000") else
                         '1' when (wb_write_en_s  = '1') and
                                  (mem_write_en_s = '1') and
                                  (mem_rs2_s = wb_rd_s) else
                        '0';

  -----------------------------------------------------------------------------
  -- Flush control
  -- For simplicity in the first version of the core, jump and branch are done in EX
  -- todo: JUMP resolved in ID
  -----------------------------------------------------------------------------
  id_flush_s <= '1' when (ex_branch_taken_s = '1') else
                '1' when (ex_jump_req_s = '1') else
                '0';

  f_flush_s <= '1' when (id_flush_s = '1')    else
               '0';

  -----------------------------------------------------------------------------
  -- Load-use hazard
  -- Will stall the pipeline one cycle, so it will be possible to make a
  -- bypass from wb -> ex
  -----------------------------------------------------------------------------
  id_load_hazard_stall_s <= '0' when ex_mem_read_en_s = '0' else
                            '0' when ex_rd_s = "00000"       else
                            '0' when id_rs1_s = "00000"       and
                                     id_rs2_s = "00000"      else
                            '1' when ex_rd_s = id_rs1_s      else
                            '1' when ex_rd_s = id_rs2_s      else
                            '0';

  -----------------------------------------------------------------------------
  -- Stall management
  -- The interface between the i$ and d$ memory with core will be responsable to
  -- send the stall to hazard unity (when cache miss for instance). Initially
  -- the core will not have cache hierarchy, but in the future it will be useful
  -----------------------------------------------------------------------------
  mem_stall_s <= '1' when mem_lsu_stall_s = '1' else
                 '0';

  ex_stall_s <= '1' when mem_stall_s = '1' else
                '0';

  id_stall_s <= '1' when mem_stall_s = '1'            else
                '1' when ex_stall_s = '1'             else
                '1' when id_load_hazard_stall_s = '1' else
                '0';

  f_stall_s <= '1' when mem_stall_s = '1'      else
               '1' when ex_stall_s = '1'       else
               '1' when id_stall_s = '1'       else
               '1' when f_icache_stall_s = '1' else
               '0';

  -----------------------------------------------------------------------------
  -- Bubble management
  -- When we have a stall in the pipeline, the stages that are not stalled will
  -- continue to operate. The next stage of a stalled one must receive a bubble
  -- that will propagate in the pipeline.
  -----------------------------------------------------------------------------
  wb_bubble_s <= '1' when mem_stall_s = '1' else
                 '0';

  mem_bubble_s <= '0' when mem_stall_s = '1' else
                  '1' when ex_stall_s = '1'  else
                  '0';

  ex_bubble_s <= '0' when ex_stall_s = '1' else
                 '1' when id_stall_s = '1' else
                 '0';

  id_bubble_s <= '0' when id_stall_s = '1' else
                 '1' when f_stall_s = '1' else
                 '0';

end architecture;