--
-- Copyright (c) 1999-2000 Tony Givargis.  Permission to copy is granted
-- provided that this header remains intact.  This software is provided
-- with no warranties.
--
-- Version : 2.8a
--

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use WORK.I8051_LIB.all;

-------------------------------------------------------------------------------

--
-- rst (active hi) : alu outputs don't car values during reset
-- op_code : defines the alu operation (see I8051_LIB)
-- src_1 : first source operand of the alu
-- src_2 : second source operand of the alu
-- src_3 : third source operand of the alu
-- src_cy : carry into the 7th bit of the alu
-- src_ac : carry into the 4th bit of the alu
-- des_1 : first destination operand of the alu
-- des_2 : second destination operand of the alu
-- des_cy : carry out of the 7th bit of the alu
-- des_ac : carry out of the 4th bit of the alu
-- des_ov : overflow out of the alu
--
entity I8051_ALU is
    port(rst     : in  STD_LOGIC;
         op_code : in  UNSIGNED (3 downto 0);
         src_1   : in  UNSIGNED (7 downto 0);
         src_2   : in  UNSIGNED (7 downto 0);
         src_3   : in  UNSIGNED (7 downto 0);
         src_cy  : in  STD_LOGIC;
         src_ac  : in  STD_LOGIC;
         des_1   : out UNSIGNED (7 downto 0);
         des_2   : out UNSIGNED (7 downto 0);
         des_cy  : out STD_LOGIC;
         des_ac  : out STD_LOGIC;
         des_ov  : out STD_LOGIC);
end I8051_ALU;

-------------------------------------------------------------------------------

architecture BHV of I8051_ALU is

-------------------------------------------------------------------------------

    procedure PCSADD (a : UNSIGNED (15 downto 0);
                      b : UNSIGNED (7 downto 0);
                      r : out UNSIGNED (15 downto 0)) is

        variable v1, v2 : SIGNED (15 downto 0);
    begin
        v1 := SIGNED(a);
        if( b(7) = '1' ) then
            
            v2 := SIGNED(CM_8 & b);
        else
            
            v2 := SIGNED(C0_8 & b);
        end if;
        v1 := v1 + v2;
        r := UNSIGNED(v1);
    end PCSADD;

-------------------------------------------------------------------------------
        
    procedure PCUADD (a : UNSIGNED (15 downto 0);
                      b : UNSIGNED (7 downto 0);
                      r : out UNSIGNED (15 downto 0)) is
    begin
        r := a + b;
    end PCUADD;
    
-------------------------------------------------------------------------------

    procedure DO_ADD (a, b : in  UNSIGNED (7 downto 0);
                      c : in  STD_LOGIC;
                      r : out UNSIGNED (7 downto 0);
                      cy, ac, ov : out STD_LOGIC) is
        
        variable v1, v2, v3, v4 : UNSIGNED (4 downto 0);
        variable v5, v6, v7, v8 : UNSIGNED (3 downto 0);
        variable v9, vA, vB, vC : UNSIGNED (1 downto 0);
    begin

        v1 := "0" & a(3 downto 0);
        v2 := "0" & b(3 downto 0);
        v3 := "0" & "000" & c;
        v4 := v1 + v2 + v3;
        
        v5 := "0" & a(6 downto 4);
        v6 := "0" & b(6 downto 4);
        v7 := "0" & "00" & v4(4);
        v8 := v5 + v6 + v7;

        v9 := "0" & a(7);
        vA := "0" & b(7);
        vB := "0" & v8(3);
        vC := v9 + vA + vB;
        
        r(7) := vC(0);
        r(6) := v8(2);
        r(5) := v8(1);
        r(4) := v8(0);
        r(3) := v4(3);
        r(2) := v4(2);
        r(1) := v4(1);
        r(0) := v4(0);
        cy := vC(1);
        ac := v4(4);
        ov := vC(1) xor v8(3);
    end DO_ADD;

-------------------------------------------------------------------------------
    
    procedure DO_SUB (a, b : in  UNSIGNED (7 downto 0);
                      c : in  STD_LOGIC;
                      r : out UNSIGNED (7 downto 0);
                      cy, ac, ov : out STD_LOGIC) is

        variable v1, v2, v3, v4 : UNSIGNED (4 downto 0);
        variable v5, v6, v7, v8 : UNSIGNED (3 downto 0);
        variable v9, vA, vB, vC : UNSIGNED (1 downto 0);
    begin

        v1 := "1" & a(3 downto 0);
        v2 := "0" & b(3 downto 0);
        v3 := "0" & "000" & c;
        v4 := v1 - v2 - v3;
        
        v5 := "1" & a(6 downto 4);
        v6 := "0" & b(6 downto 4);
        v7 := "0" & "00" & (not v4(4));
        v8 := v5 - v6 - v7;

        v9 := "1" & a(7);
        vA := "0" & b(7);
        vB := "0" & (not v8(3));
        vC := v9 - vA - vB;
        
        r(7) := vC(0);
        r(6) := v8(2);
        r(5) := v8(1);
        r(4) := v8(0);
        r(3) := v4(3);
        r(2) := v4(2);
        r(1) := v4(1);
        r(0) := v4(0);
        cy := not vC(1);
        ac := not v4(4);
        ov := (not vC(1)) xor (not v8(3));
    end DO_SUB;

-------------------------------------------------------------------------------

    procedure DO_MUL(a, b : in UNSIGNED (7 downto 0);
                     r : out UNSIGNED (15 downto 0);
                     ov : out STD_LOGIC) is

        variable v1 : UNSIGNED (15 downto 0);
    begin
        v1 := a * b;
        r := v1;
        if( v1(15 downto 8) /= C0_8 ) then

            ov := '1';
        else
            
            ov := '0';
        end if;
    end DO_MUL;
    
-------------------------------------------------------------------------------

    procedure DO_DIV(a, b : in UNSIGNED (7 downto 0);
                     r : out UNSIGNED (15 downto 0);
                     ov : out STD_LOGIC) is
    
        variable v1 : UNSIGNED (15 downto 0);
        variable v2, v3 : UNSIGNED (8 downto 0);
    begin
        if( b = C0_8 ) then
            
            r(7 downto 0) := CD_8;
            r(15 downto 8) := CD_8;
            ov := '1';
        elsif( a = b ) then

            r(7 downto 0) := C1_8;
            r(15 downto 8) := C0_8;
            ov := '0';
        elsif( a < b ) then

            r(7 downto 0) := C0_8;
            r(15 downto 8) := src_1;
            ov := '0';
        else

            v1(7 downto 0) := a;
            v1(15 downto 8) := C0_8;
            v3 := "0" & b;
            for i in 0 to 7 loop

                v1(15 downto 1) := v1(14 downto 0);
                v1(0) := '0';
                v2 := "1" & v1(15 downto 8);
                v2 := v2 - v3;
                if( v2(8) = '1' ) then
                    
                    v1(0) := '1';
                    v1(15 downto 8) := v2(7 downto 0);
                end if;
            end loop;

            r := v1;
            ov := '0';
        end if;
    end DO_DIV;
    
-------------------------------------------------------------------------------

    procedure DO_DA(a : in UNSIGNED (7 downto 0);
                    c1, c2 : in STD_LOGIC;
                    r : out UNSIGNED (7 downto 0);
                    cy : out STD_LOGIC) is

        variable v : UNSIGNED (8 downto 0);
    begin

        v := "0" & a;
        if( (c2 = '1') or (v(3 downto 0) > C9_4) ) then

            v := v + "000000110";
        end if;
        
        v(8) := v(8) or c1;
        
        if( v(8) = '1' or (v(7 downto 4) > C9_4) )then

            v := v + "001100000";
        end if;
        
        r := v(7 downto 0);
        cy := v(8);
    end DO_DA;

-------------------------------------------------------------------------------

begin
    process(rst, op_code, src_1, src_2, src_3, src_cy, src_ac)

        variable v16 : UNSIGNED (15 downto 0);
        variable v8 : UNSIGNED (7 downto 0);
        variable v_cy, v_ac, v_ov : STD_LOGIC;
    begin
        if( rst = '1' ) then

            des_1 <= CD_8;
            des_2 <= CD_8;
            des_cy <= '-';
            des_ac <= '-';
            des_ov <= '-';
        else

            case op_code is
                when ALU_OPC_ADD    =>
                    DO_ADD(src_1, src_2, src_cy, v8, v_cy, v_ac, v_ov);
                    des_1 <= v8;
                    des_2 <= CD_8;
                    des_cy <= v_cy;
                    des_ac <= v_ac;
                    des_ov <= v_ov;
                    
                when ALU_OPC_SUB    =>
                    DO_SUB(src_1, src_2, src_cy, v8, v_cy, v_ac, v_ov);
                    des_1 <= v8;
                    des_2 <= CD_8;
                    des_cy <= v_cy;
                    des_ac <= v_ac;
                    des_ov <= v_ov;

                when ALU_OPC_MUL    =>
                    DO_MUL(src_1, src_2, v16, v_ov);
                    des_1 <= v16(7 downto 0);
                    des_2 <= v16(15 downto 8);
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= v_ov;
                    
                when ALU_OPC_DIV    =>
                    DO_DIV(src_1, src_2, v16, v_ov);
                    des_1 <= v16(7 downto 0);
                    des_2 <= v16(15 downto 8);
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= v_ov;
                    
                when ALU_OPC_DA     =>
                    DO_DA(src_1, src_cy, src_ac, v8, v_cy);
                    des_1 <= v8;
                    des_2 <= CD_8;
                    des_cy <= v_cy;
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_NOT    =>
                    des_1(7) <= not src_1(7);
                    des_1(6) <= not src_1(6);
                    des_1(5) <= not src_1(5);
                    des_1(4) <= not src_1(4);
                    des_1(3) <= not src_1(3);
                    des_1(2) <= not src_1(2);
                    des_1(1) <= not src_1(1);
                    des_1(0) <= not src_1(0);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_AND    =>
                    des_1(7) <= src_1(7) and src_2(7);
                    des_1(6) <= src_1(6) and src_2(6);
                    des_1(5) <= src_1(5) and src_2(5);
                    des_1(4) <= src_1(4) and src_2(4);
                    des_1(3) <= src_1(3) and src_2(3);
                    des_1(2) <= src_1(2) and src_2(2);
                    des_1(1) <= src_1(1) and src_2(1);
                    des_1(0) <= src_1(0) and src_2(0);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';
                    
                when ALU_OPC_XOR    =>
                    des_1(7) <= src_1(7) xor src_2(7);
                    des_1(6) <= src_1(6) xor src_2(6);
                    des_1(5) <= src_1(5) xor src_2(5);
                    des_1(4) <= src_1(4) xor src_2(4);
                    des_1(3) <= src_1(3) xor src_2(3);
                    des_1(2) <= src_1(2) xor src_2(2);
                    des_1(1) <= src_1(1) xor src_2(1);
                    des_1(0) <= src_1(0) xor src_2(0);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_OR     =>
                    des_1(7) <= src_1(7) or src_2(7);
                    des_1(6) <= src_1(6) or src_2(6);
                    des_1(5) <= src_1(5) or src_2(5);
                    des_1(4) <= src_1(4) or src_2(4);
                    des_1(3) <= src_1(3) or src_2(3);
                    des_1(2) <= src_1(2) or src_2(2);
                    des_1(1) <= src_1(1) or src_2(1);
                    des_1(0) <= src_1(0) or src_2(0);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_RL     =>
                    des_1(0) <= src_1(7);
                    des_1(7 downto 1) <= src_1(6 downto 0);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';
                     
                when ALU_OPC_RLC    =>
                    des_1(0) <= src_cy;
                    des_1(7 downto 1) <= src_1(6 downto 0);
                    des_2 <= CD_8;
                    des_cy <= src_1(7);
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_RR     =>
                    des_1(7) <= src_1(0);
                    des_1(6 downto 0) <= src_1(7 downto 1);
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov<= '-';

                when ALU_OPC_RRC    =>
                    des_1(7) <= src_cy;
                    des_1(6 downto 0) <= src_1(7 downto 1);
                    des_2 <= CD_8;
                    des_cy <= src_1(0);
                    des_ac <= '-';
                    des_ov <= '-';

                when ALU_OPC_PCSADD =>
                    PCSADD(src_2 & src_1, src_3, v16);
                    des_1 <= v16(7 downto 0);
                    des_2 <= v16(15 downto 8);
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';
                    
                when ALU_OPC_PCUADD =>
                    PCUADD(src_2 & src_1, src_3, v16);
                    des_1 <= v16(7 downto 0);
                    des_2 <= v16(15 downto 8);
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';

                when others         =>
                    des_1 <= CD_8;
                    des_2 <= CD_8;
                    des_cy <= '-';
                    des_ac <= '-';
                    des_ov <= '-';
            end case;
        end if;
    end process;
end BHV;

-------------------------------------------------------------------------------

-- end of file --
