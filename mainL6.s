; Archivo:	mainL6.s
; Dispositivo:	PIC16F887
; Autor:	Jeferson Noj
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Aumento de PORTA cada segundo con TMR1 y led intermitente con TMR2
; Hardware:	LEDs en PORTA y LED en PORTB
;
; Creado: 28 feb, 2022
; Última modificación:  28 feb, 2022

PROCESSOR 16F887
#include <xc.inc>
#include "macros.s"

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)


PSECT udata_bank0	    ; Memoria común
  tmr1_var:	DS 2	    ; Almacena el valor del PORTA
  selector:	DS 1
  valor:	DS 1
  nibbles:	DS 2
  display:	DS 2

PSECT udata_shr		    ; Memoria compartida
  W_TEMP:	DS 1		
  STATUS_TEMP:	DS 1

PSECT resVect, class=CODE, abs, delta=2
;-------- VECTOR RESET ----------
ORG 00h			    ; Posición 0000h para el reset
resetVec:
    PAGESEL main
    GOTO main

PSECT intVect, class=CODE, abs, delta=2
;-------- INTERRUPT VECTOR ----------
ORG 04h			    ; Posición 0004h para interrupciones
push:
    MOVWF   W_TEMP	    ; Mover valor de W a W_TEMP
    SWAPF   STATUS, 0	    ; Intercambiar nibbles de registro STATUS y guardar en W
    MOVWF   STATUS_TEMP	    ; Mover valor de W a STATUS_TEMP
isr: 
    BTFSC   T0IF	    ; Evaluar bandera de interrupción de TMR0
    CALL    int_tmr0
    BTFSC   TMR1IF
    CALL    int_tmr1
    BTFSC   TMR2IF
    CALL    int_tmr2
pop:			   
    SWAPF   STATUS_TEMP,0   ; Intercambiar nibbles de STATUS_TEMP y guardar en W
    MOVWF   STATUS	    ; Mover valor de W a registro STATUS
    SWAPF   W_TEMP, 1	    ; Intercambiar nibbles de W_TEMP y guardar en este mismo registro
    SWAPF   W_TEMP, 0	    ; Intercambiar nibbles de W_TEMP y gardar en W
    RETFIE

;------ Subrutinas de Interrupción -----
int_tmr0:
    reset_tmr0
    CLRF    PORTD
    BTFSC   selector, 0
    GOTO    display1
    display0:
	MOVF	display, 0
	MOVWF	PORTC
	BSF	PORTD, 0
	BSF	selector, 0
	RETURN
    display1:
	MOVF	display+1, 0
	MOVWF	PORTC
	BSF	PORTD, 1
	BCF	selector, 0
	RETURN

int_tmr1:
    reset_tmr1 0x85, 0xA3  ; Reiniciamos TMR1 para 500ms
    INCF    PORTA
    RETURN

int_tmr2:
    BCF	    TMR2IF  
    BTFSC   PORTB, 4
    GOTO    $+3
    BSF	    PORTB, 4
    GOTO    $+2
    BCF	    PORTB, 4
    RETURN

PSECT code, delta=2, abs
ORG 100h		    ; Posición 0100h para el código

;-------- CONFIGURACION --------
main:
    CALL    config_clk	    ; Configuración del reloj
    CALL    config_io
    CALL    config_tmr0
    CALL    config_tmr1
    CALL    config_tmr2
    CALL    config_int
    BANKSEL PORTA

;-------- LOOP RRINCIPAL --------
loop:
    MOVF    PORTA, 0
    MOVWF   valor
    CALL    separar_nibbles
    CALL    config_display
    GOTO    loop		; Saltar al loop principal

;-------- SUBRUTINAS -----------

separar_nibbles:
    MOVF    valor, 0
    ANDLW   0x0F
    MOVWF   nibbles
    SWAPF   valor, 0
    ANDLW   0x0F
    MOVWF   nibbles+1
    RETURN

config_display:
    MOVF    nibbles, 0
    CALL    tabla
    MOVWF   display
    MOVF    nibbles+1, 0
    CALL    tabla
    MOVWF   display+1
    RETURN

config_clk:
    BANKSEL OSCCON
    BCF	    IRCF2	    ; IRCF/011/500 kHz (frecuencia de oscilación)
    BSF	    IRCF1
    BSF	    IRCF0
    BSF	    SCS		    ; Reloj interno
    RETURN

config_io:
    BANKSEL ANSEL	
    CLRF    ANSEL	    ; I/O digitales
    CLRF    ANSELH
    BANKSEL TRISA
    CLRF    TRISA	    ; PORTA como salida
    BCF	    TRISB, 4
    CLRF    TRISC
    CLRF    TRISD
    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    RETURN

config_tmr0:
    BANKSEL OPTION_REG
    BCF	    T0CS
    BCF	    PSA
    BCF	    PS2		    ; Prescaler/010/1:8
    BSF	    PS1
    BCF	    PS0
    reset_tmr0
    RETURN

config_tmr1:
    BANKSEL T1CON	    ; Cambiar a banco 00
    BSF	    TMR1ON	    ; Encender TMR1
    BCF	    TMR1CS	    ; Configurar con reloj interno
    BCF	    T1OSCEN	    ; Apagar oscilador LP
    BSF	    T1CKPS1	    ; Configurar prescaler 1:4
    BCF	    T1CKPS0	    
    BCF	    TMR1GE	    ; TRM1 siempre contando 
    reset_tmr1 0x85, 0xA3		    
    RETURN

config_tmr2:
    BANKSEL T2CON
    BSF	    T2CKPS1	    ; Prescaler/11/1:16
    BSF	    T2CKPS0
    BSF	    TMR2ON
    BSF	    TOUTPS3	    ; Postscaler/1111/1:16
    BSF	    TOUTPS2
    BSF	    TOUTPS1
    BSF	    TOUTPS0
    BANKSEL PR2
    MOVLW   245
    MOVWF   PR2
    RETURN

config_int:
    BANKSEL PIE1
    BSF	    TMR1IE
    BSF	    TMR2IE
    BANKSEL INTCON  
    BSF	    GIE
    BSF	    PEIE
    BSF	    T0IE
    BCF	    T0IF
    BCF	    TMR1IF
    BCF	    TMR2IF
    RETURN

ORG 200h		    ; Establecer posición para la tabla
tabla:
    CLRF    PCLATH	    ; Limpiar registro PCLATH
    BSF	    PCLATH, 1	    ; Posicionar PC en 0x02xxh
    ANDLW   0x0F	    ; AND entre W y literal 0x0F
    ADDWF   PCL		    ; ADD entre W y PCL 
    RETLW   00111111B	    ; 0	en 7 seg
    RETLW   00000110B	    ; 1 en 7 seg
    RETLW   01011011B	    ; 2 en 7 seg
    RETLW   01001111B	    ; 3 en 7 seg
    RETLW   01100110B	    ; 4 en 7 seg
    RETLW   01101101B	    ; 5 en 7 seg
    RETLW   01111101B	    ; 6 en 7 seg
    RETLW   00000111B	    ; 7 en 7 seg
    RETLW   01111111B	    ; 8 en 7 seg
    RETLW   01101111B	    ; 9 en 7 seg
    RETLW   01110111B	    ; 10 en 7 seg
    RETLW   01111100B	    ; 11 en 7 seg
    RETLW   00111001B	    ; 12 en 7 seg
    RETLW   01011110B	    ; 13 en 7 seg
    RETLW   01111001B	    ; 14 en 7 seg
    RETLW   01110001B	    ; 15 en 7 seg

END