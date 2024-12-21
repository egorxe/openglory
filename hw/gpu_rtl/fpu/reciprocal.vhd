library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.lzc_wire.all;
    use work.lzc_lib.all;
    use work.fp_cons.all;
    use work.fp_wire.all;
    use work.fp_lib.all;

entity reciprocal is
    port(
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        stb_i       : in  std_logic;
        data_i      : in  std_logic_vector(31 downto 0);
        result_o    : out std_logic_vector(31 downto 0);
        ready_o     : out std_logic
    );
end reciprocal;

architecture behavior of reciprocal is

    signal lzc1_32_i    : lzc_32_in_type;
    signal lzc1_32_o    : lzc_32_out_type;
    signal lzc2_32_i    : lzc_32_in_type;
    signal lzc2_32_o    : lzc_32_out_type;
    
    signal fp_ext1_i    : fp_ext_in_type;
    signal fp_ext1_o    : fp_ext_out_type;
    signal fp_ext2_i    : fp_ext_in_type;
    signal fp_ext2_o    : fp_ext_out_type;

    signal fp_rnd_i     : fp_rnd_in_type;
    signal fp_rnd_o     : fp_rnd_out_type;
    
    signal fp_fdiv_in   : fp_fdiv_in_type;
    signal fp_fdiv_out  : fp_fdiv_out_type;
    
    signal fp_mac_i     : fp_mac_in_type;
    signal fp_mac_o     : fp_mac_out_type;

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

    fp_rnd_comp : fp_rnd
        port map(
            fp_rnd_i => fp_rnd_i,
            fp_rnd_o => fp_rnd_o
        );

    fp_mac_comp : fp_mac
        port map(
            fp_mac_i => fp_mac_i,
            fp_mac_o => fp_mac_o
        );

    fp_fdiv_comp : fp_fdiv
        port map(
            reset     => not rst_i,
            clock     => clk_i,
            fp_fdiv_i => fp_fdiv_in,
            fp_fdiv_o => fp_fdiv_out,
            fp_mac_i  => fp_mac_i,
            fp_mac_o  => fp_mac_o
        );

process(all)
    variable op    : fp_operation_type;
    variable fmt   : std_logic_vector(1 downto 0);
    variable rm    : std_logic_vector(2 downto 0);
        
    variable ext1 : std_logic_vector(32 downto 0);
    variable ext2 : std_logic_vector(32 downto 0);

    variable class1 : std_logic_vector(9 downto 0);
    variable class2 : std_logic_vector(9 downto 0);
begin

    fmt := "00";
    rm := "000";
    op := init_fp_operation;
    op.fdiv := stb_i;
    
    fp_rnd_i <= init_fp_rnd_in;
    
    fp_ext1_i.data  <= ("0" & "01111111" & "00000000000000000000000");  -- 1.0 float
    fp_ext1_i.fmt   <= fmt;
    fp_ext2_i.data  <= data_i;
    fp_ext2_i.fmt   <= fmt;

    ext1 := fp_ext1_o.result;
    ext2 := fp_ext2_o.result;

    class1 := fp_ext1_o.class;
    class2 := fp_ext2_o.class;
    
    fp_fdiv_in.data1    <= ext1;
    fp_fdiv_in.data2    <= ext2;
    fp_fdiv_in.class1   <= class1;
    fp_fdiv_in.class2   <= class2;
    fp_fdiv_in.op       <= op;
    fp_fdiv_in.fmt      <= fmt;
    fp_fdiv_in.rm       <= rm;
    
    fp_rnd_i <= fp_fdiv_out.fp_rnd;
    result_o <= fp_rnd_o.result;
    ready_o  <= fp_fdiv_out.ready;

end process;

end architecture;
