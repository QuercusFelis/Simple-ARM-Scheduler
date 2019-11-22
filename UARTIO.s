;***************************************************************
; UARTIO.s Collection of Input and Output Routines for use
;   with terminal emulator. Tested with Termite 3.1 and
;   Tera Term. Saves&restores registers & delay   10/25/19
; 8-bit, No Parity, 1-Stop bit, No Flow control
; U0Rx connected to PA0     U0Tx connected to PA1
; UART_Init: BaudRate in R0; SysClkFreq in R1
; Default:  9600baud if R0=0 and 16MHz if R1=0
; InChar  - Capture ACSII input via UART0, in R0
; OutChar - Output ASCII character in R0 through UART0
; OutStr  - Output string starting at mem addr passed in R0 
; Out1BSP - Output byte in R0 as 2 Hex digits, then space
; Out2BSP - Output halfword in R0 as 4 hex digits, then space
;***************************************************************

;	***************** GPIO Registers *****************
RCGCGPIO	EQU			0x400FE608		;	GPIO clock register
PORTA_DEN	EQU 		0x4000451C		;	Digital Enable
PORTA_PCTL	EQU 		0x4000452C		;	Alternate function select
PORTA_AFSEL	EQU 		0x40004420		;	Enable Alt functions
PORTA_AMSEL	EQU 		0x40004528		;	Enable analog
PORTA_DR2R	EQU			0x40004500		;	Drive current select	
;	***************** UART Registers *****************
RCGCUART	EQU			0x400FE618		;	UART clock register
UART0_DR	EQU			0x4000C000		;	UART0 data / base address
UART0_CTL	EQU			0x30			;	UART0 control register
UART0_IBRD	EQU			0x24			;	Baud rate divisor Integer part
UART0_FBRD	EQU			0x28			;	Baud rate divisor Fractional part
UART0_LCRH	EQU			0x2C			;	UART serial parameters
UART0_CC	EQU 		0x4000CFC8		;	UART clock config
UART0_FR	EQU 		0x4000C018			;	UART status

		AREA 		|.text|,READONLY,CODE,ALIGN=2
		THUMB
		EXPORT	UART_Init
		EXPORT	InChar
		EXPORT	OutChar
		EXPORT	OutStr
		EXPORT	Out1BSP
		EXPORT	Out2BSP

; ------------UART_Init------------
; Initialize the UART. Baud Rate (Hz) in R0; SysClk (Hz) in R1
; Defaults to 9600baud if R0=0 and 16MHz if R1=0 
; 8 bit word length, no parity bits, one stop bit, FIFOs enabled

UART_Init
;	***************** Enable UART clock ***************** 
			LDR			R5,=RCGCUART
			LDR			R4,[R5]
			ORR			R4,#0x01			;	Set bit 0 to enable UART0 clock
			STR			R4,[R5]
;	***************** Setup GPIO ***************** 
;	Enable GPIO clock to use debug USB as com port (PA0, PA1)
			LDR			R5,=RCGCGPIO
			LDR			R4,[R5]
			ORR			R4,R4,#0x01			;	Set bit 0 to enable port A clock
			STR			R4,[R5]
;	***************** Setup UART ***************** 
; 	Disable UART0 while setting up
			LDR			R5,=UART0_DR
			LDR			R4,[R5,#UART0_CTL]
			BIC			R4,R4,#0x01			;	Clear bit 0 to disable UART0 while
			STR			R4,[R5,#UART0_CTL]				;	Setting up
;    (SysClk*128)/(BaudRate*16) gives IBRD as quotient (shift right 7 bits). FBRD is least significant
;    8 bits + lsb (round), then shift right 1.
;
			CBNZ		R0,Gotbr			; Baud Rate Specified?
			LDR			R0,=9600			; If not, set to 9600 baud
Gotbr		CBNZ		R1,Gotcl			; Clock Frequency specified?
			LDR			R1,=16000000		; If not, set to 16MHz
Gotcl		MOV			R1,R1,LSL #3		; SysClk*128/16
			UDIV		R2,R1,R0			; SysClk*8/BaudRate
;	Fractional computation			
Redo		AND			R4,R2,#0x3F			; Keep Fractional Component
			CMP			R4,#0x3F			; Will this round up to next integer?
			BNE			Validf				; No
			ADD			R2,#1				; Yes, increment to integer and no fraction
			B			Redo
Validf		AND			R3,R2,#0x01			; Rounding up bit of fraction
			ADD			R4,R3				; Round
			MOV			R4,R4, LSR #1		; Remove rounding bit
			STR			R4,[R5,#UART0_FBRD]
;   Integer computation
			MOV			R4,R2,LSR #7		; Integer part of divide
			STR			R4,[R5,#UART0_IBRD]
;	Set serial parameters
			MOV			R4,#0x70			;	No stick parity, 8bit, FIFO enabled, 
			STR			R4,[R5,#UART0_LCRH]				;	One stop bit, Disable parity, Normal use	
; 	Enable UART, TX, RX
			LDR			R4,[R5,#UART0_CTL]		
			ORR			R4,#0x01			;	Set bit 0
			STR			R4,[R5,#UART0_CTL]
; 	Make PA0, PA1 digital
			LDR			R5,=PORTA_DEN
			LDR			R4,[R5]
			ORR			R4,#0x03			;	Set bits 1,0 to enable digital on PA0, PA1
			STR			R4,[R5]	
; 	Disable analog on PA0, PA1
			LDR			R5,=PORTA_AMSEL
			LDR			R4,[R5]
			BIC			R4,#0x03			;	Clear bits 1,0 to disable analog on PA0, PA1
			STR			R4,[R5]
; 	Enable alternate functions selected
			LDR			R5,=PORTA_AFSEL
			LDR			R4,[R5]
			ORR			R4,#0x03			;	Set bits 1,0 to enable alt functions on PA0, PA1
			STR			R4,[R5]				;	TX LINE IS LOW UNTIL AFTER THIS CODE
; 	Select alternate function to be used (UART on PA0, PA1)
			LDR			R5,=PORTA_PCTL
			LDR			R4,[R5]
			BIC			R4,#0xFF
			ORR			R4,#0x11			;	Set bits 4,0 to select UART Rx, Tx
			STR			R4,[R5]
;			Need to wait
			LDR			R0,=50				; Time delay
Lp1 		ADDS 		R0,#-1
			BNE 		Lp1			
			BX			LR					;	End of UART_Init

InChar
;	***************** Input *****************
			PUSH		{R4-R6}
; 	Preload UART data address
			LDR			R6,=UART0_DR
                               
; check for incoming character
			LDR			R5,=UART0_FR		;	Load UART status register address
check		
			LDR			R4,[R5]
			ANDS		R4,#0x10			;	Check if char received (RXFE is 0)
			BNE			check				;	If no character, check again 
			LDR			R0,[R6]				;	Else, load received char into R0
	
			POP			{R4-R6}
			BX			LR		

OutChar

;	***************** Output *****************
			PUSH			{R4-R6}
; 	Preload UART data address
			LDR			R6,=UART0_DR

;	Check if UART is ready to send (buffer is empty)
			LDR		 	R5,=UART0_FR		;	Load UART status register address
waitR1
			LDR			R4,[R5]
			ANDS		R4,#0x20         ;	Check if TXFF = 1
			BNE 		waitR1	            ;	If so, UART is full, so wait / check again
			STR			R0,[R6]
; 	Check if UART is done transmitting  (Needed?)
waitD1
			LDR			R4,[R5]
			ANDS		R4,#0x08         ;	Check if BUSY = 1
			BNE 		waitD1	            ;	If so, UART is busy, so wait / check again
			POP			{R4-R6}
			BX		LR		; Done with OutChar

OutStr

;	***************** Output *****************
			PUSH		{R4-R7}
; 	Preload UART data address
			LDR			R7,=UART0_DR
loop
			LDRB		R6,[R0],#1			;	Load character, post inc address
			CMP			R6,#0x04			;	has end character been reached?
			BEQ			donestr				;	if so, end

;	Check if UART is ready to send (buffer is empty)
			LDR		 	R5,=UART0_FR		;	Load UART status register address
waitR2
			LDR			R4,[R5]
			ANDS		R4,#0x20         ;	Check if TXFF = 1
			BNE 		waitR2	            ;	If so, UART is full, so wait / check again
			STR			R6,[R7]				;	Else, send character

; 	Check if UART is done transmitting
waitD2
			LDR			R4,[R5]
			ANDS		R4,#0x08         ;	Check if BUSY = 1
			BNE 		waitD2	            ;	If so, UART is busy, so wait / check again
			B   		loop				;	Else, get next character
donestr
			POP		{R4-R7}
			BX		LR			; End of OutStr

Out1BSP
			PUSH		{R4-R9,LR}
;	***************** Output *****************
; 	Preload UART data address
			LDR			R7,=UART0_DR

;	Split byte. R6=LS R5=MS
			MOV			R6,R0
			AND			R6,R6,#0x0F
			MOV			R5,R0
			LSR			R5,R5,#4
			AND			R5,R5,#0x0F
	
;	Check if MS bits are > 9 and output
			CMP			R5,#0x09
			BGT			MStext1
			ADD			R0,R5,#0x30			;	ASCII number offset
			B			doneMS1
MStext1
			ADD			R0,R5,#0x37			;	ASCII character offset
doneMS1
			BL			OutBits				;	Send character
	
;	Check if LS bits are > 9 and output
			CMP			R6,#0x09
			BGT			LStext1
			ADD			R0,R6,#0x30			;	ASCII number offset
			B			doneLS1
LStext1
			ADD			R0,R6,#0x37			;	ASCII character offset
doneLS1
			BL			OutBits				;	Send character

			MOV			R0,#0x20			;	Load space character
			BL			OutBits				;	Send character
			POP			{R4-R9,LR}
			BX			LR				; done with Out1BSP
Out2BSP	
			PUSH		{R4-R9,LR}
;	***************** Output *****************
; 	Preload UART data address
			LDR			R7,=UART0_DR

			MOV			R8,#8				;	Store byte check value
			REV16		R0,R0				;	Reverse byte order
			MOV			R9,R0				;	Store value
;	Split byte. R6=LS R5=MS
splitByte	
			MOV			R6,R0
			AND			R6,R6,#0x0F
			MOV			R5,R0
			LSR			R5,R5,#4
			AND			R5,R5,#0x0F
	
;	Check if MS bits are > 9 and output
			CMP			R5,#0x09
			BGT			MStext2
			ADD			R0,R5,#0x30			;	ASCII number offset
			B			doneMS2
MStext2
			ADD			R0,R5,#0x37			;	ASCII character offset
doneMS2
			BL			OutBits				; send character
	
;	Check if LS bits are > 9 and output
			CMP			R6,#0x09
			BGT			LStext2
			ADD			R0,R6,#0x30			;	ASCII number offset
			B			doneLS2
LStext2
			ADD			R0,R6,#0x37			;	ASCII character offset
doneLS2
			BL			OutBits				;	Send character
	
			LSR			R0,R9,R8			;	Shift to lower byte
			SUBS		R8,R8,#8			;	Check if both bytes been sent?
			BEQ			splitByte			;	Send next byte

			MOV			R0,#0x20			;	Load space character
			BL			OutBits				;	Send character
done										;	Else, done
			POP			{R4-R9,LR}
			BX			LR				; Done with Out2BSP
;***************************************************************
; 	OutBits Subroutine                         
;***************************************************************
OutBits
;	Check if UART is ready to send (buffer is empty)
			LDR		 	R5,=UART0_FR		;	Load UART status register address
waitR3
			LDR			R4,[R5]
			ANDS		R4,#0x20         ;	Check if TXFF = 1
			BNE 		waitR3	            ;	If so, UART is full, so wait / check again
			STR			R0,[R7]				;	Else, send character

; 	Check if UART is done transmitting
waitD3
			LDR			R4,[R5]
			ANDS		R4,#0x08         ;	Check if BUSY = 1
			BNE 		waitD3	            ;	If so, UART is busy, so wait / check again

			BX			LR	; Outbits done

		ALIGN
		END