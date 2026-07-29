# RPi3 Bare-Metal AArch64 Bootloader

A bare-metal bootloader for the Raspberry Pi 3 (BCM2837 SoC) written from scratch in AArch64 assembly and C. No operating system, no standard library, no hardware abstraction layer — direct MMIO register access on real silicon.

Tested on both **QEMU raspi3b** emulator and **physical Raspberry Pi 3 Model B** hardware via UART.

---

## Output

```
Core 1/2/3 parked
Initializing Core 0...
RPi3 BCM2837 Bootloader
Exception Level: EL2
```

---

## Project Structure

```
rpi3-bootloader/
├── src/
│   ├── boot.s        ← AArch64 assembly entry point (_start at 0x80000)
│   ├── main.c        ← Bare-metal C bootloader logic (UART init, banner)
│   └── linker.ld     ← GNU linker script (memory layout)
├── firmware/
│   ├── bootcode.bin  ← GPU Stage 2 blob (from RPi firmware repo)
│   ├── start.elf     ← GPU Stage 3 blob (from RPi firmware repo)
│   └── fixup.dat     ← Memory split fixup (from RPi firmware repo)
├── config/
│   └── config.txt    ← RPi boot configuration
├── build/
│   ├── kernel8.elf   ← ELF with debug symbols (objdump/GDB target)
│   └── kernel8.img   ← Raw binary flashed to SD card (498 bytes)
└── Makefile
```

---

## BCM2837 Boot Sequence

The BCM2837 follows a GPU-first boot architecture. The ARM Cortex-A53 cores are held in reset until the VideoCore IV GPU completes its boot sequence.

```
Power ON
   │
   ▼
[Stage 1] ROM Bootloader          — baked into BCM2837 silicon
   │       mounts SD FAT, loads bootcode.bin
   ▼
[Stage 2] bootcode.bin            — GPU blob, closed source
   │       initialises SDRAM, loads start.elf
   ▼
[Stage 3] start.elf + fixup.dat  — GPU blob, closed source
   │       reads config.txt, loads kernel8.img → 0x80000
   │       releases ARM Cortex-A53 from reset
   ▼
[Stage 4] armstub8.bin            — EL3 stub (default built into start.elf)
   │       SMP spin-table, drops to EL2
   ▼
[Stage 5] kernel8.img             ← THIS PROJECT
           _start at 0x80000, EL2, AArch64
```

---

## Source Files

### `src/boot.s` — Assembly Entry Point

First code to run on the ARM core. Handles the multi-core problem — all 4 Cortex-A53 cores start simultaneously at `0x80000`.

- Reads `MPIDR_EL1` to identify core ID
- Parks cores 1, 2, 3 in low-power `wfe` loop
- Sets stack pointer to `0x80000` (grows downward)
- Zeros `.bss` section using 8-byte `str xzr` stores
- Branches to `main()`

### `src/main.c` — Bootloader Logic

Bare-metal C with direct volatile MMIO register access. No `#include` beyond `<stdint.h>`.

- All BCM2837 peripheral registers defined as `*(volatile uint32_t *)` macros
- Initialises mini UART: GPIO14/15 switched to ALT5, baud divisor = 270
- Baud rate formula: `(250,000,000 / (8 × 115200)) − 1 = 270`
- Reads `CurrentEL` system register, shifts `>> 2` to extract EL value
- Prints boot banner then halts in `wfe` loop

### `src/linker.ld` — Memory Layout

```
0x80000   .text.boot    _start — must be first
          .text         C functions
          .rodata       string literals
          .data         initialised globals (empty)
          .bss          zero-initialised (NOLOAD, ALIGN(8))
          /DISCARD/     .gnu* .note* .eh_frame* .comment
```

### `Makefile`

```makefile
CROSS   = aarch64-linux-gnu
CFLAGS  = -ffreestanding -nostdlib -nostartfiles -O2 -mcpu=cortex-a53
LDFLAGS = -T src/linker.ld -nostdlib -nostartfiles -static
```

Produces `kernel8.elf` (debug symbols) and `kernel8.img` (raw binary via `objcopy -O binary`).

---

## Physical Memory Map (BCM2837)

| Address | Region |
|---|---|
| `0x00000000` | GPU / VideoCore mailbox |
| `0x00008000` | ARM stub (armstub8.bin) |
| **`0x00080000`** | **kernel8.img — ARM entry point** |
| `0x3F000000` | Peripheral MMIO base |
| `0x3F200000` | GPIO registers |
| `0x3F215000` | AUX / mini UART registers |
| `0x40000000` | ARM local peripherals |

> **Note:** MMIO base is `0x3F000000` on RPi3 (BCM2837). RPi1/2 use `0x20000000` — a common porting mistake.

---

## Requirements

```bash
# Cross toolchain
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

# QEMU (optional, for emulator testing)
sudo apt install qemu-system-aarch64
```

---

## Build

```bash
make              # builds kernel8.elf and kernel8.img
make clean        # remove build artifacts
make dump         # disassemble kernel8.elf
make sections     # show section addresses and sizes
make symbols      # show symbol table sorted by address
```

### Verify the binary

```bash
# _start must be at exactly 0x80000
aarch64-linux-gnu-nm build/kernel8.elf | grep _start
# 0000000000080000 T _start

# First 4 bytes must be AArch64 instruction, NOT ELF header (7f 45 4c 46)
xxd build/kernel8.img | head -1
# 00000000: a000 38d5 ...   ← mrs x0, mpidr_el1 ✓

# Binary size
ls -lh build/kernel8.img
# 498 bytes
```

---

## Test on QEMU

```bash
make qemu
```

Which runs:

```bash
qemu-system-aarch64 \
    -M raspi3b \
    -kernel build/kernel8.img \
    -serial null \
    -serial stdio \
    -display none
```

> QEMU's `raspi3b` machine maps the mini UART to the **second** serial port — `-serial null -serial stdio` is required, not just `-serial stdio`.

### Debug with GDB

```bash
make qemu-gdb     # starts QEMU, waits for GDB on port 1234
```

In a second terminal:

```bash
aarch64-linux-gnu-gdb build/kernel8.elf
(gdb) target remote :1234
(gdb) b _start
(gdb) b main
(gdb) c
(gdb) si                  # step one instruction
(gdb) info registers      # view all ARM registers
(gdb) p/x $sp             # check stack pointer
```

---

## Flash to Physical Hardware

### SD Card Preparation

Format as FAT32. Copy exactly these 5 files to the root:

```
bootcode.bin    ← from firmware/
start.elf       ← from firmware/
fixup.dat       ← from firmware/
config.txt      ← from config/
kernel8.img     ← from build/
```

```bash
SD=/media/$USER/boot

cp firmware/bootcode.bin  $SD/
cp firmware/start.elf     $SD/
cp firmware/fixup.dat     $SD/
cp config/config.txt      $SD/
cp build/kernel8.img      $SD/
sync
```

### config.txt

```ini
arm_64bit=1       # load kernel8.img, boot AArch64 EL2
enable_uart=1     # enable mini UART on GPIO14/15
core_freq=250     # lock core clock — required for stable baud rate
```

> `core_freq=250` is critical. Without it the GPU clock varies dynamically, the baud rate drifts from 115200, and UART output is garbled.

### UART Wiring (USB-TTL adapter → RPi3 GPIO)

```
RPi3 Pin 8  (GPIO14 TXD) → White wire → RX on adapter
RPi3 Pin 10 (GPIO15 RXD) → Green wire → TX on adapter
RPi3 Pin 6  (GND)        → Black wire → GND on adapter
Red wire (5V)             → DO NOT CONNECT
```

### Open terminal before powering on

```bash
sudo cat /dev/ttyUSB0       # simplest
# or
screen /dev/ttyUSB0 115200
# or
minicom -b 115200 -D /dev/ttyUSB0
```

Power on the board. Output appears within 2 seconds.

---

## Key Technical Details

| Parameter | Value |
|---|---|
| Target SoC | BCM2837 (Raspberry Pi 3) |
| CPU | ARM Cortex-A53, AArch64 |
| Entry point | `0x80000` |
| Exception level | EL2 |
| MMIO base | `0x3F000000` |
| UART | Mini UART (AUX), GPIO14/15, ALT5 |
| Baud rate | 115200 (divisor = 270 @ 250MHz) |
| Binary size | 498 bytes |
| Toolchain | `aarch64-linux-gnu-gcc` |
| Host OS | Ubuntu 24.04 x86\_64 |

---

## Datasheets Referenced

- [BCM2837 ARM Peripherals](https://datasheets.raspberrypi.com/bcm2835/bcm2835-peripherals.pdf) — MMIO register map, GPIO, mini UART
- [ARM Architecture Reference Manual ARMv8-A](https://developer.arm.com/documentation/ddi0487/latest) — AArch64 ISA, system registers, exception levels
- [Raspberry Pi Firmware Repository](https://github.com/raspberrypi/firmware/tree/master/boot) — GPU blobs source

---

## Skills Demonstrated

- BCM2837 SoC architecture and GPU-first boot sequence
- AArch64 bare-metal assembly — system registers, multi-core management, BSP
- GNU linker script authoring for bare-metal memory layout
- Bare-metal C with direct volatile MMIO register access
- BCM2837 peripheral bring-up — GPIO alternate function, mini UART init
- Cross-compilation toolchain — gcc, objcopy, objdump, nm for AArch64
- QEMU system emulation for pre-hardware firmware validation
- Physical hardware debugging via USB-UART and GPIO serial output
- SD card firmware flashing and boot configuration

---

## Author

**Fardeen Attar**
Electronics and Communication Engineering
KLS Gogte Institute of Technology, Belagavi
Embedded Firmware Engineer — Red Nerds (Evobi Automations Pvt Ltd)
