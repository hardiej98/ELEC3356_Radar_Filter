library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MedianFilter_FSM is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;  -- synchronous, active-high

        start_pulse  : in  std_logic;
        read_pulse   : in  std_logic;
        sort_pulse   : in  std_logic;
        sort_done    : in  std_logic;

        lfsr_enable  : out std_logic;
        mem_we       : out std_logic;
        mem_addr     : out unsigned(3 downto 0); -- 0..8
        display_sel  : out std_logic;            -- 0=center, 1=median
        sort_start   : out std_logic             -- 1-clock pulse to Bubble_Sort
    );
end MedianFilter_FSM;

architecture rtl of MedianFilter_FSM is

    type state_t is (S_IDLE, S_FILL, S_READY, S_SORTING);

    signal state        : state_t := S_IDLE;
    signal index        : unsigned(3 downto 0) := (others => '0');
    signal lfsr_en_reg  : std_logic := '0';
    signal mem_we_reg   : std_logic := '0';
    signal display_sel_r: std_logic := '0';
    signal sort_start_r : std_logic := '0';

begin

    lfsr_enable <= lfsr_en_reg;
    mem_we      <= mem_we_reg;
    mem_addr    <= index;
    display_sel <= display_sel_r;
    sort_start  <= sort_start_r;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state         <= S_IDLE;
                index         <= (others => '0');
                lfsr_en_reg   <= '0';
                mem_we_reg    <= '0';
                display_sel_r <= '0';
                sort_start_r  <= '0';
            else
                -- default each cycle
                sort_start_r <= '0';

                case state is

                    when S_IDLE =>
                        lfsr_en_reg   <= '0';
                        mem_we_reg    <= '0';
                        index         <= (others => '0');
                        display_sel_r <= '0';  -- show center by default

                        if start_pulse = '1' then
                            state <= S_FILL;
                        end if;

                    when S_FILL =>
                        lfsr_en_reg <= '1';
                        mem_we_reg  <= '1';

                        if index = to_unsigned(8, index'length) then
                            state       <= S_READY;
                            index       <= (others => '0');
                            lfsr_en_reg <= '0';
                            mem_we_reg  <= '0';
                        else
                            index <= index + 1;
                        end if;

                    when S_READY =>
                        lfsr_en_reg <= '0';
                        mem_we_reg  <= '0';

                        if start_pulse = '1' then
                            -- Refill 3x3 with new randoms
                            state         <= S_FILL;
                            index         <= (others => '0');
                            display_sel_r <= '0';

                        elsif read_pulse = '1' then
                            -- Show unsorted center
                            display_sel_r <= '0';

                        elsif sort_pulse = '1' then
                            -- Start Bubble_Sort
                            sort_start_r  <= '1';
                            state         <= S_SORTING;
                        end if;

                    when S_SORTING =>
                        lfsr_en_reg <= '0';
                        mem_we_reg  <= '0';

                        if sort_done = '1' then
                            -- Show median when sort finishes
                            display_sel_r <= '1';
                            state         <= S_READY;
                        end if;

                end case;
            end if;
        end if;
    end process;

end rtl;
