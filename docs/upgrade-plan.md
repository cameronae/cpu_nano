# Five-stage CPU upgrade plan

## Implementation status (2026-10-23)

The core now implements the 50-instruction subset in [the ISA contract](isa.md),
including byte/halfword memory operations, six conditional branches, HI/LO and
iterative signed/unsigned multiply/divide. Reset,
valid bits, WB/EX forwarding, explicit load-use detection, EX resolution and
wrong-path squash are implemented. Fixed-latency synchronous memory ports
replace the hardcoded memories. Directed and seeded random retirement tests
compare against a separate C++ interpreter. `make lint`, `make test`, and
`make smoke` are the verification entry points.

Selectable 64-entry bimodal/target-buffer prediction and resolved-history
gshare are implemented, with sequential fetch retained as a baseline.
`make test-all` verifies all modes and predictor state separately.

The Tang Nano 20K wrapper, synchronous ROM/RAM, LED MMIO, startup/button reset,
Gowin project and constraints are also provided. `make system-test` checks
memory/MMIO integration; `make board-test` checks startup and button reset.
Gowin-family Yosys resource estimates are recorded in
[the FPGA guide](tang-nano-20k.md); vendor implementation/timing and board tests
remain outstanding.

The audit and proposed milestones below record the original prototype and
planning decisions; they are not a description of the upgraded RTL.

## Original Git decision (superseded)

The CPU is now a separate `cpu_nano` repository on `main`. The earlier choice
below is retained as historical context. See [repository history](repository-history.md).

Keep `final_project` in the existing `CPU_DESIGN` repository. The parent
repository already contains the lab history and an `origin` remote. A nested
repository would complicate tracking without improving the CPU implementation.
Use `feature/five-stage-cpu` for the upgrade and keep each functional milestone
in a separate commit. Push only when ready to share the branch.

Checkpoint the existing `Datapath.v` changes, all six `rtl/*.v` files, README,
local ignore rules, build entry point, and this plan together. Splitting the
top-level file without committing its supporting modules breaks a fresh clone.
Leave the unrelated tracked parent `.DS_Store` change out of CPU commits.
The project-local `.gitignore` does not untrack that parent file.

## Current baseline

The five stage boundaries already exist. Instruction coverage and pipeline
correctness are the missing work. `make lint` elaborates the prototype with
warnings; there are no self-checking functional tests yet.

Known issues to resolve before prediction:

- `IDEXE.eop` is not connected at the top, so the jump-link path is undriven.
- Only `add` and `lw` have main control decode; other PC-selection cases do
  not make those instructions fully functional.
- Forwarding compares destination numbers without checking producer write
  enable or selecting memory data for loads. Link values also need forwarding.
- Register zero can be written, and combinational register reads use
  nonblocking assignments.
- No reset or pipeline valid bits; initial instructions and memory contents
  are partly undefined and memory indexing is unchecked.
- Taken transfers do not flush the fetched younger instruction. The existing
  `PC+8` link calculation hints at delay slots, but there is no documented ISA
  contract for them.
- Source-use decoding treats jumps and fixed shifts as reading `rs`, which
  can create false stalls.
- The testbench never finishes and has no pass/fail checks.

## Proposed ISA contract

Keep the existing 32-bit MIPS instruction encodings. The first milestone is
an educational integer subset, not a claim of complete MIPS32 compliance.
Choose and document branch delay-slot behavior before changing control flow.
Recommended simplification: no delay slots, squash younger instructions on
taken control transfers, and use `PC+4` for `jal`/`jalr` links.

| Family | Proposed instructions |
| --- | --- |
| Register ALU | add/addu, sub/subu, and, or, xor, nor, slt/sltu |
| Shifts | sll/srl/sra, sllv/srlv/srav |
| Immediate ALU | addi/addiu, andi/ori/xori, slti/sltiu, lui |
| Word memory | lw, sw (aligned addresses) |
| Control flow | beq, bne, j, jal, jr, jalr |
| No operation | sll $0, $0, 0 |

Define overflow and unsupported-instruction behavior explicitly. Full MIPS32
would additionally require exceptions, more branch/load/store variants,
multiply/divide and HI/LO, privileged features, and a precise architecture
contract. Those should be separate milestones if required by the course.

## Implementation order and acceptance criteria

1. **Deterministic baseline:** reset PC and stage valid bits, preserve `$0`,
   define ROM/RAM sizes and initialization, add a bounded self-checking runner
   and a retirement/debug interface. Check reset during active execution.
2. **Integer execution:** complete decode, ALU, immediate extension and
   shift-amount paths. Check each instruction and signed/unsigned boundaries.
3. **Data hazards and stores:** qualify forwarding with valid/write-enable,
   prioritize the newest producer, forward store data, bypass WB as needed,
   and hold PC/IF-ID while injecting a load-use bubble. Check adjacent and
   separated RAW dependencies, repeated destinations, load-to-store and `$0`.
4. **Control flow:** resolve branches/jumps with forwarded operands, squash
   younger instructions, suppress wrong-path writes and stores, implement
   link and return behavior. Start with sequential fetch (predict not taken).
   EX resolution is a straightforward baseline; carry the branch PC and
   immediate into EX and flush both IF/ID and ID/EX on redirect.
5. **Verification:** compare retirement against a sequential subset model;
   run directed and randomized programs, with a cycle timeout. Require
   architectural agreement before enabling any speculative predictor.
6. **Prediction:** select and benchmark a small predictor, record predictions
   in pipeline state, update on valid resolved branches, and recover on
   incorrect direction or target. Compare cycles, mispredictions, area and
   timing with the baseline.
7. **FPGA integration:** add board top/reset/constraints and adapt instruction
   and data memory latency to the chosen FPGA RAM implementation. Current
   combinational reads do not establish a board-ready memory design.

Suggested commits: deterministic reset and tests; integer decode/ALU;
forwarding and memory hazards; branches and squash; predictor and benchmarks;
board integration. Each commit should include its relevant verification.
