-- BCD_decoder:
-- takes a 6-bit binary value (0-63) and splits it into two
-- decimal digits so it can be shown on the 7-segment display.
--   - bin_in: the 6-bit input value in binary.
--   - tens_digit: decimal "tens" place (0-6), encoded in 4-bit BCD.
--   - ones_digit: decimal "ones" place (0-9), encoded in 4-bit BCD.
-- Internally, the 6-bit input is converted to an integer, then:
--   tens_digit <= FLOOR(value / 10)
--   ones_digit <= value MOD 10
-- These two BCD nibbles are then sent to the 7-segment decoder to light
-- up the correct decimal number (00-63) on the display.

-- Why we need this BCD_decoder:
-- Radar samples are 6-bit binary values (0-63), but the 7-segment decoder
-- only takes a single decimal digit in 4-bit BCD. This module converts
-- the 6-bit value into two decimal digits (tens and ones) in BCD so the
-- display logic can show 00-63 and satisfy the project's binary-to-BCD
-- requirement.
--
-- Example:
--   bin_in      = "101011"  (binary) = 43 (decimal)
--   tens_digit  = "0100"    (BCD 4)   -> tens place = 4
--   ones_digit  = "0011"    (BCD 3)   -> ones place = 3
--   The 7-seg logic then uses these two digits to display "43".


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BCD_decoder is
    port (
        bin_in     : in  std_logic_vector(5 downto 0);
        tens_digit : out std_logic_vector(3 downto 0);  -- tens place
        ones_digit : out std_logic_vector(3 downto 0)   -- ones place
    );
end BCD_decoder;

architecture Behavioral of BCD_decoder is
begin
    process(bin_in)
        variable value : integer range 0 to 63;
    begin
        -- Convert 6-bit unsigned binary to integer
        value := to_integer(unsigned(bin_in));

        -- tens_digit = floor(value / 10)
        tens_digit <= std_logic_vector(to_unsigned(value / 10, 4));

        -- ones_digit = value mod 10
        ones_digit <= std_logic_vector(to_unsigned(value mod 10, 4));
    end process;
end Behavioral;
