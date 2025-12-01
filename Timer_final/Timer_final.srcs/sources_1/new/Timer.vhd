-- Timer Module: T=1/f , fin = 100MHz, T = 1/100MHz = 10ns
--   Every clock edge is 10ns with base internal S7-50 CLK100MHZ
--   Generates two timing pulses from the 100 MHz system clock
--   timing derived from 100 MHz input clock using unsigned counters (numeric_std) as clock dividers.
--   reset input synchronously clears all counters and tick outputs, resetting Timer 

-- 1) Timer_Debounce: slow tick 2 ms used to sample pushbuttons in Debounce module.
--    base counter divides the 100 MHz clock down to a 10 kHz tick.
--    Tick_100us occurs every 100 µs and is used as the base period for other timing.

-- 2) Timer_7segment: faster tick 100 µs used to MUX the 7 segment display.
--    debounce counter increments on each 100 µs base tick.
--    After 20 base ticks (20 × 100 µs = 2 ms), this generates single-clock pulse on Timer_Debounce. 
--    Basically gives the Debounce circuit a clean interval for the button push.
--    Timer_7segment is the 100 µs base tick, should cycle through digits to appear lit continuously

-- 3) Timer_ReadSort: super slow tick 0.5s to visualize read/sort
--    increments on each 100 µs base tick. After 5000 base ticks (5000 × 100 µs = 0.5 s),
--    creates a single-clock pulse on Timer_ReadSort, which the FSM uses to get the single read/sort output.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Timer is
    port (
        clk            : in  std_logic;   -- 100 MHz system clock
        reset          : in  std_logic;   -- synchronous, active-high
        Timer_Debounce : out std_logic;   -- ~2 ms tick for Debounce
        Timer_7segment : out std_logic;   -- ~100 µs tick for 7-seg
        Timer_ReadSort : out std_logic    -- ~0.5 s tick for read/sort visualization
    );
end Timer;

architecture Behavioral of Timer is

    -- Clock Interval #1: Base clock divider 100 MHz -> 10 kHz (100 µs period)
    -- 100 MHz / 10,000 = 10 kHz, so count 0..9,999
    signal BaseCounter : unsigned(13 downto 0) := (others => '0');  -- up to 16383
    signal Tick_100us  : std_logic := '0';      -- internal base tick (100 µs)

    -- Clock Interval #2: Debounce tick ~2 ms from 100 µs base
    -- 2 ms / 100 µs = 20 base ticks ? count 0..19
    signal DebounceCounter : unsigned(4 downto 0) := (others => '0'); -- up to 31
    signal Tick_Debounce_i : std_logic := '0';

    -- Clock Interval #3: Read/Sort visualization tick ~0.5 s from 100 µs base
    -- 0.5 s / 100 µs = 5000 base ticks ? count 0..4999
    signal ReadSortCounter : unsigned(12 downto 0) := (others => '0'); -- up to 8191
    signal Tick_ReadSort_i : std_logic := '0';

    -- 7-seg tick: forward the 100 µs base tick
    signal Tick_7segment_i : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Synchronous reset of all counters and tick signals
                BaseCounter      <= (others => '0');
                Tick_100us       <= '0';

                DebounceCounter  <= (others => '0');
                Tick_Debounce_i  <= '0';

                ReadSortCounter  <= (others => '0');
                Tick_ReadSort_i  <= '0';

                Tick_7segment_i  <= '0';

            else
                -- Clock Interval #1: 100 MHz -> 10 kHz (100 µs base tick)
                if BaseCounter = to_unsigned(9999, BaseCounter'length) then
                    BaseCounter <= (others => '0');
                    Tick_100us  <= '1';   -- one-clock-wide pulse
                else
                    BaseCounter <= BaseCounter + 1;
                    Tick_100us  <= '0';
                end if;

                -- Clock Interval #2: Debounce tick (2 ms) from 100 µs base
                -- Only count on Tick_100us
                if Tick_100us = '1' then
                    if DebounceCounter = to_unsigned(19, DebounceCounter'length) then
                        DebounceCounter <= (others => '0');  -- 20 * 100 µs = 2 ms
                        Tick_Debounce_i <= '1';
                    else
                        DebounceCounter <= DebounceCounter + 1;
                        Tick_Debounce_i <= '0';
                    end if;
                else
                    Tick_Debounce_i <= '0';  -- no new debounce tick when base tick is 0
                end if;

                -- Clock Interval #3:: Read/Sort tick (0.5 s) from 100 µs base
                -- Only count on Tick_100us
                if Tick_100us = '1' then
                    if ReadSortCounter = to_unsigned(4999, ReadSortCounter'length) then
                        ReadSortCounter <= (others => '0');   -- 5000 * 100 µs = 0.5 s
                        Tick_ReadSort_i <= '1';
                    else
                        ReadSortCounter <= ReadSortCounter + 1;
                        Tick_ReadSort_i <= '0';
                    end if;
                else
                    Tick_ReadSort_i <= '0';
                end if;

                -- Display tick: just forward the 100 µs base tick
                Tick_7segment_i <= Tick_100us;

            end if;
        end if;
    end process;

--  outputs
    Timer_Debounce <= Tick_Debounce_i;
    Timer_7segment <= Tick_7segment_i;
    Timer_ReadSort <= Tick_ReadSort_i;

end Behavioral;