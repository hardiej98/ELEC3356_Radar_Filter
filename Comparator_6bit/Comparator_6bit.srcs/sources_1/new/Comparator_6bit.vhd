library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Comparator_6bit is
    port (
        A  : in  std_logic_vector(5 downto 0);
        B  : in  std_logic_vector(5 downto 0);
        GT : out std_logic;  -- A > B
        EQ : out std_logic;  -- A = B
        LT : out std_logic   -- A < B
    );
end Comparator_6bit;

architecture Behavioral of Comparator_6bit is
begin
    process(A, B)
        variable a_u, b_u : unsigned(5 downto 0);
    begin
        a_u := unsigned(A);
        b_u := unsigned(B);

        if a_u > b_u then
            GT <= '1';
            EQ <= '0';
            LT <= '0';
        elsif a_u = b_u then
            GT <= '0';
            EQ <= '1';
            LT <= '0';
        else
            GT <= '0';
            EQ <= '0';
            LT <= '1';
        end if;
    end process;
end Behavioral;
