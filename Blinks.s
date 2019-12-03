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
		
		AREA		|.text|, CODE, READONLY
		THUMB
		EXPORT	_Init_PortF

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
		ORR		R0,#0x0F
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
		END