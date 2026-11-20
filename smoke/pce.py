#!/usr/bin/env python3
# Writes the PC Engine smoke ROM (scripts/smoke.sh): a 32 KB HuCard that
# sets up the CPU and loops. Our own, hand assembled:
#   smoke/pce.py <out.pce>
# At power-on bank 0 is mapped at $E000-$FFFF; the reset vector is $FFFE.
import sys

code = bytes([
    0x78,        # sei
    0xD4,        # csh   (7.16 MHz)
    0xD8,        # cld
    0x80, 0xFE,  # bra *
])

bank = bytearray(0x2000)
bank[0:len(code)] = code
for vector in range(0x1FF6, 0x2000, 2):  # IRQ2 IRQ1 TIMER NMI RESET: all $E000
    bank[vector] = 0x00
    bank[vector + 1] = 0xE0

with open(sys.argv[1], "wb") as f:
    f.write(bytes(bank) * 4)
