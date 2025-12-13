library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BCD_decoder is
    port (
        bin_in     : in  std_logic_vector(5 downto 0);  -- 0..63
        tens_digit : out std_logic_vector(3 downto 0);  -- tens place (0..6)
        ones_digit : out std_logic_vector(3 downto 0)   -- ones place (0..9)
    );
end BCD_decoder;

architecture Behavioral of BCD_decoder is
begin
    process(bin_in)
        variable value : integer range 0 to 63;
    begin
        -- Convert 6-bit unsigned binary to integer 0..63
        value := to_integer(unsigned(bin_in));

        -- tens_digit = floor(value / 10)
        tens_digit <= std_logic_vector(to_unsigned(value / 10, 4));

        -- ones_digit = value mod 10
        ones_digit <= std_logic_vector(to_unsigned(value mod 10, 4));
    end process;
end Behavioral;
