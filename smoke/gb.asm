; Smoke-test content for Game Boy cores: a valid header, then it halts in a
; loop. Written for this repository (no third-party ROM needed). Assembled by
; scripts/smoke.sh with rgbds; rgbfix writes the logo and checksums.
SECTION "entry", ROM0[$100]
    nop
    jp start
    ds $150 - @, 0

SECTION "main", ROM0[$150]
start:
    di
.loop:
    halt
    nop
    jr .loop
