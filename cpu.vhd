library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu is
    generic (
        PROGRAM_FILE : string := "programs/arithmetic.bin";
        MEM_BYTES : positive := 2048
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        pc_out : out std_logic_vector(31 downto 0);
        instruction_out : out std_logic_vector(31 downto 0);
        result_out : out std_logic_vector(31 downto 0);
        halted : out std_logic;
        debug_reg_select : in std_logic_vector(4 downto 0);
        debug_reg_data : out std_logic_vector(31 downto 0);
        debug_mem_addr : in std_logic_vector(31 downto 0);
        debug_mem_data : out std_logic_vector(31 downto 0)
    );
end entity;

architecture behavioral of cpu is
    type memory_t is array (0 to MEM_BYTES - 1) of std_logic_vector(7 downto 0);
    type char_file_t is file of character;

    -- The actual input is a RAW binary file: 4 little-endian bytes per RV32I instruction.
    impure function load_binary(filename : string) return memory_t is
        file binary_file : char_file_t;
        variable status : file_open_status;
        variable mem : memory_t := (others => (others => '0'));
        variable ch : character;
        variable index : natural := 0;
    begin
        file_open(status, binary_file, filename, read_mode);
        assert status = open_ok report "Could not open program binary: " & filename severity failure;
        while not endfile(binary_file) loop
            assert index < MEM_BYTES report "Binary too large for memory" severity failure;
            read(binary_file, ch);
            mem(index) := std_logic_vector(to_unsigned(character'pos(ch), 8));
            index := index + 1;
        end loop;
        file_close(binary_file);
        report "Loaded " & integer'image(index) & " program bytes from " & filename severity note;
        return mem;
    end function;

    function word_at(m : memory_t; addr : natural) return std_logic_vector is
    begin
        if addr > MEM_BYTES - 4 then
            return (31 downto 0 => '0');
        end if;
        return m(addr+3) & m(addr+2) & m(addr+1) & m(addr);
    end function;

    -- Format decoded RV32I instructions for the simulation transcript.
    function disassemble(inst : std_logic_vector(31 downto 0)) return string is
        variable op : std_logic_vector(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0);
        variable f7 : std_logic_vector(6 downto 0);
        variable rd, rs1, rs2 : natural range 0 to 31;
        variable imm_i, imm_s, imm_b : signed(31 downto 0);
    begin
        op := inst(6 downto 0);
        f3 := inst(14 downto 12);
        f7 := inst(31 downto 25);
        rd := to_integer(unsigned(inst(11 downto 7)));
        rs1 := to_integer(unsigned(inst(19 downto 15)));
        rs2 := to_integer(unsigned(inst(24 downto 20)));
        imm_i := resize(signed(inst(31 downto 20)), 32);
        imm_s(11 downto 5) := signed(inst(31 downto 25));
        imm_s(4 downto 0) := signed(inst(11 downto 7));
        imm_s(31 downto 12) := (others => inst(31));
        imm_b(12) := inst(31);
        imm_b(11) := inst(7);
        imm_b(10 downto 5) := signed(inst(30 downto 25));
        imm_b(4 downto 1) := signed(inst(11 downto 8));
        imm_b(0) := '0';
        imm_b(31 downto 13) := (others => inst(31));

        case op is
            when "0110011" =>
                case f3 is
                    when "000" =>
                        if f7 = "0000000" then
                            return "ADD x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2);
                        elsif f7 = "0100000" then
                            return "SUB x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2);
                        end if;
                    when "111" =>
                        if f7 = "0000000" then return "AND x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2); end if;
                    when "110" =>
                        if f7 = "0000000" then return "OR x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2); end if;
                    when "100" =>
                        if f7 = "0000000" then return "XOR x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2); end if;
                    when "001" =>
                        if f7 = "0000000" then return "SLL x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2); end if;
                    when "101" =>
                        if f7 = "0000000" then return "SRL x" & integer'image(rd) & ", x" & integer'image(rs1) & ", x" & integer'image(rs2); end if;
                    when others => null;
                end case;
            when "0010011" =>
                case f3 is
                    when "000" => return "ADDI x" & integer'image(rd) & ", x" & integer'image(rs1) & ", " & integer'image(to_integer(imm_i));
                    when "111" => return "ANDI x" & integer'image(rd) & ", x" & integer'image(rs1) & ", " & integer'image(to_integer(imm_i));
                    when "110" => return "ORI x" & integer'image(rd) & ", x" & integer'image(rs1) & ", " & integer'image(to_integer(imm_i));
                    when "100" => return "XORI x" & integer'image(rd) & ", x" & integer'image(rs1) & ", " & integer'image(to_integer(imm_i));
                    when others => null;
                end case;
            when "0000011" =>
                if f3 = "010" then
                    return "LW x" & integer'image(rd) & ", " & integer'image(to_integer(imm_i)) & "(x" & integer'image(rs1) & ")";
                end if;
            when "0100011" =>
                if f3 = "010" then
                    return "SW x" & integer'image(rs2) & ", " & integer'image(to_integer(imm_s)) & "(x" & integer'image(rs1) & ")";
                end if;
            when "1100011" =>
                case f3 is
                    when "000" => return "BEQ x" & integer'image(rs1) & ", x" & integer'image(rs2) & ", " & integer'image(to_integer(imm_b));
                    when "001" => return "BNE x" & integer'image(rs1) & ", x" & integer'image(rs2) & ", " & integer'image(to_integer(imm_b));
                    when others => null;
                end case;
            when "1110011" =>
                if inst = x"00100073" then return "EBREAK"; end if;
            when others => null;
        end case;
        return "UNKNOWN";
    end function;

    type registers_t is array(0 to 31) of std_logic_vector(31 downto 0);
    signal registers : registers_t := (others => (others => '0'));
    signal memory : memory_t := load_binary(PROGRAM_FILE);
    signal pc : unsigned(31 downto 0) := (others => '0');
    signal current_instruction : std_logic_vector(31 downto 0);
    signal last_result : std_logic_vector(31 downto 0) := (others => '0');
    signal stop : std_logic := '0';
begin
    pc_out <= std_logic_vector(pc);
    result_out <= last_result;
    halted <= stop;
    debug_reg_data <= registers(to_integer(unsigned(debug_reg_select)));
    debug_mem_data <= word_at(memory, to_integer(unsigned(debug_mem_addr)))
        when unsigned(debug_mem_addr) <= to_unsigned(MEM_BYTES - 4, 32)
        else (others => '0');
    current_instruction <= word_at(memory, to_integer(pc))
        when pc <= to_unsigned(MEM_BYTES - 4, 32)
        else (others => '0');
    instruction_out <= current_instruction;

    process(clk)
        variable instr : std_logic_vector(31 downto 0);
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(2 downto 0);
        variable funct7 : std_logic_vector(6 downto 0);
        variable rd, rs1, rs2 : natural range 0 to 31;
        variable imm_i, imm_s, imm_b : signed(31 downto 0);
        variable a, b, value : std_logic_vector(31 downto 0);
        variable next_pc : unsigned(31 downto 0);
        variable write_rd, store_word, valid : boolean;
        variable addr : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc <= (others => '0');
                registers <= (others => (others => '0'));
                last_result <= (others => '0');
                stop <= '0';
                -- Memory keeps its preloaded program and is not cleared on reset.
            elsif stop = '0' then
                instr := current_instruction;
                opcode := instr(6 downto 0);
                funct3 := instr(14 downto 12);
                funct7 := instr(31 downto 25);
                rd := to_integer(unsigned(instr(11 downto 7)));
                rs1 := to_integer(unsigned(instr(19 downto 15)));
                rs2 := to_integer(unsigned(instr(24 downto 20)));
                imm_i := resize(signed(instr(31 downto 20)), 32);
                -- Decode S-type immediate without ambiguous concatenation.
                imm_s(11 downto 5) := signed(instr(31 downto 25));
                imm_s(4 downto 0) := signed(instr(11 downto 7));
                imm_s(31 downto 12) := (others => instr(31));

                -- Decode B-type immediate (including the implicit zero bit).
                imm_b(12) := instr(31);
                imm_b(11) := instr(7);
                imm_b(10 downto 5) := signed(instr(30 downto 25));
                imm_b(4 downto 1) := signed(instr(11 downto 8));
                imm_b(0) := '0';
                imm_b(31 downto 13) := (others => instr(31));
                a := registers(rs1);
                b := registers(rs2);
                value := (others => '0');
                next_pc := pc + 4;
                write_rd := false;
                store_word := false;
                valid := true;
                addr := (others => '0');

                case opcode is
                    when "0110011" => -- R type
                        write_rd := true;
                        case funct3 is
                            when "000" =>
                                if funct7 = "0000000" then value := std_logic_vector(unsigned(a) + unsigned(b)); -- ADD
                                elsif funct7 = "0100000" then value := std_logic_vector(unsigned(a) - unsigned(b)); -- SUB
                                else valid := false; end if;
                            when "111" => if funct7 = "0000000" then value := a and b; else valid := false; end if; -- AND
                            when "110" => if funct7 = "0000000" then value := a or b; else valid := false; end if; -- OR
                            when "100" => if funct7 = "0000000" then value := a xor b; else valid := false; end if; -- XOR
                            when "001" => if funct7 = "0000000" then value := std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b(4 downto 0))))); else valid := false; end if; -- SLL
                            when "101" => if funct7 = "0000000" then value := std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b(4 downto 0))))); else valid := false; end if; -- SRL
                            when others => valid := false;
                        end case;
                    when "0010011" => -- I type
                        write_rd := true;
                        case funct3 is
                            when "000" => value := std_logic_vector(unsigned(a) + unsigned(imm_i)); -- ADDI
                            when "111" => value := a and std_logic_vector(imm_i); -- ANDI
                            when "110" => value := a or std_logic_vector(imm_i); -- ORI
                            when "100" => value := a xor std_logic_vector(imm_i); -- XORI
                            when others => valid := false;
                        end case;
                    when "0000011" => -- LW
                        if funct3 = "010" then
                            addr := unsigned(a) + unsigned(imm_i);
                            if addr <= to_unsigned(MEM_BYTES - 4, 32) and addr(1 downto 0) = "00" then
                                value := word_at(memory, to_integer(addr));
                                write_rd := true;
                            else valid := false; end if;
                        else valid := false; end if;
                    when "0100011" => -- SW
                        if funct3 = "010" then
                            addr := unsigned(a) + unsigned(imm_s);
                            if addr <= to_unsigned(MEM_BYTES - 4, 32) and addr(1 downto 0) = "00" then
                                store_word := true;
                                value := b;
                            else valid := false; end if;
                        else valid := false; end if;
                    when "1100011" => -- BEQ / BNE
                        case funct3 is
                            when "000" => if a = b then next_pc := unsigned(signed(pc) + imm_b); end if;
                            when "001" => if a /= b then next_pc := unsigned(signed(pc) + imm_b); end if;
                            when others => valid := false;
                        end case;
                    when "1110011" => -- EBREAK: test program termination marker
                        if instr = x"00100073" then
                            stop <= '1';
                        else valid := false; end if;
                    when others => valid := false;
                end case;

                if not valid then
                    report "Unsupported/invalid instruction at PC=" & to_hstring(std_logic_vector(pc)) & " word=" & to_hstring(instr) severity error;
                    stop <= '1';
                else
                    if write_rd and rd /= 0 then registers(rd) <= value; end if;
                    if store_word then
                        memory(to_integer(addr))   <= b(7 downto 0);
                        memory(to_integer(addr)+1) <= b(15 downto 8);
                        memory(to_integer(addr)+2) <= b(23 downto 16);
                        memory(to_integer(addr)+3) <= b(31 downto 24);
                    end if;
                    last_result <= value;
                    if instr /= x"00100073" then pc <= next_pc; end if;
                    report "PROGRAM=" & PROGRAM_FILE & " PC=" & to_hstring(std_logic_vector(pc)) & " INST=" & to_hstring(instr) & " ASM=" & disassemble(instr) & " RESULT=" & to_hstring(value) severity note;
                end if;
            end if;
        end if;
    end process;
end architecture;
