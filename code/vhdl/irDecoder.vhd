----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.11.2019 16:13:31
-- Design Name: 
-- Module Name: irDecoder - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-----------------------------------------------------------------------------
-------------------------- IO DECLERATIONS ----------------------------------
-----------------------------------------------------------------------------

entity irDecoder is
    generic   ( -- time thresholds [us * 50]
                MIN_ST_PUL      : integer   := 3500 * 50;   -- 8ms
                MAX_ST_PUL      : integer   := 10000 * 50;  -- 10ms
                MIN_ZERO_VAL    : integer   := 750 * 50;    -- 0.75ms
                ZO_THRES_VAL    : integer   := 1750 * 50;   -- 1.75ms
                MAX_ONE_VAL     : integer   := 2750 * 50;   -- 2.75ms
                DATA_FIN_VAL    : integer   := 6000 * 50    -- 6.00ms - data timeout value
                );
    port      ( SYS_RST         : in std_logic;
                CLK             : in std_logic;
                IR_RX           : in std_logic;
                IR_TX_BUSY      : in std_logic;
                IR_RX_DECODE    : out std_logic_vector(31 downto 0);
                IR_RX_DONE_FLG  : out std_logic;
                IR_RX_ERR_FLG   : out std_logic
                );
end irDecoder;

architecture Behavioral of irDecoder is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

-- IR SYNC SIGNALS
signal      irRxSync            : std_logic;
signal      irRxSyncOffset      : std_logic;
signal      irRxRiseFlg         : std_logic;
signal      irRxFallFlg         : std_logic;

-- DECODE IR SIGNALS
type decodeRxState_type is (decodeRxState_idle, decodeRxState_startPulse, decodeRxState_startRead, decodeRxState_read);
signal      decodeRxState       : decodeRxState_type;
signal      irRxCnt             : integer range 0 to MAX_ST_PUL;
signal      irRxTmp             : std_logic_vector (31 downto 0);
signal      bitInd              : integer range 0 to 32;
signal      irRxDoneFlg         : std_logic;
signal      irRxErrFlg          : std_logic;

begin

    -----------------------------------------------------------------------------------
    ------------------------ COMPONENT INSTANTIATIONS ---------------------------------
    -----------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------
    -------------------------------- MAIN PROCESSES -----------------------------------
    -----------------------------------------------------------------------------------
    
    -------------------------------- IR SIGNAL SYNC -----------------------------------
    -- creates a ir rx signal that is synced to the clock, and another that is delayed
    -- by one clock sample, then creates two flag signals for the rise and fall of the 
    -- ir data
    
    -- sync and offest signals      
    process (SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            irRxSync <= '1';
            irRxSyncOffset <= '1';        
        elsif (rising_edge(CLK)) then
            irRxSync <= IR_RX;
            irRxSyncOffset <= irRxSync;
        end if;
    end process;
    
    -- ir rx rise and fall indicator flags
    irRxFallFlg <= '1' when (irRxSync = '0' and irRxSyncOffset = '1') else '0';
    irRxRiseFlg <= '1' when (irRxSync = '1' and irRxSyncOffset = '0') else '0';
   
   
    -------------------------------- DECODE RX STATE ----------------------------------
    -- manages the state for reading the data from the rx signal
    -- sits in 'idle' untill rx signal goes low. enters 'startCheck' where it 
    -- checks to see if the data pulse is within 9ms NEC limits, if not goes 
    -- back to 'idle'.
  
    -- state process
    process (SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            irRxDoneFlg <= '0';
            irRxErrFlg <= '0';
            irRxTmp <= (others => '0');
            decodeRxState <= decodeRxState_idle;
        elsif (rising_edge(CLK)) then
            case decodeRxState is
            
            -- stays in idle until ir rx goes low
            when decodeRxState_idle =>
                irRxDoneFlg <= '0';
                irRxErrFlg <= '0';
                irRxCnt <= 0;
                bitInd <= 0;
                if (irRxFallFlg = '1' and IR_TX_BUSY = '0') then
                    decodeRxState <= decodeRxState_startPulse;
                end if;
            
            -- checks if start pulse is with limits    
            when decodeRxState_startPulse =>
                if (irRxRiseFlg = '1') then
                    irRxCnt <= 0;
                    if (irRxCnt > MIN_ST_PUL and irRxCnt < MAX_ST_PUL) then
                        decodeRxState <= decodeRxState_startRead; 
                    else
                        irRxErrFlg <= '1';
                        decodeRxState <= decodeRxState_idle;     
                    end if;
                else
                    if (irRxCnt < DATA_FIN_VAL) then 
                        irRxCnt <= irRxCnt + 1;
                    else
                        irRxErrFlg <= '1';
                        decodeRxState <= decodeRxState_idle;
                    end if;   
                end if;
            
            -- wait till the 1st bit to start the read counting
            when decodeRxState_startRead =>
                if (irRxFallFlg = '1') then
                    irRxCnt <= 0;
                    decodeRxState <= decodeRxState_read;
                else
                    if (irRxCnt < DATA_FIN_VAL) then 
                        irRxCnt <= irRxCnt + 1;
                    else
                        irRxErrFlg <= '1';
                        decodeRxState <= decodeRxState_idle;
                    end if;   
                end if; 
            
            -- read the in the data bytes
            when decodeRxState_read =>
                if (irRxFallFlg = '1') then
                    irRxCnt <= 0;
                    bitInd <= bitInd + 1;
                    if (irRxCnt > MIN_ZERO_VAL and irRxCnt < (ZO_THRES_VAL+1)) then
                        irRxTmp(bitInd) <= '0';
                    elsif (irRxCnt > ZO_THRES_VAL and irRxCnt < MAX_ONE_VAL) then
                        irRxTmp(bitInd) <= '1';
                    else
                        irRxErrFlg <= '1';
                        decodeRxState <= decodeRxState_idle;        
                    end if;
                else
                    if (irRxRiseFlg = '1' and bitInd = 32) then
                        irRxDoneFlg <= '1';
                        decodeRxState <= decodeRxState_idle;
                    else
                        if (irRxCnt < DATA_FIN_VAL) then 
                            irRxCnt <= irRxCnt + 1;
                        else
                            irRxErrFlg <= '1';
                            decodeRxState <= decodeRxState_idle;
                        end if;
                    end if;
                end if;
                    
            end case;
        end if;
    end process; 
    
    -------------------------------- OUTPUT BUFFER ------------------------------------
    -- outputs the data everytime the dataTxFlf is rasied
  
    -- output buffer
    process (SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            IR_RX_DECODE <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (irRxDoneFlg = '1') then
                IR_RX_DECODE <= irRxTmp;
            end if;
        end if;
    end process;
    
    -- buffer data tx flag to output
    IR_RX_DONE_FLG <= irRxDoneFlg when (SYS_RST = '0') else '0';
    IR_RX_ERR_FLG <= irRxErrFlg when (SYS_RST = '0') else '0';

end Behavioral;
