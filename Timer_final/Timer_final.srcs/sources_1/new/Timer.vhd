library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Timer is
    port (
        clk            : in  std_logic;   -- 100 MHz system clock
        reset          : in  std_logic;   -- synchronous, active-high
        Timer_Debounce : out std_logic;   -- ~2 ms tick for Debounce
        Timer_7segment : out std_logic;   -- ~100 탎 tick for 7-seg
        Timer_ReadSort : out std_logic    -- ~0.5 s tick for read/sort visualization
    );
end Timer;

architecture Behavioral of Timer is

    -- 100 MHz -> 10 kHz (100 탎 period): count 0..9999
    signal BaseCounter     : unsigned(13 downto 0) := (others => '0');

    -- Debounce tick: 2 ms from 100 탎 base (20 * 100 탎) ? count 0..19
    signal DebounceCounter : unsigned(4 downto 0)  := (others => '0');

    -- Read/Sort tick: 0.5 s from 100 탎 base (5000 * 100 탎) ? count 0..4999
    signal ReadSortCounter : unsigned(12 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Clear counters
                BaseCounter      <= (others => '0');
                DebounceCounter  <= (others => '0');
                ReadSortCounter  <= (others => '0');

                -- Clear outputs
                Timer_7segment   <= '0';
                Timer_Debounce   <= '0';
                Timer_ReadSort   <= '0';

            else
                -- Default: no ticks this cycle
                Timer_7segment <= '0';
                Timer_Debounce <= '0';
                Timer_ReadSort <= '0';

                ------------------------------------------------------------------
                -- Base divider: 100 MHz -> 10 kHz (100 탎 tick)
                ------------------------------------------------------------------
                if BaseCounter = to_unsigned(9999, BaseCounter'length) then
                    BaseCounter   <= (others => '0');
                    Timer_7segment <= '1';          -- 100 탎 tick (1 clock wide)

                    ----------------------------------------------------------------
                    -- Debounce tick: every 20 base ticks = 2 ms
                    ----------------------------------------------------------------
                    if DebounceCounter = to_unsigned(19, DebounceCounter'length) then
                        DebounceCounter <= (others => '0');
                        Timer_Debounce  <= '1';     -- 2 ms tick
                    else
                        DebounceCounter <= DebounceCounter + 1;
                    end if;

                    ----------------------------------------------------------------
                    -- Read/Sort tick: every 5000 base ticks = 0.5 s
                    ----------------------------------------------------------------
                    if ReadSortCounter = to_unsigned(4999, ReadSortCounter'length) then
                        ReadSortCounter <= (others => '0');
                        Timer_ReadSort  <= '1';     -- 0.5 s tick
                    else
                        ReadSortCounter <= ReadSortCounter + 1;
                    end if;

                else
                    -- Still counting toward the next 100 탎 tick
                    BaseCounter <= BaseCounter + 1;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
