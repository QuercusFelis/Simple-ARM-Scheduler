;*************************************************************** 
; Andrew Groeling & Kris Alquist
; Date 12-3-2019
; Lab #9 - Simple Scheduler 
;*************************************************************** 
;	USAGE NOTES:
;	   -The scheduler MUST be initialized with at least 1
; 		program to work properly. (This is a result of a design
;		choice to keep the interrupt handler's execution time to
; 		an absolute minimum, as maximizing the execution of other 
;		programs was considered to be the primary design goal)
;	   -To add a program, simply load the starting address
;		into R0 an call ProcAdd. It will be added to the end of
;		the execution table
;
;***************************************************************

;*************************************************************** 
; EQU Directives
;*************************************************************** 
Stack           	EQU		0x00000400		; Stack size
; Interupt symbols
NVIC_ST_CTRL		EQU		0xE000E010
NVIC_ST_RELOAD  	EQU		0xE000E014
NVIC_ST_CURRENT		EQU		0xE000E018
SHP_SYSPRI3	    	EQU		0xE000ED20 	
RELOAD_VALUE		EQU		4000000			; One second at 16 MHz
	
	; Use built-in LED on Port F
GPIO_PORTF_DATA_R  	EQU 	0x400253FC
GPIO_PORTF_DIR_R   	EQU 	0x40025400
GPIO_PORTF_AFSEL_R 	EQU 	0x40025420
GPIO_PORTF_PUR_R   	EQU 	0x40025510
GPIO_PORTF_DEN_R   	EQU 	0x4002551C
GPIO_PORTF_AMSEL_R 	EQU 	0x40025528
GPIO_PORTF_PCTL_R  	EQU 	0x4002552C
SYSCTL_RCGCGPIO_R  	EQU 	0x400FE608
PCTLCNST           	EQU 	0x0000FFF0

DELAYCNTR			EQU		1600000    ; .1 sec at 16MHZ (16,000,000/10)
DELAYCNTRSHORT		EQU		DELAYCNTR/4

;**************************************************************
; Important initialization variables
;**************************************************************
tabcap	EQU		4			;max number of programs scheduled
led1	EQU		Blink1		;addresses of programs
led2	EQU		Blink2
led3	EQU		Blink4
led7	EQU		Blink7
	
;***************************************************************
; Data Section in READWRITE
; Values of the data in this section are not properly initialazed, 
; but labels can be used in the program to change the data values.
;***************************************************************
			AREA            |.sdata|, DATA, READWRITE
			THUMB
exectab		SPACE	4*tabcap	;each address is 4 bytes, so array length is capacity*4
statetab	SPACE	4*8*tabcap	;storage for contexts (8, 4 byte registers per entry)
tabcntr		SPACE	1			;only need 1 byte for pointer
tabsize		SPACE	1			;only need 1 byte for size

;***************************************************************
; Program section                         
;***************************************************************
;LABEL	DIRECTIVE	VALUE								COMMENT
				
		AREA		|.text|, CODE, READONLY
		THUMB
		EXTERN		_Init_PortF
		EXPORT		__main				; Make Reset_Handler available to linker
__main
		BL		_Init_PortF	; Call Port F Initialization subroutine.
		BL		systick_ini
		BL		exectab_ini
		
		LDR		R0,=led1		; process initialization section
		BL		ProcAdd
		LDR		R0,=led2
		BL		ProcAdd
		LDR		R0,=led3
		BL		ProcAdd
		LDR		R0,=led7
		BL		ProcAdd
		
		CPSIE	I				; Turn on interrupts. 
		BL		Blink1
		
;*********************************************************
; ProcAdd subroutine
;*********************************************************
ProcAdd			;adds process to execution table, passed by R0
		PUSH	{R1,R2,R3,R4,LR}
		LDR		R1,=tabsize		;check if execution table is full	
		LDRB	R3,[R1]
		LDR		R2,=tabcap
		CMP		R3,R2			;compare size and capacity
		BGE		paddend			;if full, exit without adding
		LDR		R4,=statetab	;load address to write values to
		LDR		R2,=exectab		;load table address
		LSL		R3,#5			;multiply to use as offset for statetab
		ADD		R4,R3			;add offset to statetab base address
		LSR		R3,#3			;shift back to use as offset for exectab
		STR		R4,[R2,R3]		;add relevant stack pointer to program to table
		MOV		R2,#0			;clear r2 to create dummy processor state
		STR		R2,[R4],#4		;dummy R0
		STR		R2,[R4],#4		;dummy R1
		STR		R2,[R4],#4		;dummy R2
		STR		R2,[R4],#4		;dummy R3
		STR		R2,[R4],#4		;dummy R12
		LDR		R2,=0xFFFFFFF9	;dummy LR value
		STR		R2,[R4],#4		;dummy LR
		STR		R0,[R4],#4		;push program address to stack
		LDR		R2,=0x81000000	;dummy xPSR value
		STR		R2,[R4],#4		;push psuedo-xPSR
		LSR		R3,#2			;shift offset back to size (faster than reloading)
		ADD		R3,#1			;increment size
		STRB	R3,[R1]			;store size
paddend	POP		{R1,R2,R3,R4,LR}
		BX		LR

;*********************************************************
; ProcNext subroutine
;*********************************************************
ProcNext		;cycles through execution table
		LDR		R1,=tabcntr
		LDRB	R2,[R1]
		LDR		R3,=tabsize		;check if at end of table
		LDRB	R3,[R3]
		SUB		R3,#1			;sub 1 from the size for comparison
		CMP		R2,R3			; /!\ set flags here
		LDR		R3,=exectab		;size no longer needed, load the exectab pointer for R/W ops
		LSL		R2,#2
		LDR		R8,[R3,R2]		;load address of statetab for next register set
		POP		{R0-R7} 		;steal top 32 bytes from stack
		STM		R8,{R0-R7}		;store 32 bytes in corresponding statetab location
		LDR		R3,=exectab		;reload clobbered registers
		LDR		R1,=tabcntr
		LDRB	R2,[R1]
		ADD		R2,#1			;increment table counter
		BLT		pnset			; /!\ check flags here
		MOV		R2,#0			;if at end of table, reset tabcntr to 0
pnset	STRB	R2,[R1]			;update table pointer
		LSL		R2,#2
		LDR		R8,[R3,R2]		;load next statetab address
		LDM		R8,{R0-R7}		;load next context
		PUSH	{R0-R7} 		;push to stack
		BX		LR

;*********************************************************
; exectab_ini subroutine
;*********************************************************
exectab_ini		;initializes table metadata
		PUSH	{R1,R2,R3,LR}
		LDR		R1,=tabsize
		LDR		R2,=tabcntr
		MOV		R0,#0
		STRB	R0,[R1]
		STRB	R0,[R2]
		POP		{R1,R2,R3,LR}
		BX		LR

;*********************************************************
; systick_ini subroutine
;*********************************************************
systick_ini		;initialize interrupts subroutine
		PUSH {R0,R1}
		LDR	R1,=NVIC_ST_CTRL
		MOV	R0,#0
		STR	R0,[R1]
		LDR	R1,=NVIC_ST_RELOAD
		LDR	R0,=RELOAD_VALUE
		STR	R0,[R1]
		LDR	R1,=NVIC_ST_CURRENT
		STR	R0,[R1]
		LDR	R1,=SHP_SYSPRI3
		LDR	R0,=0X40000000
		STR	R0,[R1]
		LDR	R1,=NVIC_ST_CTRL
		MOV	R0,#0x03
		STR	R0,[R1]
		POP	{R0,R1}
		BX	LR
		
;*********************************************************
; SysTick ISR
;*********************************************************
; Interrupt Service routine
; This gets called every 1 s (determined by interrupt setup)
		EXPORT	SysTick_Handler
SysTick_Handler
		MOV		R10,LR		;move LR to call procnext
		BL		ProcNext	;swaps top 32 bytes of stack
		MOV		LR,R10		;restore
		BX		LR

;*******************************************************
;	Blink program section
;		(written as separate programs instead of 1 
;		 with args for demonstration purposes)
;*******************************************************

Blink1
		LDR		R0,=GPIO_PORTF_DATA_R
		MOV		R1,#0x02			;initialize values
		MOV		R2,#0x00
bloop1	LDR		R3,=DELAYCNTRSHORT	;set delay to a brief time
		STR		R1,[R0]				;turn led on
bon1	SUB		R3,#1				;count down once
		CMP		R3,#0		
		BNE		bon1				;if not 0, count down 1 more
		STR		R2,[R0]				;else, turn led off
		LDR		R3,=DELAYCNTR		;reset counter
boff1	SUB		R3,#1				;count down once
		CMP		R3,#0
		BEQ		bloop1				;if 0, start over again
		B		boff1				;else count down again

		
;****************************************************************

Blink2
		LDR		R0,=GPIO_PORTF_DATA_R
		MOV		R1,#0x04			;initialize values
		MOV		R2,#0x00
bloop2	LDR		R3,=DELAYCNTRSHORT	;set delay to a brief time
		STR		R1,[R0]				;turn led on
bon2	SUB		R3,#1				;count down once
		CMP		R3,#0		
		BNE		bon2				;if not 0, count down 1 more
		STR		R2,[R0]				;else, turn led off
		LDR		R3,=DELAYCNTR		;reset counter
boff2	SUB		R3,#1				;count down once
		CMP		R3,#0
		BEQ		bloop2				;if 0, start over again
		B		boff2				;else count down again

		
;****************************************************************
		
Blink4
		LDR		R0,=GPIO_PORTF_DATA_R
		MOV		R1,#0x08			;initialize values
		MOV		R2,#0x00
bloop4	LDR		R3,=DELAYCNTRSHORT	;set delay to a brief time
		STR		R1,[R0]				;turn led on
bon4	SUB		R3,#1				;count down once
		CMP		R3,#0		
		BNE		bon4				;if not 0, count down 1 more
		STR		R2,[R0]				;else, turn led off
		LDR		R3,=DELAYCNTR		;reset counter
boff4	SUB		R3,#1				;count down once
		CMP		R3,#0
		BEQ		bloop4				;if 0, start over again
		B		boff4				;else count down again
		
;****************************************************************
		
Blink7
		LDR		R0,=GPIO_PORTF_DATA_R
		MOV		R1,#0x0E			;initialize values
		MOV		R2,#0x00
bloop7	LDR		R3,=DELAYCNTRSHORT	;set delay to a brief time
		STR		R1,[R0]				;turn led on
bon7	SUB		R3,#1				;count down once
		CMP		R3,#0		
		BNE		bon7				;if not 0, count down 1 more
		STR		R2,[R0]				;else, turn led off
		LDR		R3,=DELAYCNTR		;reset counter
boff7	SUB		R3,#1				;count down once
		CMP		R3,#0
		BEQ		bloop7				;if 0, start over again
		B		boff7				;else count down again
;***************************************************************
; End of the program  section
;***************************************************************
		ALIGN		
        END