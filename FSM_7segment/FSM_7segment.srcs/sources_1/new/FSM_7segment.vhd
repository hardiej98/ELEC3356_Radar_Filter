library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM_7segment is
    port (
        clk      : in  std_logic;                     -- 100 MHz
        reset    : in  std_logic;                     -- synchronous, active-high
        value_in : in  std_logic_vector(5 downto 0);  -- 6-bit value (0..63)

        SEG      : out std_logic_vector(6 downto 0);  -- a..g, ACTIVE-LOW
        CAT      : out std_logic                      -- digit select
    );
end FSM_7segment;

architecture rtl of FSM_7segment is

    -------------------------------------------------------------------------
    -- Clock divider + digit select
    -------------------------------------------------------------------------
    signal cnt       : unsigned(15 downto 0) := (others => '0');
    signal digit_sel : std_logic := '0';  -- 0 = ones, 1 = tens
    constant DIV_MAX : unsigned(15 downto 0) := to_unsigned(49999, 16); -- ~1kHz/digit

    -------------------------------------------------------------------------
    -- BCD digits and segment register
    -------------------------------------------------------------------------
    signal tens_bcd  : std_logic_vector(3 downto 0) := (others => '0');
    signal ones_bcd  : std_logic_vector(3 downto 0) := (others => '0');
    signal cur_bcd   : std_logic_vector(3 downto 0) := (others => '0');

    signal seg_raw   : std_logic_vector(6 downto 0) := (others => '0'); -- ACTIVE-HIGH
    signal seg_low   : std_logic_vector(6 downto 0) := (others => '1'); -- ACTIVE-LOW

begin

    -------------------------------------------------------------------------
    -- Clock divider + digit toggle
    -------------------------------------------------------------------------
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt       <= (others => '0');
                digit_sel <= '0';
            else
                if cnt = DIV_MAX then
                    cnt       <= (others => '0');
                    digit_sel <= not digit_sel;
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Binary (0..63) -> BCD tens/ones via BCD_decoder
    -------------------------------------------------------------------------
    u_bcd : entity work.BCD_decoder
        port map (
            bin_in     => value_in,
            tens_digit => tens_bcd,
            ones_digit => ones_bcd
        );

    -------------------------------------------------------------------------
    -- Select digit (tens or ones) and drive CAT
    -------------------------------------------------------------------------
    process (digit_sel, tens_bcd, ones_bcd, reset)
    begin
        if reset = '1' then
            cur_bcd <= (others => '0');
            CAT     <= '0';
        else
            if digit_sel = '0' then
                -- show ONES on (for example) right digit
                cur_bcd <= ones_bcd;
                CAT     <= '0';        -- flip if your board wiring is opposite
            else
                -- show TENS on left digit
                cur_bcd <= tens_bcd;
                CAT     <= '1';
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- BCD -> 7-seg using SevenSeg_display (ACTIVE-HIGH), then invert
    -------------------------------------------------------------------------
    u_seg : entity work.SevenSeg_display
        port map (
            BCD => cur_bcd,
            SEG => seg_raw       -- ACTIVE-HIGH
        );

    seg_low <= not seg_raw;      -- convert to ACTIVE-LOW for output
    SEG     <= seg_low;

end rtl;
