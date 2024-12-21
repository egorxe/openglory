library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gpu_pkg.all;
use work.rast_pipe_pkg.all;
    
use std.env.all;

entity rasterizer_axis_type_wrapper_tb is
end;

architecture bench of rasterizer_axis_type_wrapper_tb is
    -- Clock period
    constant clk_period : time := 10 ns;
    -- Generics
    -- Ports
    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';
    signal axis_mosi_i : global_axis_mosi_type := AXIS_MOSI_DEFAULT;
    signal axis_miso_o : global_axis_miso_type;
    signal axis_mosi_o : global_axis_mosi_type;
    signal axis_miso_i : global_axis_miso_type := AXIS_MISO_DEFAULT;

    constant polygon    : polygon_type := (
            v => (
                (to_vec32(250.0), to_vec32(250.0), to_vec32(0.1), to_vec32(1.0), to_vec32(1.0), to_vec32(0.0), to_vec32(0.0), to_vec32(0.0)), 
                (to_vec32(250.0), to_vec32(253.5), to_vec32(0.1), to_vec32(2.0), to_vec32(0.0), to_vec32(1.0), to_vec32(0.0), to_vec32(0.0)), 
                (to_vec32(253.5), to_vec32(250.0), to_vec32(0.1), to_vec32(4.0), to_vec32(0.0), to_vec32(0.0), to_vec32(1.0), to_vec32(0.0))
            )
        ); 
begin

    rasterizer_axis_type_wrapper_inst : entity work.rasterizer_axis_type_wrapper
    port map (
        clk_i => clk_i,
        rst_i => rst_i,
        axis_mosi_i => axis_mosi_i,
        axis_miso_o => axis_miso_o,
        axis_mosi_o => axis_mosi_o,
        axis_miso_i => axis_miso_i
    );

    clk_i <= not clk_i after clk_period/2;

    load : process
	begin
		rst_i <= '1';
		axis_mosi_i.axis_tdata <= (others => '0');
		axis_mosi_i.axis_tvalid <= '0';
		wait for clk_period*5;

		rst_i <= '0';
        if (axis_miso_o.axis_tready /= '1') then
            wait until axis_miso_o.axis_tready = '1';
        end if;

        frame_loop : for j in 1 to 2 loop
            axis_mosi_i.axis_tdata <= GPU_PIPE_CMD_POLY_VERTEX;
            axis_mosi_i.axis_tvalid <= '1';
            wait for clk_period;
            if (axis_miso_o.axis_tready /= '1') then
                wait until axis_miso_o.axis_tready = '1';
                wait for clk_period;
            end if;
            axis_mosi_i.axis_tvalid <= '0';
            wait for clk_period;

            vertex_loop : for v in 0 to 2 loop
                data_loop : for d in 0 to 7 loop
                    case(d) is
                        when 0 => axis_mosi_i.axis_tdata <= polygon.v(v).x;
                        when 1 => axis_mosi_i.axis_tdata <= polygon.v(v).y;
                        when 2 => axis_mosi_i.axis_tdata <= polygon.v(v).z;
                        when 3 => axis_mosi_i.axis_tdata <= polygon.v(v).w;
                        when 4 => axis_mosi_i.axis_tdata <= polygon.v(v).r;
                        when 5 => axis_mosi_i.axis_tdata <= polygon.v(v).g;
                        when 6 => axis_mosi_i.axis_tdata <= polygon.v(v).b;
                        when others => axis_mosi_i.axis_tdata <= polygon.v(v).a;
                    end case;
                    axis_mosi_i.axis_tvalid <= '1';
                    wait for clk_period;
                    if (axis_miso_o.axis_tready /= '1') then
                        wait until axis_miso_o.axis_tready = '1';
                        wait for clk_period;
                    end if;
                    axis_mosi_i.axis_tvalid <= '0';
                    wait for clk_period;
                end loop;
            end loop;
            
            axis_mosi_i.axis_tdata <= GPU_PIPE_CMD_FRAME_END;
            axis_mosi_i.axis_tvalid <= '1';
            wait for clk_period;
            if (axis_miso_o.axis_tready /= '1') then
                wait until axis_miso_o.axis_tready = '1';
                wait for clk_period;
            end if;
            axis_mosi_i.axis_tvalid <= '0';
            wait for clk_period;
        end loop;

        wait for clk_period*50000;
        finish;

		wait;
	end process;

	read_proc: process
	begin
		axis_miso_i.axis_tready <= '0';
		wait for clk_period;
		axis_miso_i.axis_tready <= '1';
		wait;
	end process;
end;