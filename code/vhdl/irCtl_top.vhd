----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.11.2019 14:56:22
-- Design Name: 
-- Module Name: irSniffer_top - Behavioral
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

entity irCtl_top is
    generic   ( SYS_RST_VAL     : integer   := 100000  -- no. of clock cycles before reset disabled [Default = 100000]
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
end irCtl_top;

architecture Behavioral of irCtl_top is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

-- CLKS
component clks
    port      ( SYS_RST         : in    std_logic;
                CLK             : in    std_logic;
                CLK_38K_FLG     : out   std_logic;
                CLK_38K_HD      : out   std_logic
                );
end component;

-- IR DECODER
component irDecoder
    port      ( SYS_RST         : in std_logic;
                CLK             : in std_logic;
                IR_RX           : in std_logic;
                IR_TX_BUSY      : in std_logic;
                IR_RX_DECODE    : out std_logic_vector(31 downto 0);
                IR_RX_DONE_FLG  : out std_logic;
                IR_RX_ERR_FLG   : out std_logic
                );
end component;

-- IR ENCODER
component irEncoder
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
end component;

-- SPI SLAVE
component spiSlave
    port      ( CLK      : in  std_logic; -- system clock
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
end component;

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

-- SYSTEM RESET 
signal  sysRst              : std_logic;
signal  sysRstCnt           : integer range 0 to SYS_RST_VAL;

-- CLOCKS
signal  clk38kFlg           : std_logic;
signal  clk38kHD            : std_logic;

-- IR SIGNALS
signal  irRxDecode          : std_logic_vector(31 downto 0);
signal  irRxDoneFlg         : std_logic;
signal  irRxErrFlg          : std_logic;

-- SPI SIGNALS
signal  spiByteFlg          : std_logic;
signal  spiDataOut          : std_logic_vector(7 downto 0);
signal  dinBuff             : std_logic_vector(7 downto 0);
signal  din                 : std_logic_vector(7 downto 0);

-- IR DATA TRANSMISSION
signal  rxNewData           : std_logic;
signal  spiData             : std_logic_vector(31 downto 0);
type    irRxDataState_type  is (irRxDataState_idle, irRxDataState_checkData, irRxDataState_hold);
signal  irRxDataState       : irRxDataState_type;
signal  dinCount            : unsigned (1 downto 0);

-- IR ENCODING
signal  irTxBusy            : std_logic;

begin

    -----------------------------------------------------------------------------------
    ------------------------ COMPONENT INSTANTIATIONS ---------------------------------
    -----------------------------------------------------------------------------------
    
    -- CLOCKS
    clksComp : clks
        port map  ( SYS_RST         => sysRst,
                    CLK             => CLK,
                    CLK_38K_FLG     => clk38kFlg,
                    CLK_38K_HD      => clk38kHD
                    );
    
    -- IR DECODER
    irDecoderComp : irDecoder
        port map  ( SYS_RST         => sysRst,
                    CLK             => CLK,
                    IR_RX           => IR_RX,
                    IR_TX_BUSY      => irTxBusy,
                    IR_RX_DECODE    => irRxDecode,
                    IR_RX_DONE_FLG  => irRxDoneFlg,
                    IR_RX_ERR_FLG   => irRxErrFlg
                    );
                    
    -- IR ENCODER
    irEncoderComp: irEncoder
        port map  ( CLK             => CLK,
                    SYS_RST         => sysRst,
                    -- 38kHZ CLOCKS
                    CLK_38K_FLG     => clk38kFlg,
                    CLK_38K_HD      => clk38kHD,
                    -- SPI
                    SPI_BYTE_FLG    => spiByteFlg,
                    SPI_DATA_OUT    => spiDataOut,
                    DIN_CNT         => dinCount,
                    -- IR
                    IR_TX           => IR_TX,
                    IR_TX_BUSY      => irTxBusy 
                    );
                    
    -- SPI SLAVE
    spiSlaveComp : spiSlave
        port map  ( CLK             => CLK,
                    RST             => sysRst,
                    -- SPI SLAVE INTERFACE
                    SCLK            => SCLK,
                    CS_N            => CS_N,
                    MOSI            => MOSI,
                    MISO            => MISO,
                    -- USER INTERFACE
                    DIN             => din,
                    DOUT            => spiDataOut,
                    L_BIT           => spiByteFlg
                    );
    
    -----------------------------------------------------------------------------------
    -------------------------------- MAIN PROCESSES -----------------------------------
    -----------------------------------------------------------------------------------

    -------------------------------- SYSTEM RESET -------------------------------------
    -- holds the system in reset for a given amount of time
    
    -- counts up the system reset value before going back to 0, and then being disabled 
    -- by rstSys being set high
    process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (sysRst = '1') then
                if (sysRstCnt = SYS_RST_VAL) then 
                    sysRstCnt <= 0;
                else
                    sysRstCnt <= sysRstCnt + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- main system reset set net, goes high when count is reached
    sysRst <= '0' when (sysRstCnt = SYS_RST_VAL) else '1';
    
    ------------------------------ IR DATA TRANSMISSION -------------------------------
    
    -- checks when the spi cs line goes low, then if there is no new ir data it sends
    -- the value of 0 over the spi line, else it sends the data
    process(sysRst, CLK)
    begin
        if (sysRst = '1') then
            spiData <= (others => '0');
            rxNewData <= '0';
            irRxDataState <= irRxDataState_idle;
        elsif (rising_edge(CLK)) then
            case irRxDataState is
            
            -- wait for cs line to go low
            when irRxDataState_idle =>
                if (irRxDoneFlg = '1') then
                    rxNewData <= '1';
                end if;
                if (CS_N = '0') then
                    irRxDataState <= irRxDataState_checkData;
                end if;
            
            -- checks if there is any new ir rx data and sets spi data
            when irRxDataState_checkData =>
                irRxDataState <= irRxDataState_hold;
                if (rxNewData = '1') then
                    spiData <= irRxDecode;
                    rxNewData <= '0';  
                else
                    spiData <= (others => '0');
                end if;
                
            -- holds untill data is sent
            when irRxDataState_hold =>
                if (CS_N = '1') then
                    irRxDataState <= irRxDataState_idle;
                end if;
                
            end case;
        end if;
    end process;
    
    -- counts 4 bytes of spi data, resets when chip select line high
    process(CS_N, CLK)
    begin
        if (CS_N = '1') then
            dinCount <= "00";
        elsif (rising_edge(CLK)) then
            if (spiByteFlg = '1') then
                if (dinCount = "11") then
                    dinCount <= "00";
                else
                    dinCount <= dinCount + "1";
                end if;
            end if;
        end if;
    end process;
    
    -- send the spi data byte data to spi data in buffer
    dinBuff <=  spiData(7 downto 0)     when (dinCount = "00") else
                spiData(15 downto 8)    when (dinCount = "01") else
                spiData(23 downto 16)   when (dinCount = "10") else
                spiData(31 downto 24)   when (dinCount = "11") else
                (others => '0');
    
    -- send to data input    
    din <= dinBuff when (CS_N = '0') else (others => '0');     
    
    
end Behavioral;
