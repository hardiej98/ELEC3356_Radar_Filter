-- RAM_1D
-- Purpose:
--   1-D RAM storage for a conceptual 32x32 image (1024 pixels total).
--   Each pixel is stored as a 6-bit radar intensity sample.
--
--   Although the image is a 2-D grid [row, col] with row,col ? [0..31],
--   it is mapped into this 1-D RAM using:
--
--       Address = (row * 32) + col       -- 0 .. 1023
--
--   The top-level design will:
--     - Use counters/registers to generate row and column indices
--     - Convert (row, col) to a 10-bit linear address
--     - Handle 3x3 neighborhoods and zero-padding at the edges
--
-- Ports:
--   clk  : system clock (100 MHz)
--   we   : write-enable ('1' = write din to RAM at addr on this clock edge)
--   addr : 10-bit linear address (0..1023)
--   din  : 6-bit data input to store into RAM
--   dout : 6-bit data output read from RAM
--
-- Notes:
--   - This module is purely the 1-D storage element.
--     Zero-padding for edge pixels (out-of-range neighbors) is handled
--     outside this RAM by the address-generation / control logic.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity RAM_1D is
    port (
        clk  : in  std_logic;                           -- 100 MHz clock
        we   : in  std_logic;                           -- write enable
        addr : in  std_logic_vector(9 downto 0);        -- 10-bit address (0..1023)
        din  : in  std_logic_vector(5 downto 0);        -- 6-bit data in
        dout : out std_logic_vector(5 downto 0)         -- 6-bit data out
    );
end RAM_1D;

architecture Behavioral of RAM_1D is

    -- 1024 x 6-bit memory array
    type ram_array_t is array (0 to 1023) of std_logic_vector(5 downto 0);

    -- Initialize all locations to 0 (cleared image)
    signal ram : ram_array_t := (others => (others => '0'));

begin

    ------------------------------------------------------------------------
    -- Synchronous write
    ------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Asynchronous read: dout reflects the current contents at addr
    ------------------------------------------------------------------------
    dout <= ram(to_integer(unsigned(addr)));

end Behavioral;
