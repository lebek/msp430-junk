/*-
 * Copyright (c) 2011 Peter Le Bek
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <msp430g2231.h>
#include <legacymsp430.h>

#define TXD BIT1
#define BUTTON BIT3

#define SYMBOL_LEN 10
#define BIT_TIME 52

unsigned int tx_frame = 0;


/*
 *  INIT
 */

void
init_clocks (void)
{
    /* Set clock to 1MHz / 8 = 125KHz */
    BCSCTL1 = CALBC1_1MHZ;
    DCOCTL = CALDCO_1MHZ;
    BCSCTL2 &= ~(DIVS_3);
}

void
init_uart_timer (void)
{
    TACCTL0 = OUT; /* TXD idle as 1 */

    TACTL = TASSEL_2 + MC_2 + ID_3; /* Continuous mode, SMCLK, /8 */

    P1SEL |= TXD; /* Use timer function for TXD */
    P1DIR |= TXD; /* Set TXD to output direction */
}

void
init_button (void)
{
    P1DIR &= ~BUTTON; /* Set to input direction */
    P1OUT |= BUTTON; /* Set pull up resistor */
    P1REN |= BUTTON; /* Enable pull up resistor */
    P1IES |= BUTTON; /* Interrupt from high to low */
    P1IFG &= ~BUTTON; /* Clear interrupt flag */
    P1IE |= BUTTON; /* Enable interrupts */
}


/*
 *  UART
 */

void
uart_putc (char c)
{
    while (TACCTL0 & CCIE); /* Wait for current transmission to complete */

    tx_frame = (unsigned int) c;
    tx_frame |= 0x100; /* Stop bit */
    tx_frame = tx_frame << 1; /* Start bit */

    TACCR0 = TAR; /* Sync with counter */
    TACCR0 += BIT_TIME; /* Schedule first transmission interrupt */
    TACCTL0 = OUTMOD0 + CCIE; /* TXD idle as 1, enable interrupts */
}

void
uart_puts (const char *s)
{
    while (*s) uart_putc (*s++);
}


/*
 *  ISRs
 */

interrupt(TIMERA0_VECTOR)
timera_isr (void)
{
    TACCR0 += BIT_TIME; /* Schedule next transmission interrupt */

    if (tx_frame & 0x1)
        TACCTL0 &= ~OUTMOD2; /* 1 */
    else
        TACCTL0 |=  OUTMOD2; /* 0 */

    tx_frame = tx_frame >> 1; /* Next bit */

    if (!tx_frame) /* If done */
        TACCTL0 &= ~CCIE; /* Stop interrupts */

    TACCTL0 &= ~CCIFG; /* Clear interrupt flag */
}

interrupt(PORT1_VECTOR)
port1_isr (void)
{
    P1IFG &= ~BUTTON; /* Clear interrupt flag */
    __bic_SR_register_on_exit (LPM1_bits); /* Wake CPU */
}


/*
 *  MSP430-LP UART hello world
 */

int
main (void)
{
    /* Hold watchdog, we don't need it */
    WDTCTL = WDTPW + WDTHOLD;

    init_clocks ();
    init_uart_timer ();
    init_button ();

    while (1) {
        __bis_SR_register (LPM1_bits | GIE); /* Sleep CPU until button press */
        uart_puts ("hello, world\n");
    }

    return 0;
}
