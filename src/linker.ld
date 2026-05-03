/* Load image at 0x80000 with entry symbol _start. */
ENTRY(_start)

SECTIONS
{
  /*Location counter (.) set to 0x80000 here - cursor starts from this address location and moves forward in sequence*/
  . = 0x80000;

  /*_start (boot.s entry)*/
  .text.boot :
  {
    KEEP(*(.text.boot))
  }

  /* Code sections. - All your C functions from main.c — uart_init, uart_putc, uart_puts, main, etc.*/
  .text :
  {
    *(.text .text.*)
  }

  /* Read-only data. - string literals and const variables. */
  .rodata :
  {
    *(.rodata .rodata.*)
  }

  /* Initialized data. - Initialized Global and Static variables*/
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

  /*Global Offset Table*/
  .got :
  {
    *(.got .got.*)
  }

  /*All comments, gnu hash tables etc discarded*/
  /DISCARD/ :
  {
    *(.comment .gnu* .note* .eh_frame*)
  }
}
