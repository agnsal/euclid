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
-- rd (active lo) : asserted to signal a ram/reg read
-- wr (active lo) : asserted to signal a ram/reg write
--
entity I8051_XRM is

    generic(storage_size : INTEGER := 2048);

    port(rst      : in  STD_LOGIC;
         clk      : in  STD_LOGIC;
         addr     : in  UNSIGNED (15 downto 0);
         in_data  : in  UNSIGNED (7 downto 0);
         out_data : out UNSIGNED (7 downto 0);
         rd       : in  STD_LOGIC;
         wr       : in  STD_LOGIC);
end I8051_XRM;

-------------------------------------------------------------------------------

architecture BHV of I8051_XRM is

    type XRM_TYPE is array (0 to storage_size-1) of UNSIGNED (7 downto 0);
    
    signal xrm : XRM_TYPE;

begin

    process(rst, clk)
    begin

        if( rst = '1' ) then

            for i in 0 to storage_size-1 loop

                xrm(i) <= CD_8;
            end loop;

            out_data <= CD_8;
            
        elsif( clk'event and clk = '1' ) then

            if( rd = '1' and conv_integer(addr) < storage_size ) then

                out_data <= xrm(conv_integer(addr));
            elsif( wr = '1' and conv_integer(addr) < storage_size ) then

               xrm(conv_integer(addr)) <= in_data; 
            end if;
        end if;
    end process;
end BHV;

-------------------------------------------------------------------------------

-- end of file --
