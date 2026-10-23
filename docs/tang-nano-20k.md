# Tang Nano 20K target and realistic upgrades

## Target and current fit estimate

The board's GW2AR-LV18QN88C8/I7 has 20,736 LUT4s, 15,552 flip-flops,
46 block-RAM blocks (828 Kbits raw), and 48 18x18 multipliers. Start with the
board's 27 MHz oscillator. The advertised 64-Mbit SDRAM requires a controller;
it is not directly interchangeable with the core's single-cycle RAM ports.
[Source: Sipeed board specifications](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html).

The implemented design is a realistic baseline: a 32-bit, single-issue,
five-stage core with 50 integer instructions, iterative multiply/divide, a
64-entry two-bit predictor, and separate synchronous instruction/data memories.
The board wrapper defaults to **4 KiB instruction ROM + 4 KiB data RAM**.

Local Yosys 0.69+post (`143eb14f9`) Gowin-family synthesis, 2026-10-23:

| Design | LUT1–4 cells | ALU/carry cells | FF cells | Block RAM primitives |
| --- | ---: | ---: | ---: | ---: |
| Core, sequential fetch | 6,693 | 449 | 1,986 | 0 |
| Core, bimodal | 7,753 | 456 | 2,242 | 2 |
| Core, gshare | 7,812 | 456 | 2,257 | 2 |
| Board + memories + LED MMIO, bimodal | 8,304 | 457 | 2,192 | 6 |

The predictor modes also infer four small distributed-RAM primitives. Core
rows retain their external debug interface; the board row optimizes unused
debug paths and uses the bundled demo image. These are primitive counts, not
vendor packed slice utilization. The roughly 8.8k LUT/carry cells in the board
estimate suggest useful headroom within a 20,736-LUT4 device. Dedicated muxes,
packing, routing and fanout still matter.

These are **synthesis estimates, not Gowin implementation or timing results**.
No vendor tool or board was available for timing closure or programming.
27 MHz is the constraint supplied for implementation, not a measured Fmax.
Reproduce with `make synth` or, for the core comparisons:

```sh
python3 tools/synth.py --target core --predictor 0
python3 tools/synth.py --target core --predictor 1
python3 tools/synth.py --target core --predictor 2
```

Reports, source hashes, cell counts, netlists and synthesis logs are written
under `build/synth/`. `synth_gowin` is experimental; use Gowin's reports as the
final authority. The ALU module is named `CpuALU` to avoid collision with the
vendor's `ALU` primitive.

## Gowin project

1. Open `TangNano20K.gprj` in Gowin IDE. Select **GW2AR-18C**, device
   **GW2AR-LV18QN88C8/I7**, and top module **TangNano20K**.
2. Set the Verilog include directory to the project's `rtl` directory so
   `cpu_defs.vh` resolves. The project lists only synthesizable source files;
   do not add `testbench.v`, `tests/`, C++ or simulation build outputs.
3. Keep `programs/demo.hex` with the project. `CpuSystem.PROGRAM_FILE` names
   this ROM image. If the IDE runs synthesis from another working directory,
   set that parameter to the image's absolute path on the Gowin machine or
   configure its file search path. Confirm the synthesis log loaded the image.
4. The project includes `fpga/tang_nano_20k.cst` and `.sdc`: clock pin 4,
   reset S1 pin 88, and active-low LEDs on pins 15–20. The SDC requests
   37.037 ns / 27 MHz. Pins come from the Sipeed revision 1.30 schematic and
   LED example; check your board revision before programming.
5. Run synthesis, place-and-route and timing analysis. Check for inferred
   block RAM, no latches, no unconstrained clock paths, and timing slack
   at the supplied clock. Then program using the normal Gowin Programmer flow.

Pin sources: [Sipeed schematic](https://dl.sipeed.com/fileList/TANG/Nano_20K/2_Schematic/Tang_Nano_20K_3921_Schematics.pdf),
[Sipeed LED constraints](https://raw.githubusercontent.com/sipeed/TangNano-20K-example/main/led/blink_led/src/blink_led.cst).

The top generates a startup reset and synchronizes S1. All CPU logic runs on
one rising-edge clock, with enables rather than fabric-generated clocks.
`CpuSystem` uses clocked ROM/RAM read ports and byte writes. Gowin block RAM
reads and writes are synchronous, which is why the old combinational-memory
lab design was replaced.
[Source: Gowin B-SRAM guide](https://www.gowinsemi.com/upload/database_doc/6/document/5b5852bfdb1b1.pdf).

## Programs and memory map

| Address | Meaning |
| --- | --- |
| Instruction 0x00000000–0x00000fff | Default 4 KiB ROM, independent instruction space |
| Data 0x00000000–0x00000fff | Default 4 KiB RAM |
| Data 0xffff0000–0xffff0003 | LED register, little-endian byte-enabled reads/writes |
| Other addresses | Access fault, halt until reset |

`programs/demo.hex` increments the LED output, runs a software delay and loops.
A fault lights LEDs 4/5 and shows the fault code in LEDs 0–3. `programs/selftest.hex`
checks RAM lanes, load-use forwarding, multiply/HI/LO and MMIO before a deliberate
unsupported-instruction halt. `make system-test` checks those results in the
actual memory adapter, including suppression of a younger MMIO store.
`make programs` regenerates both images from their commented instruction
encodings in `tools/make_programs.py`. This is not a general MIPS assembler.

ROM and RAM configure with known contents; CPU reset preserves memory but
clears the LED register. Image words not supplied by the hex file default to
unsupported instructions. Program images must use the documented no-delay-slot
ISA. A conventional MIPS toolchain may emit unsupported instructions or rely
on architectural features this project does not implement.

## How far to grow

I recommend keeping one instruction issued per cycle and five stages until
the Gowin timing report identifies a specific long path. A practical next
memory budget is **16 KiB instructions + 16 KiB data**; 32 KiB each is also
plausible within the raw RAM budget, subject to actual mapping and other
peripherals. Set `IMEM_ADDR_BITS` and `DMEM_ADDR_BITS` on `TangNano20K` to 12
for 16 KiB, or 13 for 32 KiB. Re-synthesize every configuration; the defaults
and resource table above use 10 (4 KiB).

| Upgrade | Assessment and dependency |
| --- | --- |
| UART plus tiny monitor/loader | High value next step: inspect registers/results and load programs without regenerating bitstreams |
| Cycle, retired, stall and misprediction counters | Small, useful for comparing predictors and clock rates on real programs |
| Memory-mapped timer, GPIO, SPI | Realistic peripherals; start with polling and define their access behavior |
| Return-address stack | Modest predictor extension for nested calls, with reset and wrong-path recovery tests |
| Pipelined DSP multiplier | Plausible speedup over the iterative unit; define result latency and HI/LO hazards |
| Split IF into address/response stages | Justified if fetch prediction/memory timing is the critical path; update metadata, stalls and flush depth |
| Split decode/register read | Possible if decode is critical; requires additional bypass/hazard cases, not merely a new register |
| Cache + SDRAM controller | Plausible larger milestone; first add request/response stalls and prove variable memory latency |
| Precise exceptions/interrupts | Requires a trap/return contract and saved PC/status, beyond the current fault-and-halt behavior |
| Two-instruction fetch/issue, out-of-order or MMU | Substantial redesign; poor next step for completing this educational core |

Fetching two instructions at a time alone does not execute two per cycle. It
needs buffering and can help a slow front end, but dual issue additionally
requires dependency checks between the pair, more register-file ports,
execution resources and retirement rules. Likewise, an explicit hazard unit
is useful and already implemented in ID; it does not need a separate stage.

The five stages now mean: IF makes a synchronous instruction request, ID
decodes and reads registers, EX executes and resolves branches, MEM performs
RAM access, WB commits results. A correct prediction sustains one instruction
per cycle through this pipeline after fill. Dependent loads insert a bubble;
multiply/divide holds EX; mispredictions discard the two younger stages.
