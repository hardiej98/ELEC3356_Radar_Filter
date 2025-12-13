library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_1D is
    port (
        clk  : in  std_logic;                     -- 100 MHz clock
        we   : in  std_logic;                     -- write enable
        addr : in  std_logic_vector(9 downto 0);  -- 10-bit address (0..1023)
        din  : in  std_logic_vector(5 downto 0);  -- 6-bit data in
        dout : out std_logic_vector(5 downto 0)   -- 6-bit data out
    );
end RAM_1D;

architecture Behavioral of RAM_1D is

    -- 1024 x 6-bit memory array
    type ram_array_t is array (0 to 1023) of std_logic_vector(5 downto 0);

    -- Option A: rely on your CLEAR_RAM FSM to clear contents
    signal ram : ram_array_t;
    -- Option B (if you like sim starting at zeros):
    -- signal ram : ram_array_t := (others => (others => '0'));

begin

    -- Synchronous write
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
        end if;
    end process;

    -- Asynchronous read
    dout <= ram(to_integer(unsigned(addr)));

end Behavioral;
