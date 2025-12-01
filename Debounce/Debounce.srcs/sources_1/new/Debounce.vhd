-- Debounce Module
--   Clean up a mechanical pushbutton input so that the rest of the design
--   sees a single, stable transition instead of multiple bounces.
-- Typical usage in this project:
--   - btn_start (raw) -> Debounce -> btn_start_level, btn_start_pulse
--   - btn_read  (raw) -> Debounce -> btn_read_level,  btn_read_pulse
--   - btn_sort  (raw) -> Debounce -> btn_sort_level,  btn_sort_pulse
-- Inputs:
--   - clk         : 100 MHz system clock
--   - reset       : synchronous, active-high reset (from reset switch)
--   - noisy_in    : raw pushbutton (btn_start / btn_read / btn_sort)
--   - tick_sample : slow tick from Timer (Timer_Debounce, ~2 ms)
-- Outputs:
--   - btn_level   : debounced level (0 = released, 1 = pressed)
--   - btn_pulse   : 1-clock pulse when btn_level makes a clean 0 -> 1 transition

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Debounce is
    port (
        clk         : in  std_logic;  -- 100 MHz system clock
        reset       : in  std_logic;  -- synchronous, active-high
        noisy_in    : in  std_logic;  -- raw pushbutton
        tick_sample : in  std_logic;  -- Timer_Debounce
        btn_level   : out std_logic;  -- debounced level
        btn_pulse   : out std_logic   -- 1-clock pulse on rising edge
    );
end Debounce;

architecture Behavioral of Debounce is

    -- 2-FF synchronizer for asynchronous button input
    signal sync_0, sync_1 : std_logic := '0';

    -- Debounced states
    signal stable_state : std_logic := '0';
    signal prev_state   : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Synchronous reset of internal registers
                sync_0       <= '0';
                sync_1       <= '0';
                stable_state <= '0';
                prev_state   <= '0';

            else
                -- 1) Synchronize raw button to clock domain
                sync_0 <= noisy_in;
                sync_1 <= sync_0;

                -- 2) Only update debounced state on the slow sample tick
                if tick_sample = '1' then
                    -- Remember previous state for pulse generation
                    prev_state   <= stable_state;
                    -- Take a fresh sample of the synchronized input
                    stable_state <= sync_1;
                end if;

            end if;
        end if;
    end process;

    -- Outputs
    btn_level <= stable_state;

    -- Pulse when stable_state goes 0 -> 1 AND we are on a sample tick
    btn_pulse <= '1'
                 when (tick_sample = '1' and stable_state = '1' and prev_state = '0')
                 else '0';

end Behavioral;
