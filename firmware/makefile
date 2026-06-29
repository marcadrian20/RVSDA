CC      = riscv64-elf-gcc
LD      = riscv64-elf-ld
OBJCOPY = riscv64-elf-objcopy
OBJDUMP = riscv64-elf-objdump

CFLAGS  = -march=rv32im -mabi=ilp32 -nostdlib -ffreestanding -Os
LDFLAGS = -m elf32lriscv -T linker.ld

SRCS    = boot.S main.c npu.c
OBJS    = boot.o main.o npu.o

BRAM_WORDS = 2048   # 8KB / 4 bytes = 2048 words (change to 1024 for 4KB)

all: firmware.hex

boot.o: boot.S
	$(CC) $(CFLAGS) -c boot.S -o boot.o

main.o: main.c
	$(CC) $(CFLAGS) -c main.c -o main.o

firmware.elf: $(OBJS)
	$(CC) $(CFLAGS) -T linker.ld $(OBJS) -o firmware.elf
#$(LD) $(LDFLAGS) $(OBJS) -o firmware.elf
firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin
firmware.hex: firmware.bin
	python3 make_hex.py firmware.bin $(BRAM_WORDS) > firmware.hex
# --- Helpers -----
dump: firmware.elf
	$(OBJDUMP) -d firmware.elf

clean:
	rm -f $(OBJS) firmware.elf firmware.hex

.PHONY: all dump clean