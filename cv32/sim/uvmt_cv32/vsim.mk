###############################################################################
#
# Copyright 2020 OpenHW Group
# 
# Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://solderpad.org/licenses/
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
###############################################################################
#
# VSIM-specific Makefile for the CV32E40P "uvmt_cv32" testbench.
# VSIM is the Mentor Graphics Questa SystemVerilog simulator.
#
###############################################################################

GUI         ?= 0

# Questasim commands
VLIB      = vlib
VLOG      = vlog
VOPT      = vopt
VSIM      = vsim

# Work library
VWORK     = work

# Build parameters
VLOG_FLAGS    = -pedanticerrors -timescale "1ns/1ps" -mfcu +acc=rb \
    -suppress 2577 -suppress 2583 -suppress 2181 -suppress 13262 \
#     -writetoplevels  uvmt_cv32_tb
VOPT_FLAGS    = -debugdb -fsmdebug +acc #=mnprft
        
VLOG_LOG      = vloggy

# Simulation parameters
VSIM_FLAGS       ?=  # user defined
VSIM_FLAGS       += -novopt -suppress 12110
VSIM_FLAGS       += +firmware=$(VSIM_FIRMWARE)
VSIM_FLAGS       += +signature=dump_sign.txt
ifeq ($(GUI), 0)
	VSIM_FLAGS += -c -do 'source $(VSIM_SCRIPT); exit -f'
else
	VSIM_FLAGS += $(VSIM_GUI_FLAGS)
	VSIM_FLAGS += -do $(VSIM_SCRIPT)
endif
VSIM_GUI_FLAGS    = -gui -debugdb
UVM_TESTNAME = uvmt_cv32_firmware_test_c

# Simulation scripts
VSIM_SCRIPT_DIR   = ../questa
VSIM_SCRIPT       = $(VSIM_SCRIPT_DIR)/vsim.tcl

###############################################################################
# Help !!!!

no_rule:
	@echo 'makefile: SIMULATOR is set to $(SIMULATOR), but no rule/target specified.'
	@echo 'try "make SIMULATOR=vsim sanity" (or just "make sanity" if shell ENV variable SIMULATOR is already set).'

help-vsim:
	vsim -help

###############################################################################
# Generic rules

.lib-rtl:
	$(VLIB) $(VWORK)
	touch .lib-rtl

.build-rtl: .lib-rtl $(CV32E40P_PKG) $(TBSRC_PKG) $(TBSRC)
	$(VLOG) \
		-work $(VWORK) \
		$(VLOG_FLAGS) \
		+incdir+$(DV_UVME_CV32_PATH) \
		+incdir+$(DV_UVMT_CV32_PATH) \
		-f $(CV32E40P_MANIFEST) \
		-f $(DV_UVMT_CV32_PATH)/uvmt_cv32.flist \
		$(TBSRC_PKG) $(TBSRC)
	touch .build-rtl

.opt-rtl: .build-rtl
	$(VOPT) -work $(VWORK) $(VOPT_FLAGS) $(RTLSRC_VLOG_TB_TOP) -o $(RTLSRC_VOPT_TB_TOP)
	touch .opt-rtl

.PHONY: vsim-build
vsim-build: .opt-rtl

# run tb and exit
.PHONY: vsim-run
vsim-run:
	$(VSIM) $(VSIM_FLAGS) -work $(VWORK) +UVM_TESTNAME=$(UVM_TESTNAME) \
	$(RTLSRC_VOPT_TB_TOP)  

# run tb and drop into interactive shell
.PHONY: vsim-run-sh
vsim-run-sh: VSIM_FLAGS += -c
vsim-run-sh:
	$(VSIM) -work $(VWORK) $(VSIM_FLAGS) \
	$(RTLSRC_VOPT_TB_TOP)

vsim-all: $(VSIM_FIRMWARE) vsim-build vsim-run

%.vsim-run:
	@echo "sim: $*"
	make SIMULATOR=vsim vsim-all VSIM_FIRMWARE=$*

###############################################################################
# Hello world !!!!!

.PHONY: hello-world
hello-world: $(CUSTOM)/hello_world.hex.$(SIMULATOR)-run

###############################################################################
# RISC-V tests

.PHONY: questa-cv32_riscv_tests
questa-cv32_riscv_tests: \
	$(CV32_RISCV_TESTS_FIRMWARE)/cv32_riscv_tests_firmware.hex.$(SIMULATOR)-run

###############################################################################
# ???

.PHONY: questa-firmware
questa-firmware: vsim-all $(FIRMWARE)/firmware.hex
questa-firmware: VSIM_FLAGS += +firmware=$(FIRMWARE)/firmware.hex
questa-firmware: vsim-run

###############################################################################
# ???

.PHONY: questa-unit-test 
questa-unit-test:  firmware-unit-test-clean 
questa-unit-test:  $(FIRMWARE)/firmware_unit_test.hex 
questa-unit-test: VSIM_FLAGS += "+firmware=$(FIRMWARE)/firmware_unit_test.hex"
questa-unit-test: vsim-run

###############################################################################
# in vsim
.PHONY: firmware-vsim-run
firmware-vsim-run: vsim-all $(FIRMWARE)/firmware.hex
firmware-vsim-run: ALL_VSIM_FLAGS += "+firmware=$(FIRMWARE)/firmware.hex"
firmware-vsim-run: vsim-run

.PHONY: vsim-firmware-unit-test 
vsim-firmware-unit-test:  firmware-unit-test-clean 
vsim-firmware-unit-test:  $(FIRMWARE)/firmware_unit_test.hex 
vsim-firmware-unit-test: ALL_VSIM_FLAGS += "+firmware=$(FIRMWARE)/firmware_unit_test.hex"
vsim-firmware-unit-test: vsim-run

.PHONY: firmware-vsim-run-gui
firmware-vsim-run-gui: vsim-all $(FIRMWARE)/firmware.hex
firmware-vsim-run-gui: ALL_VSIM_FLAGS += "+firmware=$(FIRMWARE)/firmware.hex"
firmware-vsim-run-gui: vsim-run-gui

###############################################################################
# Clean up your mess!

vsim-clean:
	if [ -d $(VWORK) ]; then rm -r $(VWORK); fi
	rm -f transcript vsim.wlf vsim.dbg trace_core*.log \
	.build-rtl .opt-rtl .lib-rtl *.vcd objdump
