PROCESSOR 16F887
#include <xc.inc>

reset_tmr0 MACRO
    BANKSEL TMR0	    ; Cambiar de banco
    MOVLW   240		    ; 1 ms = 4(1/500Khz)(256-N)(256)
			    ; N = 256 - (0.001s*500Khz)/(4*256) = 252
    MOVWF   TMR0	    ; Configurar tiempo de retardo
    BCF	    T0IF	    ; Limpiar bandera de interrupción
    ENDM

reset_tmr1 MACRO TMR1_H, TMR1_L	 ; Esta es la forma correcta
    BANKSEL TMR1H
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM