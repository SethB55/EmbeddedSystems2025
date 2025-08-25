;
; Lab3.asm
;
; Created: 3/3/2025 9:40:14 PM
; Author : Seth Bolen & Adrian Alvarez
;

;
; Lab2.asm
;
; Created: 2/10/2025 5:44:39 PM
; Author : adralvarez + Seth Bolen
.include "m328Pdef.inc"
.cseg
.org 0

; ----------
; -- CODE --
; ----------
;   54393

; Use pin 4 and 5 for A and B outputs from RPG
.equ A_BIT = 41
.equ B_BIT = 5

; lookup table
lookup_table:
	.db 0x3F ; 0 on the display
	.db 0x06 ; 1 on the display
	.db 0x5B ; 2 on the display
	.db 0x4F ; 3 on the display
	.db 0x66 ; 4 on the display
	.db 0x6D ; 5 on the display
	.db 0x7D ; 6 on the display
	.db 0x07 ; 7 on the display
	.db 0x7F ; 8 on the display
	.db 0x6F ; 9 on the display
	.db 0x77 ; A on the display
	.db 0x7C ; B on the display
	.db 0x39 ; C on the display
	.db 0x5E ; D on the display
	.db 0x79 ; E on the display
	.db 0x71 ; F on the display


; configure I/O lines as output & connected to SN74HC595
sbi DDRB, 1 ; PB1 is now output to SER, PIN 14 on SR
sbi DDRB, 2 ; PB2 is now output to SRCLK,
sbi DDRB, 3 ; PB3 is now output to RCLCK
cbi DDRB, 0 ; PB0 IS INPUT FROM BUTTON!
sbi DDRB,5 ;output yellow LED
ldi R20, 0 

; set pins PB4 and PB5 as input lines for outputs A and B from rotary device
cbi DDRD, A_BIT
cbi DDRD, B_BIT

; timing
.equ SHORT_PRESS_TIME = 5 ; about 1 second threshold
.equ LONG_PRESS_TIME  = 12 ; about 2 second threshold

; states
.equ STATE_00 = 0
.equ STATE_01 = 1
.equ STATE_11 = 2
.equ STATE_10 = 3


; set shift register connection lines as 0
cbi PORTB, 1
cbi PORTB, 2
cbi PORTB, 3

; set names for registers
.def display_value = R16
.def temp = R21
.def timerINC = R20
.def curr_state = R24 ; current state of the state machine
.def new_state = R25 ; new state to transition to

.def count = R18 ; keeps track of what number is being displayed 
.def inputIndex = R22 ; keeps track of how many inputs have already been input so we can easier compare
.def willUnlock = R23 ; will unlock will act as a boolean, we will set it to true if all input numbers match the combination.


ldi display_value, 0x40 ; set the first thing when power to "-"
rcall display
cbi PORTB, 5 ; led reset
ldi R18, 0 ; load default value 0 into R18
ldi willUnlock, 0 ; load 0 so we can compare if its 5 later on
ldi inputIndex, 0 ; load 0 do determine which combination index we are on

button_set:
cpi r26, 0
breq turn_on_fan
cpi r2, 1
breq turn_off_fan
reti

turn_on_fan:
ldi r24, 1
LDI r22, 100 ; set duty cycle to turn on fan
OUT OCR0B, r22
reti

turn_off_fan:
ldi r24, 0
LDI r22, 0 ; set duty cycle to turn off fan
OUT OCR0B, r22
reti

;Using R16, R17, R18, R20, R21, R22, R23, R24, R27, R30, R31
main_loop:
    ; read current value of A and B pins
    in temp, PIND
    andi temp, (1 << A_BIT) | (1 << B_BIT)
    
    ; determine the new state based on pin readings
    ldi new_state, STATE_00 ; default to 00
    cpi temp, 0x00
    breq state_detected
    ldi new_state, STATE_01 ; set to 01
    cpi temp, 0x10
    breq state_detected
    ldi new_state, STATE_11 ; set to 11
    cpi temp, 0x30
    breq state_detected
    ldi new_state, STATE_10 ; set to 10
    cpi temp, 0x20
    breq state_detected
    
    ; if we get here, the reading was invalid (shouldn't happen)
    rjmp check_button
    
state_detected:
    ; if the state hasn't changed, nothing to do
    cp new_state, curr_state
    breq check_button
    
    ; check for clockwise rotation (00?01?11?10?00)
    cpi curr_state, STATE_00
    brne not_cw_from_00
    cpi new_state, STATE_01
    breq update_state ; valid transition, but rotation not complete
    rjmp check_ccw
    
not_cw_from_00:
    cpi curr_state, STATE_01
    brne not_cw_from_01
    cpi new_state, STATE_11
    breq update_state ; valid transition, but rotation not complete
    rjmp check_ccw
    
not_cw_from_01:
    cpi curr_state, STATE_11
    brne not_cw_from_11
    cpi new_state, STATE_10
    breq update_state ; valid transition, but rotation not complete
    rjmp check_ccw
    
not_cw_from_11:
    cpi curr_state, STATE_10
    brne check_ccw
    cpi new_state, STATE_00
    brne check_ccw
    
    ; clockwise rotation completed
    cpi count, 15
    brge stay_at_F
    inc count
    rcall update_display
    rjmp update_state
    
check_ccw:
    ; check for counter-clockwise rotation (00?10?11?01?00)
    cpi curr_state, STATE_00
    brne not_ccw_from_00
    cpi new_state, STATE_10
    breq update_state ; valid transition, but rotation not complete
    rjmp update_state ; not a valid transition
    
not_ccw_from_00:
    cpi curr_state, STATE_10
    brne not_ccw_from_10
    cpi new_state, STATE_11
    breq update_state ; valid transition, but rotation not complete
    rjmp update_state ; not a valid transition
    
not_ccw_from_10:
    cpi curr_state, STATE_11
    brne not_ccw_from_11
    cpi new_state, STATE_01
    breq update_state ; valid transition, but rotation not complete
    rjmp update_state ; not a valid transition
    
not_ccw_from_11:
    cpi curr_state, STATE_01
    brne update_state
    cpi new_state, STATE_00
    brne update_state
    
    ; counter-clockwise rotation completed
    cpi count, 0
    breq stay_at_0
    dec count
    rcall update_display
    
update_state:
    ; update the current state
    mov curr_state, new_state
    
check_button:
    ; Button code
    ; Since the button is active low, when NOT pressed PB0 = 1.
    sbis PINB, 0      ; skip next instruction if PB0 is set (bit is 1) (i.e. button not pressed)
    rjmp button_pressed ; when button is pressed, PB0 becomes 0, so we rjmp to button_pressed subroutine
    
    cpi inputIndex, 5 ; checks if the number combination indexs is 5
    breq combinationCheck ; if true go to combinationCheck

    rjmp main_loop    ; continue looping if no change

; button is pressed
button_pressed: ; In this loop, if the button is still pressed (active low: PD5 = 0), then SBIC will skip the next
				; instruction. If the button is released (PD5 = 1), SBIC will NOT skip, and will go rjmp to do_something_loop
	sbi PORTB, 5 ; light up yellow led on board and decimal for 4 seconds
	rcall delay_10ms ; ea 1 sec	
	cbi PORTB, 5 ; turn off yellow led

    sbic PINB,0 ; skip next instruction if PD5 is clear (button unpressed)
    rjmp do_something_loop ; if not skipped (button released), exit loop.
    inc timerINC ; increment the press-duration counter to use to compare with later
    rcall delay_10ms ; delay a fixed interval (about .1 second)
    rjmp button_pressed ; loop back and continue while button is pressed

do_something_loop: ; do_something_loop subroutine decides what the button does based off of how long it was pressed (the number stored in r20)
	cpi timerINC, 100
	brlo checkInput ; iF timer increment is less than .1 ms * 100 = 10s, jump to storing or checking if the input matches the combination
	rjmp reset_display

reset_display:
	ldi timerINC, 0
    ldi display_value, 0x40 ; Load "-" character
    rcall display           ; Call display update
    ldi count, 0            ; Reset count
    ldi inputIndex, 0       ; Reset input index
    ldi willUnlock, 0       ; Reset unlock flag
    rjmp main_loop          ; Return to main loop
; makes sure display doesnt overflow over F
stay_at_F:
    ; Stay at "F"
    ldi display_value, 0x71 ; displays "F"
    rcall display
    rcall delay
    rjmp main_loop ; keep looping

; makes sure display doesnt overflow over 0
stay_at_0:
    ; Stay at "0"
    ldi display_value, 0x3F ; displays "0"
    rcall display
    rcall delay
    rjmp main_loop ; keep looping

; checks if the combination is correct
combinationCheck:
	cpi willUnlock, 5
	breq unlockLock ; if combination correct, willUnlock == 5, unlock lock
	rjmp lock ; else keep it locked

; checks the input for the combinaion, based on which index the user is on
checkInput:
	cpi inputIndex, 0 ; checking what digit (place in the combination sequence of code) we will be comparing the current input/digit
	breq checkInput0
	cpi inputIndex, 1
	breq checkInput1
	cpi inputIndex, 2
	breq checkInput2
	cpi inputIndex, 3
	breq checkInput3
	cpi inputIndex, 4
	breq checkInput4

	rjmp main_loop

; checkInput0 through checkInput4 checks if the input value matches the corresponding passcode value and increments the code index
; if one of the values doesn't match, the willUnlock value will not increment
checkInput0:
	inc inputIndex ; increments the inputIndex to go to the next input
	cpi count, 5
	breq inc_index ; if first input is equal to 5 go to inc_index
	rjmp main_loop ; go back to main loop
checkInput1:
	inc inputIndex ; increments the inputIndex to go to the next input
	cpi count, 4
	breq inc_index ; if first input is equal to 4 go to inc_index
	rjmp main_loop
checkInput2:
	inc inputIndex ; increments the inputIndex to go to the next input
	cpi count, 3
	breq inc_index ; if first input is equal to 3 go to inc_index
	rjmp main_loop
checkInput3:
	inc inputIndex ; increments the inputIndex to go to the next input
	cpi count, 9
	breq inc_index ; if first input is equal to 9 go to inc_index
	rjmp main_loop 
checkInput4:
	inc inputIndex ; increments the inputIndex to go to the next input
	cpi count, 3
	breq inc_index ; if first input is equal to 3 go to inc_index
	rjmp main_loop
	
; increments willUnlock
inc_index:
	inc willUnlock
	rjmp main_loop

/*
; checks if the combination is correct
combinationCheck:
	cpi willUnlock, 5
	breq unlockLock ; if combination correct, willUnlock == 5, unlock lock
	rjmp lock ; else keep it locked
*/

; unlocks lock
unlockLock:
	; the three snippets of code resets all the registers so the user may try another combination
	ldi count, 0 ; resets the count
	ldi inputIndex, 0 ; resets the inputIndex
	ldi willUnlock, 0 ; resets the willUnlock
	ldi display_value, 0x80 ; displays "."
	rcall display
	sbi PORTB, 5 ; light up yellow led on board and decimal for 4 seconds
	rcall delay ; ea 1 sec
	rcall delay
	rcall delay
	rcall delay
	cbi PORTB, 5 ; turns off yellow led
	ldi display_value, 0x40 ; reset display to "-"
	rcall display
	rjmp main_loop ; goes back to main_loop for user to try again

; keeps lock locked
lock:
	; the three snippets of code resets all the registers so the user may try another combination
	ldi count, 0 ; resets the count
	ldi inputIndex, 0 ; resets the inputIndex
	ldi willUnlock, 0 ; resets the willUnlock
	ldi display_value, 0x08 ; displays "_"
	rcall display
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	ldi display_value, 0x40 ; reset display to "-"
	rcall display
	rjmp main_loop ; goes back to main_loop for user to try again

; uses the lookup table to update whats displayed
update_display:
	; Use the Z pointer to look up the display pattern from program memory
    ldi ZL, LOW(2*lookup_table) ; load low byte of table address with the 2* multiplier for word addressing
    ldi ZH, HIGH(2*lookup_table) ; load high byte of table address
    
    mov temp, count ; move count to temp register
    lsl temp ; multiply by 2 for proper program memory word addressing
    add ZL, temp ; add offset to Z pointer
    ldi temp, 0 ; clear temp for carry
    adc ZH, temp ; add carry to high byte
    
    lpm display_value, Z ; load pattern from program memory at Z pointer

	; delays before displaying variable
	;rcall delay_10ms 
	;rcall delay_10ms rcall delay_10ms 
	;rcall delay_10ms 

    rcall display ; call display routine
	rcall delay_10ms 
	rcall delay_10ms rcall delay_10ms 
	rcall delay_10ms 
    rjmp main_loop ; return to main loop


display:
	; backup used registers on stack
	push display_value
	push R17
	in R17, SREG
	push R17

	ldi R17, 8 ; loop --> test all 8 bits
loop:
	rol display_value ; rotate left trough Carry
	BRCS set_ser_in_1 ; branch if Carry is set
	cbi PORTB,1 ; set SER to 0

	rjmp end
set_ser_in_1:
	sbi PORTB,1 ; set SER to 1

end:
; generate SRCLK pulse, sets pins
	sbi PORTB,2 ; set SRCLK to 1
	nop ; delay
	nop
	nop
	nop
	cbi PORTB,2 ; set back to 0

	dec R17
	brne loop

	; generate RCLK pulse, parallel output 8 bits in register
	sbi PORTB,3
	nop
	nop
	nop
	cbi PORTB,3

	; restore registers from stack
	pop R17
	out SREG, R17
	pop R17
	pop display_value

	ret

; === Delay Subroutines === basically makes the program run through junk loops for about 0.2 seconds
delay:
	delay_1s:
	ldi r27, 100
	delay_1s_cont:
	cpi r27, 0
	rcall delay_10ms
	dec r27
	brne delay_1s_cont
	ret
;delay for 10ms
	delay_10ms:
	ldi r24, 0b00000101 ; Set prescaler to 1024
	out TCCR0B, r24
	ldi r24,100
	out TCNT0, r24 ; Set timer count to 100
; Wait for TIMER0 to roll over.
	delay_cont:
; Stop timer 0.
	in r30,TCCR0B ; Save configuration
	ldi r31,0x00 ; Stop timer 0
	out TCCR0B,r31
; Clear overflow flag.
	in r31,TIFR0 ; tmp <-- TIFR0
	sbr r31,1<<TOV0 ; Clear TOV0, write logic 1
	out TIFR0,r31
; Start timer with new initial count
	out TCNT0,r24 ; Load counter
	out TCCR0B,r30 ; Restart timer
	wait:
	in r31,TIFR0 ; tmp <-- TIFR0
	sbrs r31,TOV0 ; Check overflow flag
	rjmp wait
	ret

