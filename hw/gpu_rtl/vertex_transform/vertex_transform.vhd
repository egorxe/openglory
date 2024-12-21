------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Vertex coordinate transformation stage
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_vertex_pkg.all;
use work.gpu_pkg.all;

entity vertex_transform is
    generic (
        SCREEN_WIDTH  : integer := 640;
        SCREEN_HEIGHT : integer := 480;
        VERBOSE       : boolean := False
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;

        data_i  : in  vec32;
        valid_i : in  std_logic; --input handshake mechanism
        ready_o : out std_logic; --input handshake mechanism

        data_o  : out vec32;
        valid_o : out std_logic; --output handshake mechanism
        ready_i : in  std_logic; --output handshake mechanism
        last_o  : out std_logic  --only for AXI-Stream wrapper
    );
end vertex_transform;

architecture rtl of vertex_transform is

    constant MODEL_MATRIX_INIT  : M44 := M44_ID;
    constant PROJ_MATRIX_INIT   : M44 := M44_ID;
    constant VIEWPORT_INIT : viewport_params := (
        ZERO32, ZERO32, 
        to_vec32(real(SCREEN_WIDTH) / 2.0), 
        to_vec32(real(SCREEN_HEIGHT) / 2.0), 
        to_vec32(0.5), to_vec32(0.5)
    );

    type module_state_type is (READING, MODELMATRIX_MUL, PROJECTION_MUL);

    type reg_type is record
        preclip_state       : module_state_type;
        reading_state       : integer range 0 to 5;
        calc_state          : integer range 0 to 1;
        
        data                : vec32;
        cmd                 : vec32;
        data_out            : vec32;
        valid_out           : std_logic;
        last_out            : std_logic;
        ready_out           : std_logic;
        
        vertex_counter      : integer range 0 to 2;
        vertex_data_counter : integer range 0 to 255; -- to pass arbitrary commands
        input_counter       : integer range 0 to 1;
        row_read_cnt        : integer range 0 to 3;
        col_read_cnt        : integer range 0 to 5;
        
        coords              : V4;
        vertex_attributes   : vertex_attr_type;
        attrib_num          : attrib_num_type;  -- attributes per vertex minus 1
        clip_vertex_ready   : std_logic;
        
        mul_set             : std_logic;
        mul_start           : std_logic;
        
        model_matrix        : M44;
        proj_matrix         : M44;
        matrix              : M44;
        
        viewport            : viewport_params;
    end record;

    constant REG_RST : reg_type := (
            READING, 0, 0,
            ZERO32, ZERO32, ZERO32, '0', '0', '0',
            0, 0, 0, 0, 0,
            (others => ZERO32), ZERO_VERTEX_ATTR, 0, '0',
            '0', '0',
            MODEL_MATRIX_INIT, PROJ_MATRIX_INIT, M44_ID,
            VIEWPORT_INIT
        );

    signal reg_in, reg : reg_type;

    signal s_mul_result     : V4;
    signal s_mul_res_ready  : std_logic;
    signal s_mul_load_ready : std_logic;
    
    signal stage_free       : std_logic;
    
    signal clip_busy        : std_logic;
    signal clip_input_busy  : std_logic;
    signal clip_valid       : std_logic;
    signal clip_last        : std_logic;
    signal clip_data        : vec32;
    
    procedure verbose_print(str : string) is
    begin
        if VERBOSE then
            report str;
        end if;
    end;

begin

    stage_free  <= (not clip_busy) and (not reg.clip_vertex_ready);
    valid_o     <= reg_in.valid_out or clip_valid;
    last_o      <= reg_in.last_out;
    data_o      <= reg_in.data_out;
    ready_o     <= reg_in.ready_out;
    assert (not ((reg_in.valid_out='1') and (clip_valid='1'))) severity failure;

    sync : process (clk_i)
    begin
        if (Rising_edge(clk_i)) then
            if (rst_i = '1') then
                reg <= REG_RST;
            else
                reg <= reg_in;
            end if;
        end if;
    end process;

    async : process (all)
        variable var : reg_type;
    begin

        var                := reg;
        
        var.valid_out   := '0';
        var.last_out    := '0';
        var.ready_out   := '0';

        var.mul_start   := '0';
        var.mul_set     := '0';
        
        var.clip_vertex_ready := '0';

        case (reg.preclip_state) is
            when READING =>
                case (reg.input_counter) is
                    -- request next stream word
                    when 0 =>
                        var.ready_out := '1';
                        if (valid_i = '1') then
                            var.input_counter := 1;
                            var.data := data_i;
                        end if;

                    -- process stream word
                    when 1 =>
                        -- if any processing hasn't been started yet
                        case (reg.reading_state) is
                            when 0 =>
                                case (reg.data) is
                                    when GPU_PIPE_CMD_POLY_VERTEX3 =>
                                        var.cmd := GPU_PIPE_CMD_POLY_VERTEX4;
                                        var.attrib_num := NCOLORS-1;
                                        verbose_print("Polygon vertex READING started");
                                        if (ready_i = '1') then
                                            var.input_counter := 0;
                                            var.reading_state := 1;
                                        end if;
                                        
                                    when GPU_PIPE_CMD_POLY_VERTEX3TC =>
                                        var.cmd := GPU_PIPE_CMD_POLY_VERTEX4TC;
                                        var.attrib_num := NCOLORS+NTEXCOORD-1;
                                        verbose_print("Polygon vertex with texcoord READING started");
                                        if (ready_i = '1') then
                                            var.input_counter := 0;
                                            var.reading_state := 1;
                                        end if;
    
                                    when GPU_PIPE_CMD_MODEL_MATRIX =>
                                        verbose_print("Model matrix READING started");
                                        var.input_counter := 0;
                                        var.reading_state := 2;
    
                                    when GPU_PIPE_CMD_PROJ_MATRIX =>
                                        verbose_print("Projection matrix READING started");
                                        var.input_counter := 0;
                                        var.reading_state := 3;
    
                                    when GPU_PIPE_CMD_VIEWPORT_PARAMS =>
                                        if stage_free then
                                            verbose_print("Viewport params READING started");
                                            var.input_counter := 0;
                                            var.reading_state := 4;
                                        end if;
    
                                    when others =>
                                        -- send unknown commands to next stage with all arguments
                                        if stage_free then
                                            var.data_out := reg.data;
                                            var.valid_out := '1';
                                            var.last_out := to_sl(cmd_num_args(reg.data) = 0);
                                            var.cmd := reg.data;
                                            -- synthesis translate_off
                                            verbose_print("Vertex transform passing command " & to_hstring(reg.data) & " to next stage");
                                            -- synthesis translate_on
                                            if (ready_i = '1') then
                                                var.input_counter := 0;
                                                if cmd_num_args(reg.data) = 0 then
                                                    var.reading_state := 0;
                                                else
                                                    var.reading_state := 5;
                                                end if;
                                            end if;
                                        end if;
                                end case;

                            when 1 =>
                                -- reading of polygon data
                                var.input_counter := 0;

                                if (reg.vertex_data_counter < NCOORDS + reg.attrib_num) then
                                    if (reg.vertex_data_counter < NCOORDS) then
                                        var.coords(reg.vertex_data_counter) := reg.data;
                                    else
                                        var.vertex_attributes(reg.vertex_data_counter - NCOORDS) := reg.data;
                                    end if;
                                    var.vertex_data_counter := reg.vertex_data_counter + 1;

                                else
                                    var.vertex_attributes(reg.vertex_data_counter - NCOORDS) := reg.data;
                                        
                                    var.vertex_data_counter := 0;
                                    var.preclip_state       := MODELMATRIX_MUL;
                                    if (reg.vertex_counter = NVERTICES-1) then
                                        var.vertex_counter := 0;
                                        var.reading_state := 0;
                                    else
                                        var.vertex_counter := reg.vertex_counter + 1;
                                    end if;
                                end if;

                            when 2 | 3 =>
                                -- reading model/projection matrix
                                var.input_counter := 0;
                                if reg.reading_state = 2 then
                                    var.model_matrix(reg.row_read_cnt)(reg.col_read_cnt) := reg.data;
                                else
                                    var.proj_matrix(reg.row_read_cnt)(reg.col_read_cnt) := reg.data;
                                end if;
                                var.col_read_cnt := reg.col_read_cnt + 1;
                                
                                if reg.col_read_cnt = 3 then
                                    var.col_read_cnt := 0;

                                    if reg.row_read_cnt = 3 then
                                        var.reading_state := 0;
                                        var.row_read_cnt := 0;
                                    else
                                        var.row_read_cnt := reg.row_read_cnt + 1;
                                    end if;
                                end if;
                                
                            when 4 =>
                                -- reading viewport params
                                var.input_counter := 0;
                                case reg.col_read_cnt is
                                    when 0 =>
                                        var.viewport.x0 := reg.data;
                                        var.col_read_cnt := reg.col_read_cnt + 1;
                                    when 1 =>
                                        var.viewport.y0 := reg.data;
                                        var.col_read_cnt := reg.col_read_cnt + 1;
                                    when 2 =>
                                        var.viewport.w2 := reg.data;
                                        var.col_read_cnt := reg.col_read_cnt + 1;
                                    when 3 =>
                                        var.viewport.h2 := reg.data;
                                        var.col_read_cnt := reg.col_read_cnt + 1;
                                    when 4 =>
                                        var.viewport.fn2 := reg.data;
                                        var.col_read_cnt := reg.col_read_cnt + 1;
                                    when 5 =>
                                        var.viewport.nf2 := reg.data;
                                        var.col_read_cnt := 0;
                                        var.reading_state := 0;
                                end case;
                                
                            when 5 =>
                                -- send all unknown command arguments to next stage
                                var.data_out  := reg.data;
                                var.valid_out := '1';
                                var.last_out := to_sl(var.vertex_data_counter = cmd_num_args(reg.cmd));
                            
                                if (ready_i = '1') then
                                    var.vertex_data_counter := reg.vertex_data_counter + 1;
                                    var.input_counter := 0;
                                    
                                    if var.vertex_data_counter = cmd_num_args(reg.cmd) then
                                        var.reading_state := 0;
                                        var.vertex_data_counter := 0;
                                    end if;
                                end if;

                        end case;

                end case;

            -- Model matrix transform
            when MODELMATRIX_MUL =>
                case (reg.calc_state) is
                    when 0 =>
                        var.calc_state := 1;
                        --assign_V3_to_V4(var.w_coords, reg.coords);
                        var.coords(3) := to_slv(1.0);
                        var.matrix      := reg.model_matrix;
                        var.mul_set     := '1';
                        var.mul_start   := '1';
                        
                    when others =>
                        if (s_mul_res_ready = '1') then
                            var.coords       := s_mul_result;
                            var.calc_state   := 0;
                            var.preclip_state := PROJECTION_MUL;
                        end if;
                end case;

            -- Projection transform
            when PROJECTION_MUL => 
                case (reg.calc_state) is
                    when 0 =>
                        var.calc_state := 1;
                        var.matrix     := reg.proj_matrix;
                        var.mul_set     := '1';
                        var.mul_start   := '1';

                    when others =>
                        if (s_mul_res_ready = '1') and (clip_input_busy = '0') then
                            var.coords  := s_mul_result;
                            var.calc_state   := 0;
                            var.preclip_state := READING;
                            var.clip_vertex_ready := '1';
                        end if;
                end case;
        end case;
        
        -- connect final stage stream outputs
        if clip_valid then
            var.data_out := clip_data;
            var.last_out := clip_last;
        end if;

        reg_in <= var;
    end process;
    
    -- Second trasformation stage performing clipping, NDC and viewport transforms
    clip : entity work.clipping_viewport 
    port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
                             
            vertex_i        => ((reg.coords(0), reg.coords(1), reg.coords(2), reg.coords(3)), reg.vertex_attributes),
            vertex_ready_i  => reg.clip_vertex_ready,
            busy_o          => clip_busy,
            input_busy_o    => clip_input_busy,
                             
            viewport_i      => reg.viewport,
            cmd_i           => reg.cmd,
            attrib_num_i    => reg.attrib_num,
                             
            data_o          => clip_data,
            valid_o         => clip_valid,
            last_o          => clip_last,
            ready_i         => ready_i
    );

    M4_mul_V4_inst : entity work.M4_mul_V4
        port map (
            rst_i          => rst_i,
            clk_i          => clk_i,
            matrix_i       => reg_in.matrix,
            vector_i       => reg_in.coords,
            vector_o       => s_mul_result,
            set_i          => reg_in.mul_set,
            start_i        => reg_in.mul_start,
            result_ready_o => s_mul_res_ready,
            load_ready_o   => s_mul_load_ready
        );

end architecture rtl;
