#include <stdint.h>

/* BCM2837 peripheral base for MMIO. */
#define MMIO_BASE 0x3F000000u

#define GPFSEL1 (*(volatile uint32_t *)(MMIO_BASE + 0x200004U))
#define GPPUD (*(volatile uint32_t *)(MMIO_BASE + 0x200094U))
#define GPPUDCLK0 (*(volatile uint32_t *)(MMIO_BASE + 0x200098U))

#define AUX_ENABLES (*(volatile uint32_t *)(MMIO_BASE + 0x215004U))
#define AUX_MU_IO_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215040U))
#define AUX_MU_IER_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215044U))
#define AUX_MU_IIR_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215048U))
#define AUX_MU_LCR_REG (*(volatile uint32_t *)(MMIO_BASE + 0x21504CU))
#define AUX_MU_MCR_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215050U))
#define AUX_MU_LSR_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215054U))
#define AUX_MU_CNTL_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215060U))
#define AUX_MU_BAUD_REG (*(volatile uint32_t *)(MMIO_BASE + 0x215068U))

static inline void delay(int32_t count)
{
  while (count-- > 0)
  {
    __asm__ volatile("nop");
  }
}

static void uart_init(void)
{
  uint32_t selector = 0;

  /* Enable mini UART and configure for 8N1 at 115200 baud. */
  AUX_ENABLES = 1U;
  AUX_MU_CNTL_REG = 0U;
  AUX_MU_IER_REG = 0U;
  AUX_MU_IIR_REG = 0xC6U;
  AUX_MU_LCR_REG = 3U;
  AUX_MU_MCR_REG = 0U;
  AUX_MU_BAUD_REG = 270U;

  /* Map GPIO14/15 to ALT5 (TXD1/RXD1). */
  selector = GPFSEL1;
  selector &= ~((7u << 12) | (7u << 15));
  selector |= (2u << 12) | (2u << 15);
  GPFSEL1 = selector;

  /* Disable GPIO pull-ups/downs for UART pins. */
  GPPUD = 0U;
  delay(150);
  GPPUDCLK0 = (1U << 14) | (1U << 15);
  delay(150);
  GPPUDCLK0 = 0U;

  AUX_MU_CNTL_REG = 3U;
}

static void uart_putc(char c)
{
  while ((AUX_MU_LSR_REG & 0x20U) == 0U)
  {
  }
  AUX_MU_IO_REG = (uint32_t)c;
}

static void uart_puts(const char *s)
{
  while (*s)
  {
    if (*s == '\n')
    {
      uart_putc('\r');
    }
    uart_putc(*s++);
  }
}

static uint64_t read_current_el(void)
{
  uint64_t el = 0;
  /* CurrentEL[3:2] contains the exception level. */
  __asm__ volatile("mrs %0, CurrentEL" : "=r"(el));
  return el;
}

__attribute__((noreturn)) void main(void)
{
  uart_init();
  uart_puts("RPi3 BCM2837 Bootloader\n");
  /* Print current exception level (EL0-EL3). */
  uint64_t el = read_current_el() >> 2U;
  uart_puts("Exception Level: EL");
  uart_putc('0' + (char)el);
  uart_puts("\n");

  while (1)
  {
    __asm__ volatile("wfe");
  }
}
