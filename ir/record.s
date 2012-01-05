;;;
;;; Copyright (c) 2012 Peter Le Bek
;;; All rights reserved.
;;;
;;;
;;; Infrared signal recorder
;;;
;;; For assembly with Michael Kohn's naken430asm
;;;
;;; R10 = fei_arr index
;;; R11 = [ 0x000 0 0 (READING) (ALIVE) ]
;;; R12 = call param
;;;

.include "msp430g2x31.inc"

        ALIVE   equ 0x01
        READING equ 0x02

        CALBC1_1MHZ equ 0x10FF
        CALDCO_1MHZ equ 0x10FE

        TXD  equ 0x0002
        RLED equ 0x0001
        GLED equ 0x0040

        IRR equ 0x0010
        BTN equ 0x0008

        MAX_INTERVAL equ 5000

        .org 0xF800
uart_tx:
        ;; Pad octet with start and stop bits
        bis.w #0x0100,R12
        rla.w R12
uart_tx_delay:
        ;;
        ;; Next two instructions determine the delay between bit transmissions.
        ;; They're a function of:
        ;;
        ;;     { desired baudrate, MCLK frequency, intraloop overhead,
        ;;       extraloop overhead }
        ;;
        ;; The forumla is:
        ;;
        ;;     (MCLK frequency / desired baudrate) - (extraloop overhead)
        ;;     ----------------------------------------------------------
        ;;                          intraloop overhead
        ;;
        ;; The quotient result is the number of loop interations and is stored
        ;; in R5. The remainder is accounted for with an equal number of NOPs.
        ;;
        ;; The current intraloop overhead is 3 cycles and extraloop overhead is
        ;; 16 cycles. MCLK is set at 1MHz, and the desired baudrate is 9600.
        ;;
        mov #29,R5
        nop

uart_tx_loop:
        dec.w R5
        jnz uart_tx_loop

        ;; Take the next bit and transmit
        rra.w R12
        jc uart_tx_1
uart_tx_0:
        bic.b #0x02,&P1OUT
        jmp uart_tx_delay
uart_tx_1:
        bis.b #0x02,&P1OUT
        jnz uart_tx_delay       ; RRA sets Z when we're done

        ret

reset:
        ;; No watchdog
        mov #0x5A80,&WDTCTL

        ;; Init stack
        mov.w #0x0280,SP

        ;; Init program state
        clr R11

        ;; TXD and LEDs to out direction
        bis.b #(TXD|RLED|GLED),&P1DIR

        ;; TXD idling at 1, GLED off
        bis.b #TXD,&P1OUT
        bic.b #GLED,&P1OUT

        ;; RLED on
        bis.b #RLED,&P1OUT

        ;; Button and IR receiver to in direction, waiting for interrupts
        bic.b #(BTN|IRR),&P1DIR
        bis.b #(BTN|IRR),&P1OUT
        bis.b #(BTN|IRR),&P1REN
        bis.b #(BTN|IRR),&P1IES
        bic.b #(BTN|IRR),&P1IFG
        bis.b #(BTN|IRR),&P1IE

        ;; MCLK to 1MHz with DCO
        clr.b &DCOCTL
        mov.b &CALBC1_1MHZ,&BCSCTL1
        mov.b &CALDCO_1MHZ,&DCOCTL

        bis.b #DIVS_0,&BCSCTL2  ; SMCLK = 1 MHz /1
        bis.w #CCIE,&TACCTL0    ; Set timer interrupt
        mov.w #MAX_INTERVAL,&TACCR0

        bis.b #0x58,SR          ; Enter LPM1 with GIE

        jmp hang                ; Never reached

p1_isr:
        bit.b #BTN,&P1IFG
        jc p1_isr_btn
p1_isr_irr:
        bic.b #IRR,&P1IFG

        bit.b #ALIVE,R11        ; IF !ALIVE
        jz p1_isr_ret           ;   return

        bit.b #READING,R11      ; IF ALIVE && READING
        jc p1_isr_store         ;   store fei

        ;; ELSE ALIVE && NOT READING
        mov.w #fei_arr,R10      ; Reset fei_arr index
        bis.b #READING,R11      ; Enter READING state
        bis.w #(TASSEL_2|MC_1|TACLR),&TACTL
        jmp p1_isr_ret
p1_isr_store:
        mov.w &TAR,0(R10)
        incd.w R10                ; Increment fei_arr index

        bis.w #(TASSEL_2|MC_1|TACLR),&TACTL ; Clear and start timer in up mode
        jmp p1_isr_ret
p1_isr_btn:
        bic.b #BTN,&P1IFG
        xor.b #ALIVE,R11        ; Toggle program state
        bic.b #READING,R11
        xor.b #(GLED|RLED),&P1OUT ; Toggle LEDs
p1_isr_ret:
        reti

ta0_isr:
        ;; IFG cleared automatically
        mov.w #MC_0,&TACTL      ; Halt timer

        mov.w #fei_arr,R6
ta0_send_loop:
        mov.b 0(R6),R12
        call #uart_tx

        mov.b 1(R6),R12
        call #uart_tx

        incd.w R6
        cmp R6,R10
        jnz ta0_send_loop

        call #uart_tx
        call #uart_tx

        mov.w #fei_arr,R10      ; Reset fei_arr index

        bic.b #READING,R11
        bic.b #ALIVE,R11
        xor.b #(GLED|RLED),&P1OUT ; Toggle LEDs
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

        .org 0x0200
fei_arr:
        dw 0x1234      ; Base of falling-edge interval array

