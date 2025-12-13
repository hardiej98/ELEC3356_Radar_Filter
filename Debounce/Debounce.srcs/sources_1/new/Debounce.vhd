library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Debounce is
    port (
        clk         : in  std_logic;  -- 100 MHz system clock
        reset       : in  std_logic;  -- synchronous, active-high
        noisy_in    : in  std_logic;  -- raw pushbutton
        tick_sample : in  std_logic;  -- Timer_Debounce (~2 ms pulse)
        btn_level   : out std_logic;  -- debounced level
        btn_pulse   : out std_logic   -- 1-clock pulse on clean 0->1
    );
end Debounce;

architecture Behavioral of Debounce is

    -- 2-FF synchronizer for asynchronous input
    signal sync_0, sync_1 : std_logic := '0';

    -- Debounced state
    signal debounced  : std_logic := '0';

    -- Registered pulse output
    signal pulse  : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Synchronous reset
                sync_0    <= '0';
                sync_1    <= '0';
                debounced <= '0';
                pulse <= '0';

            else
                -- Default: no pulse this clock
                pulse <= '0';

                -- 1) Synchronize raw button to clock domain
                sync_0 <= noisy_in;
                sync_1 <= sync_0;

                -- 2) On each slow sample tick, update debounced state
                if tick_sample = '1' then
                    -- If the synchronized input changed since last sample,
                    -- update debounced level and generate a rising-edge pulse.
                    if sync_1 /= debounced then
                        debounced <= sync_1;

                        -- Rising edge: old debounced=0, new sync_1=1
                        if sync_1 = '1' then
                            pulse <= '1';
                        end if;
                    end if;
                end if;

            end if;
        end if;
    end process;

    -- Outputs
    btn_level <= debounced;
    btn_pulse <= pulse;

end Behavioral;
