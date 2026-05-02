/* Load image at 0x80000 with entry symbol _start. */
ENTRY(_start)

SECTIONS
{
  . = 0x80000;

  .text.boot :
  {
    KEEP(*(.text.boot))
  }

  /* Code sections. */
  .text :
  {
    *(.text .text.*)
  }

  /* Read-only data. */
  .rodata :
  {
    *(.rodata .rodata.*)
  }

  /* Initialized data. */
  .data :
  {
    *(.data .data.*)
  }

  /* Zero-initialized data; aligned for 8-byte stores. */
  .bss (NOLOAD) :
  {
    . = ALIGN(8);
    __bss_start = .;
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(8);
    __bss_end = .;
  }

  .got :
  {
    *(.got .got.*)
  }

  /DISCARD/ :
  {
    *(.comment .gnu* .note* .eh_frame*)
  }
}
