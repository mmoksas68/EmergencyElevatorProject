# EmergencyElevatorProject
System verilog project

In order to run the project download the zip file and run DijitalProject.xpr file with Vivado.


Explanation of My Project Codes and Modules


I have one top module and 3 other modules on my code. These 3 other modules are the modules that are given top us, so I will only explain my top module. In general, my top modules consist of my variables and 3 modules for keypad, display and seven segments and 3 always blocks that works in sync at the positive edge of the clock of the basys3 which is 100 mhz.  Firstly, I will try to explain my variables. Secondly, I will try to explain my first always block which is my most important always block because this block includes resetting system, resetting time, starting execution, adding passengers, execution scenario itself. Thirdly, I will try to explain my last 2 blocks which display the elevator and passengers and direction of elevator. I won’t explain the ready modules that are given, I only explain which variables that I send to them. P.s. I changed SevSeg_4digit module a bit in order to function it for the project appropriately. 
	My variables and the explanation of them are listed below: 
	
•[0:2] [11:0] floors: In this variable I am storing the passengers that are on the floors. 

•[3:0] currentState: This stores the state that system is in. According to the current state the system works. States are explained at the FSM transition diagram section.  

•isItWaiting: This variable is 1 if passengers are being added to elevator or elevator is being emptying, if not it is 0. According to this variable the left digit of seven segment moves or waits.

•[2:0] elevator: This variable store number of the passengers in the elevator.

•[26:0] counter: This variable is used to obtain 1 second from the clock input of basys3, which is 100mhz.

•[26:0] timer: This variable stores the elapsed time and increases every one second when any execution is on. If the system or the time is reset, this variable is set to zero.

•[26:0] waitingTime: This variable also stores time and increases every one second when execution is on. However, after increasing to 2 or 3 second depending on the transition of states, this variable is set to 0. Therefore, this variable is necessary for adjusting the movement times.

•[0:7] [7:0] image_red: This variable is the ready variable that is given on sample projects. Acts just as the same. However, I change its values according to my floors variable at my second always block at every time of the positive edge of the 100mhz clock.

•[0:7] [7:0] image_green: This variable is the ready variable that is given on sample projects and I didn’t even use it. 

•[0:7] [7:0] image_blue: This variable is the ready variable that is given on sample projects. Acts just as the same. However, I change its values according to my elevator and currentState variables at my second always block at every time of the positive edge of the 100mhz clock.

•[3:0] in0: This variable is set to first digit of my timer variable and send to SevSeg_4digit module that I copied from the sample projects. 

•[3:0] in1: This variable is set to second digit of my timer variable and send to SevSeg_4digit module that I copied from the sample projects.  

•[3:0] in2: This variable is set to third digit of my timer variable and send to SevSeg_4digit module that I copied from the sample projects.  

•[3:0] in3: This variable is the indicator of the direction of elevator. It is changed in my last always block according to states and isItWaiting variable for every 250 milliseconds. 

My first always block consist of 4 different parts. Only one part is functioned at every clock edge. These parts are resetting time, resetting system, adding passengers, executing the scenario. First 3 parts are simple. In executing the scenario my counter variable increases every clock edge and if it is increased enough for 1 second my timer and waitingTime will increase one and my counter will set to zero again. Again, in executing the scenario part, my states are changing according to my algorithm and if the execution ends the state S11 is active. P.s. state S11 is explained clearly at the end of my report. 
My algorithm consists of 3 parts. First part is to have a situation when there are no passengers more than 3 on every block. Second part is actual logic and the last part is special cases where my logic doesn’t work. In order to do first part starting from first floor elevator goes and takes 4 passengers and remove them on the ground until first part’s aim is satisfied. After the situation that there are only passengers less then 4 on every floor, my main algorithm works which is starting from the top taking that floor’s passengers if all passengers can fit in the elevator. For example, for the situation of floor 1,2,3 for passengers 2,3,0: my elevator goes to second floor, not third because there are no passengers there, takes the 3 passengers and doesn’t stop at the first floor because there are only 1 place left and 2 passengers on the first floor. After emptying elevator, it goes and takes the passengers on the first floor. My main logic is not effective if and only if there are 8 passengers left on the floors and they can be ordered as 3,3,2 or 3,2,3 or 2,3,3 which is the third part of my algorithm, the special cases. I handle this cases in a way that starting from the top I collect all passengers till elevator is full and leave them on the ground.
My second always block only arranges the image_red and image_blue variables according to my other variables at every positive edge of the clock. Similarly, my last always block arranges the direction indicator according to my other variables at every positive edge of the clock.
