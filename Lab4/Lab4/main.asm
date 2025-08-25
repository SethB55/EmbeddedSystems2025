;RPG just randomly doesnt work now
; Lab4.asm
;
; Created: 3/24/2025 2:49:42 PM
; Author : Adrian Alvarez, Seth Bolen
;

;.def fan_const = r14 ; fan constant which is compared with fan boolean
;.def fan_boolean = r29 ; determines if fan should be running or not
.def data = r16 ; data line that includes display or instructions (write to PORTC)
.def char = r17 ; full 8 bit character which is spliced into 4 bit data during display
.def remainder = r23
.def dividend = r19
.def divisor = r25
.def lc = r18
.def ascii_const = r14
.def prev_state = r30


.org 0x0000 ; program starts here, source: RESET
	rjmp setup
.org 0x0002 ; interrupt for button, source: INT0
	rjmp button_interrupt
.org 0x0006 ; interrupt for rpg, source: PCINT0
	rjmp rpg_interrupt



; setups everything for the program
; used registers: r24, r25, r26, r27, r31
.org 0x0032 ; starts the program, souce: SPM_Ready
setup:
	; intialie input pins
	cbi DDRD, 2 ; PB0 is input for button
	cbi DDRB, 0 ; A bit for rpg
	cbi DDRB, 1 ; B bit for rpg

	; initialize output pins
	; RS nd E
	sbi DDRB, 5 ; output
	sbi DDRB, 3 ; output
	; Port C
	sbi DDRC, 0 ; output
	sbi DDRC, 1 ; output
	sbi DDRC, 2 ; output
	sbi DDRC, 3 ; output
	; fan port
	sbi DDRD, 5 ; output

	; button interrupt setup
	ldi r26, 0b00000010 ; The falling edge of INT0 generates an interrupt request.
	sts EICRA, r26 ; External Interrupt Control Register A
	ldi r26, 0b00000001 ; enable external interrupt 0
	out EIMSK, r26 ; External Interrupt Mask Register

	; rpg interrupt setup
	lds r26, PCICR ; grab the Pin Change Interrupt Control Register
	ori r26, 0b00000001 ; enable Pin Change Interrupt Enable 0
	sts PCICR, r26 ; update Pin Change Interrupt Control Register
	lds r26, PCMSK0 ; grab the Pin Change Mask Register 0
	ori r26, 0b00000011 ; enable Pin Change Enable Mask 1 and 0
	sts PCMSK0, r26 ; grab the Pin Change Mask Register 0

	; initialie fan constant, fan boolean, and ascii_const
	ldi r26, 0x30
	mov ascii_const, r26

	; PWM for fan
	ldi r26, 0b00100011 ;configures timer to toggle OCR2B pin for PWM (found in datasheet)
	out TCCR0A,r26
	ldi r26,0b00001001 ;setup prescaler, also sets OCR2A to "overflow"
	out TCCR0B,r26
	ldi r26,199 ; sets the top value to 99
	out OCR0A,r26
	ldi r21,100 ; sets DC to 50, hence starts fan at 50%
	out OCR0B,r21
	sei ; enable interrupts

	;rcall delay_100ms ; 100 ms delay, MIGHT NOT NEED IT
	rcall LCD_initialize ; call initialize LCD
	;rjmp display_char

start:
ldi r20, 1
	; display "DC: XX%"
	ldi data, 0b00000010 ; cursor home
	rcall send_instruction
	rcall first_line
	ldi char, 0x44
	rcall display_char
	ldi char, 0x43
	rcall display_char
	ldi char, 0x3A

	rcall display_char
	ldi data,0b10000111
	rcall send_instruction
	ldi char, 0x25
	rcall display_char

	; display "Fan:" on second line
	rcall second_line
	ldi char, 0x46
	rcall display_char
	ldi char, 0x61
	rcall display_char
	ldi char, 0x6E
	rcall display_char
	ldi char, 0x3A
	rcall display_char
	rcall dc_location

	rcall fan_location
	ldi char, 0x59
	rcall display_char
	ldi char, 0x65
	rcall display_char
	ldi char, 0x73
	rcall display_char

main:
	rcall dc_location ;place cursor on the duty cycle value
	
	mov r0, r26 //store temp into 0
	ldi r26, 0
	cpse r20, r26 ;check if fan should be on or off. skips next if not equal (equal = skip = off)
	rjmp fanIsOn//
	mov r26, r0 //store back
	//if we are here, fan_boolean equals fan_constant, meaning the fan is off I think
	//hard code 00s
	rcall dc_location 
	ldi char, 0x30        ; Load ASCII '0'
	rcall display_char    ; Display upper digit (0)

	ldi char, 0x30        ; Load ASCII '0' again
	rcall display_char    ; Display lower digit (0)

	rjmp main

fanIsOn:
	mov r26, r0 //store back
	mov r26, r0
	;sts OCR2B, r21 ;if on, update pwm with the desired duty cycle (r21)
	out OCR0B,r21
	mov r26, r21
	lsr r21 
	;divide r21 by 10 to separate digits
	ldi divisor, 10
	mov dividend, r21
	;inc dividend
	rcall divide

	;display upper digit
	mov char, dividend
	add char, ascii_const
	rcall display_char

	;display lower digit
	mov char, remainder
	add char, ascii_const
	rcall display_char
	mov r21, r26 
	mov r26, r0
	mov r0, r26
	;if fan is on, display "Yes" on second line
	//cp fan_boolean, fan_const
	//breq display_yes
	rjmp main

;8-bit division algorithm, the quotient is stored in dividend and the remainder is stored in remainder
divide:
	ldi remainder, 0x00 ;clear remainder and carry flag
	clc
	ldi lc, 9
d1:
	rol dividend ;left shift dividend
	dec lc
	brne d2 ;if carry set, division is complete
	ret
d2:
	rol remainder ;shift dividend into remainder
	sub remainder, divisor
	brcc d3 ;if result is negative, restore remainder
	add remainder, divisor
	clc
	rjmp d1
d3:
	sec
	rjmp d1

display_char:
	

	sbi PORTB,5
	rcall delay_500us
	;
	sbi PORTB, 3
	;
	mov data, char
	swap data
	out PORTC, data ;send upper nibble
	rcall LCD_Strobe
	;
	sbi PORTB, 3
	;
	swap data
	out PORTC, data ;send lower nibble
	rcall LCD_Strobe
	ret

LCD_initialize: 
	; 8-bit mode
	rcall delay_100ms ; wait 100ms for LCD to power up
	rcall set_8bit_mode ; set device to 8-bit mode
	rcall delay_5ms ; wait 5 ms
	rcall set_8bit_mode ; set device to 8-bit mode
	rcall delay_500us ; wait at least 200us
	rcall set_8bit_mode ; set device to 8-bit mode
	rcall delay_500us ; wait at least 200us
	rcall set_4bit_mode ; set device to 4-bit mode
	rcall delay_5ms ; wait at least 5ms

	; 4-bit mode
	rcall set_interface
	rcall delay_5ms ; wait at least 5ms
	rcall enable_display
	rcall delay_5ms ; wait at least 5ms
	rcall clear_and_home
	rcall delay_5ms ; wait at least 5ms
	rcall set_cursor_direction
	rcall delay_5ms ; wait at least 5ms

	; turn on display
	ldi data, 0x00
	out PORTC, data
	rcall LCD_Strobe
	ldi data, 0x0C
	out PORTC, data
	rcall LCD_Strobe
	rcall delay_5ms ; wait at least 5ms
	ret

; strobe enable
LCD_strobe:
	sbi PORTB, 3
	rcall delay_250ns
	cbi PORTB, 3 ; sets E to 0
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Instructions for 8-bit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set_8bit_mode:
	cbi PORTB, 5 ; RS = 0
	ldi data, 0x03 ; 3 hex
	out PORTC, data ; writes out to PORTC (DB4-7)
	rcall LCD_strobe ; strobe enable
	ret

set_4bit_mode:
	ldi data, 0x02 ; 2 hex
	out PORTC, data ; writes out to PORTC (DB4-7)
	rcall LCD_strobe ; strobe enable
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Instructions for 4-bit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

send_instruction: ;general instruction, specific instruction subroutines call this to send data
	cbi PORTB,5
	rcall delay_500us

	;
	sbi PORTB, 3
	;
	swap data
	out PORTC, data ;send upper nibble
	rcall LCD_Strobe
	;
	sbi PORTB, 3
	;
	swap data
	out PORTC, data ;send lower nibble
	rcall LCD_Strobe
	rcall delay_100ms ;display extra time because some instructions require long delays
	ret

set_interface:
	ldi data, 0x28
	rcall send_instruction
	ret
enable_display:
	ldi data, 0b00001101
	rcall send_instruction
	ret
clear_and_home:
	ldi data, 0x01
	rcall send_instruction
	ldi data, 0b00000010 ;cursor home
	rcall send_instruction
	ret
set_cursor_direction:
	ldi data, 0x06
	rcall send_instruction
	ret

first_line:
	ldi data,0b10000000
	rcall send_instruction
	ret

second_line:
	ldi data,0b11000000
	rcall send_instruction
	ret

dc_location:
	ldi data,0b10000101
	rcall send_instruction
	ret

fan_location:
	ldi data,0b11000100
	rcall send_instruction
	ret

delay:
	; delay for 250ns
	; uses three nop abd one ret because each one is one cycle
	; and each cycle on an ATmega328P is 62.5ns (1/16MHz)
	delay_250ns:
		nop
		nop
		nop
		nop
		nop
		nop
		ret
	; delay for 100ms
	; uses the 500us delay to make an 100ms delay
	delay_100ms:
		ldi r27, 200
	delay_100ms_cont:
		cpi r27, 0
		rcall delay_500us
		dec r27
		brne delay_100ms_cont
		ret
	; delay for 5ms
	; uses the 500us delay to make an 5ms delay
	delay_5ms:
		ldi r27, 10
	delay_5ms_cont:
		cpi r27, 0
		rcall delay_500us
		dec r27
		brne delay_5ms_cont
		ret
	; delay for 500us, this is for the initialization, at least 200us
	; use timer counter 2 for LCD and timer counter 0 for WPM
	delay_500us:
		ldi r24, 0b00000011 ; Set prescaler to 32
		sts TCCR2B, r24
		ldi r24,6
		sts TCNT2, r24 ; Set timer count to 6

		in r31,TIFR2 ; tmp <-- TIFR0
		sbr r31,1<<TOV2 ; clears the overflow flag
		out TIFR2,r31
		wait:
			in r31,TIFR2 ; tmp <-- TIFR0
			sbrs r31,TOV2 ; Check overflow flag
			rjmp wait
			ret


DCupdate:
	rcall dc_location ;place cursor on the duty cycle value

	;sts OCR2B, r21 ;if on, update pwm with the desired duty cycle (r21)
	out OCR0B,r21
	mov r26, r21
	lsr r21 
	;divide r21 by 10 to separate digits
	ldi divisor, 10
	mov dividend, r21
	;inc dividend
	rcall divide
	rcall dc_location
	;display upper digit
	mov char, dividend
	add char, ascii_const
	rcall display_char

	;display lower digit
	mov char, remainder
	add char, ascii_const
	rcall display_char
	mov r21, r26 
	reti
	

button_interrupt:
	;rcall delay_5ms ; debounce delay

wait_int:
	;sbic PIND,2      ; Wait until button is pressed (low)
	;rjmp wait_int

	cpi r20, 1
	breq fan_off

; Turn fan ON
fan_on:
	;ldi fan_boolean, 0x0F
	ldi r20, 1
	out OCR0B, r21

	rcall fan_location
	ldi char, 0x59 ; 'Y'
	rcall display_char
	ldi char, 0x65 ; 'e'
	rcall display_char
	ldi char, 0x73 ; 's'
	rcall display_char
	rjmp end_button_interrupt

; Turn fan OFF
fan_off:
	;ldi fan_boolean, 0x00
	ldi r20, 0
	mov r27, r20
	out OCR0B, r27

	rcall fan_location
	ldi char, 0x4E ; 'N'
	rcall display_char
	ldi char, 0x6F ; 'o'
	rcall display_char
	ldi char, 0x20 ; clear last character spot
	rcall display_char
	rjmp end_button_interrupt

end_button_interrupt:
	sbic PIND, 2     ; wait for button to be released (high)
	rjmp end_button_interrupt
	rjmp real_end

real_end:
rcall dc_location
rcall delay_5ms
reti

rpg_interrupt:

	;ldi r26, 1
	;cpse r20, r26 ;check if fan should be on or off. skips next if not equal (equal = off)
	;rjmp end_rpg_interrupt 
	mov r0, r26 //store temp into 0
	ldi r26, 1
	cpse r20, r26 ;check if fan should be on or off. skips next if not equal (equal = off)
	rjmp end_rpg_interrupt
	mov r26, r0

in r29, PINB ; Read RPG signals
andi r29, (1 << 0) | (1 << 1) ; Keep only PD0 & PD1
cp r29, prev_state ; Compare with previous state
breq end_rpg_interrupt ; if no change exit ISR
; Only detect movement when PB0 (CH0) changes
sbrc prev_state, 0 ; If previous PB0 was 0, continue checking
sbrs r29, 0 ; If new PB0 is 1, this is a valid step
rjmp update_prev_state ; Otherwise, ignore transition
; Full Quad Decoding (Detect Clockwise or Counterclockwise)
sbrc r29, 1 ; If PB1 (CHB) is 1, CW detected
rjmp CCW
rjmp CW

update_prev_state:
	mov prev_state, r29
	rjmp end_rpg_interrupt

CCW:  ; Previously CW
	push r28
	ldi r28, 199 ; prevents incrementing past 99% duty cycle
	cpse r21, r28
	inc r21
	;ldi r21,10
	sts OCR0B,r21
	;cpse fan_boolean, fan_const
	;dec r21
	pop r28
	rjmp end_rpg_interrupt

CW:  ; Previously CCW
	push r28
	ldi r28, 0 ;prevents incrementing below 0% duty cycle
	cpse r21, r28
	dec r21
	;ldi r21,10 
	sts OCR0B,r21
	
	;cpse fan_boolean, fan_const
	;inc r21
	pop r28
	rjmp end_rpg_interrupt
end_rpg_interrupt:
	rcall delay_5ms ; delay 5ms
	mov r26, r0
	;sei
	;cbi PORTD, 0 tried to use for testing interrupt
	reti

	; for the fan


	/*
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
	*/