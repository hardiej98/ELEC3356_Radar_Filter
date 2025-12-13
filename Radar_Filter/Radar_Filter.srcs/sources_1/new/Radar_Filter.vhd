library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Radar_Filter is
    port (
        CLK100MHZ : in  std_logic;                     -- 100 MHz clock
        resetSW   : in  std_logic;                     -- synchronous, active-high reset

        startBTN  : in  std_logic;                     -- Start: fill 3x3 from RNG
        readBTN   : in  std_logic;                     -- Read: show unsorted center
        sortBTN   : in  std_logic;                     -- Sort: run Bubble_Sort, show median

        SEG       : out std_logic_vector(6 downto 0);  -- 7-seg segments a..g, ACTIVE-LOW
        CAT       : out std_logic                      -- digit select for PmodSSD
    );
end Radar_Filter;

architecture Behavioral of Radar_Filter is

    -------------------------------------------------------------------------
    -- Types
    -------------------------------------------------------------------------
    type reg_array_3x3 is array (0 to 8) of std_logic_vector(5 downto 0);

    -------------------------------------------------------------------------
    -- Global reset
    -------------------------------------------------------------------------
    signal reset_sync : std_logic;

    -------------------------------------------------------------------------
    -- Debounce tick (~2 ms) and counter
    -------------------------------------------------------------------------
    signal tick_debounce : std_logic;
    signal db_cnt        : unsigned(17 downto 0) := (others => '0');
    constant DB_MAX      : unsigned(17 downto 0) := to_unsigned(199999, 18);  -- ~2 ms @100 MHz

    -------------------------------------------------------------------------
    -- Debounced button pulses
    -------------------------------------------------------------------------
    signal start_pulse : std_logic;
    signal read_pulse  : std_logic;
    signal sort_pulse  : std_logic;

    -------------------------------------------------------------------------
    -- RNG interface (6-bit LFSR)
    -------------------------------------------------------------------------
    signal rng_enable : std_logic;
    signal rng_value6 : std_logic_vector(5 downto 0);

    -------------------------------------------------------------------------
    -- 3x3 register bank
    -------------------------------------------------------------------------
    signal mem      : reg_array_3x3 := (others => (others => '0'));
    signal mem_we   : std_logic;
    signal mem_addr : unsigned(3 downto 0);  -- 0..8

    -------------------------------------------------------------------------
    -- Bubble sort / median
    -------------------------------------------------------------------------
    signal sort_start : std_logic;
    signal sort_done  : std_logic;

    signal s0, s1, s2,
           s3, s4, s5,
           s6, s7, s8  : std_logic_vector(5 downto 0);

    signal median_value6 : std_logic_vector(5 downto 0);

    -------------------------------------------------------------------------
    -- Display select + value
    -------------------------------------------------------------------------
    signal display_sel    : std_logic;                    -- 0=center, 1=median
    signal display_value6 : std_logic_vector(5 downto 0); -- 0..63

begin

    -------------------------------------------------------------------------
    -- Reset mapping
    -------------------------------------------------------------------------
    reset_sync <= resetSW;

    -------------------------------------------------------------------------
    -- Debounce tick generator (~2 ms)
    -------------------------------------------------------------------------
    process (CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            if reset_sync = '1' then
                db_cnt        <= (others => '0');
                tick_debounce <= '0';
            else
                if db_cnt = DB_MAX then
                    db_cnt        <= (others => '0');
                    tick_debounce <= '1';
                else
                    db_cnt        <= db_cnt + 1;
                    tick_debounce <= '0';
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Debounce: start/read/sort buttons
    -------------------------------------------------------------------------
    u_db_start : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => startBTN,
            tick_sample => tick_debounce,
            btn_level   => open,
            btn_pulse   => start_pulse
        );

    u_db_read : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => readBTN,
            tick_sample => tick_debounce,
            btn_level   => open,
            btn_pulse   => read_pulse
        );

    u_db_sort : entity work.Debounce
        port map (
            clk         => CLK100MHZ,
            reset       => reset_sync,
            noisy_in    => sortBTN,
            tick_sample => tick_debounce,
            btn_level   => open,
            btn_pulse   => sort_pulse
        );

    -------------------------------------------------------------------------
    -- Control FSM: fill 3x3, handle READ/SORT, start Bubble_Sort
    -------------------------------------------------------------------------
    u_ctrl : entity work.MedianFilter_FSM
        port map (
            clk          => CLK100MHZ,
            reset        => reset_sync,

            start_pulse  => start_pulse,
            read_pulse   => read_pulse,
            sort_pulse   => sort_pulse,
            sort_done    => sort_done,

            lfsr_enable  => rng_enable,
            mem_we       => mem_we,
            mem_addr     => mem_addr,
            display_sel  => display_sel,
            sort_start   => sort_start
        );

    -------------------------------------------------------------------------
    -- 6-bit RNG
    -------------------------------------------------------------------------
    u_rng : entity work.LFSR_RNG_6bit
        port map (
            clk        => CLK100MHZ,
            reset      => reset_sync,
            enable     => rng_enable,
            random_out => rng_value6
        );

    -------------------------------------------------------------------------
    -- 3x3 register bank (internal "RAM")
    -------------------------------------------------------------------------
    process (CLK100MHZ)
        variable idx_int : integer;
    begin
        if rising_edge(CLK100MHZ) then
            if reset_sync = '1' then
                mem <= (others => (others => '0'));
            else
                if mem_we = '1' then
                    idx_int := to_integer(mem_addr);
                    if (idx_int >= 0) and (idx_int <= 8) then
                        mem(idx_int) <= rng_value6;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Bubble Sort Unit (3x3 median)
    -------------------------------------------------------------------------
    u_sort : entity work.Bubble_Sort
        port map (
            clk   => CLK100MHZ,
            reset => reset_sync,
            start => sort_start,

            x0 => mem(0),
            x1 => mem(1),
            x2 => mem(2),
            x3 => mem(3),
            x4 => mem(4),
            x5 => mem(5),
            x6 => mem(6),
            x7 => mem(7),
            x8 => mem(8),

            y0 => s0,
            y1 => s1,
            y2 => s2,
            y3 => s3,
            y4 => s4,   -- median
            y5 => s5,
            y6 => s6,
            y7 => s7,
            y8 => s8,

            done => sort_done
        );

    median_value6 <= s4;

    -------------------------------------------------------------------------
    -- Select display value: center vs median (6-bit 0..63)
    -------------------------------------------------------------------------
    display_value6 <= mem(4) when display_sel = '0' else median_value6;

    -------------------------------------------------------------------------
    -- 7-segment Display FSM (BCD inside)
    -------------------------------------------------------------------------
    u_disp : entity work.FSM_7segment
        port map (
            clk      => CLK100MHZ,
            reset    => reset_sync,
            value_in => display_value6,   -- 6-bit value (0..63)
            SEG      => SEG,
            CAT      => CAT
        );

end Behavioral;
