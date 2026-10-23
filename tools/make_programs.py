#!/usr/bin/env python3
"""Generate the demo and bounded board-memory selftest, without an assembler."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def i(op, rs, rt, imm):
    return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xffff)
def r(rs, rt, rd, fn):
    return (rs << 21) | (rt << 16) | (rd << 11) | fn
def write(name, program):
    assert len(program) <= 1024
    # CpuSystem initializes unspecified ROM words to unsupported instructions.
    (ROOT/'programs'/name).write_text(''.join(f'{w:08x}\n' for w in program))
# $1=MMIO LED address, increment output, delay, loop. No delay slots.
write('demo.hex', [i(0xf,0,1,0xffff), i(9,0,2,0), i(9,2,2,1),
    i(0x2b,1,2,0), i(0xf,0,3,0x0040), i(9,3,3,-1), i(5,3,0,-2),
    (2<<26)|2])
# Byte lanes, signed loads, load-use, HI/LO, MMIO write/read, then explicit halt.
write('selftest.hex', [i(9,0,1,-128), i(0x2b,0,1,0), i(0x24,0,2,0),
    i(0x20,0,3,0), r(2,3,4,0x21), i(0x29,0,2,2), i(0x25,0,5,2),
    r(2,5,0,0x19), r(0,0,6,0x12), i(0xf,0,7,0xffff), i(0x2b,7,6,0),
    i(0x23,7,8,0), i(0x2b,0,8,4), 0xffffffff, i(0x2b,7,0,0)])
