VERILATOR ?= verilator
RTL := Datapath.v $(wildcard rtl/*.v)
VFLAGS := -Irtl -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL

.PHONY: lint test smoke
lint:
	$(VERILATOR) --lint-only $(VFLAGS) --top-module Datapath $(RTL)

test: build/VDatapath
	./build/VDatapath

build/VDatapath: $(RTL) rtl/cpu_defs.vh tests/cpu_test.cpp
	$(VERILATOR) --cc --exe --build $(VFLAGS) --top-module Datapath --Mdir build $(RTL) $(abspath tests/cpu_test.cpp)

smoke:
	$(VERILATOR) --binary --timing --assert $(VFLAGS) --top-module testbench --Mdir build/smoke $(RTL) testbench.v
	./build/smoke/Vtestbench
