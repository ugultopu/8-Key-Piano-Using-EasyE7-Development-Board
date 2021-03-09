/*
* Clock Frequency: 8MHz.
* PWM Prescaler: 1.
* Number of PWM Samples: 30.
* Using "Phase and Frequency Correct PWM".
* Using "Middle C"s octave.
* TOP value is stored in 2 bytes.
*/
.equ LUT_WORD_SIZE=30	
.equ currentCompareValueIndex=$60
.equ previousInput=$61
.equ pressedKeyIndicesArrayStart=$62
.equ TOPHighByteLocation=$6A
.equ LUTStart=$6C
.def temp=R16
.def temp1=R17
.def temp2=R18
.def temp3=R19
.def temp4=R20
.def arg0=R21
.def v0=R22
	
.org $000
	jmp RESET
.org $010
	jmp TIMER1_COMPB_ISR
RESET:
	ldi temp, high(RAMEND)
	out sph, temp
	ldi temp, low(RAMEND)
	out spl, temp			
	sbi ddrd, 4		
	clr temp		
	out ddrc, temp	
	ldi temp, (1<<OCIE1B)	
	out timsk, temp	
	sei				
MAIN:
	rcall GET_INPUT	
	rjmp MAIN
GET_INPUT:
	in temp2, PINC	
	ldi temp1, 20	
	DEBOUNCING_LOOP:
		in temp, PINC			
		cp temp, temp2				
		brne RETURN_FROM_GET_INPUT	
		dec temp1				
		breq AFTER_DEBOUNCING_LOOP	
		rjmp DEBOUNCING_LOOP	
	AFTER_DEBOUNCING_LOOP:
		lds temp1, previousInput
		cp temp, temp1			
		breq RETURN_FROM_GET_INPUT	
		sts previousInput, temp	
		mov arg0, temp
		rcall PROCESS_INPUT	
	RETURN_FROM_GET_INPUT:
		ret		

PROCESS_INPUT:
	cli	
	cpi arg0, 0	
	brne INPUT_IS_NONZERO
	clr temp	
	ori temp, (1<<CS10)
	com temp	
	in temp1, tccr1b
	and temp1, temp	
	out tccr1b, temp1	
	rjmp RETURN_FROM_PROCESS_INPUT
	INPUT_IS_NONZERO:
		rcall GET_KEY_INDEX	
		mov arg0, v0		
		rcall GENERATE_TOP_AND_LUT	
		rcall RESTART_PWM	
	RETURN_FROM_PROCESS_INPUT:
		sei	
		ret		

GET_KEY_INDEX:
	ldi v0, 0		
	ldi XH, high(pressedKeyIndicesArrayStart)
	ldi XL, low(pressedKeyIndicesArrayStart)	
	ldi temp1, -1	
	GET_KEY_INDEX_LOOP:
		inc temp1	
		cpi temp1, 8
		breq RETURN_FROM_GET_KEY_INDEX	
		lsl arg0	
		brcc GET_KEY_INDEX_LOOP	
		inc v0		
		st X+, temp1	
		rjmp GET_KEY_INDEX_LOOP
	RETURN_FROM_GET_KEY_INDEX:
		ret			

GENERATE_TOP_AND_LUT:
	rcall GENERATE_TOP
	rcall GENERATE_LUT
	ret

CLEAR_TOP:
	clr temp	
	sts TOPHighByteLocation, temp	
	sts TOPHighByteLocation+1, temp	
	ret			

GENERATE_TOP:
	rcall CLEAR_TOP	
	ldi XH, high(pressedKeyIndicesArrayStart)
	ldi XL, low(pressedKeyIndicesArrayStart)	
	ldi temp4, -1	
	GENERATE_TOP_LOOP:
		inc temp4	
		cp temp4, arg0	
		breq RETURN_FROM_GENERATE_TOP_LOOP 
		ld temp,X+	
		lsl temp	
		ldi ZH, high(TOP_VALUES*2)
		ldi ZL, low(TOP_VALUES*2)	
		add ZL, temp
		clr temp		
		adc ZH, temp	
		lpm temp, Z+	
		lpm temp1, Z	
		lds temp2, TOPHighByteLocation		
		lds temp3, TOPHighByteLocation+1	
		add temp1, temp3	
		adc temp, temp2		
		sts TOPHighByteLocation,temp	
		sts TOPHighByteLocation+1,temp1	
		rjmp GENERATE_TOP_LOOP
	RETURN_FROM_GENERATE_TOP_LOOP:
		ret	

CLEAR_LUT:
	ldi XH, high(LUTStart)
	ldi XL, low(LUTStart)	
	clr temp	
	ldi temp1, -1	
	CLEAR_LUT_LOOP:
		inc temp1	
		cpi temp1, LUT_WORD_SIZE*2	
		breq RETURN_FROM_CLEAR_LUT_LOOP 
		st X+, temp	
		rjmp CLEAR_LUT_LOOP
	RETURN_FROM_CLEAR_LUT_LOOP:
		ret	

GENERATE_LUT:
	rcall CLEAR_LUT	
	ldi XH, high(pressedKeyIndicesArrayStart)
	ldi XL, low(pressedKeyIndicesArrayStart)	
	ldi temp4, -1	
	GENERATE_LUT_LOOP:
		inc temp4	
		cp temp4, arg0	
		breq RETURN_FROM_GENERATE_LUT_LOOP 
		ld temp,X+	
		ldi temp1, LUT_WORD_SIZE
		mul temp, temp1	
		lsl R0
		rol R1		
		ldi ZH, high(KEY_COMPARE_START*2)	
		ldi ZL, low(KEY_COMPARE_START*2)	
		add ZL, R0
		adc ZH, R1	
		rcall ADD_CURRENT_LUT	
		rjmp GENERATE_LUT_LOOP	
	RETURN_FROM_GENERATE_LUT_LOOP:
		ret	
		
ADD_CURRENT_LUT:
	push temp4	
	push temp	
	push XH		
	push XL		
	ldi XH, high(LUTStart)
	ldi XL, low(LUTStart)	
	ldi temp4, -1	
	ADD_CURRENT_LUT_LOOP:
		inc temp4	
		cpi temp4, LUT_WORD_SIZE	
		breq RETURN_FROM_ADD_CURRENT_LUT_LOOP 
		ld temp, X+		
		ld temp1, X+	
		lpm temp2, Z+	
		lpm temp3, Z+	
		add temp1, temp3	
		adc temp, temp2		
		sbiw XH:XL, 2		
		st X+, temp		
		st X+, temp1	
		rjmp ADD_CURRENT_LUT_LOOP
	RETURN_FROM_ADD_CURRENT_LUT_LOOP:
		pop XL		
		pop XH		
		pop temp	
		pop temp4	
		ret	

RESTART_PWM:
	lds temp, TOPHighByteLocation	
	out OCR1AH, temp 	
	lds temp, TOPHighByteLocation+1	
	out OCR1AL, temp 	
	ldi ZH, high(LUTStart)
	ldi ZL, low(LUTStart)	
	ld temp, Z+			
	out OCR1BH, temp	
	ld temp, Z+			
	out OCR1BL, temp	
	clr temp	
	inc temp
	sts currentCompareValueIndex, temp	
	clr temp			
	out tcnt1H, temp	
	out tcnt1L, temp	
	ldi temp, (1<<OCF1B)
	out tifr, temp		
	ldi temp, (1<<COM1B1)|(0<<COM1B0)|(0<<WGM11)|(1<<WGM10)
	out tccr1a, temp	
	ldi temp, (1<<WGM13)|(0<<WGM12)|(0<<CS12)|(0<<CS11)|(1<<CS10)
	out tccr1b, temp	
	sbi ddrd, 4		
	ldi temp, (1<<OCIE1B)	
	out timsk, temp	
	ret		

TIMER1_COMPB_ISR:
	push temp	
	in temp, SREG	
	push temp	
	lds temp, currentCompareValueIndex	
	cpi temp, LUT_WORD_SIZE	
	brne AFTER_CCVI_FIX	
	sbiw ZH:ZL, LUT_WORD_SIZE*2	
	clr temp		
	AFTER_CCVI_FIX:
		inc temp							
		sts currentCompareValueIndex, temp	
		ld temp, Z+						
		out OCR1BH, temp					
		ld temp, Z+						
		out OCR1BL, temp					
		pop temp	
		out SREG, temp	
		pop temp	
		reti								

TOP_VALUES:
	.db high(510),low(510)
	.db high(454),low(454)
	.db high(405),low(405)
	.db high(382),low(382)
	.db high(340),low(340)
	.db high(303),low(303)
	.db high(287),low(287)
	.db high(255),low(255)
KEY_COMPARE_START:
	KEY_40:
		.db high(255),low(255)
		.db high(308),low(308)
		.db high(359),low(359)
		.db high(405),low(405)
		.db high(445),low(445)
		.db high(476),low(476)
		.db high(498),low(498)
		.db high(509),low(509)
		.db high(509),low(509)
		.db high(498),low(498)
		.db high(476),low(476)
		.db high(445),low(445)
		.db high(405),low(405)
		.db high(359),low(359)
		.db high(308),low(308)
		.db high(255),low(255)
		.db high(202),low(202)
		.db high(151),low(151)
		.db high(105),low(105)
		.db high(65),low(65)
		.db high(34),low(34)
		.db high(12),low(12)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(12),low(12)
		.db high(34),low(34)
		.db high(65),low(65)
		.db high(105),low(105)
		.db high(151),low(151)
		.db high(202),low(202)
	KEY_42:
		.db high(227),low(227)
		.db high(274),low(274)
		.db high(319),low(319)
		.db high(360),low(360)
		.db high(396),low(396)
		.db high(424),low(424)
		.db high(443),low(443)
		.db high(453),low(453)
		.db high(453),low(453)
		.db high(443),low(443)
		.db high(424),low(424)
		.db high(396),low(396)
		.db high(360),low(360)
		.db high(319),low(319)
		.db high(274),low(274)
		.db high(227),low(227)
		.db high(180),low(180)
		.db high(135),low(135)
		.db high(94),low(94)
		.db high(58),low(58)
		.db high(30),low(30)
		.db high(11),low(11)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(11),low(11)
		.db high(30),low(30)
		.db high(58),low(58)
		.db high(94),low(94)
		.db high(135),low(135)
		.db high(180),low(180)
	KEY_44:
		.db high(203),low(203)
		.db high(245),low(245)
		.db high(285),low(285)
		.db high(322),low(322)
		.db high(353),low(353)
		.db high(378),low(378)
		.db high(395),low(395)
		.db high(404),low(404)
		.db high(404),low(404)
		.db high(395),low(395)
		.db high(378),low(378)
		.db high(353),low(353)
		.db high(322),low(322)
		.db high(285),low(285)
		.db high(245),low(245)
		.db high(203),low(203)
		.db high(160),low(160)
		.db high(120),low(120)
		.db high(83),low(83)
		.db high(52),low(52)
		.db high(27),low(27)
		.db high(10),low(10)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(10),low(10)
		.db high(27),low(27)
		.db high(52),low(52)
		.db high(83),low(83)
		.db high(120),low(120)
		.db high(160),low(160)
	KEY_45:
		.db high(191),low(191)
		.db high(231),low(231)
		.db high(269),low(269)
		.db high(303),low(303)
		.db high(333),low(333)
		.db high(356),low(356)
		.db high(373),low(373)
		.db high(381),low(381)
		.db high(381),low(381)
		.db high(373),low(373)
		.db high(356),low(356)
		.db high(333),low(333)
		.db high(303),low(303)
		.db high(269),low(269)
		.db high(231),low(231)
		.db high(191),low(191)
		.db high(151),low(151)
		.db high(113),low(113)
		.db high(79),low(79)
		.db high(49),low(49)
		.db high(26),low(26)
		.db high(9),low(9)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(9),low(9)
		.db high(26),low(26)
		.db high(49),low(49)
		.db high(79),low(79)
		.db high(113),low(113)
		.db high(151),low(151)
	KEY_47:
		.db high(170),low(170)
		.db high(205),low(205)
		.db high(239),low(239)
		.db high(270),low(270)
		.db high(296),low(296)
		.db high(317),low(317)
		.db high(332),low(332)
		.db high(339),low(339)
		.db high(339),low(339)
		.db high(332),low(332)
		.db high(317),low(317)
		.db high(296),low(296)
		.db high(270),low(270)
		.db high(239),low(239)
		.db high(205),low(205)
		.db high(170),low(170)
		.db high(135),low(135)
		.db high(101),low(101)
		.db high(70),low(70)
		.db high(44),low(44)
		.db high(23),low(23)
		.db high(8),low(8)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(8),low(8)
		.db high(23),low(23)
		.db high(44),low(44)
		.db high(70),low(70)
		.db high(101),low(101)
		.db high(135),low(135)
	KEY_49:
		.db high(152),low(152)
		.db high(183),low(183)
		.db high(213),low(213)
		.db high(241),low(241)
		.db high(264),low(264)
		.db high(283),low(283)
		.db high(296),low(296)
		.db high(302),low(302)
		.db high(302),low(302)
		.db high(296),low(296)
		.db high(283),low(283)
		.db high(264),low(264)
		.db high(241),low(241)
		.db high(213),low(213)
		.db high(183),low(183)
		.db high(152),low(152)
		.db high(120),low(120)
		.db high(90),low(90)
		.db high(62),low(62)
		.db high(39),low(39)
		.db high(20),low(20)
		.db high(7),low(7)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(7),low(7)
		.db high(20),low(20)
		.db high(39),low(39)
		.db high(62),low(62)
		.db high(90),low(90)
		.db high(120),low(120)
	KEY_51:
		.db high(144),low(144)
		.db high(173),low(173)
		.db high(202),low(202)
		.db high(228),low(228)
		.db high(250),low(250)
		.db high(268),low(268)
		.db high(280),low(280)
		.db high(286),low(286)
		.db high(286),low(286)
		.db high(280),low(280)
		.db high(268),low(268)
		.db high(250),low(250)
		.db high(228),low(228)
		.db high(202),low(202)
		.db high(173),low(173)
		.db high(144),low(144)
		.db high(114),low(114)
		.db high(85),low(85)
		.db high(59),low(59)
		.db high(37),low(37)
		.db high(19),low(19)
		.db high(7),low(7)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(7),low(7)
		.db high(19),low(19)
		.db high(37),low(37)
		.db high(59),low(59)
		.db high(85),low(85)
		.db high(114),low(114)
	KEY_52:
		.db high(128),low(128)
		.db high(154),low(154)
		.db high(179),low(179)
		.db high(202),low(202)
		.db high(222),low(222)
		.db high(238),low(238)
		.db high(249),low(249)
		.db high(254),low(254)
		.db high(254),low(254)
		.db high(249),low(249)
		.db high(238),low(238)
		.db high(222),low(222)
		.db high(202),low(202)
		.db high(179),low(179)
		.db high(154),low(154)
		.db high(128),low(128)
		.db high(101),low(101)
		.db high(76),low(76)
		.db high(53),low(53)
		.db high(33),low(33)
		.db high(17),low(17)
		.db high(6),low(6)
		.db high(1),low(1)
		.db high(1),low(1)
		.db high(6),low(6)
		.db high(17),low(17)
		.db high(33),low(33)
		.db high(53),low(53)
		.db high(76),low(76)
		.db high(101),low(101)