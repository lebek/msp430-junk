;;;
;;; Copyright (c) 2012 Peter Le Bek
;;; All rights reserved.
;;;

.include "msp430g2x31.inc"

        LFXT1S0 equ 0x10

        CALBC1_1MHZ equ 0x10FF
        CALDCO_1MHZ equ 0x10FE

        RLED equ 0x0001
        GLED equ 0x0040

        XLED  equ 0x0010

        BTN equ 0x0008

        .org 0xF800

reset:
        ;; No watchdog
        mov #0x5A80,&WDTCTL

        ;;  Init stack
        mov.w #0x0280,SP

        ;; LEDs to out direction
        bis.b #(RLED|GLED|XLED),&P1DIR

        ;; RLED on, rest off
        bic.b #(GLED|XLED),&P1OUT
        bis.b #RLED,&P1OUT

        ;; Button to in direction, waiting for interrupts
        bic.b #BTN,&P1DIR
        bis.b #BTN,&P1OUT
        bis.b #BTN,&P1REN
        bis.b #BTN,&P1IES
        bic.b #BTN,&P1IFG
        bis.b #BTN,&P1IE

        ;; MCLK to 1MHz with DCO
        mov.b &CALBC1_1MHZ,&BCSCTL1
        mov.b &CALDCO_1MHZ,&DCOCTL
        bis.b #DIVS_1,&BCSCTL2  ; SMCLK = 1 MHz /2

        ;; Crystal (LFXT1) in low frequency mode to support G2231 etc
        bic.w #OSCOFF,SR
        bic.b #XTS,&BCSCTL1
        mov.b #LFXT1S0,&BCSCTL3

        bis.w #CCIE,&TACCTL0   ; Set timer interrupt
        bis.w #(TASSEL_2|ID_3|MC_2|TACLR),&TACTL ; SMCLK, /8, 0->0FFFFh, clear
        bis.b #0x58,SR          ; Enter LPM1 with GIE

        jmp hang                ; Never reached

p1_isr:
        bic.b #BTN,&P1IFG
        xor.b #(RLED|GLED),&P1OUT

        ;; Toggle clock source and divider (crystal runs slow)
        xor.w #(TASSEL_1|TASSEL_2|ID_3|TACLR),&TACTL
        reti

ta0_isr:
        xor.b #XLED,&P1OUT
        reti

hang:
        jmp hang

        .org 0xFFE0
vectors:
        ;; routine                addr   interrupt
        dw hang                 ; 0xFFE0
        dw hang                 ; 0xFFE2
        dw p1_isr               ; 0xFFE4 P1IFG.0 to P1IFG.7
        dw hang                 ; 0xFFE6 P2IFG.6 to P2IFG.7
        dw hang                 ; 0xFFE8 USIIFG, USISTTIFG
        dw hang                 ; 0xFFEA ADC10IFG
        dw hang                 ; 0xFFEC
        dw hang                 ; 0xFFEE
        dw hang                 ; 0xFFF0 TACCR1 CCIFG, TAIFG
        dw ta0_isr              ; 0xFFF2 TACCR0 CCIFG
        dw hang                 ; 0xFFF4 WDTIFG
        dw hang                 ; 0xFFF6
        dw hang                 ; 0xFFF8
        dw hang                 ; 0xFFFA
        dw hang                 ; 0xFFFC NMIIFG, OFIFG, ACCVIFG
        dw reset                ; 0xFFFE PORIFG, RSTIFG, WDTIFG, KEYV
