-- Bubble_Sort: Bubble Sort Unit for 3x3 Median Filter
-- Purpose:
--   Sort nine 6-bit radar intensity values (from the 3x3 register bank)
--   using a bubble sort algorithm implemented with sequential compare-and-
--   swap operations. The sorted outputs can be used for visualization or
--   to extract the median value (y4 = 5th smallest).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Bubble_Sort is
    port (
        clk   : in  std_logic;  -- 100 MHz system clock
        reset : in  std_logic;  -- synchronous, active-high
        start : in  std_logic;  -- sort start (use a 1-clock pulse)

        -- 3x3 neighborhood inputs from Reg_Bank 3x3 array
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

    -- Internal array of 9 values as unsigned for comparison
    type reg_array_t is array (0 to 8) of unsigned(5 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));

    -- Bubble sort loop indices
    signal i : integer range 0 to 7 := 0;  -- outer loop: number of passes
    signal j : integer range 0 to 7 := 0;  -- inner loop: compare index

    -- FSM states (rename DONE to avoid clash with 'done' signal)
    type state_type is (IDLE, SORT_STATE, DONE_STATE);
    signal state : state_type := IDLE;

begin

    -- Main sequential process: FSM + bubble sort compare-and-swap
    process(clk)
        variable temp : unsigned(5 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Global synchronous reset
                state <= IDLE;
                regs  <= (others => (others => '0'));
                i     <= 0;
                j     <= 0;
                done  <= '0';

            else
                case state is

                    when IDLE =>
                        done <= '0';  -- not done in IDLE

                        -- Start pulse: load inputs and begin sorting
                        if start = '1' then
                            regs(0) <= unsigned(x0);
                            regs(1) <= unsigned(x1);
                            regs(2) <= unsigned(x2);
                            regs(3) <= unsigned(x3);
                            regs(4) <= unsigned(x4);
                            regs(5) <= unsigned(x5);
                            regs(6) <= unsigned(x6);
                            regs(7) <= unsigned(x7);
                            regs(8) <= unsigned(x8);

                            i <= 0;
                            j <= 0;
                            state <= SORT_STATE;
                        end if;

                    when SORT_STATE =>
                        -- One compare-and-swap per clock cycle: regs(j) vs regs(j+1)
                        temp := regs(j);
                        if regs(j) > regs(j + 1) then
                            regs(j)     <= regs(j + 1);
                            regs(j + 1) <= temp;
                        end if;

                        -- Advance inner loop index j, then outer loop index i
                        if j < (7 - i) then
                            -- More pairs to compare in this pass
                            j <= j + 1;
                        else
                            -- End of inner pass for this i
                            j <= 0;
                            if i < 7 then
                                i <= i + 1;             -- next pass
                            else
                                -- All passes complete (i = 7): sorting done
                                state <= DONE_STATE;
                                done  <= '1';
                            end if;
                        end if;

                    when DONE_STATE =>
                        -- Hold done = '1' until next start or reset
                        done <= '1';

                        -- Allow a new sort without full system reset
                        if start = '1' then
                            regs(0) <= unsigned(x0);
                            regs(1) <= unsigned(x1);
                            regs(2) <= unsigned(x2);
                            regs(3) <= unsigned(x3);
                            regs(4) <= unsigned(x4);
                            regs(5) <= unsigned(x5);
                            regs(6) <= unsigned(x6);
                            regs(7) <= unsigned(x7);
                            regs(8) <= unsigned(x8);

                            i    <= 0;
                            j    <= 0;
                            done <= '0';
                            state <= SORT_STATE;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Outputs: map internal regs to sorted outputs y0..y8
    y0 <= std_logic_vector(regs(0));
    y1 <= std_logic_vector(regs(1));
    y2 <= std_logic_vector(regs(2));
    y3 <= std_logic_vector(regs(3));
    y4 <= std_logic_vector(regs(4));  -- median value here
    y5 <= std_logic_vector(regs(5));
    y6 <= std_logic_vector(regs(6));
    y7 <= std_logic_vector(regs(7));
    y8 <= std_logic_vector(regs(8));

end Behavioral;
