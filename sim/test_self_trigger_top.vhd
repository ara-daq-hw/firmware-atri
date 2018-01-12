--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:14:03 08/31/2011
-- Design Name:   
-- Module Name:   /home/luca/Physics/ARA2/luca_firmware/firmware/ATRI/trunk/rtl/test_self_trigger_top.vhd
-- Project Name:  ATRI
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: self_trigger_top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY test_self_trigger_top IS
END test_self_trigger_top;
 
ARCHITECTURE behavior OF test_self_trigger_top IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT self_trigger_top
     Port ( clk : in  STD_LOGIC;
           trig_in1 : in  STD_LOGIC_VECTOR (3 downto 0);
		     trig_in2 : in  STD_LOGIC_VECTOR (3 downto 0);
	   	  trig_in3 : in  STD_LOGIC_VECTOR (3 downto 0);
			  trig_in4 : in  STD_LOGIC_VECTOR (3 downto 0);
           trig_o : out  STD_LOGIC;
           scal_trig_o : out  STD_LOGIC;
           scal_l1_o : out  STD_LOGIC_VECTOR (15 downto 0);
           delay_o : out  STD_LOGIC_VECTOR (63 downto 0);
			  trig_info_o : out STD_LOGIC_VECTOR (31 downto 0);
			  disable_i : in STD_LOGIC);

    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal trig_in1 : std_logic_vector(3 downto 0) := (others => '0');
   signal trig_in2 : std_logic_vector(3 downto 0) := (others => '0');
   signal trig_in3 : std_logic_vector(3 downto 0) := (others => '0');
   signal trig_in4 : std_logic_vector(3 downto 0) := (others => '0');
   signal disable_i : std_logic := '0';

 	--Outputs
   signal trig_o : std_logic;
   signal scal_trig_o : std_logic;
   signal scal_l1_o : std_logic_vector(15 downto 0);
   signal delay_o : std_logic_vector(63 downto 0);
	signal trig_info_o : STD_LOGIC_VECTOR (31 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: self_trigger_top PORT MAP (
          clk => clk,
          trig_in1 => trig_in1,
          trig_in2 => trig_in2,
          trig_in3 => trig_in3,
          trig_in4 => trig_in4,
          trig_o => trig_o,
          scal_trig_o => scal_trig_o,
          scal_l1_o => scal_l1_o,
          delay_o => delay_o,
			 trig_info_o => trig_info_o,
			 disable_i => disable_i
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      trig_in1 <=(others => '0');
      trig_in2 <=(others => '0');
      trig_in3 <=(others => '0');
      trig_in4 <=(others => '0');
		-- hold reset state for 100 ns.
		wait for 100 ns;	
		trig_in1(0)<='1';
		wait for 2*clk_period;
		wait for 4*clk_period;
		trig_in1(0)<='0';
		trig_in1(3)<='1';
		wait for 2*clk_period;
		trig_in1(3)<='0';
		trig_in1(1)<='1';
		wait for 2*clk_period;
		trig_in1(1)<='0';
		wait for 10*clk_period;
		trig_in2(1)<='1';
		wait for clk_period;
		trig_in2(2)<='1';
		wait for clk_period;
		trig_in2(1)<='0';
		wait for clk_period;
		trig_in2(2)<='0';
		wait for 11*clk_period;
		trig_in2(3)<='1';
		wait for 2*clk_period;
		trig_in2(3)<='0';
		--disable_i <='1';
		wait for 100*clk_period;
		disable_i<='1';
		trig_in3 (1)<='1';
		trig_in3 (2)<='1';
		trig_in3 (3)<='1';
		wait for clk_period;
		trig_in3 (1)<='0';
		trig_in3 (2)<='0';
		trig_in3 (3)<='0';


      -- insert stimulus here 

      wait;
   end process;

END;
