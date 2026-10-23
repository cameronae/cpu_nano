VERILATOR ?= verilator
RTL := Datapath.v $(wildcard rtl/*.v)
VFLAGS := -Irtl -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL

.PHONY: lint test test-all predictor-test smoke fpga-lint system-test board-test synth programs
lint:
	$(VERILATOR) --lint-only $(VFLAGS) --top-module Datapath $(RTL)

test: build/sim/bimodal/VDatapath
	./build/sim/bimodal/VDatapath

test-all: test build/sim/none/VDatapath build/sim/gshare/VDatapath predictor-test
	./build/sim/none/VDatapath
	./build/sim/gshare/VDatapath

build/sim/bimodal/VDatapath: $(RTL) rtl/cpu_defs.vh tests/cpu_test.cpp
	mkdir -p $(@D)
	$(VERILATOR) --cc --exe --build $(VFLAGS) --top-module Datapath --Mdir build/sim/bimodal $(RTL) $(abspath tests/cpu_test.cpp)

build/sim/none/VDatapath: $(RTL) rtl/cpu_defs.vh tests/cpu_test.cpp
	mkdir -p $(@D)
	$(VERILATOR) --cc --exe --build $(VFLAGS) -GPREDICTOR=0 --top-module Datapath --Mdir build/sim/none $(RTL) $(abspath tests/cpu_test.cpp)

build/sim/gshare/VDatapath: $(RTL) rtl/cpu_defs.vh tests/cpu_test.cpp
	mkdir -p $(@D)
	$(VERILATOR) --cc --exe --build $(VFLAGS) -GPREDICTOR=2 --top-module Datapath --Mdir build/sim/gshare $(RTL) $(abspath tests/cpu_test.cpp)

predictor-test: build/sim/predictor/VBranchPredictor build/sim/predictor-gshare/VBranchPredictor
	./build/sim/predictor/VBranchPredictor
	./build/sim/predictor-gshare/VBranchPredictor

build/sim/predictor/VBranchPredictor: rtl/branch_predictor.v tests/predictor_test.cpp
	mkdir -p $(@D)
	$(VERILATOR) --cc --exe --build $(VFLAGS) --top-module BranchPredictor --Mdir build/sim/predictor $< $(abspath tests/predictor_test.cpp)

build/sim/predictor-gshare/VBranchPredictor: rtl/branch_predictor.v tests/predictor_test.cpp
	mkdir -p $(@D)
	$(VERILATOR) --cc --exe --build $(VFLAGS) -GMODE=2 -CFLAGS '-DPREDICTOR_MODE=2' --top-module BranchPredictor --Mdir build/sim/predictor-gshare $< $(abspath tests/predictor_test.cpp)

smoke:
	mkdir -p build/sim/smoke
	$(VERILATOR) --binary --timing --assert $(VFLAGS) --top-module testbench --Mdir build/sim/smoke $(RTL) testbench.v
	./build/sim/smoke/Vtestbench

fpga-lint:
	$(VERILATOR) --lint-only $(VFLAGS) --top-module TangNano20K $(RTL) fpga/*.v

system-test: build/sim/system/Vsystem_testbench
	./build/sim/system/Vsystem_testbench

build/sim/system/Vsystem_testbench: $(RTL) rtl/cpu_defs.vh fpga/cpu_system.v tests/system_testbench.v programs/selftest.hex
	mkdir -p $(@D)
	$(VERILATOR) --binary --timing --assert $(VFLAGS) --top-module system_testbench --Mdir build/sim/system $(RTL) fpga/cpu_system.v tests/system_testbench.v

synth:
	python3 tools/synth.py --target board

board-test: build/sim/board/Vboard_testbench
	./build/sim/board/Vboard_testbench

build/sim/board/Vboard_testbench: $(RTL) rtl/cpu_defs.vh fpga/cpu_system.v fpga/tang_nano_20k.v tests/board_testbench.v programs/demo.hex
	mkdir -p $(@D)
	$(VERILATOR) --binary --timing --assert $(VFLAGS) --top-module board_testbench --Mdir build/sim/board $(RTL) fpga/*.v tests/board_testbench.v

programs:
	python3 tools/make_programs.py
