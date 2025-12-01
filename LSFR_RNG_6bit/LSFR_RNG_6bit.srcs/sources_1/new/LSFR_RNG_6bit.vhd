-- Random Number Generator (6-bit) using 8-bit LFSR
-- Purpose:
--   Generate pseudorandom 6-bit values for filling the RAM with initial
--   radar intensity samples. Internally uses an 8-bit LFSR with taps:
--   x^8 + x^6 + x^5 + x^4 + 1.
-- Behavior:
--   - On reset = '1', the LFSR loads a non-zero seed "00110110".
--     (Must not be all zeros, or the LFSR would lock up.)
--   - When enable = '1' on a rising clock edge, the LFSR shifts:
--       * New bit = XOR of bits 7, 5, 4, 3
--       * Shift direction: [7] <= feedback, [6] <= old[7], ..., [0] <= old[1]
--   - random_out is taken from the lower 6 bits of the LFSR state.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LFSR_RNG_6bit is
    port (
        clk        : in  std_logic;                       -- 100 MHz system clock
        reset      : in  std_logic;                       -- synchronous, active-high
        enable     : in  std_logic;                       -- step LFSR when '1'
        random_out : out std_logic_vector(5 downto 0)     -- 6-bit pseudorandom output
    );
end LFSR_RNG_6bit;

architecture Behavioral of LFSR_RNG_6bit is

    signal LFSR_reg : std_logic_vector(7 downto 0) := "00110110";  -- non-zero seed
    signal feedback : std_logic;

begin

    feedback <= LFSR_reg(7) xor LFSR_reg(5) xor LFSR_reg(4) xor LFSR_reg(3);

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                LFSR_reg <= "00110110";     -- non-zero seed

            elsif enable = '1' then
                -- Shift from "top side":
                -- new bit into bit 7; bit7->6, 6->5, ..., 1->0
                LFSR_reg <= feedback & LFSR_reg(7 downto 1);
            end if;

        end if;
    end process;

    random_out <= LFSR_reg(5 downto 0);

end Behavioral;
