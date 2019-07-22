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

-------------------------------------------------------------------------------

entity I8051_TSB is
end I8051_TSB;

-------------------------------------------------------------------------------

architecture BHV of I8051_TSB is

    component I8051_ALL
        port(rst          : in  STD_LOGIC;
             clk          : in  STD_LOGIC;
             xrm_addr     : out UNSIGNED (15 downto 0);
             xrm_out_data : out UNSIGNED (7 downto 0);
             xrm_in_data  : in  UNSIGNED (7 downto 0);
             xrm_rd       : out STD_LOGIC;
             xrm_wr       : out STD_LOGIC;
             p0_in        : in  UNSIGNED (7 downto 0);
             p0_out       : out UNSIGNED (7 downto 0);
             p1_in        : in  UNSIGNED (7 downto 0);
             p1_out       : out UNSIGNED (7 downto 0);
             p2_in        : in  UNSIGNED (7 downto 0);
             p2_out       : out UNSIGNED (7 downto 0);
             p3_in        : in  UNSIGNED (7 downto 0);
             p3_out       : out UNSIGNED (7 downto 0));
    end component;

    component I8051_XRM

        generic(storage_size : INTEGER := 2048);

        port(rst      : in  STD_LOGIC;
             clk      : in  STD_LOGIC;
             addr     : in  UNSIGNED (15 downto 0);
             in_data  : in  UNSIGNED (7 downto 0);
             out_data : out UNSIGNED (7 downto 0);
             rd       : in  STD_LOGIC;
             wr       : in  STD_LOGIC);
    end component;

    signal rst      : STD_LOGIC := '1';
    signal clk      : STD_LOGIC := '0';
    signal addr     : UNSIGNED (15 downto 0);
    signal in_data  : UNSIGNED (7 downto 0);
    signal out_data : UNSIGNED (7 downto 0);
    signal rd       : STD_LOGIC;
    signal wr       : STD_LOGIC;
    signal p0_in    : UNSIGNED (7 downto 0);
    signal p0_out   : UNSIGNED (7 downto 0);
    signal p1_in    : UNSIGNED (7 downto 0);
    signal p1_out   : UNSIGNED (7 downto 0);
    signal p2_in    : UNSIGNED (7 downto 0);
    signal p2_out   : UNSIGNED (7 downto 0);
    signal p3_in    : UNSIGNED (7 downto 0);
    signal p3_out   : UNSIGNED (7 downto 0);
begin

    rst <= '0' after 50 ns;
    clk <= not clk after 25 ns;
    
    U_ALL : I8051_ALL port map (rst, clk,
                                addr, out_data, in_data, rd, wr,
                                p0_in, p0_out, p1_in, p1_out,
                                p2_in, p2_out, p3_in, p3_out);

    U_XRM : I8051_XRM port map (rst, clk, addr, out_data, in_data, rd, wr);
              
end BHV;

-------------------------------------------------------------------------------

configuration CFG_I8051_TSB of I8051_TSB is
    for BHV
    end for;
end CFG_I8051_TSB;

-------------------------------------------------------------------------------

-- end of file --
