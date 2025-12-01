library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Radar_Filter is
    port (
        CLK100MHZ : in  std_logic;

        -- Single reset switch
        resetSW   : in  std_logic;  -- synchronous reset

        -- Individual pushbuttons
        startBTN  : in  std_logic;  -- Start: RNG fill RAM
        readBTN   : in  std_logic;  -- Read: load 3x3 neighborhood
        sortBTN   : in  std_logic;  -- Sort: run Bubble_Sort & write median

        -- 7-seg outputs
        SEG       : out std_logic_vector(6 downto 0);  -- a..g (active-LOW)
        AN        : out std_logic_vector(3 downto 0);  -- an3..an0 (on-board)
        CAT       : out std_logic                      -- Pmod 7-seg common line
    );
end Radar_Filter;

architecture Behavioral of Radar_Filter is

    -------------------------------------------------------------------------
    -- Global reset (synchronous, active-high)
    -------------------------------------------------------------------------
    signal reset_sync : std_logic;

    -------------------------------------------------------------------------
    -- Timer outputs
    -------------------------------------------------------------------------
    signal Timer_Debounce : std_logic;  -- debounce tick
    signal Timer_7segment : std_logic;  -- digit multiplex tick
    signal Timer_ReadSort : std_logic;  -- slow tick for read/sort visualization

    -------------------------------------------------------------------------
    -- Debounced button pulses (we only use pulses, not levels)
    -------------------------------------------------------------------------
    signal btn_start_pulse : std_logic;
    signal btn_read_pulse  : std_logic;
    signal btn_sort_pulse  : std_logic;

    -------------------------------------------------------------------------
    -- Center coordinates for 3x3 neighborhood (fixed at 16,16 for now)
    -------------------------------------------------------------------------
    signal center_row_in : std_logic_vector(4 downto 0);
    signal center_col_in : std_logic_vector(4 downto 0);

    -------------------------------------------------------------------------
    -- RNG interface
    -------------------------------------------------------------------------
    signal rng_enable : std_logic;
    signal rng_value6 : std_logic_vector(5 downto 0);  -- random 6-bit data

    -------------------------------------------------------------------------
    -- RAM interface (1024 x 6-bit)
    -------------------------------------------------------------------------
    signal ram_addr  : std_logic_vector(9 downto 0);
    signal ram_we    : std_logic;
    signal ram_din   : std_logic_vector(5 downto 0);
    signal ram_dout  : std_logic_vector(5 downto 0);
    signal write_sel : std_logic_vector(1 downto 0);   -- "00" zeros, "01" RNG, "10" median

    -------------------------------------------------------------------------
    -- Reg_Bank signals
    -------------------------------------------------------------------------
    signal reg_data_in  : std_logic_vector(5 downto 0);
    signal reg_load_sel : std_logic_vector(3 downto 0);
    signal reg_load_en  : std_logic;
    -- 3x3 unsorted neighborhood
    signal r0, r1, r2,
           r3, r4, r5,
           r6, r7, r8  : std_logic_vector(5 downto 0);

    -------------------------------------------------------------------------
    -- Bubble_Sort signals
    -------------------------------------------------------------------------
    signal s0, s1, s2,
           s3, s4, s5,
           s6, s7, s8  : std_logic_vector(5 downto 0);

    signal sort_start : std_logic;
    signal sort_done  : std_logic;

    -- Median value (center after sort) is s4
    signal median_value : std_logic_vector(5 downto 0);

    -------------------------------------------------------------------------
    -- Display state for FSM_7segment
    -------------------------------------------------------------------------
    signal display_state : std_logic_vector(1 downto 0);

    -------------------------------------------------------------------------
    -- Debug state from RadarFilter_FSM (optional)
    -------------------------------------------------------------------------
    signal state_debug : std_logic_vector(3 downto 0);

begin

    -------------------------------------------------------------------------
    -- Reset mapping
    -------------------------------------------------------------------------
    reset_sync <= resetSW;  -- use resetSW as global synchronous reset

    -------------------------------------------------------------------------
    -- Fixed center coordinate for now: (16,16)
    -------------------------------------------------------------------------
    center_row_in <= "10000";  -- 16
    center_col_in <= "10000";  -- 16

    -------------------------------------------------------------------------
    -- Timer: generates Timer_Debounce, Timer_7segment, Timer_ReadSort
    -------------------------------------------------------------------------
    u_timer : entity work.Timer
        port map (
            clk            => CLK100MHZ,
            reset          => reset_sync,
            Timer_Debounce => Timer_Debounce,
            Timer_7segment => Timer_7segment,  -- digit multiplex tick
            Timer_ReadSort => Timer_ReadSort   -- slow visualization tick
        );

    -------------------------------------------------------------------------
    -- Debounce for Start button (we only use btn_pulse)
    -------------------------------------------------------------------------
    u_db_start : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => startBTN,
            tick_sample => Timer_Debounce,
            btn_level   => open,             -- unused
            btn_pulse   => btn_start_pulse
        );

    -------------------------------------------------------------------------
    -- Debounce for Read button
    -------------------------------------------------------------------------
    u_db_read : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => readBTN,
            tick_sample => Timer_Debounce,
            btn_level   => open,             -- unused
            btn_pulse   => btn_read_pulse
        );

    -------------------------------------------------------------------------
    -- Debounce for Sort button
    -------------------------------------------------------------------------
    u_db_sort : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => sortBTN,
            tick_sample => Timer_Debounce,
            btn_level   => open,             -- unused
            btn_pulse   => btn_sort_pulse
        );

    -------------------------------------------------------------------------
    -- RNG: LFSR-based random number generator (6-bit output)
    -------------------------------------------------------------------------
    u_rng : entity work.LFSR_RNG_6bit
        port map (
            clk        => CLK100MHZ,
            reset      => reset_sync,
            enable     => rng_enable,
            random_out => rng_value6
        );

    -------------------------------------------------------------------------
    -- RAM write-data multiplexer
    -------------------------------------------------------------------------
    with write_sel select
        ram_din <=
            (others => '0')   when "00",  -- clear
            rng_value6        when "01",  -- RNG
            median_value      when "10",  -- median write-back
            (others => '0')   when others;

    -------------------------------------------------------------------------
    -- RAM: 1D memory
    -------------------------------------------------------------------------
    u_ram : entity work.RAM_1D
        port map (
            clk  => CLK100MHZ,
            we   => ram_we,
            addr => ram_addr,
            din  => ram_din,
            dout => ram_dout
        );

    -------------------------------------------------------------------------
    -- 3x3 Register Bank
    -------------------------------------------------------------------------
    u_regbank : entity work.Reg_Bank
        port map (
            clk      => CLK100MHZ,
            reset    => reset_sync,
            data_in  => reg_data_in,
            load_sel => reg_load_sel,
            load_en  => reg_load_en,
            r0       => r0,
            r1       => r1,
            r2       => r2,
            r3       => r3,
            r4       => r4,
            r5       => r5,
            r6       => r6,
            r7       => r7,
            r8       => r8
        );

    -------------------------------------------------------------------------
    -- Bubble Sort Unit (Bubble_Sort)
    -------------------------------------------------------------------------
    u_sort : entity work.Bubble_Sort
        port map (
            clk   => CLK100MHZ,
            reset => reset_sync,
            start => sort_start,

            x0 => r0, 
            x1 => r1, 
            x2 => r2,
            x3 => r3, 
            x4 => r4, 
            x5 => r5,
            x6 => r6, 
            x7 => r7, 
            x8 => r8,

            y0 => s0, 
            y1 => s1, 
            y2 => s2,
            y3 => s3, 
            y4 => s4, 
            y5 => s5,
            y6 => s6, 
            y7 => s7, 
            y8 => s8,

            done => sort_done
        );

    -- Median value is the center of sorted outputs
    median_value <= s4;

    -------------------------------------------------------------------------
    -- Main Control FSM (RadarFilter_FSM)
    -------------------------------------------------------------------------
    u_ctrl : entity work.RadarFilter_FSM
        port map (
            clk             => CLK100MHZ,
            reset           => reset_sync,

            btn_start_pulse => btn_start_pulse,
            btn_read_pulse  => btn_read_pulse,
            btn_sort_pulse  => btn_sort_pulse,

            center_row_in   => center_row_in,
            center_col_in   => center_col_in,

            ram_dout        => ram_dout,

            ram_addr        => ram_addr,
            ram_we          => ram_we,
            write_sel       => write_sel,

            rng_enable      => rng_enable,

            reg_data_in     => reg_data_in,
            reg_load_sel    => reg_load_sel,
            reg_load_en     => reg_load_en,

            sort_start      => sort_start,
            sort_done       => sort_done,

            display_state   => display_state,
            state_debug     => state_debug
        );

    -------------------------------------------------------------------------
    -- 7-Segment Display FSM
    -------------------------------------------------------------------------
    u_disp : entity work.FSM_7segment
        port map (
            clk          => CLK100MHZ,
            reset        => reset_sync,
            tick_mux     => Timer_7segment,  -- from Timer module
            tick_index   => Timer_ReadSort,  -- from Timer module

            display_state => display_state,

            r0 => r0, 
            r1 => r1, 
            r2 => r2,
            r3 => r3, 
            r4 => r4, 
            r5 => r5,
            r6 => r6, 
            r7 => r7, 
            r8 => r8,

            s0 => s0, 
            s1 => s1, 
            s2 => s2,
            s3 => s3, 
            s4 => s4, 
            s5 => s5,
            s6 => s6, 
            s7 => s7, 
            s8 => s8,

            median_value => median_value,

            SEG => SEG,
            AN  => AN
        );

    -------------------------------------------------------------------------
    -- Pmod 7-seg CAT control
    -------------------------------------------------------------------------
    CAT <= '1';

end Behavioral;
