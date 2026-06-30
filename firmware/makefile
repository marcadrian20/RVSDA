CC      = riscv64-elf-gcc
LD      = riscv64-elf-ld
OBJCOPY = riscv64-elf-objcopy
OBJDUMP = riscv64-elf-objdump

CFLAGS  = -march=rv32im -mabi=ilp32 -nostdlib -ffreestanding -Os
LDFLAGS = -m elf32lriscv -T linker.ld

ifeq ($(TEST),)
TARGET  := main
C_SRC   := main.c
else
TARGET  := $(TEST)
C_SRC   := tests/$(TEST).c
endif
C_OBJ := $(C_SRC:.c=.o)
SRCS    = boot.S $(C_SRC) npu.c
OBJS    = boot.o $(C_OBJ) npu.o
ELF := firmware_$(TARGET).elf
BIN := firmware_$(TARGET).bin
HEX := firmware_$(TARGET).hex

BRAM_WORDS = 2048   # 8KB / 4 bytes = 2048 words (change to 1024 for 4KB)

all: $(HEX)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@
	
$(ELF): $(OBJS)
	$(CC) $(CFLAGS) -T linker.ld $(OBJS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(BIN)
	python3 make_hex.py $< $(BRAM_WORDS) > $@
# --- Helpers -----
dump: $(ELF)
	$(OBJDUMP) -d $<

clean:
	rm -f boot.o npu.o main.o tests/*.o firmware_*.elf firmware_*.bin firmware_*.hex

.PHONY: all dump clean