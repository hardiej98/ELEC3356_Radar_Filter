library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM_7segment is
    port (
        clk           : in  std_logic;                    -- 100 MHz
        reset         : in  std_logic;                    -- synchronous, active-high

        -- Timer ticks from Timer module
        tick_mux      : in  std_logic;                    -- from Timer_7segment
        tick_index    : in  std_logic;                    -- from Timer_ReadSort

        -- Display state from main FSM:
        --   "00" -> unsorted 3x3 (r0..r8)
        --   "01" -> sorted   3x3 (s0..s8)
        --   "10" -> final filtered center (median_value)
        display_state : in  std_logic_vector(1 downto 0);

        -- Unsorted 3x3 values (from Reg_Bank)
        r0 : in std_logic_vector(5 downto 0);
        r1 : in std_logic_vector(5 downto 0);
        r2 : in std_logic_vector(5 downto 0);
        r3 : in std_logic_vector(5 downto 0);
        r4 : in std_logic_vector(5 downto 0);
        r5 : in std_logic_vector(5 downto 0);
        r6 : in std_logic_vector(5 downto 0);
        r7 : in std_logic_vector(5 downto 0);
        r8 : in std_logic_vector(5 downto 0);

        -- Sorted 3x3 values (from Bubble_Sort)
        s0 : in std_logic_vector(5 downto 0);
        s1 : in std_logic_vector(5 downto 0);
        s2 : in std_logic_vector(5 downto 0);
        s3 : in std_logic_vector(5 downto 0);
        s4 : in std_logic_vector(5 downto 0);
        s5 : in std_logic_vector(5 downto 0);
        s6 : in std_logic_vector(5 downto 0);
        s7 : in std_logic_vector(5 downto 0);
        s8 : in std_logic_vector(5 downto 0);

        -- Final filtered (center) value (typically s4)
        median_value : in std_logic_vector(5 downto 0);

        -- Outputs to 7-seg (common-anode, active-LOW segments & anodes)
        SEG : out std_logic_vector(6 downto 0);  -- a..g
        AN  : out std_logic_vector(3 downto 0)   -- an3..an0 (active-LOW)
    );
end FSM_7segment;

architecture Behavioral of FSM_7segment is

    -------------------------------------------------------------------------
    -- Digit multiplex FSM: 4 digits
    -------------------------------------------------------------------------
    type digit_state_type is (DIGIT0, DIGIT1, DIGIT2, DIGIT3);
    signal digit_state : digit_state_type := DIGIT0;

    -------------------------------------------------------------------------
    -- 3x3 neighborhood index (0..8)
    -------------------------------------------------------------------------
    signal idx_3x3 : integer range 0 to 8 := 0;  -- which of the 9 values

    -------------------------------------------------------------------------
    -- Current 6-bit value to display and its BCD digits
    -------------------------------------------------------------------------
    signal current_val : std_logic_vector(5 downto 0) := (others => '0');
    signal tens_digit  : std_logic_vector(3 downto 0) := (others => '0');
    signal ones_digit  : std_logic_vector(3 downto 0) := (others => '0');

    -- BCD for index and mode (left digits)
    signal bcd_idx   : std_logic_vector(3 downto 0) := (others => '0');
    signal bcd_mode  : std_logic_vector(3 downto 0) := (others => '0');

    -- BCD nibble currently sent to the 7-seg decoder
    signal digit_value : std_logic_vector(3 downto 0) := (others => '0');

begin

    -------------------------------------------------------------------------
    -- 1) Digit multiplex FSM
    --    Advance 0->1->2->3->0 when tick_mux = '1' (from Timer_7segment).
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                digit_state <= DIGIT0;
            elsif tick_mux = '1' then
                case digit_state is
                    when DIGIT0 => digit_state <= DIGIT1;
                    when DIGIT1 => digit_state <= DIGIT2;
                    when DIGIT2 => digit_state <= DIGIT3;
                    when DIGIT3 => digit_state <= DIGIT0;
                end case;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 2) 3x3 index scanner
    --    - In unsorted/sorted modes ("00"/"01"), move through 0..8 on tick_index
    --    - In filtered mode ("10"), hold index at center (4)
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                idx_3x3 <= 0;
            else
                if display_state = "10" then
                    -- filtered center: always index 4
                    idx_3x3 <= 4;
                elsif (display_state = "00") or (display_state = "01") then
                    if tick_index = '1' then
                        if idx_3x3 = 8 then
                            idx_3x3 <= 0;
                        else
                            idx_3x3 <= idx_3x3 + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 3) Select current 6-bit value based on display_state & idx_3x3
    -------------------------------------------------------------------------
    process(idx_3x3, display_state,
            r0,r1,r2,r3,r4,r5,r6,r7,r8,
            s0,s1,s2,s3,s4,s5,s6,s7,s8,
            median_value)
    begin
        current_val <= (others => '0');

        if display_state = "00" then
            -- Unsorted 3x3 neighborhood
            case idx_3x3 is
                when 0 => current_val <= r0;
                when 1 => current_val <= r1;
                when 2 => current_val <= r2;
                when 3 => current_val <= r3;
                when 4 => current_val <= r4;
                when 5 => current_val <= r5;
                when 6 => current_val <= r6;
                when 7 => current_val <= r7;
                when 8 => current_val <= r8;
                when others => current_val <= (others => '0');
            end case;

        elsif display_state = "01" then
            -- Sorted 3x3 neighborhood
            case idx_3x3 is
                when 0 => current_val <= s0;
                when 1 => current_val <= s1;
                when 2 => current_val <= s2;
                when 3 => current_val <= s3;
                when 4 => current_val <= s4;
                when 5 => current_val <= s5;
                when 6 => current_val <= s6;
                when 7 => current_val <= s7;
                when 8 => current_val <= s8;
                when others => current_val <= (others => '0');
            end case;

        else
            -- display_state = "10": final filtered center value
            current_val <= median_value;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 4) Binary (6-bit) to BCD tens/ones for current_val
    -------------------------------------------------------------------------
    u_bcd : entity work.BCD_decoder
        port map (
            bin_in     => current_val,
            tens_digit => tens_digit,
            ones_digit => ones_digit
        );

    -------------------------------------------------------------------------
    -- 5) BCD for index (digit 2) and display mode (digit 3)
    -------------------------------------------------------------------------
    bcd_idx <= std_logic_vector(to_unsigned(idx_3x3, 4));

    with display_state select
        bcd_mode <=
            "0000" when "00",  -- 0: unsorted
            "0001" when "01",  -- 1: sorted
            "0010" when "10",  -- 2: filtered
            "1111" when others; -- invalid -> blank

    -------------------------------------------------------------------------
    -- 6) Digit select: choose BCD nibble and anode based on digit_state
    -------------------------------------------------------------------------
    with digit_state select
        digit_value <=
            ones_digit when DIGIT0,  -- rightmost
            tens_digit when DIGIT1,
            bcd_idx    when DIGIT2,
            bcd_mode   when DIGIT3;

    with digit_state select
        AN <=
            "1110" when DIGIT0,  -- enable digit 0 (rightmost)
            "1101" when DIGIT1,  -- enable digit 1
            "1011" when DIGIT2,  -- enable digit 2
            "0111" when DIGIT3;  -- enable digit 3 (leftmost)

    -------------------------------------------------------------------------
    -- 7) BCD -> 7-seg decoder (ACTIVE-LOW segments, common-anode)
    -------------------------------------------------------------------------
    u_seg : entity work.SevenSeg_display
        port map (
            BCD => digit_value,
            SEG => SEG
        );

end Behavioral;
