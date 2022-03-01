; Archivo:	mainL6.s
; Dispositivo:	PIC16F887
; Autor:	Jeferson Noj
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Aumento de PORTA cada segundo con TMR1
; Hardware:	LEDs en PORTA
;
; Creado: 28 feb, 2022
; Última modificación:  28 feb, 2022

PROCESSOR 16F887
#include <xc.inc>

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

reset_tmr1 MACRO TMR1_H, TMR1_L	 ; Esta es la forma correcta
    BANKSEL TMR1H
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM

PSECT udata_bank0	    ; Memoria común
  tmr1_var:	DS 2	    ; Almacena el valor del PORTA

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
    BTFSC   TMR1IF	    ; Evaluar bandera de interrupción de TMR0
    CALL    int_tmr1
pop:			   
    SWAPF   STATUS_TEMP,0   ; Intercambiar nibbles de STATUS_TEMP y guardar en W
    MOVWF   STATUS	    ; Mover valor de W a registro STATUS
    SWAPF   W_TEMP, 1	    ; Intercambiar nibbles de W_TEMP y guardar en este mismo registro
    SWAPF   W_TEMP, 0	    ; Intercambiar nibbles de W_TEMP y gardar en W
    RETFIE

;------ Subrutinas de Interrupción -----
int_tmr1:
    reset_tmr1 0x0B, 0xDC  ; Reiniciamos TMR1 para 500ms
    INCF    tmr1_var	   ; Incremento en PORTA
    MOVF    tmr1_var, 0
    SUBLW   2
    BTFSS   STATUS, 2
    GOTO    $+3 
    INCF    PORTA
    CLRF    tmr1_var
    RETURN

PSECT code, delta=2, abs
ORG 100h		    ; Posición 0100h para el código

;-------- CONFIGURACION --------
main:
    CALL    config_clk	    ; Configuración del reloj
    CALL    config_io
    CALL    config_tmr1
    CALL    config_int
    BANKSEL PORTA

;-------- LOOP RRINCIPAL --------
loop:
    GOTO    loop		; Saltar al loop principal

config_clk:
    BANKSEL OSCCON
    BSF	    IRCF2	    ; IRCF/110/4MHz (frecuencia de oscilación)
    BSF	    IRCF1
    BCF	    IRCF0
    BSF	    SCS		    ; Reloj interno
    RETURN

config_io:
    BANKSEL ANSEL	
    CLRF    ANSEL	    ; I/O digitales
    CLRF    ANSELH
    BANKSEL TRISA
    CLRF    TRISA	    ; PORTA como salida
    BANKSEL PORTA
    CLRF    PORTA
    RETURN

config_tmr1:
    BANKSEL T1CON	    ; Cambiar a banco 00
    BSF	    TMR1ON	    ; Encender TMR1
    BCF	    TMR1CS	    ; Configurar con reloj interno
    BCF	    T1OSCEN	    ; Apagar oscilador LP
    BSF	    T1CKPS1	    ; Configurar prescaler 1:8
    BSF	    T1CKPS0	    
    BCF	    TMR1GE	    ; TRM1 siempre contando 
    reset_tmr1 0x0B, 0xDC		    
    RETURN

config_int:
    BANKSEL PIE1
    BSF	    TMR1IE
    BANKSEL INTCON  
    BSF	    GIE
    BSF	    PEIE
    BCF	    TMR1IF
    RETURN
