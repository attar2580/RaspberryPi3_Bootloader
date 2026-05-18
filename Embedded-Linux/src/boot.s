/* AArch64 reset entry for Raspberry Pi 3 (BCM2837). */
.section .text.boot 
.global _start

_start:
  /* Identify core; only core 0 continues. */
  mrs x0, mpidr_el1   /* → read core ID */
  and x0, x0, #0xff   /* → isolate Aff0 bits */
  cbz x0, .Lprimary   /* → core 0 jumps, others fall through */

.Lsecondary_wait:     /* → cores 1,2,3 stuck here forever */
  wfe
  b .Lsecondary_wait

.Lprimary:            /* → only core 0 from here */
  /* Set stack pointer to 0x80000 (grows downward). */
  ldr x0, =_start     /* → x0 = 0x80000 */
  mov sp, x0          /* → sp = 0x80000 */

  /* Zero .bss using 8-byte stores. */
  ldr x1, =__bss_start
  ldr x2, =__bss_end
  cmp x1, x2
  b.hs .Lbss_done     /* → skip if BSS empty */

.Lbss_clear:
  str xzr, [x1], #8   /* → zero 8 bytes, advance */
  cmp x1, x2
  b.lo .Lbss_clear    /* → loop until done */

.Lbss_done:
  bl main             /* → jump to C code ← you are here in QEMU */

.Lhalt:               /* → only reached if main() returns */
  wfe
  b .Lhalt
