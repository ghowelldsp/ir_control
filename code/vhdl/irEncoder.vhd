----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.04.2020 11:47:07
-- Design Name: 
-- Module Name: irEncoder - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-----------------------------------------------------------------------------
-------------------------- IO DECLERATIONS ----------------------------------
-----------------------------------------------------------------------------

entity irEncoder is
    generic   ( IR_ST_TOT_VAL   : integer   := 342;     -- total ir start pulse time [13.5ms @ 38kHz]
                IR_ST_HIGH_VAL  : integer   := 171;     -- time till ir start pulse held high [9ms @ 38kHz]
                IR_PUL_HIGH_VAL : integer   := 22;      -- time each pulse is held low for [0.6ms @ 1Mhz] 
                IR_PUL_ZERO_VAL : integer   := 43;      -- time each '0' pulse is held for [1.125ms @ 38kHz] 
                IR_PUL_ONE_VAL  : integer   := 85       -- time each '1' pulse is held for [2.25ms @ 38kHz]    
                );
    port      ( CLK             : in    std_logic;
                SYS_RST         : in    std_logic;
                -- 38kHZ CLOCKS
                CLK_38K_FLG     : in   std_logic;
                CLK_38K_HD      : in   std_logic;
                -- SPI
                SPI_BYTE_FLG    : in    std_logic;
                SPI_DATA_OUT    : in    std_logic_vector(7 downto 0);
                DIN_CNT         : in    unsigned (1 downto 0);
                -- IR
                IR_TX           : out   std_logic;
                IR_TX_BUSY      : out   std_logic   
                );
end irEncoder;

architecture Behavioral of irEncoder is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

signal  spiByteOffsetFlg    : std_logic;
signal  irTxData            : std_logic_vector(31 downto 0);
signal  spiLstByteFlg       : std_logic;
signal  irTxTmp             : std_logic;
signal  irTxNi              : integer range 0 to 32;
type    irEncodeState_type  is (irEncodeState_idle, irEncodeState_startPul, irEncodeState_pulseHigh, irEncodeState_pulseType, irEncodeState_pulseZero, irEncodeState_pulseOne);
signal  irEncodeState       : irEncodeState_type;
signal  irTxCnt             : integer range 0 to IR_ST_TOT_VAL;

begin

    -----------------------------------------------------------------------------
    ------------------------ COMPONENT INSTANTIATIONS ---------------------------
    -----------------------------------------------------------------------------
    
    -----------------------------------------------------------------------------
    -------------------------------- MAIN PROCESSES -----------------------------
    -----------------------------------------------------------------------------
    
    ------------------------------ IR ENCODE -------------------------------  
    -- get the data send over spi and encode it to the ir format and 
    -- transmit it
    
    -- offset the last read flag by 1 cycle
    process(SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            spiByteOffsetFlg <= '0';
        elsif (rising_edge(CLK)) then
            spiByteOffsetFlg <= SPI_BYTE_FLG;
        end if;
    end process;
    
    -- stores the data from the spi mosi line
    process(SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            irTxData <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (SPI_BYTE_FLG = '1') then
                irTxData(23 downto 0) <= irTxData(31 downto 8);
            elsif (spiByteOffsetFlg = '1') then
                irTxData(31 downto 24) <= SPI_DATA_OUT;
            end if;
        end if;
    end process;
    
    -- flag to signal last byte of data has been recieved
    spiLstByteFlg <= spiByteOffsetFlg when (DIN_CNT = "00") else '0';
    
    -- encodes the ir signal from the spi data
    process(SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            irTxNi <= 0;
            irTxTmp <= '0';
            IR_TX_BUSY <= '0';
            irEncodeState <= irEncodeState_idle;
        elsif (rising_edge(CLK)) then
            case irEncodeState is
            
            -- stays in idle until the last data byte from the SPI line is recieved
            when irEncodeState_idle =>
                irTxNi <= 0;
                irTxCnt <= 0;
                irTxTmp <= '0';
                if (spiLstByteFlg = '1' and irTxData /= x"00000000") then
                    IR_TX_BUSY <= '1';
                    irEncodeState <= irEncodeState_startPul; 
                end if;
            
            -- initiates start pulse
            when irEncodeState_startPul =>
                if (CLK_38K_FLG = '1') then
                    if (irTxCnt = IR_ST_TOT_VAL) then
                        irTxCnt <= 0;
                        irTxTmp <= '1';
                        irEncodeState <= irEncodeState_pulseHigh; 
                    elsif (irTxCnt >= IR_ST_HIGH_VAL and irTxCnt < IR_ST_TOT_VAL) then
                        irTxTmp <= '0';
                        irTxCnt <= irTxCnt + 1;
                    else
                        irTxTmp <= '1';
                        irTxCnt <= irTxCnt + 1;
                    end if;
                end if;
            
            -- initiates all the high parts of the signal
            when irEncodeState_pulseHigh =>
                if (CLK_38K_FLG = '1') then
                    irTxTmp <= '1';
                    if (irTxCnt = IR_PUL_HIGH_VAL-1) then
                        irTxTmp <= '0';
                        irTxCnt <= irTxCnt + 1;
                        irEncodeState <= irEncodeState_pulseType; 
                    else
                        irTxCnt <= irTxCnt + 1;
                    end if;
                end if;
            
            -- chooses between a short pulse for '0' and a longer pulse for '1' 
            when irEncodeState_pulseType =>
                if (irTxNi = 32) then
                    IR_TX_BUSY <= '0';
                    irTxTmp <= '0';
                    irEncodeState <= irEncodeState_idle;    
                else
                    if (irTxData(irTxNi) = '0') then
                        irEncodeState <= irEncodeState_pulseZero;
                    elsif (irTxData(irTxNi) = '1') then
                        irEncodeState <= irEncodeState_pulseOne;
                    end if;
                    irTxNi <= irTxNi + 1;
                end if;
            
            -- sets the ir tx line low for required pulse time for '0'
            when irEncodeState_pulseZero => 
                if (CLK_38K_FLG = '1') then
                    if (irTxCnt = IR_PUL_ZERO_VAL-1) then
                        irTxCnt <= 0;
                        irTxTmp <= '1';
                        irEncodeState <= irEncodeState_pulseHigh;
                    else
                        irTxCnt <= irTxCnt + 1;
                    end if;
                end if;  
            
            -- sets the ir tx line low for required pulse time for '1'
            when irEncodeState_pulseOne => 
                if (CLK_38K_FLG = '1') then
                    if (irTxCnt = IR_PUL_ONE_VAL-1) then
                        irTxCnt <= 0;
                        irTxTmp <= '1';
                        irEncodeState <= irEncodeState_pulseHigh;
                    else
                        irTxCnt <= irTxCnt + 1;
                    end if;
                end if;
                
            end case;            
        end if;
    end process;
    
    -- modulate ir tx signal by 38kHz half duty clock
    IR_TX <= CLK_38K_HD when (irTxTmp = '1') else '0';
    
end Behavioral;
