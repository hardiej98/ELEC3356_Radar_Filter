-- Bubble_Sort: Bubble Sort Unit for 3x3 Median Filter
-- Uses 9 internal 6-bit registers and a 6-bit comparator block
-- to perform one compare-and-swap per clock cycle.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Bubble_Sort is
    port (
        clk   : in  std_logic;  -- 100 MHz system clock
        reset : in  std_logic;  -- synchronous, active-high
        start : in  std_logic;  -- sort start (use a 1-clock pulse)

        -- 3x3 neighborhood inputs from Reg_Bank
        x0    : in  std_logic_vector(5 downto 0);
        x1    : in  std_logic_vector(5 downto 0);
        x2    : in  std_logic_vector(5 downto 0);
        x3    : in  std_logic_vector(5 downto 0);
        x4    : in  std_logic_vector(5 downto 0);
        x5    : in  std_logic_vector(5 downto 0);
        x6    : in  std_logic_vector(5 downto 0);
        x7    : in  std_logic_vector(5 downto 0);
        x8    : in  std_logic_vector(5 downto 0);

        -- Sorted outputs (ascending). Median = y4.
        y0    : out std_logic_vector(5 downto 0);
        y1    : out std_logic_vector(5 downto 0);
        y2    : out std_logic_vector(5 downto 0);
        y3    : out std_logic_vector(5 downto 0);
        y4    : out std_logic_vector(5 downto 0);  -- median value
        y5    : out std_logic_vector(5 downto 0);
        y6    : out std_logic_vector(5 downto 0);
        y7    : out std_logic_vector(5 downto 0);
        y8    : out std_logic_vector(5 downto 0);

        done  : out std_logic  -- '1' when sorting complete
    );
end Bubble_Sort;

architecture Behavioral of Bubble_Sort is

    -- 9 internal registers, each 6 bits
    type reg_array_t is array (0 to 8) of std_logic_vector(5 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));

    -- Bubble sort loop indices
    signal i : integer range 0 to 7 := 0;  -- outer pass index
    signal j : integer range 0 to 7 := 0;  -- inner compare index

    -- FSM states
    type state_type is (IDLE, SORT, DONE_STATE);
    signal state : state_type := IDLE;

    -- Comparator inputs/outputs (purely combinational datapath)
    signal cmp_A, cmp_B : std_logic_vector(5 downto 0);
    signal cmp_GT, cmp_EQ, cmp_LT : std_logic;

begin

    -------------------------------------------------------------------------
    -- Comparator instance: compares the current pair regs(j), regs(j+1)
    -------------------------------------------------------------------------
    U_CMP : entity work.Comparator_6bit
        port map (
            A  => cmp_A,
            B  => cmp_B,
            GT => cmp_GT,
            EQ => cmp_EQ,
            LT => cmp_LT
        );

    -------------------------------------------------------------------------
    -- Combinational datapath: select which pair of regs feeds comparator
    -------------------------------------------------------------------------
    process(regs, j)
    begin
        -- default (won't be used when j is valid)
        cmp_A <= (others => '0');
        cmp_B <= (others => '0');

        case j is
            when 0 =>
                cmp_A <= regs(0);
                cmp_B <= regs(1);
            when 1 =>
                cmp_A <= regs(1);
                cmp_B <= regs(2);
            when 2 =>
                cmp_A <= regs(2);
                cmp_B <= regs(3);
            when 3 =>
                cmp_A <= regs(3);
                cmp_B <= regs(4);
            when 4 =>
                cmp_A <= regs(4);
                cmp_B <= regs(5);
            when 5 =>
                cmp_A <= regs(5);
                cmp_B <= regs(6);
            when 6 =>
                cmp_A <= regs(6);
                cmp_B <= regs(7);
            when 7 =>
                cmp_A <= regs(7);
                cmp_B <= regs(8);
            when others =>
                -- keep defaults
                null;
        end case;
    end process;

    -------------------------------------------------------------------------
    -- Sequential process: FSM + compare-and-swap using comparator outputs
    -------------------------------------------------------------------------
    process(clk)
        variable temp : std_logic_vector(5 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then
                state <= IDLE;
                regs  <= (others => (others => '0'));
                i     <= 0;
                j     <= 0;
                done  <= '0';

            else
                case state is

                    -----------------------------------------------------------------
                    when IDLE =>
                        done <= '0';

                        -- Load all 9 inputs and start sorting on start pulse
                        if start = '1' then
                            regs(0) <= x0;
                            regs(1) <= x1;
                            regs(2) <= x2;
                            regs(3) <= x3;
                            regs(4) <= x4;
                            regs(5) <= x5;
                            regs(6) <= x6;
                            regs(7) <= x7;
                            regs(8) <= x8;

                            i <= 0;
                            j <= 0;
                            state <= SORT;
                        end if;

                    -----------------------------------------------------------------
                    when SORT =>
                        -- One compare-and-swap per clock between regs(j) & regs(j+1)
                        if j <= 7 then
                            if cmp_GT = '1' then
                                -- swap regs(j) and regs(j+1)
                                temp      := regs(j);
                                regs(j)   <= regs(j+1);
                                regs(j+1) <= temp;
                            end if;
                        end if;

                        -- Advance inner/outer loop indices
                        if j < (7 - i) then
                            -- more pairs to compare this pass
                            j <= j + 1;
                        else
                            -- finished this pass over the array
                            j <= 0;
                            if i < 7 then
                                i <= i + 1;
                            else
                                -- all passes complete
                                state <= DONE_STATE;
                                done  <= '1';
                            end if;
                        end if;

                    -----------------------------------------------------------------
                    when DONE_STATE =>
                        -- Hold done = '1' until next start or reset
                        done <= '1';

                        -- Allow new sort without global reset
                        if start = '1' then
                            regs(0) <= x0;
                            regs(1) <= x1;
                            regs(2) <= x2;
                            regs(3) <= x3;
                            regs(4) <= x4;
                            regs(5) <= x5;
                            regs(6) <= x6;
                            regs(7) <= x7;
                            regs(8) <= x8;

                            i    <= 0;
                            j    <= 0;
                            done <= '0';
                            state <= SORT;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Outputs: sorted values (ascending)
    -------------------------------------------------------------------------
    y0 <= regs(0);
    y1 <= regs(1);
    y2 <= regs(2);
    y3 <= regs(3);
    y4 <= regs(4);  -- median
    y5 <= regs(5);
    y6 <= regs(6);
    y7 <= regs(7);
    y8 <= regs(8);

end Behavioral;
