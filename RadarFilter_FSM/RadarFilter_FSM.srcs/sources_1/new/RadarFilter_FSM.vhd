-- RadarFilter_FSM
-- Top-level control FSM for the Radar Data Filter datapath.
--
-- Responsibilities:
--   1) After reset, clear RAM (write zeros to all 1024 locations).
--   2) On Start button: fill RAM with 6-bit random values (from LFSR_RNG_6bit).
--   3) On Read button: read a 3x3 neighborhood around (center_row_in,
--      center_col_in), apply zero-padding at edges, and load the 9 values
--      into Reg_Bank.
--   4) On Sort button: start BubbleSort9, wait until done, then write the
--      median value back into RAM at the center address.
--   5) Control 7-seg display mode:
--        "00" -> show unsorted 3x3 (RegBank r0..r8)
--        "01" -> show sorted 3x3 (BubbleSort y0..y8)
--        "10" -> show final filtered center value (median)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RadarFilter_FSM is
    port (
        clk   : in  std_logic;  -- 100 MHz system clock
        reset : in  std_logic;  -- synchronous, active-high

        -- Debounced button pulses (1-clock wide)
        btn_start_pulse : in  std_logic;  -- Start: RNG fill RAM
        btn_read_pulse  : in  std_logic;  -- Read: load 3x3 neighborhood
        btn_sort_pulse  : in  std_logic;  -- Sort: run Bubble_Sort, write median

        -- Center pixel coordinates (0..31)
        center_row_in : in std_logic_vector(4 downto 0); -- row index
        center_col_in : in std_logic_vector(4 downto 0); -- col index

        -- RAM interface
        ram_dout  : in  std_logic_vector(5 downto 0);     -- data read from RAM
        ram_addr  : out std_logic_vector(9 downto 0);     -- address to RAM
        ram_we    : out std_logic;                        -- write enable
        write_sel : out std_logic_vector(1 downto 0);
        -- write_sel encoding (for top-level RAM data mux):
        --   "00" -> write zeros
        --   "01" -> write RNG value
        --   "10" -> write median value

        -- RNG control
        rng_enable : out std_logic;                       -- enable LFSR_RNG_6bit

        -- Reg_Bank interface
        reg_data_in  : out std_logic_vector(5 downto 0);  -- value to load
        reg_load_sel : out std_logic_vector(3 downto 0);  -- which register 0..8
        reg_load_en  : out std_logic;                     -- load enable

        -- Bubble_Sort control
        sort_start : out std_logic;                       -- 1-clock pulse
        sort_done  : in  std_logic;                       -- from Bubble_Sort.done

        -- 7-seg display state (for FSM_7segment)
        display_state : out std_logic_vector(1 downto 0);
        --   "00" -> show unsorted 3x3 (r0..r8)
        --   "01" -> show sorted   3x3 (s0..s8)
        --   "10" -> show filtered center (median_value)

        -- Optional debug: FSM state encoding (for LEDs / ILA)
        state_debug : out std_logic_vector(3 downto 0)
    );
end RadarFilter_FSM;

architecture Behavioral of RadarFilter_FSM is

    -------------------------------------------------------------------------
    -- FSM states
    -------------------------------------------------------------------------
    type state_type is (
        S_RESET_INIT,        -- after reset, prepare to clear RAM
        S_CLEAR_RAM,         -- write zeros to all 1024 RAM locations
        S_IDLE,              -- RAM cleared, wait for Start / Read
        S_FILL_INIT,         -- prepare for random fill
        S_FILL_WRITE,        -- write RNG values across RAM
        S_WAIT_READ,         -- RAM filled, waiting for Read
        S_READ_INIT,         -- latch center row/col, reset neighbor index
        S_READ_NEIGHBOR,     -- loop over 3x3 neighbors, load Reg_Bank
        S_WAIT_SORT_BUTTON,  -- neighborhood loaded, wait for Sort
        S_SORT_WAIT,         -- Bubble_Sort running, wait for sort_done
        S_WRITE_MEDIAN,      -- write median back to RAM
        S_SHOW_FILTERED      -- show final filtered center until next command
    );

    signal state, next_state : state_type := S_RESET_INIT;

    -------------------------------------------------------------------------
    -- 10-bit address counter for CLEAR_RAM and FILL_WRITE (0..1023)
    -------------------------------------------------------------------------
    signal addr_counter : unsigned(9 downto 0) := (others => '0');

    -------------------------------------------------------------------------
    -- Latched center coordinates (0..31) for current neighborhood
    -------------------------------------------------------------------------
    signal center_row : unsigned(4 downto 0) := (others => '0');
    signal center_col : unsigned(4 downto 0) := (others => '0');

    -------------------------------------------------------------------------
    -- Neighbor index: 0..8 -> 3x3 window positions
    -------------------------------------------------------------------------
    signal nbr_index : integer range 0 to 8 := 0;

begin

    -------------------------------------------------------------------------
    -- 1) Sequential process: state & internal register updates
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= S_RESET_INIT;
                addr_counter <= (others => '0');
                center_row   <= (others => '0');
                center_col   <= (others => '0');
                nbr_index    <= 0;
            else
                state <= next_state;

                case state is
                    when S_CLEAR_RAM =>
                        -- Count through all addresses 0..1023 during clear
                        if addr_counter < to_unsigned(1023, 10) then
                            addr_counter <= addr_counter + 1;
                        end if;

                    when S_FILL_INIT =>
                        -- Start fill from address 0
                        addr_counter <= (others => '0');

                    when S_FILL_WRITE =>
                        -- Count through all addresses for random fill
                        if addr_counter < to_unsigned(1023, 10) then
                            addr_counter <= addr_counter + 1;
                        end if;

                    when S_READ_INIT =>
                        -- Latch the center row/col at the moment of Read
                        center_row <= unsigned(center_row_in);
                        center_col <= unsigned(center_col_in);
                        nbr_index  <= 0;

                    when S_READ_NEIGHBOR =>
                        -- Move to next neighbor each clock until reaching 8
                        if nbr_index < 8 then
                            nbr_index <= nbr_index + 1;
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 2) Combinational process: next-state logic & control outputs
    -------------------------------------------------------------------------
    process(state, addr_counter,
            btn_start_pulse, btn_read_pulse, btn_sort_pulse,
            sort_done, center_row, center_col, nbr_index, ram_dout)
        -- local variables for address & neighbor calculations
        variable addr_int         : unsigned(9 downto 0);
        variable center_addr      : unsigned(9 downto 0);
        variable row_int, col_int : integer;
        variable center_row_int   : integer;
        variable center_col_int   : integer;
        variable in_range         : boolean;
    begin
        ---------------------------------------------------------------------
        -- Default outputs (safe defaults)
        ---------------------------------------------------------------------
        next_state    <= state;

        ram_we        <= '0';
        write_sel     <= "00";     -- default: zeros (if ram_we='0', no effect)
        rng_enable    <= '0';

        reg_data_in   <= (others => '0');
        reg_load_en   <= '0';
        reg_load_sel  <= (others => '0');

        sort_start    <= '0';
        display_state <= "00";     -- default: unsorted view

        -- Default local vars
        addr_int       := (others => '0');
        row_int        := 0;
        col_int        := 0;
        in_range       := false;

        -- integer versions for neighbor math
        center_row_int := to_integer(center_row);
        center_col_int := to_integer(center_col);

        -- center address from latched row/col: (row * 32) + col
        center_addr := to_unsigned(center_row_int * 32 + center_col_int, 10);

        ---------------------------------------------------------------------
        -- State behavior
        ---------------------------------------------------------------------
        case state is

            -----------------------------------------------------------------
            when S_RESET_INIT =>
                -- After reset, clear RAM once.
                addr_int      := (others => '0');
                display_state <= "00";
                next_state    <= S_CLEAR_RAM;

            -----------------------------------------------------------------
            when S_CLEAR_RAM =>
                -- Write zeros to every RAM address 0..1023
                ram_we    <= '1';
                write_sel <= "00";          -- zeros as RAM.din (via top-level mux)
                addr_int  := addr_counter;

                display_state <= "00";      -- safe "idle" view (unsorted)

                if addr_counter = to_unsigned(1023, 10) then
                    next_state <= S_IDLE;
                else
                    next_state <= S_CLEAR_RAM;
                end if;

            -----------------------------------------------------------------
            when S_IDLE =>
                -- RAM cleared; wait for Start(fill) or Read(load 3x3).
                display_state <= "00";      -- unsorted view
                addr_int      := center_addr;  -- default center location

                if btn_start_pulse = '1' then
                    next_state <= S_FILL_INIT;
                elsif btn_read_pulse = '1' then
                    next_state <= S_READ_INIT;
                else
                    next_state <= S_IDLE;
                end if;

            -----------------------------------------------------------------
            when S_FILL_INIT =>
                -- Prepare for random fill (addr_counter reset in seq block)
                rng_enable    <= '0';
                ram_we        <= '0';
                write_sel     <= "01";      -- RNG source (next state)
                addr_int      := (others => '0');
                display_state <= "00";      -- still unsorted
                next_state    <= S_FILL_WRITE;

            -----------------------------------------------------------------
            when S_FILL_WRITE =>
                -- Fill RAM with RNG values at all addresses 0..1023
                rng_enable    <= '1';       -- run the LFSR
                ram_we        <= '1';
                write_sel     <= "01";      -- RNG -> RAM.din
                addr_int      := addr_counter;
                display_state <= "00";

                if addr_counter = to_unsigned(1023, 10) then
                    next_state <= S_WAIT_READ;
                else
                    next_state <= S_FILL_WRITE;
                end if;

            -----------------------------------------------------------------
            when S_WAIT_READ =>
                -- RAM filled with random data; wait for Read to load 3x3.
                display_state <= "00";      -- unsorted
                addr_int      := center_addr;

                if btn_read_pulse = '1' then
                    next_state <= S_READ_INIT;
                elsif btn_start_pulse = '1' then
                    -- allow user to re-fill with new RNG values
                    next_state <= S_FILL_INIT;
                else
                    next_state <= S_WAIT_READ;
                end if;

            -----------------------------------------------------------------
            when S_READ_INIT =>
                -- Center row/col will be latched in sequential block.
                -- Next state will begin reading neighbors.
                display_state <= "00";
                addr_int      := center_addr;
                next_state    <= S_READ_NEIGHBOR;

            -----------------------------------------------------------------
            when S_READ_NEIGHBOR =>
                -- For each nbr_index = 0..8:
                --   compute neighbor coords,
                --   apply zero-padding if out-of-range,
                --   load one Reg_Bank register.
                display_state <= "00";       -- unsorted view while loading

                -- neighbor coordinate offsets based on nbr_index:
                -- 0: (-1,-1), 1: (-1,0), 2: (-1,1)
                -- 3: ( 0,-1), 4: ( 0,0), 5: ( 0,1)
                -- 6: ( 1,-1), 7: ( 1,0), 8: ( 1,1)
                case nbr_index is
                    when 0 =>
                        row_int := center_row_int - 1;
                        col_int := center_col_int - 1;
                    when 1 =>
                        row_int := center_row_int - 1;
                        col_int := center_col_int;
                    when 2 =>
                        row_int := center_row_int - 1;
                        col_int := center_col_int + 1;
                    when 3 =>
                        row_int := center_row_int;
                        col_int := center_col_int - 1;
                    when 4 =>
                        row_int := center_row_int;
                        col_int := center_col_int;
                    when 5 =>
                        row_int := center_row_int;
                        col_int := center_col_int + 1;
                    when 6 =>
                        row_int := center_row_int + 1;
                        col_int := center_col_int - 1;
                    when 7 =>
                        row_int := center_row_int + 1;
                        col_int := center_col_int;
                    when 8 =>
                        row_int := center_row_int + 1;
                        col_int := center_col_int + 1;
                    when others =>
                        row_int := center_row_int;
                        col_int := center_col_int;
                end case;

                -- Check for out-of-bounds (zero-padding)
                if (row_int < 0) or (row_int > 31) or
                   (col_int < 0) or (col_int > 31) then
                    in_range := false;
                else
                    in_range := true;
                end if;

                -- Select which Reg_Bank register (0..8)
                reg_load_sel <= std_logic_vector(to_unsigned(nbr_index, 4));
                reg_load_en  <= '1';

                if in_range then
                    -- Compute linear address = (row * 32) + col
                    addr_int    := to_unsigned(row_int * 32 + col_int, 10);
                    reg_data_in <= ram_dout;    -- value from RAM
                else
                    -- Out-of-range neighbor: zero-padding
                    addr_int    := center_addr; -- don't-care address
                    reg_data_in <= (others => '0');
                end if;

                -- After neighbor 8, move on to Sort-button wait
                if nbr_index = 8 then
                    next_state <= S_WAIT_SORT_BUTTON;
                else
                    next_state <= S_READ_NEIGHBOR;
                end if;

            -----------------------------------------------------------------
            when S_WAIT_SORT_BUTTON =>
                -- All 9 Reg_Bank registers are loaded.
                -- Wait for Sort button to begin Bubble_Sort.
                display_state <= "00";       -- still showing unsorted
                addr_int      := center_addr;

                if btn_sort_pulse = '1' then
                    sort_start <= '1';       -- 1-clock start pulse
                    next_state <= S_SORT_WAIT;
                else
                    next_state <= S_WAIT_SORT_BUTTON;
                end if;

            -----------------------------------------------------------------
            when S_SORT_WAIT =>
                -- Bubble_Sort is running. When sort_done='1',
                -- sorted outputs are valid and y4 is the median.
                display_state <= "01";       -- show sorted 3x3
                addr_int      := center_addr;

                if sort_done = '1' then
                    next_state <= S_WRITE_MEDIAN;
                else
                    next_state <= S_SORT_WAIT;
                end if;

            -----------------------------------------------------------------
            when S_WRITE_MEDIAN =>
                -- Write the median back into RAM at the center address.
                display_state <= "10";       -- filtered center mode
                ram_we        <= '1';
                write_sel     <= "10";       -- median source -> RAM.din
                addr_int      := center_addr;

                -- After writing the median, go to SHOW_FILTERED
                next_state    <= S_SHOW_FILTERED;

            -----------------------------------------------------------------
            when S_SHOW_FILTERED =>
                -- Final filtered center value is shown on 7-seg (display_state="10").
                -- Wait here until user chooses to Read another neighborhood
                -- or Start a new random fill.
                display_state <= "10";       -- 7-seg shows median_value
                addr_int      := center_addr;
                ram_we        <= '0';
                write_sel     <= "00";

                if btn_read_pulse = '1' then
                    next_state <= S_READ_INIT;
                elsif btn_start_pulse = '1' then
                    next_state <= S_FILL_INIT;
                else
                    next_state <= S_SHOW_FILTERED;
                end if;

        end case;

        ---------------------------------------------------------------------
        -- Drive RAM address output
        ---------------------------------------------------------------------
        ram_addr <= std_logic_vector(addr_int);

        ---------------------------------------------------------------------
        -- Debug state encoding
        ---------------------------------------------------------------------
        case state is
            when S_RESET_INIT        => state_debug <= "0000";
            when S_CLEAR_RAM         => state_debug <= "0001";
            when S_IDLE              => state_debug <= "0010";
            when S_FILL_INIT         => state_debug <= "0011";
            when S_FILL_WRITE        => state_debug <= "0100";
            when S_WAIT_READ         => state_debug <= "0101";
            when S_READ_INIT         => state_debug <= "0110";
            when S_READ_NEIGHBOR     => state_debug <= "0111";
            when S_WAIT_SORT_BUTTON  => state_debug <= "1000";
            when S_SORT_WAIT         => state_debug <= "1001";
            when S_WRITE_MEDIAN      => state_debug <= "1010";
            when S_SHOW_FILTERED     => state_debug <= "1011";
        end case;

    end process;

end Behavioral;
