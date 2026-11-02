library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- simple ALU implementation 
entity ALU is
    port (
	a, b  : in STD_LOGIC_VECTOR(31 downto 0); -- operands
	op    : in STD_LOGIC_VECTOR(2 downto 0); -- 3 bit opcode
	result: in STD_LOGIC_VECTOR(31 downto 0);
    );
end entity;

architecture RTL of ALU is
begin
    process(a, b, op)
    begin
        case op is
            when "000" => result <= std_logic_vector(unsigned(a) + unsigned(b));  -- ADD
            when "001" => result <= std_logic_vector(unsigned(a) - unsigned(b)); -- SUB
            when "010" => result <= a and b; -- bitwise AND
            when "011" => result <= a or b; -- bitwise OR
            when "100" => result <= a xor b; -- XOR
            when "101" => result <= std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b(4 downto 0)))));
            when "110" => result <= std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b(4 downto 0)))));
            when others => result <= (others => '0');
        end case;
    end process;
end architecture;
