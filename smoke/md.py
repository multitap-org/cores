#!/usr/bin/env python3
# Writes the Mega Drive smoke ROM (scripts/smoke.sh): 64 KB that sets up the
# 68000 and loops. Our own, hand assembled:
#   smoke/md.py <out.md>
# The vector table's first two longs are the stack pointer and the reset PC.
import struct
import sys

rom = bytearray(0x10000)
struct.pack_into(">II", rom, 0, 0x00FFFE00, 0x00000200)
for vector in range(8, 0x100, 4):   # every exception: the same loop
    struct.pack_into(">I", rom, vector, 0x00000206)
rom[0x100:0x110] = b"SEGA MEGA DRIVE "
rom[0x150:0x160] = b"SMOKE           "
struct.pack_into(">II", rom, 0x1A0, 0, len(rom) - 1)   # ROM start / end
code = bytes([
    0x46, 0xFC, 0x27, 0x00,  # move.w #$2700,sr   (supervisor, interrupts off)
    0x60, 0xFE,              # bra.s *
    0x60, 0xFE,              # $206: bra.s *       (exceptions)
])
rom[0x200:0x200 + len(code)] = code

with open(sys.argv[1], "wb") as f:
    f.write(rom)
