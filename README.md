# Five-stage MIPS-style CPU

A 32-bit, single-issue IF / ID / EX / MEM / WB CPU for an educational FPGA
project targeting the Sipeed Tang Nano 20K and Gowin IDE. The design implements
50 integer instructions: ALU/logic, shifts, immediates, byte/halfword/word memory
operations, conditional branches, jumps, calls, returns, HI/LO and iterative
signed/unsigned multiply and divide.

The ISA uses MIPS encodings with **no delay slots** and wrapping arithmetic.
This is an explicitly documented subset, not full MIPS32 compatibility.
See [the ISA and interface contract](docs/isa.md) before writing programs.

## Build and verification

Requires Verilator, Make, and a C++ compiler:

```sh
make lint
make test
make smoke
```

`make test` compares WB retirement with an independent C++ interpreter and
checks final memory. It includes directed instruction/hazard/control tests,
fault handling, reset, and eight reproducible randomized instruction streams.
`make smoke` is a bounded Verilog waveform-oriented simulation. Generated
files live in ignored `build/`; lint warnings are errors apart from deliberate
module-filename and unused-signal exclusions.

## RTL organization

- `Datapath.v`: core interface, stage registers, squash, fault and control flow.
- `rtl/if_stage.v`: resettable PC with redirect priority.
- `rtl/id_stage.v`: complete subset decoder and register file with WB bypass.
- `rtl/ex_stage.v`: arithmetic, comparison, logic and barrel shifts.
- `rtl/muldiv.v`: shared iterative multiply/divide, with EX backpressure.
- `rtl/forwarding.v`: explicit forwarding and load-use hazard detection.
- `rtl/mem_stage.v`, `rtl/wb_stage.v`: little-endian store/load byte lanes.
- `rtl/cpu_defs.vh`: shared control encodings.
- `tests/cpu_test.cpp`: independent reference model and cycle/memory harness.
- `testbench.v`: small synchronous-memory smoke test.

The core has synchronous, fixed-latency memory interfaces. Do not reuse the old
clock-only instantiation; reset and memory connections are required. No external
SDRAM controller is included.

This directory remains in the parent `CPU_DESIGN` repository on
`feature/five-stage-cpu`. Commits are kept separate by functional milestone.
The [upgrade plan](docs/upgrade-plan.md) records the original prototype audit;
[branch predictor research](docs/branch-predictor.md) records the initial choice.
