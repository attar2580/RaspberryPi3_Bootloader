CC := aarch64-linux-gnu-gcc
OBJCOPY := aarch64-linux-gnu-objcopy
OBJDUMP := aarch64-linux-gnu-objdump
NM := aarch64-linux-gnu-nm

# Directories
SRC_DIR := src
BUILD_DIR := build
INC_DIR := include

# Bare-metal build flags for Cortex-A53.
CFLAGS := -ffreestanding -nostdlib -nostartfiles -O2 -mcpu=cortex-a53 -Wall -Wextra -I$(INC_DIR)
LDFLAGS := -T $(SRC_DIR)/linker.ld -nostdlib -nostartfiles -static

TARGET := kernel8
ELF := $(BUILD_DIR)/$(TARGET).elf
IMG := $(BUILD_DIR)/$(TARGET).img

# Find all C and Assembly sources
SRCS_C := $(wildcard $(SRC_DIR)/*.c)
SRCS_S := $(wildcard $(SRC_DIR)/*.s)

# Object files
OBJS := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS_C))
OBJS += $(patsubst $(SRC_DIR)/%.s, $(BUILD_DIR)/%.o, $(SRCS_S))

.PHONY: all clean dump sections symbols dirs

all: dirs $(IMG)

dirs:
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS) $(SRC_DIR)/linker.ld
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $@

$(IMG): $(ELF)
	$(OBJCOPY) -O binary $< $@

dump: $(ELF)
	$(OBJDUMP) -D $< > $(BUILD_DIR)/$(TARGET).dump

sections: $(ELF)
	$(OBJDUMP) -h $<

symbols: $(ELF)
	$(NM) -n $<

clean:
	rm -rf $(BUILD_DIR)
