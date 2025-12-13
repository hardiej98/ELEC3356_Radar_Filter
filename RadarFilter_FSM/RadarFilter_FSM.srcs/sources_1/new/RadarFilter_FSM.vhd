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
    -- FSM states (streamlined)
    -------------------------------------------------------------------------
    type state_type is (
        S_CLEAR_RAM,       -- write zeros to all 1024 RAM locations
        S_IDLE,            -- wait for Start / Read
        S_FILL,            -- RNG fill RAM
        S_READ,            -- load 3x3 neighborhood into Reg_Bank
        S_WAIT_SORT,       -- wait for Sort button
        S_SORT,            -- Bubble_Sort running, wait for sort_done
        S_WRITE_MEDIAN,    -- write median back to RAM
        S_SHOW_FILTERED    -- show final filtered center until next command
    );

    signal state, next_state : state_type := S_CLEAR_RAM;

    -------------------------------------------------------------------------
    -- 10-bit address counter for CLEAR_RAM and FILL (0..1023)
    -------------------------------------------------------------------------
    signal addr_counter : unsigned(9 downto 0) := (others => '0');

    -------------------------------------------------------------------------
    -- Neighbor index: 0..8 -> 3x3 window positions
    -------------------------------------------------------------------------
    signal nbr_index : integer range 0 to 8 := 0;

begin

    -------------------------------------------------------------------------
    -- 1) Sequential process: state & internal counters
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= S_CLEAR_RAM;
                addr_counter <= (others => '0');
                nbr_index    <= 0;
            else
                -- update state
                state <= next_state;

                -----------------------------------------------------------------
                -- address counter for CLEAR_RAM and FILL
                -----------------------------------------------------------------
                case state is
                    when S_CLEAR_RAM =>
                        if addr_counter < to_unsigned(1023, 10) then
                            addr_counter <= addr_counter + 1;
                        end if;

                    when S_FILL =>
                        if addr_counter < to_unsigned(1023, 10) then
                            addr_counter <= addr_counter + 1;
                        end if;

                    when others =>
                        null;
                end case;

                -----------------------------------------------------------------
                -- neighbor index 0..8 while in S_READ
                -----------------------------------------------------------------
                if state = S_READ then
                    if nbr_index < 8 then
                        nbr_index <= nbr_index + 1;
                    end if;
                end if;

                -----------------------------------------------------------------
                -- On entry to S_FILL: restart addr_counter at 0
                -----------------------------------------------------------------
                if (state /= S_FILL) and (next_state = S_FILL) then
                    addr_counter <= (others => '0');
                end if;

                -----------------------------------------------------------------
                -- On entry to S_READ: restart neighbor index at 0
                -----------------------------------------------------------------
                if (state /= S_READ) and (next_state = S_READ) then
                    nbr_index <= 0;
                end if;

            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 2) Combinational process: next-state logic & control outputs
    -------------------------------------------------------------------------
    process(state, addr_counter,
            btn_start_pulse, btn_read_pulse, btn_sort_pulse,
            sort_done, nbr_index,
            center_row_in, center_col_in,
            ram_dout)
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
        center_row_int := to_integer(unsigned(center_row_in));
        center_col_int := to_integer(unsigned(center_col_in));

        -- center address from row/col: (row * 32) + col
        center_addr := to_unsigned(center_row_int * 32 + center_col_int, 10);

        ---------------------------------------------------------------------
        -- State behavior
        ---------------------------------------------------------------------
        case state is

            -----------------------------------------------------------------
            when S_CLEAR_RAM =>
                -- Write zeros to every RAM address 0..1023 after reset
                ram_we        <= '1';
                write_sel     <= "00";          -- zeros as RAM.din
                addr_int      := addr_counter;
                display_state <= "00";

                if addr_counter = to_unsigned(1023, 10) then
                    next_state <= S_IDLE;
                else
                    next_state <= S_CLEAR_RAM;
                end if;

            -----------------------------------------------------------------
            when S_IDLE =>
                -- RAM cleared/filled; wait for Start(fill) or Read(load 3x3).
                display_state <= "00";      -- unsorted view
                addr_int      := center_addr;

                if btn_start_pulse = '1' then
                    next_state <= S_FILL;
                elsif btn_read_pulse = '1' then
                    next_state <= S_READ;
                else
                    next_state <= S_IDLE;
                end if;

            -----------------------------------------------------------------
            when S_FILL =>
                -- Fill RAM with RNG values at all addresses 0..1023
                rng_enable    <= '1';       -- run the LFSR
                ram_we        <= '1';
                write_sel     <= "01";      -- RNG -> RAM.din
                addr_int      := addr_counter;
                display_state <= "00";

                if addr_counter = to_unsigned(1023, 10) then
                    next_state <= S_IDLE;
                else
                    next_state <= S_FILL;
                end if;

            -----------------------------------------------------------------
            when S_READ =>
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
                    addr_int    := center_addr; -- don't-care
                    reg_data_in <= (others => '0');
                end if;

                -- After neighbor 8, move on to waiting for Sort
                if nbr_index = 8 then
                    next_state <= S_WAIT_SORT;
                else
                    next_state <= S_READ;
                end if;

            -----------------------------------------------------------------
            when S_WAIT_SORT =>
                -- All 9 Reg_Bank registers are loaded.
                -- Wait for Sort button to begin Bubble_Sort.
                display_state <= "00";       -- still showing unsorted
                addr_int      := center_addr;

                if btn_sort_pulse = '1' then
                    sort_start <= '1';       -- 1-clock start pulse
                    next_state <= S_SORT;
                else
                    next_state <= S_WAIT_SORT;
                end if;

            -----------------------------------------------------------------
            when S_SORT =>
                -- Bubble_Sort is running. When sort_done='1',
                -- sorted outputs are valid and y4 is the median.
                display_state <= "01";       -- show sorted 3x3
                addr_int      := center_addr;

                if sort_done = '1' then
                    next_state <= S_WRITE_MEDIAN;
                else
                    next_state <= S_SORT;
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
                    next_state <= S_READ;
                elsif btn_start_pulse = '1' then
                    next_state <= S_FILL;
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
            when S_CLEAR_RAM      => state_debug <= "0000";
            when S_IDLE           => state_debug <= "0001";
            when S_FILL           => state_debug <= "0010";
            when S_READ           => state_debug <= "0011";
            when S_WAIT_SORT      => state_debug <= "0100";
            when S_SORT           => state_debug <= "0101";
            when S_WRITE_MEDIAN   => state_debug <= "0110";
            when S_SHOW_FILTERED  => state_debug <= "0111";
        end case;

    end process;

end Behavioral;
