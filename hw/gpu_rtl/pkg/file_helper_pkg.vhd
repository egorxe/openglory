library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.float_pkg.all;

use work.gpu_pkg.all;
    
package file_helper_pkg is

type BinaryFile is file of character;

function ToChar (slv8 : std_logic_vector (7 downto 0)) return character;
procedure WriteFloat(file f : BinaryFile; x : float32);
procedure ReadFloat(file f : BinaryFile; x : out float32);
procedure WriteUint32(file f : BinaryFile; constant v : vec32);
procedure ReadUint32(file f : BinaryFile; v : out vec32);

end file_helper_pkg;

package body file_helper_pkg is

function ToChar (slv8 : std_logic_vector (7 downto 0)) return character is
    constant XMAP : integer := 0;
    variable temp : integer := 0;
begin
    for i in slv8'range loop
        temp:=temp*2;
        case slv8(i) is
            when '0' | 'L'  => null;
            when '1' | 'H'  => temp :=temp+1;
            when others     => temp :=temp+XMAP;
        end case;
    end loop;
    return character'val(temp);
end ToChar;

procedure WriteUint32(file f : BinaryFile; constant v : vec32) is 
begin
    write(f, ToChar(v(7 downto 0)));
    write(f, ToChar(v(15 downto 8)));
    write(f, ToChar(v(23 downto 16)));
    write(f, ToChar(v(31 downto 24)));
end procedure;

procedure ReadUint32(file f : BinaryFile; v : out vec32) is 
    variable c : character;
begin
    read(f, c);
    v(7 downto 0) := to_slv(character'pos(c), 8);
    read(f, c);
    v(15 downto 8) := to_slv(character'pos(c), 8);
    read(f, c);
    v(23 downto 16) := to_slv(character'pos(c), 8);
    read(f, c);
    v(31 downto 24) := to_slv(character'pos(c), 8);
end procedure;

procedure WriteFloat(file f : BinaryFile; x : float32) is 
    variable v : vec32;
begin
    v := to_slv(x);
    WriteUint32(f, v);
end procedure;

procedure ReadFloat(file f : BinaryFile; x : out float32) is 
    variable v : vec32;
begin
    ReadUint32(f, v);
    x := to_float(v);
end procedure;

end file_helper_pkg;
