# Targets:
#   all          : pull picorv32, package IP, build project/bitstream, compile firmware
#   package      : package the IP (run package_ip.tcl)
#   design       : create project, synth/impl/bitstream (run run_proj.tcl)
#   firmware     : compile the firmware (assumes firmware/ has a Makefile)
#   clean        : remove build, .Xil, NPU_CLOSURE_TEST, and any Vivado logs
#   sim			 : run sim with a sim firmware config
SHELL := /bin/bash
PROJECT_NAME := NPU_CLOSURE_TEST
REPO_ROOT := $(shell pwd)
RTL_DIR    := $(REPO_ROOT)/rtl
EXTERNAL   := $(RTL_DIR)/external_modules
PICORV32_DIR := $(EXTERNAL)/picorv32
BUILD_DIR  := $(REPO_ROOT)/build
PROJECT_DIR := $(BUILD_DIR)/NPU_CLOSURE_TEST
SIM_PROJECT_DIR := $(BUILD_DIR)/AXI_NPU_SIM
XIL_DIR    := $(REPO_ROOT)/.Xil
FIRMWARE_DIR := $(REPO_ROOT)/firmware
SCRIPTS_DIR := $(REPO_ROOT)/scripts
OVERLAY_DIR := $(REPO_ROOT)/pynq/overlay/RVSDA
OVERLAY_FIRMWARE_DIR := $(OVERLAY_DIR)/firmware
OVERLAY_MODEL_DIR := $(OVERLAY_DIR)/model_data

# Bitstream and HWH files
BIT_FILE := $(PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1/npu_bd_wrapper.bit
HWH_FILE := $(PROJECT_DIR)/$(PROJECT_NAME).gen/sources_1/bd/npu_bd/hw_handoff/npu_bd.hwh

PACKAGE_SCRIPT := $(SCRIPTS_DIR)/package_ip.tcl
RUN_SCRIPT     := $(SCRIPTS_DIR)/run_proj.tcl
SIM_RUN_SCRIPT := $(SCRIPTS_DIR)/run_sim.tcl

VIVADO ?= vivado
VIVADO_MODE := batch
VIVADO_OPTS :=

ARRAY_SIZE       ?= 8
DATA_WIDTH       ?= 8
IMEM_ADDR_WIDTH  ?= 11
BRAM_ADDR_WIDTH  ?= 12
ACC_WIDTH        ?= 24
JOBS             ?= 16
FWTEST ?=

.PHONY: all package design sim firmware clean help overlay mnist sim-tb view-tb check-tb test-all-tb clean-tb

all: picorv32 design firmware overlay
	@echo "Simple design has been built"
	@echo "Bitstream: $(PROJECT_DIR)/$(PROJECT_DIR).runs/impl_1/npu_bd_wrapper.bit"

picorv32:
	@mkdir -p $(EXTERNAL)
	@if [ -d "$(PICORV32_DIR)" ] && [ -n "$$(ls -A $(PICORV32_DIR))" ]; then \
		echo "PicoRV32 already exists in $(PICORV32_DIR)."; \
	else \
		echo "Cloning PicoRV32 into $(PICORV32_DIR)"; \
		git clone --depth 1 https://github.com/YosysHQ/picorv32.git $(PICORV32_DIR); \
	fi

package: picorv32
	@echo "Packaging RVSDA"
	@cd $(REPO_ROOT) && $(VIVADO) -mode $(VIVADO_MODE) -source $(PACKAGE_SCRIPT) $(VIVADO_OPTS)
	@echo "Packaged successfully"

design: picorv32
	@echo "Building Vivado project and generating bitstream"
	@cd $(REPO_ROOT) && $(VIVADO) -mode $(VIVADO_MODE) -source $(RUN_SCRIPT) -tclargs \
		--ARRAY_SIZE $(ARRAY_SIZE) \
		--DATA_WIDTH $(DATA_WIDTH) \
		--IMEM_ADDR_WIDTH $(IMEM_ADDR_WIDTH) \
		--BRAM_ADDR_WIDTH $(BRAM_ADDR_WIDTH) \
		--ACC_WIDTH $(ACC_WIDTH) \
		--jobs $(JOBS)
	@echo "Design built and bitstream generated."

sim: picorv32
	@echo "Compiling firmware for simulation (test: sim_base_operation_tests)"
	$(MAKE) -C $(FIRMWARE_DIR) TEST=sim_base_operation_tests
	@echo "Running simulation..."
	@cd $(REPO_ROOT) && $(VIVADO) -mode $(VIVADO_MODE) -source $(SIM_RUN_SCRIPT) -tclargs \
		--ARRAY_SIZE $(ARRAY_SIZE) \
		--DATA_WIDTH $(DATA_WIDTH) \
		--IMEM_ADDR_WIDTH $(IMEM_ADDR_WIDTH) \
		--BRAM_ADDR_WIDTH $(BRAM_ADDR_WIDTH) \
		--ACC_WIDTH $(ACC_WIDTH) \
		--skip-package
	@echo "Simulation finished."

firmware:
	@if [ -f "$(FIRMWARE_DIR)/makefile" ]; then \
		echo "Compiling firmware (test: $(if $(FWTEST),$(FWTEST),main)) in $(FIRMWARE_DIR)"; \
		$(MAKE) -C $(FIRMWARE_DIR) TEST=$(FWTEST); \
	else \
		echo "No firmware Makefile found. Skipping firmware compilation."; \
	fi

overlay:
	@echo "Preparing overlay..."
	@mkdir -p $(OVERLAY_DIR) $(OVERLAY_FIRMWARE_DIR)
	@if [ ! -f $(BIT_FILE) ] || [ ! -f $(HWH_FILE) ]; then \
		echo "Bitstream or HWH missing - running 'make design'"; \
		$(MAKE) design; \
	fi
	@cp $(BIT_FILE) $(OVERLAY_DIR)/RVSDA.bit
	@cp $(HWH_FILE) $(OVERLAY_DIR)/RVSDA.hwh
	@echo "Compiling all test firmwares except sim_base_operation_test..."
	@for test in $$(ls $(FIRMWARE_DIR)/tests/*.c | grep -v sim_base_operation_test | sed 's/.*\///; s/\.c//'); do \
		echo "  Building $$test..."; \
		$(MAKE) -C $(FIRMWARE_DIR) TEST=$$test; \
		cp $(FIRMWARE_DIR)/firmware_$$test.bin $(OVERLAY_FIRMWARE_DIR)/firmware_$$test.bin; \
	done
	@if [ "$(mnist)" = "true" ]; then \
		echo "Copying model data (mnist=true)..."; \
		mkdir -p $(OVERLAY_MODEL_DIR); \
		if [ -d "$(REPO_ROOT)/models/model_weights" ]; then \
			cp -r $(REPO_ROOT)/models/model_weights/* $(OVERLAY_MODEL_DIR)/; \
		else \
			echo "WARNING: models/model_weights/ not found - run 'make mnist' first."; \
		fi; \
	fi
	@echo "Overlay created in $(OVERLAY_DIR)"

mnist:
	@echo "Running MNIST model training/export..."
	@cd $(REPO_ROOT)/models && python3 model_mnist.py
	@echo "Model generated in models/model_weights/"

sim-tb:
	@$(MAKE) -C tb sim TB=$(TB)

view-tb:
	@$(MAKE) -C tb view TB=$(TB)

check-tb:
	@$(MAKE) -C tb check

test-all-tb:
	@$(MAKE) -C tb test-all

clean-tb:
	@$(MAKE) -C tb clean

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(XIL_DIR)
	@rm -rf $(PROJECT_DIR)
	@rm -rf $(SIM_PROJECT_DIR)
	@rm -rf $(OVERLAY_DIR)
	@rm -f vivado*.log vivado*.jou
	@echo "Clean done."

help:
	@echo "Available targets:"
	@echo "  all          : Pull picorv32, package IP, build project/bitstream, compile firmware"
	@echo "  package      : Package the IP only"
	@echo "  design       : Build the Vivado project and generate bitstream"
	@echo "  firmware     : Compile the firmware"
	@echo "  overlay      : Build overlay for PYNQ (bit, HWH, all test firmwares, optionally model data)"
	@echo "  mnist        : Generate MNIST model data (model_weights/)"
	@echo "  clean        : Remove build, .Xil, and Vivado logs"
	@echo "  sim          : Run simulation (creates sim project and launches simulation)"
	@echo ""
	@echo "RTL Testbench Simulation (in tb/ directory):"
	@echo "  sim-tb       : Run RTL testbench simulation (TB=pe|sa|npu|wsb|skdbuff|sys_ctrl|pool)"
	@echo "  view-tb      : View waveform in GTKWave"
	@echo "  check-tb     : Syntax check all RTL files"
	@echo "  test-all-tb  : Run all testbenches"
	@echo "  clean-tb     : Clean testbench simulation files"
	@echo ""
	@echo "Override parameters:"
	@echo "  ARRAY_SIZE, DATA_WIDTH, IMEM_ADDR_WIDTH, BRAM_ADDR_WIDTH, ACC_WIDTH, JOBS"
	@echo "  FWTEST       : choose a test from firmware/tests/ (default: main)"
	@echo "  mnist=true   : with overlay, also copy model data (requires 'make mnist' first)"
	@echo "  TB           : choose testbench (pe, sa, npu, wsb, skdbuff, sys_ctrl, pool)"