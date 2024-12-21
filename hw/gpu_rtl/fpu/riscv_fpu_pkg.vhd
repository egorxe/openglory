-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp_func is

	function and_reduce(arg: std_logic_vector) return ux01;
	function nand_reduce(arg: std_logic_vector) return ux01;
	function or_reduce(arg: std_logic_vector) return ux01;
	function nor_reduce(arg: std_logic_vector) return ux01;
	function xor_reduce(arg: std_logic_vector) return ux01;
	function xnor_reduce(arg: std_logic_vector) return ux01;

end fp_func;

package body fp_func is

	function and_reduce(arg: std_logic_vector) return ux01 is
		variable result: std_logic;
	begin
		result := '1';
		for i in arg'range loop
			result := result and arg(i);
		end loop;
		return result;
	end;

	function nand_reduce(arg: std_logic_vector) return ux01 is
	begin
		return not and_reduce(arg);
	end;

	function or_reduce(arg: std_logic_vector) return ux01 is
		variable result: std_logic;
	begin
		result := '0';
		for i in arg'range loop
			result := result or arg(i);
		end loop;
		return result;
	end;

	function nor_reduce(arg: std_logic_vector) return ux01 is
	begin
		return not or_reduce(arg);
	end;

	function xor_reduce(arg: std_logic_vector) return ux01 is
		variable result: std_logic;
	begin
		result := '0';
		for i in arg'range loop
			result := result xor arg(i);
		end loop;
		return result;
	end;

	function xnor_reduce(arg: std_logic_vector) return ux01 is
	begin
		return not xor_reduce(arg);
	end;

end fp_func;

-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

package lzc_wire is

	type lzc_32_in_type is record
		a : std_logic_vector(31 downto 0);
	end record;

	type lzc_32_out_type is record
		c : std_logic_vector(4 downto 0);
	end record;

	type lzc_128_in_type is record
		a : std_logic_vector(127 downto 0);
	end record;

	type lzc_128_out_type is record
		c : std_logic_vector(6 downto 0);
	end record;

end package;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

package lzc_lib is

	component lzc_4
		port(
			A : in  std_logic_vector(3 downto 0);
			Z : out std_logic_vector(1 downto 0);
			V : out std_logic
		);
	end component;

	component lzc_8
		port(
			A : in  std_logic_vector(7 downto 0);
			Z : out std_logic_vector(2 downto 0);
			V : out std_logic
		);
	end component;

	component lzc_16
		port(
			A : in  std_logic_vector(15 downto 0);
			Z : out std_logic_vector(3 downto 0);
			V : out std_logic
		);
	end component;

	component lzc_32
		port(
			A : in  std_logic_vector(31 downto 0);
			Z : out std_logic_vector(4 downto 0);
			V : out std_logic
		);
	end component;

	component lzc_64
		port(
			A : in  std_logic_vector(63 downto 0);
			Z : out std_logic_vector(5 downto 0);
			V : out std_logic
		);
	end component;

	component lzc_128
		port(
			A : in  std_logic_vector(127 downto 0);
			Z : out std_logic_vector(6 downto 0);
			V : out std_logic
		);
	end component;

end package;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;

package fp_cons is

	constant funct_fadd     : std_logic_vector(4 downto 0) := "00000";
	constant funct_fsub     : std_logic_vector(4 downto 0) := "00001";
	constant funct_fmul     : std_logic_vector(4 downto 0) := "00010";
	constant funct_fdiv     : std_logic_vector(4 downto 0) := "00011";
	constant funct_fsqrt    : std_logic_vector(4 downto 0) := "01011";
	constant funct_fsgnj    : std_logic_vector(4 downto 0) := "00100";
	constant funct_fmax     : std_logic_vector(4 downto 0) := "00101";
	constant funct_fcmp     : std_logic_vector(4 downto 0) := "10100";
	constant funct_fclass   : std_logic_vector(4 downto 0) := "11100";
	constant funct_fmv_f2i  : std_logic_vector(4 downto 0) := "11100";
	constant funct_fmv_i2f  : std_logic_vector(4 downto 0) := "11110";
	constant funct_fcvt_f2i : std_logic_vector(4 downto 0) := "11000";
	constant funct_fcvt_i2f : std_logic_vector(4 downto 0) := "11010";

	constant funct_fmadd  : std_logic_vector(6 downto 0) := "1000011";
	constant funct_fmsub  : std_logic_vector(6 downto 0) := "1000111";
	constant funct_fnmsub : std_logic_vector(6 downto 0) := "1001011";
	constant funct_fnmadd : std_logic_vector(6 downto 0) := "1001111";

	constant opcode_fp     : std_logic_vector(6 downto 0) := "1010011";
	constant opcode_fload  : std_logic_vector(6 downto 0) := "0000111";
	constant opcode_fstore : std_logic_vector(6 downto 0) := "0100111";
	constant opcode_fmadd  : std_logic_vector(6 downto 0) := "1000011";
	constant opcode_fmsub  : std_logic_vector(6 downto 0) := "1000111";
	constant opcode_fnmsub : std_logic_vector(6 downto 0) := "1001011";
	constant opcode_fnmadd : std_logic_vector(6 downto 0) := "1001111";

end fp_cons;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fp_cons.all;

package fp_wire is

	type f_state_type is (F0, F1, F2, F3, F4);

	function to_std_logic(
		condition : in boolean
	)
	return std_logic;

	type fp_operation_type is record
		fmadd    : std_logic;
		fmsub    : std_logic;
		fnmadd   : std_logic;
		fnmsub   : std_logic;
		fadd     : std_logic;
		fsub     : std_logic;
		fmul     : std_logic;
		fdiv     : std_logic;
		fsqrt    : std_logic;
		fsgnj    : std_logic;
		fcmp     : std_logic;
		fmax     : std_logic;
		fclass   : std_logic;
		fmv_i2f  : std_logic;
		fmv_f2i  : std_logic;
		fcvt_i2f : std_logic;
		fcvt_f2i : std_logic;
		fcvt_op  : std_logic_vector(1 downto 0);
	end record;

	constant init_fp_operation : fp_operation_type := (
		fmadd    => '0',
		fmsub    => '0',
		fnmadd   => '0',
		fnmsub   => '0',
		fadd     => '0',
		fsub     => '0',
		fmul     => '0',
		fdiv     => '0',
		fsqrt    => '0',
		fsgnj    => '0',
		fcmp     => '0',
		fmax     => '0',
		fclass   => '0',
		fmv_i2f  => '0',
		fmv_f2i  => '0',
		fcvt_i2f => '0',
		fcvt_f2i => '0',
		fcvt_op  => (others => '0')
	);

	type fp_reg_read_in_type is record
		rden1  : std_logic;
		raddr1 : std_logic_vector(4 downto 0);
		rden2  : std_logic;
		raddr2 : std_logic_vector(4 downto 0);
		rden3  : std_logic;
		raddr3 : std_logic_vector(4 downto 0);
	end record;

	type fp_reg_write_in_type is record
		wren  : std_logic;
		waddr : std_logic_vector(4 downto 0);
		wdata : std_logic_vector(31 downto 0);
	end record;

	type fp_reg_out_type is record
		data1 : std_logic_vector(31 downto 0);
		data2 : std_logic_vector(31 downto 0);
		data3 : std_logic_vector(31 downto 0);
	end record;

	type fp_csr_read_in_type is record
		rden  : std_logic;
		raddr : std_logic_vector(11 downto 0);
	end record;

	type fp_csr_write_in_type is record
		wren  : std_logic;
		waddr : std_logic_vector(11 downto 0);
		wdata : std_logic_vector(31 downto 0);
	end record;

	type fp_csr_out_type is record
		data : std_logic_vector(31 downto 0);
	end record;

	type fp_dec_in_type is record
		instr : std_logic_vector(31 downto 0);
	end record;

	type fp_dec_out_type is record
		imm       : std_logic_vector(31 downto 0);
		int_rden1 : std_logic;
		int_wren  : std_logic;
		fpu_rden1 : std_logic;
		fpu_rden2 : std_logic;
		fpu_rden3 : std_logic;
		fpu_wren  : std_logic;
		fpu_load  : std_logic;
		fpu_store : std_logic;
		fpu       : std_logic;
		fpu_op    : fp_operation_type;
		valid     : std_logic;
	end record;

	type fp_dec_reg_type is record
		instr     : std_logic_vector(31 downto 0);
		imm       : std_logic_vector(31 downto 0);
		imm_i     : std_logic_vector(31 downto 0);
		imm_s     : std_logic_vector(31 downto 0);
		opcode    : std_logic_vector(6 downto 0);
		funct7    : std_logic_vector(6 downto 0);
		rm        : std_logic_vector(2 downto 0);
		int_rden1 : std_logic;
		int_wren  : std_logic;
		fpu_rden1 : std_logic;
		fpu_rden2 : std_logic;
		fpu_rden3 : std_logic;
		fpu_wren  : std_logic;
		fpu_load  : std_logic;
		fpu_store : std_logic;
		fpu       : std_logic;
		fpu_op    : fp_operation_type;
		valid     : std_logic;
	end record;

	type fp_for_in_type is record
		reg_en1   : std_logic;
		reg_addr1 : std_logic_vector(4 downto 0);
		reg_data1 : std_logic_vector(31 downto 0);
		reg_en2   : std_logic;
		reg_addr2 : std_logic_vector(4 downto 0);
		reg_data2 : std_logic_vector(31 downto 0);
		reg_en3   : std_logic;
		reg_addr3 : std_logic_vector(4 downto 0);
		reg_data3 : std_logic_vector(31 downto 0);
		exe_en    : std_logic;
		exe_addr  : std_logic_vector(4 downto 0);
		exe_data  : std_logic_vector(31 downto 0);
		mem_en    : std_logic;
		mem_addr  : std_logic_vector(4 downto 0);
		mem_data  : std_logic_vector(31 downto 0);
	end record;

	type fp_for_out_type is record
		data1 : std_logic_vector(31 downto 0);
		data2 : std_logic_vector(31 downto 0);
		data3 : std_logic_vector(31 downto 0);
	end record;

	type fp_exe_in_type is record
		data1  : std_logic_vector(31 downto 0);
		data2  : std_logic_vector(31 downto 0);
		data3  : std_logic_vector(31 downto 0);
		op     : fp_operation_type;
		fmt    : std_logic_vector(1 downto 0);
		rm     : std_logic_vector(2 downto 0);
		enable : std_logic;
	end record;

	type fp_exe_out_type is record
		result : std_logic_vector(31 downto 0);
		flags  : std_logic_vector(4 downto 0);
		ready  : std_logic;
	end record;

	type fp_rnd_in_type is record
		sig  : std_logic;
		expo : integer range -1023 to 1023;
		mant : std_logic_vector(24 downto 0);
		rema : std_logic_vector(1 downto 0);
		fmt  : std_logic_vector(1 downto 0);
		rm   : std_logic_vector(2 downto 0);
		grs  : std_logic_vector(2 downto 0);
		snan : std_logic;
		qnan : std_logic;
		dbz  : std_logic;
		inf  : std_logic;
		zero : std_logic;
	end record;

	constant init_fp_rnd_in : fp_rnd_in_type := (
		sig  => '0',
		expo => 0,
		mant => (others => '0'),
		rema => (others => '0'),
		fmt  => (others => '0'),
		rm   => (others => '0'),
		grs  => (others => '0'),
		snan => '0',
		qnan => '0',
		dbz  => '0',
		inf  => '0',
		zero => '0'
	);

	type fp_rnd_out_type is record
		result : std_logic_vector(31 downto 0);
		flags  : std_logic_vector(4 downto 0);
	end record;

	type fp_fma_in_type is record
		data1  : std_logic_vector(32 downto 0);
		data2  : std_logic_vector(32 downto 0);
		data3  : std_logic_vector(32 downto 0);
		class1 : std_logic_vector(9 downto 0);
		class2 : std_logic_vector(9 downto 0);
		class3 : std_logic_vector(9 downto 0);
		op     : fp_operation_type;
		fmt    : std_logic_vector(1 downto 0);
		rm     : std_logic_vector(2 downto 0);
	end record;

	type fp_fma_out_type is record
		fp_rnd : fp_rnd_in_type;
		ready  : std_logic;
	end record;

	type fp_fma_reg_type_0 is record
        fmt          : std_logic_vector(1 downto 0);
        rm           : std_logic_vector(2 downto 0);
        
        snan         : std_logic;
		qnan         : std_logic;
		inf          : std_logic;
		neg          : std_logic;
        
		mantissa_a   : std_logic_vector(23 downto 0);
		mantissa_b   : std_logic_vector(23 downto 0);
		mantissa_c   : std_logic_vector(23 downto 0);
        exponent_mul : signed(10 downto 0);
        exponent_a   : std_logic_vector(8 downto 0);
        exponent_b   : std_logic_vector(8 downto 0);
        exponent_c   : std_logic_vector(8 downto 0);
        
        sign_mul     : std_logic;
        sign_add     : std_logic;
        
        ready        : std_logic;
	end record;

	constant init_fp_fma_reg_0 : fp_fma_reg_type_0 := (
		fmt          => (others => '0'),
		rm           => (others => '0'),
        
		snan         => '0',
		qnan         => '0',
		inf          => '0',
		neg          => '0',
        
		mantissa_a   => (others => '0'),
		mantissa_b   => (others => '0'),
		mantissa_c   => (others => '0'),
        exponent_mul => (others => '0'),
        exponent_a   => (others => '0'),
        exponent_b   => (others => '0'),
        exponent_c   => (others => '0'),
        
        sign_mul     => '0',
		sign_add     => '0',
		
		ready        => '0'
	);
    
	type fp_fma_reg_type_1 is record
		fmt          : std_logic_vector(1 downto 0);
		rm           : std_logic_vector(2 downto 0);
		snan         : std_logic;
		qnan         : std_logic;
		dbz          : std_logic;
		inf          : std_logic;
		zero         : std_logic;
		neg          : std_logic;
		sign_mul     : std_logic;
		exponent_mul : signed(10 downto 0);
		mantissa_mul : std_logic_vector(76 downto 0);
		sign_add     : std_logic;
		exponent_add : signed(10 downto 0);
		mantissa_add : std_logic_vector(76 downto 0);
		exponent_neg : std_logic;
		ready        : std_logic;
        
        mantissa_mac : std_logic_vector(76 downto 0);
        exponent_mac : signed(10 downto 0);
	end record;

	constant init_fp_fma_reg_1 : fp_fma_reg_type_1 := (
		fmt          => (others => '0'),
		rm           => (others => '0'),
		snan         => '0',
		qnan         => '0',
		dbz          => '0',
		inf          => '0',
		zero         => '0',
		neg          => '0',
		sign_mul     => '0',
		exponent_mul => (others => '0'),
		mantissa_mul => (others => '0'),
		sign_add     => '0',
		exponent_add => (others => '0'),
		mantissa_add => (others => '0'),
		exponent_neg => '0',
		ready        => '0',
        
        exponent_mac => (others => '0'),
        mantissa_mac => (others => '0')
	);

	type fp_fma_reg_type_2 is record
		sign_rnd     : std_logic;
		exponent_rnd : integer range -1023 to 1023;
		mantissa_rnd : std_logic_vector(24 downto 0);
		fmt          : std_logic_vector(1 downto 0);
		rm           : std_logic_vector(2 downto 0);
		grs          : std_logic_vector(2 downto 0);
		snan         : std_logic;
		qnan         : std_logic;
		dbz          : std_logic;
		inf          : std_logic;
		zero         : std_logic;
		ready        : std_logic;
	end record;

	constant init_fp_fma_reg_2 : fp_fma_reg_type_2 := (
		sign_rnd     => '0',
		exponent_rnd => 0,
		mantissa_rnd => (others => '0'),
		fmt          => (others => '0'),
		rm           => (others => '0'),
		grs          => (others => '0'),
		snan         => '0',
		qnan         => '0',
		dbz          => '0',
		inf          => '0',
		zero         => '0',
		ready        => '0'
	);

	type fp_mac_in_type is record
		a  : signed(26 downto 0);
		b  : signed(26 downto 0);
		c  : signed(26 downto 0);
		op : std_logic;
	end record;

	type fp_mac_out_type is record
		d : signed(51 downto 0);
	end record;

	type fp_fdiv_in_type is record
		data1  : std_logic_vector(32 downto 0);
		data2  : std_logic_vector(32 downto 0);
		class1 : std_logic_vector(9 downto 0);
		class2 : std_logic_vector(9 downto 0);
		op     : fp_operation_type;
		fmt    : std_logic_vector(1 downto 0);
		rm     : std_logic_vector(2 downto 0);
	end record;

	type fp_fdiv_out_type is record
		fp_rnd : fp_rnd_in_type;
		ready  : std_logic;
	end record;

	type fp_fdiv_functional_reg_type is record
		state             : f_state_type;
		istate            : natural range 0 to 15;
		fmt               : std_logic_vector(1 downto 0);
		rm                : std_logic_vector(2 downto 0);
		a                 : std_logic_vector(32 downto 0);
		b                 : std_logic_vector(32 downto 0);
		class_a           : std_logic_vector(9 downto 0);
		class_b           : std_logic_vector(9 downto 0);
		snan              : std_logic;
		qnan              : std_logic;
		inf               : std_logic;
		dbz               : std_logic;
		zero              : std_logic;
		op                : std_logic;
		index             : natural range 0 to 127;
		qa                : signed(26 downto 0);
		qb                : signed(26 downto 0);
		q0                : signed(26 downto 0);
		q1                : signed(26 downto 0);
		r0                : signed(51 downto 0);
		r1                : signed(51 downto 0);
		y                 : signed(26 downto 0);
		y0                : signed(26 downto 0);
		y1                : signed(26 downto 0);
		y2                : signed(26 downto 0);
		h0                : signed(26 downto 0);
		h1                : signed(26 downto 0);
		e0                : signed(26 downto 0);
		e1                : signed(26 downto 0);
		sign_fdiv         : std_logic;
		exponent_fdiv     : integer range -1023 to 1023;
		mantissa_fdiv     : std_logic_vector(55 downto 0);
		counter_fdiv      : integer range 0 to 1;
		exponent_bias     : integer range 0 to 127;
		sign_rnd          : std_logic;
		exponent_rnd      : integer range -1023 to 1023;
		mantissa_rnd      : std_logic_vector(24 downto 0);
		remainder_rnd     : std_logic_vector(1 downto 0);
		counter_rnd       : integer range 0 to 31;
		grs               : std_logic_vector(2 downto 0);
		odd               : std_logic;
		result            : std_logic_vector(31 downto 0);
		flags             : std_logic_vector(4 downto 0);
		ready             : std_logic;
	end record;

	constant init_fp_fdiv_functional_reg : fp_fdiv_functional_reg_type := (
		state             => F0,
		istate            => 0,
		fmt               => (others => '0'),
		rm                => (others => '0'),
		a                 => (others => '0'),
		b                 => (others => '0'),
		class_a           => (others => '0'),
		class_b           => (others => '0'),
		snan              => '0',
		qnan              => '0',
		inf               => '0',
		dbz               => '0',
		zero              => '0',
		op                => '0',
		index             => 0,
		qa                => (others => '0'),
		qb                => (others => '0'),
		q0                => (others => '0'),
		q1                => (others => '0'),
		r0                => (others => '0'),
		r1                => (others => '0'),
		y                 => (others => '0'),
		y0                => (others => '0'),
		y1                => (others => '0'),
		y2                => (others => '0'),
		h0                => (others => '0'),
		h1                => (others => '0'),
		e0                => (others => '0'),
		e1                => (others => '0'),
		sign_fdiv         => '0',
		exponent_fdiv     => 0,
		mantissa_fdiv     => (others => '0'),
		counter_fdiv      => 0,
		exponent_bias     => 0,
		sign_rnd          => '0',
		exponent_rnd      => 0,
		mantissa_rnd      => (others => '0'),
		remainder_rnd     => (others => '0'),
		counter_rnd       => 0,
		grs               => (others => '0'),
		odd               => '0',
		result            => (others => '0'),
		flags             => (others => '0'),
		ready             => '0'
	);

	type fp_fdiv_fixed_reg_type is record
		state             : f_state_type;
		istate            : natural range 0 to 31;
		fmt               : std_logic_vector(1 downto 0);
		rm                : std_logic_vector(2 downto 0);
		a                 : std_logic_vector(32 downto 0);
		b                 : std_logic_vector(32 downto 0);
		class_a           : std_logic_vector(9 downto 0);
		class_b           : std_logic_vector(9 downto 0);
		snan              : std_logic;
		qnan              : std_logic;
		inf               : std_logic;
		dbz               : std_logic;
		zero              : std_logic;
		op                : std_logic;
		qa                : signed(26 downto 0);
		qb                : signed(26 downto 0);
		q                 : std_logic_vector(25 downto 0);
		m                 : std_logic_vector(27 downto 0);
		r                 : std_logic_vector(27 downto 0);
		e                 : std_logic_vector(27 downto 0);
		sign_fdiv         : std_logic;
		exponent_fdiv     : integer range -1023 to 1023;
		mantissa_fdiv     : std_logic_vector(77 downto 0);
		counter_fdiv      : integer range 0 to 1;
		exponent_bias     : integer range 0 to 127;
		sign_rnd          : std_logic;
		exponent_rnd      : integer range -1023 to 1023;
		mantissa_rnd      : std_logic_vector(24 downto 0);
		remainder_rnd     : std_logic_vector(1 downto 0);
		counter_rnd       : integer range 0 to 31;
		grs               : std_logic_vector(2 downto 0);
		odd               : std_logic;
		result            : std_logic_vector(31 downto 0);
		flags             : std_logic_vector(4 downto 0);
		ready             : std_logic;
	end record;

	constant init_fp_fdiv_fixed_reg : fp_fdiv_fixed_reg_type := (
		state             => F0,
		istate            => 0,
		fmt               => (others => '0'),
		rm                => (others => '0'),
		a                 => (others => '0'),
		b                 => (others => '0'),
		class_a           => (others => '0'),
		class_b           => (others => '0'),
		snan              => '0',
		qnan              => '0',
		inf               => '0',
		dbz               => '0',
		zero              => '0',
		op                => '0',
		qa                => (others => '0'),
		qb                => (others => '0'),
		q                 => (others => '0'),
		m                 => (others => '0'),
		r                 => (others => '0'),
		e                 => (others => '0'),
		sign_fdiv         => '0',
		exponent_fdiv     => 0,
		mantissa_fdiv     => (others => '0'),
		counter_fdiv      => 0,
		exponent_bias     => 0,
		sign_rnd          => '0',
		exponent_rnd      => 0,
		mantissa_rnd      => (others => '0'),
		remainder_rnd     => (others => '0'),
		counter_rnd       => 0,
		grs               => (others => '0'),
		odd               => '0',
		result            => (others => '0'),
		flags             => (others => '0'),
		ready             => '0'
	);

	type fp_cmp_in_type is record
		data1  : std_logic_vector(32 downto 0);
		data2  : std_logic_vector(32 downto 0);
		rm     : std_logic_vector(2 downto 0);
		class1 : std_logic_vector(9 downto 0);
		class2 : std_logic_vector(9 downto 0);
	end record;

	type fp_cmp_out_type is record
		result : std_logic_vector(31 downto 0);
		flags  : std_logic_vector(4 downto 0);
	end record;

	type fp_max_in_type is record
		data1  : std_logic_vector(31 downto 0);
		data2  : std_logic_vector(31 downto 0);
		ext1   : std_logic_vector(32 downto 0);
		ext2   : std_logic_vector(32 downto 0);
		fmt    : std_logic_vector(1 downto 0);
		rm     : std_logic_vector(2 downto 0);
		class1 : std_logic_vector(9 downto 0);
		class2 : std_logic_vector(9 downto 0);
	end record;

	type fp_max_out_type is record
		result : std_logic_vector(31 downto 0);
		flags  : std_logic_vector(4 downto 0);
	end record;

	type fp_sgnj_in_type is record
		data1 : std_logic_vector(31 downto 0);
		data2 : std_logic_vector(31 downto 0);
		fmt   : std_logic_vector(1 downto 0);
		rm    : std_logic_vector(2 downto 0);
	end record;

	type fp_sgnj_out_type is record
		result : std_logic_vector(31 downto 0);
	end record;

	type fp_ext_in_type is record
		data : std_logic_vector(31 downto 0);
		fmt  : std_logic_vector(1 downto 0);
	end record;

	type fp_ext_out_type is record
		result : std_logic_vector(32 downto 0);
		class  : std_logic_vector(9 downto 0);
	end record;

	type fp_cvt_i2f_in_type is record
		data : std_logic_vector(31 downto 0);
		op   : fp_operation_type;
		fmt  : std_logic_vector(1 downto 0);
		rm   : std_logic_vector(2 downto 0);
	end record;

	type fp_cvt_i2f_out_type is record
		fp_rnd : fp_rnd_in_type;
	end record;

	type fp_cvt_f2i_in_type is record
		data  : std_logic_vector(32 downto 0);
		op    : fp_operation_type;
		rm    : std_logic_vector(2 downto 0);
		class : std_logic_vector(9 downto 0);
	end record;

	type fp_cvt_f2i_out_type is record
		result : std_logic_vector(31 downto 0);
		flags  : std_logic_vector(4 downto 0);
	end record;

	type fp_unit_in_type is record
		fp_dec_i  : fp_dec_in_type;
		fp_reg_ri : fp_reg_read_in_type;
		fp_reg_wi : fp_reg_write_in_type;
		fp_for_i  : fp_for_in_type;
		fp_csr_ri : fp_csr_read_in_type;
		fp_csr_wi : fp_csr_write_in_type;
		fp_exe_i  : fp_exe_in_type;
	end record;

	type fp_unit_out_type is record
		fp_dec_o  : fp_dec_out_type;
		fp_reg_o  : fp_reg_out_type;
		fp_for_o  : fp_for_out_type;
		fp_csr_o  : fp_csr_out_type;
		fp_exe_o  : fp_exe_out_type;
	end record;

end package;

package body fp_wire is

	function to_std_logic(
		condition : in boolean
	)
	return std_logic is
	begin
		if condition then
			return '1';
		else
			return '0';
		end if;
	end function to_std_logic;

end fp_wire;
-- args: --std=08 --ieee=synopsys

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lzc_wire.all;
use work.lzc_lib.all;
use work.fp_cons.all;
use work.fp_wire.all;

package fp_lib is

	component fp_dec
		port(
			fp_dec_i : in  fp_dec_in_type;
			fp_dec_o : out fp_dec_out_type
		);
	end component;

	component fp_reg
		port(
			reset     : in  std_logic;
			clock     : in  std_logic;
			fp_reg_ri : in  fp_reg_read_in_type;
			fp_reg_wi : in  fp_reg_write_in_type;
			fp_reg_o  : out fp_reg_out_type
		);
	end component;

	component fp_for
		port(
			fp_for_i : in  fp_for_in_type;
			fp_for_o : out fp_for_out_type
		);
	end component;

	component fp_ext
		port(
			fp_ext_i : in  fp_ext_in_type;
			fp_ext_o : out fp_ext_out_type;
			lzc_o    : in  lzc_32_out_type;
			lzc_i    : out lzc_32_in_type
		);
	end component;

	component fp_cmp
		port(
			fp_cmp_i : in  fp_cmp_in_type;
			fp_cmp_o : out fp_cmp_out_type
		);
	end component;

	component fp_cvt
		port(
			fp_cvt_f2i_i : in  fp_cvt_f2i_in_type;
			fp_cvt_f2i_o : out fp_cvt_f2i_out_type;
			fp_cvt_i2f_i : in  fp_cvt_i2f_in_type;
			fp_cvt_i2f_o : out fp_cvt_i2f_out_type;
			lzc_i        : out lzc_32_in_type;
			lzc_o        : in  lzc_32_out_type
		);
	end component;

	component fp_max
		port(
			fp_max_i : in  fp_max_in_type;
			fp_max_o : out fp_max_out_type
		);
	end component;

	component fp_sgnj
		port(
			fp_sgnj_i : in  fp_sgnj_in_type;
			fp_sgnj_o : out fp_sgnj_out_type
		);
	end component;

	component fp_rnd
		port(
			fp_rnd_i : in  fp_rnd_in_type;
			fp_rnd_o : out fp_rnd_out_type
		);
	end component;

	component fp_fma
		port(
			reset    : in  std_logic;
			clock    : in  std_logic;
			fp_fma_i : in  fp_fma_in_type;
			fp_fma_o : out fp_fma_out_type;
			lzc_o    : in  lzc_128_out_type;
			lzc_i    : out lzc_128_in_type
		);
	end component;

	component fp_mac
		port(
			fp_mac_i : in  fp_mac_in_type;
			fp_mac_o : out fp_mac_out_type
		);
	end component;

	component fp_fdiv
		port(
			reset     : in  std_logic;
			clock     : in  std_logic;
			fp_fdiv_i : in  fp_fdiv_in_type;
			fp_fdiv_o : out fp_fdiv_out_type;
			fp_mac_i  : out fp_mac_in_type;
			fp_mac_o  : in  fp_mac_out_type
		);
	end component;

	component fp_exe
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
	end component;

end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpupack is
	-- Data width of floating-point number. Deafult: 32
	constant FP_WIDTH : integer := 32;
	
	-- Data width of fraction. Deafult: 23
	constant FRAC_WIDTH : integer := 23;
	
	-- Data width of exponent. Deafult: 8
	constant EXP_WIDTH : integer := 8;
end fpupack;

package body fpupack is	
end fpupack;
