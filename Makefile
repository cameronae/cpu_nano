VERILATOR ?= verilator
RTL := Datapath.v $(wildcard rtl/*.v)

.PHONY: lint
# Baseline prototype: warnings remain visible and are not treated as errors.
# This checks elaboration only; it does not prove instruction correctness.
lint:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal --top-module testbench $(RTL) testbench.v
