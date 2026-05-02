/* AArch64 reset entry for Raspberry Pi 3 (BCM2837). */
.section .text.boot
.global _start

_start:
  /* Identify core; only core 0 continues. */
  mrs x0, mpidr_el1
  and x0, x0, #0xff
  cbz x0, .Lprimary

.Lsecondary_wait:
  wfe
  b .Lsecondary_wait

.Lprimary:
  /* Set stack pointer to 0x80000 (grows downward). */
  ldr x0, =_start
  mov sp, x0

  /* Zero .bss using 8-byte stores. */
  ldr x1, =__bss_start
  ldr x2, =__bss_end
  cmp x1, x2
  b.hs .Lbss_done

.Lbss_clear:
  str xzr, [x1], #8
  cmp x1, x2
  b.lo .Lbss_clear

.Lbss_done:
  bl main

.Lhalt:
  wfe
  b .Lhalt
