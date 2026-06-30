
SHELL := /bin/bash
REPO_ROOT := $(shell cd .. && pwd)
SIM_DIR := $(REPO_ROOT)/sim
RTL_DIR := $(REPO_ROOT)/rtl
TB_DIR := $(REPO_ROOT)/tb
RETIRED_DIR := $(REPO_ROOT)/retired
PICORV_DIR := $(REPO_ROOT)/rtl/external_modules/picorv32/picorv32.v
# RTL source files
RTL_SOURCES := $(RTL_DIR)/*.sv $(RTL_DIR)/axi/*.sv $(RTL_DIR)/buffers/*.sv $(RTL_DIR)/synchronization/*.sv $(RTL_DIR)/post_processing/*.sv  $(RTL_DIR)/memory/*.sv $(RTL_DIR)/systolic/*.sv $(PICORV_DIR) #npu_top.sv $(RTL_DIR)/systolic/pe.sv $(RTL_DIR)/systolic/systolic_array.sv $(RTL_DIR)/buffers/window_shift_buffer.sv $(RTL_DIR)/buffers/window_deskewer_buffer.sv $(RTL_DIR)/memory/Memory_Block.sv $(RTL_DIR)/control/ execution_controller.sv
TB_PE_FILE := $(TB_DIR)/pe_tb.sv
TB_PE_TOP := PE_tb

TB_SA_FILE := $(TB_DIR)/systolic_array_tb.sv
TB_SA_TOP := Systolic_Array_tb

TB_NPU_FILE := $(TB_DIR)/NPU_tb.sv
TB_NPU_TOP := NPU_tb

TB_WSB_FILE := $(TB_DIR)/window_shift_buffer_tb.sv
TB_WSB_TOP := Window_Shift_Buffer_tb

TB_SKDBUFF_FILE := $(TB_DIR)/skid_buffer_tb.sv
TB_SKDBUFF_TOP := Skid_Buffer_tb

TB_SYS_CTRL_FILE := $(TB_DIR)/ execution_controller_tb.sv
TB_SYS_CTRL_TOP :=  execution_controller_tb

TB_POOL_FILE := $(TB_DIR)/pooling_unit_tb.sv
TB_POOL_TOP := Pooling_Unit_tb

TB ?= pe

ifeq ($(TB),pe)
	TB_FILE := $(TB_PE_FILE)
	TOP_MODULE := $(TB_PE_TOP)
	SOURCES := $(RTL_DIR)/systolic/pe.sv $(TB_FILE)
	VVP_OUT := pe_tb.vvp
	VCD_OUT := pe_tb.vcd
else ifeq ($(TB),sa)
	TB_FILE := $(TB_SA_FILE)
	TOP_MODULE := $(TB_SA_TOP)
	SOURCES := $(RTL_DIR)/systolic/systolic_array.sv $(RTL_DIR)/systolic/pe.sv $(RTL_DIR)/memory/*.sv $(RTL_DIR)/buffers/*.sv $(RETIRED_DIR)/npu_exposed_sa_ctrls.sv $(TB_FILE)
	VVP_OUT := systolic_array_tb.vvp
	VCD_OUT := systolic_array_tb.vcd
else ifeq ($(TB),wsb)
	TB_FILE := $(TB_WSB_FILE)
	TOP_MODULE := $(TB_WSB_TOP)
	SOURCES := $(RTL_DIR)/buffers/window_shift_buffer.sv $(TB_FILE)
	VVP_OUT := window_shift_buffer_tb.vvp
	VCD_OUT := window_shift_buffer_tb.vcd
else ifeq ($(TB),skdbuff)
	TB_FILE := $(TB_SKDBUFF_FILE)
	TOP_MODULE := $(TB_SKDBUFF_TOP)
	SOURCES := $(RTL_DIR)/buffers/skid_buffer.sv $(TB_FILE)
	VVP_OUT := skid_buffer_tb.vvp
	VCD_OUT := skid_buffer_tb.vcd
else ifeq ($(TB),sys_ctrl)
	TB_FILE := $(TB_SYS_CTRL_FILE)
	TOP_MODULE := $(TB_SYS_CTRL_TOP)
	SOURCES := $(RTL_SOURCES) $(RETIRED_DIR)/npu_systolic_ctrl_top.sv $(TB_FILE)
	VVP_OUT :=  execution_controller_tb.vvp
	VCD_OUT :=  execution_controller_tb.vcd
else ifeq ($(TB),pool)
	TB_FILE := $(TB_POOL_FILE)
	TOP_MODULE := $(TB_POOL_TOP)

	SOURCES := \
		$(RTL_DIR)/post_processing/pooling_unit.sv \
		$(RTL_DIR)/post_processing/pooling_lane.sv \
		$(TB_FILE)

	VVP_OUT := pooling_unit_tb.vvp
	VCD_OUT := pooling_unit_tb.vcd
else
	$(error Unknown testbench: $(TB). Use TB=pe or TB=sa)
endif

# Icarus Verilog options
IVERILOG_OPTS := -g2012 -Wall

# Phony targets
.PHONY: all sim view clean help test-pe test-sa test-wsb test-skdbuff test-pool check 

# Default target
all: sim

# Compile and run simulation
sim: $(SOURCES)
	@echo "Compiling $(TOP_MODULE)..."
	@mkdir -p $(SIM_DIR)
	iverilog $(IVERILOG_OPTS) -o $(SIM_DIR)/$(VVP_OUT) $(SOURCES)
	@echo "Running simulation..."
	cd $(SIM_DIR) && vvp $(VVP_OUT)

# View waveform
view:
	@if [ -f $(SIM_DIR)/$(VCD_OUT) ]; then \
		echo "Opening waveform in GTKWave..."; \
		gtkwave $(SIM_DIR)/$(VCD_OUT) & \
	else \
		echo "Error: $(VCD_OUT) not found. Run 'make sim TB=$(TB)' first."; \
	fi

clean:
	@echo "Cleaning simulation files..."
	rm -rf $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd
	@echo "Clean complete."

# Help message
help:
	@echo "Targets:"
	@echo "  all       		- Compile and run simulation (default)"
	@echo "  sim       		- Compile and run simulation"
	@echo "  view      		- Open waveform in GTKWave"
	@echo "  clean     		- Remove generated files"
	@echo "  help      		- Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make sim TB=pe          # Run PE testbench"
	@echo "  make sim TB=sa          # Run Systolic Array testbench"
	@echo "  make sim TB=wsb         # Run Window Shift Buffer testbench"
	@echo "  make sim TB=sa view     # Run SA testbench and view waveform"
	@echo "  make test-all           # Run all tests"
	@echo "  make sim TB=pool       # Run Pooling Unit testbench"