#!/usr/bin/env python3
# Writes the Super Nintendo smoke ROM (scripts/smoke.sh): 32 KB LoROM that
# turns the screen on with a red backdrop and loops. Our own, hand assembled:
#   smoke/snes.py <out.sfc>
import sys

code = bytes([
    0x78,                    # sei
    0x18, 0xFB,              # clc; xce          (native mode, 8-bit A / X / Y)
    0xA9, 0x8F, 0x8D, 0x00, 0x21,  # lda #$8F; sta $2100   forced blank
    0x9C, 0x21, 0x21,        # stz $2121         palette entry 0 (backdrop)
    0xA9, 0x1F, 0x8D, 0x22, 0x21,  # lda #$1F; sta $2122   red, low byte
    0x9C, 0x22, 0x21,        # stz $2122         high byte
    0xA9, 0x0F, 0x8D, 0x00, 0x21,  # lda #$0F; sta $2100   screen on, full brightness
    0x80, 0xFE,              # bra *
])
rti = 0x8040                 # every other vector: rti

rom = bytearray(0x8000)
rom[0:len(code)] = code
rom[rti - 0x8000] = 0x40

header = 0x7FC0
title = b"MULTITAP SMOKE".ljust(21, b" ")
rom[header:header + 21] = title
rom[header + 0x15] = 0x20    # LoROM, slow
rom[header + 0x16] = 0x00    # ROM only
rom[header + 0x17] = 0x05    # 32 KB
rom[header + 0x18] = 0x00    # no RAM
rom[header + 0x19] = 0x01    # North America
rom[header + 0x1A] = 0x00
rom[header + 0x1B] = 0x00    # version
rom[header + 0x1C:header + 0x20] = bytes([0xFF, 0xFF, 0x00, 0x00])

def vector(offset, address):
    rom[offset] = address & 0xFF
    rom[offset + 1] = address >> 8

for offset in range(0x7FE4, 0x7FF0, 2):  # native: COP BRK ABORT NMI - IRQ
    vector(offset, rti)
for offset in range(0x7FF4, 0x7FFC, 2):  # emulation: COP - ABORT NMI
    vector(offset, rti)
vector(0x7FFC, 0x8000)                    # emulation RESET
vector(0x7FFE, rti)                       # emulation IRQ/BRK

checksum = sum(rom) & 0xFFFF
vector(header + 0x1E, checksum)
vector(header + 0x1C, checksum ^ 0xFFFF)

with open(sys.argv[1], "wb") as f:
    f.write(rom)
