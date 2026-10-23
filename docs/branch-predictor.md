# Branch predictor recommendation

## Implemented update (2026-10-23)

The core now has selectable prediction: `PREDICTOR=0` disables it, `1` is the
default 64-entry bimodal predictor, and `2` selects six-bit resolved-history
gshare. Both dynamic modes have a 64-entry direct-mapped tagged target buffer
so that prediction works alongside the synchronous instruction-memory request.
Each target slot has a valid bit, 24-bit PC tag, 30-bit aligned target, and
conditional bit. The direction table has 64 two-bit counters initialized to
weakly not taken. Raw table storage is 3,712 bits, plus six history bits for
gshare, excluding pipeline metadata and implementation overhead.

The target index is PC[7:2]. Bimodal uses that index for direction; gshare XORs
it with the current history. Save the lookup index and predicted next PC at
fetch. Update the saved counter index once on valid EX branch resolution;
allocate/update targets for conditional branches and jumps. Conditional
branches alone train direction/history. Gshare history advances at resolution,
not speculative fetch, so it needs no history rollback but can miss recent
in-flight correlations. Indirect jumps use their last resolved target.

EX compares predicted and actual next PC for every valid instruction, including
non-branches, and recovers by flushing younger stages. Older MEM faults override
prediction/training and reset clears validity/counters/history. Stalls retain
prediction metadata. Simultaneous lookup/update observes pre-edge state for
the accepted fetch.

`make test-all` compares all three configurations with the same independent
architectural model. Standalone predictor tests cover saturation, tag misses,
counter/target aliasing, updates and reset. Bimodal remains the default: a
simple 100-iteration loop needs fewer cycles than with gshare while gshare
warms its history. This is a directed example, not a general workload ranking.

Measured `loop-benchmark` in `tests/cpu_test.cpp` (2026-10-23):

| Mode | Active clock cycles to halt | Retired records | EX next-PC corrections |
| --- | ---: | ---: | ---: |
| Sequential | 404 | 202 | 99 |
| Bimodal | 210 | 202 | 2 |
| Gshare | 222 | 202 | 8 |

The records include the final unsupported-instruction fault. Cycle counts
exclude setup reset and the post-halt drain check. No FPGA frequency result
is implied; a predictor can reduce cycles while extending the clock path.

The original research and proposed choices below are retained as rationale;
the previous combinational-ROM suggestion no longer describes the memory path.

Research date: 2026-10-08. This is a proposed design, not implemented RTL or a
measured performance claim. Keep the existing repository and implement on
`feature/five-stage-cpu` after the correctness milestones in
[the upgrade plan](upgrade-plan.md).

## Choice

Start with a **64-entry bimodal table of two-bit saturating counters**.
Use predict-not-taken as the reference configuration. My recommendation is
based on the small, single-issue pipeline and the value of keeping recovery
and verification simple. The table holds 128 bits of direction state; that
does not include muxes, update logic, or pipeline prediction metadata.

Direction and target prediction are separate jobs. BOOM's documentation
describes a direction predictor that needs another mechanism to identify
branches and provide their targets, either a BTB or instruction decoding.
[Source: BOOM backing predictor](https://docs.boom-core.org/en/latest/sections/branch-prediction/backing-predictor.html).

For this project's current combinational ROM, decode fetched `beq`/`bne`
and compute `fetch_pc + 4 + (sign_extend(imm16) << 2)` in IF. Consult the
direction table only for those instructions. This avoids a BTB initially,
but adds a ROM/decode/adder path to next-PC selection. Check timing before
assuming this is suitable for the board. If instruction memory becomes
synchronous, reconsider fetch staging or introduce a tagged target buffer.

## Alternatives

| Predictor | Proposed use in this project | Tradeoff |
| --- | --- | --- |
| Always not taken | Mandatory correctness/performance baseline | No training; taken branches redirect |
| Backward taken, forward not taken | Optional inexpensive comparison | No history table; depends on branch layout |
| 64-entry bimodal | Recommended first dynamic predictor | Small state and simple updates; PC aliasing and correlated outcomes remain |
| 64-entry gshare, six-bit history | Follow-up experiment | Add history, saved lookup index, and a defined history-update/recovery policy |
| TAGE / tournament | Defer | More structures and verification work than this first milestone needs |

Ibex documents a static policy that takes negative-offset branches and skips
positive-offset branches. Its feature is marked experimental; its cycle
penalties should not be transplanted to this five-stage MIPS-style design.
[Source: Ibex instruction fetch](https://ibex-core.readthedocs.io/en/latest/03_reference/instruction_fetch.html).

Gshare XORs branch-address bits with global history to index a counter table.
BOOM also describes speculative history and recovery; ANU's course material
explains the address/history hash and benchmark comparison methodology.
[Source: BOOM backing predictor](https://docs.boom-core.org/en/latest/sections/branch-prediction/backing-predictor.html),
[source: ANU branch prediction assignment](https://comp.anu.edu.au/courses/comp3710-uarch/assessments/02-bp2/).

## Proposed bimodal behavior

- Index: `fetch_pc[7:2]`, ignoring the two word-alignment bits.
- Reset counters to `01` (weakly not taken).
- Predict taken when the selected counter's high bit is one.
- On an accepted, valid resolved conditional branch, increment for taken
  or decrement for not taken, saturating at `11` or `00`.
- Train once per branch, including correctly predicted branches. Do not
  train on reset, bubbles, squashed instructions, or repeatedly while held.
- Different branch PCs may share an entry. That can harm accuracy, but must
  never affect correctness because EX verifies every prediction.

| State | Prediction | Next on not taken | Next on taken |
| --- | --- | --- | --- |
| 00 | Not taken | 00 | 01 |
| 01 | Not taken | 00 | 10 |
| 10 | Taken | 01 | 11 |
| 11 | Taken | 10 | 11 |

For the first version, handle direct jumps and register jumps with ordinary
resolved redirects. Do not train them as conditional branches. Optimizing
direct jump fetch or adding a return-address stack can be separate commits.

## Pipeline integration proposal

This proposal assumes EX resolution and **no delay slots**, as recommended
in the upgrade plan. Decide that ISA contract before implementing it.

1. IF produces a predicted next PC. IF/ID captures the instruction PC,
   predicted next PC, and prediction index together with the instruction.
2. ID/EX carries that metadata, the operands, immediate, controls, and valid
   bit. A stall holds the fetch/decode state and injects an invalid EX bubble.
3. EX uses forwarded operands to resolve the branch. Actual next PC is
   the target if taken, otherwise branch PC + 4.
4. Compare actual next PC against the saved predicted next PC. On mismatch,
   redirect fetch and invalidate IF/ID and the younger instruction entering
   ID/EX. Let the resolving instruction and older instructions advance.
5. Give reset highest priority, then EX redirect, then data-hazard hold,
   then ordinary predicted fetch. Redirect must override a younger stall.
6. Update the table using the resolving branch's saved index. Specify that
   simultaneous fetch/update sees the pre-edge table value; later reads see
   the updated value. Use the current counter at update, rather than an old
   counter value saved at fetch.

Expose a small predictor interface: fetch PC/instruction and predicted next
PC/index; resolved-valid, resolved-index, and actual-taken for training;
reset. Keep mismatch detection and pipeline flushing in the CPU controller.

A tagged BTB is an optional later target-prediction structure, not a
replacement for direction counters. BOOM describes checking a PC tag and
using the target on a hit, with conditional direction consulted separately.
[Source: BOOM next-line predictor](https://docs.boom-core.org/en/latest/sections/branch-prediction/nl-predictor.html).

If that later version speculates from BTB entries, check predicted next PC
even for fetched non-control instructions: a stale entry must be recoverable.

## Verification and decision gate

Before predictor RTL, prove ALU, memory, stalls, forwarding, branches, and
wrong-path suppression with prediction disabled. Then test all counter
transitions and saturation, reset state, correct and incorrect predictions,
negative branch offsets, aliasing, consecutive branches, load-to-branch,
and redirect concurrent with a younger load-use hazard. Place stores and
register writes on wrong paths and verify neither takes effect.

Run identical programs with prediction disabled and enabled. Compare
architectural retirement and final memory/register state against a sequential
reference. Count retired instructions, cycles, valid resolved conditional
branches, incorrect directions, and next-PC recovery events. Report CPI and
mispredictions per thousand retired instructions; do not count bubbles.

Use loops, nested loops, alternating conditions, correlated branches, and
deliberate PC collisions. Sweep 16/32/64/128 counters before committing to a
size. Compare FPGA area and achievable clock frequency as well as cycles:
fewer cycles with a slower clock may not improve elapsed execution time.
Choose gshare only if these workloads justify its additional history logic.
