library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SevenSeg_display is
    port (
        BCD : in  std_logic_vector(3 downto 0);  -- 0..9
        SEG : out std_logic_vector(6 downto 0)   -- a..g, ACTIVE-HIGH for PmodSSD
    );
end SevenSeg_display;

architecture Behavioral of SevenSeg_display is
begin
    process(BCD)
    begin
        -- default: all segments OFF
        SEG <= "0000000";

        case BCD is
            --              abcdefg
            when "0000" => SEG <= "1111110"; -- 0
            when "0001" => SEG <= "0110000"; -- 1
            when "0010" => SEG <= "1101101"; -- 2
            when "0011" => SEG <= "1111001"; -- 3
            when "0100" => SEG <= "0110011"; -- 4
            when "0101" => SEG <= "1011011"; -- 5
            when "0110" => SEG <= "1011111"; -- 6
            when "0111" => SEG <= "1110000"; -- 7
            when "1000" => SEG <= "1111111"; -- 8
            when "1001" => SEG <= "1111011"; -- 9

            when others => SEG <= "0000000"; -- blank
        end case;
    end process;
end Behavioral;
