;
; 9032_project.asm
;
; Created: 2018/10/22 15:47:57
; Author : Ran Bai
; version Number: 1.0
; Function: design and achieve a cup & ball game in the AVR lab board
; Replace with your application code
;------------------------------------------------------------------------------------------------------------
;Board settings(Designed): 5 parts
;	1.LED:
;	Three LEDs which stand for cup: LED3-5---->PORTC(PC0-2, respectively)
;	Four LEDs for indicator: LED6-9---->PORTB(PB0-PB3, respectively)
;	2.KeyPad:
;	C2-C0---->PORTC(PC7-PC5, respectively)
;	    R0---->PORTC(PC4)
;	3.Motor:
;	Ope---->any +5v
;	Mot---->PORTC(PC3)
;	4.LCD:
;	LCD DATA:D0-D7----->PORTF(PF0-PF7, respectively)
;	LCD CTRL:BE---->PA4
;	          RW---->PA5
;	          E------->PA6
;	          RS----->PA7
;	5.Interrupt:
;		INT0---->PB0
;------------------------------------------------------------------------------------------------------------
.include"m2560def.inc"
.def tmp1 = r16             ; tmp2:tmp1 is 1 bytes of temp register, used for storing temporarily
.def tmp2 = r17             ;
.def random_number = r18    ; store random number generated by Timer0
.def status = r19           ; define the status2 and status3, 0xFF stand for ball is shuffled, status 2
                            ;                                 0x00 stand for ball stop shuffled, status 3
.def score = r20            ; store user score in the game
.def control = r21          ; define control to r21, used for debouncing
.def is_dimmed_light = r22  ; define is_dimmed_light to r22, used for determining whether output dimmed light
.def kb_input = r23         ; define kb_input to r23, used for storing the number of keypad input. 1/2/3
.def ball_shuffle = r2      ; define ball_shuffle to r2, used for control random number generate or not, 0x00:dont shuffle, 0xFF:shuffle
.def hundred = r26          ; used to store hundred digit of score
.def ten = r27              ; used to store ten digit of score
.def one = r28              ; used to store one digit of score

; control other 4 LED on and off 
.macro other_LED_off
     ldi tmp1, 0x00                     ; PORTB output all 0, LED6-9 off
	 out PORTB, tmp1
.endmacro
.macro other_LED_on
     ldi tmp1, 0xFF                     ; PORTB output all 1, LED6-9 on
	 out PORTB, tmp1
.endmacro

; copy PWM to 3 LED(display dimmed light)
.macro copy_dimmed_light
		sbic PING, 0                   ; skip if Pin0 of PING is 0
		sbi PORTC, 0                   ; set pin0 of PORTC to 1
		sbic PING, 0                   ; skip if Pin0 of PING is 0
		sbi PORTC, 1                   ; set pin1 of PORTC to 1
		sbic PING, 0                   ; skip if Pin0 of PING is 0
		sbi PORTC, 2                   ; set pin2 of PORTC to 1
		
		sbis PING, 0                   ; skip if Pin0 of PING is 1
		cbi PORTC, 0                   ; clear pin0 of PORTC to 0
		sbis PING, 0                   ; skip if Pin0 of PING is 1
		cbi PORTC, 1                   ; clear pin1 of PORTC to 0
		sbis PING, 0                   ; skip if Pin0 of PING is 1
		cbi PORTC, 2                   ; clear pin2 of PORTC to 0
.endmacro

; display score in the LCD
.macro  display_score
        mov tmp2, score                ; move score to tmp2
        clr hundred                    ; clear hundred, ten, one, these 3 registers
		clr ten                        ;
		clr one                        ;
        do_lcd_command 0b00000001      ;  ��score:�� is displayed on LCD;
		do_lcd_data 'S'
		do_lcd_data 'c'
		do_lcd_data 'o'
		do_lcd_data 'r'
		do_lcd_data 'e'
		do_lcd_data ':'
    is_hundred:
		cpi tmp2, 100                  ; compare tmp2 with 100
		brlo is_ten
		subi tmp2, 100                 ; tmp2 = tmp2 - 100; if tmp2 > 100
		ldi tmp1, 1   
		add hundred, tmp1              ; hundred = hundred + 1
		rjmp is_hundred
	is_ten:
	    cpi tmp2, 10                   ; compare tmp2 with 10
		brlo is_one
		subi tmp2, 10                  ; tmp2 = tmp2 - 10; if tmp2 > 10
		ldi tmp1, 1
		add ten, tmp1                  ; ten = ten + 1
		rjmp is_ten                    
	is_one:
	    mov one, tmp2                  ; the rest of one digits of score

	    ldi tmp1, '0'                   ; 
		add hundred, tmp1               ; hundred = hundred + '0', ASCII code of hundred
		add ten, tmp1                   ; ten = ten + '0', ASCII code of ten
		add one, tmp1                   ; one = one + '0', ASCII code of one

		do_lcd_data1 hundred            ; display hundred digits of score in the LCD
		do_lcd_data1 ten                ; display ten digits of score in the LCD
		do_lcd_data1 one                ; display one digits of score in the LCD
.endmacro

; read input from keypad
.macro read_kb
	read:
	    copy_dimmed_light                     ; copy dimmed light signal here
        sbi PORTC, 4                          ; set R0 to 1
		cbi PORTC, 5                          ; set C0 to 0, C1,C2 to 1
		sbi PORTC, 6                          ;
		sbi PORTC, 7                          ;
        ldi kb_input, 1                       ; load kb_input to 1

		ldi tmp1, 0xFF                        ; slow down the scan operation.
    delay1:                                   ;
	    dec tmp1                              ;
		brne delay1                           ;
		
		sbis PINC, 4                          ; determine if press '1', end loop
		rjmp convert

		copy_dimmed_light                     ; copy dimmed light signal here
		sbi PORTC, 4                          ; set R0 to 1
		sbi PORTC, 5                          ; set C1 to 0, C0,C2 to 1
		cbi PORTC, 6                          ;
		sbi PORTC, 7                          ;
		ldi kb_input, 2                       ; load kb_input to 2
		
		ldi tmp1, 0xFF                        ; slow down the scan operation.
    delay2:                                   ;
	    dec tmp1                              ;
		brne delay2                           ;

		sbis PINC, 4                          ; determine if press '2', end loop
		rjmp convert

		copy_dimmed_light                     ; copy dimmed light signal here
		sbi PORTC, 4                          ; set R0 to 1
		sbi PORTC, 5                          ; set C2 to 0, C0,C1 to 1
		sbi PORTC, 6                          ;
		cbi PORTC, 7                          ;
		ldi kb_input, 3                       ;

		ldi tmp1, 0xFF                        ; slow down the scan operation.
    delay3:                                   ;
	    dec tmp1                              ;
		brne delay3                           ;

		sbis PINC, 4                          ; determine if press '3', end loop
		rjmp convert
		jmp read
	convert:
.endmacro

; display the random number in the cup LED
.macro cup_led_display
		cpi random_number, 1             ; compare random_number with 1
		brne not_1
		sbi PORTC, 0                     ; random_number = 1 ---> LED2 on, LED0, LED1 off
		cbi PORTC, 1                     ;
		cbi PORTC, 2                     ;
		rjmp cup_end
	not_1:
		cpi random_number, 2             ; compare random_number with 2
		brne not_2
		cbi PORTC, 0                     ; random_number = 2 ---> LED1 on, LED0, LED2 off
		sbi PORTC, 1                     ;
		cbi PORTC, 2                     ;
		rjmp cup_end
	not_2:                               ; else random_number is 3
		cbi PORTC, 0                     ; random_number = 3 ---> LED0 on, LED1, LED2 off
		cbi PORTC, 1                     ;
		sbi PORTC, 2                     ;
	cup_end:
.endmacro

; LCD macro
.macro do_lcd_command                    ; do lcd command
	ldi tmp1, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data                       ; do lcd data
	ldi tmp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro do_lcd_data1                      ; do lcd data, but it can get data from a register
	mov tmp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.cseg
      jmp RESET                     ; Interrupt vector
.org  INT0addr
      jmp EXT_INT0
.org OVF0addr
	  jmp Timer0OVF

RESET:
    ; defined register initial
    ldi random_number, 1            ; initial random number, set to 1
    clr score                       ; score initial, clear to 0
	clr status                      ; status inital, clear to 0x00, status used to sign which status it is. 2 or 3
	                                ;                status2: status = 0xFF, status3: status = 0x00
    clr is_dimmed_light             ; is_dimmed_light = 0x00: dont display dimmed light
	                                ; is_dimmed_light = 0xFF: display dimmed light
    clr kb_input                    ; clear kb_input
	clr ball_shuffle                ; clear ball_shuffle
	

    ; LCD initial
	ldi tmp1, low(RAMEND)           ; RAMEND = 0x21FF, the bottom of stack
	out SPL, tmp1                   ; inital stack pointer, with SPH:SPL
	ldi tmp1, high(RAMEND)          ;
	out SPH, tmp1                   ;

	ser tmp1
	out DDRF, tmp1                  ; inital direction of PORT F
	out DDRA, tmp1                  ; inital direction of PORT A
	clr tmp1
	out PORTF, tmp1                 ; output 0x00 to PORTF
	out PORTA, tmp1                 ; output 0x00 to PORTA

	do_lcd_command 0b00111000		; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000		; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000		; 2x5x7
	do_lcd_command 0b00111000		; 2x5x7
	do_lcd_command 0b00001000		; display off
	do_lcd_command 0b00000001		; clear display
	do_lcd_command 0b00000110		; increment, no display shift
	do_lcd_command 0b00001110		; Cursor on, bar, no blink

	do_lcd_data 'R'                  ; 1 a. ��Ready���� is displayed on LCD
	do_lcd_data 'e'
	do_lcd_data 'a'
	do_lcd_data 'd'
	do_lcd_data 'y'
	do_lcd_data '.'
	do_lcd_data '.'
	do_lcd_data '.'
		
	; timer0 inital
	ldi tmp1, 0b00000000
	out TCCR0A, tmp1
	ldi tmp1, 0b00000001
	out TCCR0B, tmp1				; Prescaling value=64
	ldi tmp1, 1<<TOIE0				; =1024 microseconds
	sts TIMSK0, tmp1				; T/C0 interrupt enable

	; portG initial for dimmed_light
	clr tmp1
	out DDRG, tmp1                  ; set port G to input mode
	ser tmp1
	out PORTG, tmp1                 ; active pull-up resistor for input pin

	; INT0 interrupt initial
	ldi tmp1, (2 << ISC00)	        ; set INT0 as falling edge triggered interrupt
	sts EICRA, tmp1
	in tmp1, EIMSK		            ; enable INT0
	ori tmp1, (1<<INT0)
	out EIMSK, tmp1

	; Timer5 initial
	ldi tmp1, 0b00001000
    sts DDRL, tmp1                  ; Bit 3 will function as OC5A.

	clr tmp1
	sts OCR5AH, tmp1
	ldi tmp1, 0x2A
	sts OCR5AL, tmp1               ; the value controls the PWM duty cycle

	ldi tmp1, (1 << CS50)          ; set Timer5 to Phase Correct PWM mode
	sts TCCR5B, tmp1
	ldi tmp1, (1 << WGM50)|(1 << COM5A1)
	sts TCCR5A, tmp1

	; enable the global interrupt
	sei		

	; port C inital, include motor, cup LED, and keypad. 0-->input, 1-->output
	ldi tmp1, 0b11101111
	out DDRC, tmp1

	; other LED initial, all pin of B set to output mode
	ldi tmp1, 0xFF
	out DDRB, tmp1

	cup_led_display            ; 1 b.The cup LED with the ball is on
	jmp main                   ; jmp t o main

;-----------------------------------------Interrupt0-----------------------------------------------
EXT_INT0:
	    ; debouncing
		cpi control, 1                 ; debouncing operation
		breq can_next                  ;
		jmp through_interrupt          ; 
	can_next:
		com status                     ; switch status between 2 and 3 
		cpi status, 0xFF               ; compare status 
		brne status_3                  ; if flag==0xFF, go to status 2, else status 3
		jmp status_2
	status_3:                          ; status3
			clr ball_shuffle               ; clear ball_shuffle, ball stop shuffle
			do_lcd_command 0b00000001      ; 3 a. ��guess���� is displayed on LCD;
			do_lcd_data 'G'                ;
			do_lcd_data 'u'                ;
			do_lcd_data 'e'                ;
			do_lcd_data 's'                ; 
			do_lcd_data 's'                ;
			do_lcd_data '.'                ;
			do_lcd_data '.'                ;
			do_lcd_data '.'                ;
			cbi PORTC, 3                   ; 3 a. The motor stops;
										   ; 3 b. The three cup LEDs remain dimmed
			read_kb                        ; read input from keypad
			clr is_dimmed_light            ; stop display dimmed light
			cup_led_display                ; display correspond cup led
            
			cp random_number, kb_input     ; compare random_number with keypad input
			breq correct                   ; if equal, jump to correct, else incorrect
			rjmp incorrect                 ;
		correct:                           ; operations when guess is correct
		    inc score                      ; 3 c ii. the score on the LCD is incremented by 1
            display_score                  ; display score in the LCD

			other_LED_on                   ; 3 c ii. the indicator will flash a few times
			rcall sleep_150ms              ; delay
			other_LED_off                  ; off
			rcall sleep_150ms              ; delay
			other_LED_on                   ; on
			rcall sleep_150ms              ; delay
			other_LED_off                  ; off
			rcall sleep_150ms              ; delay
			other_LED_on                   ; on
			rcall sleep_150ms              ; delay
			other_LED_off                  ; off
			rcall sleep_150ms              ; delay
			rjmp end_interrupt
		incorrect:                         ; operations when guess is incorrect
		    cpi score, 1                   ; compare score with 1
			breq re_start                  ; if in incorrect situation, decrease from 1 or 0, game over
			brlo re_start                  ; 
		    dec score                      ;
			display_score                  ; display score in the LCD
			rjmp end_interrupt
		re_start:
		    jmp game_over                  ; jump to game_over

	status_2:                              ; status2
	        rcall sleep_150ms
			rcall sleep_150ms
			ldi tmp1, 0xFF
			mov ball_shuffle, tmp1         ; ball start shuffle
			do_lcd_command 0b00000001      ; 2 a. ��Start ���� is displayed on LCD;
			do_lcd_data 'S'
			do_lcd_data 't'
			do_lcd_data 'a'
			do_lcd_data 'r'
			do_lcd_data 't'
			do_lcd_data '.'
			do_lcd_data '.'
			do_lcd_data '.'

			sbi PORTC, 3                  ; 2 b. Motor spins;

			ldi is_dimmed_light, 0xFF     ; 2 c. Three cup LEDs are all on, but in dimmed light; other LEDs remain off
		end_interrupt:
			clr control                   ; clear control
		through_interrupt:
			reti                          ; end interrupt and return

	game_over:                                ; game over
		do_lcd_command 0b00000001             ; display "GAME OVER!"
		do_lcd_data	'G'                       ;
		do_lcd_data	'A'                       ;
		do_lcd_data	'M'                       ;
		do_lcd_data	'E'                       ;
		do_lcd_data	' '                       ;
		do_lcd_data	'O'                       ;
		do_lcd_data	'V'                       ;
		do_lcd_data	'E'                       ;
		do_lcd_data	'R'                       ;
		do_lcd_data	'!'                       ; 
		rcall sleep_1s                        ; sleep 1s
		clr control                           ; clear control
		jmp	RESET                             ; jump to RESET, restart game

;-----------------------------------------------Timer0---------------------------------------------------
Timer0OVF:                         ; Timer0 used to generate random_number(1ms)
        ldi tmp1, 0xFF
		cp tmp1, ball_shuffle      ; ball shuffling
		brne end_timer0
		inc random_number          ; random_number = randoom_number + 1
		cpi random_number, 4       ; random_number can not large than 3
		brne end_timer0
		ldi random_number, 1       ; load random_number with 1
	end_timer0:
	    ldi tmp1, 0xFF
		cp is_dimmed_light, tmp1   ; determing if show dimmed light in the cup LCD
		brne not_dimmed
							       ; status 2/3, if status 3, press keypad and jump out loop
		copy_dimmed_light
	not_dimmed:
		reti
;----------------------------------------------main---------------------------------------------------
main:   
        ; Debouncing
		cpi control, 1                ; control == 1, have permission to do something in the Interrupt0
		breq continue                 ; control == 1, continue
		rcall sleep_150ms             ; if control != 1, should wait 150ms, and give back permission
		ldi control, 1                ; load control with 1
    continue:
		rjmp main

;------------------------------------------------LCD----------------------------------------------------
; LCD macro
.equ LCD_RS = 7                   ; define LCD_RS to 7
.equ LCD_E = 6                    ; define LCD_E to 6
.equ LCD_RW = 5                   ; define LCD_RW to 5
.equ LCD_BE = 4                   ; define LCD_BE to 4

.macro lcd_set                    ; one pin of lcd control set to 1
	sbi PORTA, @0
.endmacro
.macro lcd_clr                    ; one pin of lcd control clear to 0
	cbi PORTA, @0
.endmacro
;
; Send a command to the LCD (tmp1)
;
lcd_command:                      ; do lcd command, write command to IR
	out PORTF, tmp1
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:                        ; do lcd data, write data to DR(Data Register)
	out PORTF, tmp1
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:                         ; lcd wait, until correct operation
	push tmp1
	clr tmp1
	out DDRF, tmp1
	out PORTF, tmp1
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
        nop
	in tmp1, PINF
	lcd_clr LCD_E
	sbrc tmp1, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser tmp1
	out DDRF, tmp1
	pop tmp1
	ret

;---------------------------------------------Delay---------------------------------------------------------------
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
sleep_1ms:                                    ; sleep 1ms
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:                                    ; 5ms = 5*1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	ret

sleep_30ms:                                   ; 30ms = 6*5ms
    rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	ret

sleep_150ms:                                  ; 150ms = 5*30ms
    rcall sleep_30ms                          ; 30ms 
	rcall sleep_30ms                          ; 30ms
	rcall sleep_30ms                          ; 30ms
	rcall sleep_30ms                          ; 30ms
	rcall sleep_30ms                          ; 30ms
	ret
sleep_1s:                                     ; 1s = 6*150ms + 3*30ms + 2*5ms
    rcall sleep_150ms                         ; 150ms
	rcall sleep_150ms                         ; 150ms
	rcall sleep_150ms                         ; 150ms
	rcall sleep_150ms                         ; 150ms
	rcall sleep_150ms                         ; 150ms
	rcall sleep_150ms                         ; 150ms
	rcall sleep_30ms                          ; 30ms
	rcall sleep_30ms                          ; 30ms
	rcall sleep_30ms                          ; 30ms
	rcall sleep_5ms                           ; 5ms
	rcall sleep_5ms                           ; 5ms
	ret