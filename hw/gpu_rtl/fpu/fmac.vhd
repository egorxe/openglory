library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.lzc_wire.all;
    use work.lzc_lib.all;
    use work.fp_cons.all;
    use work.fp_wire.all;
    use work.fp_lib.all;

entity fmac is
	port(
		clk_i       : in  std_logic;
		rst_i       : in  std_logic;
		stb_i       : in  std_logic;
		a_i         : in  std_logic_vector(31 downto 0);
		b_i         : in  std_logic_vector(31 downto 0);
		c_i         : in  std_logic_vector(31 downto 0);
		result_o    : out std_logic_vector(31 downto 0);
		ready_o     : out std_logic
	);
end fmac;

architecture behavior of fmac is

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

	signal fp_fma_i  : fp_fma_in_type;
	signal fp_fma_o  : fp_fma_out_type;

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

	fp_rnd_comp : fp_rnd
		port map(
			fp_rnd_i => fp_rnd_i,
			fp_rnd_o => fp_rnd_o
		);

	fp_fma_comp : fp_fma
		port map(
			reset    => not rst_i,
			clock    => clk_i,
			fp_fma_i => fp_fma_i,
			fp_fma_o => fp_fma_o,
			lzc_o    => lzc_128_o,
			lzc_i    => lzc_128_i
		);

process(all)
    variable op    : fp_operation_type;
    variable fmt   : std_logic_vector(1 downto 0);
    variable rm    : std_logic_vector(2 downto 0);
        
    variable ext1 : std_logic_vector(32 downto 0);
    variable ext2 : std_logic_vector(32 downto 0);
    variable ext3 : std_logic_vector(32 downto 0);

    variable class1 : std_logic_vector(9 downto 0);
    variable class2 : std_logic_vector(9 downto 0);
    variable class3 : std_logic_vector(9 downto 0);
begin

    ready_o  <= '0';

    op.fadd := '0';
    op.fsub := '0';
    op.fmul := '0';
    op.fdiv := '0';
    op.fcvt_f2i := '0';
    op.fcvt_i2f := '0';
    op.fcvt_op := "00";
    fmt := "00";
    rm := "000";    -- near even
    op.fmsub := '0';
    op.fnmadd := '0';
    op.fnmsub := '0';
    op.fsqrt := '0';
    op.fsgnj := '0';
    op.fcmp := '0';
    op.fmax := '0';
    op.fclass := '0';
    op.fmv_i2f := '0';
    op.fmv_f2i := '0';
    
    fp_rnd_i <= init_fp_rnd_in;
    
    op.fmadd := stb_i;

    fp_ext1_i.data <= a_i;
    fp_ext1_i.fmt <= fmt;
    fp_ext2_i.data <= b_i;
    fp_ext2_i.fmt <= fmt;
    fp_ext3_i.data <= c_i;
    fp_ext3_i.fmt <= fmt;

    ext1 := fp_ext1_o.result;
    ext2 := fp_ext2_o.result;
    ext3 := fp_ext3_o.result;

    class1 := fp_ext1_o.class;
    class2 := fp_ext2_o.class;
    class3 := fp_ext3_o.class;

    fp_fma_i.data1 <= ext1;
    fp_fma_i.data2 <= ext2;
    fp_fma_i.data3 <= ext3;
    fp_fma_i.class1 <= class1;
    fp_fma_i.class2 <= class2;
    fp_fma_i.class3 <= class3;
    fp_fma_i.op <= op;
    fp_fma_i.fmt <= fmt;
    fp_fma_i.rm <= rm;
    
    fp_rnd_i <= fp_fma_o.fp_rnd;
    result_o <= fp_rnd_o.result;
    ready_o  <= fp_fma_o.ready;

end process;

end architecture;
