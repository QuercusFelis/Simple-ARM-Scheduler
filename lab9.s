;*************************************************************** 
; Student Version Adapted from version from Sanja Manic
; Date 10-19-18
; Lab #7 - Maskable interrupts 
; Uses Termite and PortF LED (RG&B)
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
RELOAD_VALUE		EQU		3999999			; One second at 16 MHz
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
	
;***************************************************************
; Data Section in READWRITE
; Values of the data in this section are not properly initialazed, 
; but labels can be used in the program to change the data values.
;***************************************************************
		AREA            |.sdata|, DATA, READWRITE
        THUMB
exectab	SPACE	4*tabcap	
tabcntr	SPACE	1
tabsize	SPACE	1

;***************************************************************
; Directives - This Data Section is part of the code
; It is in the read only section  so values cannot be changed.
;***************************************************************
;LABEL	DIRECTIVE       VALUE                           COMMENT
		AREA            |.data|, DATA, READONLY
		THUMB
tabcap	EQU		4			;max number of programs scheduled
led1	EQU		Blink1
led2	EQU		Blink2
led3	EQU		Blink3
led7	EQU		Blink7
         
;***************************************************************
; Program section                         
;***************************************************************
;LABEL	DIRECTIVE	VALUE								COMMENT
				
		AREA		|.text|, CODE, READONLY
		THUMB
		EXPORT		__main				; Make Reset_Handler available to linker
__main
		BL		_Init_PortF	; Call Port F Initialization subroutine.
		BL		exectab_ini
		
		LDR		R0,=led1		; process initialization section
		BL		ProcAdd
		LDR		R0,=led2
		BL		ProcAdd
		LDR		R0,=led3
		BL		ProcAdd
		LDR		R0,=led7
		BL		ProcAdd
		
		BL		systick_ini
		CPSIE	I				; Turn on interrupts. 
		WFI

;*********************************************************
; ProcAdd subroutine
;*********************************************************
ProcAdd			;adds process to execution table, passed by R0
		PUSH	{R0,R1,R2,R3,LR}
		LDR		R1,=tabsize
		LDR		R3,[R1]
		LDR		R2,=tabcap		;check if execution table is full
		LDR		R2,[R2]
		CMP		R3,R2
		BLT		padd
		BX		paddend
padd	ADD		R3,#1
		STRB	R3,[R1]
		LDR		R2,=exectab
		MUL		R3,4
		STR		R0,[R2,R3]
paddend	POP		{R0,R1,R2,R3,LR}
		BX		LR

;*********************************************************
; ProcNext subroutine
;*********************************************************
ProcNext		;cycles through execution table
		PUSH	{R1,R2,R3}
		LDR		R1,=tabcntr
		LDR		R2,[R1]
		LDR		R3,=tabsize		;check if at end of table
		LDR		R3,[R3]
		CMP		R2,R3
		LDR		R3,=exectab
		STR		R0,[R3,R2,LSL #2]	;store last program counter in table
		ADD		R2,#1			;increment table counter
		BLT		pnset
		MOV		R2,#0
pnset	STR		R2,[R1]			;update table pointer and program counter
		LDR		R0,[R3,R2,LSL #2]
		POP		{R1,R2,R3}
		PUSH	{R0}
		BX		LR

;*********************************************************
; exectab_ini subroutine
;*********************************************************
exectab_ini		;initializes table metadata
		PUSH	{R1,R2,LR}
		LDR		R1,=tabsize
		LDR		R2,=tabcntr
		MOV		R0,#0
		STRB	R0,[R1]
		STRB	R0,[R2]
		POP		{R1,R2,LR}
		BX		LR

;*********************************************************
; systick_ini subroutine
;*********************************************************
systick_ini		;initialize interupts subroutine
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
; _Init_PortF subroutine
;*********************************************************
; Make Port F 1-3 outputs, enable digital I/O, ensure alt. functions off.
; Input: none  Output: none   Modifies: R0, R1
; 32 lines of assembly code available in several examples using built-in LEDs

_Init_PortF
		PUSH	{R0,R1,LR}
		LDR		R1,=SYSCTL_RCGCGPIO_R	; 1) activate clock for Port F
		LDR		R0,[R1]
		ORR		R0,#0x20
		STR		R0,[R1]
; 2) no need to unlock PF		
		LDR		R1,=GPIO_PORTF_AMSEL_R	; 3) disable analog functionality
		LDR		R0,[R1]
		BIC		R0,#0xFF
		STR		R0,[R1]
; 4) configure as GPIO
		LDR		R1,=GPIO_PORTF_DIR_R	; 5) set direction register
		LDR		R0,[R1]
		ORR		R0,#0x14
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTF_AFSEL_R	; 6) regular port function
		LDR		R0,[R1]
		BIC		R0,#0xFF
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTF_DEN_R	; 7) enable Port F digital port
		LDR		R0,[R1]
		ORR		R0,#0xFF
		STR		R0,[R1]
		LDR		R1,=GPIO_PORTF_DATA_R; Turn off LED (RG&B)
		MOV		R0,#0x00
		STRB	R0,[R1]
		POP		{R0,R1,LR}
		BX		LR
	ALIGN                           	; make sure the end of this section is aligned
		
;*********************************************************
; SysTick ISR
;*********************************************************
; Interrupt Service routine
; This gets called every 1 s (determined by interrupt setup)
		EXPORT	SysTick_Handler
SysTick_Handler
		POP		{R0}
		PUSH	{LR}
		BL		ProcNext
		POP		{LR}
		BX		LR
		
;***************************************************************
; End of the program  section
;***************************************************************
		ALIGN		
        END