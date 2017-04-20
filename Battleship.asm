;***************************************************************************************
; Joel Torres
; June 2016
; BATTLESHIP
; **************************************************************************************
#include <msp430.h>
;---------------------------------------------------------------------------------------
;|||||||||||||||||||||||||||||||||||||MACROS||||||||||||||||||||||||||||||||||||||||||||
;---------------------------------------------------------------------------------------
; Writes a string from memory on the LCD

; string - memory address of first character in string
; position - command to set cursor on specific position in LCD
;---------------------------------------------------------------------------------------
wrtstr          MACRO   string, position        ; Define write string macro
                LOCAL   nextChar, done          ; Local variables
                push    R15                     ; Backup R15 into stack
                push    R13                     ; Backup R13 into stack
                mov     position, R15           ; Move position command to R15 
                call    #Command                ; Send to Command specific cursor position
                mov     #string, R13            ; Move string to R13
nextChar        mov.b   @R13+, R15              ; Move the address in R13 to R15 and increment
                cmp.b   #'*', R15               ; End of string?
                jz      done                    ; If end of string, jump to done
                call    #WriteLCD               ; Write the contents of R15 in LCD
                jmp     nextChar                ; Check if there are characters remaining
done            pop     R13                     ; Put back R13 original contents (if any)
                pop     R15                     ; Put back R15 original contents (if any)
                ENDM                            ; End Macro
;---------------------------------------------------------------------------------------
;||||||||||||||||||||||||||||||||||||Program Setup||||||||||||||||||||||||||||||||||||||
;---------------------------------------------------------------------------------------
		ORG     0C000h			; Program Start
RESET 		mov.w   #0400h , SP 		; Initialize SP
StopWDT 	mov.w   #WDTPW+WDTHOLD,&WDTCTL 	; Stop WDT
SetupP1 	mov.b   #0xF3 ,&P1DIR 	        ; Setup P1
                bic.b   #0xFF, &P1OUT           ; Clear P1
SetupP2         mov.b   #0x07, &P2DIR           ; Setup P2
                bic.b   #0xFF, &P2OUT           ; Clear P2
                bis.b   #00001100b ,&P1REN      ; Select internal resistor for buttons
                bis.b   #00001100b ,&P1OUT      ; Make it pull-up (buttons)
                call    #InitLCD                ; Initialize LCD
                mov.b   #0x01, R15              ; Clear LCD
                call    #Command                ; Send Clear LCD command
                mov.b   #0x0C, R15              ; Remove blinking cursor
                call    #Command                ; Send command to remove blinking cursor
                call    #Delay                  ; LCD initialized; give it some time...       
                bis.b   #0x0C, &P1IE            ; Enable P1.2, P1.3 interruptions
                bic.b   #0x0C, &P1IFG           ; Clear interrupt flag on P1.2, P1.3
                eint                            ; Global interrupt enable                
;---------------------------------------------------------------------------------------
;|||||||||||||||||||||||||||||||||||GAME START||||||||||||||||||||||||||||||||||||||||||
;--------------------------------------------------------------------------------------- 
Welcome         mov     #0x83, R12              ; Move cursor position 0x83 to R12
                wrtstr  MSGStart, R12           ; Display "Battleship" on LCD at position in R12
                mov     #50, R7                 ; Move value to R7 for a delay after title
                
D0              call    #Delay                  ; Call Delay subroutine
                dec     R7                      ; Decrement R7 by one
                jnz     D0                      ; Jump back to D0 if condition isn't satisfied
                
                mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display
                mov     #1, R11                 ; Counter for coordinates selection
                mov     #-1, R13                ; Counter to know if ENTER pressed or display next ship prompt
                mov     #0x80, R12              ; Move cursor position to R12
                wrtstr  MSGSHIP1, R12           ; Display "Ship 1> " prompt  
                mov     #0x88, R12              ; Move first cursor position to R12               
                wrtstr  MSGCOORA1, R12          ; Display "A1" on screen (first coordinate)
                mov     #0xC0, R12              ; Move new cursor position to R12               
                wrtstr  MSGBUTTONS, R12         ; Display buttons function message
                mov     #0x88, R12              ; Move new cursor position to R12
                mov     #0x04, R10              ; Move first coordinate (A1) to temporary coordinate holder register (R10)                
Coordinates     cmp     #5, R13                 ; Compare ENTER counter with max pressing times before continuing game
                jnz     Coordinates             ; Keep waiting until all coordinates are entered
                mov.b   #6, R6                  ; Set ship coordinates counter (2 coordinates per ship = 6 coordinates)
DisplayPlayer   mov     #5, R13                 ; Force ENTER counter to five for further playing
                mov.b   #0x01, R15              ; Clear display 
                call    #Command                ; Call command to clear display
                mov.b   #0x80, R12              ; Move cursor position to R12
                call    #Delay                  ; Give some time to clear LCD command
                wrtstr  MSGPLAYER1, R12         ; Display "Attack?" prompt
                mov     #0xC0, R12              ; Move cursor position to R12               
                wrtstr  MSGBUTTONS, R12         ; Display buttons function message
                mov     #17, R11                ; Set B1 counter to 17 for player selection
                mov     #0, R9                  ; Marker for player 1 (0) or player 2 (1)

Player          cmp     #6, R13                 ; Compare ENTER counter 
                jnz     Player                  ; Jump back to Player if ENTER hasn't been pressed    
                                                ; If here, a player was selected
                cmp     #0, R9                  ; Now, check which player was selected
                jz      Attack                  ; Jump to Attack subroutine if player 1 was selected
                cmp     #1, R9                  ; Check if Player 2 was selected
                jz      Defend                  ; Jump to Defend subroutine if player 2 was selected            
                               
Attack:                                         ; Attack mode subroutine
                mov     #0x04, R8               ; Move first coordinate (A1) to attack register
Let1            cmp     #7, R13                 ; Compare ENTER counter                 
                jnz     Let1                    ; Jump back to Let1 until condition is satisfied (ENTER pressed)
                call    #SendAttack             ; ENTER pressed, call subroutine SendAttack to send letter first
Num1            cmp     #8, R13                 ; Compare ENTER counter again
                jnz     Num1                    ; Jump back to Num1 until condition is satisfied (ENTER pressed)
                call    #SendAttack             ; ENTER pressed, call subroutine SendAttack again to send number 
                jmp     DisplayPlayer           ; Attack mode finished; jump back to mode selection

Defend:                                         ; Defend mode subroutine
Let2            cmp     #6, R13                 ; Compare ENTER counter
                jnz     Let2                    ; Jump back to Let2 until condition is satisfied (ENTER pressed)
                call    #ReceiveAttack          ; ENTER pressed, call subroutine ReceiveAttack to receive letter first                                   
Num2            cmp     #7, R13                 ; Compare ENTER counter again
                jnz     Num2                    ; Jump back to Num2 until condition is satisfied (ENTER pressed)
                call    #ReceiveAttack          ; ENTER pressed, call subroutine ReceiveAttack again to receive number                
                cmp     #0, R6                  ; Defend mode finished; compare coordinates counter with 0
                jz      GameOver                ; Jump to GameOver if counter of coordinates (R6) is zero
                jmp     DisplayPlayer           ; Jump back to mode selection if there are coordinates left
                
GameOver        mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move first cursor position to R12
                call    #Delay                  ; Give some time to clear LCD command
                wrtstr  MSGGAMEOVER, R12        ; Display "GAME OVER" message on LCD        
                jmp     $                       ; Infinite loop for testing purposes
;---------------------------------------------------------------------------------------
;|||||||||||||||||||||||||||||||||||||SUBROUTINES|||||||||||||||||||||||||||||||||||||||
;---------------------------------------------------------------------------------------
;                               Send Attack Coordinate
;---------------------------------------------------------------------------------------
SendAttack      mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move cursor position to R12
                push    R8                      ; Backup attack coordinate (R8) before making changes
                
                cmp     #7, R13                 ; Compare ENTER counter 
                jz      SendLetter              ; Jump to SendLetter if counter is 7
                cmp     #8, R13                 ; Compare ENTER counter again
                jz      SendNumber              ; Jump to SendNumber if counter is 8
                
SendLetter      wrtstr  MSGLETTER1, R12         ; Display "Sending letter..." message on LCD
                rra     R8                      ; Rotate to the right to put msb on lsb location
                rra     R8                      ; Rotate again
                rra     R8                      ; And again
                rra     R8                      ; And again
                mov.b   R8, &P2OUT              ; Now, move R8 contents (letter) to P2 
                pop     R8                      ; Pop back R8 (original contents)
                mov     #0xC0, R12              ; Move cursor position to R12               
                wrtstr  MSGENTER, R12           ; Display "Press ENTER" message on LCD    
                jmp     ExitAttack              ; Jump to exit (ret)
                                         
SendNumber      wrtstr  MSGNUMBER1, R12         ; Display "Sending number..." message on LCD
                mov.b   R8, &P2OUT              ; Move R8 contents (number) to P2                
                mov     #0xC0, R12              ; Move cursor position to R12               
                wrtstr  MSGWAITING, R12         ; Display "Please wait..." message on LCD                
                mov     #40, R7                 ; Move value to R7 for a delay
D1              call    #Delay                  ; Call Delay subroutine
                dec     R7                      ; Decrement R7 by one
                jnz     D1                      ; Jump back to label D1 if R7 isn't zero
                
                mov.b   #0x01, R15              ; Clear LCD
                call    #Command                ; Send Clear LCD command
                mov     #0x80, R12              ; Move cursor position to R12 
                wrtstr  MSGSENT, R12            ; Display "Attack completed" message on LCD

                mov     #40, R7                 ; Move value to R7 for a delay
D2              call    #Delay                  ; Call Delay subroutine
                dec     R7                      ; Decrement R7 by one
                jnz     D2                      ; Jump back to label D2 if R7 isn't zero
                
                jmp     DisplayPlayer           ; Jump back to Display Player to choose player again
                
ExitAttack      ret                             ; Exit SendAttack subroutine 
;---------------------------------------------------------------------------------------
;                               Receive Attack Coordinate
;---------------------------------------------------------------------------------------
ReceiveAttack   bit.b   #0x20, &P2IN            ; First, test control bit (P2.5)
                
                jnc     Letter                  ; Control bit is 0, letter is being received                
                jmp     Number                  ; If here, control bit is 1 so number is being received
                 
Letter          mov     #0x00, R4               ; Clean R4 for input coordinate
                bit.b   #BIT4, &P2IN            ; Test P2.4 for input               
                rlc     R4                      ; Rotate left with carry to insert control bit (0 for letter)
                bit.b   #BIT3, &P2IN            ; Test P2.3 for input
                rlc     R4                      ; Rotate left with carry again, this time with P2.3 input
                mov     #0xC0, R12              ; Move cursor position to R12               
                wrtstr  MSGENTER, R12	        ; Display "Press ENTER" message on LCD 
                jmp     ExitDefend              ; Letter input completed, jump to ExitDefend (ret)
                
Number		mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display 
                mov     #0x80, R12              ; Move cursor position to R12
                wrtstr  MSGNUMBER2, R12         ; Display "Receiving number" on LCD

                mov     #40, R7                 ; Move value to R7 for a delay
D3              call    #Delay                  ; Call Delay subroutine
                dec     R7                      ; Decrement R7 by one
                jnz     D3                      ; Jump back to label D3 if R7 isn't zero
                
                rla     R4                      ; Insert 0 between letter nibble and number nibble
                bit.b   #BIT5, &P2IN            ; Test control bit (P2.5) to generate carry
                rlc     R4                      ; Rotate left with carry to insert control bit (1 for number)
                bit.b   #BIT4, &P2IN            ; Test P2.4 for input                
                rlc     R4                      ; Rotate left with carry again, this time with P2.4 input
                bit.b   #BIT3, &P2IN            ; Test P2.3 for input
                rlc     R4                      ; Rotate left with carry again, this time with P2.3 input
		              
                cmp     R4, 0x0300              ; Compare input coordinate in R4 with ship coordinates
                jz      Hit                     ; If zero, attack was succesful; jump to Hit 
                
                cmp     R4, 0x0302              ; Compare input coordinate in R4 with ship coordinates
                jz      Hit                     ; If zero, attack was succesful; jump to Hit 
                
                cmp     R4, 0x0304              ; Compare input coordinate in R4 with ship coordinates             
                jz      Hit                     ; If zero, attack was succesful; jump to Hit 
                
                cmp     R4, 0x0306              ; Compare input coordinate in R4 with ship coordinates  
                jz      Hit                     ; If zero, attack was succesful; jump to Hit 
                
                cmp     R4, 0x0308              ; Compare input coordinate in R4 with ship coordinates              
                jz      Hit                     ; If zero, attack was succesful; jump to Hit
                
                cmp     R4, 0x030A              ; Compare input coordinate in R4 with ship coordinates 
                jz      Hit                     ; If zero, attack was succesful; jump to Hit
                                
                jmp     Safe                    ; If here, attack was unsuccessful; jump to Safe
                
Hit             dec     R6                      ; Decrement ship coordinates counter
                mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move cursor position to R12
                call    #Delay                  ; Give some time to clear LCD command
                wrtstr  MSGSHIPHITS, R12        ; Display "You're hit! :(" message on LCD
                call    #Delay          
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                
                jmp     ExitDefend              ; Hit action completed, jump to ExitDefend (ret)              
                                
Safe            mov.b   #0x01, R15              ; Clear display
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move first cursor position to R12
                call    #Delay                  ; Give some time to clear LCD command
                wrtstr  MSGSHIPHITNS, R12       ; Display "You're safe! :P" message on LCD
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                call    #Delay
                jmp     ExitDefend              ; Safe action completed, jump to ExitDefend (ret)                 
                                
ExitDefend      ret                             ; Defend completed; return back to caller
;---------------------------------------------------------------------------------------
;                                      Command
;---------------------------------------------------------------------------------------
Command		bic.b   #0xF0, &P1OUT           ; Clear msbyte      
                bis.b   R15, &P1OUT             ; Put data on P1
		bic.b   #0x01, &P1OUT	        ; Set D/I=LOW : Write
		call    #Nybble			; Send lower 4 bits
                bic.b   #0xF0, &P1OUT           ; Clear msb  
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
		bis.b   R15, &P1OUT		; Send upper 4 bits
		call    #Nybble                 ; Call nybble subroutine
		ret                             ; Return from subroutine
;---------------------------------------------------------------------------------------
;                                    Write to LCD
;---------------------------------------------------------------------------------------
WriteLCD	bic.b   #0xF0, &P1OUT           ; Clear msbyte     
                bis.b   R15, &P1OUT             ; Put data on P1
		bis.b   #0x01, &P1OUT	        ; Set D/I=LOW : Write
		call    #Nybble			; Send lower 4 bits
                bic.b   #0xF0, &P1OUT           ; Clear msb
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
                rla     R15                     ; Shift left
		bis.b   R15, &P1OUT		; Send upper 4 bits
		call    #Nybble                 ; Call nybble subroutine
		ret                             ; Return from subroutine
;---------------------------------------------------------------------------------------
;                                       Nybble
;---------------------------------------------------------------------------------------
Nybble   	bis.b   #0x02, &P1OUT	        ; E = 1
		call    #Delay		        ; enable pulse width >= 300ns
		bic.b   #0x02, &P1OUT	        ; Clock enable: falling edge (E = 0)
		ret                             ; Return from subroutine
;---------------------------------------------------------------------------------------
;                                       Delay
;---------------------------------------------------------------------------------------
Delay  		mov     #10000 ,R14 		; Delay to R14       
L1		dec     R14 			; Decrement R14
 		jnz     L1 			; Delay over?
		ret                             ; Return from subroutine
;---------------------------------------------------------------------------------------
;                                  Init Subroutine
;---------------------------------------------------------------------------------------
InitLCD		bic.b   #0xFF, &P1OUT           ; P1 = 0 & E = 0
		call    #Delay			; Wait >15 msec after power is applied
		bis.b   #0x30, &P1OUT		; put 0x30 on the output port
		call    #Delay			; must wait 5ms, busy flag not available
		call    #Nybble			; command 0x30 = Wake up
		call    #Delay			; must wait 160us, busy flagnot available
		call    #Nybble			; command 0x30 = Wake up #2
		call    #Delay			; must wait 160us, busy flagnot available
		call    #Nybble			; command 0x30 = Wake up #3
		call    #Delay			; can check busy flag now instead of delay
		bic.b   #0xF3, &P1OUT           ; Clear P1 outputs        
                bis.b   #0x20, &P1OUT		; put 0x20 on the output port
		call    #Nybble			; Function set: 4-bit interface
                mov     #0x28, R15              ; Move 0x28 command to R15
		call    #Command	        ; Function set: 4-bit/2-line
                mov     #0x10, R15              ; Move 0x10 command to R15
		call    #Command		; Set cursor
                mov     #0x0F, R15              ; Move 0x0F command to R15
		call    #Command		; Display ON; Blinking cursor
                mov     #0x06, R15              ; Move 0x06 command to R15
		call    #Command		; Entry Mode set
                ret                             ; Return from subroutine
;---------------------------------------------------------------------------------------
;                      P1 Buttons Interrupt Service Routine
;---------------------------------------------------------------------------------------
PBISR           bit.b   #0x04, &P1IFG           ; Check if interruption occured on left button
                jc      INTB1                   ; Jump to INTB1 subroutine if button 1 was pressed
                bit.b   #0x08, &P1IFG           ; Check if interruption occured on right button
                jc      INTB2                   ; Jump to INTB2 subroutine if button 2 was pressed       
         ;------------------------Button 1-----------------------;                
INTB1:          cmp     #0, R11                 ; Compare R11 counter with 0 (SELECT not pressed yet)
                jz      COORA1                  ; Jump to Coordinate A1 if valid
                cmp     #1, R11                 ; Compare R11 counter with 1 (SELECT pressed once)
                jz      COORA2                  ; Jump to Coordinate A2 if valid
                cmp     #2, R11                 ; Compare R11 counter with 2 (SELECT pressed twice)
                jz      COORA3                  ; Jump to Coordinate A3 if valid
                cmp     #3, R11                 ; Compare R11 counter with 3 (SELECT pressed three times)
                jz      COORA4                  ; Jump to Coordinate A4 if valid
                cmp     #4, R11                 ; Compare R11 counter with 4 (SELECT pressed four times)
                jz      COORB1                  ; Jump to Coordinate B1 if valid
                cmp     #5, R11                 ; Compare R11 counter with 5 (SELECT pressed five times)
                jz      COORB2                  ; Jump to Coordinate B2 if valid
                cmp     #6, R11                 ; Compare R11 counter with 6 (SELECT pressed six times)
                jz      COORB3                  ; Jump to Coordinate B3 if valid 
                cmp     #7, R11                 ; Compare R11 counter with 7 (SELECT pressed seven times)
                jz      COORB4                  ; Jump to Coordinate B4 if valid            
                cmp     #8, R11                 ; Compare R11 counter with 8 (SELECT pressed eight times)
                jz      COORC1                  ; Jump to Coordinate C1 if valid
                cmp     #9, R11                 ; Compare R11 counter with 9 (SELECT pressed nine times)
                jz      COORC2                  ; Jump to Coordinate C2 if valid
                cmp     #10, R11                ; Compare R11 counter with 10 (SELECT pressed ten times)
                jz      COORC3                  ; Jump to Coordinate C3 if valid
                cmp     #11, R11                ; Compare R11 counter with 11 (SELECT pressed eleven times)
                jz      COORC4                  ; Jump to Coordinate C4 if valid
                cmp     #12, R11                ; Compare R11 counter with 12 (SELECT pressed twelve times)
                jz      COORD1                  ; Jump to Coordinate D1 if valid
                cmp     #13, R11                ; Compare R11 counter with 13 (SELECT pressed thirteen times)
                jz      COORD2                  ; Jump to Coordinate D2 if valid
                cmp     #14, R11                ; Compare R11 counter with 14 (SELECT pressed fourteen times)
                jz      COORD3                  ; Jump to Coordinate D3 if valid
                cmp     #15, R11                ; Compare R11 counter with 15 (SELECT pressed fifteen times)
                jz      COORD4                  ; Jump to Coordinate D4 if valid
                cmp     #16, R11                ; Compare R11 counter with 16 (player selection SELECT pressed once)               
                jz      Player1                 ; Jump to Player 1 if valid                
                cmp     #17, R11                ; Compare R11 counter with 16 (player selection SELECT pressed twice)              
                jz      Player2                 ; Jump to Player 1 if valid
                
COORA1:         wrtstr   MSGCOORA1, R12         ; Display coordinate A2 on LCD
                mov      #0x04, R10             ; Move A1 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)
                                                                                                                                                                     ; Jump to interrupt exit (reti)
COORA2:         wrtstr   MSGCOORA2, R12         ; Display coordinate A2 on LCD
                mov      #0x05, R10             ; Move A2 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORA3:         wrtstr   MSGCOORA3, R12         ; Display coordinate A3 on LCD
                mov      #0x06, R10             ; Move A3 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORA4:         wrtstr   MSGCOORA4, R12         ; Display coordinate A4 on LCD
                mov      #0x07, R10             ; Move A4 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORB1:         wrtstr   MSGCOORB1, R12         ; Display coordinate B1 on LCD
                mov      #0x14, R10             ; Move B1 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)  

COORB2:         wrtstr   MSGCOORB2, R12         ; Display coordinate B2 on LCD
                mov      #0x15, R10             ; Move B2 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORB3:         wrtstr   MSGCOORB3, R12         ; Display coordinate B3 on LCD
                mov      #0x16, R10             ; Move B3 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORB4:         wrtstr   MSGCOORB4, R12         ; Display coordinate B4 on LCD
                mov      #0x17, R10             ; Move B4 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORC1:         wrtstr   MSGCOORC1, R12         ; Display coordinate C1 on LCD
                mov      #0x24, R10             ; Move C1 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORC2:         wrtstr   MSGCOORC2, R12         ; Display coordinate C2 on LCD
                mov      #0x25, R10             ; Move C2 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORC3:         wrtstr   MSGCOORC3, R12         ; Display coordinate C3 on LCD
                mov      #0x26, R10             ; Move C3 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORC4:         wrtstr   MSGCOORC4, R12         ; Display coordinate C4 on LCD
                mov      #0x27, R10             ; Move C4 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORD1:         wrtstr   MSGCOORD1, R12         ; Display coordinate D1 on LCD
                mov      #0x34, R10             ; Move D1 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORD2:         wrtstr   MSGCOORD2, R12         ; Display coordinate D2 on LCD
                mov      #0x35, R10             ; Move D2 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORD3:         wrtstr   MSGCOORD3, R12         ; Display coordinate D3 on LCD
                mov      #0x36, R10             ; Move D3 to R10 to send it later to memory
                inc      R11                    ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)

COORD4:         wrtstr   MSGCOORD4, R12         ; Display coordinate D4 on LCD
                mov      #0x37, R10             ; Move D4 to R10 to send it later to memory
                mov      #0, R11                ; Increase R11 counter (SELECT)
                jmp      B1Exit                 ; Jump to interrupt exit (reti)                               

Player1         mov.b   #0x01, R15              ; Clear display
                mov     #0, R9                  ; Move 0 to marker for player 1 
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move first cursor position to R12
                wrtstr  MSGPLAYER1, R12         ; Display 
                mov     #0xC0, R12              ; Move first cursor position to R12               
                wrtstr  MSGBUTTONS, R12
                inc     R11                     ; Increase R11 counter (SELECT)
                jmp     B1Exit                  ; Jump to interrupt exit (reti)

Player2         mov.b   #0x01, R15              ; Clear display
                mov     #1, R9                  ; Move 1 to marker for player 2
                call    #Command                ; Call command to clear display
                mov     #0x80, R12              ; Move first cursor position to R12
                wrtstr  MSGPLAYER2, R12         ; Display ship 1 prompt
                mov     #0xC0, R12              ; Move first cursor position to R12               
                wrtstr  MSGBUTTONS, R12
                dec     R11                     ; Decrease R11 counter (SELECT) to display player 1 again
                jmp     B1Exit                  ; Jump to interrupt exit (reti)
                
B1Exit          jmp Exit                
         ;------------------------Button 2-----------------------;                            
INTB2:          inc     R13                     ; Increase R13 counter (ENTER)               
                mov     #0, R11                 ; Reset R11 counter (SELECT)
                
                cmp     #0, R13                 ; Compare R13 counter with 0 (ENTER not pressed yet)
                jz      Enter1                  ; Jump to Enter1 subroutine if valid
                
                cmp     #1, R13                 ; Compare R13 counter with 1 (ENTER pressed one time)
                jz      Enter2                  ; Jump to Enter2 subroutine if valid
                
                cmp     #2, R13                 ; Compare R13 counter with 2 (ENTER pressed two times)
                jz      Enter3                  ; Jump to Enter3 subroutine if valid
                
                cmp     #3, R13                 ; Compare R13 counter with 3 (ENTER pressed three times)
                jz      Enter4                  ; Jump to Enter4 subroutine if valid
                
                cmp     #4, R13                 ; Compare R13 counter with 4 (ENTER pressed four times)
                jz      Enter5                  ; Jump to Enter5 subroutine if valid
                
                cmp     #5, R13                 ; Compare R13 counter with 5 (ENTER pressed five times)
                jz      Enter6                  ; Jump to Enter6 subroutine if valid
                
                cmp     #6, R13                 ; Exit player selection
                jz      PlayerAction            ; Jump to player action
                
                cmp     #7, R13                 ; Compare R13 counter with 7 (ENTER pressed seven times)
                jz      Enter7                  ; Jump to Enter7 subroutine if valid
                
                cmp     #8, R13                 ; Compare R13 counter with 8 (ENTER pressed eight times)    
                jz      Enter8                  ; Jump to Enter8 subroutine if valid
                
                cmp     #9, R13                 ; Compare R13 counter with 9 (ENTER pressed nine times)
                jz      Enter9                  ; Jump to Enter9 subroutine if valid
                
Enter1          mov     #0x8B, R12              ; Move second coordinate cursor position to R12 (Ship 1, Second Coordinate)
                mov     R10, 0x0300             ; Move Ship 1 First Coordinate in R10 to memory                
                jz      INTB1                   ; Jump to second coordinate selection       
                
Enter2          mov     #0x80, R12              ; Move first coordinate cursor position to R12 (Ship 2, First Coordinate)
                mov     R10, 0x0302             ; Move Ship 1 Second Coordinate in R10 to memory
                jz      Ship2                   ; Jump to Ship 2 first coordinate selection
                
Enter3          mov     #0x8B, R12              ; Move second coordinate cursor position to R12 (Ship 2, Second Coordinate) 
                mov     R10, 0x0304             ; Move Ship 2 First Coordinate in R10 to memory
                jz      INTB1                   ; Jump to Ship 2 second coordinate selection
                
Enter4          mov     #0x80, R12              ; Move first coordinate cursor position to R12 (Ship 3, First Coordinate)
                mov     R10, 0x0306             ; Move Ship 2 Second Coordinate in R10 to memory
                jz      Ship3                   ; Jump to next ship first coordinate
                
Enter5          mov     #0x8B, R12              ; Move second coordinate cursor position to R12 (Ship 3, Second Coordinate)
                mov     R10, 0x0308             ; Move Ship 3 First Coordinate in R10 to memory
                jz      INTB1                   ; Jump to second coordinate selection
                
Enter6          mov     R10, 0x030A             ; Move Ship 3 Second Coordinate in R10 to memory                
                jmp     Exit                    ; Jump to second coordinate selection
                
Enter7          mov     R10, R8                 ; 
                jmp     Exit                    ; Coordinate to attack is in R8; exit   
                
Enter8          jmp     Exit                    ; Attack or Defend completed

Enter9          jmp     Exit                    

Ship2:          mov.b   #0x01, R15              ; Clear LCD command
                call    #Command                ; Call command subroutine to execute display clear
                wrtstr  MSGSHIP2, R12           ; Display ship 1 prompt  
                mov     #0x88, R12              ; Move first cursor position to R12               
                wrtstr  MSGCOORA1, R12          ; Display ship 1 prompt
                mov     #0xC0, R12              ; Move first cursor position to R12               
                wrtstr  MSGBUTTONS, R12         ; Display buttons function message
                mov     #0x88, R12              ; Move first cursor position to R12 
                inc     R11                     ; Increase R11 counter
                jmp     Exit                    ; Jump to interrupt exit (reti)
                               
Ship3:          mov.b   #0x01, R15              ; Clear LCD
                call    #Command                ; Call command subroutine to execute display clear
                wrtstr  MSGSHIP3, R12           ; Display ship 1 prompt  
                mov     #0x88, R12              ; Move first cursor position to R12               
                wrtstr  MSGCOORA1, R12          ; Display ship 1 prompt
                mov     #0xC0, R12              ; Move first cursor position to R12               
                wrtstr  MSGBUTTONS, R12         ; Display buttons function message
                mov     #0x88, R12              ; Move cursor to position in R12 
                inc     R11                     ; Increase R11 counter
                jmp     Exit                    ; Jump to interrupt exit (reti)
                
PlayerAction    cmp     #0, R9                  ; Compare if R9 has 0 (player 1)
                jz      Player1Action           ; Jump if zero to Player1Action
                cmp     #1, R9                  ; Compare if R9 has 1 (player 2)
                jz      Player2Action           ; Jump if zero to Player2Action
                jmp     Exit                    ; Jump to exit (reti)
                
Player1Action   mov     #0x80, R12              ; Move first cursor position to R12
                wrtstr  MSGATTACK, R12          ; Display attack message...
                mov     #1, R11                 ; Force 
                mov     #0x8A, R12              ; Move cursor to this position
                jmp     Exit                    ; Jump to exit (reti)

Player2Action   mov.b   #0x01, R15              ; Clear LCD
                call    #Command                ; Call command subroutine to execute display clear
                mov     #0x80, R12              ; Move first cursor position to R12
                wrtstr  MSGLETTER2, R12         ; Display defend message...                
                jmp     Exit                    ; Jump to exit (reti)
                
Exit            bic.b   #0xFF, &P1IFG           ; Clear interrupt flag in P1
                reti                            ; Return from interruption
;---------------------------------------------------------------------------------------
;                               LCD Messages
;---------------------------------------------------------------------------------------

MSGStart        DW      'BATTLESHIP*'           ; Welcome message
MSGBUTTONS      DW      'SELECT     ENTER*'     ; Buttons function display
MSGENTER        DW      'Press ENTER*'          ; Press Enter message
MSGSHIP1        DW      'Ship 1> *'             ; Ship 1 prompt
MSGSHIP2        DW      'Ship 2> *'             ; Ship 2 prompt
MSGSHIP3        DW      'Ship 3> *'             ; Ship 3 prompt         
MSGCOORA1       DW      'A1*'                   ; Coordinate A1 prompt
MSGCOORA2       DW      'A2*'                   ; Coordinate A2 prompt
MSGCOORA3       DW      'A3*'                   ; Coordinate A3 prompt
MSGCOORA4       DW      'A4*'                   ; Coordinate A4 prompt
MSGCOORB1       DW      'B1*'                   ; Coordinate B1 prompt
MSGCOORB2       DW      'B2*'                   ; Coordinate B2 prompt
MSGCOORB3       DW      'B3*'                   ; Coordinate B3 prompt
MSGCOORB4       DW      'B4*'                   ; Coordinate B4 prompt
MSGCOORC1       DW      'C1*'                   ; Coordinate C1 prompt
MSGCOORC2       DW      'C2*'                   ; Coordinate C2 prompt
MSGCOORC3       DW      'C3*'                   ; Coordinate C3 prompt
MSGCOORC4       DW      'C4*'                   ; Coordinate C4 prompt
MSGCOORD1       DW      'D1*'                   ; Coordinate D1 prompt
MSGCOORD2       DW      'D2*'                   ; Coordinate D2 prompt
MSGCOORD3       DW      'D3*'                   ; Coordinate D3 prompt
MSGCOORD4       DW      'D4*'                   ; Coordinate D4 prompt
MSGPLAYER1      DW      'Attack?*'              ; Attack (player 1) prompt
MSGPLAYER2      DW      'Defend?*'              ; Defend (player 2) prompt 
MSGATTACK       DW      'Attack! > A1*'         ; Attack coordinate prompt
MSGLETTER1      DW      'Sending letter >>*'    ; Sending attack coordinate letter message
MSGNUMBER1      DW      'Sending number >>*'    ; Sending number coordinate number message
MSGWAITING      DW      'Please wait...*'       ; Please wait... message
MSGLETTER2      DW      'Receiving letter*'     ; Receiving attack coordinate letter message
MSGNUMBER2      DW      'Receiving number*'     ; Receiving attack coordinate number message
MSGSENT         DW      'Attack completed*'     ; Attack completed message
MSGSHIPHITS     DW      'You''re hit! :(*'      ; Successful ship hit message
MSGSHIPHITNS    DW      'You''re safe! :P*'     ; Unsucessful ship hit message
MSGGAMEOVER     DW      'GAME OVER :(*'         ; Game over message
;---------------------------------------------------------------------------------------
;                               Interrupt Vectors
;---------------------------------------------------------------------------------------
		ORG     0FFFEh 			; MSP430 RESET Vector
		DW      RESET			; Address of label RESET
                ORG     0FFE4h                  ; Interrupt vector 2
                DW      PBISR                   ; ddress of label PBISR
                        END