;|-----------------------------------------------------------|
;| INSTITUTO TECNOLOGICO DE ESTUDIOS SUPERIORES DE OCCIDENTE |
;| Microprocessor and microcontroller fundamentals           |
;|                                                           |
;| AUTHORS:   Narda Ibarra                                   |
;|            Kury Vazquez                                   |
;|            Diego Lopez                                    |
;|-----------------------------------------------------------|	
			
			
			PRESSED_VAL EQU 43H
			DELAY1 		EQU R1
			ROW_CTR 	EQU R2
			COL_CTR 	EQU R3
			BINARY_MASK EQU R4
			DELAY2 		EQU R5
			DELAY4 		EQU R6
			DELAY5 		EQU R7
			
			SPACE_CTR	EQU 40H
			TEMP		EQU 41H
			BTN_CTR		EQU 42H
			
			CURR_CHAR EQU 80H
			ICURR_CHAR EQU 76H
			CHAR_CTR  EQU 70H	
			INT_CTR   EQU 75H
				
				

ORG 000H 
	JMP START
	
ORG 003H
	AJMP INTER_BT
					
	

//--------------------------INITIAL VALUES-------------------------
ORG 040H
	
START:  	MOV SPACE_CTR, #33d
			MOV	DPTR, #0300H 
			MOV BTN_CTR, #1d
			SETB IT0			
			MOV IE, #10000001b  ;Initialize INT0 ;INT0 Begins when pushbutton is pressed(P3.2, Pin 12 AT89)			
			
			MOV TMOD, #20H		
			MOV TH1, #0FDH		;Baud Rate 9600
			MOV SCON, #50H		;Serial Mode 1 (8 bits + 1 stop bit)
			SETB TR1	
			
			MOV CHAR_CTR, #00H
			MOV INT_CTR, #00H
			
//-----------------INITIALIZE and CONFIGURE DISPLAY-----------------
			
			LCALL WAIT // initialization of LCD by software
			LCALL WAIT // this part of program is not mandatory but
			MOV A, #38H // recommended to use because it will
			LCALL COMMAND // guarantee proper initialization even when
			LCALL WAIT // power supply reset timings are not met
			MOV A, #38H
			LCALL COMMAND
			LCALL WAIT
			MOV A, #38H
			LCALL COMMAND // initialization complete
			
			MOV A, #38H // initialize LCD, 8-bit interface, 5X7 dots/character
			LCALL COMMAND // send command to LCD
			MOV A, #0FH // display on, cursor on with blinking
			LCALL COMMAND // send command to LCD
			MOV A, #06 // shift cursor right
			LCALL COMMAND // send command to LCD
			MOV A, #01H // clear LCD screen and memory
			LCALL COMMAND // send command to LCD
			MOV A, #80H // set cursor at line 1, first position
			LCALL COMMAND // send command to LCD
			
			
START_MAT:	MOV PRESSED_VAL, #00 // binary code for the pressed key will be stored in R0
			MOV P2, #0FFH // configure P2 as I/P port
			MOV P1, #00H // ground all the rows
			
			
NO_REL: 	MOV A, P2
			ANL A, #0FH // mask the upper nibble which is not used for keyboard
			CJNE A, #0FH, NO_REL 
			// if all the keys are not high previous key is not released
			LCALL DBOUN // debounce for the key release
			
			// check for any key press and wait until key is pressed
WAIT_MAT: 	MOV A, P2 
			ANL A, #0FH 
			CJNE A, #0FH, K_IDEN // key identify
			SJMP WAIT_MAT 
		
K_IDEN: 	LCALL DBOUN
			MOV BINARY_MASK, #7FH // only one row is made 0 at a time
			MOV ROW_CTR, #04 // row counter
			MOV A, BINARY_MASK

NXT_ROW:	RL A
			MOV BINARY_MASK, A // save data to ground the next row
			MOV P1, A // ground one row
			MOV A, P2
			ANL A, #0FH // mask the upper nibble
			MOV COL_CTR, #04 // column counter
		
		
NXT_COLM: 	RRC A // move A0 bit in carry
			JNC KY_FND
			INC PRESSED_VAL
			DJNZ COL_CTR, NXT_COLM
			MOV A, BINARY_MASK
			DJNZ ROW_CTR, NXT_ROW
			SJMP WAIT_MAT // no key closure found, go back and check again
		
KY_FND: 	MOV A, PRESSED_VAL // hex code of key is in R0, store it in A
			SJMP CONTINUE
		
		
DBOUN:  	MOV DELAY4, #10 // debounce delay for 10ms (Xtal=12MHz)

THR2: 		MOV DELAY5, #250

THR1: 		NOP
			NOP
			DJNZ DELAY5, THR1
			DJNZ DELAY4, THR2
			RET
		
CONTINUE: 	//MOV P3, A // send binary code for the pressed key on Port 3
			LCALL WRITE_DATA 
			
			JMP START_MAT// go for detecting the next key press and identification
HERE: 		SJMP HERE // wait indefinitely



//----------------------INTERRUPTION-----------------------------------------------
INTER_BT:	
			MOV ICURR_CHAR, 80H // Move to the string beginning 
			MOV INT_CTR, 80H  //Initialize counter 

LOOP:		
			MOV R0, ICURR_CHAR // GO BACK TO R0 
			MOV A, @R0         //MOVE CURR CONTENT TO MEMORY
			ACALL SEND         //SEND INFO
			INC ICURR_CHAR     //INCREMENT COUNTER AND MOVE TO NEXT MEM
			INC INT_CTR        //INCREMENT COUTER 
			MOV A, INT_CTR				
			CJNE A, CHAR_CTR, LOOP  //COMPARE AND MOVE IF NOT COMPLETE
			
			
SEND: 		MOV SBUF, A //SEND DATA
HERE2: 		JNB TI, HERE2 // WAIT UNITL THE LAST BIT IS SENT
			CLR TI
			RETI

//-----------------------WRITE DATA------------------------------
			
			
COMMAND: // command write subroutine
			MOV P0, A // place command on P2
			CLR P2.7 // RS = 0 for command
			CLR P2.6 // R/W = 0 for write operation
			SETB P2.5 // E = 1 for high pulse
			LCALL WAIT // wait for some time
			CLR P2.5 // E = 0 for H-to-L pulse
			LCALL WAIT // wait for LCD to complete the given command
			RET
			
			
WRITE_DATA: // data writeA subroutine
			MOV TEMP, A //MOVE REQUIRED DATA 
			DJNZ SPACE_CTR, CONTINUE3 //DECREASE COUNTER 32 - x AND JUMP UNTIL 0 
			LCALL INITIAL_CHAR 
			MOV SPACE_CTR, #32d	
			
			
CONTINUE3:	
			MOV A, SPACE_CTR   //RECOVER COUTER 
			CJNE A,#16d,CONTINUE2  //VERIFY IF FIRST ROW IS FULL 
			LCALL NXT_LINE //JUMP PTR TO NEXT ROW
					
			
CONTINUE2:	
			//Check if button is pressed
			JNB P3.7, CHECK_BTN_CTR
			JMP MAT_TABLE 
	
CHECK_BTN_CTR: 
			MOV A, BTN_CTR //CHECK IF 2 BUTTONS HAVES BEEN PRESSED (ascci)
			CJNE A, #1d, DISP_DATA


// CHANGE LOOK-UP TABLE, DEPENDING ON THE FIRST PRESSED BUTTON ON THE MATRIXKEYBOARD 
CHANGE_DPTR: 
			MOV A, TEMP
			CJNE A, #3d, TB1
			MOV	DPTR, #0400H //01 - 0FH VALUES 
			DEC BTN_CTR
			INC SPACE_CTR			
			RET
			
TB1:		MOV A, TEMP
			CJNE A, #15d, TB2
			MOV	DPTR, #0420H //10 - 1FH VALUES 
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB2:		CJNE A, #14d, TB3
			MOV	DPTR, #0440H //20 - 2FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB3:		CJNE A, #13d, TB4
			MOV	DPTR, #0460H //30 - 3FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB4:		CJNE A, #11d, TB5
			MOV	DPTR, #0480H //40 - 4FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB5:		CJNE A, #10d, TB6
			MOV	DPTR, #0500H //50 - 5FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB6:		CJNE A, #9d, TB7
			MOV	DPTR, #0520H //60 - 6FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
TB7:		CJNE A, #7d, NONE
			MOV	DPTR, #0540H //70 - 7FH VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET				
NONE:		MOV	DPTR, #0300H // DEFAULT BUTTONS VALUES
			DEC BTN_CTR
			INC SPACE_CTR
			RET
			
MAT_TABLE:	
			MOV BTN_CTR, #1d
			MOV DPTR, #0300H	
			
DISP_DATA:	MOV A, TEMP //DATA REQUIRED TO DISPLAY
			MOVC A, @A+DPTR 
TEST:		MOV P0, A // send data to port 1


			MOV CURR_CHAR, A // CURRENT_CHAR FOR INTERRUPTION
			INC CHAR_CTR
			
			SETB P2.7 // RS = 1 for data
			CLR P2.6 // R/W = 0 for write operation
			SETB P2.5 // E = 1 for high pulse
			LCALL WAIT // wait for some time
			CLR P2.5 // E = 0 for H-to-L pulse
			LCALL WAIT // wait for LCD to write the given data
			MOV BTN_CTR, #1d
			RET
			
			
WAIT: 		MOV DELAY1, #30H // delay subroutine
THERE:  	MOV DELAY2, #0FFH 
HERE1:  	DJNZ DELAY2, HERE1 
			DJNZ DELAY1, THERE
			RET		
			
			

NXT_LINE: 	
			MOV A, #0C0H  //set cursos at line 1 in LCD screen
			LCALL COMMAND
			MOV CHAR_CTR, #00H 
			RET

INITIAL_CHAR:
			
			MOV A, #01H //clear LCD screen
			LCALL COMMAND
			MOV A, #80H //set cursor at line 1 in LCD screen
			LCALL COMMAND
			RET
			
			
//----------------------ASCII-----------------------		
ORG 0300H 
						
			DB  044H	;1  
			DB  023H	;2
			DB  030H	;3
			DB  02AH	;A	
			DB  043H	;4
			DB  039H	;5
			DB  038H	;6
			DB  037H	;B
			DB  042H	;7
			DB  036H	;8
			DB  035H	;9
			DB  034H	;C
			DB  041H	;*
			DB  033H	;0
			DB  032H	;#
			DB  031H	;D


ORG 0400H /		
						
			DB  0DH	;1 -0 + D  
			DB  0EH ;2 -0 + # (E)
			DB  00H	;3 -0 +  0
			DB	0FH ;4 -0 + * (F)
			DB  0CH	;3 -0 +  C
			DB  09H	;4 -0 +  9
			DB  08H	;5-0 +  8
			DB  07H	;6 -0 +  7
			DB  0BH	;7 -0 +  B
			DB  06H	;8 -0 +  6
			DB  05H	;9 -0 +  5
			DB  04H	;10 -0 +  4 
			DB  0AH	;11 -0 +  A
			DB  03H	;12 -0 +  3
			DB  02H	;13 -0 +  2
			DB  01H	;14 -0 +  1	

ORG 0420H //1 
			DB  01DH	;1 -1 + D {  
			DB  01EH    ;1 -1 + E
			DB  010H	;3 -1 +  0
			DB  01FH	;3 -1 +  F
			DB  01CH	;5 -1 +  C
			DB  019H	;6 -1 +  9
			DB  018H	;7 -1 +  8
			DB  017H	;8 -1 +  7
			DB  01BH	;9 -1 +  B
			DB  016H	;10 -1 +  6
			DB  015H	;11 -1 +  5
			DB  014H	;12 -1 +  4 
			DB  01AH	;13 -1 +  A
			DB  013H	;14 -1 +  3
			DB  012H	;15 -1 +  2
			DB  011H	;16 -1 +  1	
ORG 0440H //2 
			DB  02DH	;1 -2 + D      
			DB  02EH    ;2 -2 + E
			DB  020H	;3 -2 +  0     
			DB  02FH    ;4 -2 + F
			DB  02CH	;5 -2 +  C     
			DB  029H	;6 -2 +  9	
			DB  028H	;7 -2 +  8     
			DB  027H	;8 -2 +  7      
			DB  02BH	;9 -2 +  B      
			DB  026H	;10 -2 +  6     
			DB  025H	;11 -2 +  5     
			DB  024H	;12 -2 +  4     
			DB  02AH	;13 -2 +  A     
			DB  023H	;14 -2 +  3    
			DB  022H	;15 -2 +  2          
			DB  021H	;16 -2 +  1           
ORG 0460H //3 
			DB  03DH	;1 -3 + D   
			DB  03EH    ;2 -2 + E
			DB  030H	;3 -2 +  0   
			DB  03FH    ;4 -2 + F
			DB  03CH	;5 -3 +  C
			DB  039H	;6 -3 +  9
			DB  038H	;7 -3 +  8
			DB  037H	;8 -3 +  7
			DB  03BH	;9 -3 +  B
			DB  036H	;10 -3 +  6
			DB  035H	;11 -3 +  5
			DB  034H	;12 -3 +  4 
			DB  03AH	;13 -3 +  A
			DB  033H	;14 -3 +  3
			DB  032H	;15 -3 +  2
			DB  031H	;16 -3 +  1	
ORG 0480H //4
			DB  04DH	;1 -4 + D   
			DB  04EH    ;2 -2 + E
			DB  040H	;3 -2 +  0    
			DB  04FH    ;4 -2 + F
			DB  04CH	;5 -4 +  C
			DB  049H	;6 -4 +  9
			DB  048H	;7 -4 +  8
			DB  047H	;8 -4 +  7
			DB  04BH	;9 -4 +  B
			DB  046H	;10 -4 +  6
			DB  045H	;11 -4 +  5
			DB  044H	;12 -4 +  4 
			DB  04AH	;13 -4 +  A
			DB  043H	;14 -4 +  3
			DB  042H	;15 -4 +  2
			DB  041H	;16 -4 +  1	
ORG 0500H //5 
			DB  05DH	;1 -5 + D   
			DB  05EH    ;2 -2 + E
			DB  050H	;3 -2 +  0    
			DB  05FH    ;4 -2 + F
			DB  05CH	;5 -5 +  C
			DB  059H	;6 -5 +  9
			DB  058H	;7 -5 +  8
			DB  057H	;8 -5 +  7
			DB  05BH	;9 -5 +  B
			DB  056H	;10 -5 +  6
			DB  055H	;11 -5 +  5
			DB  054H	;12 -5 +  4 
			DB  05AH	;13 -5 +  A
			DB  053H	;14 -5 +  3
			DB  052H	;15 -5 +  2
			DB  051H	;16 -5 +  1	
ORG 0520H //6
			DB  06DH	;1 -6 + D   
			DB  06EH    ;2 -2 + E
			DB  060H	;3 -2 +  0    
			DB  06FH    ;4 -2 + F
			DB  06CH	;5 -6 +  C
			DB  069H	;6 -6 +  9
			DB  068H	;7 -6 +  8
			DB  067H	;8 -6 +  7
			DB  06BH	;9 -6 +  B
			DB  066H	;10 -6 +  6
			DB  065H	;11 -6 +  5
			DB  064H	;12 -6 +  4 
			DB  06AH	;13 -6 +  A
			DB  063H	;14 -6 +  3
			DB  062H	;15 -6 +  2
			DB  061H	;16 -6 +  1	
ORG 0540H //7 
			DB  07DH	;1 -7 + D   
			DB  07EH    ;2 -2 + E
			DB  070H	;3 -2 +  0    
			DB  07FH    ;4 -2 + F
			DB  07CH	;5 -7 +  C
			DB  079H	;6 -7 +  9
			DB  078H	;7 -7 +  8
			DB  077H	;8 -7 +  7
			DB  07BH	;9 -7 +  B
			DB  076H	;10 -7 +  6
			DB  075H	;11 -7 +  5
			DB  074H	;12 -7 +  4 
			DB  07AH	;13 -7 +  A
			DB  073H	;14 -7 +  3
			DB  072H	;15 -7 +  2
			DB  071H	;16 -7 +  1		
				
END 
