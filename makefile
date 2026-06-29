# Targets:
#   all          : pull picorv32, package IP, build project/bitstream, compile firmware
#   package      : package the IP (run package_ip.tcl)
#   design       : create project, synth/impl/bitstream (run run_proj.tcl)
#   firmware     : compile the firmware (assumes firmware/ has a Makefile)
#   clean        : remove build, .Xil, NPU_CLOSURE_TEST, and any Vivado logs

SHELL := /bin/bash
REPO_ROOT := $(shell pwd)
RTL_DIR    := $(REPO_ROOT)/rtl
EXTERNAL   := $(RTL_DIR)/external_modules
PICORV32_DIR := $(EXTERNAL)/picorv32
BUILD_DIR  := $(REPO_ROOT)/build
PROJECT_DIR := $(BUILD_DIR)/NPU_CLOSURE_TEST   # as defined in proj.tcl
XIL_DIR    := $(REPO_ROOT)/.Xil
FIRMWARE_DIR := $(REPO_ROOT)/firmware
SCRIPTS_DIR := $(REPO_ROOT)/scripts
PACKAGE_SCRIPT := $(SCRIPTS_DIR)/package_ip.tcl
RUN_SCRIPT     := $(SCRIPTS_DIR)/run_proj.tcl

VIVADO ?= vivado
VIVADO_MODE := -mode batch
VIVADO_OPTS :=

ARRAY_SIZE       ?= 8
DATA_WIDTH       ?= 8
IMEM_ADDR_WIDTH  ?= 11
BRAM_ADDR_WIDTH  ?= 12
ACC_WIDTH        ?= 24
JOBS             ?= 16

.PHONY: all package design firmware clean help

all: picorv32 design firmware
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
	@cd $(REPO_ROOT) && $(VIVADO) $(VIVADO_MODE) -source $(PACKAGE_SCRIPT) $(VIVADO_OPTS)
	@echo "Packaged successfully"

design: picorv32
	@echo "Building Vivado project and generating bitstream"
	@cd $(REPO_ROOT) && $(VIVADO) $(VIVADO_MODE) -source $(RUN_SCRIPT) -tclargs \
		--ARRAY_SIZE $(ARRAY_SIZE) \
		--DATA_WIDTH $(DATA_WIDTH) \
		--IMEM_ADDR_WIDTH $(IMEM_ADDR_WIDTH) \
		--BRAM_ADDR_WIDTH $(BRAM_ADDR_WIDTH) \
		--ACC_WIDTH $(ACC_WIDTH) \
		--jobs $(JOBS)
	@echo "Design built and bitstream generated."

firmware:
	@if [ -f "$(FIRMWARE_DIR)/makefile" ]; then \
		echo "Compiling firmware in $(FIRMWARE_DIR)..."; \
		$(MAKE) -C $(FIRMWARE_DIR); \
	else \
		echo "No firmware Makefile found. Skipping firmware compilation."; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(XIL_DIR)
	@rm -rf $(PROJECT_DIR)
	@# Also remove any Vivado log files that might appear in root
	@rm -f vivado*.log vivado*.jou
	@echo "Clean done.

help:
	@echo "Available targets:"
	@echo "  all          : Pull picorv32, package IP, build project/bitstream, compile firmware"
	@echo "  package      : Package the IP only"
	@echo "  design       : Build the Vivado project and generate bitstream"
	@echo "  firmware     : Compile the firmware"
	@echo "  clean        : Remove build, .Xil, and Vivado logs"

	@echo "Override parameters:"
	@echo "  ARRAY_SIZE, DATA_WIDTH, IMEM_ADDR_WIDTH, BRAM_ADDR_WIDTH, ACC_WIDTH, JOBS"