#!/usr/bin/env python3
# Writes the DOS smoke program (scripts/smoke.sh): a .COM that loops. Our own:
#   smoke/dos.py <out.com>
import sys

code = bytes([
    0xFA,        # cli
    0xEB, 0xFE,  # jmp $
])

with open(sys.argv[1], "wb") as f:
    f.write(code)
