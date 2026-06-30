from pynq import DefaultIP
import numpy as np
import time
class RVSDADriver(DefaultIP):
    
    # bindto = ['xilinx.com:module_ref:RVSDA:1.0']
    bindto = ['marc.org:marc:RVSDA:1.0']

    def __init__(self, description):
        super().__init__(description)

    @property
    def ctrl(self):
        """Read the Control Register."""
        return self.read(0x00)

    @ctrl.setter
    def ctrl(self, value):
        """Write to the Control Register."""
        self.write(0x00, int(value))

    @property
    def status(self):
        """Read the Status Register (Read-Only)."""
        return self.read(0x04)

    @property
    def ddr_base(self):
        """Read the AXI DDR Base Register."""
        return self.read(0x08)

    @ddr_base.setter
    def ddr_base(self, address):
        """Set the physical DDR Base Address for the RVSDA."""
        self.write(0x08, int(address))

    def load_instruction_memory(self, instructions_array):
        """Stream compiled RISC-V binaries directly into IMEM."""
        # IMEM starts at byte offset 0x0C
        offset = 0x0C
        for instr in instructions_array:
            self.write(offset, int(instr))
            offset += 4
    def start(self):
        self.ctrl = 3
    def wait_done(
        self,
        poll_interval=0.01,
        timeout=None
    ):

        start_time = time.time()

        while True:

            if self.status == 0x1:
                return True

            if (
                timeout is not None
                and
                (time.time() - start_time) > timeout
            ):
                raise TimeoutError(
                    "RVSDA execution timed out"
                )

            time.sleep(poll_interval)
    @property
    def done(self):
        return self.status == 0x1
