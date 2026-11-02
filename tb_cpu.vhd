library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_cpu is end entity;
architecture sim of tb_cpu is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal pc_a, inst_a, result_a, pc_b, inst_b, result_b : std_logic_vector(31 downto 0);
    signal halt_a, halt_b : std_logic;
    signal select_a, select_b : std_logic_vector(4 downto 0) := (others => '0');
    signal data_a, data_b : std_logic_vector(31 downto 0);
    signal mem_addr_a, mem_addr_b : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_data_a, mem_data_b : std_logic_vector(31 downto 0);
begin
    cpu_math: entity work.cpu
        generic map(PROGRAM_FILE => "programs/arithmetic.bin")
        port map(clk=>clk, reset=>reset, pc_out=>pc_a, instruction_out=>inst_a,
                 result_out=>result_a, halted=>halt_a, debug_reg_select=>select_a,
                 debug_reg_data=>data_a, debug_mem_addr=>mem_addr_a, debug_mem_data=>mem_data_a);
    cpu_memory: entity work.cpu
        generic map(PROGRAM_FILE => "programs/memory_branch.bin")
        port map(clk=>clk, reset=>reset, pc_out=>pc_b, instruction_out=>inst_b,
                 result_out=>result_b, halted=>halt_b, debug_reg_select=>select_b,
                 debug_reg_data=>data_b, debug_mem_addr=>mem_addr_b, debug_mem_data=>mem_data_b);

    process
        procedure tick is
        begin
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end procedure;
        procedure check_math(constant idx : natural; constant expected : std_logic_vector(31 downto 0)) is
        begin
            select_a <= std_logic_vector(to_unsigned(idx, 5));
            wait for 1 ns;
            assert data_a = expected report "Arithmetic: x" & integer'image(idx) &
                " expected " & to_hstring(expected) & " got " & to_hstring(data_a) severity failure;
        end procedure;
        procedure check_memory(constant idx : natural; constant expected : std_logic_vector(31 downto 0)) is
        begin
            select_b <= std_logic_vector(to_unsigned(idx, 5));
            wait for 1 ns;
            assert data_b = expected report "Memory/branch: x" & integer'image(idx) &
                " expected " & to_hstring(expected) & " got " & to_hstring(data_b) severity failure;
        end procedure;
    begin
        tick;
        reset <= '0';
        for i in 1 to 200 loop
            exit when halt_a = '1' and halt_b = '1';
            tick;
        end loop;
        assert halt_a = '1' report "Arithmetic program did not finish" severity failure;
        assert halt_b = '1' report "Memory/branch program did not finish" severity failure;
        check_math(0, x"00000000");
        check_math(1, x"00000005");
        check_math(2, x"00000007");
        check_math(3, x"0000000C");
        check_math(4, x"00000007");
        check_math(5, x"00000005");
        check_math(6, x"00000007");
        check_math(7, x"00000002");
        check_math(8, x"000000A0");
        check_math(9, x"00000005");
        check_math(10, x"00000004");
        check_math(11, x"0000000D");
        check_math(12, x"00000006");
        check_memory(1, x"00000100");
        check_memory(2, x"0000002A");
        check_memory(3, x"0000002A");
        check_memory(4, x"00000001");
        check_memory(5, x"00000002");
        check_memory(6, x"FFFFFFFF");
        mem_addr_b <= x"00000100";
        wait for 1 ns;
        assert mem_data_b = x"0000002A" report "SW failed: memory[256] != 42" severity failure;
        report "PASS: all 15 RV32I instructions + two binary programs + memory/branch tests" severity note;
        wait;
    end process;
end architecture;
