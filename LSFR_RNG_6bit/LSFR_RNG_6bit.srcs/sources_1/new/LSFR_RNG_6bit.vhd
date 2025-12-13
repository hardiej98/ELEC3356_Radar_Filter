library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LFSR_RNG_6bit is
    port (
        clk        : in  std_logic;                   -- 100 MHz system clock
        reset      : in  std_logic;                   -- synchronous, active-high
        enable     : in  std_logic;                   -- step LFSR_RNG_6bit when '1'
        random_out : out std_logic_vector(5 downto 0) -- 6-bit pseudorandom output
    );
end LFSR_RNG_6bit;

architecture Behavioral of LFSR_RNG_6bit is

    -- 6-bit LFSR_RNG_6bit state
    signal LFSR_RNG_6bit_reg : std_logic_vector(5 downto 0);

begin

    process(clk)
        variable feedback : std_logic;
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Non-zero seed so we don't get stuck at all-zeros
                LFSR_RNG_6bit_reg <= "000001";

            elsif enable = '1' then
                -- Simple feedback using top two bits
                feedback := LFSR_RNG_6bit_reg(5) xor LFSR_RNG_6bit_reg(4);

                -- Shift left: new bit enters at bit 0
                -- new[5] = old[4], ..., new[1] = old[0], new[0] = feedback
                LFSR_RNG_6bit_reg <= LFSR_RNG_6bit_reg(4 downto 0) & feedback;
            end if;

        end if;
    end process;

    random_out <= LFSR_RNG_6bit_reg;

end Behavioral;
