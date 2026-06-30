# RVSDA – RISC-V Systolic based Decoupled Architecture

This repository contains the complete hardware, firmware, and software stack for the **RVSDA** NPU (Neural Processing Unit) – a configurable systolic array accelerator for matrix multiplication and convolution, targeting Xilinx Zynq-7000 (ex: Zedboard). The project includes:

- Parameterizable RTL design (SystemVerilog)
- Vivado IP packaging and project generation scripts
- RISC‑V firmware for the embedded PicoRV32 core
- PYNQ overlay (bitstream + HWH + firmware binaries)
- MNIST model training and weight export
- Icarus Verilog testbenches for individual RTL blocks

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Main Makefile Targets](#main-makefile-targets)
- [Building the Hardware Overlay](#building-the-hardware-overlay)
- [Running Simulations](#running-simulations)
- [Customising Parameters](#customising-parameters)
- [Generating MNIST Model Data](#generating-mnist-model-data)
- [Using the Overlay on PYNQ](#using-the-overlay-on-pynq)
---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/marcadrian20/RVSDA.git
cd RVSDA

# Build everything (PicoRV32, IP, design, firmware, overlay)
make all

# (Optional) run firmware simulation
make sim

# (Optional) run RTL testbench (ex: PE testbench)
make sim-tb TB=pool

# See all available targets
make help
```

---

## Prerequisites

### Hardware Design (Vivado)
- **Xilinx Vivado** 2025.1 (or later) – for IP packaging, synthesis, implementation, and bitstream generation.
- A supported Zynq-7000 board (ex: PYNQ-Z2, ZedBoard) – default part is `xc7z020clg484-1`.

### Firmware Compilation
- **RISC-V GCC toolchain** (ex: `riscv64-elf-gcc`).
### Python (for MNIST model)
- Python 3 with `numpy`, `tensorflow` – required only for the `mnist` target.

### RTL Testbenches (optional)
- **Icarus Verilog** (`iverilog`) – for compiling and running testbenches.
- **GTKWave** – for viewing waveform dumps (optional, `view-tb` target).

---

## Directory Structure

```
.
├── Makefile                 # Main build system
├── rtl/                     # RTL sources (SystemVerilog)
│   ├── external_modules/    # External IP (picorv32 cloned here)
├── tb/                      # RTL testbenches
│   ├── Makefile
│   └── *tb.sv
├── firmware/                # RISC-V firmware
│   ├── makefile
│   ├── main.c
│   ├── tests/               # Alternative test programs
│   └── make_hex.py
├── scripts/                 # Vivado Tcl scripts
│   ├── package_ip.tcl
│   ├── run_proj.tcl
│   ├── run_sim.tcl
│   ├── create_sim.tcl
│   ├── register_ip_repo.tcl
│   └── create_project.tcl
├── models/                  # MNIST model training
│   └── model_mnist.py
├── pynq/                    # PYNQ overlay output
│   ├── notebooks/    
│   └── overlay/RVSDA/
│       ├── RVSDA.bit
│       ├── RVSDA.hwh
│       └── firmware/        # Compiled test binaries
├── build/                   # Vivado project and IP repo (generated)
└── sim/                     # Simulation output (vvp, vcd)
```

---

## Main Makefile Targets

| Target        | Description |
|---------------|-------------|
| `all`         | Full flow: clone PicoRV32, package IP, build design, compile default firmware, create overlay |
| `package`     | Package RVSDA IP (only) |
| `design`      | Synthesise, implement, and generate bitstream (runs Vivado in batch mode) |
| `firmware`    | Compile firmware (default `main.c`; override with `FWTEST=name`) |
| `overlay`     | Create PYNQ overlay: copy bit & HWH, compile all tests (except sim_base) and place binaries |
| `mnist`       | Train/export MNIST model weights (requires Tensorflow) |
| `sim`         | Run firmware simulation in Vivado (uses `sim_base_operation_test`) |
| `sim-tb`      | Run an RTL testbench (ex: `make sim-tb TB=pe`) |
| `view-tb`     | Open waveform in GTKWave for the last testbench run |
| `check-tb`    | Syntax‑check all RTL and testbench files |
| `test-all-tb` | Run all RTL testbenches sequentially |
| `clean-tb`    | Remove simulation output files (`.vvp`, `.vcd`) |
| `clean`       | Remove `build/`, `.Xil/`, Vivado logs, and overlay directory |

---

## Building the Hardware Overlay

1. **Install Vivado** and ensure `vivado` is in your `PATH`.
2. Run `make design` – this will:
   - Clone PicoRV32 (if not present)
   - Package the RVSDA IP
   - Create a Vivado project, synthesise, implement, and generate a bitstream.
3. Create the overlay:
   ```bash
   make overlay
   ```
   This copies the bitstream and HWH to `pynq/overlay/RVSDA/`, compiles all test firmwares (except `sim_base_operation_test`), and places the binaries in `pynq/overlay/RVSDA/firmware/`.

To include MNIST model data in the overlay, first run `make mnist`, then:
```bash
make overlay mnist=true
```

---

## Running Simulations

### Firmware Simulation (Vivado)
This simulates the whole system (Zynq PS + NPU) in Vivado’s simulator:
```bash
make sim
```
It compiles `sim_base_operation_test` and launches the simulation in batch mode.

### RTL Testbenches (Icarus Verilog)
Run individual testbenches from the `tb/` directory:
```bash
make sim-tb TB=pe          # PE testbench
make sim-tb TB=sa          # Systolic Array testbench
make sim-tb TB=wsb         # Window Shift Buffer
make sim-tb TB=skdbuff     # Skid Buffer
make sim-tb TB=pool        # Pooling Unit
```

View the generated waveform:
```bash
make view-tb
```
(Requires GTKWave.)


---

## Customising Parameters

The RVSDA IP has several configurable parameters. They can be overridden at build time:

| Parameter         | Default | Description |
|-------------------|---------|-------------|
| `ARRAY_SIZE`      | 8       | Number of PEs per row/column in the systolic array |
| `DATA_WIDTH`      | 8       | Bit‑width of input data (weights/activations) |
| `IMEM_ADDR_WIDTH` | 11      | Address width for instruction memory (2^11 = 2048 words, 8KB) |
| `BRAM_ADDR_WIDTH` | 12      | Address width for weight/activation BRAMs (2^12 = 4096 words) |
| `ACC_WIDTH`       | 24      | Accumulator width; affects FCLK0 frequency (24->160 MHz, 32->140 MHz) |
| `JOBS`            | 16      | Number of parallel jobs for Vivado synthesis/implementation |
| `FWTEST`          | (empty) | Select a test from `firmware/tests/` (like `FWTEST=pynq_base_test`) |
| `TB`              | pe      | Select RTL testbench for `sim-tb` |
| `VIVADO_MODE`              | batch      | Starts Vivado in either the GUI mode or Batch mode |

Example:
```bash
make all ARRAY_SIZE=8 ACC_WIDTH=24
make firmware FWTEST=pynq_simple_28x28_test
make sim VIVADO_MODE=gui
```

---

## Generating MNIST Model Data

The `mnist` target trains a simple neural network on MNIST and exports the weights to `models/model_weights/`. This data can be copied into the overlay for inference on the PYNQ board.

```bash
make mnist
```

Then to include it in the overlay:
```bash
make overlay mnist=true
```

There is an example of usage of mnist in the Jupyter Notebook in the `pynq/noteboks` folder. Copy it to PYNQ board's Notebooks folder. 
---

## Using the Overlay on PYNQ

After running `make overlay`, you will have:

- `pynq/overlay/RVSDA/RVSDA.bit` – the bitstream
- `pynq/overlay/RVSDA/RVSDA.hwh` – hardware handoff file
- `pynq/overlay/RVSDA/firmware/*.bin` – compiled test programs

On the PYNQ board, copy the entire `RVSDA/` folder to your Jupyter workspace and use the PYNQ overlay API to load it:

```python
from pynq import Overlay
ol = Overlay("RVSDA.bit")
```

The firmware binaries can be loaded into the NPU’s instruction memory via the AXI‑Lite interface (refer to the NPU driver code in `firmware/npu.c`).

---



