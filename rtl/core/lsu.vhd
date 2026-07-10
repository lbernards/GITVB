library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library packages;
use packages.cpu_types_pkg.all;

entity lsu is
  port(
    i_clk             : in std_logic;
    i_nrst            : in std_logic;
    -- EX/MEM INTERFACE
    i_mem_address     : in std_logic_vector(31 downto 0); -- This is the request address (that came from ALU)
    i_mem_rv2         : in std_logic_vector(31 downto 0); -- Thats the data used in store
    i_mem_size        : in mem_size_t;
    i_mem_unsigned    : in std_logic;
    i_mem_write       : in std_logic;
    i_mem_read        : in std_logic;
    -- D$ interface
    --request channel
    o_i1_req_valid       : out std_logic; -- valid request (load/store)
    i_i1_cache_ready     : in  std_logic; -- D$ is able to accept the request
    o_i1_req_addr        : out std_logic_vector(31 downto 0); -- Mem operation address
    o_i1_req_wdata       : out std_logic_vector(31 downto 0); -- Data to be written (store)
    o_i1_req_we          : out std_logic; -- write enable (1 = store, 0 = load)
    o_i1_req_size        : out mem_size_t; -- (byte/half/ord)
    o_i1_req_wmask       : out std_logic_vector(3 downto 0);
    -- resp channel
    i_i2_rsp_valid       : in  std_logic; -- valid response (load or store ack)
    o_i2_rsp_ready       : out std_logic; -- LSU is able to receive data
    i_i2_rsp_rdata       : in  std_logic_vector(31 downto 0); -- loaded data from D$
    -- MEM control
    o_mem_stall_s        : out std_logic;
    -- MEM/WB OUTPUT
    i_wb_stall           : in std_logic;
    o_wb_lsu_stall       : out std_logic;
    o_wb_rdata           : out std_logic_vector(31 downto 0);
    o_wb_valid_rdata     : out std_logic
  );
end entity;

architecture logic of lsu is

  signal clk_s                : std_logic;
  signal nrst_s               : std_logic;

  signal i1_address_s         : std_logic_vector(31 downto 0);
  signal i1_store_data_s      : std_logic_vector(31 downto 0);
  signal i1_data_size_s       : mem_size_t;
  signal i1_unsigned_s        : std_logic;
  signal i1_write_s           : std_logic;
  signal i1_read_s            : std_logic;
  signal i1_fire_s            : std_logic;
  signal i1_cache_ready_s     : std_logic;

  signal req_address_s        : std_logic_vector(31 downto 0);
  signal i1_req_valid_s       : std_logic;
  signal i1_req_ready_s       : std_logic;
  signal i1_req_we_s          : std_logic;
  signal i1_req_wmask_s       : std_logic_vector(3 downto 0);
  signal i1_req_wdata_s       : std_logic_vector(31 downto 0);

  signal i2_rsp_valid_s       : std_logic;
  signal i2_rsp_ready_s       : std_logic;
  signal i2_rsp_rdata_s       : std_logic_vector(31 downto 0);
  signal i2_rsp_valid_rdata_s : std_logic;

  signal i2_fire_s            : std_logic;
  signal i2_data_size_s       : mem_size_t;
  signal i2_read_s            : std_logic;
  signal i2_size_mask_s       : std_logic_vector(31 downto 0);
  signal i2_unsigned_s        : std_logic;
  signal i2_rdata_s           : std_logic_vector(31 downto 0);
  signal i2_valid_read_s      : std_logic;

  -- Control singals
  signal mem_stall_s            : std_logic;
  signal misaligned_s           : std_logic;
  signal mem_stall_by_dreq_s    : std_logic;
  signal wb_stall_s             : std_logic;
  signal wb_external_stall_s    : std_logic;
  signal req_done_d, req_done_q : std_logic;
  signal offset_s               : std_logic_vector(1 downto 0);
  signal high_wmask_s           : std_logic_vector(3 downto 0);
  signal low_wmask_s            : std_logic_vector(3 downto 0);
  signal signal_extend_s        : std_logic_vector(23 downto 0);
  signal next_rounded_addr_s    : unsigned(31 downto 0);
  signal increased_addr_s       : std_logic_vector(31 downto 0);
  signal high_wdata_s           : std_logic_vector(31 downto 0);
  signal low_wdata_s            : std_logic_vector(31 downto 0);
  signal rounded_addr_s         : std_logic_vector(31 downto 0);
  signal masked_rdata_s         : std_logic_vector(31 downto 0);
  signal rdata_s                : std_logic_vector(31 downto 0);
  signal low_rdata_s            : std_logic_vector(31 downto 0);
  signal low_rdata_q            : std_logic_vector(31 downto 0);
  signal high_rdata_s           : std_logic_vector(31 downto 0);

  -- control FSM
  type lsu_state_t is (S_MEM_IDLE, S_MEM_DWRITE, S_MEM_DREAD, S_MEM_DREAD_DONE); -- DREAD = double read
  signal lsu_fsm_d, lsu_fsm_q : lsu_state_t; --

begin

  clk_s                <= i_clk;
  nrst_s               <= i_nrst;
  -- EX/MEM
  i1_address_s         <= i_mem_address;
  i1_store_data_s      <= i_mem_rv2;
  i1_data_size_s       <=  i_mem_size;
  i1_unsigned_s        <= i_mem_unsigned;
  i1_write_s           <= i_mem_write;
  i1_read_s            <= i_mem_read;

  o_mem_stall_s        <= mem_stall_s;

  -- D$ interface signals
  -- Request channel
  o_i1_req_valid       <= i1_req_valid_s;
  i1_cache_ready_s     <= i_i1_cache_ready;
  o_i1_req_addr        <= req_address_s;
  o_i1_req_wdata       <= i1_req_wdata_s;
  o_i1_req_we          <= i1_req_we_s;
  o_i1_req_size        <= i1_data_size_s;
  o_i1_req_wmask       <= i1_req_wmask_s;
  -- Response channel
  i2_rsp_valid_rdata_s  <= i_i2_rsp_valid;
  o_i2_rsp_ready        <= i2_rsp_ready_s;
  i2_rsp_rdata_s        <= i_i2_rsp_rdata;

  -- MEM/WB
  wb_external_stall_s   <= i_wb_stall;
  o_wb_lsu_stall        <= wb_stall_s;
  o_wb_rdata            <= i2_rdata_s;
  o_wb_valid_rdata      <= i2_valid_read_s;


  ------------------------------------------------
  -- LSU handshake
  ------------------------------------------------
  -- i1 (request for read or write)
  i1_req_valid_s <= '0' when req_done_q = '1' else
                    '1' when lsu_fsm_q = S_MEM_DREAD else
                    '1' when lsu_fsm_q = S_MEM_DWRITE else
                    '1' when i1_write_s = '1' else
                    '1' when i1_read_s = '1'  else
                    '0';

  i1_req_ready_s  <= i1_cache_ready_s when lsu_fsm_q = S_MEM_IDLE and i1_write_s = '1' else
                     i1_cache_ready_s when lsu_fsm_q = S_MEM_DWRITE else
                     '1'; -- Request will not write in write buffer

  i1_fire_s      <= '1' when i1_req_valid_s = '1' and i1_req_ready_s = '1' else
                    '0';

  i1_req_we_s    <= '1' when lsu_fsm_q = S_MEM_DWRITE else
                    '1' when i1_write_s = '1' else
                    '0';

  -- i2 (response)
  i2_fire_s      <= '1' when i2_rsp_valid_s = '1' and i2_rsp_ready_s = '1' else
                    '0';

  i2_rsp_valid_s <= '1' when i2_rsp_valid_rdata_s = '1' else
                    '0';

  i2_rsp_ready_s <= '0' when wb_external_stall_s = '1' else
                    '1';

  ------------------------------------------------
  -- MEM data operation
  ------------------------------------------------
  -- The address will be kept in the flop EX/MEM during double request, due to stall. So,
  -- we dont need to save the address again for i2, since we already will have it, saving space and energy.
  offset_s <= i1_address_s(1 downto 0);

  ------------ Write (store)-----------------------------------------------------------------------------------------------
  low_wmask_s <= "0001" when offset_s = "00" and i1_data_size_s = MEM_BYTE else
                 "0011" when offset_s = "00" and i1_data_size_s = MEM_HALF else
                 "1111" when offset_s = "00" and i1_data_size_s = MEM_WORD else
                 "0010" when offset_s = "01" and i1_data_size_s = MEM_BYTE else
                 "0110" when offset_s = "01" and i1_data_size_s = MEM_HALF else
                 "1110" when offset_s = "01" and i1_data_size_s = MEM_WORD else
                 "0100" when offset_s = "10" and i1_data_size_s = MEM_BYTE else
                 "1100" when offset_s = "10" else
                 "1000" when offset_s = "11" else
                 "0000";

  --If mem half we must only send one more byte. Else the complement of the word must be sent.
  high_wmask_s <= "0001" when i1_data_size_s = MEM_HALF else
                  not low_wmask_s;  -- Only word size will activate this.


  low_wdata_s <= i1_store_data_s                          when offset_s = "00" else
                 i1_store_data_s(23 downto 0) & x"00"     when offset_s = "01" else
                 i1_store_data_s(15 downto 0) & x"0000"   when offset_s = "10" else
                 i1_store_data_s(7 downto 0)  & x"000000" when offset_s = "11" else
                 (others => '0');

  -- Write data for the second request (High data).
  high_wdata_s    <= x"000000" & i1_store_data_s(15 downto  8) when i1_data_size_s = MEM_HALF else
                     x"000000" & i1_store_data_s(31 downto 24) when offset_s = "01" else
                     x"0000"   & i1_store_data_s(31 downto 16) when offset_s = "10" else
                     x"00"     & i1_store_data_s(31 downto  8) when offset_s = "11" else
                     (others => '0');

  ------------ Read (Load)---------------------------------------------------------------------------------------------
  low_rdata_s  <= low_rdata_q                            when wb_stall_s = '1' else
                  low_rdata_q                            when lsu_fsm_q = S_MEM_DREAD_DONE else
                  i2_rsp_rdata_s                         when lsu_fsm_q = S_MEM_IDLE else
                  x"00" & i2_rsp_rdata_s(23 downto 0)    when offset_s = "01" else
                  x"0000" & i2_rsp_rdata_s(15 downto 0)  when offset_s = "10" else
                  x"000000" & i2_rsp_rdata_s(7 downto 0) when offset_s = "11" else
                  (others => '0');

  -- Second read data request.
  high_rdata_s <= (others => '0')                              when lsu_fsm_q /= S_MEM_DREAD_DONE else
                  i2_rsp_rdata_s(7 downto 0) & x"000000"       when offset_s = "01" else
                  i2_rsp_rdata_s(15 downto 0) & x"0000"        when offset_s = "10" else
                  i2_rsp_rdata_s(23 downto 0) & x"00"          when offset_s = "11" and i2_data_size_s = MEM_WORD else
                  x"0000" & i2_rsp_rdata_s(7 downto 0) & x"00" when offset_s = "11" and i2_data_size_s = MEM_HALF else
                  (others => '0');

  -- Mask and signal extension
  rdata_s <= high_rdata_s or low_rdata_s;

  signal_extend_s <= (others => rdata_s(7))  when i2_data_size_s = MEM_BYTE else
                     (others => rdata_s(15)) when i2_data_size_s = MEM_HALF else
                     (others => '0');

  i2_size_mask_s <= x"FFFF_FFFF" when i2_data_size_s = MEM_WORD else
                    x"0000_FFFF" when i2_data_size_s = MEM_HALF else
                    x"0000_00FF" when i2_data_size_s = MEM_BYTE else
                    x"0000_0000";

  masked_rdata_s <= rdata_s and i2_size_mask_s;

  i2_rdata_s <= masked_rdata_s                                             when i2_data_size_s = MEM_WORD else
                masked_rdata_s                                             when i2_unsigned_s = '1' else
                signal_extend_s(15 downto 0) & masked_rdata_s(15 downto 0) when i2_data_size_s = MEM_HALF else
                signal_extend_s & masked_rdata_s(7 downto 0)               when i2_data_size_s = MEM_BYTE else
                (others => '0');

  i2_valid_read_s <= '1' when lsu_fsm_q = S_MEM_DREAD_DONE else
                     '0' when lsu_fsm_q /= S_MEM_IDLE else
                     '1' when i2_fire_s = '1' else
                     '0';

  ----------------------------------------------------------
  -- DATA MISALIGNMENT (double request)
  ----------------------------------------------------------
  -- When the request address is not aligned and we traspass
  -- the D$ line, we must make two request for D$, so we can
  -- read/write the whole data
  ----------------------------------------------------------
  misaligned_s  <= '0' when i1_req_valid_s = '0' else
                   '0' when lsu_fsm_q /= S_MEM_IDLE else  -- Means that the second req has succesfully been done
                   '1' when offset_s = "11" and i1_data_size_s /= MEM_BYTE else
                   '1' when offset_s /= "00" and i1_data_size_s = MEM_WORD else
                   '0';

  req_address_s <= increased_addr_s when lsu_fsm_q = S_MEM_DREAD else
                   increased_addr_s when lsu_fsm_q = S_MEM_DWRITE else
                   i1_address_s;

  -- We will use the same i1_address to elaborate the second request, since the EX/MEM buffer is
  -- stalled during double request
  rounded_addr_s <= i1_address_s and x"FFFF_FFFC";

  next_rounded_addr_s  <= unsigned(rounded_addr_s) + x"0000_0004"; -- Going to the next line

  increased_addr_s <= std_logic_vector(next_rounded_addr_s);

  -----------------
  -- For write
  i1_req_wmask_s <= high_wmask_s when lsu_fsm_q = S_MEM_DWRITE  else
                    low_wmask_s  when lsu_fsm_q = S_MEM_IDLE and i1_write_s = '1' else
                    (others => '0');

  i1_req_wdata_s <= high_wdata_s when lsu_fsm_q = S_MEM_DWRITE else
                    low_wdata_s  when lsu_fsm_q = S_MEM_IDLE and i1_write_s = '1' else
                    (others => '0');

  ----------------------------------------------------------------------------------------------------
  -- Stall management
  ----------------------------------------------------------------------------------------------------
  -- When valid is 0 it doesn`t mean we must stall.
  mem_stall_s <= '1' when wb_stall_s = '1' else
                 '1' when i1_req_valid_s = '1' and i1_req_ready_s = '0' else -- fire_s = '0'
                 '0' when lsu_fsm_q = S_MEM_DWRITE or lsu_fsm_q = S_MEM_DREAD else -- Double request stop condition
                 '1' when misaligned_s = '1' else -- Start double request
                 '0';

  -- If stalled by double request (dreq), fsm can change state.
  mem_stall_by_dreq_s <= '0' when wb_stall_s = '1' else
                         '0' when i1_req_valid_s = '1' and i1_req_ready_s = '0' else
                         '0' when lsu_fsm_q /= S_MEM_IDLE else
                         '1' when misaligned_s = '1' else
                         '0';

  wb_stall_s <= '1' when wb_external_stall_s = '1' else
                '0' when i2_read_s = '0' else
                '1' when i2_fire_s = '0' else
                '0';

  ----------------------------------------------------------------------------------------------------
  -- Request control logic
  ----------------------------------------------------------------------------------------------------
  req_done_d <= '0' when lsu_fsm_q /= lsu_fsm_d else
                '0' when mem_stall_s = '0' else
                '1' when i1_fire_s = '1' else
                req_done_q;

  ----------------------------------
  -- Flopping to i2
  ----------------------------------
  p_control_mem : process(clk_s, nrst_s)
  begin
    if nrst_s = '0' then
      lsu_fsm_q       <= S_MEM_IDLE;
      low_rdata_q     <= (others => '0');
      i2_read_s       <= '0';
      i2_unsigned_s   <= '0';
      i2_data_size_s  <= MEM_WORD;
      req_done_q      <= '0';

    elsif rising_edge(clk_s) then
      req_done_q      <= req_done_d;
      lsu_fsm_q       <= lsu_fsm_d;
      low_rdata_q     <= low_rdata_s;

      if wb_stall_s = '0' then
        i2_read_s       <= i1_read_s;
        i2_unsigned_s   <= i1_unsigned_s;
        i2_data_size_s  <= i1_data_size_s;
      end if;

    end if;
  end process;

  ------------------------------------------------
  -- FSM behavior
  ------------------------------------------------
  p_fsm_behavior : process(all)
  begin
    case lsu_fsm_q is
      when S_MEM_IDLE =>
        lsu_fsm_d <= lsu_fsm_q;
        if misaligned_s = '1' and mem_stall_by_dreq_s = '1' and mem_stall_s = '1' then
          if i1_write_s = '1' then
            lsu_fsm_d <= S_MEM_DWRITE;
          elsif i1_read_s = '1' then
            lsu_fsm_d <= S_MEM_DREAD;
          else
            lsu_fsm_d <= lsu_fsm_q;
          end if;
        end if;

      when S_MEM_DWRITE =>
        lsu_fsm_d <= lsu_fsm_q;
        if mem_stall_s = '0' then
          lsu_fsm_d <= S_MEM_IDLE;
        end if;

      when S_MEM_DREAD =>
        lsu_fsm_d <= lsu_fsm_q;
        if mem_stall_s = '0' then
          lsu_fsm_d <= S_MEM_DREAD_DONE;
        end if;

      when S_MEM_DREAD_DONE =>
        lsu_fsm_d <= lsu_fsm_q;
        if wb_stall_s = '0' then

          -- This condition won't happen if i1 hasn't fired
          if misaligned_s = '1' and mem_stall_by_dreq_s = '1' and mem_stall_s = '1' then
            if i1_write_s = '1' then
              lsu_fsm_d <= S_MEM_DWRITE;
            elsif i1_read_s = '1' then
              lsu_fsm_d <= S_MEM_DREAD;
            else
              lsu_fsm_d <= S_MEM_IDLE;
            end if;

          else
            lsu_fsm_d <= S_MEM_IDLE;
          end if;

        end if;

      when others =>
        lsu_fsm_d <= S_MEM_IDLE;

    end case;
  end process;

end architecture;