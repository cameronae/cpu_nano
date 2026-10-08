# Pipelined CPU Datapath

This repository contains a small Verilog CPU datapath project developed for a Penn State CPU design lab. The RTL is organized around a five-stage pipeline: instruction fetch, decode, execute, memory access, and writeback. The current top-level module is `Datapath` in [`Datapath.v`](Datapath.v), with a clock-only interface.

## Repository layout

- `Datapath.v` — top-level wiring between pipeline stages, hazard control, branch/jump selection, and forwarding.
- `rtl/if_stage.v` — program counter, instruction memory, PC incrementer, and IF/ID register.
- `rtl/id_stage.v` — control unit, register file, destination-register mux, and immediate extender.
- `rtl/ex_stage.v` — ID/EX pipeline register, ALU input mux, and ALU.
- `rtl/mem_stage.v` — EX/MEM pipeline register and data memory.
- `rtl/wb_stage.v` — MEM/WB pipeline register and writeback mux.
- `rtl/forwarding.v` — forwarding muxes for the two register operands.
- `testbench.v` — simple Verilog clock-generation testbench that instantiates `Datapath`.

The modules remain plain Verilog modules and can be compiled together; compile the top-level file, all files under `rtl/`, and `testbench.v` in a Verilog simulator. Run `make lint` for a Verilator elaboration check. Warnings remain visible; this is not a functional test.

This folder belongs to the parent `CPU_DESIGN` Git repository; no separate repository is needed. See [the upgrade plan](docs/upgrade-plan.md) for the prototype issues, proposed instruction subset, and implementation milestones.

## Current design behavior

- The PC starts at byte address 100.
- Instruction memory is a 64-word array indexed by `pc >> 2`; locations 25 through 29 are initialized with sample R-type instructions.
- The register file has 32 registers, initialized with sample values in registers 1 through 10, and updates on the falling clock edge.
- Data memory is a 64-word array with sample contents in words 0 through 9. Reads are combinational and stores update on the falling clock edge.
- Pipeline state generally advances on rising clock edges. A load-use hazard can hold the PC and IF/ID register and inject a bubble into ID/EX.
- The control unit currently decodes R-type `add` and `lw` for the main writeback/ALU controls. It also contains PC selection and forwarding comparisons for additional instruction cases, but the sample instruction memory and control decode are not yet a complete or validated ISA implementation.
- `testbench.v` only supplies a 10 ns clock. It does not contain assertions, a pass/fail check, or a self-checking C++ testbench.

The RTL is a lab prototype. In particular, memory bounds, reset behavior, instruction coverage, and FPGA synthesis portability still need deliberate review before treating this as a complete CPU.

## Simulation

Use a Verilog simulator such as the simulator configured by the original Vivado lab project. Add `Datapath.v`, the six files in `rtl/`, and `testbench.v` as design sources, then set `testbench` as the simulation top. The testbench runs continuously; inspect internal signals in a waveform viewer to follow pipeline state.

## Planned FPGA and verification direction

The intended future target is a Sipeed Tang Nano 20K FPGA board. Before programming the board, the project will need a board-facing top module with clock/reset handling, pin constraints, and a deliberate mapping of observable CPU state to board I/O or debug interfaces. The current `Datapath` top level only has a clock input and is not yet a board-ready FPGA top.

The planned verification direction is to replace or supplement the Verilog-only clock testbench with a Verilator-driven C++ testbench. A useful next step will be to define stable observation points (for example, a small debug/status interface or selected public signals) and self-checking tests for instruction results, hazards, forwarding, branches, and memory operations. Keep simulator-specific constructs and initialization assumptions in mind when making the RTL more portable to Verilator and FPGA synthesis.
