----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04.04.2020 15:41:00
-- Design Name: 
-- Module Name: clks - Behavioral
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

entity clks is
    generic   ( CLK_38K_VAL     : integer   := 1316;    -- no. of clock cycles to create 38kHz clock [1316 @ 50Mhz sys clk]
                CLK_HD_38K_VAL  : integer   := 658      -- no. of clock cycles to create 38kHz half duty clock [658 @ 50Mhz sys clk]
                );
    port      ( SYS_RST         : in    std_logic;
                CLK             : in    std_logic;
                CLK_38K_FLG     : out   std_logic;
                CLK_38K_HD      : out   std_logic
                );
end clks;

architecture Behavioral of clks is

-----------------------------------------------------------------------------
---------------------- COMPONENT DECLERATIONS -------------------------------
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
------------------------ SIGNAL DECLERATIONS --------------------------------
-----------------------------------------------------------------------------

-- 38KHZ FLAG
signal  clk38kCnt           : integer range 0 to CLK_38K_VAL;
signal  clk38kHdTmp         : std_logic;

begin

    -----------------------------------------------------------------------------------
    ------------------------ COMPONENT INSTANTIATIONS ---------------------------------
    -----------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------
    -------------------------------- MAIN PROCESSES -----------------------------------
    -----------------------------------------------------------------------------------
    
    -- 38KHZ FLAG
    -- this flag runs at ~38kHz to drive the ir signals
    
    -- counting process
    process (SYS_RST, CLK)
    begin
        if (SYS_RST = '1') then
            clk38kCnt <= 0;
            clk38kHdTmp <= '0';
        elsif (rising_edge(CLK)) then
            if (clk38kCnt = CLK_38K_VAL-1) then
                clk38kHdTmp <= '1';
                clk38kCnt <= 0;
            elsif (clk38kCnt > (CLK_HD_38K_VAL-2) and clk38kCnt < (CLK_38K_VAL-1)) then
                clk38kHdTmp <= '0';
                clk38kCnt <= clk38kCnt + 1;
            else
                clk38kHdTmp <= '1';
                clk38kCnt <= clk38kCnt + 1;
            end if;
        end if;
    end process;
    
    -- 38kHz flag
    CLK_38K_FLG <= '1' when (clk38kCnt = CLK_38K_VAL-1) else '0';
    
    -- 38kHz half duty clock
    CLK_38K_HD <= clk38kHdTmp when (SYS_RST = '0') else '0';
    

end Behavioral;
