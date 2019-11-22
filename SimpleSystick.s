; *******************************************************************
; Very Simple Systick Program showing use of interrupts             *
; Runs on TM4C123 uses UARTIO and startup       Bill Eads  11-2-19  *
; *******************************************************************
NVIC_ST_BASE			EQU 0xE000E000
CTRL					EQU       0x10	; Offset from base
RELOAD        			EQU       0x14
CURRENT					EQU       0x18
SHP_SYSPRI3	        	EQU 0xE000ED20
RELOAD_VALUE			EQU    4000000	; 16,000,000/4 one second
		IMPORT		UART_Init
		IMPORT		OutStr		
		EXPORT		__main	
;*********************************************************
; Program area including SysTick Interrupt Initialization
;*********************************************************
		AREA    |.text|, CODE, READONLY, ALIGN=2
__main
		BL		UART_Init
  		LDR 	R1, =NVIC_ST_BASE	; Use this base for Systick registers
    	MOV 	R0, #0          		
    	STR 	R0, [R1,#CTRL]		; Turn Off Systick
    	LDR 	R0, =RELOAD_VALUE	
    	STR 	R0, [R1,#RELOAD]    ; Set reload value
	    STR 	R0, [R1,#CURRENT]	; Reset current counter value
		LDR 	R2, =SHP_SYSPRI3	; Systick interrupt priority register
    	MOV 	R0, #0x40000000		; Systick interrupt priority =2 (>0)
		STR 	R0, [R2]
    	MOV 	R0, #0x03 			; Turn on Systick with Precision Clock
    	STR 	R0, [R1,#CTRL]    	;  and enabling interrupts
 
		CPSIE 	I					; Enable Interrupts	
wait	WFI							; Sleep waiting for interrupts
		B		wait

;*********************************************************
; SysTick ISR
;*********************************************************
		EXPORT	SysTick_Handler
SysTick_Handler
		PUSH	{LR}
		LDR		R0,=hello
		BL		OutStr
		POP		{LR}
		BX		LR
		ALIGN
hello	DCB		"Hello from SysTick",0x0D,0x04
		ALIGN                          
  		END