VERILATOR ?= verilator
RTL := Datapath.v $(wildcard rtl/*.v)
VFLAGS := -Irtl -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL

.PHONY: lint test test-all predictor-test smoke
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
