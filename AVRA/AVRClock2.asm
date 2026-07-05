;;;***********************************************************************
;;;*  AVR Digital Clock in the Mirror World                              *
;;;* 								         *
;;;*  File Name            :"AVRClock2.asm"                              *
;;;*  Title                :AVR Clock 2 Source                           *
;;;*  Date (Start)         :25May2022                                    *
;;;*  		                                                         *
;;;*  Version              :2.2dev (28 jun 2026)                         *
;;;*  Target MCUs          :ATmega48-88-168-328                          *
;;;*                                                                     *
;;;* DESCRIPTION                                                         *
;;;*     Ver 2.0dev  ; 5 May 2022: Start Development                     *
;;;*     Ver 2.2     ; 1 Jun 2026: For new JLCPCB Board-1/		 *
;;;*		  		    Slight pin changes        		 *
;;;***********************************************************************
		.NOLIST
		;;  Makefile replaces m88Pdef.inc to an appropriate .inc file.
		.include "m88Pdef.inc"
		;; .include "m48def.inc"
                ;; .include "m88PAdef.inc"
                ;; .include "m328def.inc"

		.LIST   
		;;	 ***** Global Register Variables
		.def    NULL 	=r14	                  ; Always 0 
		.def    SR	=r15                              ; Used for Status Register Escape
		.def    A	=r16                              ; Local use/input/output 	
		.def    B	=r17                              ; Local use
		.def    C	=r18                              ; Used for LED Brightness
		.def    D	=r19                              ; Local use
		.def    E	=r20                              ; Local use
		.def    F	=r21   	                          ; Used for Ambient brightness	
		.def    ADJ	=r22  				  ; ADJUSTMENT FLAGs 
	;;	** Use the following Registers to Store Current Hour/Packed BCD
		.def    HH	=r23
		.def    MM	=r24
		.def    SS	=r25
	;;	*** Brightness adjustment. Adjust for your system (LED, Photoresitor properties)
	;;	ADCH value is divided by 4 to sADC=0--63. LED faintest if sADC<=FA_LIM, Brightest (full duty)
	;;	if sADC>FA_LIM+BR_LIM. In general, BR_LIM<63-FA_LIM to attain full LED brightness at the bright
	;;	ambient light, but logically it accepts up to 255. LED duty cylce is approximately (sADC-FA_LIM+1)/BR_LIM
	;;	(sADC>=FA_LIM) or 1/BR_LIM (sADC<=FA_LIM).
		.equ	BR_LIM	= 50 	                          ; Bright limit,above which duty=full
		.equ	FA_LIM	= 10	                          ; Faint limit, below which duty=1
	;; Multiplexer channel definitions on PORTB
		.equ	S0	= 5	                          ; MUX Channel 6 = Sec lower digit
		.equ	S1	= 4	                          ; MUX Channel 5 = Sec highr digit
		.equ	M0	= 3	                          ; MUX Channel 4 = Min lower digit
		.equ	M1	= 2	                          ; MUX Channel 3 = Min highr digit
		.equ	H0	= 1	                          ; MUX Channel 2 = Hr  lower digit
		.equ	H1	= 0	                          ; MUX Channel 1 = Hr  highr digit
								  ; MUX Channel 0 = Not used
	;; Switch and sensor pin definitions on PINC
		.equ	PWOUT	= 0	                          ; Power Outage detetction LOW is power-out (Batt Operated)
		.equ	FWBTN	= 3	                          ; Forward button pin 
		.equ	MDBTN	= 2	                          ; Mode button pin
		.equ	BWBTN	= 1	                          ; Backward button pin
		.equ	TILT	= 5	                          ; Tilt Switch
	
		.CSEG   
                                                  ;********** 	Interupt Vector	**********
		.org    0x000
			rjmp    RESET		                  ;Reset Handle
		.org    INT0addr                             ;=$001	External Interrupt0
			reti    
		.org    INT1addr                             ;=$002	External Interrupt1
			reti    
		.org    PCI0addr                             ;=$003	Pin Change Interrupt0
			reti    
		.org    PCI1addr                             ;=$004	Pin Change Interrupt1
			reti    
		.org    PCI2addr                             ;=$005	Pin Change Interrupt2
			reti    
		.org    WDTaddr	                             ;=$006	Watchdog Timeout
			reti
		.org    OC2Aaddr                             ;=$007	Timer/Counter2 Compare Match Interrupt
			rjmp    ADV_SEC	 	                  ; Timer 2 Overflow every second
		.org    OC2Baddr                             ;=$008	Timer/Counter2 Compare Match Interrupt	
			reti    
		.org    OVF2addr                             ;=$009	Overflow2 Interrupt
			reti    
		.org    ICP1addr                             ;=$00a	Input Capture1 Interrupt 	
			reti    
		.org    OC1Aaddr                             ;=$00b	Output Compare1A Interrupt 
			reti    
		.org    OC1Baddr                             ;=$00c	Output Compare1B Interrupt 
			reti    
		.org    OVF1addr                             ;=$00d	Overflow1 Interrupt 
			reti    
		.org    OC0Aaddr                             ;=$00e	Timer/Counter0 Compare Match Interrupt
			reti    
		.org    OC0Baddr                             ;=$00f	Timer/Counter0 Compare Match Interrupt	
			reti    
		.org    OVF0addr                             ;=$010	Overflow0 Interrupt
			reti    
		.org    SPIaddr                              ;=$011	SPI Interrupt 	
			reti    
		.org    URXCaddr                             ;=$012	USART Receive Complete Interrupt 
			reti    
		.org    UDREaddr                             ;=$013	USART Data Register Empty Interrupt 
			reti    
		.org    UTXCaddr                             ;=$014	USART Transmit Complete Interrupt 
			reti    
		.org    ADCCaddr                             ;=$015	ADC Conversion Complete Handle
			reti
			;;rjmp    SET_BRIGHT
		.org    ERDYaddr                             ;=$016	EEPROM write complete
			reti    
		.org    ACIaddr	                          ;=$017	Analog Comparator Interrupt 
			reti    
		.org    TWIaddr                              ;=$018	TWI Interrupt Vector Address
			reti    
		.org    SPMRaddr                             ;=$019	Store Program Memory Ready Interrupt 
			reti    
     ;;;
     ;;;	**********		Main Program Starts Here  ********
     ;;
;
RESET:
		cli					  ; Global Interupt disable	
		clr     NULL
		ldi     A,	low(RAMEND)		  ; Load low byte address of end of RAM 
		out     SPL,	A		          ; Initialize stack pointer to end of internal RAM
		ldi     A,	high(RAMEND)		  ; Load high byte address of end of RAM 
		out     SPH, 	A			  ; Initialize high byte 
;;;
;;; Setting Modes
;;; 
		;; Shut Down Unnecessary Modules for power reduction
		ldi	A,	(1<<PRUSART0)		; keep SPI/UART and ADC is on
		sts	PRR,	A
		;;	Main Clock 8MHz Internal Oscillator by Fuse Bit Setting
		;;	No pre-scaler. Operate at 8MHz, to avoid looking flickerd with dimmness control. 
		;;	External 128 kHz (12.8Mz Crystal reduce freq by 100 using 74HC390)  			
		;;	First CLKPR7=CLKPCE is enabled with all other bits 0
		;; 	Then within 4 clock cycles, CLKPS0..3 must be written (and CLPCE Cleared)
		ldi	A, 	1<<CLKPCE
		sts	CLKPR, A			; Prescaler Enable
		ldi	A,  	0; (1<<CLKPS0)	Prescaler=1
		sts	CLKPR, A		
		;;
		;;	Configure Input Pins
		;;
		;;   PC0-Externally Pulled Down, Power Outage detection	
		;;   PC3-Pullup  : Upper Botton  Adjust Up (normal) Down (mirrored)/Enforce Wake  
		;;   PC2-Pullup  : Middle Button  Mode Display -push_1sec ->Hr Adj ->Min Adj->Display
		;;   PC1-Pullup  : Lower Botton  Adjust Down (normal) Up (mirrored)/Enforce Wake
		;;
		;;   PC5-Pullup  : Tilt Detector  
		;;
		ldi	A, 	0b00000000	
		out	DDRC, A
		ldi	A,	0b00101110	 
		out	PORTC, A
		nop
		;;   PC4-ADC4    : Brightness Detector Configure as ADC
		clr	A
		ldi	A,	(1<<ADC4D) ; Disabe digital input for ADC 4 
		sts	DIDR0, A		
		ldi	A, 	(1<<REFS0)|(1<<MUX2)|(1<<ADLAR) ;Use AVCC as ref. Select ADC4 (MUX3..0=0100), Result left adj.
		sts	ADMUX, A
		ldi	A,	(1<<ADEN)|(1<<ADIE)|(1<<ADPS1) ;ADC Enable/ADC Interrupt Enable/Prescaler 4
		sts	ADCSRA, A
		;;
		;;	*****   Output Pin Configuration  **** 
		;;   	PD0-7: Output Pin ... 7 Seg
		;;   	PB0-5: Output Pin ... 6 digit Multiplexer
		;;	
		ldi	A,	0xFF
		out	DDRD, 	A	
		ldi	A,	0b00111111
		out	DDRB,	A	
		clr	A
		;out	PORTD,	A
		;out	PORTB,	A	
		;;
		;;	Timer/Counter 0 Setup.. Use for waiting/PreScale System Clock (1000 kHz) 
		;;	by 1024 (1.024 ms), Normal Mode, No interupt
		;;	
		clr	A
		out	TCCR0A,	A		; Normal Opertaion
		sts	TIMSK0,	A		; No Interupt
		ldi	A,	(1<<CS02)|(1<<CS00)	
		out	TCCR0B,	A		; Select clk_{IO}/1024 pre-scaler			
		;;	
		;; 	Timer/Counter 2 Clock -- Interupt Operated Real Time Clock--- Option Setting
		;;	
		ldi	A,	(1<<WGM21)
		sts	TCCR2A, A		; CTC Operation of Timer 2			
		ldi	A,	(1<<CS22)|(1<<CS21)|(1<<CS20)		 
		sts	TCCR2B,	A		; Select  clk_{T2S}/1024 prescaler Clock2->125 Hz	
		ldi 	A, 	(1<<EXCLK)
		sts	ASSR,	A		; Use external as timer2 source
		ori	A,	(1<<AS2)
		sts	ASSR,	A		; Use external as timer2 source
		ldi	A, 	124
		sts	OCR2A,	A 	; Output comoare match A=124 (interupt when the registor=124)
wait_sync:	lds	A,	ASSR
		andi    A,	0b00011111  	; See if any updates are busy
		brne	wait_sync		; Wait for all busy signals to be cleared
		ldi	F,	BR_LIM		; Ambient brightness initial value
		ldi	C,	BR_LIM		; LED Brightness initial value
		;;	Enable Timer2 Overflow Interupt
		ldi	A,	(1<<OCIE2A)	; Timer2 Compare Match 	
		sts	TIMSK2,	A		; mask set
		sei				; Global Interupt enable			
		clr	HH		
		clr	MM
		;
		clr	SS
		ldi	SS,	0x01
		clr	ADJ
		;;rcall	HOUR_SET			; Start With hour set Mode	
wait_inp:	sbis	PINC,	PWOUT       	
		rcall	BATT_OP			; Check Power Outage Line
		rcall	SET_BRIGHT		; Set brightness if the conversion is done.
		rcall	START_BRIGHT		; Start ADC to measure ambient brightness if the previous conversion is done.
		sbis	PINC,	MDBTN		; Mode button/long push (in sub TIME_SET) enters time set mode 
		rcall	TIME_SET
 		sbis	PINC,	BWBTN
		rcall	BRIGHT_DISP		; Show brightness while FWD button is pushed
		sbis	PINC,	FWBTN		; Check LED while BWD button is pushed
		rcall	LEDTEST
		in	A,	PINC		
		andi	A,	(1<<MDBTN)|(1<<FWBTN)|(1<<BWBTN) ; if any buttons is 0 (pushed)
		cpi	A,	(1<<MDBTN)|(1<<FWBTN)|(1<<BWBTN)
		brne	wait_inp		; skip time display
		rcall	TIME_DISP		;Time display	
		rjmp	wait_inp

;;;
;;;	End of Main Routine
;;;

ADV_SEC:	; Timer2 Compare Match interupt handling every sec.
		;rcall	LEDTEST		; Check if interrupt is working
		;reti
		in	SR,	SREG	;Keep Status
		push	A
		push 	B
		ldi	B, 	0x60	;Advance Clock by one second/8-bit Timer2 interupt
		mov	A, 	SS	
		rcall	INC_BCD		;Increase Packed BCD min/or sec with carry
		mov	SS,	A 	
		brcc	end_adv
		ldi	B,	0x60
		mov	A,	MM
		rcall	INC_BCD
		mov	MM,	A
		brcc	end_adv
hr_set:		mov	A,	HH
		ldi	B,	0x24
		rcall	INC_BCD
		mov	HH,	A	
end_adv:	clc                     ;Clear Carry
		pop	B
 		pop	A	
		out	SREG,	SR ; Restore Status Register
		reti
;;;
	
INC_BCD:		; increase A-reg with Packed BCD by 1/ reset w carry if B is reached	
		push	D
		inc	A			
		mov	D,	A
		andi	D,	0x0F    	;Take Lower Nibbles
		subi	D,	0x0A		;If Lower Nibbles<10	
		brne	no_carry1		;Skip to no_carry1
		subi	A,	-0x10		;Add 1 to upper digit
		andi	A,	0xF0		;Lower Digit is now 0
no_carry1:	clc				;clear carry by default
 		push	B
		sub	B,	A		;Reached Pre-defined B (0x60 or 0x24)?
		pop	B
		brne	no_carry2		;
		clr	A			;It is now zero 
		sec				;Give Carry to calling routine if A=B				
no_carry2:	pop	D
 		ret
; 			
	
DEC_BCD:	;decrease A-reg with Packed BCD, if A=0, return B(0x24 or 0x60)-1			
		push	C
		push	D	
		subi	A,	0			; If A is currently 0, Give Back PBCD B-1
		brne	dec_bcd1
		mov	A,	B
IFR0:		dec	A				;B-1 -> PBCD	
		mov	D,	A			;If lower nibble is F, give 9 and finish.	
		andi	D,	0x0F			;	
		subi	D,	0x0F			;
		brne	dec_done		;
		andi	A,	0xF0		;
		ori	A,	0x09	
		rjmp	dec_done
dec_bcd1:	mov	C,	A
 		mov	D,	A
		swap	D
		andi	D,	0x0F		;D is Upper Nibble	
		andi	C,	0x0F    	;C is Lower Nibble	
		subi	C,	1		;Decrement with carry
		brcc	no_carry3
		ldi	C,	0x09		;Lower Digit is now 9
		dec	D		
no_carry3:	swap	D			; Lower Nibble=C,Upper Nibble =D
 		or	D,	C
		mov	A,	D				
dec_done:	pop	D
 		pop	C
 		ret	
;
;	******* 	Subroutine for TIME SET  	******
;
				
TIME_SET:
		rcall   RST_TIM0	; Reset Timer0
		ldi	B,	8		; 2 sec push will enter HOUR_SET Mode
push_1s:	rcall	TIME_DISP		; TIME_DISP  					
		sbic	PINC,	MDBTN 	; Return if released before ~2s 
		ret		
		sbis	TIFR0,	TOV0	; If timer0 overflows, go, otherwise loop.		
		rjmp	push_1s
		rcall	RST_TIM0		
		dec	B		; Repeat timer0 overflow B times
		brne	push_1s

		; Wait for button release	
wait_rel:	ori	ADJ,	0b100	;Set Hour ADJ mode (set bit2) 
		rcall	TIME_DISP
  		sbis	PINC,	MDBTN
  		rjmp	wait_rel		

HOUR_SET:	push	A
		push	B
		ldi	B,	0x24	; Cycle at 24 Hr upon inc/dec		
		rcall	TIME_DISP
		rcall	RST_TIM0	; E is set to 100 (approx 1xE sec timeout)
hr_loop:	mov	A,	HH
		sbis	PINC, 	FWBTN	
		rcall	PUSH_UP	
		sbis	PINC,	BWBTN
		rcall	PUSH_DOWN
		mov	HH,	A	
		rcall	TIME_DISP
		sbis	TIFR0,	TOV0	; If timer overflows, dec E, otherwise next
		rjmp	hr_skip
		sbi	TIFR0,	TOV0
		dec 	E
		brne	hr_skip
		sbis	PINC,	PWOUT	; If Timer out and Battery_op mode, exit the Time Set Mode
		rjmp	exit_tset
hr_skip:	sbic	PINC,	MDBTN
		rjmp	hr_loop
wait_rel_hm:	sbis	PINC,	MDBTN		; Wait mode button release
		rjmp	wait_rel_hm
		rcall	WAIT_DISP
		;; From Here, Minute adjstment mode
		andi	ADJ,	0b11111011	; Hour Adjust flag clear
		ori	ADJ,	0b00000010	; Min  Adjust flag set	
		ldi	B,	0x60		; Cycle at 60 min upon inc/dec	
		rcall	RST_TIM0		; Rest Timer0 for Timeout on Batt_op				
min_loop:	mov	A,	MM
		sbis	PINC, 	FWBTN	
		rcall	PUSH_UP_SC	
		sbis	PINC,	BWBTN
		rcall	PUSH_DOWN_SC
		mov	MM,	A
		rcall	TIME_DISP
		sbis	TIFR0,	TOV0	; If timer overflows, reset, decE, otherwise next
		rjmp	min_skip
		sbi	TIFR0,	TOV0
		dec 	E
		brne	min_skip
		sbis	PINC,	PWOUT	; If Timer out and Battery_op mode, exit the Time Set Mode
		rjmp	exit_tset
min_skip:	sbic	PINC,	MDBTN
		rjmp	min_loop
wait_rel_mm:	sbis	PINC,	MDBTN
		rjmp	wait_rel_mm

exit_tset:	andi	ADJ,	0b11111001	; Min/Hr Adjust flag clear		
 		pop	B
		pop	A
		ret

PUSH_UP_SC:     clr	SS              ; Set 0 sec.
		sts	TCNT2,	SS		
PUSH_UP:	rcall	RST_TIM0	; Batt Op. Timeout Extend when botton is pushed
		sbis	PINC,	FWBTN	; Wait for forward  button release
		rjmp	PUSH_UP		
		sbic	PINC,	TILT  ; normal
		rjmp	upsdn1
		rcall	INC_BCD
		clc
		rjmp	wd1
upsdn1:		rcall	DEC_BCD         ;Upside down
		clc		
wd1:		rcall 	WAIT_DISP       ;Chattering prevention. Momentarily suppress next button push. 
		ret	

PUSH_DOWN_SC:	clr	SS
		sts	TCNT2,	SS		
PUSH_DOWN:      rcall	RST_TIM0	; Timeout Extend when botton is pushed
		sbis	PINC,	BWBTN	; Wait for backward button release
		rjmp	PUSH_DOWN		
		sbic	PINC,	TILT  	; Tilt_sensor=normal
		rjmp	upsdn2
		rcall	DEC_BCD
		clc
		rjmp	wd2
upsdn2:		rcall	INC_BCD
		clc
wd2:		rcall	WAIT_DISP	;Chattering prevention. Momentarily suppress next button push. 
		ret
		
RST_TIM0:
		sbi	TIFR0,	TOV0   	; Reset Timer0 -Clear Overflow flag by writing "1"
		out	TCNT0,	NULL
		ldi	E,	100	; about 20-sec timeout. Use if battery operated.
		ret	

WAIT_DISP:      push	B               ; WAIT WHILE DISPLAYING TIME. For Chattering prevention. 
		ldi	B,	50	; Wait about ~0.08 sec with time display	
disp_loop:	rcall	TIME_DISP
  		dec	B
		brne	disp_loop
		pop 	B
		ret					
;;
;;	*******		Subroutine for TIME DISP	******	
;;
		
LD_7SEG:	;Obtain 7 segment pattern data address XH, XL for normal or mirrored
		ldi	XL,	low(SEGM_NO<<1)
		ldi	XH,	high(SEGM_NO<<1)
		in	A, 	PINC							
		andi	A,	(1<<TILT)	; See Port PC5 (Tilt Switch)  to decide Normal(0) or Mirrored (1)
		breq	skip_mirror
		ldi	XL,	low(SEGM_MR<<1)
		ldi	XH,	high(SEGM_MR<<1)
skip_mirror:	ret
	
;   DISPLAY 

TIME_DISP:
		push	A
		rcall	LD_7SEG			; read tilt SW and get 7 segment+dot pattern for normal or mirrored.
		ldi	A,	0xFF
		rcall 	DUTY_C
		rcall 	DUTY_C
		;;	---- Display Seconds	----										
		mov	A,	SS						
		rcall	SET_7SEG
		sbi	PORTB,  S0		;On: Multiplexer 0: SS low
		rcall 	DUTY_C						
		cbi	PORTB, 	S0		;Off: Clear Multiplexer 0: SS low
		mov	A,	SS
		swap	A			;for higher nibble
		rcall	SET_7SEG
		cbi	PORTD, 	7		;Display Colon-connected to SEG7,MUX5	
		sbi	PORTB, 	S1		;On: Multiplexer 5: SS high
		rcall 	DUTY_C
		cbi	PORTB,	S1 		;Off: Multiplexer 5: SS high
		;;	---- Display Minutes	----
		mov	A,	MM
		rcall	SET_7SEG		
		sbi	PORTB,	M0		;On: Multiplexer 4: MM low
		sbrc	ADJ, 1			;If minute adjust mode, show blinking dot.
		rcall	BLINK_P			;If time adjustment flag ADJ.1 (Min adj), blink dot
		rcall	DUTY_C									
		cbi	PORTB,	M0		;Off: Multiplexer 4: MM low
		mov	A,	MM
		swap	A			;for higher nibble
		rcall	SET_7SEG
		sbi	PORTB,	M1		;On: Multiplexer-- MM low
		sbrc	ADJ, 1			;If minute adjust mode, show blinking dot.
		rcall	BLINK_P			;If time adjustment flag ADJ.1 (Min adj), blink dot
		rcall 	DUTY_C
		cbi	PORTB,	M1		;Off: Multiplexer-- MM low
		;;	---- Display Hours	-----		
		mov	A,	HH		;
		rcall	SET_7SEG		;
		sbi	PORTB,	H0		;On: Multiplexer-- HH low
		sbrc	ADJ,	2
		rcall	BLINK_P	
		rcall	DUTY_C
		cbi	PORTB,	H0		;Off: Multiplexer-HH low							
		mov	A,	HH
		swap	A				;for higher nibble
		rcall	SET_7SEG
		andi	A,	0x0F		;If zero, do not display
		breq	skip_hdis
		sbi	PORTB,	H1		;On: Multiplexer 1: HH high
		sbrc	ADJ,	2
		rcall	BLINK_P
		rcall 	DUTY_C
		cbi	PORTB,	H1 		;Off: Multiplexer 1: HH high
skip_hdis:	pop	A
		ret
												
SET_7SEG:
		push 	A
		andi	A,	0x0F	;Only use lower nibble
		movw	ZL,	XL	
		add	ZL,	A
		adc	ZH,	NULL	;Carries to ZH
		lpm	A,      Z       ;Load Segment Pattern from (Z) to A					
		out	PORTD,	A
		pop	A	
		ret

BLINK_P:	;Read Timer2 register/cycles 0-255 every 1 sec
		lds	A,	TCNT2
		sbrc	A,	4		;On-off switch every 1/8 sec
		cbi	PORTD,	7		;Turn on dot LED.
		ret	
	
LEDTEST:  	;LED Check all 8 and dots are on
		pop	A
		clr	A		; All LED on (LOW)
		cbi	PORTB,	S0
		out	PORTD,	A
		sbi	PORTB, 	S0	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	S0
		out	PORTD,	A
		sbi	PORTB,  S1	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	S1
		out	PORTD,	A
		sbi	PORTB,  M0	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	M0
		out	PORTD,	A
		sbi	PORTB,  M1	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	M1
		out	PORTD,	A
		sbi	PORTB,  H0	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	H0
		out	PORTD,	A
		sbi	PORTB,  H1	; Go through MUX
		rcall	DUTY_C
		cbi	PORTB,	H1
		push	A
		ret

BRIGHT_DISP:	; Brightness display
		rcall	LD_7SEG		; 7 segment pattern normal or mirrored dep. tilt sw.
		;; Show ambient brightness in SS digits.
		mov	A,	F	; Ambient brightness 	
		rcall 	BIN2BCD8	; To BCD 8 bit
		rcall	SET_7SEG	; A to BCD code
		sbi	PORTB,	S0
		rcall	DUTY_C
		cbi	PORTB,	S0
		swap	A
		rcall	SET_7SEG
		sbi	PORTB,	S1
		rcall	DUTY_C
		cbi	PORTB,	S1
		;; show LED brightness in MM digits.
		mov	A,	C	; LED brightness 	
		rcall 	BIN2BCD8	; To BCD 8 bit
		rcall	SET_7SEG
		sbi	PORTB,	M0
		rcall	DUTY_C
		cbi	PORTB,	M0
		swap	A
		rcall	SET_7SEG
		sbi	PORTB,	M1
		rcall	DUTY_C
		cbi	PORTB,	M1
		;; Show "br" in HH digits.
		ldi	A,	0b10000011 ; "b"
	 	sbic	PINC,	TILT	
		ldi	A,	0b10001100 ; Mirrored "b"
		out	PORTD,	A
		sbi	PORTB,	H1
		rcall	DUTY_C
		cbi	PORTB,	H1
		;; 
		ldi	A,	0b10101111 ; "r"
	 	sbic	PINC,	TILT	
		ldi	A,	0b10011111 ; Mirrored "r"
		out	PORTD,  A
		sbi	PORTB,	H0
		rcall	DUTY_C
		cbi	PORTB,	H0
		ret
;;; 
;;;	*******		Subroutine BATT	******
;;;		Battery Operated Mode

BATT_OP:
		ldi	A,	0b0111
		out	SMCR,	A 	; Sleep Enable with Power-save Mode
sleep1:		sbic	PINC,	0	; Out of Sleep Mode if Power is back
		rjmp	wake_up	
		sbis	PINC,	MDBTN	; Time_Set ModeXW
		rcall	TIME_SET
		sbis	PINC,	FWBTN	; During Up/Down button is pushed, display				
		rjmp	batt_disp	; even	in the battery operated mode	
		sbis	PINC,	BWBTN
		rjmp	batt_disp
		sleep				; Go to sleep/Wake up by Timer2 overflow every second
		rjmp	sleep1
batt_disp:	rcall	TIME_DISP
	 	rjmp	sleep1
wake_up:	ldi	A,	0b0110
	   	out	SMCR,	A	; Disable Sleep
	   	ret					

DUTY_C:		;;  Duty cycle control/approx 0.03(C) ms (on) 0.03*(BR_LIM-C)ms (off)
		;;  for 8MHz Clock Fuse Prescaler=1/8
		;;  For LED PWM Brightness control.
		push 	B
		push	D
		push	E
		mov	B,  C
wloop1:		ldi	D,  25
wloop2:		dec	D	
		brne	wloop2								
		dec	B			
		brne	wloop1
		mov	B, 	C
		subi 	B,	BR_LIM
		brsh	rwait		; Maximum Brightness. Skip Turning off 		
		ldi	E, 0xFF
		out	PORTD,	E	; 7 seg off
		neg	B		; BR_LIM-B  the loop with LED off
		rjmp	wloop3
wloop3:		ldi	D,  25
wloop4:		dec	D
		brne	wloop4								
		dec	B			
		brne	wloop3	
rwait:		pop	E
		pop	D
		pop	B
		ret
		
START_BRIGHT:			  ; Start ADC from CdS reading
		lds	A,	ADCSRA
		andi	A,	(1<<ADSC)|(1<<ADIF)                         
		breq	go_conv 	  ; Return if still in conv or handling 
		ret
go_conv:	lds	A,	ADCSRA
		sbr	A,	(1<<ADSC) ; ADSC bit on.
		sts	ADCSRA,	A 	  ; Start Conversion, read on interupt
		ret

SET_BRIGHT:	;; Set brightness at the end of conversion    ;;; Check here so FA_LIM and BR_LIM make sense.
		;; Scale ADCH reading to sADC=0-63, C=sADC-FA_LIM or 1 of sADC<FA_LIM.
		;; If C is ADC>=BR_LIM, F(LED brightness)=BR_LIM (full)
		;; F register keeps Brighness_sADC, C register keeps Brightess_LED: C
		;; If sADC<=FA_LIM, C(LED brightness)=1
		lds	A,	ADCSRA
		andi	A,	(1<<ADSC)|(1<<ADIF)                         
		breq	start_set_br 	  ; Return if still in conv or handling
		ret				
start_set_br:	push	E	
		lds	E,	ADCH	; 
		lsr	E		; ADCH: 0-255, E=ADCH/4
		lsr	E		; E: 0-63
		mov	F,	E       ; Keep scaled ADC val (ambient brightness) to F.	
		subi	E,	FA_LIM  ; Scaling. ADC-FA_LIM+1
		brsh	skip_zero  	; IF ADC<FA_LIM, Brightbess=1 
		clr	E	
skip_zero:	inc	E		
		cpi	E, 	BR_LIM  ; IF E > BR_LIM
		brlo	skip_full
		ldi	C, 	BR_LIM 	; Full brightness
		rjmp	reti_br
skip_full:	mov	C, 	E
reti_br:	pop	E
		ret

	
;*****************************************************
;* "bin2BCD8" - 8-bit Binary to BCD conversion
;* This subroutine converts an 8-bit number (A) to a 2-digit 
;* i.e 0x15 becomes 0x21
;* result in A
;**********************************************************
;
BIN2BCD8:  			; A is input/output D is Temporary
		clr	D			;clear temp reg
bBCD8_1:	subi	A,10		;input = input - 10
		brcs	bBCD8_2		;abort if carry set
		subi	D,-0x10 	;increase digit 10
		rjmp	bBCD8_1		;loop again
bBCD8_2:	subi	A,-10		;compensate extra subtraction
		add	A,D		;Add both BCD digit
		ret
		
.CSEG
;	Data for 7-segmanet display (Normal and Mirrored)
;   Note: When .DB line is divided, each line should contain EVEN number of bytes to 
;	      assure continuity. Edited for V2.  

; SEGM_NO: .DB 0b01111110,0b00100010,0b01010111,0b00111011,0b00101011,0b00111101
; .DB 0b01111101,0b00100110,0b01111111,0b00111111
; SEGM_MR: .DB 0b01111110,0b00010010,0b00111101,0b00111011,0b01100011,0b01010111
; .DB 0b01011111,0b00110010,0b01111111,0b01110111

; 7-seg is LOW Active. Port output 0 turns LEDs on.
; 
;            	      76543210,  76543210,  76543210,  76543210,  76543210,  76543210	
SEGM_NO: 	.DB 0b11000000,0b11111001,0b10100100,0b10110000,0b10011001,0b10010010
		.DB 0b10000010,0b11011000,0b10000000,0b10010000
SEGM_MR: 	.DB 0b11000000,0b11111001,0b10010010,0b10110000,0b10101001,0b10100100
		.DB 0b10000100,0b11100001,0b10000000,0b10100000

