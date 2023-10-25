library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART is
	generic(
		F_CPU: natural := 50_000_000;
		BAUD: natural := 9_600;
		BAUD_RATE: natural := 50_000_000/9_600;
		SAMPLE_RATE: natural := 8*50_000_000/9_600
	);
	
	port(
		clk: in std_logic;
		rstn: in std_logic;
		
		rx_signal: in std_logic;
		
		-- Display of recived data
		display_hex1,
		display_hex2: out std_logic_vector(7 downto 0)
	);
end entity;


architecture UART_ARCH of UART is
	-------------------------- STATES --------------------------
	
	type state_type is (idle,bit_sampling,byte_processing,display_state);
	signal pr_state, nx_state: state_type;
	
	
	-------------------------- SIGNALS --------------------------
	
	-- Data Register
	signal UART_RX_DATA: std_logic_vector(7 downto 0) := 		"00000000";
	
	-- Sampling Register
	signal UART_RX_SAMPLE: std_logic_vector(7 downto 0) := 	"00000000";
	
	-- Status Register
	signal UART_RX_STATUS: std_logic_vector(3 downto 0) := 	"0000";
	/*
		0 - Wait For Startbit
		1 - Sampling
		2 - 
		3 - Read Data Ready
	*/
	
	signal UART_RX_BYTE_CNT: natural range 0 to 8:= 0;
	
	-- Clock Counter of RX
	signal UART_RX_CLKCNT: natural := 0;
	
	-- Clock Counter of Sampling Counter
	signal UART_RX_SAMPLECNT: natural := 0;
	
	-------------------------- FUNCTIONS --------------------------
	
	pure function display(input: std_logic_vector) return std_logic_vector is		
		
		variable output: std_logic_vector(7 downto 0) := "00000000";
		
	begin
		
		case input is
			when "0000" => output := "01111110"; -- Print 0
			when "0001" => output := "00110000"; -- Print 1
			when "0010" => output := "10100100"; -- Print 2
			when "0011" => output := "10110000"; -- Print 3
			when "0100" => output := "10011001"; -- Print 4
			when "0101" => output := "10010010"; -- Print 5
			when "0110" => output := "10000010"; -- Print 6
			when "0111" => output := "11111000"; -- Print 7
			when "1000" => output := "10000000"; -- Print 8
			when "1001" => output := "10010000"; -- Print 9
			when "1010" => output := "10001000"; -- Print A
			when "1011" => output := "10000011"; -- Print B
			when "1100" => output := "11000110"; -- Print C
			when "1101" => output := "10100001"; -- Print D
			when "1110" => output := "10000110"; -- Print E
			when "1111" => output := "10001110"; -- Print F
			when others => null;
		end case;
		
		return output;
		
	end function;
	
	--Check If High/Low
	pure function byte_value(input: std_logic_vector) return std_logic is
		
		variable output: std_logic;
		
	begin
		
		if to_integer(unsigned(input)) = 15 then
			output := '1';
		else
			output := '0';
		end if;
		
		return output;
		
	end function;
	
begin
	
	-- Change Of States
	State_Change: process(clk, rstn)
	begin
		if rstn = '0' then
			pr_state <= idle;
		elsif rising_edge(clk) then
			pr_state <= nx_state;
		end if;
	end process;
	
	-- Logic For which State To Change To
	State_Transitions: process(clk, rstn)
	begin
		if rstn = '0' then
			nx_state <= idle;
		elsif rising_edge(clk) then
			
			--Tired, Logic Probably Broke but me thinks it works
			case pr_state is
				--Wait For Input				--Wait For Startbit Detection
				when idle 					=> if UART_RX_STATUS(0) = '1' then
														nx_state <= idle;
													else
														nx_state <= bit_sampling;
													end if;
					
				--Sample Input					-- If Sampling Bit Set To 1, Stay In State
				when bit_sampling 		=> if UART_RX_STATUS(1) = '1' then
														nx_state <= bit_sampling;
													else
														nx_state <= byte_processing;
													end if;
					
				--Process Sampled Input		-- If Byte Ready Print Out
				when byte_processing 	=> if UART_RX_STATUS(3) = '1' then
														nx_state <= display_state;
													else 
														nx_state <= bit_sampling;
													end if;
					
				--Display Input
				when display_state 		=> nx_state <= idle;
			end case;
		end if;
	end process;
	
	-- Logic For what to do every State
	Value_Processing: process(clk, rstn)
	begin
		if rstn = '0' then
			
			UART_RX_DATA 		<= "00000000";
			UART_RX_SAMPLE 	<= "00000000";
			UART_RX_BYTE_CNT 	<= 0;
			UART_RX_CLKCNT		<= 0;
			UART_RX_SAMPLECNT <= 0;
			
		elsif rising_edge(clk) then
			
			case pr_state is				
				--Idle State					--Reset All Registers/Values
				when idle 					=> UART_RX_DATA 		<= "00000000";
													UART_RX_SAMPLE 	<= "00000000";
													UART_RX_BYTE_CNT 	<= 0;
													UART_RX_CLKCNT		<= 0;
													UART_RX_SAMPLECNT <= 0;
				
				--Bit Sampling					--Loop Over Input Signal
				when bit_sampling 		=> null;
				
				--Process Byte From Bit		--Whenever Bit Recived Process Output Variable
				when byte_processing 	=>	UART_RX_DATA(UART_RX_BYTE_CNT) <= byte_value(UART_RX_SAMPLE(5 downto 2));
													
													UART_RX_BYTE_CNT <= UART_RX_BYTE_CNT + 1;
													
													if UART_RX_BYTE_CNT >= 7 then
														
														UART_RX_STATUS(3) <= '1';
														
													else
														
														--UART_RX_STATUS(3) <= '0';
														
													end if;
				
				--Code For Display			--Display Hex Values
				when display_state	 	=> display_hex1 <= display(UART_RX_DATA(3 downto 0));
													display_hex2 <= display(UART_RX_DATA(7 downto 4));
													
													--Restart Waiting For Startbit
													UART_RX_STATUS(0) <= '1';
													UART_RX_STATUS(3) <= '0';
			end case;
		end if;
	end process;
	
	-- Clock Independent Input Detection
	UART_RX_START: process(all)
	begin
		
		if falling_edge(rx_signal) then
			
			UART_RX_STATUS(2) <= '0';
			
		end if;
		
	end process;
end architecture;
