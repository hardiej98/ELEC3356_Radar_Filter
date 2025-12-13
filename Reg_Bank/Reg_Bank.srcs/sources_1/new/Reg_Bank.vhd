library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Reg_Bank is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data_in  : in  std_logic_vector(5 downto 0);
        load_sel : in  std_logic_vector(3 downto 0);  -- selects r0..r8
        load_en  : in  std_logic;

        r0 : out std_logic_vector(5 downto 0);
        r1 : out std_logic_vector(5 downto 0);
        r2 : out std_logic_vector(5 downto 0);
        r3 : out std_logic_vector(5 downto 0);
        r4 : out std_logic_vector(5 downto 0);
        r5 : out std_logic_vector(5 downto 0);
        r6 : out std_logic_vector(5 downto 0);
        r7 : out std_logic_vector(5 downto 0);
        r8 : out std_logic_vector(5 downto 0)
    );
end Reg_Bank;

architecture Behavioral of Reg_Bank is

    -- 9 registers, each 6 bits
    type reg_array_t is array (0 to 8) of std_logic_vector(5 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));

begin

    -------------------------------------------------------------------------
    -- Single synchronous process: resets and writes selected register
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                regs <= (others => (others => '0'));

            elsif load_en = '1' then
                case load_sel is
                    when "0000" => regs(0) <= data_in;
                    when "0001" => regs(1) <= data_in;
                    when "0010" => regs(2) <= data_in;
                    when "0011" => regs(3) <= data_in;
                    when "0100" => regs(4) <= data_in;
                    when "0101" => regs(5) <= data_in;
                    when "0110" => regs(6) <= data_in;
                    when "0111" => regs(7) <= data_in;
                    when "1000" => regs(8) <= data_in;
                    when others => null;  -- no write
                end case;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Continuous outputs
    -------------------------------------------------------------------------
    r0 <= regs(0);
    r1 <= regs(1);
    r2 <= regs(2);
    r3 <= regs(3);
    r4 <= regs(4);
    r5 <= regs(5);
    r6 <= regs(6);
    r7 <= regs(7);
    r8 <= regs(8);

end Behavioral;
