--
-- Copyright (c) 1999-2000 Tony Givargis.  Permission to copy is granted
-- provided that this header remains intact.  This software is provided
-- with no warranties.
--
-- Version : 2.8
--

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use WORK.I8051_LIB.all;

-------------------------------------------------------------------------------

--
-- rst (active hi) : when asserted, the registers are set to default values
-- clk (rising edge) : clock signal - all ram i/o is synchronous
-- addr : this is the address of ram/reg being requested
-- in_data : this is the data being writen into the ram/reg
-- out_data : this is the data being read from the ram/reg
-- in_bit_data : this is the bit-data being writen into the ram/reg
-- out_bit_data : this is the bit-data being read from the ram/reg
-- rd (active lo) : asserted to signal a ram/reg read
-- wr (active lo) : asserted to signal a ram/reg write
-- is_bit_addr (active hi) : asserted if requesting a ram/reg bit-data
-- p0_in : write access to the 8051's port 0
-- p0_out : read access to the 8051's port 0
-- p1_in : write access to the 8051's port 0
-- p1_out : read access to the 8051's port 0
-- p2_in : write access to the 8051's port 0
-- p2_out : read access to the 8051's port 0
-- p3_in : write access to the 8051's port 0
-- p3_out : read access to the 8051's port 0
--
entity I8051_RAM is
    port(rst          : in  STD_LOGIC;
         clk          : in  STD_LOGIC;
         addr         : in  UNSIGNED (7 downto 0);
         in_data      : in  UNSIGNED (7 downto 0);
         out_data     : out UNSIGNED (7 downto 0);
         in_bit_data  : in  STD_LOGIC;
         out_bit_data : out STD_LOGIC;
         rd           : in  STD_LOGIC;
         wr           : in  STD_LOGIC;
         is_bit_addr  : in  STD_LOGIC;
         p0_in        : in  UNSIGNED (7 downto 0);
         p0_out       : out UNSIGNED (7 downto 0);
         p1_in        : in  UNSIGNED (7 downto 0);
         p1_out       : out UNSIGNED (7 downto 0);
         p2_in        : in  UNSIGNED (7 downto 0);
         p2_out       : out UNSIGNED (7 downto 0);
         p3_in        : in  UNSIGNED (7 downto 0);
         p3_out       : out UNSIGNED (7 downto 0));
end I8051_RAM;

-------------------------------------------------------------------------------

architecture BHV of I8051_RAM is

    type IRAM_TYPE is array (0 to 127) of UNSIGNED (7 downto 0);
    
    signal iram : IRAM_TYPE;

    signal sfr_b    : UNSIGNED (7 downto 0);
    signal sfr_acc  : UNSIGNED (7 downto 0);
    signal sfr_psw  : UNSIGNED (7 downto 0);
    signal sfr_ie   : UNSIGNED (7 downto 0);
    signal sfr_ip   : UNSIGNED (7 downto 0);
    signal sfr_sp   : UNSIGNED (7 downto 0);
    signal sfr_dpl  : UNSIGNED (7 downto 0);
    signal sfr_dph  : UNSIGNED (7 downto 0);
    signal sfr_pcon : UNSIGNED (7 downto 0);
    signal sfr_scon : UNSIGNED (7 downto 0);
    signal sfr_sbuf : UNSIGNED (7 downto 0);
    signal sfr_tcon : UNSIGNED (7 downto 0);
    signal sfr_tmod : UNSIGNED (7 downto 0);
    signal sfr_tl0  : UNSIGNED (7 downto 0);
    signal sfr_th0  : UNSIGNED (7 downto 0);
    signal sfr_tl1  : UNSIGNED (7 downto 0);
    signal sfr_th1  : UNSIGNED (7 downto 0);

begin

    process(rst, clk)

-------------------------------------------------------------------------------

        procedure GET_BYTE (a : UNSIGNED (7 downto 0);
                            v : out UNSIGNED (7 downto 0)) is
        begin
            case a is
                when R_B    => v := sfr_b;
                when R_ACC  => v := sfr_acc;
                when R_PSW  => v := sfr_psw;
                when R_IP   => v := sfr_ip;
                when R_IE   => v := sfr_ie;
                when R_SP   => v := sfr_sp;
                when R_P0   => v := p0_in;
                when R_P1   => v := p1_in;
                when R_P2   => v := p2_in;
                when R_P3   => v := p3_in;
                when R_DPL  => v := sfr_dpl;
                when R_DPH  => v := sfr_dph;
                when R_PCON => v := sfr_pcon;
                when R_SCON => v := sfr_scon;
                when R_SBUF => v := sfr_sbuf;
                when R_TCON => v := sfr_tcon;
                when R_TMOD => v := sfr_tmod;
                when R_TL0  => v := sfr_tl0;
                when R_TL1  => v := sfr_tl1;
                when R_TH0  => v := sfr_th0;
                when R_TH1  => v := sfr_th1;
                when others => v := iram(conv_integer(a(6 downto 0)));
            end case;
        end GET_BYTE;

-------------------------------------------------------------------------------
        
        procedure SET_BYTE (a : UNSIGNED (7 downto 0);
                            v : UNSIGNED (7 downto 0)) is
        begin
            case a is
                when R_B    => sfr_b <= v;
                when R_ACC  => sfr_acc <= v;
                when R_PSW  => sfr_psw <= v;
                when R_IP   => sfr_ip <= v;
                when R_IE   => sfr_ie <= v;
                when R_SP   => sfr_sp <= v;
                when R_P0   => p0_out <= v;
                when R_P1   => p1_out <= v;
                when R_P2   => p2_out <= v;
                when R_P3   => p3_out <= v;
                when R_DPL  => sfr_dpl <= v;
                when R_DPH  => sfr_dph <= v;
                when R_PCON => sfr_pcon <= v;
                when R_SCON => sfr_scon <= v;
                when R_SBUF => sfr_sbuf <= v;
                when R_TCON => sfr_tcon <= v;
                when R_TMOD => sfr_tmod <= v;
                when R_TL0  => sfr_tl0 <= v;
                when R_TL1  => sfr_tl1 <= v;
                when R_TH0  => sfr_th0 <= v;
                when R_TH1  => sfr_th1 <= v;
                when others => iram(conv_integer(a(6 downto 0))) <= v;
            end case;
        end SET_BYTE;

-------------------------------------------------------------------------------
        
        procedure GET_BIT (a : UNSIGNED (7 downto 0); v : out STD_LOGIC) is
            variable vu : UNSIGNED (7 downto 0);
            variable vi : INTEGER;
        begin
            vu := a(7 downto 3) & "000";
            vi := conv_integer(a(2 downto 0));
            case vu is
                when R_B    => v := sfr_b(vi);
                when R_ACC  => v := sfr_acc(vi);
                when R_PSW  => v := sfr_psw(vi);
                when R_IP   => v := sfr_ip(vi);
                when R_IE   => v := sfr_ie(vi);
                when R_SP   => v := sfr_sp(vi);
                when R_P0   => v := p0_in(vi);
                when R_P1   => v := p1_in(vi);
                when R_P2   => v := p2_in(vi);
                when R_P3   => v := p3_in(vi);
                when R_SCON => v := sfr_scon(vi);
                when R_TCON => v := sfr_tcon(vi);
                when others =>
                    vu := "0010" & a(6 downto 3);
                    v := iram(conv_integer(vu))(vi);
            end case;
        end GET_BIT;

-------------------------------------------------------------------------------
        
        procedure SET_BIT (a : UNSIGNED (7 downto 0); v : STD_LOGIC) is
            variable vu : UNSIGNED (7 downto 0);
            variable vi : INTEGER;
        begin
            vu := a(7 downto 3) & "000";
            vi := conv_integer(a(2 downto 0));
            case vu is
                when R_B    => sfr_b(vi) <= v;
                when R_ACC  => sfr_acc(vi) <= v;
                when R_PSW  => sfr_psw(vi) <= v;
                when R_IP   => sfr_ip(vi) <= v;
                when R_IE   => sfr_ie(vi) <= v;
                when R_SP   => sfr_sp(vi) <= v;
                when R_P0   => p0_out(vi) <= v;
                when R_P1   => p1_out(vi) <= v;
                when R_P2   => p2_out(vi) <= v;
                when R_P3   => p3_out(vi) <= v;
                when R_SCON => sfr_scon(vi) <= v;
                when R_TCON => sfr_tcon(vi) <= v;
                when others =>
                    vu := "0010" & a(6 downto 3);
                    iram(conv_integer(vu))(vi) <= v;
            end case;        
        end SET_BIT;

-------------------------------------------------------------------------------

        variable v8 : UNSIGNED (7 downto 0);
        variable v1 : STD_LOGIC;
    begin

        if( rst = '1' ) then

            for i in 0 to 127 loop

                iram(i) <= CD_8;
            end loop;

            sfr_b    <= C0_8;
            sfr_acc  <= C0_8;
            sfr_psw  <= C0_8;
            sfr_ie   <= C0_8;
            sfr_ip   <= C0_8;
            sfr_sp   <= CD_8;
            sfr_dpl  <= C0_8;
            sfr_dph  <= C0_8;
            sfr_pcon <= C0_8;
            sfr_scon <= C0_8;
            sfr_sbuf <= C0_8;
            sfr_tcon <= C0_8;
            sfr_tmod <= C0_8;
            sfr_tl0  <= C0_8;
            sfr_th0  <= C0_8;
            sfr_tl1  <= C0_8;
            sfr_th1  <= C0_8;

            out_data <= CD_8;
            out_bit_data <= '-';
            p0_out <= CD_8;
            p1_out <= CD_8;
            p2_out <= CD_8;
            p3_out <= CD_8;
            
        elsif( clk'event and clk = '1' ) then

            if( rd = '1' ) then

                if( is_bit_addr = '1' ) then
                    
                    GET_BIT(addr, v1);
                    out_bit_data <= v1;
                else

                    GET_BYTE(addr, v8);
                    out_data <= v8;
                end if;
            elsif( wr = '1' ) then

                if( is_bit_addr = '1' ) then

                    SET_BIT(addr, in_bit_data);
                else
                    
                    SET_BYTE(addr, in_data);
                end if;
            end if;
        end if;
    end process;
end BHV;

-------------------------------------------------------------------------------

-- end of file --
