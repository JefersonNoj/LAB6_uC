; Archivo:	mainL6.s
; Dispositivo:	PIC16F887
; Autor:	Jeferson Noj
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	LED intermitente con TMR2 y contador de segundos
; Hardware:	LED en PORTB y displays 7 seg en PORTC
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
  SEGUNDOS:	DS 1	    ; Contador de segundos
  selector:	DS 1	    ; Selector de displays
  decenas:	DS 1	    ; Contador de las decenas
  unidades:	DS 1	    ; Contador de las unidades
  temp1:	DS 1	    ; Registro temporal para división
  temp2:	DS 1	    ; Registro temporal para división
  display:	DS 2	    ; Registro que almacena el valor para el display

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
    CALL    int_tmr0	    ; Si ocurre interrupción, ir a subrutina de TMR0
    BTFSC   TMR1IF	    ; Evaluar bandera de interrupción de TMR1
    CALL    int_tmr1	    ; Si ocurre interrupción, ir a subrutina de TMR1
    BTFSC   TMR2IF	    ; Evaluar bandera de interrupción de TMR2
    CALL    int_tmr2	    ; Si ocurre interrupción, ir a subrutina de TMR2
pop:			   
    SWAPF   STATUS_TEMP,0   ; Intercambiar nibbles de STATUS_TEMP y guardar en W
    MOVWF   STATUS	    ; Mover valor de W a registro STATUS
    SWAPF   W_TEMP, 1	    ; Intercambiar nibbles de W_TEMP y guardar en este mismo registro
    SWAPF   W_TEMP, 0	    ; Intercambiar nibbles de W_TEMP y gardar en W
    RETFIE

;------ Subrutinas de Interrupción -----
int_tmr0:
    reset_tmr0		    ; Reiniciar TMR0
    CLRF    PORTD	    ; Limpiar PORTD (apagar ambos displays)
    BTFSC   selector, 0	    ; Evaluar bit 0 del selector de displays
    GOTO    display1	    ; Si el bit 0 del selector es 1, ir a display1
    display0:
	MOVF	display, 0	; Mover valor de registro display a W
	MOVWF	PORTC		; mover dicho valor a PORTC
	BSF	PORTD, 0	; Encender display conectado al pin RD0
	BSF	selector, 0	; Setear bit 0 del selector para ir a display1 en proxima interrupción
	RETURN
    display1:
	MOVF	display+1, 0	; Mover valor de registro display+1 a W
	MOVWF	PORTC		; mover dicho valor a PORTC
	BSF	PORTD, 1	; Encender display conectado al pin RD1
	BCF	selector, 0	; Limpiar bit 0 del selector para ir a display0 en próxima interrupción
	RETURN

int_tmr1:
    reset_tmr1 0x85, 0xA3   ; Reiniciar TMR0
    INCF    SEGUNDOS	    ; Incrementar contador de segundos
    MOVF    SEGUNDOS, 0	    ; Mover valor del contador a W
    SUBLW   60		    ; Restar la literal 60 
    BTFSC   STATUS, 2	    ; Evaular bandera ZERO para determinar si se han contado 60s
    CLRF    SEGUNDOS	    ; Si bandera ZERO = 1, limpiar reiniciar contador de segundos
    RETURN  

int_tmr2:
    BCF	    TMR2IF	    ; Limpiar bandera de interrupción del TMR2
    BTFSC   PORTB, 4	    ; Evaluar estado del LED en RB4
    GOTO    $+3		    ; Saltar a la tercera interrupción siguiente (apagar LED)
    BSF	    PORTB, 4	    ; Encender LED en pin RB4
    GOTO    $+2		    ; Saltar a la segunda interrupción siguiente (salir de subrutina)
    BCF	    PORTB, 4	    ; Apagar LED en pin RB4
    RETURN

PSECT code, delta=2, abs
ORG 100h		    ; Posición 0100h para el código

;-------- CONFIGURACION --------
main:
    CALL    config_clk	    ; Configuración del reloj
    CALL    config_io	    ; Configuración de I/O
    CALL    config_tmr0	    ; Configuración del TMR0
    CALL    config_tmr1	    ; Configuración del TMR1
    CALL    config_tmr2	    ; Configuración del TMR2
    CALL    config_int	    ; Configuración de interrupciones 
    CLRF    SEGUNDOS	    ; Limpiar contador de segundos 
    BANKSEL PORTA	
    CLRF    PORTC

;-------- LOOP RRINCIPAL --------
loop:
    CALL    obtenerDU		; Obtener decenas y unidades de segundos
    CALL    config_display	; Obtener valores para display 7 seg
    GOTO    loop		; Saltar al loop principal

;-------- SUBRUTINAS -----------

obtenerDU:
    CLRF    decenas		; Limpiar registro de la decenas
    MOVF    SEGUNDOS, 0		; Guardar valor del contador de segundos al registro temp1
    MOVWF   temp1		
    MOVF    temp1, 0		; Guardar valor del registro temp1 en registro temp2
    MOVWF   temp2
    MOVLW   10			; Mover literal 10 a W
    SUBWF   temp1, 1		; Restar 10 al registro temp1 y guardar en este registro
    BTFSS   STATUS, 0		; Evaluar bit de CARRY del registro STATUS
    GOTO    obtenerU		; Saltar a la instrucción indicada si ocurrió overflow en el rango
    MOVF    temp1, 0		; Guardar valor de registro temp1 en registro temp2 
    MOVWF   temp2
    INCF    decenas		; Incrementear el condador de las decenas   
    GOTO    $-7			; Saltar a la séptima instrucción anterior (repetir resta) 
    obtenerU:
	MOVF    temp2, 0	; Mover valor de registro temp2 al contador de unidades
	MOVWF   unidades	
	RETURN

config_display:
    MOVF    unidades, 0	    ; Mover valor de contador de unidades a W
    CALL    tabla	    ; Obtener valor correspondiente para display 7 seg
    MOVWF   display	    ; Mover valor de W al registro display
    MOVF    decenas, 0	    ; Mover valor de contador de decenas a W
    CALL    tabla	    ; Obtener valor correspondiente para display 7 seg
    MOVWF   display+1	    ; Mover valor de W al registro display+1
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
    BCF	    TRISB, 4	    ; Pin RB4 como salida
    CLRF    TRISC	    ; PORTC como salida
    CLRF    TRISD	    ; PORTC como salida
    BANKSEL PORTA
    CLRF    PORTA	    ; Limpiar PORTA
    CLRF    PORTB	    ; Limpiar PORTB
    CLRF    PORTC	    ; Limpiar PORTC
    CLRF    PORTD	    ; Limpiar PORTD
    RETURN

config_tmr0:
    BANKSEL OPTION_REG
    BCF	    T0CS	    ; 
    BCF	    PSA		    ; Asignar prescaler a TMR0
    BCF	    PS2		    ; Prescaler/010/1:8
    BSF	    PS1
    BCF	    PS0
    reset_tmr0		    ; Reiniciar TMR0
    RETURN

config_tmr1:
    BANKSEL T1CON	    ; Cambiar a banco 00
    BSF	    TMR1ON	    ; Encender TMR1
    BCF	    TMR1CS	    ; Configurar con reloj interno
    BCF	    T1OSCEN	    ; Apagar oscilador LP
    BSF	    T1CKPS1	    ; Configurar prescaler 1:4 / 10
    BCF	    T1CKPS0	    
    BCF	    TMR1GE	    ; TRM1 siempre contando 
    reset_tmr1 0x85, 0xA3   ; Reiniciar TMR1 
    RETURN

config_tmr2:
    BANKSEL T2CON
    BSF	    T2CKPS1	    ; Prescaler/11/1:16
    BSF	    T2CKPS0
    BSF	    TMR2ON	    ; Encender TMR2
    BSF	    TOUTPS3	    ; Postscaler/1111/1:16
    BSF	    TOUTPS2
    BSF	    TOUTPS1
    BSF	    TOUTPS0
    BANKSEL PR2		    ; Cambiar de banco
    MOVLW   245		    ; Mover literal 245 a registro PR2
    MOVWF   PR2
    RETURN

config_int:
    BANKSEL PIE1	    
    BSF	    TMR1IE	    ; Habilitar interrupción de TRM1
    BSF	    TMR2IE	    ; Habilitar interrupción de TRM2
    BANKSEL INTCON	    
    BSF	    GIE		    ; Habilitar interrupciones globales
    BSF	    PEIE	    ; Habilitar interrupciones periféricas
    BSF	    T0IE	    ; Habilitar interrupción de TRM0
    BCF	    T0IF	    ; Limpiar bandera de interrupción de TRM0
    BCF	    TMR1IF	    ; Limpiar bandera de interrupción de TRM1
    BCF	    TMR2IF	    ; Limpiar bandera de interrupción de TRM2
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