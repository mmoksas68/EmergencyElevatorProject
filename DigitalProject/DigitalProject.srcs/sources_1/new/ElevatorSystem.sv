`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/23/2018 12:25:51 AM
// Design Name: 
// Module Name: ElevatorSystem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ElevatorSystem(
	// clock
	input clk, //100Mhz on Basys3
	
	// introduced variables
    input resetTimer, systemReset, executeScenario,
	
	// FPGA pins for 8x8 display
	output reset_out, //shift register's reset
	output OE, 	//output enable, active low 
	output SH_CP,  //pulse to the shift register
	output ST_CP,  //pulse to store shift register
	output DS, 	//shift register's serial input data
	output [7:0] col_select, // active column, active high
	
	//7-segment signals
	output a, b, c, d, e, f, g, dp, 
    output [3:0] an,    
        
    //matrix  4x4 keypad
    output [3:0] keyb_row,
    input  [3:0] keyb_col );


// variables
reg [3:0] numOfPassengersInFirstFloor = {4'b0000};
reg [3:0] numOfPassengersInSecondFloor = {4'b0000};
reg [3:0] numOfPassengersInThirdFloor = {4'b0000};
logic [2:0] elevator = {4'b0000}; 
logic execution = {1'b0};
logic direction = {1'b1};
logic [1:0] currentFloor = {2'b00};
logic [26:0] counter = {27{1'b0}};
logic [26:0] elapsedTime = {27{1'b0}}; 
logic [26:0] moveTime = {27{1'b0}};

 
// initial value for RGB images:
// image_???[0]     : left column  .... image_???[7]     : right column
// image_???[?]'MSB : top line     .... image_???[?]'LSB : bottom line
logic [0:7] [7:0] image_red = 
{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
logic [0:7] [7:0]  image_green = 
{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
logic [0:7] [7:0]  image_blue = 
{8'b00000011, 8'b00000011, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
// run an example function for each key of keypad.
logic [2:0] col_num;
logic [3:0] in0 = 4'h0; //initial value
logic [3:0] in1 = 4'h0; //initial value
logic [3:0] in2 = 4'h0; //initial value
logic [3:0] in3 = 4'd10; //initial value


// this module shows 4 hexadecimal numbers on 4-digit 7-Segment.  
// 4 digits are scanned with high speed, then you do not notice that every time 
// only one of them is ON. dp is always off.
SevSeg_4digit SevSeg_4digit_inst0(
	.clk(clk),
	.in3(in3), .in2(in2), .in1(in1), .in0(in0), //user inputs for each digit (hexadecimal)
	.a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g), .dp(dp), // just connect them to FPGA pins (individual LEDs).
	.an(an)   // just connect them to FPGA pins (enable vector for 4 digits active low) 
);


// This module displays 8x8 image on LED display module. 
display_8x8 display_8x8_0(
    .clk(clk),
    
    // RGB data for display current column
    .red_vect_in(image_red[col_num]),
    .green_vect_in(image_green[col_num]),
    .blue_vect_in(image_blue[col_num]),
    
    .col_data_capture(), // unused
    .col_num(col_num),
    
    // FPGA pins for display
    .reset_out(reset_out),
    .OE(OE),
    .SH_CP(SH_CP),
    .ST_CP(ST_CP),
    .DS(DS),
    .col_select(col_select)   
);
 
 
//matrix keypad scanner 4x4
logic [3:0] key_value;
keypad4X4 keypad4X4_inst0(
	.clk(clk),
	.keyb_row(keyb_row), // just connect them to FPGA pins, row scanner
	.keyb_col(keyb_col), // just connect them to FPGA pins, column scanner
    .key_value(key_value), //user's output code for detected pressed key: row[1:0]_col[1:0]
    .key_valid(key_valid)  // user's output valid: if the key is pressed long enough (more than 20~40 ms), key_valid becomes '1' for just one clock cycle.
);	


// logic
always@ (posedge clk)
begin
    
    // resetting timer to 0.
    if(resetTimer == 1)
        elapsedTime <= {27{1'b0}}; 
 
 
    // indicating to execute scenario.
    else if(executeScenario == 1 && ( numOfPassengersInFirstFloor > 0 || numOfPassengersInSecondFloor > 0 || numOfPassengersInThirdFloor > 0 ))
        execution <= 1; 
    
    
    // resetting the system.    
    else if(systemReset == 1)
    begin
        numOfPassengersInFirstFloor <= {4'b0000};
        numOfPassengersInSecondFloor <= {4'b0000};
        numOfPassengersInThirdFloor <= {4'b0000};
        elevator <= {3'b000};
        currentFloor <= {2'b00};
        execution <= {1'b0};
        direction <= {1'b1};
        elapsedTime <= {27{1'b0}};
    end
    

    // incrementing or decrementing the number 
    // of passengers in floors through 4x4 matrix.
    else if (key_valid == 1'b1 && execution == 0) 
    begin
	   case(key_value) 
	       4'b0100: numOfPassengersInFirstFloor <= numOfPassengersInFirstFloor + 1;
	       4'b0101: numOfPassengersInFirstFloor <= numOfPassengersInFirstFloor - 1;
	       4'b1000: numOfPassengersInSecondFloor <= numOfPassengersInSecondFloor + 1;
	       4'b1001: numOfPassengersInSecondFloor <=  numOfPassengersInSecondFloor - 1;
	       4'b1100: numOfPassengersInThirdFloor <= numOfPassengersInThirdFloor + 1;
	       4'b1101: numOfPassengersInThirdFloor <= numOfPassengersInThirdFloor - 1;	
   	    endcase
	end
	
	
	// performing execution.
	else if(execution == 1) 
    begin
        
       // setting counter (for 1 sec) and incrementing 
       // moveTime and elapsed time accordingly.
	   counter <= counter + 1;
	   if(counter == (2*27'd49_999_999))
	   begin
	       moveTime <= moveTime + 1;
	       elapsedTime <= elapsedTime + 1;
	       counter <= {27{1'b0}}; 
	   end
       
       
       case(currentFloor)
            // elevator being in ground floor.
            2'b00:
                // elevator going up. 
                if(direction == 1)
                begin 
                    
                    // checking for passengers in upper floors.          
                    if( numOfPassengersInFirstFloor > 0 || numOfPassengersInSecondFloor > 0 || numOfPassengersInThirdFloor > 0 )
                    begin
                     
                        if( moveTime == 3 )
                        begin
                             moveTime <= 0;
                             currentFloor <= 2'b01;                            
                        end    
                    end
                    
                    else direction <= 0;
                end
                
                // elevator going down.    
                else
                begin
                    // no passenger left, emptying the elevator and terminating the execution or scenario.
                    if(numOfPassengersInFirstFloor <= 0 && numOfPassengersInSecondFloor <= 0 && numOfPassengersInThirdFloor <= 0 )
                    begin
                      if( moveTime == 2 )
                        begin
                        moveTime <= 0;
                        elevator <= 0;
                        execution <= 0;
                        direction <= 1;
                      end
                    end
                    else
                    
                    // passengers are left, emptying the elevator and going to upper floors to collect remaining passengers.
                    begin
                      if( moveTime == 2 )
                          begin
                          moveTime <= 0;
                          elevator <= 0;
                          direction <= 1;
                        end
                    end
                end          
        
            // elevator being in first floor.
            2'b01: 
                // elevator going up. 
                if(direction == 1)
                begin 
                    // checking for passengers in upper floors.          
                    if(numOfPassengersInSecondFloor > 0 || numOfPassengersInThirdFloor > 0)
                    begin
                     
                        if( moveTime == 3 )
                        begin
                             moveTime <= 0;
                             currentFloor <= 2'b10; 
                        end
                    end
                    
                    else direction <= 0;      
                end
                
                // elevator going down.    
                else
                begin
                
                    // elevator is empty and passengers are more than 4.
                    // elevator will take 4 passengers from the floor.
                    if( numOfPassengersInFirstFloor >= 4 && elevator == 0)
                    begin
                        
                        if( moveTime == 2 )
                        begin
                            numOfPassengersInFirstFloor <= numOfPassengersInFirstFloor - 4;
                            elevator <= elevator + 4;
                            currentFloor <= 2'b01;
                            moveTime <= 0;  
                        end          
                    end
                    
                    
                    else
                    begin
                        
                        // working in mod 4, when the elevator has more space than the passengers 
                        // in floor according to the mod 4, then collecting the passengers.                   
                        if( (4 - elevator) >= numOfPassengersInFirstFloor % 4 && numOfPassengersInFirstFloor % 4 != 0 )
                        begin
                            if( moveTime == 2 )
                            begin
                                elevator <= elevator + numOfPassengersInFirstFloor % 4;
                                numOfPassengersInFirstFloor <= numOfPassengersInFirstFloor - (numOfPassengersInFirstFloor % 4);
                                moveTime <= 0;
                                currentFloor <= 2'b01; 
                            end
                        end
                        
                        
                        else
                        begin
                            
                            // working in mod 4, when the elevator has less space
                            // than the passengers in floor according to the mod 4, then looking 
                            // for all the passengers and deciding to take the passengers.                   
                            if( elevator != 4 && (((numOfPassengersInFirstFloor % 4) - (4-elevator)) + (numOfPassengersInSecondFloor % 4) + (numOfPassengersInThirdFloor % 4) == 4) )
                            begin 
                                if( moveTime == 2 )
                                begin
                                    numOfPassengersInFirstFloor <= numOfPassengersInFirstFloor - (4 - elevator);
                                    elevator <= 4;                                          
                                    moveTime <= 0;
                                    currentFloor <= 2'b01; 
                                end
                            end
                            
                            // going down to ground floor
                            else
                            begin
                            
                                if( moveTime == 3 )
                                begin
                                    moveTime <= 0;
                                    currentFloor <= 2'b00; 
                                end
                            end     
                        end
                    end          
                end
                
            // elevator being in second floor.
            2'b10: 
                // elevator going up. 
                if(direction == 1)
                begin 
                    // checking for passengers in upper floors.          
                    if(numOfPassengersInThirdFloor > 0)
                    begin 
                        
                        if( moveTime == 3 )
                        begin
                            moveTime <= 0;
                            currentFloor <= 2'b11; 
                        end
                    end
                    
                    else direction <= 0;            
                end    
                
                // elevator going down.    
                else
                begin
                    
                    // elevator is empty and passengers are more than 4.
                    // elevator will take 4 passengers from the floor.
                    if( numOfPassengersInSecondFloor >= 4 && elevator == 0)
                    begin
                        
                        if( moveTime == 2 )
                        begin
                            numOfPassengersInSecondFloor <= numOfPassengersInSecondFloor - 4;
                            elevator <= elevator + 4;
                            moveTime <= 0;
                            currentFloor <= 2'b10; 
                        end          
                    end
                    
                    else
                    begin                    
                        
                        // working in mod 4, when the elevator has more space than the passengers 
                        // in floor according to the mod 4, then collecting the passengers.
                        if( (4 - elevator) >= numOfPassengersInSecondFloor % 4 && numOfPassengersInSecondFloor % 4 != 0)
                        begin
                            
                            if( moveTime == 2 )
                            begin
                                elevator <= elevator + numOfPassengersInSecondFloor % 4;
                                numOfPassengersInSecondFloor <=  numOfPassengersInSecondFloor - ( numOfPassengersInSecondFloor % 4);                                            
                                moveTime <= 0;
                                currentFloor <= 2'b10;
                            end
                        end
                        
                        else
                        begin
                        
                        // working in mod 4, when the elevator has less space
                        // than the passengers in floor according to the mod 4, then looking 
                        // for all the passengers and deciding to take the passengers.
                        if( elevator != 4 && (((numOfPassengersInSecondFloor % 4) - (4-elevator)) + (numOfPassengersInFirstFloor % 4) + (numOfPassengersInThirdFloor % 4) == 4) )
                        begin 
                        
                            if( moveTime == 2 )
                            begin
                                numOfPassengersInSecondFloor <= numOfPassengersInSecondFloor - (4 - elevator);
                                elevator <= 4;                                          
                                moveTime <= 0;
                                currentFloor <= 2'b10; 
                            end
                        end
                        
                        // going down to first floor
                        else
                        begin
                            if( moveTime == 3 )
                            begin
                                moveTime <= 0;
                                currentFloor <= 2'b01; 
                            end
                        end        
                    end                   
                end          
            end
            
            // elevator being in third floor.            
            2'b11: 
            
                // elevator going up. 
                if(direction == 1)
                    direction <= 0;
            
                // elevator going down.            
                else
                begin
                
                    // elevator is empty and passengers are more than 4.
                    // elevator will take 4 passengers from the floor.
                    if( numOfPassengersInThirdFloor >= 4 && elevator == 0)
                    begin
                        
                        if( moveTime == 2 )
                        begin
                            numOfPassengersInThirdFloor <= numOfPassengersInThirdFloor - 4;
                            elevator <= elevator + 4;
                            moveTime <= 0;
                            currentFloor <= 2'b11;  
                        end          
                    end
                    
                    else
                    begin                    
                    
                        // working in mod 4, when the elevator has more space than the passengers 
                        // in floor according to the mod 4, then collecting the passengers.
                        if( (4 - elevator) >= numOfPassengersInThirdFloor % 4 && numOfPassengersInThirdFloor % 4 != 0)
                        begin
                        
                            if( moveTime == 2 )
                            begin
                                elevator <= elevator + numOfPassengersInThirdFloor % 4;
                                numOfPassengersInThirdFloor <= numOfPassengersInThirdFloor - (numOfPassengersInThirdFloor % 4);
                                moveTime <= 0;
                                currentFloor <= 2'b11; 
                            end
                        end
                        
                        // going down to third floor.
                        else
                        begin
                            if( moveTime == 3 )
                            begin
                                moveTime <= 0;
                                currentFloor <= 2'b10;
                                counter <= {27{1'b0}}; // bura önemli 
                            end
                        end                                    
                    end          
                end          
       endcase 
    end
end

// 8x8 image display    
always@ (posedge clk)
begin
    
    // displaying the elevator. 
    case(currentFloor)
        
        // ground floor.
        2'b00:
            case(elevator)
                3'b000: // passenger count: 0
                begin
                    image_blue[0] <= 8'b00000011;
                    image_blue[1] <= 8'b00000011;
                    image_red[0]  <= 8'b00000000;
                    image_red[1]  <= 8'b00000000;                         
                end
           
                3'b001: // passenger count: 1
                begin
                    image_blue[0] <= 8'b00000010;
                    image_blue[1] <= 8'b00000011;
                    image_red[0]  <= 8'b00000001;
                    image_red[1]  <= 8'b00000000; 
                end
          
                3'b010: // passenger count: 2
                begin
                    image_blue[0] <= 8'b00000010;
                    image_blue[1] <= 8'b00000010;
                    image_red[0]  <= 8'b00000001;
                    image_red[1]  <= 8'b00000001;
                end
           
                3'b011: // passenger count: 3
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00000010;
                    image_red[0]  <= 8'b00000011;
                    image_red[1]  <= 8'b00000001;
                end   
          
                3'b100: // passenger count: 4
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00000000;
                    image_red[0]  <= 8'b00000011;
                    image_red[1]  <= 8'b00000011;
                end                           
            endcase 
          
        // first floor.
        2'b01:  
            case(elevator)
                
                3'b000: // passenger count: 0
                begin
                    image_blue[0] <= 8'b00001100;
                    image_blue[1] <= 8'b00001100;
                    image_red[0]  <= 8'b00000000;
                    image_red[1]  <= 8'b00000000;                         
                end
             
                3'b001: // passenger count: 1
                begin
                    image_blue[0] <= 8'b00001000;
                    image_blue[1] <= 8'b00001100;
                    image_red[0]  <= 8'b00000100;
                    image_red[1]  <= 8'b00000000; 
                end
            
                3'b010: // passenger count: 2
                begin
                    image_blue[0] <= 8'b00001000;
                    image_blue[1] <= 8'b00001000;
                    image_red[0]  <= 8'b00000100;
                    image_red[1]  <= 8'b00000100;
                end
             
                3'b011: // passenger count: 3
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00001000;
                    image_red[0] <= 8'b00001100;
                    image_red[1] <= 8'b00000100;
                end   
            
                3'b100: // passenger count: 4
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00000000;
                    image_red[0] <= 8'b00001100;
                    image_red[1] <= 8'b00001100;
                end                           
            endcase 

        // second floor.
        2'b10:  
            case(elevator)
                
                3'b000: // passenger count: 0
                begin
                    image_blue[0] <= 8'b00110000;
                    image_blue[1] <= 8'b00110000;
                    image_red[0]  <= 8'b00000000;
                    image_red[1]  <= 8'b00000000;                         
                end
             
                3'b001: // passenger count: 1
                begin
                    image_blue[0] <= 8'b00100000;
                    image_blue[1] <= 8'b00110000;
                    image_red[0]  <= 8'b00010000;
                    image_red[1]  <= 8'b00000000; 
                end
            
                3'b010: // passenger count: 2
                begin
                    image_blue[0] <= 8'b00100000;
                    image_blue[1] <= 8'b00100000;
                    image_red[0]  <= 8'b00010000;
                    image_red[1]  <= 8'b00010000;
                end
             
                3'b011: // passenger count: 3
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00100000;
                    image_red[0]  <= 8'b00110000;
                    image_red[1]  <= 8'b00010000;
                end   
            
                3'b100: // passenger count: 4
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00000000;
                    image_red[0] <= 8'b00110000;
                    image_red[1] <= 8'b00110000;
                end                           
            endcase 
     
        // third floor.        
        2'b11:  
            case(elevator)
                
                3'b000: // passenger count: 0
                begin
                    image_blue[0] <= 8'b11000000;
                    image_blue[1] <= 8'b11000000;
                    image_red[0]  <= 8'b00000000;
                    image_red[1]  <= 8'b00000000;                         
                end
             
                3'b001: // passenger count: 1
                begin
                    image_blue[0] <= 8'b10000000;
                    image_blue[1] <= 8'b11000000;
                    image_red[0]  <= 8'b01000000;
                    image_red[1]  <= 8'b00000000; 
                end
            
                3'b010: // passenger count: 2
                begin
                    image_blue[0] <= 8'b10000000;
                    image_blue[1] <= 8'b10000000;
                    image_red[0]  <= 8'b01000000;
                    image_red[1]  <= 8'b01000000;
                end
             
                3'b011: // passenger count: 3
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b10000000;
                    image_red[0]  <= 8'b11000000;
                    image_red[1]  <= 8'b01000000;
                end   
            
                3'b100: // passenger count: 4
                begin
                    image_blue[0] <= 8'b00000000;
                    image_blue[1] <= 8'b00000000;
                    image_red[0]  <= 8'b11000000;
                    image_red[1]  <= 8'b11000000;
                end                           
            endcase     
    endcase
    
    // displaying the passengers in floor1.
    case(numOfPassengersInFirstFloor)
    
        4'b0000: // number of passengers in floor1 = 0
        begin       
            image_red[2][3] <= 0;
            image_red[2][2] <= 0;
            image_red[3][3] <= 0;
            image_red[3][2] <= 0;
            image_red[4][3] <= 0;
            image_red[4][2] <= 0;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0001: // number of passengers in floor1 = 1
        begin        
            image_red[2][3] <= 0;
            image_red[2][2] <= 1;
            image_red[3][3] <= 0;
            image_red[3][2] <= 0;
            image_red[4][3] <= 0;
            image_red[4][2] <= 0;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0010: // number of passengers in floor1 = 2
        begin       
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 0;
            image_red[3][2] <= 0;
            image_red[4][3] <= 0;
            image_red[4][2] <= 0;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0011: // number of passengers in floor1 = 3
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 0;
            image_red[3][2] <= 1;
            image_red[4][3] <= 0;
            image_red[4][2] <= 0;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end  
    
        4'b0100: // number of passengers in floor1 = 4 
        begin       
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 0;
            image_red[4][2] <= 0;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0101: // number of passengers in floor1 = 5
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 0;
            image_red[4][2] <= 1;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0110: // number of passengers in floor1 = 6
        begin       
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 0;
            image_red[5][2] <= 0;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b0111: // number of passengers in floor1 = 7
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 0;
            image_red[5][2] <= 1;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end  
        
        4'b1000: // number of passengers in floor1 = 8
        begin       
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 1;
            image_red[5][2] <= 1;
            image_red[6][3] <= 0;
            image_red[6][2] <= 0;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b1001: // number of passengers in floor1 = 9
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 1;
            image_red[5][2] <= 1;
            image_red[6][3] <= 0;
            image_red[6][2] <= 1;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b1010: // number of passengers in floor1 = 10 
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 1;
            image_red[5][2] <= 1;
            image_red[6][3] <= 1;
            image_red[6][2] <= 1;
            image_red[7][3] <= 0;
            image_red[7][2] <= 0;
        end
    
        4'b1011: // number of passengers in floor1 = 11
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 1;
            image_red[5][2] <= 1;
            image_red[6][3] <= 1;
            image_red[6][2] <= 1;
            image_red[7][3] <= 0;
            image_red[7][2] <= 1;
        end
    
        4'b1100: // number of passengers in floor1 = 12
        begin        
            image_red[2][3] <= 1;
            image_red[2][2] <= 1;
            image_red[3][3] <= 1;
            image_red[3][2] <= 1;
            image_red[4][3] <= 1;
            image_red[4][2] <= 1;
            image_red[5][3] <= 1;
            image_red[5][2] <= 1;
            image_red[6][3] <= 1;
            image_red[6][2] <= 1;
            image_red[7][3] <= 1;
            image_red[7][2] <= 1;
        end  
    endcase 
    
    // displaying the passengers in floor2.
    case(numOfPassengersInSecondFloor)
            
        4'b00_00: // number of passengers in floor2 = 0
        begin       
            image_red[2][5] <= 0;
            image_red[2][4] <= 0;
            image_red[3][5] <= 0;
            image_red[3][4] <= 0;
            image_red[4][5] <= 0;
            image_red[4][4] <= 0;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
        end
        
        4'b00_01: // number of passengers in floor2 = 1
        begin        
            image_red[2][5] <= 0;
            image_red[2][4] <= 1;
            image_red[3][5] <= 0;
            image_red[3][4] <= 0;
            image_red[4][5] <= 0;
            image_red[4][4] <= 0;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end                  
        
       4'b00_10: // number of passengers in floor2 = 2
       begin       
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 0;
            image_red[3][4] <= 0;
            image_red[4][5] <= 0;
            image_red[4][4] <= 0;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
        end
        
        4'b00_11: // number of passengers in floor2 = 3
        begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 0;
            image_red[3][4] <= 1;
            image_red[4][5] <= 0;
            image_red[4][4] <= 0;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
        end  
        
        4'b01_00: // number of passengers in floor2 = 4
        begin       
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 0;
            image_red[4][4] <= 0;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
        end
        
        4'b01_01: // number of passengers in floor2 = 5
        begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 0;
            image_red[4][4] <= 1;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end
        
       4'b01_10: // number of passengers in floor2 = 6
       begin       
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 0;
            image_red[5][4] <= 0;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end
        
       4'b01_11: // number of passengers in floor2 = 7
       begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 0;
            image_red[5][4] <= 1;
            image_red[6][5] <= 0;
            image_red[6][4] <= 0;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end  
        
       4'b10_00: // number of passengers in floor2 = 8
       begin       
           image_red[2][5] <= 1;
           image_red[2][4] <= 1;
           image_red[3][5] <= 1;
           image_red[3][4] <= 1;
           image_red[4][5] <= 1;
           image_red[4][4] <= 1;
           image_red[5][5] <= 1;
           image_red[5][4] <= 1;
           image_red[6][5] <= 0;
           image_red[6][4] <= 0;
           image_red[7][5] <= 0;
           image_red[7][4] <= 0;
       end
        
       4'b10_01: // number of passengers in floor2 = 9
       begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 1;
            image_red[5][4] <= 1;
            image_red[6][5] <= 0;
            image_red[6][4] <= 1;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end
        
       4'b10_10: // number of passengers in floor2 = 10
       begin       
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 1;
            image_red[5][4] <= 1;
            image_red[6][5] <= 1;
            image_red[6][4] <= 1;
            image_red[7][5] <= 0;
            image_red[7][4] <= 0;
       end
        
       4'b10_11: // number of passengers in floor2 = 11
       begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 1;
            image_red[5][4] <= 1;
            image_red[6][5] <= 1;
            image_red[6][4] <= 1;
            image_red[7][5] <= 0;
            image_red[7][4] <= 1;
       end
        
       4'b11_00: // number of passengers in floor2 = 12
       begin        
            image_red[2][5] <= 1;
            image_red[2][4] <= 1;
            image_red[3][5] <= 1;
            image_red[3][4] <= 1;
            image_red[4][5] <= 1;
            image_red[4][4] <= 1;
            image_red[5][5] <= 1;
            image_red[5][4] <= 1;
            image_red[6][5] <= 1;
            image_red[6][4] <= 1;
            image_red[7][5] <= 1;
            image_red[7][4] <= 1;
       end  
    endcase
    
    // displaying the passengers in floor3.
    case(numOfPassengersInThirdFloor)
            
        4'b00_00: // number of passengers in floor3 = 0 
        begin       
            image_red[2][7] <= 0;
            image_red[2][6] <= 0;
            image_red[3][7] <= 0;
            image_red[3][6] <= 0;
            image_red[4][7] <= 0;
            image_red[4][6] <= 0;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b00_01: // number of passengers in floor3 = 1
        begin        
            image_red[2][7] <= 0;
            image_red[2][6] <= 1;
            image_red[3][7] <= 0;
            image_red[3][6] <= 0;
            image_red[4][7] <= 0;
            image_red[4][6] <= 0;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b00_10: // number of passengers in floor3 = 2 
        begin       
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 0;
            image_red[3][6] <= 0;
            image_red[4][7] <= 0;
            image_red[4][6] <= 0;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b00_11: // number of passengers in floor3 = 3
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 0;
            image_red[3][6] <= 1;
            image_red[4][7] <= 0;
            image_red[4][6] <= 0;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end  
            
        4'b01_00: // number of passengers in floor3 = 4
        begin       
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 0;
            image_red[4][6] <= 0;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b01_01: // number of passengers in floor3 = 5
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 0;
            image_red[4][6] <= 1;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b01_10: // number of passengers in floor3 = 6 
        begin       
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 0;
            image_red[5][6] <= 0;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b01_11: // number of passengers in floor3 = 7
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 0;
            image_red[5][6] <= 1;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end  
        
        4'b10_00: // number of passengers in floor3 = 8 
        begin       
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 1;
            image_red[5][6] <= 1;
            image_red[6][7] <= 0;
            image_red[6][6] <= 0;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b10_01: // number of passengers in floor3 = 9
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 1;
            image_red[5][6] <= 1;
            image_red[6][7] <= 0;
            image_red[6][6] <= 1;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b10_10: // number of passengers in floor3 = 10
        begin       
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 1;
            image_red[5][6] <= 1;
            image_red[6][7] <= 1;
            image_red[6][6] <= 1;
            image_red[7][7] <= 0;
            image_red[7][6] <= 0;
        end
            
        4'b10_11: // number of passengers in floor3 = 11
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 1;
            image_red[5][6] <= 1;
            image_red[6][7] <= 1;
            image_red[6][6] <= 1;
            image_red[7][7] <= 0;
            image_red[7][6] <= 1;
        end
            
        4'b11_00: // number of passengers in floor3 = 12
        begin        
            image_red[2][7] <= 1;
            image_red[2][6] <= 1;
            image_red[3][7] <= 1;
            image_red[3][6] <= 1;
            image_red[4][7] <= 1;
            image_red[4][6] <= 1;
            image_red[5][7] <= 1;
            image_red[5][6] <= 1;
            image_red[6][7] <= 1;
            image_red[6][6] <= 1;
            image_red[7][7] <= 1;
            image_red[7][6] <= 1;
        end  
    endcase 
end

// timer display
always@ (posedge  clk)
begin 

    // setting indicator when elapsed time is 0.
    if (elapsedTime == 0) 
        in3 = 4'd10;

    if (execution == 1)
    begin 
        
        // indicating the direction of the elevator.
        if(counter % (27'd49_999_999/2 + 1) == 0 )
        begin
                 
            // going up: clockwise
            if(direction == 1)
            begin
                if(in3 >= 15)
                    in3 <= in3-5;
                else
                    in3 <= in3 + 1;
            end
                    
            // going down: counter clockwise.
            else if(direction == 0)
            begin
                if(in3 <= 10)
                    in3 <= in3 + 5;
                else
                    in3 <= in3 - 1;
            end
        end
    end

    // showing elapsed time in seven segment.
    in0 <= elapsedTime % 10;
    in1 <= (elapsedTime / 10) % 10;
    in2 <= (elapsedTime /100 )% 10;

end
endmodule
