--------------------------------------------------------------------------------
-- PROJECT: SPI MASTER AND SLAVE FOR FPGA
--------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.03.2020 13:19:19
-- Design Name: 
-- Module Name: spi_slave - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-----------------------------------------------------------------------------
-------------------------- IO DECLERATIONS ----------------------------------
-----------------------------------------------------------------------------

entity spiSlave is
    port  ( CLK      : in  std_logic; -- system clock
            RST      : in  std_logic; -- high active synchronous reset
            -- SPI SLAVE INTERFACE
            SCLK     : in  std_logic; -- SPI clock
            CS_N     : in  std_logic; -- SPI chip select, active in low
            MOSI     : in  std_logic; -- SPI serial data from master to slave
            MISO     : out std_logic; -- SPI serial data from slave to master
            -- USER INTERFACE
            DIN      : in  std_logic_vector(7 downto 0);    -- input data for SPI master
            DOUT     : out std_logic_vector(7 downto 0);    -- output data from SPI master
            L_BIT    : out std_logic                        -- signal indicating the last bit has been received
            );
end spiSlave;

architecture RTL of spiSlave is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

-- sclk signals
signal sclk_latch           : std_logic;
signal sclk_offset          : std_logic;
signal sclkRiseTick         : std_logic;
signal sclkFallTick         : std_logic;

-- bit counter signals
signal bitCount             : unsigned(2 downto 0);
signal bitCount1            : unsigned(2 downto 0);
signal lastBitTick          : std_logic;

-- mosi signals
signal mosiShftReg          : std_logic_vector (7 downto 0);
signal mosiData             : std_logic_vector (7 downto 0);

-- miso signals
signal misoBuff             : std_logic;

begin

-----------------------------------------------------------------------------------
------------------------ COMPONENT INSTANTIATIONS ---------------------------------
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
-------------------------------- MAIN PROCESSES -----------------------------------
-----------------------------------------------------------------------------------

    -------------------------------- SCLK LATCH -----------------------------------
    -- latches the sclk clock to the system clock and creates rise and fall flags
    
    -- latch the incoming clock from the master spi device, then latch the same
    -- clock but offset by 1 sys clock cycle to an offset signal
    process (RST, CLK)
    begin
        if (RST = '1') then
            sclk_latch <= '0';
            sclk_offset <= '0';    
        elsif (rising_edge(CLK)) then
            sclk_latch <= SCLK;
            sclk_offset <= sclk_latch;           
        end if;
    end process;
    
    -- create master clock rise and fall flags from latched clock signal and offset
    -- clock signal
    sclkRiseTick <= '1' when (sclk_latch = '1' and sclk_offset = '0') else '0';
    sclkFallTick <= '1' when (sclk_latch = '0' and sclk_offset = '1') else '0';
    
    
    -------------------------------- BIT COUNTER ----------------------------------
    -- counts the number of clock cycles of the sclk clock
    
    -- counts up to 8 bits on the falling edge of the master clock, then resets
    process (RST, CLK)
    begin
        if (RST = '1') then
            bitCount <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (sclkFallTick = '1') then
                if (bitCount = "111") then
                    bitCount <= (others => '0');
                else
                    bitCount <= bitCount + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- raises a flag on the falling edge of the 8th bit
    lastBitTick <= '1' when (bitCount = "111" and sclkFallTick = '1') else '0';
    L_BIT <= lastBitTick;
    
    -- counts up to 8 bits on the rising edge of the master clock, then resets
    process (RST, CLK)
    begin
        if (RST = '1') then
            bitCount1 <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (sclkRiseTick = '1') then
                if (bitCount1 = "111") then
                    bitCount1 <= (others => '0');
                else
                    bitCount1 <= bitCount1 + 1;
                end if;
            end if;
        end if;
    end process;
    
    
    -------------------------------- MOSI -------------------------------------
    
    -- captures the current mosi bit on the rising edge off the master
    -- clock, shifts register and stores in LSB
    process (RST, CLK)
    begin
        if (RST = '1') then
            mosiShftReg <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (sclkRiseTick = '1') then
                mosiShftReg <= mosiShftReg(6 downto 0) & MOSI;
            end if;
        end if;
    end process;
    
    -- saves the final 8 bit value recieved from then MOSI on the falling 
    -- edge of the last bit    
    process (RST, CLK)
    begin
        if (RST = '1') then
            mosiData <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (lastBitTick = '1') then
                mosiData <= mosiShftReg;
            end if;
        end if;
    end process;
    
    -- send data out of module 
    DOUT <= mosiData;
    
    -------------------------------- MISO -------------------------------------
    
    -- selects the output bit to stream to MISO
    misoBuff <= DIN(0) when (bitCount1 = "111") else
                DIN(1) when (bitCount1 = "110") else
                DIN(2) when (bitCount1 = "101") else
                DIN(3) when (bitCount1 = "100") else
                DIN(4) when (bitCount1 = "011") else
                DIN(5) when (bitCount1 = "010") else
                DIN(6) when (bitCount1 = "001") else
                DIN(7);
    
    -- buffers the miso line to the output when chip select line is low           
    MISO <= misoBuff when (CS_N = '0') else '0';
    
end RTL;