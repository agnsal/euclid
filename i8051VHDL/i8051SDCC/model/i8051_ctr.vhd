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
-- rst (active hi) : when asserted the controller state is reset
-- clk (rising edge) : clock signal
-- rom_addr : this is the rom address being requested
-- rom_data : this is the data returned by rom
-- rom_rd (active lo) : asserted to signal a rom read
-- ram_addr : this is the address of ram/reg being requested
-- ram_out_data : this is the data sent to the ram/reg
-- ram_in_data : this is the data received from the ram/reg
-- ram_out_bit_data : this is the bit-data sent to the ram/reg
-- ram_in_bit_data : this is the bit-data received from the ram/reg
-- ram_rd (active lo) : asserted to signal a ram/reg read
-- ram_wr (active lo) : asserted to signal a ram/reg write
-- ram_is_bit_addr (active hi) : asserted if requesting a ram/reg bit-data
-- xrm_addr : this is the address of external memory being requested
-- xrm_out_data : this is the data sent to the external memory
-- xrm_in_data : this is the data received from the external memory
-- xrm_rd (active lo) : asserted to signal a external memory read
-- xrm_wr (active lo) : asserted to signal a external memory write
-- dec_op_out : actual variable length opcode sent to decoder (see 8051 specs)
-- dec_op_in(6 downto 0) : cracked (fixed length) opcode (see I8051_LIB)
-- dec_op_in(7) : set if this instruction uses a second byte of data
-- dec_op_in(8) : set if this instruction uses a third byte of data
-- alu_op_code : defines the alu operation requested (see I8051_LIB)
-- alu_src_1 : first source operand of the alu (see I8051_ALU)
-- alu_src_2 : second source operand of the alu (see I8051_ALU)
-- alu_src_3 : third source operand of the alu (see I8051_ALU)
-- alu_src_cy : carry into the 7th bit of the alu (see I8051_ALU)
-- alu_src_ac : carry into the 4th bit of the alu (see I8051_ALU)
-- alu_des_1 : first destination operand of the alu (see I8051_ALU)
-- alu_des_2 : second destination operand of the alu (see I8051_ALU)
-- alu_des_cy : carry out of the 7th bit of the alu (see I8051_ALU)
-- alu_des_ac : carry out of the 4th bit of the alu (see I8051_ALU)
-- alu_des_ov : overflow out of the alu (see I8051_ALU)
--
entity I8051_CTR is
    port(rst              : in  STD_LOGIC;
         clk              : in  STD_LOGIC;
         rom_addr         : out UNSIGNED (11 downto 0);
         rom_data         : in  UNSIGNED (7 downto 0);
         rom_rd           : out STD_LOGIC;
         ram_addr         : out UNSIGNED (7 downto 0);
         ram_out_data     : out UNSIGNED (7 downto 0);
         ram_in_data      : in  UNSIGNED (7 downto 0);
         ram_out_bit_data : out STD_LOGIC;
         ram_in_bit_data  : in  STD_LOGIC;
         ram_rd           : out STD_LOGIC;
         ram_wr           : out STD_LOGIC;
         ram_is_bit_addr  : out STD_LOGIC;
         xrm_addr         : out UNSIGNED (15 downto 0);
         xrm_out_data     : out UNSIGNED (7 downto 0);
         xrm_in_data      : in  UNSIGNED (7 downto 0);
         xrm_rd           : out STD_LOGIC;
         xrm_wr           : out STD_LOGIC;
         dec_op_out       : out UNSIGNED (7 downto 0);
         dec_op_in        : in  UNSIGNED (8 downto 0);
         alu_op_code      : out UNSIGNED (3 downto 0);
         alu_src_1        : out UNSIGNED (7 downto 0);
         alu_src_2        : out UNSIGNED (7 downto 0);
         alu_src_3        : out UNSIGNED (7 downto 0);
         alu_src_cy       : out STD_LOGIC;
         alu_src_ac       : out STD_LOGIC;
         alu_des_1        : in  UNSIGNED (7 downto 0);
         alu_des_2        : in  UNSIGNED (7 downto 0);
         alu_des_cy       : in  STD_LOGIC;
         alu_des_ac       : in  STD_LOGIC;
         alu_des_ov       : in  STD_LOGIC);
end I8051_CTR;

-------------------------------------------------------------------------------

architecture BHV of I8051_CTR is

    type CPU_STATE_TYPE is (CS_0, CS_1, CS_2, CS_3);
    type EXE_STATE_TYPE is (ES_0, ES_1, ES_2, ES_3, ES_4, ES_5, ES_6, ES_7);
    
    signal reg_pc_15_11 : UNSIGNED (4 downto 0);
    signal reg_pc_10_8  : UNSIGNED (2 downto 0);
    signal reg_pc_7_0   : UNSIGNED (7 downto 0);
    signal reg_op1      : UNSIGNED (7 downto 0);
    signal reg_op2      : UNSIGNED (7 downto 0);
    signal reg_op3      : UNSIGNED (7 downto 0);
    signal reg_acc      : UNSIGNED (7 downto 0);
    signal reg_cy       : STD_LOGIC;
    signal reg_ac       : STD_LOGIC;
    signal reg_f0       : STD_LOGIC;
    signal reg_rs1      : STD_LOGIC;
    signal reg_rs0      : STD_LOGIC;
    signal reg_ov       : STD_LOGIC;
    signal reg_nu       : STD_LOGIC;
    signal reg_p        : STD_LOGIC;

    signal cpu_state : CPU_STATE_TYPE;
    signal exe_state : EXE_STATE_TYPE;
begin

    process(rst, clk)

-------------------------------------------------------------------------------

        procedure SET_PC_1 (pch, pcl : UNSIGNED (7 downto 0)) is
        begin
            reg_pc_15_11 <= pch(7 downto 3);
            reg_pc_10_8 <= pch(2 downto 0);
            reg_pc_7_0 <= pcl;
        end SET_PC_1;

-------------------------------------------------------------------------------

        procedure SET_PC_2 (pch : UNSIGNED (2 downto 0);
                            pcl : UNSIGNED (7 downto 0)) is
        begin
            reg_pc_10_8 <= pch;
            reg_pc_7_0 <= pcl;
        end SET_PC_2;
        
-------------------------------------------------------------------------------

        procedure SET_PC_H (pch : UNSIGNED (7 downto 0)) is
        begin
            reg_pc_15_11 <= pch(7 downto 3);
            reg_pc_10_8 <= pch(2 downto 0);
        end SET_PC_H;
        
-------------------------------------------------------------------------------

        procedure SET_PC_L (pcl : UNSIGNED (7 downto 0)) is
        begin
            reg_pc_7_0 <= pcl;
        end SET_PC_L;
        
-------------------------------------------------------------------------------

        procedure GET_PC_H (pch : out UNSIGNED (7 downto 0)) is
        begin
            pch := reg_pc_15_11 & reg_pc_10_8;
        end GET_PC_H;
        
-------------------------------------------------------------------------------

        procedure GET_PC_L (pcl : out UNSIGNED (7 downto 0)) is
        begin
            pcl := reg_pc_7_0;
        end GET_PC_L;
        
-------------------------------------------------------------------------------
        
        procedure GET_RAM_ADDR_1 (a : out UNSIGNED (7 downto 0)) is
        begin
            a := "000" & reg_rs1 & reg_rs0 & reg_op1(2 downto 0);
        end GET_RAM_ADDR_1;

-------------------------------------------------------------------------------
        
        procedure GET_RAM_ADDR_2 (a : out UNSIGNED (7 downto 0)) is
        begin
            a := "000" & reg_rs1 & reg_rs0 & "00" & reg_op1(0);
        end GET_RAM_ADDR_2;

-------------------------------------------------------------------------------

        procedure SET_PSW (p : UNSIGNED (7 downto 0)) is
        begin
            reg_cy <= p(7);
            reg_ac <= p(6);
            reg_f0 <= p(5);
            reg_rs1 <= p(4);
            reg_rs0 <= p(3);
            reg_ov <= p(2);
            reg_nu <= p(1);
            reg_p <= p(0);
        end SET_PSW;
        
-------------------------------------------------------------------------------

        procedure GET_PSW (p : out UNSIGNED (7 downto 0)) is
        begin
            p(7) := reg_cy;
            p(6) := reg_ac;
            p(5) := reg_f0;
            p(4) := reg_rs1;
            p(3) := reg_rs0;
            p(2) := reg_ov;
            p(1) := reg_nu;
            p(0) := reg_p;
        end GET_PSW;
        
-------------------------------------------------------------------------------

        procedure START_RD_ROM (h, l : UNSIGNED (7 downto 0)) is
        begin
            rom_addr <= h(3 downto 0) & l;
            rom_rd <= '1';
        end START_RD_ROM;

-------------------------------------------------------------------------------
        
        procedure STOP_RD_ROM is
        begin
            rom_addr <= CD_12;
            rom_rd <= '0';
        end STOP_RD_ROM;

-------------------------------------------------------------------------------

        procedure START_RD_RAM (a : UNSIGNED (7 downto 0)) is
        begin
            ram_addr <= a;
            ram_is_bit_addr <= '0';
            ram_rd <= '1';
            ram_wr <= '0';
        end START_RD_RAM;

-------------------------------------------------------------------------------
        
        procedure START_WR_RAM (a : UNSIGNED (7 downto 0)) is
        begin
            ram_addr <= a;
            ram_is_bit_addr <= '0';
            ram_rd <= '0';
            ram_wr <= '1';
        end START_WR_RAM;

-------------------------------------------------------------------------------
        
        procedure START_RD_BIT_RAM (a : UNSIGNED (7 downto 0)) is
        begin
            ram_addr <= a;
            ram_is_bit_addr <= '1';
            ram_rd <= '1';
            ram_wr <= '0';
        end START_RD_BIT_RAM;

-------------------------------------------------------------------------------
        
        procedure START_WR_BIT_RAM (a : UNSIGNED (7 downto 0)) is
        begin
            ram_addr <= a;
            ram_is_bit_addr <= '1';
            ram_rd <= '0';
            ram_wr <= '1';
        end START_WR_BIT_RAM;

-------------------------------------------------------------------------------
        
        procedure STOP_RD_WR_RAM is
        begin
            ram_addr <= CD_8;
            ram_out_data <= CD_8;
            ram_out_bit_data <= '-';
            ram_is_bit_addr <= '-';
            ram_rd <= '0';
            ram_wr <= '0';
        end STOP_RD_WR_RAM;

-------------------------------------------------------------------------------

        procedure START_RD_XRM (a : UNSIGNED (15 downto 0)) is
        begin
            xrm_addr <= a;
            xrm_rd <= '1';
            xrm_wr <= '0';
        end START_RD_XRM;

-------------------------------------------------------------------------------
        
        procedure START_WR_XRM (a : UNSIGNED (15 downto 0)) is
        begin
            xrm_addr <= a;
            xrm_rd <= '0';
            xrm_wr <= '1';
        end START_WR_XRM;

-------------------------------------------------------------------------------
        
        procedure STOP_RD_WR_XRM is
        begin
            xrm_addr <= CD_16;
            xrm_out_data <= CD_8;
            xrm_rd <= '0';
            xrm_wr <= '0';
        end STOP_RD_WR_XRM;

-------------------------------------------------------------------------------

        procedure SHUT_DOWN_ALU is
        begin
            alu_op_code <= ALU_OPC_NONE;
            alu_src_1 <= CD_8;
            alu_src_2 <= CD_8;
            alu_src_3 <= CD_8;
            alu_src_cy <= '-';
            alu_src_ac <= '-';
        end SHUT_DOWN_ALU;

-------------------------------------------------------------------------------

        variable v8, pcl, pch  : UNSIGNED (7 downto 0);
    begin
        
        if( rst = '1' ) then

            SET_PC_1(C0_8, C0_8);
            
            reg_op1 <= C0_8;
            reg_op2 <= CD_8;
            reg_op3 <= CD_8;
            reg_acc <= CD_8;

            SET_PSW(CD_8);
            
            cpu_state <= CS_0;
            exe_state <= ES_0;

            STOP_RD_ROM;
            STOP_RD_WR_RAM;
            STOP_RD_WR_XRM;
            SHUT_DOWN_ALU;
            
        elsif( clk'event and clk = '1' ) then

            STOP_RD_ROM;
            STOP_RD_WR_RAM;
            STOP_RD_WR_XRM;
            
            case cpu_state is

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

                --
                -- reset controller
                --
                when CS_0 =>
                    case exe_state is
                        when ES_0 =>
                            ram_out_data <= CM_8;
                            START_WR_RAM(R_P0);
                            exe_state <= ES_1;

                        when ES_1 =>
                            ram_out_data <= CM_8;
                            START_WR_RAM(R_P1);
                            exe_state <= ES_2;

                        when ES_2 =>
                            ram_out_data <= CM_8;
                            START_WR_RAM(R_P2);
                            exe_state <= ES_3;

                        when ES_3 =>
                            ram_out_data <= CM_8;
                            START_WR_RAM(R_P3);
                            exe_state <= ES_4;

                        when ES_4 =>
                            ram_out_data <= C7_8;
                            START_WR_RAM(R_SP);
                            exe_state <= ES_5;

                        when ES_5 =>
                            cpu_state <= CS_1;
                            exe_state <= ES_0;

                        when others => null;
                    end case;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

                --
                -- handle interrupts
                --
                when CS_1 =>
                    cpu_state <= CS_2;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

                --
                -- process instructions
                --
                when CS_2 =>
                    case exe_state is
                        when ES_0 =>
                            GET_PC_H(pch);
                            GET_PC_L(pcl);
                            START_RD_ROM(pch, pcl);
                            alu_op_code <= ALU_OPC_PCUADD;
                            alu_src_1 <= pcl;
                            alu_src_2 <= pch;
                            alu_src_3 <= C1_8;
                            exe_state <= ES_1;

                        when ES_1 =>
                            START_RD_RAM(R_PSW);
                            exe_state <= ES_2;

                        when ES_2 =>
                            START_RD_RAM(R_ACC);
                            reg_op1 <= rom_data;
                            exe_state <= ES_3;
                            
                        when ES_3 =>
                            START_RD_ROM(alu_des_2, alu_des_1);
                            SET_PSW(ram_in_data);
                            alu_op_code <= ALU_OPC_PCUADD;
                            alu_src_1 <= alu_des_1;
                            alu_src_2 <= alu_des_2;
                            if( dec_op_in(7) = '1' ) then

                                alu_src_3 <= C1_8;
                            else

                                alu_src_3 <= C0_8;
                            end if;
                            exe_state <= ES_4;

                        when ES_4 =>
                            START_RD_ROM(alu_des_2, alu_des_1);
                            reg_acc <= ram_in_data;
                            alu_op_code <= ALU_OPC_PCUADD;
                            alu_src_1 <= alu_des_1;
                            alu_src_2 <= alu_des_2;
                            if( dec_op_in(8) = '1' ) then

                                alu_src_3 <= C1_8;
                            else

                                alu_src_3 <= C0_8;
                            end if;
                            exe_state <= ES_5;

                        when ES_5 =>
                            reg_op2 <= rom_data;
                            SET_PC_1(alu_des_2, alu_des_1);
                            exe_state <= ES_6;

                        when ES_6 =>
                            reg_op3 <= rom_data;
                            exe_state <= ES_7;

                        when ES_7 =>
                            SHUT_DOWN_ALU;
                            cpu_state <= CS_3;
                            exe_state <= ES_0;
                    end case;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
                    
                --
                -- execute state
                --
                when CS_3 =>
                    case dec_op_in(6 downto 0) is

-------------------------------------------------------------------------------

                        --
                        -- sp       <- sp + 1
                        -- mem(sp)  <- pc(7-0)
                        -- sp       <- sp + 1
                        -- mem(sp)  <- pc(15-8)
                        -- pc(10-0) <- page address
                        --
                        when OPC_ACALL  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_SP);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= alu_des_1;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    ram_out_data <= pcl;
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PC_H(pch);
                                    ram_out_data <= pch;
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_SP);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    SET_PC_2(reg_op1(7 downto 5), reg_op2);
                                    exe_state <= ES_7;

                               when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + (r)
                        --
                        when OPC_ADD_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= '0';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + (direct)
                        --
                        when OPC_ADD_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= '0';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + ((r))
                        --
                        when OPC_ADD_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= '0';
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + #data
                        --
                        when OPC_ADD_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    alu_src_cy <= '0';
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + cy + (r)
                        --
                        when OPC_ADDC_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + cy + (direct)
                        --
                        when OPC_ADDC_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + cy + ((r))
                        --
                        when OPC_ADDC_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + cy + #data
                        --
                        when OPC_ADDC_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;
                            
-------------------------------------------------------------------------------

                        --
                        -- pc(10-0) <- page address
                        --
                        when OPC_AJMP   =>
                            case exe_state is
                                when ES_0 =>
                                    SET_PC_2(reg_op1(7 downto 5), reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc && (r)
                        --
                        when OPC_ANL_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc && (direct)
                        --
                        when OPC_ANL_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc && ((r))
                        --
                        when OPC_ANL_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc && #data
                        --
                        when OPC_ANL_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) && acc
                        --
                        when OPC_ANL_5  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) && #data
                        --
                        when OPC_ANL_6  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_AND;
                                    alu_src_1 <= reg_op3;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- cy & (bit)
                        --
                        when OPC_ANL_7  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_cy <= reg_cy and ram_in_bit_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- cy & ~(bit)
                        --
                        when OPC_ANL_8  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_cy <= reg_cy and (not ram_in_bit_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( a != (direct) )
                        --     pc <- pc + rel
                        -- if( a < (direct) )
                        --     cy <- 1
                        -- else
                        --     cy <- 0
                        --
                        when OPC_CJNE_1 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_acc /= ram_in_data ) then

                                        alu_src_3 <= reg_op3;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    if( reg_acc < ram_in_data ) then

                                        reg_cy <= '1';
                                    else

                                        reg_cy <= '0';
                                    end if;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( a != #data )
                        --     pc <- pc + rel
                        -- if( a < #data )
                        --     cy <- 1
                        -- else
                        --     cy <- 0
                        --
                        when OPC_CJNE_2 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_acc /= reg_op2 ) then

                                        alu_src_3 <= reg_op3;
                                    else
                                        alu_src_3 <= C0_8;
                                    end if;
                                    if( reg_acc < reg_op2 ) then

                                        reg_cy <= '1';
                                    else

                                        reg_cy <= '0';
                                    end if;
                                    exe_state <= ES_1;
                                    
                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( (r) != #data )
                        --     pc <- pc + rel
                        -- if( (r) < #data )
                        --     cy <- 1
                        -- else
                        --     cy <- 0
                        --
                        when OPC_CJNE_3 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( ram_in_data /= reg_op2 ) then
                                        
                                        alu_src_3 <= reg_op3;
                                    else
                                        
                                        alu_src_3 <= C0_8;
                                    end if;
                                    if( ram_in_data < reg_op2 ) then

                                        reg_cy <= '1';
                                    else

                                        reg_cy <= '0';
                                    end if;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( ((r)) != #data )
                        --     pc <- pc + rel
                        -- if( ((r)) < #data )
                        --     cy <- 1
                        -- else
                        --     cy <- 0
                        --
                        when OPC_CJNE_4 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;
                                    
                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( ram_in_data /= reg_op2 ) then
                                        
                                        alu_src_3 <= reg_op3;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    if( ram_in_data < reg_op2 ) then

                                        reg_cy <= '1';
                                    else

                                        reg_cy <= '0';
                                    end if;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- 0
                        --
                        when OPC_CLR_1  =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <= C0_8;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- 0
                        --
                        when OPC_CLR_2  =>
                            case exe_state is
                                when ES_0 =>
                                    reg_cy <= '0';
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (bit) <- 0
                        --
                        when OPC_CLR_3  =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_bit_data <= '0';
                                    START_WR_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- ~acc
                        --
                        when OPC_CPL_1  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_NOT;
                                    alu_src_1 <= reg_acc;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- ~cy
                        --
                        when OPC_CPL_2  =>
                            case exe_state is
                                when ES_0 =>
                                    reg_cy <= not reg_cy;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (bit) <- ~(bit)
                        --
                        when OPC_CPL_3  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_bit_data <= not ram_in_bit_data;
                                    START_WR_BIT_RAM(reg_op2);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_DA     =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_DA;
                                    alu_src_1 <= reg_acc;
                                    alu_src_cy <= reg_cy;
                                    alu_src_ac <= reg_ac;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc - 1
                        --
                        when OPC_DEC_1  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- (r) - 1
                        --
                        when OPC_DEC_2  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) - 1
                        --
                        when OPC_DEC_3  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --    
                        -- ((r)) <- ((r)) - 1
                        --    
                        when OPC_DEC_4  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_DIV    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_B);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_DIV;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_2;
                                    START_WR_RAM(R_B);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- (r) - 1
                        -- if( (r) != 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_DJNZ_1 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(v8);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( alu_des_1 /= C0_8 ) then

                                        alu_src_3 <= reg_op2;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) - 1
                        -- if( (direct) != 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_DJNZ_2 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( alu_des_1 /= C0_8 ) then

                                        alu_src_3 <= reg_op3;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc + 1
                        --
                        when OPC_INC_1  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- (r) + 1
                        --
                        when OPC_INC_2  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) + 1
                        --
                        when OPC_INC_3  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --    
                        -- ((r)) <- ((r)) + 1
                        --    
                        --    
                        when OPC_INC_4  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- dptr <- dptr + 1
                        --
                        when OPC_INC_5  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_DPL);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(R_DPH);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_DPL);
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= alu_des_cy;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_DPH);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( (bit) == 1 )
                        --     pc <- pc + rel
                        --
                        when OPC_JB     =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( ram_in_bit_data = '1' ) then

                                        alu_src_3 <= reg_op3;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( (bit) == 1 )
                        --     pc <- pc + rel
                        --     (bit) <- 0
                        --
                        when OPC_JBC    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( ram_in_bit_data = '1' ) then

                                        alu_src_3 <= reg_op3;
                                        ram_out_bit_data <= '0';
                                        START_WR_BIT_RAM(reg_op2);
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( cy == 1 )
                        --     pc <- pc + rel
                        --
                        when OPC_JC     =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_cy = '1' ) then

                                        alu_src_3 <= reg_op2;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- pc <- dptr + acc
                        --
                        when OPC_JMP    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_DPL);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(R_DPH);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_src_1 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    alu_op_code <= ALU_OPC_PCUADD;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_3 <= reg_acc;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( (bit) == 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_JNB    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( ram_in_bit_data = '0' ) then

                                        alu_src_3 <= reg_op3;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( cy == 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_JNC    =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_cy = '0' ) then

                                        alu_src_3 <= reg_op2;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( acc != 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_JNZ    =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_acc /= C0_8 ) then

                                        alu_src_3 <= reg_op2;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- if( acc == 0 )
                        --     pc <- pc + rel
                        --
                        when OPC_JZ     =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    if( reg_acc = C0_8 ) then

                                        alu_src_3 <= reg_op2;
                                    else

                                        alu_src_3 <= C0_8;
                                    end if;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- sp       <- sp + 1
                        -- mem(sp)  <- pc(7-0)
                        -- sp       <- sp + 1
                        -- mem(sp)  <- pc(15-8)
                        -- pc(15-0) <- address
                        --
                        when OPC_LCALL  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_SP);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= alu_des_1;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    ram_out_data <= pcl;
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PC_H(pch);
                                    ram_out_data <= pch;
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_SP);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    SET_PC_1(reg_op2, reg_op3);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- pc(15-0) <- address
                        --
                        when OPC_LJMP   =>
                            case exe_state is
                                when ES_0 =>
                                    SET_PC_1(reg_op2, reg_op3);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- (r)
                        --
                        when OPC_MOV_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- (direct)
                        --
                        when OPC_MOV_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- ((r))
                        --
                        when OPC_MOV_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- #data
                        --
                        when OPC_MOV_4  =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <= reg_op2;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- acc
                        --
                        when OPC_MOV_5  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- (direct)
                        --
                        when OPC_MOV_6  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (r) <- #data
                        --
                        when OPC_MOV_7  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= reg_op2;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- acc
                        --
                        when OPC_MOV_8  =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (r)
                        --
                        when OPC_MOV_9  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct)
                        --
                        when OPC_MOV_10 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(reg_op3);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- ((r))
                        --
                        when OPC_MOV_11 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- #data
                        --
                        when OPC_MOV_12 =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <= reg_op3;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- ((r)) <- acc
                        --
                        when OPC_MOV_13 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- ((r)) <- (direct)
                        --
                        when OPC_MOV_14 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_acc <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- ((r)) <- #data
                        --
                        when OPC_MOV_15 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= reg_op2;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- (bit)
                        --
                        when OPC_MOV_16 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_cy <= ram_in_bit_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (bit) <- cy
                        --
                        when OPC_MOV_17 =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_bit_data <= reg_cy;
                                    START_WR_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- dph <- #data-hi
                        -- dpl <- #data-lo
                        --
                        when OPC_MOV_18 =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <= reg_op2;
                                    START_WR_RAM(R_DPH);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= reg_op3;
                                    START_WR_RAM(R_DPL);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- (dptr + acc)
                        --
                        when OPC_MOVC_1 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_DPL);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(R_DPH);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_src_1 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    alu_op_code <= ALU_OPC_PCUADD;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_3 <= reg_acc;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    START_RD_ROM(alu_des_2, alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    ram_out_data <= rom_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- (pc + acc)
                        --
                        when OPC_MOVC_2 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCUADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    alu_src_3 <= reg_acc;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_ROM(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= rom_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- ((r))
                        --
                        when OPC_MOVX_1 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_XRM("00000000" & ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= xrm_in_data;
                                    START_WR_RAM(REG_ACC);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- (DPTR)
                        --
                        when OPC_MOVX_2 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_DPL);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(R_DPH);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_src_1 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    alu_op_code <= ALU_OPC_PCUADD;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_3 <= C0_8;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    START_RD_XRM(alu_des_2 & alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    ram_out_data <= xrm_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- ((r)) <- acc
                        --
                        when OPC_MOVX_3 =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    xrm_out_data <= reg_acc;
                                    START_WR_XRM("00000000" & ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (DPTR) <- acc
                        --
                        when OPC_MOVX_4 =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_DPL);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(R_DPH);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_src_1 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    alu_op_code <= ALU_OPC_PCUADD;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_3 <= C0_8;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    xrm_out_data <= reg_acc;
                                    START_WR_XRM(alu_des_2 & alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_MUL    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_B);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_MUL;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_2;
                                    START_WR_RAM(R_B);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- no operation
                        --
                        when OPC_NOP    =>
                            case exe_state is
                                when ES_0 =>
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc || (r)
                        --
                        when OPC_ORL_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc || (direct)
                        --
                        when OPC_ORL_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc || ((r))
                        --
                        when OPC_ORL_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc || #data
                        --
                        when OPC_ORL_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) || acc
                        --
                        when OPC_ORL_5  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) || #data
                        --
                        when OPC_ORL_6  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_OR;
                                    alu_src_1 <= reg_op3;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- cy | (bit)
                        --
                        when OPC_ORL_7  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_cy <= reg_cy or ram_in_bit_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- cy | ~(bit)
                        --
                        when OPC_ORL_8  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    reg_cy <= reg_cy or (not ram_in_bit_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (sp)
                        -- sp <- sp - 1
                        --
                        when OPC_POP    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_SP);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_SP);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- sp <- sp + 1
                        -- (sp) <- (direct)
                        --
                        when OPC_PUSH   =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_SP);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_SP);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- pc(15-8) <- (sp)
                        -- sp <- sp - 1
                        -- pc(7-0) <- (sp)
                        -- sp <- sp - 1
                        --
                        when OPC_RET    =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(R_SP);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    START_RD_RAM(alu_des_1);
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= alu_des_1;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '1';
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    SET_PC_H(ram_in_data);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    SET_PC_L(ram_in_data);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_SP);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_RL     =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_RL;
                                    alu_src_1 <= reg_acc;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_RLC    =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_RLC;
                                    alu_src_1 <= reg_acc;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_RR     =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_RR;
                                    alu_src_1 <= reg_acc;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- see I8051_ALU
                        --
                        when OPC_RRC    =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_RRC;
                                    alu_src_1 <= reg_acc;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- cy <- 1
                        --
                        when OPC_SETB_1 =>
                            case exe_state is
                                when ES_0 =>
                                    reg_cy <= '1';
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (bit) <- 1
                        --
                        when OPC_SETB_2 =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_bit_data <= '1';
                                    START_WR_BIT_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- pc <- pc + rel
                        --
                        when OPC_SJMP   =>
                            case exe_state is
                                when ES_0 =>
                                    GET_PC_H(pch);
                                    GET_PC_L(pcl);
                                    alu_op_code <= ALU_OPC_PCSADD;
                                    alu_src_1 <= pcl;
                                    alu_src_2 <= pch;
                                    alu_src_3 <= reg_op2;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    SET_PC_1(alu_des_2, alu_des_1);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc - cy - (r)
                        --
                        when OPC_SUBB_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc - cy - (direct)
                        --
                        when OPC_SUBB_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc - cy - ((r))
                        --
                        when OPC_SUBB_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc - cy - #data
                        --
                        when OPC_SUBB_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_SUB;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    alu_src_cy <= reg_cy;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    reg_cy <= alu_des_cy;
                                    reg_ac <= alu_des_ac;
                                    reg_ov <= alu_des_ov;
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    GET_PSW(v8);
                                    ram_out_data <= v8;
                                    START_WR_RAM(R_PSW);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc(3-0) <-> acc(7-4)
                        --
                        when OPC_SWAP   =>
                            case exe_state is
                                when ES_0 =>
                                    ram_out_data <=
                                    reg_acc(3 downto 0) & reg_acc(7 downto 4);
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <-> (r)
                        --
                        when OPC_XCH_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_RAM_ADDR_1(v8);
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(v8);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <-> (direct)
                        --
                        when OPC_XCH_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <-> ((r))
                        --
                        when OPC_XCH_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= reg_acc;
                                    START_WR_RAM(ram_in_data);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <= ram_in_data;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc(3-0) <-> ((r))(3-0)
                        --
                        when OPC_XCHD   =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_ADD;
                                    alu_src_1 <= ram_in_data;
                                    alu_src_2 <= C0_8;
                                    alu_src_cy <= '0';
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    START_RD_RAM(alu_des_1);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    ram_out_data <=
                                    ram_in_data(7 downto 4) &
                                    reg_acc(3 downto 0);
                                    START_WR_RAM(alu_des_1);
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <=
                                    reg_acc(7 downto 4) &
                                    ram_in_data(3 downto 0);
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc ^ (r)
                        --
                        when OPC_XRL_1  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_1(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc ^ (direct)
                        --
                        when OPC_XRL_2  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc ^ ((r))
                        --
                        when OPC_XRL_3  =>
                            case exe_state is
                                when ES_0 =>
                                    GET_RAM_ADDR_2(v8);
                                    START_RD_RAM(v8);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    START_RD_RAM(ram_in_data);
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- acc <- acc ^ #data
                        --
                        when OPC_XRL_4  =>
                            case exe_state is
                                when ES_0 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= reg_op2;
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(R_ACC);
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) ^ acc
                        --
                        when OPC_XRL_5  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_acc;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        --
                        -- (direct) <- (direct) ^ #data
                        --
                        when OPC_XRL_6  =>
                            case exe_state is
                                when ES_0 =>
                                    START_RD_RAM(reg_op2);
                                    exe_state <= ES_1;

                                when ES_1 =>
                                    exe_state <= ES_2;

                                when ES_2 =>
                                    alu_op_code <= ALU_OPC_XOR;
                                    alu_src_1 <= reg_op3;
                                    alu_src_2 <= ram_in_data;
                                    exe_state <= ES_3;

                                when ES_3 =>
                                    ram_out_data <= alu_des_1;
                                    START_WR_RAM(reg_op2);
                                    exe_state <= ES_4;

                                when ES_4 =>
                                    exe_state <= ES_5;

                                when ES_5 =>
                                    exe_state <= ES_6;

                                when ES_6 =>
                                    exe_state <= ES_7;

                                when ES_7 =>
                                    SHUT_DOWN_ALU;
                                    cpu_state <= CS_1;
                                    exe_state <= ES_0;
                            end case;

-------------------------------------------------------------------------------

                        when others     => null;
                    end case;
            end case;
        end if;
    end process;
    dec_op_out <= reg_op1;
end BHV;

-------------------------------------------------------------------------------

-- end of file --
