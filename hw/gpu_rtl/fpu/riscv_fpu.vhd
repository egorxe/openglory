library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_4 is
	port(
		A : in  std_logic_vector(3 downto 0);
		Z : out std_logic_vector(1 downto 0);
		V : out std_logic
	);
end lzc_4;

architecture behavior of lzc_4 is

	signal A0 : std_logic := '0';
	signal A1 : std_logic := '0';
	signal A2 : std_logic := '0';
	signal A3 : std_logic := '0';

	signal S0 : std_logic;
	signal S1 : std_logic;
	signal S2 : std_logic;
	signal S3 : std_logic;
	signal S4 : std_logic;

begin

	A0 <= A(0);
	A1 <= A(1);
	A2 <= A(2);
	A3 <= A(3);

	S0 <= A3 or A2;
	S1 <= A1 or A0;
	S2 <= S1 or S0;
	S3 <= (not S0) and A1;
	S4 <= A3 or S3;

	V <= S2;
	Z(0)   <= S4;
	Z(1)   <= S0;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_8 is
	port(
		A : in  std_logic_vector(7 downto 0);
		Z : out std_logic_vector(2 downto 0);
		V : out std_logic
	);
end lzc_8;

architecture behavior of lzc_8 is

	signal Z0 : std_logic_vector(1 downto 0);
	signal Z1 : std_logic_vector(1 downto 0);

	signal V0 : std_logic;
	signal V1 : std_logic;

	signal S0 : std_logic;
	signal S1 : std_logic;
	signal S2 : std_logic;
	signal S3 : std_logic;
	signal S4 : std_logic;

begin

	lzc_4_comp_0 : lzc_4 port map(A => A(3 downto 0), Z => Z0, V => V0);
	lzc_4_comp_1 : lzc_4 port map(A => A(7 downto 4), Z => Z1, V => V1);

	S0 <= V1 or V0;
	S1 <= (not V1) and Z0(0);
	S2 <= Z1(0) or S1;
	S3 <= (not V1) and Z0(1);
	S4 <= Z1(1) or S3;

	V <= S0;
	Z(0)   <= S2;
	Z(1)   <= S4;
	Z(2)   <= V1;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_16 is
	port(
		A : in  std_logic_vector(15 downto 0);
		Z : out std_logic_vector(3 downto 0);
		V : out std_logic
	);
end lzc_16;

architecture behavior of lzc_16 is

	signal Z0 : std_logic_vector(2 downto 0);
	signal Z1 : std_logic_vector(2 downto 0);

	signal V0 : std_logic;
	signal V1 : std_logic;

	signal S0 : std_logic;
	signal S1 : std_logic;
	signal S2 : std_logic;
	signal S3 : std_logic;
	signal S4 : std_logic;
	signal S5 : std_logic;
	signal S6 : std_logic;

begin

	lzc_8_comp_0 : lzc_8 port map(A => A(7 downto 0), Z => Z0, V => V0);
	lzc_8_comp_1 : lzc_8 port map(A => A(15 downto 8), Z => Z1, V => V1);

	S0 <= V1 or V0;
	S1 <= (not V1) and Z0(0);
	S2 <= Z1(0) or S1;
	S3 <= (not V1) and Z0(1);
	S4 <= Z1(1) or S3;
	S5 <= (not V1) and Z0(2);
	S6 <= Z1(2) or S5;

	V <= S0;
	Z(0)   <= S2;
	Z(1)   <= S4;
	Z(2)   <= S6;
	Z(3)   <= V1;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_32 is
	port(
		A : in  std_logic_vector(31 downto 0);
		Z : out std_logic_vector(4 downto 0);
		V : out std_logic
	);
end lzc_32;

architecture behavior of lzc_32 is

	signal Z0 : std_logic_vector(3 downto 0);
	signal Z1 : std_logic_vector(3 downto 0);

	signal V0 : std_logic;
	signal V1 : std_logic;

	signal S0 : std_logic;
	signal S1 : std_logic;
	signal S2 : std_logic;
	signal S3 : std_logic;
	signal S4 : std_logic;
	signal S5 : std_logic;
	signal S6 : std_logic;
	signal S7 : std_logic;
	signal S8 : std_logic;

begin

	lzc_16_comp_0 : lzc_16 port map(A => A(15 downto 0), Z => Z0, V => V0);
	lzc_16_comp_1 : lzc_16 port map(A => A(31 downto 16), Z => Z1, V => V1);

	S0 <= V1 or V0;
	S1 <= (not V1) and Z0(0);
	S2 <= Z1(0) or S1;
	S3 <= (not V1) and Z0(1);
	S4 <= Z1(1) or S3;
	S5 <= (not V1) and Z0(2);
	S6 <= Z1(2) or S5;
	S7 <= (not V1) and Z0(3);
	S8 <= Z1(3) or S7;

	V <= S0;
	Z(0)   <= S2;
	Z(1)   <= S4;
	Z(2)   <= S6;
	Z(3)   <= S8;
	Z(4)   <= V1;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_64 is
	port(
		A : in  std_logic_vector(63 downto 0);
		Z : out std_logic_vector(5 downto 0);
		V : out std_logic
	);
end lzc_64;

architecture behavior of lzc_64 is

	signal Z0 : std_logic_vector(4 downto 0);
	signal Z1 : std_logic_vector(4 downto 0);

	signal V0 : std_logic;
	signal V1 : std_logic;

	signal S0  : std_logic;
	signal S1  : std_logic;
	signal S2  : std_logic;
	signal S3  : std_logic;
	signal S4  : std_logic;
	signal S5  : std_logic;
	signal S6  : std_logic;
	signal S7  : std_logic;
	signal S8  : std_logic;
	signal S9  : std_logic;
	signal S10 : std_logic;

begin

	lzc_32_comp_0 : lzc_32 port map(A => A(31 downto 0), Z => Z0, V => V0);
	lzc_32_comp_1 : lzc_32 port map(A => A(63 downto 32), Z => Z1, V => V1);

	S0  <= V1 or V0;
	S1  <= (not V1) and Z0(0);
	S2  <= Z1(0) or S1;
	S3  <= (not V1) and Z0(1);
	S4  <= Z1(1) or S3;
	S5  <= (not V1) and Z0(2);
	S6  <= Z1(2) or S5;
	S7  <= (not V1) and Z0(3);
	S8  <= Z1(3) or S7;
	S9  <= (not V1) and Z0(4);
	S10 <= Z1(4) or S9;

	V <= S0;
	Z(0)   <= S2;
	Z(1)   <= S4;
	Z(2)   <= S6;
	Z(3)   <= S8;
	Z(4)   <= S10;
	Z(5)   <= V1;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lzc_lib.all;

entity lzc_128 is
	port(
		A : in  std_logic_vector(127 downto 0);
		Z : out std_logic_vector(6 downto 0);
		V : out std_logic
	);
end lzc_128;

architecture behavior of lzc_128 is

	signal Z0 : std_logic_vector(5 downto 0);
	signal Z1 : std_logic_vector(5 downto 0);

	signal V0 : std_logic;
	signal V1 : std_logic;

	signal S0  : std_logic;
	signal S1  : std_logic;
	signal S2  : std_logic;
	signal S3  : std_logic;
	signal S4  : std_logic;
	signal S5  : std_logic;
	signal S6  : std_logic;
	signal S7  : std_logic;
	signal S8  : std_logic;
	signal S9  : std_logic;
	signal S10 : std_logic;
	signal S11 : std_logic;
	signal S12 : std_logic;

begin

	lzc_64_comp_0 : lzc_64 port map(A => A(63 downto 0), Z => Z0, V => V0);
	lzc_64_comp_1 : lzc_64 port map(A => A(127 downto 64), Z => Z1, V => V1);

	S0  <= V1 or V0;
	S1  <= (not V1) and Z0(0);
	S2  <= Z1(0) or S1;
	S3  <= (not V1) and Z0(1);
	S4  <= Z1(1) or S3;
	S5  <= (not V1) and Z0(2);
	S6  <= Z1(2) or S5;
	S7  <= (not V1) and Z0(3);
	S8  <= Z1(3) or S7;
	S9  <= (not V1) and Z0(4);
	S10 <= Z1(4) or S9;
	S11 <= (not V1) and Z0(5);
	S12 <= Z1(5) or S11;

	V <= S0;
	Z(0)   <= S2;
	Z(1)   <= S4;
	Z(2)   <= S6;
	Z(3)   <= S8;
	Z(4)   <= S10;
	Z(5)   <= S12;
	Z(6)   <= V1;

end behavior;

-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_func.all;

entity fp_ext is
	port(
		fp_ext_i : in  fp_ext_in_type;
		fp_ext_o : out fp_ext_out_type;
		lzc_o    : in  lzc_32_out_type;
		lzc_i    : out lzc_32_in_type
	);
end fp_ext;

architecture behavior of fp_ext is

begin

	process(fp_ext_i, lzc_o)
		variable data : std_logic_vector(31 downto 0);
		variable fmt  : std_logic_vector(1 downto 0);

		variable mantissa : std_logic_vector(31 downto 0);
		variable counter  : integer range 0 to 31;

		variable result : std_logic_vector(32 downto 0);
		variable class  : std_logic_vector(9 downto 0);

		variable mantissa_zero : std_logic;
		variable exponent_zero : std_logic;
		variable exponent_ones : std_logic;

	begin
		data := fp_ext_i.data;
		fmt := fp_ext_i.fmt;

		mantissa := (others => '1');
		counter := 0;

		result := (others => '0');
		class := (others => '0');

		mantissa_zero := '0';
		exponent_zero := '0';
		exponent_ones := '0';

		if fmt = "00" then
			mantissa := '0' & data(22 downto 0) & X"FF";
			exponent_zero := nor_reduce(data(30 downto 23));
			exponent_ones := and_reduce(data(30 downto 23));
			mantissa_zero := nor_reduce(data(22 downto 0));
		end if;

		lzc_i.a         <= mantissa;
		counter := to_integer(unsigned(not lzc_o.c));

		if fmt = "00" then
			result(32) := data(31);
			if and_reduce(data(30 downto 23)) = '1' then
				result(31 downto 23) := (others => '1');
				result(22 downto 0) := data(22 downto 0);
			elsif or_reduce(data(30 downto 23)) = '1' then
				result(31 downto 23) := std_logic_vector(resize(unsigned(data(30 downto 23)), 9) + 128);
				result(22 downto 0) := data(22 downto 0);
			elsif counter < 24 then
				result(31 downto 23) := std_logic_vector(to_unsigned(129 - counter, 9));
				result(22 downto 0) := std_logic_vector(shift_left(unsigned(data(22 downto 0)),counter));
			end if;
		end if;

		if result(32) = '1' then
			if exponent_ones = '1' then
				if mantissa_zero = '1' then
					class(0) := '1';
				elsif result(22) = '0' then
					class(8) := '1';
				else
					class(9) := '1';
				end if;
			elsif exponent_zero = '1' then
				if mantissa_zero = '1' then
					class(3) := '1';
				else
					class(2) := '1';
				end if;
			else
				class(1) := '1';
			end if;
		else
			if exponent_ones = '1' then
				if mantissa_zero = '1' then
					class(7) := '1';
				elsif result(22) = '0' then
					class(8) := '1';
				else
					class(9) := '1';
				end if;
			elsif exponent_zero = '1' then
				if mantissa_zero = '1' then
					class(4) := '1';
				else
					class(5) := '1';
				end if;
			else
				class(6) := '1';
			end if;
		end if;

		fp_ext_o.result <= result;
		fp_ext_o.class <= class;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;

entity fp_cmp is
	port(
		fp_cmp_i : in  fp_cmp_in_type;
		fp_cmp_o : out fp_cmp_out_type
	);
end fp_cmp;

architecture behavior of fp_cmp is

begin

	process(fp_cmp_i)
		variable data1  : std_logic_vector(32 downto 0);
		variable data2  : std_logic_vector(32 downto 0);
		variable rm     : std_logic_vector(2 downto 0);
		variable class1 : std_logic_vector(9 downto 0);
		variable class2 : std_logic_vector(9 downto 0);

		variable cmp_lt : std_logic;
		variable cmp_le : std_logic;

		variable result : std_logic_vector(31 downto 0);
		variable flags  : std_logic_vector(4 downto 0);

	begin
		data1 := fp_cmp_i.data1;
		data2 := fp_cmp_i.data2;
		rm := fp_cmp_i.rm;
		class1 := fp_cmp_i.class1;
		class2 := fp_cmp_i.class2;

		cmp_lt := '0';
		cmp_le := '0';

		result := (others => '0');
		flags := (others => '0');

		if rm = "000" or rm = "001" or rm = "010" then
			cmp_lt := to_std_logic(unsigned(data1(31 downto 0)) < unsigned(data2(31 downto 0)));
			cmp_le := to_std_logic(unsigned(data1(31 downto 0)) <= unsigned(data2(31 downto 0)));
		end if;

		--FEQ
		if rm = "010" then

			if (class1(8) or class2(8)) = '1' then
				flags(4) := '1';
			elsif (class1(9) or class2(9)) = '1' then
				flags(4) := '0';
			elsif ((class1(3) or class1(4)) and (class2(3) or class2(4))) = '1' then
				result(0) := '1';
			elsif data1 = data2 then
				result(0) := '1';
			end if;

		--FLT
		elsif rm = "001" then

			if (class1(8) or class2(8) or class1(9) or class2(9)) = '1' then
				flags(4) := '1';
			elsif ((class1(3) or class1(4)) and (class2(3) or class2(4))) = '1' then
				result(0) := '0';
			elsif (data1(32) xor data2(32)) = '1' then
				result(0) := data1(32);
			else
				if data1(32) = '1' then
					result(0) := not cmp_le;
				else
					result(0) := cmp_lt;
				end if;
			end if;

		--FLE
		elsif rm = "000" then

			if (class1(8) or class2(8) or class1(9) or class2(9)) = '1' then
				flags(4) := '1';
			elsif ((class1(3) or class1(4)) and (class2(3) or class2(4))) = '1' then
				result(0) := '1';
			elsif (data1(32) xor data2(32)) = '1' then
				result(0) := data1(32);
			else
				if data1(32) = '1' then
					result(0) := not cmp_lt;
				else
					result(0) := cmp_le;
				end if;
			end if;

		end if;

		fp_cmp_o.result <= result;
		fp_cmp_o.flags <= flags;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;

entity fp_max is
	port(
		fp_max_i : in  fp_max_in_type;
		fp_max_o : out fp_max_out_type
	);
end fp_max;

architecture behavior of fp_max is

begin

	process(fp_max_i)
		variable data1  : std_logic_vector(31 downto 0);
		variable data2  : std_logic_vector(31 downto 0);
		variable ext1   : std_logic_vector(32 downto 0);
		variable ext2   : std_logic_vector(32 downto 0);
		variable fmt    : std_logic_vector(1 downto 0);
		variable rm     : std_logic_vector(2 downto 0);
		variable class1 : std_logic_vector(9 downto 0);
		variable class2 : std_logic_vector(9 downto 0);

		variable nan  : std_logic_vector(31 downto 0);
		variable comp : std_logic;

		variable result : std_logic_vector(31 downto 0);
		variable flags  : std_logic_vector(4 downto 0);

	begin
		data1 := fp_max_i.data1;
		data2 := fp_max_i.data2;
		ext1 := fp_max_i.ext1;
		ext2 := fp_max_i.ext2;
		fmt := fp_max_i.fmt;
		rm := fp_max_i.rm;
		class1 := fp_max_i.class1;
		class2 := fp_max_i.class2;

		nan := X"7FC00000";
		comp := '0';

		result := (others => '0');
		flags := (others => '0');

		if rm = "000" or rm = "001" then
			comp := to_std_logic(unsigned(ext1(31 downto 0)) > unsigned(ext2(31 downto 0)));
		end if;

		if rm = "000" then

			if (class1(8) and class2(8)) = '1' then
				result := nan;
				flags(4) := '1';
			elsif class1(8) = '1' then
				result := data2;
				flags(4) := '1';
			elsif class2(8) = '1' then
				result := data1;
				flags(4) := '1';
			elsif (class1(9) and class2(9)) = '1' then
				result := nan;
			elsif class1(9) = '1' then
				result := data2;
			elsif class2(9) = '1' then
				result := data1;
			elsif (ext1(32) xor ext2(32)) = '1' then
				if ext1(32) = '1' then
					result := data1;
				else
					result := data2;
				end if;
			else
				if ext1(32) = '1' then
					if comp = '1' then
						result := data1;
					else
						result := data2;
					end if;
				else
					if comp = '1' then
						result := data2;
					else
						result := data1;
					end if;
				end if;
			end if;

		elsif rm = "001" then

			if (class1(8) and class2(8)) = '1' then
				result := nan;
				flags(4) := '1';
			elsif class1(8) = '1' then
				result := data2;
				flags(4) := '1';
			elsif class2(8) = '1' then
				result := data1;
				flags(4) := '1';
			elsif (class1(9) and class2(9)) = '1' then
				result := nan;
			elsif class1(9) = '1' then
				result := data2;
			elsif class2(9) = '1' then
				result := data1;
			elsif (ext1(32) xor ext2(32)) = '1' then
				if ext1(32) = '1' then
					result := data2;
				else
					result := data1;
				end if;
			else
				if ext1(32) = '1' then
					if comp = '1' then
						result := data2;
					else
						result := data1;
					end if;
				else
					if comp = '1' then
						result := data1;
					else
						result := data2;
					end if;
				end if;
			end if;

		end if;

		fp_max_o.result <= result;
		fp_max_o.flags <= flags;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;

entity fp_sgnj is
	port(
		fp_sgnj_i : in  fp_sgnj_in_type;
		fp_sgnj_o : out fp_sgnj_out_type
	);
end fp_sgnj;

architecture behavior of fp_sgnj is

begin

	process(fp_sgnj_i)
		variable data1 : std_logic_vector(31 downto 0);
		variable data2 : std_logic_vector(31 downto 0);
		variable fmt   : std_logic_vector(1 downto 0);
		variable rm    : std_logic_vector(2 downto 0);

		variable result : std_logic_vector(31 downto 0);

	begin
		data1 := fp_sgnj_i.data1;
		data2 := fp_sgnj_i.data2;
		fmt := fp_sgnj_i.fmt;
		rm := fp_sgnj_i.rm;

		result := (others => '0');

		if fmt = "00" then

			result(30 downto 0) := data1(30 downto 0);
			if rm = "000" then
				result(31) := data2(31);
			elsif rm = "001" then
				result(31) := not data2(31);
			elsif rm = "010" then
				result(31) := data1(31) xor data2(31);
			end if;

		end if;

		fp_sgnj_o.result <= result;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_func.all;

entity fp_cvt is
	port(
		fp_cvt_f2i_i : in  fp_cvt_f2i_in_type;
		fp_cvt_f2i_o : out fp_cvt_f2i_out_type;
		fp_cvt_i2f_i : in  fp_cvt_i2f_in_type;
		fp_cvt_i2f_o : out fp_cvt_i2f_out_type;
		lzc_i        : out lzc_32_in_type;
		lzc_o        : in  lzc_32_out_type
	);
end fp_cvt;

architecture behavior of fp_cvt is

begin

	process(fp_cvt_f2i_i)
		variable data  : std_logic_vector(32 downto 0);
		variable op    : std_logic_vector(1 downto 0);
		variable rm    : std_logic_vector(2 downto 0);
		variable class : std_logic_vector(9 downto 0);

		variable result : std_logic_vector(31 downto 0);
		variable flags  : std_logic_vector(4 downto 0);

		variable snan : std_logic;
		variable qnan : std_logic;
		variable inf  : std_logic;
		variable zero : std_logic;

		variable sign_cvt      : std_logic;
		variable exponent_cvt  : integer range -4095 to 4095;
		variable mantissa_cvt  : std_logic_vector(58 downto 0);
		variable exponent_bias : natural range 0 to 127;

		variable mantissa_uint : std_logic_vector(32 downto 0);

		variable grs : std_logic_vector(2 downto 0);
		variable odd : std_logic;

		variable rnded : natural range 0 to 1;

		variable oor : std_logic;

		variable or_1 : std_logic;
		variable or_2 : std_logic;
		variable or_3 : std_logic;

		variable oor_32u : std_logic;
		variable oor_32s : std_logic;

	begin
		data := fp_cvt_f2i_i.data;
		op := fp_cvt_f2i_i.op.fcvt_op;
		rm := fp_cvt_f2i_i.rm;
		class := fp_cvt_f2i_i.class;

		flags := (others => '0');
		result := (others => '0');

		snan := class(8);
		qnan := class(9);
		inf := class(0) or class(7);
		zero := '0';

		if op = "00" then
			exponent_bias := 34;
		else
			exponent_bias := 35;
		end if;

		sign_cvt := data(32);
		exponent_cvt := to_integer(unsigned(data(31 downto 23))) - 252;
		mantissa_cvt := X"000000001" & data(22 downto 0);

		oor := '0';

		if exponent_cvt > exponent_bias then
			oor := '1';
		elsif exponent_cvt > 0 then
			mantissa_cvt := std_logic_vector(shift_left(unsigned(mantissa_cvt), exponent_cvt));
		end if;

		mantissa_uint := mantissa_cvt(58 downto 26);

		grs := mantissa_cvt(25 downto 24) & or_reduce(mantissa_cvt(23 downto 0));
		odd := mantissa_uint(0) or or_reduce(grs(1 downto 0));

		rnded := 0;

		case rm is
			when "000" =>               --rne--
				if (grs(2) and odd) = '1' then
					rnded := 1;
				end if;
			when "001" =>               --rtz--
				null;
			when "010" =>               --rdn--
				if (sign_cvt and flags(0)) = '1' then
					rnded := 1;
				end if;
			when "011" =>               --rup--
				if (not sign_cvt and flags(0)) = '1' then
					rnded := 1;
				end if;
			when "100" =>               --rmm--
				if flags(0) = '1' then
					rnded := 1;
				end if;
			when others =>
				null;
		end case;

		mantissa_uint := std_logic_vector(unsigned(mantissa_uint) + rnded);

		or_1 := mantissa_uint(32);
		or_2 := mantissa_uint(31);
		or_3 := or_reduce(mantissa_uint(30 downto 0));

		zero := or_1 or or_2 or or_3;

		oor_32u := or_1;
		oor_32s := or_1;

		if sign_cvt = '1' then
			if op = "00" then
				oor_32s := oor_32s or (or_2 and or_3);
			elsif op = "01" then
				oor := oor or zero;
			end if;
		else
			oor_32s := oor_32s or or_2;
		end if;

		oor_32u := to_std_logic(op = "01") and (oor_32u or oor or inf or snan or qnan);
		oor_32s := to_std_logic(op = "00") and (oor_32s or oor or inf or snan or qnan);

		if sign_cvt = '1' then
			mantissa_uint := std_logic_vector(-signed(mantissa_uint));
		end if;

		if op = "00" then
			result := mantissa_uint(31 downto 0);
			if oor_32s = '1' then
				result := X"80000000";
				flags := "10000";
			end if;
		elsif op = "01" then
			result := mantissa_uint(31 downto 0);
			if oor_32u = '1' then
				result := X"FFFFFFFF";
				flags := "10000";
			end if;
		end if;

		fp_cvt_f2i_o.result <= result;
		fp_cvt_f2i_o.flags <= flags;

	end process;

	process(fp_cvt_i2f_i, lzc_o)
		variable data : std_logic_vector(31 downto 0);
		variable op   : std_logic_vector(1 downto 0);
		variable fmt  : std_logic_vector(1 downto 0);
		variable rm   : std_logic_vector(2 downto 0);

		variable snan : std_logic;
		variable qnan : std_logic;
		variable dbz  : std_logic;
		variable inf  : std_logic;
		variable zero : std_logic;

		variable sign_uint     : std_logic;
		variable exponent_uint : natural range 0 to 31;
		variable mantissa_uint : std_logic_vector(31 downto 0);
		variable counter_uint  : natural range 0 to 31;
		variable exponent_bias : natural range 0 to 127;

		variable sign_rnd     : std_logic;
		variable exponent_rnd : integer range -1023 to 1023;
		variable mantissa_rnd : std_logic_vector(24 downto 0);

		variable grs : std_logic_vector(2 downto 0);

	begin
		data := fp_cvt_i2f_i.data;
		op := fp_cvt_i2f_i.op.fcvt_op;
		fmt := fp_cvt_i2f_i.fmt;
		rm := fp_cvt_i2f_i.rm;

		snan := '0';
		qnan := '0';
		dbz := '0';
		inf := '0';
		zero := '0';

		exponent_bias := 127;

		sign_uint := '0';
		if op = "00" then
			sign_uint := data(31);
		end if;

		if sign_uint = '1' then
			data := std_logic_vector(-signed(data));
		end if;

		mantissa_uint := X"FFFFFFFF";
		exponent_uint := 0;
		if op(1) = '0' then
			mantissa_uint := data(31 downto 0);
			exponent_uint := 31;
		end if;

		zero := nor_reduce(mantissa_uint);

		lzc_i.a <= mantissa_uint;
		counter_uint := to_integer(unsigned(not lzc_o.c));

		mantissa_uint := std_logic_vector(shift_left(unsigned(mantissa_uint),counter_uint));

		sign_rnd := sign_uint;
		exponent_rnd := exponent_uint + exponent_bias - counter_uint;

		mantissa_rnd := "0" & mantissa_uint(31 downto 8);
		grs := mantissa_uint(7 downto 6) & or_reduce(mantissa_uint(5 downto 0));

		fp_cvt_i2f_o.fp_rnd.sig <= sign_rnd;
		fp_cvt_i2f_o.fp_rnd.expo <= exponent_rnd;
		fp_cvt_i2f_o.fp_rnd.mant <= mantissa_rnd;
		fp_cvt_i2f_o.fp_rnd.rema <= "00";
		fp_cvt_i2f_o.fp_rnd.fmt <= fmt;
		fp_cvt_i2f_o.fp_rnd.rm <= rm;
		fp_cvt_i2f_o.fp_rnd.grs <= grs;
		fp_cvt_i2f_o.fp_rnd.snan <= snan;
		fp_cvt_i2f_o.fp_rnd.qnan <= qnan;
		fp_cvt_i2f_o.fp_rnd.dbz <= dbz;
		fp_cvt_i2f_o.fp_rnd.inf <= inf;
		fp_cvt_i2f_o.fp_rnd.zero <= zero;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_func.all;

entity fp_rnd is
	port(
		fp_rnd_i : in  fp_rnd_in_type;
		fp_rnd_o : out fp_rnd_out_type
	);
end fp_rnd;

architecture behavior of fp_rnd is

begin

	process(fp_rnd_i)
		variable sig  : std_logic;
		variable expo : integer range -1023 to 1023;
		variable mant : std_logic_vector(24 downto 0);
		variable rema : std_logic_vector(1 downto 0);
		variable fmt  : std_logic_vector(1 downto 0);
		variable rm   : std_logic_vector(2 downto 0);
		variable grs  : std_logic_vector(2 downto 0);
		variable snan : std_logic;
		variable qnan : std_logic;
		variable dbz  : std_logic;
		variable inf  : std_logic;
		variable zero : std_logic;

		variable odd : std_logic;

		variable rnded : natural range 0 to 1;

		variable result : std_logic_vector(31 downto 0);
		variable flags  : std_logic_vector(4 downto 0);

	begin
		sig := fp_rnd_i.sig;
		expo := fp_rnd_i.expo;
		mant := fp_rnd_i.mant;
		rema := fp_rnd_i.rema;
		fmt := fp_rnd_i.fmt;
		rm := fp_rnd_i.rm;
		grs := fp_rnd_i.grs;
		snan := fp_rnd_i.snan;
		qnan := fp_rnd_i.qnan;
		dbz := fp_rnd_i.dbz;
		inf := fp_rnd_i.inf;
		zero := fp_rnd_i.zero;

		result := X"00000000";
		flags := "00000";

		odd := mant(0) or or_reduce(grs(1 downto 0)) or to_std_logic(rema = "01");
		flags(0) := to_std_logic(rema /= "00") or or_reduce(grs);

		rnded := 0;
		case rm is
			when "000" =>               --rne--
				if (grs(2) and odd) = '1' then
					rnded := 1;
				end if;
			when "001" =>               --rtz--
				null;
			when "010" =>               --rdn--
				if (sig and flags(0)) = '1' then
					rnded := 1;
				end if;
			when "011" =>               --rup--
				if (not sig and flags(0)) = '1' then
					rnded := 1;
				end if;
			when "100" =>               --rmm--
				if flags(0) = '1' then
					rnded := 1;
				end if;
			when others =>
				null;
		end case;

		if expo = 0 then
			flags(1) := flags(0);
		end if;

		mant := std_logic_vector(unsigned(mant) + rnded);

		rnded := 0;
		if fmt = "00" then
			if mant(24) = '1' then
				rnded := 1;
			elsif mant(23) = '1' then
				if expo = 0 then
					expo := 1;
					if expo = 1 then
						flags(1) := not grs(1);
					end if;
				end if;
			end if;
		end if;

		expo := expo + rnded;
		mant := std_logic_vector(shift_right(unsigned(mant),rnded));

		if snan = '1' then
			flags := "10000";
		elsif qnan = '1' then
			flags := "00000";
		elsif dbz = '1' then
			flags := "01000";
		elsif inf = '1' then
			flags := "00000";
		elsif zero = '1' then
			flags := "00000";
		end if;

		if fmt = "00" then
			if (snan or qnan) = '1' then
				result := "01" & X"FF" & "00" & X"00000";
			elsif (dbz or inf) = '1' then
				result := sig & X"FF" & "000" & X"00000";
			elsif zero = '1' then
				result := sig & X"00" & "000" & X"00000";
			elsif expo = 0 then
				result := sig & X"00" & mant(22 downto 0);
			elsif expo > 254 then
				flags := "00101";
				result := sig & X"FF" & "000" & X"00000";
			else
				result := sig & std_logic_vector(to_unsigned(expo, 8)) & mant(22 downto 0);
			end if;
		end if;

		fp_rnd_o.result <= result;
		fp_rnd_o.flags <= flags;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_func.all;

entity fp_fma is
	port(
		reset    : in  std_logic;
		clock    : in  std_logic;
		fp_fma_i : in  fp_fma_in_type;
		fp_fma_o : out fp_fma_out_type;
		lzc_o    : in  lzc_128_out_type;
		lzc_i    : out lzc_128_in_type
	);
end fp_fma;

architecture behavior of fp_fma is

	signal r_0 : fp_fma_reg_type_0 := init_fp_fma_reg_0;
	signal r_1 : fp_fma_reg_type_1 := init_fp_fma_reg_1;
	signal r_2 : fp_fma_reg_type_2 := init_fp_fma_reg_2;

	signal rin_0 : fp_fma_reg_type_0 := init_fp_fma_reg_0;
	signal rin_1 : fp_fma_reg_type_1 := init_fp_fma_reg_1;
	signal rin_2 : fp_fma_reg_type_2 := init_fp_fma_reg_2;

begin

	process(fp_fma_i)
		variable a            : std_logic_vector(32 downto 0);
		variable b            : std_logic_vector(32 downto 0);
		variable c            : std_logic_vector(32 downto 0);
		variable class_a      : std_logic_vector(9 downto 0);
		variable class_b      : std_logic_vector(9 downto 0);
		variable class_c      : std_logic_vector(9 downto 0);
		variable fmt          : std_logic_vector(1 downto 0);
		variable rm           : std_logic_vector(2 downto 0);
		variable snan         : std_logic;
		variable qnan         : std_logic;
		variable dbz          : std_logic;
		variable inf          : std_logic;
		variable zero         : std_logic;
		variable neg          : std_logic;
		variable sign_a       : std_logic;
		
		variable mantissa_a   : std_logic_vector(23 downto 0);
		variable sign_b       : std_logic;
		variable mantissa_b   : std_logic_vector(23 downto 0);
		variable sign_c       : std_logic;
		variable mantissa_c   : std_logic_vector(23 downto 0);
		
		variable exponent_a   : std_logic_vector(8 downto 0);
        variable exponent_b   : std_logic_vector(8 downto 0);
        variable exponent_c   : std_logic_vector(8 downto 0);
		
		variable ready        : std_logic;

	begin
		a := fp_fma_i.data1;
		b := fp_fma_i.data2;
		c := fp_fma_i.data3;
		class_a := fp_fma_i.class1;
		class_b := fp_fma_i.class2;
		class_c := fp_fma_i.class3;
		fmt := fp_fma_i.fmt;
		rm := fp_fma_i.rm;
		snan := '0';
		qnan := '0';
		dbz := '0';
		inf := '0';
		zero := '0';
		neg := fp_fma_i.op.fnmsub or fp_fma_i.op.fnmadd;
		ready := fp_fma_i.op.fmadd or fp_fma_i.op.fmsub or fp_fma_i.op.fnmsub or fp_fma_i.op.fnmadd or fp_fma_i.op.fadd or fp_fma_i.op.fsub or fp_fma_i.op.fmul;

		if (fp_fma_i.op.fadd or fp_fma_i.op.fsub) = '1' then
			c := b;
			class_c := class_b;
			b := (30 downto 23 => '1', others => '0'); -- +1.0
			class_b := (6 => '1', others => '0');
		end if;

		if (fp_fma_i.op.fmsub or fp_fma_i.op.fnmsub or fp_fma_i.op.fsub) = '1' then
			c(32) := not c(32);
		end if;

		if fp_fma_i.op.fmul = '1' then
			c := (32 => a(32) xor b(32), others => '0');
			class_c := (others => '0');
		end if;

		sign_a := a(32);
		exponent_a := a(31 downto 23);
		mantissa_a := or_reduce(exponent_a) & a(22 downto 0);

		sign_b := b(32);
		exponent_b := b(31 downto 23);
		mantissa_b := or_reduce(exponent_b) & b(22 downto 0);

		sign_c := c(32);
		exponent_c := c(31 downto 23);
		mantissa_c := or_reduce(exponent_c) & c(22 downto 0);

		if (class_a(8) or class_b(8) or class_c(8)) = '1' then
			snan := '1';
		elsif (((class_a(3) or class_a(4)) and (class_b(0) or class_b(7))) or ((class_b(3) or class_b(4)) and (class_a(0) or class_a(7)))) = '1' then
			snan := '1';
		elsif (class_a(9) or class_b(9) or class_c(9)) = '1' then
			qnan := '1';
		elsif (((class_a(0) or class_a(7)) or (class_b(0) or class_b(7))) and ((class_c(0) or class_c(7)) and to_std_logic((a(32) xor b(32)) /= c(32)))) = '1' then
			snan := '1';
		elsif ((class_a(0) or class_a(7)) or (class_b(0) or class_b(7)) or (class_c(0) or class_c(7))) = '1' then
			inf := '1';
		end if;

		rin_0.fmt        <= fmt;
		rin_0.rm         <= rm;
        
		rin_0.snan       <= snan;
		rin_0.qnan       <= qnan;
		rin_0.inf        <= inf;
		rin_0.neg        <= neg;
        
        rin_0.mantissa_a <= mantissa_a;
		rin_0.mantissa_b <= mantissa_b;
		rin_0.mantissa_c <= mantissa_c;
        
        rin_0.exponent_mul <= signed("00" & exponent_a) + signed("00" & exponent_b) - 255;
        rin_0.exponent_a <= exponent_a;
		rin_0.exponent_b <= exponent_b;
		rin_0.exponent_c <= exponent_c;
        
        rin_0.sign_mul  <= sign_a xor sign_b;
        rin_0.sign_add  <= sign_c;
        
        rin_0.ready     <= ready;
        
    end process;
    
    process(r_0, fp_fma_i)
        variable exponent_add : signed(10 downto 0);
        variable exponent_mul : signed(10 downto 0);
        
        variable mantissa_mul : std_logic_vector(76 downto 0);
        variable mantissa_add : std_logic_vector(76 downto 0);
        
        variable exponent_dif : signed(10 downto 0);
		variable counter_dif  : integer range 0 to 63;
        
        variable exponent_neg : std_logic;
        
        variable mantissa_l   : std_logic_vector(76 downto 0);
		variable mantissa_r   : std_logic_vector(76 downto 0);
        
        --
        variable mantissa_mac : std_logic_vector(76 downto 0);
        variable not_mul      : integer range 0 to 1;
        variable not_add      : integer range 0 to 1;
        variable exponent_mac : signed(10 downto 0);
        variable sign_add     : std_logic;
        variable sign_mul     : std_logic;
    begin
    
        sign_mul := r_0.sign_mul;
        sign_add := r_0.sign_add;
    
        exponent_add := signed("00" & r_0.exponent_c);
        exponent_mul := r_0.exponent_mul;
    
		if and_reduce(r_0.exponent_c) = '1' then
			exponent_add := "001" & X"FF";
		end if;
		if (and_reduce(r_0.exponent_a) or and_reduce(r_0.exponent_b)) = '1' then
			exponent_mul := "001" & X"FF";
		end if;

		mantissa_add := "000" & r_0.mantissa_c & "00" & X"000000000000";
		mantissa_mul := "00" & std_logic_vector(unsigned(r_0.mantissa_a) * unsigned(r_0.mantissa_b)) & "000" & X"000000";

		exponent_dif := exponent_mul - exponent_add;
		counter_dif := 0;

		exponent_neg := exponent_dif(10);

		if exponent_neg = '1' then
			counter_dif := 27;
			if exponent_dif > -27 then
				counter_dif := -to_integer(exponent_dif);
			end if;
			mantissa_l := mantissa_add;
			mantissa_r := mantissa_mul;
		else
			counter_dif := 50;
			if exponent_dif < 50 then
				counter_dif := to_integer(exponent_dif);
			end if;
			mantissa_l := mantissa_mul;
			mantissa_r := mantissa_add;
		end if;

		mantissa_r := std_logic_vector(shift_right(unsigned(mantissa_r),counter_dif));

		if exponent_neg = '1' then
			mantissa_add := mantissa_l;
			mantissa_mul := mantissa_r;
		else
			mantissa_add := mantissa_r;
			mantissa_mul := mantissa_l;
		end if;
        
        -----------
        if exponent_neg = '1' then
			exponent_mac := exponent_add;
		else
			exponent_mac := exponent_mul;
		end if;

		if sign_add = '1' then
			mantissa_add := not mantissa_add;
			not_add := 1;
		else
			not_add := 0;
		end if;
		if sign_mul = '1' then
			mantissa_mul := not mantissa_mul;
			not_mul := 1;
		else
			not_mul := 0;
		end if;

		mantissa_mac := std_logic_vector(signed(mantissa_add) + signed(mantissa_mul) + not_add + not_mul);
        
        rin_1.mantissa_mac <= mantissa_mac;
        rin_1.exponent_mac <= exponent_mac;
        -------------

		rin_1.fmt <= r_0.fmt;
		rin_1.rm <= r_0.rm;
		rin_1.snan <= r_0.snan;
		rin_1.qnan <= r_0.qnan;
		rin_1.dbz <= '0';--dbz;
		rin_1.inf <= r_0.inf;
		rin_1.zero <= '0';--zero;
		rin_1.neg <= r_0.neg;
		rin_1.sign_mul <= sign_mul;
		--rin_1.exponent_mul <= exponent_mul;
		--rin_1.mantissa_mul <= mantissa_mul;
		rin_1.sign_add <= sign_add;
		--rin_1.exponent_add <= exponent_add;
		--rin_1.mantissa_add <= mantissa_add;
		--rin_1.exponent_neg <= exponent_neg;
		rin_1.ready <= r_0.ready;

	end process;

	process(r_1,lzc_o)
		variable fmt          : std_logic_vector(1 downto 0);
		variable rm           : std_logic_vector(2 downto 0);
		variable snan         : std_logic;
		variable qnan         : std_logic;
		variable dbz          : std_logic;
		variable inf          : std_logic;
		variable zero         : std_logic;
		variable neg          : std_logic;
		
		variable sign_add     : std_logic;
        variable sign_mul     : std_logic;
		--variable exponent_mul : signed(10 downto 0);
		--variable mantissa_mul : std_logic_vector(76 downto 0);
		
		
		--variable exponent_add : signed(10 downto 0);
		--variable mantissa_add : std_logic_vector(76 downto 0);
		--variable exponent_neg : std_logic;
		variable sign_mac     : std_logic;
		variable exponent_mac : signed(10 downto 0);
		variable mantissa_mac : std_logic_vector(76 downto 0);
		variable mantissa_lzc : std_logic_vector(127 downto 0);
		variable counter_mac  : integer range 0 to 127;
		variable counter_sub  : integer range 0 to 31;
		variable bias         : integer range 0 to 255;
		variable sign_rnd     : std_logic;
		variable exponent_rnd : integer range -1023 to 1023;
		variable mantissa_rnd : std_logic_vector(24 downto 0);
		variable grs          : std_logic_vector(2 downto 0);
		variable ready        : std_logic;

	begin
		fmt := r_1.fmt;
		rm := r_1.rm;
		snan := r_1.snan;
		qnan := r_1.qnan;
		dbz := r_1.dbz;
		inf := r_1.inf;
		zero := r_1.zero;
		neg := r_1.neg;
		sign_mul := r_1.sign_mul;
		--exponent_mul := r_1.exponent_mul;
		--mantissa_mul := r_1.mantissa_mul;
		sign_add := r_1.sign_add;
		--exponent_add := r_1.exponent_add;
		--mantissa_add := r_1.mantissa_add;
		--exponent_neg := r_1.exponent_neg;
		ready := r_1.ready;

		mantissa_mac := r_1.mantissa_mac;
		exponent_mac := r_1.exponent_mac;
        
		sign_mac := mantissa_mac(76);

		zero := nor_reduce(mantissa_mac);

		if zero = '1' then
			sign_mac := sign_add and sign_mul;
		elsif sign_mac = '1' then
			mantissa_mac := std_logic_vector(-signed(mantissa_mac));
		end if;

		bias := 126;

		mantissa_lzc := mantissa_mac(75 downto 0) & X"FFFFFFFFFFFFF";

		lzc_i.a <= mantissa_lzc;
		counter_mac := to_integer(unsigned(not (lzc_o.c)));
		mantissa_mac := std_logic_vector(shift_left(unsigned(mantissa_mac),counter_mac));

		sign_rnd := sign_mac xor neg;
		exponent_rnd := to_integer(exponent_mac) - bias - counter_mac;

		counter_sub := 0;
		if exponent_rnd <= 0 then
			counter_sub := 31;
			if exponent_rnd > -31 then
				counter_sub := 1 - exponent_rnd;
			end if;
			exponent_rnd := 0;
		end if;

		mantissa_mac := std_logic_vector(shift_right(unsigned(mantissa_mac),counter_sub));

		mantissa_rnd := "0" & mantissa_mac(75 downto 52);
		grs := mantissa_mac(51 downto 50) & or_reduce(mantissa_mac(49 downto 0));

		rin_2.sign_rnd <= sign_rnd;
		rin_2.exponent_rnd <= exponent_rnd;
		rin_2.mantissa_rnd <= mantissa_rnd;
		rin_2.fmt <= fmt;
		rin_2.rm <= rm;
		rin_2.grs <= grs;
		rin_2.snan <= snan;
		rin_2.qnan <= qnan;
		rin_2.dbz <= dbz;
		rin_2.inf <= inf;
		rin_2.zero <= zero;
		rin_2.ready <= ready;

	end process;

	process(r_2)
	begin
		fp_fma_o.fp_rnd.sig <= r_2.sign_rnd;
		fp_fma_o.fp_rnd.expo <= r_2.exponent_rnd;
		fp_fma_o.fp_rnd.mant <= r_2.mantissa_rnd;
		fp_fma_o.fp_rnd.rema <= "00";
		fp_fma_o.fp_rnd.fmt <= r_2.fmt;
		fp_fma_o.fp_rnd.rm <= r_2.rm;
		fp_fma_o.fp_rnd.grs <= r_2.grs;
		fp_fma_o.fp_rnd.snan <= r_2.snan;
		fp_fma_o.fp_rnd.qnan <= r_2.qnan;
		fp_fma_o.fp_rnd.dbz <= r_2.dbz;
		fp_fma_o.fp_rnd.inf <= r_2.inf;
		fp_fma_o.fp_rnd.zero <= r_2.zero;
		fp_fma_o.ready <= r_2.ready;

	end process;

	process(clock)
	begin
		if rising_edge(clock) then

			if reset = '0' then

				r_0 <= init_fp_fma_reg_0;
				r_1 <= init_fp_fma_reg_1;
				r_2 <= init_fp_fma_reg_2;

			else

				r_0 <= rin_0;
				r_1 <= rin_1;
				r_2 <= rin_2;

			end if;

		end if;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fp_wire.all;

entity fp_mac is
	port(
		fp_mac_i : in  fp_mac_in_type;
		fp_mac_o : out fp_mac_out_type
	);
end fp_mac;

architecture behavior of fp_mac is

	signal add : signed(51 downto 0);
	signal mul : signed(53 downto 0);
	signal mac : signed(51 downto 0);
	signal res : signed(51 downto 0);

begin

	add <= fp_mac_i.a & "0" & X"000000";
	mul <= fp_mac_i.b * fp_mac_i.c;
	mac <= mul(51 downto 0) when fp_mac_i.op = '0' else -mul(51 downto 0);
	res <= add + mac;
	fp_mac_o.d <= res;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_func.all;

entity fp_fdiv is
	generic(
		PERFORMANCE : integer := 1
	);
	port(
		reset     : in  std_logic;
		clock     : in  std_logic;
		fp_fdiv_i : in  fp_fdiv_in_type;
		fp_fdiv_o : out fp_fdiv_out_type;
		fp_mac_i  : out fp_mac_in_type;
		fp_mac_o  : in  fp_mac_out_type
	);
end fp_fdiv;

architecture behavior of fp_fdiv is

	signal r   : fp_fdiv_functional_reg_type := init_fp_fdiv_functional_reg;
	signal rin : fp_fdiv_functional_reg_type := init_fp_fdiv_functional_reg;

	signal r_fix   : fp_fdiv_fixed_reg_type := init_fp_fdiv_fixed_reg;
	signal rin_fix : fp_fdiv_fixed_reg_type := init_fp_fdiv_fixed_reg;

	type lut_type is array (0 to 127) of signed(7 downto 0);
	type lut_root_type is array (0 to 95) of signed(7 downto 0);

	signal reciprocal_lut : lut_type := (
		"00000000", "11111110", "11111100", "11111010", "11111000", "11110110", "11110100", "11110010",
		"11110000", "11101111", "11101101", "11101011", "11101010", "11101000", "11100110", "11100101",
		"11100011", "11100001", "11100000", "11011110", "11011101", "11011011", "11011010", "11011001",
		"11010111", "11010110", "11010100", "11010011", "11010010", "11010000", "11001111", "11001110",
		"11001100", "11001011", "11001010", "11001001", "11000111", "11000110", "11000101", "11000100",
		"11000011", "11000001", "11000000", "10111111", "10111110", "10111101", "10111100", "10111011",
		"10111010", "10111001", "10111000", "10110111", "10110110", "10110101", "10110100", "10110011",
		"10110010", "10110001", "10110000", "10101111", "10101110", "10101101", "10101100", "10101011",
		"10101010", "10101001", "10101000", "10101000", "10100111", "10100110", "10100101", "10100100",
		"10100011", "10100011", "10100010", "10100001", "10100000", "10011111", "10011111", "10011110",
		"10011101", "10011100", "10011100", "10011011", "10011010", "10011001", "10011001", "10011000",
		"10010111", "10010111", "10010110", "10010101", "10010100", "10010100", "10010011", "10010010",
		"10010010", "10010001", "10010000", "10010000", "10001111", "10001111", "10001110", "10001101",
		"10001101", "10001100", "10001100", "10001011", "10001010", "10001010", "10001001", "10001001",
		"10001000", "10000111", "10000111", "10000110", "10000110", "10000101", "10000101", "10000100",
		"10000100", "10000011", "10000011", "10000010", "10000010", "10000001", "10000001", "10000000");

	signal reciprocal_root_lut : lut_root_type := (
		"10110101", "10110010", "10101111", "10101101", "10101010", "10101000", "10100110", "10100011",
		"10100001", "10011111", "10011110", "10011100", "10011010", "10011000", "10010110", "10010101",
		"10010011", "10010010", "10010000", "10001111", "10001110", "10001100", "10001011", "10001010",
		"10001000", "10000111", "10000110", "10000101", "10000100", "10000011", "10000010", "10000001",
		"10000000", "01111111", "01111110", "01111101", "01111100", "01111011", "01111010", "01111001",
		"01111000", "01110111", "01110111", "01110110", "01110101", "01110100", "01110011", "01110011",
		"01110010", "01110001", "01110001", "01110000", "01101111", "01101111", "01101110", "01101101",
		"01101101", "01101100", "01101011", "01101011", "01101010", "01101010", "01101001", "01101001",
		"01101000", "01100111", "01100111", "01100110", "01100110", "01100101", "01100101", "01100100",
		"01100100", "01100011", "01100011", "01100010", "01100010", "01100010", "01100001", "01100001",
		"01100000", "01100000", "01011111", "01011111", "01011111", "01011110", "01011110", "01011101",
		"01011101", "01011101", "01011100", "01011100", "01011011", "01011011", "01011011", "01011010");

begin

	FUNCTIONAL : if PERFORMANCE = 1 generate

		process(r, fp_fdiv_i, fp_mac_o, reciprocal_lut, reciprocal_root_lut)
			variable v : fp_fdiv_functional_reg_type;

		begin
			v := r;

			case r.state is
				when F0 =>
					if fp_fdiv_i.op.fdiv = '1' then
						v.state := F1;
					elsif fp_fdiv_i.op.fsqrt = '1' then
						v.state := F2;
					end if;
					v.istate := 0;
					v.ready := '0';
				when F1 =>
					if v.istate = 8 then
						v.state := F3;
					end if;
					v.istate := v.istate + 1;
					v.ready := '0';
				when F2 =>
					if v.istate = 10 then
						v.state := F3;
					end if;
					v.istate := v.istate + 1;
					v.ready := '0';
				when F3 =>
					v.state := F0;
					v.ready := '1';
				when others =>
					v.state := F0;
					v.ready := '1';
			end case;

			case r.state is
				when F0 =>

					v.a := fp_fdiv_i.data1;
					v.b := fp_fdiv_i.data2;
					v.class_a := fp_fdiv_i.class1;
					v.class_b := fp_fdiv_i.class2;
					v.fmt := fp_fdiv_i.fmt;
					v.rm := fp_fdiv_i.rm;
					v.snan := '0';
					v.qnan := '0';
					v.dbz := '0';
					v.inf := '0';
					v.zero := '0';

					if fp_fdiv_i.op.fsqrt = '1' then
						v.b := (30 downto 23 => '1', others => '0');
						v.class_b := (others => '0');
					end if;

					if (v.class_a(8) or v.class_b(8)) = '1' then
						v.snan := '1';
					elsif (((v.class_a(3) or v.class_a(4))) and ((v.class_b(3) or v.class_b(4)))) = '1' then
						v.snan := '1';
					elsif (((v.class_a(0) or v.class_a(7))) and ((v.class_b(0) or v.class_b(7)))) = '1' then
						v.snan := '1';
					elsif ((v.class_a(9) or v.class_b(9))) = '1' then
						v.qnan := '1';
					end if;

					if (((v.class_a(0) or v.class_a(7))) and ((v.class_b(1) or v.class_b(2) or v.class_b(3) or v.class_b(4) or v.class_b(5) or v.class_b(6)))) = '1' then
						v.inf := '1';
					elsif (((v.class_b(3) or v.class_b(4))) and ((v.class_a(1) or v.class_a(2) or v.class_a(5) or v.class_a(6)))) = '1' then
						v.dbz := '1';
					end if;

					if (((v.class_a(3) or v.class_a(4))) or ((v.class_b(0) or v.class_b(7)))) = '1' then
						v.zero := '1';
					end if;

					if fp_fdiv_i.op.fsqrt = '1' then
						if v.class_a(7) = '1' then
							v.inf := '1';
						end if;
						if (v.class_a(0) or v.class_a(1) or v.class_a(2)) = '1' then
							v.snan := '1';
						end if;
					end if;

					v.qa := "01" & signed(v.a(22 downto 0)) & "00";
					v.qb := "01" & signed(v.b(22 downto 0)) & "00";

					v.sign_fdiv := v.a(32) xor v.b(32);
					v.exponent_fdiv := to_integer(signed("0" & v.a(31 downto 23)) - signed("0" & v.b(31 downto 23)));
					v.y := "0" & nor_reduce(v.b(22 downto 16)) & reciprocal_lut(to_integer(unsigned(v.b(22 downto 16)))) & "0" & X"0000";
					v.op := '0';

					if fp_fdiv_i.op.fsqrt = '1' then
						v.qa := "01" & signed(v.a(22 downto 0)) & "00";
						if v.a(23) = '0' then
							v.qa := v.qa srl 1;
						end if;
						v.index := to_integer(unsigned(v.qa(25 downto 19)) - 32);
						v.exponent_fdiv := to_integer(shift_right((signed("0" & v.a(31 downto 23)) - 253), 1));
						v.y := "0" & reciprocal_root_lut(v.index) & "00" & X"0000";
						v.op := '1';
					end if;

					fp_mac_i.a <= (others => '0');
					fp_mac_i.b <= (others => '0');
					fp_mac_i.c <= (others => '0');
					fp_mac_i.op <= '0';
				when F1 =>
					case r.istate is
						when 0 =>
							fp_mac_i.a <= X"400000" & "000";
							fp_mac_i.b <= v.qb;
							fp_mac_i.c <= v.y;
							fp_mac_i.op <= '1';
							v.e0 := fp_mac_o.d(51 downto 25);
						when 1 =>
							fp_mac_i.a <= v.y;
							fp_mac_i.b <= v.y;
							fp_mac_i.c <= v.e0;
							fp_mac_i.op <= '0';
							v.y0 := fp_mac_o.d(51 downto 25);
						when 2 =>
							fp_mac_i.a <= X"000000" & "000";
							fp_mac_i.b <= v.e0;
							fp_mac_i.c <= v.e0;
							fp_mac_i.op <= '0';
							v.e1 := fp_mac_o.d(51 downto 25);
						when 3 =>
							fp_mac_i.a <= v.y0;
							fp_mac_i.b <= v.y0;
							fp_mac_i.c <= v.e1;
							fp_mac_i.op <= '0';
							v.y1 := fp_mac_o.d(51 downto 25);
						when 4 =>
							fp_mac_i.a <= X"000000" & "000";
							fp_mac_i.b <= v.qa;
							fp_mac_i.c <= v.y1;
							fp_mac_i.op <= '0';
							v.q0 := fp_mac_o.d(51 downto 25);
						when 5 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.qb;
							fp_mac_i.c <= v.q0;
							fp_mac_i.op <= '1';
							v.r0 := fp_mac_o.d;
						when 6 =>
							fp_mac_i.a <= v.q0;
							fp_mac_i.b <= v.r0(51 downto 25);
							fp_mac_i.c <= v.y1;
							fp_mac_i.op <= '0';
							v.q0 := fp_mac_o.d(51 downto 25);
						when 7 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.qb;
							fp_mac_i.c <= v.q0;
							fp_mac_i.op <= '1';
							v.r1 := fp_mac_o.d;
							v.q1 := v.q0;
							if v.r1(51 downto 25) > 0 then
								v.q1 := v.q1 + "01";
							end if;
						when 8 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.qb;
							fp_mac_i.c <= v.q1;
							fp_mac_i.op <= '1';
							v.r0 := fp_mac_o.d;
							if v.r0(51 downto 25) = 0 then
								v.q0 := v.q1;
								v.r1 := v.r0;
							end if;
						when others =>
							fp_mac_i.a <= (others => '0');
							fp_mac_i.b <= (others => '0');
							fp_mac_i.c <= (others => '0');
							fp_mac_i.op <= '0';
					end case;
				when F2 =>
					case r.istate is
						when 0 =>
							fp_mac_i.a <= X"000000" & "000";
							fp_mac_i.b <= v.qa;
							fp_mac_i.c <= v.y;
							fp_mac_i.op <= '0';
							v.y0 := fp_mac_o.d(51 downto 25);
						when 1 =>
							fp_mac_i.a <= X"000000" & "000";
							fp_mac_i.b <= X"200000" & "000";
							fp_mac_i.c <= v.y;
							fp_mac_i.op <= '0';
							v.h0 := fp_mac_o.d(51 downto 25);
						when 2 =>
							fp_mac_i.a <= X"200000" & "000";
							fp_mac_i.b <= v.h0;
							fp_mac_i.c <= v.y0;
							fp_mac_i.op <= '1';
							v.e0 := fp_mac_o.d(51 downto 25);
						when 3 =>
							fp_mac_i.a <= v.y0;
							fp_mac_i.b <= v.y0;
							fp_mac_i.c <= v.e0;
							fp_mac_i.op <= '0';
							v.y1 := fp_mac_o.d(51 downto 25);
						when 4 =>
							fp_mac_i.a <= v.h0;
							fp_mac_i.b <= v.h0;
							fp_mac_i.c <= v.e0;
							fp_mac_i.op <= '0';
							v.h1 := fp_mac_o.d(51 downto 25);
						when 5 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.y1;
							fp_mac_i.c <= v.y1;
							fp_mac_i.op <= '1';
							v.r0 := fp_mac_o.d;
						when 6 =>
							fp_mac_i.a <= v.y1;
							fp_mac_i.b <= v.h1;
							fp_mac_i.c <= v.r0(51 downto 25);
							fp_mac_i.op <= '0';
							v.y2 := fp_mac_o.d(51 downto 25);
						when 7 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.y2;
							fp_mac_i.c <= v.y2;
							fp_mac_i.op <= '1';
							v.r0 := fp_mac_o.d;
						when 8 =>
							fp_mac_i.a <= v.y2;
							fp_mac_i.b <= v.h1;
							fp_mac_i.c <= v.r0(51 downto 25);
							fp_mac_i.op <= '0';
							v.q0 := fp_mac_o.d(51 downto 25);
						when 9 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.q0;
							fp_mac_i.c <= v.q0;
							fp_mac_i.op <= '1';
							v.r1 := fp_mac_o.d;
							v.q1 := v.q0;
							if v.r1(51 downto 25) > 0 then
								v.q1 := v.q1 + "01";
							end if;
						when 10 =>
							fp_mac_i.a <= v.qa;
							fp_mac_i.b <= v.q1;
							fp_mac_i.c <= v.q1;
							fp_mac_i.op <= '1';
							v.r0 := fp_mac_o.d;
							if v.r0(51 downto 25) = 0 then
								v.q0 := v.q1;
								v.r1 := v.r0;
							end if;
						when others =>
							fp_mac_i.a <= (others => '0');
							fp_mac_i.b <= (others => '0');
							fp_mac_i.c <= (others => '0');
							fp_mac_i.op <= '0';
					end case;
				when F3 =>
					fp_mac_i.a <= (others => '0');
					fp_mac_i.b <= (others => '0');
					fp_mac_i.c <= (others => '0');
					fp_mac_i.op <= '0';

					v.mantissa_fdiv := std_logic_vector(v.q0(25 downto 0)) & "00" & X"0000000";

					v.remainder_rnd := "10";
					if v.r1 > 0 then
						v.remainder_rnd := "01";
					elsif v.r1 = 0 then
						v.remainder_rnd := "00";
					end if;

					v.counter_fdiv := 0;
					if v.mantissa_fdiv(55) = '0' then
						v.mantissa_fdiv := v.mantissa_fdiv(54 downto 0) & "0";
						v.counter_fdiv := 1;
					end if;
					if v.op = '1' then
						v.counter_fdiv := 1;
						if v.mantissa_fdiv(55) = '0' then
							v.mantissa_fdiv := v.mantissa_fdiv(54 downto 0) & "0";
							v.counter_fdiv := 0;
						end if;
					end if;

					v.exponent_bias := 127;

					v.sign_rnd := v.sign_fdiv;
					v.exponent_rnd := v.exponent_fdiv + v.exponent_bias - v.counter_fdiv;

					v.counter_rnd := 0;
					if v.exponent_rnd <= 0 then
						v.counter_rnd := 25;
						if v.exponent_rnd > -25 then
							v.counter_rnd := 1 - v.exponent_rnd;
						end if;
						v.exponent_rnd := 0;
					end if;

					v.mantissa_fdiv := std_logic_vector(shift_right(unsigned(v.mantissa_fdiv),v.counter_rnd));

					v.mantissa_rnd := "0" & v.mantissa_fdiv(55 downto 32);
					v.grs := v.mantissa_fdiv(31 downto 30) & or_reduce(v.mantissa_fdiv(29 downto 0));

				when others =>
					fp_mac_i.a <= (others => '0');
					fp_mac_i.b <= (others => '0');
					fp_mac_i.c <= (others => '0');
					fp_mac_i.op <= '0';

			end case;

			fp_fdiv_o.fp_rnd.sig <= v.sign_rnd;
			fp_fdiv_o.fp_rnd.expo <= v.exponent_rnd;
			fp_fdiv_o.fp_rnd.mant <= v.mantissa_rnd;
			fp_fdiv_o.fp_rnd.rema <= v.remainder_rnd;
			fp_fdiv_o.fp_rnd.fmt <= v.fmt;
			fp_fdiv_o.fp_rnd.rm <= v.rm;
			fp_fdiv_o.fp_rnd.grs <= v.grs;
			fp_fdiv_o.fp_rnd.snan <= v.snan;
			fp_fdiv_o.fp_rnd.qnan <= v.qnan;
			fp_fdiv_o.fp_rnd.dbz <= v.dbz;
			fp_fdiv_o.fp_rnd.inf <= v.inf;
			fp_fdiv_o.fp_rnd.zero <= v.zero;
			fp_fdiv_o.ready <= v.ready;

			rin <= v;

		end process;

		process(clock)
		begin
			if rising_edge(clock) then

				if reset = '0' then

					r <= init_fp_fdiv_functional_reg;

				else

					r <= rin;

				end if;

			end if;

		end process;

	end generate FUNCTIONAL;

	FIXED : if PERFORMANCE = 0 generate

		fp_mac_i.a <= (others => '0');
		fp_mac_i.b <= (others => '0');
		fp_mac_i.c <= (others => '0');
		fp_mac_i.op <= '0';

		process(r_fix, fp_fdiv_i)
			variable v : fp_fdiv_fixed_reg_type;

		begin
			v := r_fix;

			case r_fix.state is
				when F0 =>
					if fp_fdiv_i.op.fdiv = '1' then
						v.state := F1;
						v.istate := 25;
					elsif fp_fdiv_i.op.fsqrt = '1' then
						v.state := F1;
						v.istate := 24;
					end if;
					v.ready := '0';
				when F1 =>
					if v.istate = 0 then
						v.state := F2;
					else
						v.istate := v.istate - 1;
					end if;
					v.ready := '0';
				when F2 =>
					v.state := F3;
					v.ready := '0';
				when others =>
					v.state := F0;
					v.ready := '1';
			end case;

			case r_fix.state is

				when F0 =>

					v.a := fp_fdiv_i.data1;
					v.b := fp_fdiv_i.data2;
					v.class_a := fp_fdiv_i.class1;
					v.class_b := fp_fdiv_i.class2;
					v.fmt := fp_fdiv_i.fmt;
					v.rm := fp_fdiv_i.rm;
					v.snan := '0';
					v.qnan := '0';
					v.dbz := '0';
					v.inf := '0';
					v.zero := '0';

					if fp_fdiv_i.op.fsqrt = '1' then
						v.b := (30 downto 23 => '1', others => '0');
						v.class_b := (others => '0');
					end if;

					if (v.class_a(8) or v.class_b(8)) = '1' then
						v.snan := '1';
					elsif (((v.class_a(3) or v.class_a(4))) and ((v.class_b(3) or v.class_b(4)))) = '1' then
						v.snan := '1';
					elsif (((v.class_a(0) or v.class_a(7))) and ((v.class_b(0) or v.class_b(7)))) = '1' then
						v.snan := '1';
					elsif (v.class_a(9) or v.class_b(9)) = '1' then
						v.qnan := '1';
					end if;

					if (((v.class_a(0) or v.class_a(7))) and ((v.class_b(1) or v.class_b(2) or v.class_b(3) or v.class_b(4) or v.class_b(5) or v.class_b(6)))) = '1' then
						v.inf := '1';
					elsif (((v.class_b(3) or v.class_b(4))) and ((v.class_a(1) or v.class_a(2) or v.class_a(5) or v.class_a(6)))) = '1' then
						v.dbz := '1';
					end if;

					if (((v.class_a(3) or v.class_a(4))) or ((v.class_b(0) or v.class_b(7)))) = '1' then
						v.zero := '1';
					end if;

					if fp_fdiv_i.op.fsqrt = '1' then
						if v.class_a(7) = '1' then
							v.inf := '1';
						end if;
						if (v.class_a(0) or v.class_a(1) or v.class_a(2)) = '1' then
							v.snan := '1';
						end if;
					end if;

					v.sign_fdiv := v.a(32) xor v.b(32);

					v.exponent_fdiv := to_integer(signed("0" & v.a(31 downto 23)) - signed("0" & v.b(31 downto 23)));
					if fp_fdiv_i.op.fsqrt = '1' then
						v.exponent_fdiv := to_integer(shift_right((signed("0" & v.a(31 downto 23)) - 253), 1));
					end if;

					v.q := (others => '0');

					v.m := X"1" & v.b(22 downto 0) & "0";
					v.r := "0" & X"1" & v.a(22 downto 0);
					v.op := '0';
					if fp_fdiv_i.op.fsqrt = '1' then
						v.m := (others => '0');
						if v.a(23) = '0' then
							v.r := v.r(26 downto 0) & '0';
						end if;
						v.op := '1';
					end if;

				when F1 =>

					if v.op = '1' then
						v.m := '0' & v.q & '0';
						v.m(r_fix.istate) := '1';
					end if;
					v.r := v.r(26 downto 0) & '0';
					v.e := std_logic_vector(signed(v.r) - signed(v.m));
					if v.e(26) = '0' then
						v.q(r_fix.istate) := '1';
						v.r := v.e;
					end if;

				when F2 =>

					v.mantissa_fdiv := v.q & v.r(26 downto 0) & "0" & X"000000";

					v.counter_fdiv := 0;
					if v.mantissa_fdiv(77) = '0' then
						v.counter_fdiv := 1;
					end if;

					v.mantissa_fdiv := std_logic_vector(shift_left(unsigned(v.mantissa_fdiv),v.counter_fdiv));

					v.sign_rnd := v.sign_fdiv;

					v.exponent_bias := 127;

					v.exponent_rnd := v.exponent_fdiv + v.exponent_bias - v.counter_fdiv;

					v.counter_rnd := 0;
					if v.exponent_rnd <= 0 then
						v.counter_rnd := 25;
						if v.exponent_rnd > -25 then
							v.counter_rnd := 1 - v.exponent_rnd;
						end if;
						v.exponent_rnd := 0;
					end if;

					v.mantissa_fdiv := std_logic_vector(shift_right(unsigned(v.mantissa_fdiv),v.counter_rnd));

					v.mantissa_rnd := "0" & v.mantissa_fdiv(77 downto 54);
					v.grs := v.mantissa_fdiv(53 downto 52) & or_reduce(v.mantissa_fdiv(51 downto 0));

				when others =>

			end case;

			fp_fdiv_o.fp_rnd.sig <= v.sign_rnd;
			fp_fdiv_o.fp_rnd.expo <= v.exponent_rnd;
			fp_fdiv_o.fp_rnd.mant <= v.mantissa_rnd;
			fp_fdiv_o.fp_rnd.rema <= "00";
			fp_fdiv_o.fp_rnd.fmt <= v.fmt;
			fp_fdiv_o.fp_rnd.rm <= v.rm;
			fp_fdiv_o.fp_rnd.grs <= v.grs;
			fp_fdiv_o.fp_rnd.snan <= v.snan;
			fp_fdiv_o.fp_rnd.qnan <= v.qnan;
			fp_fdiv_o.fp_rnd.dbz <= v.dbz;
			fp_fdiv_o.fp_rnd.inf <= v.inf;
			fp_fdiv_o.fp_rnd.zero <= v.zero;
			fp_fdiv_o.ready <= v.ready;

			rin_fix <= v;

		end process;

		process(clock)
		begin
			if rising_edge(clock) then

				if reset = '0' then

					r_fix <= init_fp_fdiv_fixed_reg;

				else

					r_fix <= rin_fix;

				end if;

			end if;

		end process;

	end generate FIXED;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.fp_cons.all;
use work.fp_wire.all;

entity fp_exe is
	port(
		reset        : in  std_logic;
		clock        : in  std_logic;
		fp_exe_i     : in  fp_exe_in_type;
		fp_exe_o     : out fp_exe_out_type;
		fp_ext1_o    : in  fp_ext_out_type;
		fp_ext1_i    : out fp_ext_in_type;
		fp_ext2_o    : in  fp_ext_out_type;
		fp_ext2_i    : out fp_ext_in_type;
		fp_ext3_o    : in  fp_ext_out_type;
		fp_ext3_i    : out fp_ext_in_type;
		fp_cmp_o     : in  fp_cmp_out_type;
		fp_cmp_i     : out fp_cmp_in_type;
		fp_cvt_f2i_o : in  fp_cvt_f2i_out_type;
		fp_cvt_f2i_i : out fp_cvt_f2i_in_type;
		fp_cvt_i2f_o : in  fp_cvt_i2f_out_type;
		fp_cvt_i2f_i : out fp_cvt_i2f_in_type;
		fp_max_o     : in  fp_max_out_type;
		fp_max_i     : out fp_max_in_type;
		fp_sgnj_o    : in  fp_sgnj_out_type;
		fp_sgnj_i    : out fp_sgnj_in_type;
		fp_fma_o     : in  fp_fma_out_type;
		fp_fma_i     : out fp_fma_in_type;
		fp_fdiv_o    : in  fp_fdiv_out_type;
		fp_fdiv_i    : out fp_fdiv_in_type;
		fp_rnd_o     : in  fp_rnd_out_type;
		fp_rnd_i     : out fp_rnd_in_type
	);
end fp_exe;

architecture behavior of fp_exe is

begin

	process(fp_exe_i, fp_ext1_o, fp_ext2_o, fp_ext3_o, fp_cmp_o, fp_max_o, fp_sgnj_o, fp_cvt_f2i_o, fp_cvt_i2f_o, fp_fma_o, fp_fdiv_o, fp_rnd_o)
		variable data1 : std_logic_vector(31 downto 0);
		variable data2 : std_logic_vector(31 downto 0);
		variable data3 : std_logic_vector(31 downto 0);
		variable op    : fp_operation_type;
		variable fmt   : std_logic_vector(1 downto 0);
		variable rm    : std_logic_vector(2 downto 0);

		variable result : std_logic_vector(31 downto 0);
		variable flags  : std_logic_vector(4 downto 0);
		variable ready  : std_logic;

		variable fp_rnd : fp_rnd_in_type;

		variable ext1 : std_logic_vector(32 downto 0);
		variable ext2 : std_logic_vector(32 downto 0);
		variable ext3 : std_logic_vector(32 downto 0);

		variable class1 : std_logic_vector(9 downto 0);
		variable class2 : std_logic_vector(9 downto 0);
		variable class3 : std_logic_vector(9 downto 0);

	begin
		data1 := fp_exe_i.data1;
		data2 := fp_exe_i.data2;
		data3 := fp_exe_i.data3;
		op := fp_exe_i.op;
		fmt := fp_exe_i.fmt;
		rm := fp_exe_i.rm;

		result := (others => '0');
		flags := (others => '0');
		ready := fp_exe_i.enable;

		fp_rnd := init_fp_rnd_in;

		fp_ext1_i.data <= data1;
		fp_ext1_i.fmt <= fmt;
		fp_ext2_i.data <= data2;
		fp_ext2_i.fmt <= fmt;
		fp_ext3_i.data <= data3;
		fp_ext3_i.fmt <= fmt;

		ext1 := fp_ext1_o.result;
		ext2 := fp_ext2_o.result;
		ext3 := fp_ext3_o.result;

		class1 := fp_ext1_o.class;
		class2 := fp_ext2_o.class;
		class3 := fp_ext3_o.class;

		fp_cmp_i.data1 <= ext1;
		fp_cmp_i.data2 <= ext2;
		fp_cmp_i.rm <= rm;
		fp_cmp_i.class1 <= class1;
		fp_cmp_i.class2 <= class2;

		fp_max_i.data1 <= data1;
		fp_max_i.data2 <= data2;
		fp_max_i.ext1 <= ext1;
		fp_max_i.ext2 <= ext2;
		fp_max_i.fmt <= fmt;
		fp_max_i.rm <= rm;
		fp_max_i.class1 <= class1;
		fp_max_i.class2 <= class2;

		fp_sgnj_i.data1 <= data1;
		fp_sgnj_i.data2 <= data2;
		fp_sgnj_i.fmt <= fmt;
		fp_sgnj_i.rm <= rm;

		fp_cvt_i2f_i.data <= data1;
		fp_cvt_i2f_i.op <= op;
		fp_cvt_i2f_i.fmt <= fmt;
		fp_cvt_i2f_i.rm <= rm;

		fp_cvt_f2i_i.data <= ext1;
		fp_cvt_f2i_i.op <= op;
		fp_cvt_f2i_i.rm <= rm;
		fp_cvt_f2i_i.class <= class1;

		fp_fma_i.data1 <= ext1;
		fp_fma_i.data2 <= ext2;
		fp_fma_i.data3 <= ext3;
		fp_fma_i.class1 <= class1;
		fp_fma_i.class2 <= class2;
		fp_fma_i.class3 <= class3;
		fp_fma_i.op <= op;
		fp_fma_i.fmt <= fmt;
		fp_fma_i.rm <= rm;

		fp_fdiv_i.data1 <= ext1;
		fp_fdiv_i.data2 <= ext2;
		fp_fdiv_i.class1 <= class1;
		fp_fdiv_i.class2 <= class2;
		fp_fdiv_i.op <= op;
		fp_fdiv_i.fmt <= fmt;
		fp_fdiv_i.rm <= rm;

		if fp_fma_o.ready = '1' then
			fp_rnd := fp_fma_o.fp_rnd;
		elsif fp_fdiv_o.ready = '1' then
			fp_rnd := fp_fdiv_o.fp_rnd;
		elsif op.fcvt_i2f = '1' then
			fp_rnd := fp_cvt_i2f_o.fp_rnd;
		end if;

		fp_rnd_i <= fp_rnd;

		if fp_fma_o.ready = '1' then
			result := fp_rnd_o.result;
			flags := fp_rnd_o.flags;
			ready := '1';
		elsif fp_fdiv_o.ready = '1' then
			result := fp_rnd_o.result;
			flags := fp_rnd_o.flags;
			ready := '1';
		elsif op.fmadd = '1' then
			ready := '0';
		elsif op.fmsub = '1' then
			ready := '0';
		elsif op.fnmsub = '1' then
			ready := '0';
		elsif op.fnmadd = '1' then
			ready := '0';
		elsif op.fadd = '1' then
			ready := '0';
		elsif op.fsub = '1' then
			ready := '0';
		elsif op.fmul = '1' then
			ready := '0';
		elsif op.fdiv = '1' then
			ready := '0';
		elsif op.fsqrt = '1' then
			ready := '0';
		elsif op.fsgnj = '1' then
			result := fp_sgnj_o.result;
			flags := "00000";
		elsif op.fmax = '1' then
			result := fp_max_o.result;
			flags := fp_max_o.flags;
		elsif op.fcmp = '1' then
			result := fp_cmp_o.result;
			flags := fp_cmp_o.flags;
		elsif op.fclass = '1' then
			result := "00" & X"00000" & class1;
			flags := "00000";
		elsif op.fmv_f2i = '1' then
			result := data1;
			flags := "00000";
		elsif op.fmv_i2f = '1' then
			result := data1;
			flags := "00000";
		elsif op.fcvt_i2f = '1' then
			result := fp_rnd_o.result;
			flags := fp_rnd_o.flags;
		elsif op.fcvt_f2i = '1' then
			result := fp_cvt_f2i_o.result;
			flags := fp_cvt_f2i_o.flags;
		end if;

		fp_exe_o.result <= result;
		fp_exe_o.flags <= flags;
		fp_exe_o.ready <= ready;

	end process;

end behavior;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.lzc_lib.all;
use work.fp_cons.all;
use work.fp_wire.all;
use work.fp_lib.all;

entity fp_unit is
	port(
		reset     : in  std_logic;
		clock     : in  std_logic;
		fp_unit_i : in  fp_unit_in_type;
		fp_unit_o : out fp_unit_out_type
	);
end fp_unit;

architecture behavior of fp_unit is

	signal lzc1_32_i : lzc_32_in_type;
	signal lzc1_32_o : lzc_32_out_type;
	signal lzc2_32_i : lzc_32_in_type;
	signal lzc2_32_o : lzc_32_out_type;
	signal lzc3_32_i : lzc_32_in_type;
	signal lzc3_32_o : lzc_32_out_type;
	signal lzc4_32_i : lzc_32_in_type;
	signal lzc4_32_o : lzc_32_out_type;

	signal lzc_128_i : lzc_128_in_type;
	signal lzc_128_o : lzc_128_out_type;

	signal fp_ext1_i : fp_ext_in_type;
	signal fp_ext1_o : fp_ext_out_type;
	signal fp_ext2_i : fp_ext_in_type;
	signal fp_ext2_o : fp_ext_out_type;
	signal fp_ext3_i : fp_ext_in_type;
	signal fp_ext3_o : fp_ext_out_type;

	signal fp_cmp_o  : fp_cmp_out_type;
	signal fp_cmp_i  : fp_cmp_in_type;
	signal fp_max_o  : fp_max_out_type;
	signal fp_max_i  : fp_max_in_type;
	signal fp_sgnj_o : fp_sgnj_out_type;
	signal fp_sgnj_i : fp_sgnj_in_type;
	signal fp_fma_i  : fp_fma_in_type;
	signal fp_fma_o  : fp_fma_out_type;

	signal fp_mac_i : fp_mac_in_type;
	signal fp_mac_o : fp_mac_out_type;

	signal fp_fdiv_i : fp_fdiv_in_type;
	signal fp_fdiv_o : fp_fdiv_out_type;

	signal fp_cvt_f2i_o : fp_cvt_f2i_out_type;
	signal fp_cvt_f2i_i : fp_cvt_f2i_in_type;
	signal fp_cvt_i2f_o : fp_cvt_i2f_out_type;
	signal fp_cvt_i2f_i : fp_cvt_i2f_in_type;

	signal fp_rnd_i : fp_rnd_in_type;
	signal fp_rnd_o : fp_rnd_out_type;

begin

	lzc1_32_comp : lzc_32
		port map(
			A => lzc1_32_i.a,
			Z => lzc1_32_o.c
		);

	lzc2_32_comp : lzc_32
		port map(
			A => lzc2_32_i.a,
			Z => lzc2_32_o.c
		);

	lzc3_32_comp : lzc_32
		port map(
			A => lzc3_32_i.a,
			Z => lzc3_32_o.c
		);

	lzc4_32_comp : lzc_32
		port map(
			A => lzc4_32_i.a,
			Z => lzc4_32_o.c
		);

	lzc_128_comp : lzc_128
		port map(
			A => lzc_128_i.a,
			Z => lzc_128_o.c
		);

	fp_ext1_comp : fp_ext
		port map(
			fp_ext_i => fp_ext1_i,
			fp_ext_o => fp_ext1_o,
			lzc_o    => lzc1_32_o,
			lzc_i    => lzc1_32_i
		);

	fp_ext2_comp : fp_ext
		port map(
			fp_ext_i => fp_ext2_i,
			fp_ext_o => fp_ext2_o,
			lzc_o    => lzc2_32_o,
			lzc_i    => lzc2_32_i
		);

	fp_ext3_comp : fp_ext
		port map(
			fp_ext_i => fp_ext3_i,
			fp_ext_o => fp_ext3_o,
			lzc_o    => lzc3_32_o,
			lzc_i    => lzc3_32_i
		);

	fp_cmp_comp : fp_cmp
		port map(
			fp_cmp_i => fp_cmp_i,
			fp_cmp_o => fp_cmp_o
		);

	fp_rnd_comp : fp_rnd
		port map(
			fp_rnd_i => fp_rnd_i,
			fp_rnd_o => fp_rnd_o
		);

	fp_cvt_comp : fp_cvt
		port map(
			fp_cvt_f2i_i => fp_cvt_f2i_i,
			fp_cvt_f2i_o => fp_cvt_f2i_o,
			fp_cvt_i2f_i => fp_cvt_i2f_i,
			fp_cvt_i2f_o => fp_cvt_i2f_o,
			lzc_i        => lzc4_32_i,
			lzc_o        => lzc4_32_o
		);

	fp_sgnj_comp : fp_sgnj
		port map(
			fp_sgnj_i => fp_sgnj_i,
			fp_sgnj_o => fp_sgnj_o
		);

	fp_max_comp : fp_max
		port map(
			fp_max_i => fp_max_i,
			fp_max_o => fp_max_o
		);

	fp_fma_comp : fp_fma
		port map(
			reset    => reset,
			clock    => clock,
			fp_fma_i => fp_fma_i,
			fp_fma_o => fp_fma_o,
			lzc_o    => lzc_128_o,
			lzc_i    => lzc_128_i
		);

	fp_mac_comp : fp_mac
		port map(
			fp_mac_i => fp_mac_i,
			fp_mac_o => fp_mac_o
		);

	fp_fdiv_comp : fp_fdiv
		port map(
			reset     => reset,
			clock     => clock,
			fp_fdiv_i => fp_fdiv_i,
			fp_fdiv_o => fp_fdiv_o,
			fp_mac_i  => fp_mac_i,
			fp_mac_o  => fp_mac_o
		);

	fp_exe_comp : fp_exe
		port map(
			reset        => reset,
			clock        => clock,
			fp_exe_i     => fp_unit_i.fp_exe_i,
			fp_exe_o     => fp_unit_o.fp_exe_o,
			fp_ext1_o    => fp_ext1_o,
			fp_ext1_i    => fp_ext1_i,
			fp_ext2_o    => fp_ext2_o,
			fp_ext2_i    => fp_ext2_i,
			fp_ext3_o    => fp_ext3_o,
			fp_ext3_i    => fp_ext3_i,
			fp_cmp_o     => fp_cmp_o,
			fp_cmp_i     => fp_cmp_i,
			fp_cvt_f2i_o => fp_cvt_f2i_o,
			fp_cvt_f2i_i => fp_cvt_f2i_i,
			fp_cvt_i2f_o => fp_cvt_i2f_o,
			fp_cvt_i2f_i => fp_cvt_i2f_i,
			fp_max_o     => fp_max_o,
			fp_max_i     => fp_max_i,
			fp_sgnj_o    => fp_sgnj_o,
			fp_sgnj_i    => fp_sgnj_i,
			fp_fma_o     => fp_fma_o,
			fp_fma_i     => fp_fma_i,
			fp_fdiv_o    => fp_fdiv_o,
			fp_fdiv_i    => fp_fdiv_i,
			fp_rnd_o     => fp_rnd_o,
			fp_rnd_i     => fp_rnd_i
		);

end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fp_wire.all;
use work.fpupack.all;

--cannot do several conversions one by one due to peculiarities of result latching (at least one tick should be between)
entity fpu is
	port (
		clk_i       : in  std_logic;
		rst_i 		: in std_logic;

		opa_i       : in  std_logic_vector(FP_WIDTH-1 downto 0);
		opb_i       : in  std_logic_vector(FP_WIDTH-1 downto 0);
		fpu_op_i    : in  std_logic_vector(2 downto 0);
		rmode_i     : in  std_logic_vector(1 downto 0); --should be connected
		output_o    : out std_logic_vector(FP_WIDTH-1 downto 0);

		start_i     : in  std_logic; --needed only for ready_o generation
		ready_o     : out std_logic;

		--should be removed
		ine_o 			: out std_logic; -- inexact
        overflow_o  	: out std_logic; -- overflow
        underflow_o 	: out std_logic; -- underflow
        div_zero_o  	: out std_logic; -- divide by zero
        inf_o			: out std_logic; -- infinity
        zero_o			: out std_logic; -- zero
        qnan_o			: out std_logic; -- queit Not-a-Number
        snan_o			: out std_logic -- signaling Not-a-Number
	);
end entity fpu;

architecture rtl of fpu is
	signal fp_i : fp_unit_in_type;
	signal fp_o : fp_unit_out_type;

	signal s_opa_i       : std_logic_vector(FP_WIDTH-1 downto 0) := (others => '0');
	signal s_opb_i       : std_logic_vector(FP_WIDTH-1 downto 0) := (others => '0');
	signal s_fpu_op_i    : std_logic_vector(2 downto 0) := (others => '0');
	signal s_start_i     : std_logic := '0';

	signal s_reset : std_logic;
	signal operation : std_logic_vector(5 downto 0) := (others => '0');
	signal reg_ready, reg_in_ready : std_logic := '0';
	signal reg_result, reg_in_result : std_logic_vector(FP_WIDTH - 1 downto 0) := (others => '0');
begin
	fp_unit_1 : entity work.fp_unit
		port map (
			reset     => s_reset, 
			clock     => clk_i,
			fp_unit_i => fp_i,
			fp_unit_o => fp_o
		);	

	s_reset <= not rst_i; --changes polarity!

	process(clk_i)
	begin
		if (rising_edge(clk_i)) then
			if (rst_i = '1') then
				s_start_i <= '0';
				s_opa_i <= (others => '0');
				s_opb_i <= (others => '0');
				s_fpu_op_i <= (others => '0');

				reg_ready <= '0';
				reg_result <= (others => '0');
			else
				s_start_i <= start_i;
				s_opa_i <= opa_i;
				s_opb_i <= opb_i;
				s_fpu_op_i <= fpu_op_i;

				reg_ready <= reg_in_ready; 
				reg_result <= reg_in_result;
			end if;
		end if;
	end process;

	process (all)
	begin
		reg_in_result <= reg_result;
		reg_in_ready <= '0';
		operation <= (others => '0');

		if (rst_i /= '1') then
			reg_in_ready <= fp_o.fp_exe_o.ready;
			if (fp_o.fp_exe_o.ready = '1') then
				reg_in_result <= fp_o.fp_exe_o.result;
			end if;

			if (s_start_i = '1') then
				case (s_fpu_op_i) is
					when "000" =>
						operation <= "000001"; --fadd

					when "001" =>
						operation <= "000010"; --fsub

					when "010" =>
						operation <= "000100"; --fmul

					when "011" =>	
						operation <= "001000"; --fdiv

					when "100" =>
						operation <= "010000"; --fcvt_f2i

					when "101" =>
						operation <= "100000"; --fcvt_i2f

					when others =>
						operation <= "000000";
				end case;
			end if;
		end if;
	end process;

	--interconnections ---------------------------------------------------------
	fp_i.fp_exe_i.data1 <= s_opa_i;
	fp_i.fp_exe_i.data2 <= s_opb_i;
	fp_i.fp_exe_i.op.fadd <= operation(0);
	fp_i.fp_exe_i.op.fsub <= operation(1);
	fp_i.fp_exe_i.op.fmul <= operation(2);
	fp_i.fp_exe_i.op.fdiv <= operation(3);
	fp_i.fp_exe_i.op.fcvt_f2i <= operation(4);
	fp_i.fp_exe_i.op.fcvt_i2f <= operation(5);
	fp_i.fp_exe_i.op.fcvt_op <= "00";
	fp_i.fp_exe_i.fmt <= "00";
	fp_i.fp_exe_i.rm <= "000";
	fp_i.fp_exe_i.enable <= s_start_i; 

	output_o <= reg_result;
	ready_o <= reg_ready;

	--not used -----------------------------------------------------------------
	ine_o 			<= '0'; -- inexact
    overflow_o  	<= '0'; -- overflow
    underflow_o 	<= '0'; -- underflow
    div_zero_o  	<= '0'; -- divide by zero
    inf_o			<= '0'; -- infinity
    zero_o			<= '0'; -- zero
    qnan_o			<= '0'; -- queit Not-a-Number
    snan_o			<= '0'; -- signaling Not-a-Number

	fp_i.fp_exe_i.data3 <= (others => '0');
	fp_i.fp_exe_i.op.fmadd <= '0';
	fp_i.fp_exe_i.op.fmsub <= '0';
	fp_i.fp_exe_i.op.fnmadd <= '0';
	fp_i.fp_exe_i.op.fnmsub <= '0';
	fp_i.fp_exe_i.op.fsqrt <= '0';
	fp_i.fp_exe_i.op.fsgnj <= '0';
	fp_i.fp_exe_i.op.fcmp <= '0';
	fp_i.fp_exe_i.op.fmax <= '0';
	fp_i.fp_exe_i.op.fclass <= '0';
	fp_i.fp_exe_i.op.fmv_i2f <= '0';
	fp_i.fp_exe_i.op.fmv_f2i <= '0';

	fp_i.fp_dec_i.instr <= (others => '0');

	fp_i.fp_reg_ri.rden1 <= '0';
	fp_i.fp_reg_ri.raddr1 <= (others => '0');
	fp_i.fp_reg_ri.rden2 <= '0';
	fp_i.fp_reg_ri.raddr2 <= (others => '0');
	fp_i.fp_reg_ri.rden3 <= '0';
	fp_i.fp_reg_ri.raddr3 <= (others => '0');

	fp_i.fp_reg_wi.wren <= '0';
	fp_i.fp_reg_wi.waddr <= (others => '0');
	fp_i.fp_reg_wi.wdata <= (others => '0');

	fp_i.fp_for_i.reg_en1 <= '0';
	fp_i.fp_for_i.reg_addr1 <= (others => '0');
	fp_i.fp_for_i.reg_data1 <= (others => '0');
	fp_i.fp_for_i.reg_en2 <= '0';
	fp_i.fp_for_i.reg_addr2 <= (others => '0');
	fp_i.fp_for_i.reg_data2 <= (others => '0');
	fp_i.fp_for_i.reg_en3 <= '0';
	fp_i.fp_for_i.reg_addr3 <= (others => '0');
	fp_i.fp_for_i.reg_data3 <= (others => '0');
	fp_i.fp_for_i.exe_en <= '0';
	fp_i.fp_for_i.exe_addr <= (others => '0');
	fp_i.fp_for_i.exe_data <= (others => '0');
	fp_i.fp_for_i.mem_en <= '0';
	fp_i.fp_for_i.mem_addr <= (others => '0');
	fp_i.fp_for_i.mem_data <= (others => '0');

	fp_i.fp_csr_ri.rden <= '0';
	fp_i.fp_csr_ri.raddr <= (others => '0');

	fp_i.fp_csr_wi.wren <= '0';
	fp_i.fp_csr_wi.waddr <= (others => '0');
	fp_i.fp_csr_wi.wdata <= (others => '0');
end architecture rtl;
