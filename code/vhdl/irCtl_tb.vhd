----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.11.2019 15:35:20
-- Design Name: 
-- Module Name: irSniffer_tb - Behavioral
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

entity irCtl_tb is
--  Port ( );
end irCtl_tb;

architecture Behavioral of irCtl_tb is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

component irCtl_top
    generic   ( SYS_RST_VAL     : integer   := 10 -- no. of clock cycles before reset disabled (Default = 100000)
                );
    port      ( CLK             : in    std_logic;
                -- IR SIGNALS
                IR_RX           : in    std_logic;
                IR_TX           : out   std_logic;
                -- SPI SIGNALS
                SCLK            : in    std_logic; -- SPI clock
                CS_N            : in    std_logic; -- SPI chip select, active in low
                MOSI            : in    std_logic; -- SPI serial data from master to slave
                MISO            : out   std_logic  -- SPI serial data from slave to master
                );
end component;

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

-- CLOCK SIGNALS
signal      sysClk              : std_logic;
constant    clkHP               : time                              := 10ns;

-- IR SIGNALS
signal      irRxTmp             : std_logic_vector(31 downto 0)     := "11100000111000000000100011110111";
signal      irRx                : std_logic; 
signal      irTx                : std_logic; 
constant    irStart             : time                              := 5ms;
constant    irStartLow          : time                              := 4.5ms;
constant    irStartHigh         : time                              := 4.5ms;
constant    irRxLow             : time                              := 0.579ms;
constant    irRxZero            : time                              := 1.125ms - irRxLow;
constant    irRxOne             : time                              := 2.25ms - irRxLow;
constant    irRepeat            : time                              := 500ms;

-- SPI SIGNALS
signal      sclk                : std_logic;
signal      cs_n                : std_logic;
signal      mosi                : std_logic;
signal      miso                : std_logic;
signal      sclkHalfPeriod      : time                              := 500ns;
signal      spiDataStart        : time                              := 77.1ms;
signal      spiRepeat           : time                              := 5000ms;

signal      mosiDataByte1       : std_logic_vector(7 downto 0)      := "00000111";
signal      mosiDataByte2       : std_logic_vector(7 downto 0)      := "00000111";
signal      mosiDataByte3       : std_logic_vector(7 downto 0)      := "00010000";
signal      mosiDataByte4       : std_logic_vector(7 downto 0)      := "11101111";

begin

    -----------------------------------------------------------------------------------
    ------------------------ COMPONENT INSTANTIATIONS ---------------------------------
    -----------------------------------------------------------------------------------
    
    TOP : irCtl_top
    port map  ( CLK             => sysClk,
                IR_RX           => irRx,
                IR_TX           => irTx,
                -- SPI SLAVE INTERFACE
                SCLK            => sclk,
                CS_N            => cs_n,
                MOSI            => mosi,
                MISO            => miso
                );

    -----------------------------------------------------------------------------------
    -------------------------------- MAIN PROCESSES -----------------------------------
    -----------------------------------------------------------------------------------
    
    ------------------------------------ CLOCKS ---------------------------------------
    
    -- 50 MHZ CLOCK
    process
        begin
            sysClk <= '0';
        wait for clkHP;
            sysClk <= '1';          
        wait for clkHP;    
    end process;
    
    ----------------------------------- IR SIGNALS ------------------------------------
    
    -- IR RX
    process
    begin  
        irRx <= '1';        -- pull high when no transfer
        wait for irStart;
        irRx <= '0';        -- start bit low
        wait for irStartLow;
        irRx <= '1';        -- start bit high  
        wait for irStartHigh;
        
        for ni in 0 to 31 loop
            irRx <= '0';        -- low
            wait for irRxLow;
            irRx <= '1';        -- high
            if (irRxTmp(-ni+31) = '0') then
                wait for irRxZero;
            else
                wait for irRxOne;
            end if;
        end loop;
        
        irRx <= '0';        -- low
        wait for irRxLow;
        irRx <= '1';        -- end transmission  
        wait for irRepeat;
        
    end process;
    
    ---------------------------------- SPI SIGNALS -----------------------------------
    
    -- CHIP SELECT
    process
    begin 
        cs_n <= '1';
        wait for spiDataStart;
        cs_n <= '0';     
        wait for sclkHalfPeriod*84;
        cs_n <= '1';
        wait for spiRepeat;
    end process;
    
    -- SCLK Process
    process
    begin
        sclk <= '0';
        wait for spiDataStart + (sclkHalfPeriod*20);
        for nii in 0 to 31 loop
            sclk <= '1';
            wait for sclkHalfPeriod;
            sclk <= '0';
            wait for sclkHalfPeriod;
        end loop;
        wait for spiRepeat;     
    end process;
    
    -- MOSI 
    process
    begin
        -- pull low for when no transfer
        mosi <= '0';
        wait for spiDataStart + (sclkHalfPeriod*19); 
        
        -- byte 1 
        for ni in 0 to 7 loop
            mosi <= mosiDataByte1(-ni+7);
            wait for sclkHalfPeriod*2;
        end loop;
        
        -- byte 2 
        for ni in 0 to 7 loop
            mosi <= mosiDataByte2(-ni+7);
            wait for sclkHalfPeriod*2;
        end loop;
        
        -- byte 3 
        for ni in 0 to 7 loop
            mosi <= mosiDataByte3(-ni+7);
            wait for sclkHalfPeriod*2;
        end loop;
        
        -- byte 4 
        for ni in 0 to 7 loop
            mosi <= mosiDataByte4(-ni+7);
            wait for sclkHalfPeriod*2;
        end loop;
        
        mosi <= '0';
        wait for spiRepeat; 
    end process;

end Behavioral;
