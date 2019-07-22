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
use STD.TEXTIO.all;
use WORK.I8051_LIB.all;

-------------------------------------------------------------------------------

--
-- op_in : cracked opcode of the executing instruction (see I8051_LIB)
--
entity I8051_DBG is
    port(op_in   : in  UNSIGNED (8 downto 0));
end I8051_DBG;

-------------------------------------------------------------------------------

architecture BHV of I8051_DBG is

    type OPC_TYPE is (
        
        ACALL,
        ADD_1,
        ADD_2,
        ADD_3,
        ADD_4,
        ADDC_1,
        ADDC_2,
        ADDC_3,
        ADDC_4,
        AJMP,
        ANL_1,
        ANL_2,
        ANL_3,
        ANL_4,
        ANL_5,
        ANL_6,
        ANL_7,
        ANL_8,
        CJNE_1,
        CJNE_2,
        CJNE_3,
        CJNE_4,
        CLR_1,
        CLR_2,
        CLR_3,
        CPL_1,
        CPL_2,
        CPL_3,
        DA   ,
        DEC_1,
        DEC_2,
        DEC_3,
        DEC_4,
        DIV  ,
        DJNZ_1,
        DJNZ_2,
        INC_1,
        INC_2,
        INC_3,
        INC_4,
        INC_5,
        JB   ,
        JBC  ,
        JC   ,
        JMP  ,
        JNB  ,
        JNC  ,
        JNZ  ,
        JZ   ,
        LCALL,
        LJMP ,
        MOV_1,
        MOV_2,
        MOV_3,
        MOV_4,
        MOV_5,
        MOV_6,
        MOV_7,
        MOV_8,
        MOV_9,
        MOV_10,
        MOV_11,
        MOV_12,
        MOV_13,
        MOV_14,
        MOV_15,
        MOV_16,
        MOV_17,
        MOV_18,
        MOVC_1,
        MOVC_2,
        MOVX_1,
        MOVX_2,
        MOVX_3,
        MOVX_4,
        MUL,   
        NOP,  
        ORL_1, 
        ORL_2,
        ORL_3, 
        ORL_4,
        ORL_5, 
        ORL_6, 
        ORL_7, 
        ORL_8, 
        POP,   
        PUSH,  
        RET,   
        RETI,  
        RL,    
        RLC,   
        RR,    
        RRC,   
        SETB_1,
        SETB_2,
        SJMP,  
        SUBB_1,
        SUBB_2,
        SUBB_3,
        SUBB_4,
        SWAP,  
        XCH_1, 
        XCH_2, 
        XCH_3, 
        XCHD,  
        XRL_1, 
        XRL_2, 
        XRL_3, 
        XRL_4, 
        XRL_5, 
        XRL_6,
        OTHER); 

    signal opc : OPC_TYPE;
begin
    process(op_in)

        variable s : STRING (1 to 12);
        variable l : LINE;
        file f : TEXT is out "trace.out";
    begin

        case op_in(6 downto 0) is 
            when OPC_ACALL  => s := "ACALL       "; opc <= ACALL;
            when OPC_ADD_1  => s := "ADD 1       "; opc <= ADD_1;
            when OPC_ADD_2  => s := "ADD 2       "; opc <= ADD_2;
            when OPC_ADD_3  => s := "ADD 3       "; opc <= ADD_3;
            when OPC_ADD_4  => s := "ADD 4       "; opc <= ADD_4;
            when OPC_ADDC_1 => s := "ADDC 1      "; opc <= ADDC_1;
            when OPC_ADDC_2 => s := "ADDC 2      "; opc <= ADDC_2;
            when OPC_ADDC_3 => s := "ADDC 3      "; opc <= ADDC_3;
            when OPC_ADDC_4 => s := "ADDC 4      "; opc <= ADDC_4;
            when OPC_AJMP   => s := "AJMP        "; opc <= AJMP;
            when OPC_ANL_1  => s := "ANL 1       "; opc <= ANL_1;
            when OPC_ANL_2  => s := "ANL 2       "; opc <= ANL_2;
            when OPC_ANL_3  => s := "ANL 3       "; opc <= ANL_3;
            when OPC_ANL_4  => s := "ANL 4       "; opc <= ANL_4;
            when OPC_ANL_5  => s := "ANL 5       "; opc <= ANL_5;
            when OPC_ANL_6  => s := "ANL 6       "; opc <= ANL_6;
            when OPC_ANL_7  => s := "ANL 7       "; opc <= ANL_7;
            when OPC_ANL_8  => s := "ANL 8       "; opc <= ANL_8;
            when OPC_CJNE_1 => s := "CJNE 1      "; opc <= CJNE_1;
            when OPC_CJNE_2 => s := "CJNE 2      "; opc <= CJNE_2;
            when OPC_CJNE_3 => s := "CJNE 3      "; opc <= CJNE_3;
            when OPC_CJNE_4 => s := "CJNE 4      "; opc <= CJNE_4;
            when OPC_CLR_1  => s := "CLR 1       "; opc <= CLR_1;
            when OPC_CLR_2  => s := "CLR 2       "; opc <= CLR_2;
            when OPC_CLR_3  => s := "CLR 3       "; opc <= CLR_3;
            when OPC_CPL_1  => s := "CPL 1       "; opc <= CPL_1;
            when OPC_CPL_2  => s := "CPL 2       "; opc <= CPL_2;
            when OPC_CPL_3  => s := "CPL 3       "; opc <= CPL_3;
            when OPC_DA     => s := "DA          "; opc <= DA;
            when OPC_DEC_1  => s := "DEC 1       "; opc <= DEC_1;
            when OPC_DEC_2  => s := "DEC 2       "; opc <= DEC_2;
            when OPC_DEC_3  => s := "DEC 3       "; opc <= DEC_3;
            when OPC_DEC_4  => s := "DEC 4       "; opc <= DEC_4;
            when OPC_DIV    => s := "DIV         "; opc <= DIV;
            when OPC_DJNZ_1 => s := "DJNZ 1      "; opc <= DJNZ_1;
            when OPC_DJNZ_2 => s := "DJNZ 2      "; opc <= DJNZ_2;
            when OPC_INC_1  => s := "INC 1       "; opc <= INC_1;
            when OPC_INC_2  => s := "INC 2       "; opc <= INC_2;
            when OPC_INC_3  => s := "INC 3       "; opc <= INC_3;
            when OPC_INC_4  => s := "INC 4       "; opc <= INC_4;
            when OPC_INC_5  => s := "INC 5       "; opc <= INC_5;
            when OPC_JB     => s := "JB          "; opc <= JB;
            when OPC_JBC    => s := "JBC         "; opc <= JBC;
            when OPC_JC     => s := "JC          "; opc <= JC;
            when OPC_JMP    => s := "JMP         "; opc <= JMP;
            when OPC_JNB    => s := "JNB         "; opc <= JNB;
            when OPC_JNC    => s := "JNC         "; opc <= JNC;
            when OPC_JNZ    => s := "JNZ         "; opc <= JNZ;
            when OPC_JZ     => s := "JZ          "; opc <= JZ;
            when OPC_LCALL  => s := "LCALL       "; opc <= LCALL;
            when OPC_LJMP   => s := "LJMP        "; opc <= LJMP;
            when OPC_MOV_1  => s := "MOV 1       "; opc <= MOV_1;
            when OPC_MOV_2  => s := "MOV 2       "; opc <= MOV_2;
            when OPC_MOV_3  => s := "MOV 3       "; opc <= MOV_3;
            when OPC_MOV_4  => s := "MOV 4       "; opc <= MOV_4;
            when OPC_MOV_5  => s := "MOV 5       "; opc <= MOV_5;
            when OPC_MOV_6  => s := "MOV 6       "; opc <= MOV_6;
            when OPC_MOV_7  => s := "MOV 7       "; opc <= MOV_7;
            when OPC_MOV_8  => s := "MOV 8       "; opc <= MOV_8;
            when OPC_MOV_9  => s := "MOV 9       "; opc <= MOV_9;
            when OPC_MOV_10 => s := "MOV 10      "; opc <= MOV_10;
            when OPC_MOV_11 => s := "MOV 11      "; opc <= MOV_11;
            when OPC_MOV_12 => s := "MOV 12      "; opc <= MOV_12;
            when OPC_MOV_13 => s := "MOV 13      "; opc <= MOV_13;
            when OPC_MOV_14 => s := "MOV 14      "; opc <= MOV_14;
            when OPC_MOV_15 => s := "MOV 15      "; opc <= MOV_15;
            when OPC_MOV_16 => s := "MOV 16      "; opc <= MOV_16;
            when OPC_MOV_17 => s := "MOV 17      "; opc <= MOV_17;
            when OPC_MOV_18 => s := "MOV 18      "; opc <= MOV_18;
            when OPC_MOVC_1 => s := "MOVC 1      "; opc <= MOVC_1;
            when OPC_MOVC_2 => s := "MOVC 2      "; opc <= MOVC_2;
            when OPC_MOVX_1 => s := "MOVX 1      "; opc <= MOVX_1;
            when OPC_MOVX_2 => s := "MOVX 2      "; opc <= MOVX_2;
            when OPC_MOVX_3 => s := "MOVX 3      "; opc <= MOVX_3;
            when OPC_MOVX_4 => s := "MOVX 4      "; opc <= MOVX_4;
            when OPC_MUL    => s := "MUL         "; opc <= MUL;
            when OPC_NOP    => s := "NOP         "; opc <= NOP;
            when OPC_ORL_1  => s := "ORL 1       "; opc <= ORL_1;
            when OPC_ORL_2  => s := "ORL 2       "; opc <= ORL_2;
            when OPC_ORL_3  => s := "ORL 3       "; opc <= ORL_3;
            when OPC_ORL_4  => s := "ORL 4       "; opc <= ORL_4;
            when OPC_ORL_5  => s := "ORL 5       "; opc <= ORL_5;
            when OPC_ORL_6  => s := "ORL 6       "; opc <= ORL_6;
            when OPC_ORL_7  => s := "ORL 7       "; opc <= ORL_7;
            when OPC_ORL_8  => s := "ORL 8       "; opc <= ORL_8;
            when OPC_POP    => s := "POP         "; opc <= POP;
            when OPC_PUSH   => s := "PUSH        "; opc <= PUSH;
            when OPC_RET    => s := "RET         "; opc <= RET;
            when OPC_RETI   => s := "RETI        "; opc <= RETI;
            when OPC_RL     => s := "RL          "; opc <= RL;
            when OPC_RLC    => s := "RLC         "; opc <= RLC;
            when OPC_RR     => s := "RR          "; opc <= RR;
            when OPC_RRC    => s := "RRC         "; opc <= RRC;
            when OPC_SETB_1 => s := "SETB 1      "; opc <= SETB_1;
            when OPC_SETB_2 => s := "SETB 2      "; opc <= SETB_2;
            when OPC_SJMP   => s := "SJMP        "; opc <= SJMP;
            when OPC_SUBB_1 => s := "SUBB 1      "; opc <= SUBB_1;
            when OPC_SUBB_2 => s := "SUBB 2      "; opc <= SUBB_2;
            when OPC_SUBB_3 => s := "SUBB 3      "; opc <= SUBB_3;
            when OPC_SUBB_4 => s := "SUBB 4      "; opc <= SUBB_4;
            when OPC_SWAP   => s := "SWAP        "; opc <= SWAP;
            when OPC_XCH_1  => s := "XCH 1       "; opc <= XCH_1;
            when OPC_XCH_2  => s := "XCH 2       "; opc <= XCH_2;
            when OPC_XCH_3  => s := "XCH 3       "; opc <= XCH_3;
            when OPC_XCHD   => s := "XCHD        "; opc <= XCHD;
            when OPC_XRL_1  => s := "XRL 1       "; opc <= XRL_1;
            when OPC_XRL_2  => s := "XRL 2       "; opc <= XRL_2;
            when OPC_XRL_3  => s := "XRL 3       "; opc <= XRL_3;
            when OPC_XRL_4  => s := "XRL 4       "; opc <= XRL_4;
            when OPC_XRL_5  => s := "XRL 5       "; opc <= XRL_5;
            when OPC_XRL_6  => s := "XRL 6       "; opc <= XRL_6;
            when others     => s := "            "; opc <= OTHER;
        end case;

        if( s /= "            " ) then

            write(l, s, LEFT, 7);
            writeline(f, l);
        end if;
    end process;
end BHV;

-------------------------------------------------------------------------------

-- end of file --
