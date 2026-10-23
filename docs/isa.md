# CPU architecture and memory contract

This is a 32-bit educational MIPS-encoded integer CPU, not a MIPS32-compliant
processor. Normal instructions use the standard opcode/function fields.
There are **no branch delay slots**. Assemble programs for this contract;
unmodified binaries that depend on MIPS delay slots are not compatible.

## Instructions

| Family | Implemented instructions |
| --- | --- |
| Register arithmetic | add, addu, sub, subu, slt, sltu |
| Register logic | and, or, xor, nor |
| Shifts | sll, srl, sra, sllv, srlv, srav |
| Immediate | addi, addiu, slti, sltiu, andi, ori, xori, lui |
| Loads | lb, lbu, lh, lhu, lw |
| Stores | sb, sh, sw |
| Conditional branches | beq, bne, blez, bgtz, bltz, bgez |
| Jumps | j, jal, jr, jalr |
| HI/LO | mfhi, mflo, mthi, mtlo, mult, multu, div, divu |

These are 50 instructions, plus `nop` as `sll $0,$0,0`.
`$0` always reads zero and ignores writes. All other registers reset to zero.
The reset PC defaults to byte address zero and is parameterized.

- All additions/subtractions wrap modulo 2^32, including add/addi/sub. There
  are no overflow exceptions. Signed comparisons and arithmetic right shifts
  use two's complement. Variable shifts use the low five bits of `rs`.
- Arithmetic, comparison, and address immediates are sign extended. In
  particular, sltiu compares unsigned values after sign extending the immediate.
  andi/ori/xori zero extend; lui places the immediate in the high 16 bits.
- Data is little endian. Halfwords require two-byte alignment; words require
  four-byte alignment. Addresses are byte addresses; the memory adapter
  indexes words with address >> 2 and preserves the byte lanes.
- Branch target: PC + 4 + (sign-extended immediate << 2). Jump target:
  {(PC+4)[31:28], instruction[25:0], 2'b00}. jr/jalr use the forwarded `rs`.
- jal writes PC+4 to `$31`; jalr writes PC+4 to `rd`. Every younger
  instruction on an incorrect path is discarded on a resolved redirect.
  Correct predictions continue without a squash. There is no delay slot.
- Use canonical encodings; reserved operand fields are not exhaustively
  validated. Unimplemented opcode/function cases fault instead of acting as nop.
- HI/LO reset to zero. Multiply and divide use a shared iterative unit that
  holds EX and younger stages while older instructions drain. Normal operations
  perform 32 iteration steps plus start/completion handoff cycles; there is no
  large combinational divide path. Signed division truncates toward zero and
  the remainder has the dividend's sign. Division by zero deterministically
  returns LO=0xffffffff, HI=dividend. INT_MIN / -1 returns LO=INT_MIN, HI=0.
  These exceptional-case choices do not implement MIPS exception semantics.

Not provided: CP0, exception handlers, interrupts, virtual memory, atomics,
branch-likely/link branch variants, unaligned merge loads/stores, floating
point, or operating-system support.

## Five stages and hazards

1. **IF:** issue a synchronous instruction-memory read at the current PC.
   Memory registers the instruction at the edge; the core registers matching
   PC and validity metadata at the same edge.
2. **ID:** decode that instruction, read two registers, identify actual source
   usage, and detect a dependent load in EX. WB has an explicit bypass to ID.
3. **EX:** select forwarded register operands, execute the ALU, calculate memory
   addresses, and resolve control transfers against their saved predictions.
   EX/MEM forwarding has priority
   over MEM/WB. The address of a load is never forwarded as loaded data.
4. **MEM:** issue a synchronous RAM read or byte-enabled store. The RAM read
   output registers at the edge leading into WB.
5. **WB:** select the registered load data or ALU/link result, extend loads,
   and write the register file at the end of WB. Retirement observation uses
   this same transaction.

A load-use dependency holds PC and the synchronous instruction-memory output,
keeps ID metadata, and injects an invalid bubble into EX. Store payloads, branch
comparisons, and register-jump targets all use forwarded values. Reset and
older faults override younger work. A resolved transfer overrides a younger
load-use stall. IF/ID and ID/EX valid bits squash wrong-path instructions.

`PREDICTOR=0` selects sequential fetch, `1` (default) selects a 64-entry bimodal
two-bit counter table plus tagged target buffer, and `2` selects six-bit
resolved-history gshare with the same target buffer. Predictions are made from
PC alone, alongside the synchronous instruction request. Fetch saves the
predicted next PC and counter index through ID/EX. EX checks the actual next
PC for every instruction, including non-branches, and redirects on a mismatch.
Only valid, non-faulting resolved control transfers train the predictor.
See [the predictor notes](branch-predictor.md) for state and recovery details.

Hazard detection is combinational control across stages, not an extra pipeline
stage. Splitting decode or fetch is only useful if timing reports show a long
path; each added stage changes forwarding distances and recovery penalties.

## Core ports

`Datapath` is now a core with external memory ports and synchronous active-high
`reset`. This intentionally replaces the old clock-only, hardcoded-memory top.
Compile plain Verilog RTL with `rtl` on the include search path.

- `instruction_enable/address`: when enabled, the memory registers the addressed
  instruction on the rising edge, alongside `instruction_fault`. Both outputs
  must hold during a disabled cycle. The fault signal corresponds to the
  returned instruction, not the current fetch PC.
- `data_enable/address/write_data/write_strobes`: a request valid for one edge.
  Zero strobes mean read; set bits select the four byte lanes of a store.
  Reads register `data_read_data` on that edge and hold it when disabled.
  The core's load formatter uses the low address bits.
- `data_fault`: combinational access rejection for the current MEM transaction.
  The memory must suppress physical writes for rejected transactions. It must
  not create a combinational path through `data_enable` back to itself.
- There is no ready/valid response handshake or variable latency yet. SDRAM,
  caches, or buses must not be attached without a stall/response adapter.
- `retire_valid/pc/instruction/write/destination/data/fault`: WB observation,
  sampled just before/on the rising edge. Retirement includes non-writing
  instructions and a final fault record. `retire_write` excludes writes to `$0`.
  Stores physically update in MEM; this interface does not expose store traces.
- `load_stall`, `redirect_event`: per-cycle observation, not clock enables for
  external logic. `halted/fault_code/fault_pc` latch when a fault reaches WB.

Reset invalidates pipeline state, clears the register file, and blocks memory
requests immediately. It does not clear ROM/RAM. Reset must be asserted for at
least one rising edge. All core state uses rising edges, avoiding half-cycle
RAM/register-file timing assumptions.

## Faults

Faults halt until reset. They do not vector to a handler. Older instructions
finish, and the faulting instruction plus younger work have no register/store
side effects. On an EX fault, the faulting record advances while younger
instructions are squashed. A MEM access fault additionally squashes the younger
EX instruction before it can enter MEM.

| Code | Meaning |
| --- | --- |
| 0 | None |
| 1 | Unsupported instruction |
| 2 | Misaligned instruction address / taken jump target |
| 3 / 4 | Misaligned load / store |
| 5 | Instruction access rejected by memory |
| 6 / 7 | Load / store access rejected by memory |

There is no dedicated halt instruction. Tests use `0xffffffff` (unsupported)
for an explicit terminating fault. Programs may instead end in an infinite loop.
