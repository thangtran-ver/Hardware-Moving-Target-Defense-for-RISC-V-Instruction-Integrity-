/*=====================================================================
 *  main.c -- firmware chay tren Tang Nano 20K qua auth_soc
 *            (PicoRV32 + authenticated_memory_wrapper + Ascon-128a)
 *
 *  Moi lenh CPU fetch deu da duoc wrapper xac thuc bang tag Ascon truoc
 *  khi vao CPU. Ket qua in ra UART (MMIO 0x0200_0010).
 *
 *  Sau kiem thu + do chi phi, firmware vao MONITOR: doc lenh tu UART RX
 *  (0x0200_0018) va doc/ghi bo nho THAT qua bus (giong tang_4k_apb):
 *      rb/rh/rw addr          doc byte / half word / word
 *      wb/wh/ww addr value    ghi byte / half word / word
 *      ti                     in cycle / instret
 *      he                     danh sach lenh       (so deu la hex)
 *
 *  Bien dich them -D de tao kich ban tan cong luc chay:
 *    -DATTACK_WCODE   : sw vao vung CODE  -> wrapper chan (WRITE-PROT)
 *    -DATTACK_JUMP    : nhay vao ma nam trong data RAM -> FETCH-NOCODE
 *
 *  Ban do bo nho (giong auth_sim/fw_c): CODE 0x0, TAG 0x10000,
 *  DATA 0x20000 (0x20000..0x200FF de trong, firmware dung tu 0x20100).
 *  RV32I thuan: KHONG dung '*', '/', '%'.
 *===================================================================*/
#include <stdint.h>

/* Ngoai vi DUY NHAT: UART (rtl/fpga_uart.v) */
#define REG(a)        (*(volatile uint32_t *)(a))
#define UART_TX_REG   REG(0x02000010u)
#define UART_ST_REG   REG(0x02000014u)   /* [0] TX busy [1] RX ready [2] RX overrun */
#define UART_RX_REG   REG(0x02000018u)   /* doc = lay 1 byte khoi FIFO RX */

/* Phai trung tangnano20k_top.v / make_variants.py */
#define CFG_G         4u
#define CFG_T         128u

/* Bo dem co san trong PicoRV32 (ENABLE_COUNTERS = 1, mac dinh cua
 * auth_soc_top): rdcycle = so chu ky, rdinstret = so lenh da thuc thi. */
static inline uint32_t rdcycle(void)   { uint32_t v; __asm__ volatile ("rdcycle %0"   : "=r"(v)); return v; }
static inline uint32_t rdinstret(void) { uint32_t v; __asm__ volatile ("rdinstret %0" : "=r"(v)); return v; }

#define CYC_PER_MS    27000u

void *memcpy(void *d, const void *s, uint32_t n)
{
    uint8_t *dd = (uint8_t *)d; const uint8_t *ss = (const uint8_t *)s;
    while (n--) *dd++ = *ss++;
    return d;
}
void *memset(void *d, int c, uint32_t n)
{
    uint8_t *dd = (uint8_t *)d;
    while (n--) *dd++ = (uint8_t)c;
    return d;
}

/*------------------------------------------------------------ UART */
static void putc_(char c)
{
    while (UART_ST_REG & 1u) { }
    UART_TX_REG = (uint32_t)(unsigned char)c;
}
static void puts_(const char *s)
{
    while (*s) { if (*s == '\n') putc_('\r'); putc_(*s++); }
}
static void __attribute__((unused)) put_hex(uint32_t v, int digits)
{
    int i;
    for (i = digits - 1; i >= 0; i--) {
        uint32_t n = (v >> (i << 2)) & 0xFu;
        putc_((char)(n < 10u ? '0' + n : 'A' + n - 10u));
    }
}
static void put_dec(uint32_t v)
{
    static const uint32_t p10[10] = {
        1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
        10000u, 1000u, 100u, 10u, 1u };
    int i, started = 0;
    for (i = 0; i < 10; i++) {
        int d = 0;
        while (v >= p10[i]) { v -= p10[i]; d++; }
        if (d || started || i == 9) { putc_((char)('0' + d)); started = 1; }
    }
}
static uint32_t udiv(uint32_t n, uint32_t d)
{
    uint32_t q = 0, r = 0;
    int i;
    if (d == 0u) return 0xFFFFFFFFu;
    for (i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1u);
        if (r >= d) { r -= d; q |= (1u << i); }
    }
    return q;
}
static uint32_t mul100(uint32_t x) { return (x << 6) + (x << 5) + (x << 2); }

static void __attribute__((unused)) delay_ms(uint32_t ms)
{
    while (ms--) {
        uint32_t t0 = rdcycle();
        while ((rdcycle() - t0) < CYC_PER_MS) { }
    }
}

/*------------------------------------------------------------ kiem thu */
static int n_test, n_fail;

static void check(const char *name, int ok)
{
    n_test++;
    puts_("  ["); put_dec((uint32_t)n_test); puts_("] ");
    puts_(name);
    puts_(ok ? " : OK\n" : " : SAI  <<<<<\n");
    if (!ok) n_fail++;
}

static int32_t fib(int32_t n)
{
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

static void bsort(int32_t *a, int n)
{
    int i, j;
    for (i = 0; i < n - 1; i++)
        for (j = 0; j < n - 1 - i; j++)
            if (a[j] > a[j + 1]) { int32_t t = a[j]; a[j] = a[j + 1]; a[j + 1] = t; }
}

/* giong auth_sim/fw_c/main.c */
int table[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};          /* .data -> DATA */
static volatile const uint32_t magic = 0xDEADBEEFu;       /* .rodata -> CODE */

__attribute__((noinline)) uint32_t twice(uint32_t x) { return x + x; }

__attribute__((noinline)) void run_tests(void)
{
    puts_("\n--- Kiem thu (moi lenh deu qua Ascon-128a truoc khi vao CPU) ---\n");
    {
        uint32_t s = 0; int i;
        for (i = 0; i < 10; i++) s += (uint32_t)table[i];
        check("Tong table[] (.data)       = 55", s == 55u);
        check("twice(55)                  = 110", twice(s) == 110u);
    }
    check("magic (.rodata, vung CODE) = DEADBEEF", magic == 0xDEADBEEFu);
    check("fib(10)                    = 55", fib(10) == 55);
    {
        int32_t a[6] = {55, 22, 99, 11, 44, 3};
        int i, ok = 1;
        bsort(a, 6);
        for (i = 0; i < 5; i++) if (a[i] > a[i + 1]) ok = 0;
        check("Sap xep noi bot 6 phan tu  = tang dan", ok);
    }
    {
        static volatile int32_t m[4];
        int i, ok = 1;
        for (i = 0; i < 4; i++) m[i] = (i << 3) + (i << 1) + i;
        for (i = 0; i < 4; i++) if (m[i] != (i << 3) + (i << 1) + i) ok = 0;
        check("Ghi/doc data RAM           = 11*i", ok);
    }
}

/*------------------------------------------------------------ chi phi */
static volatile int32_t sink;

__attribute__((noinline)) void bench(void)
{
    uint32_t c0, i0, cyc, ins;
    int32_t arr[24];
    int i;

    for (i = 0; i < 24; i++) arr[i] = 24 - i;

    c0 = rdcycle(); i0 = rdinstret();
    sink = fib(12);
    bsort(arr, 24);
    cyc = rdcycle() - c0; ins = rdinstret() - i0;

    puts_("\n--- Chi phi (kernel: fib(12) + bubble sort 24 phan tu) ---\n");
    puts_("  So chu ky             : "); put_dec(cyc); puts_("\n");
    puts_("  So lenh da thuc thi   : "); put_dec(ins); puts_("\n");
    puts_("  CPI                   : "); put_dec(udiv(cyc, ins)); puts_(".");
    {
        uint32_t frac = udiv(mul100(cyc), ins) - mul100(udiv(cyc, ins));
        if (frac < 10u) putc_('0');
        put_dec(frac);
    }
    puts_("\n  Ket qua               : ");
    puts_((sink == 144 && arr[0] == 1 && arr[23] == 24) ? "dung\n" : "SAI\n");
}

/*------------------------------------------------------------ tan cong */
#ifdef ATTACK_WCODE
__attribute__((noinline)) void attack_wcode(void)
{
    volatile uint32_t *p = (volatile uint32_t *)(uintptr_t)&twice;
    uint32_t before = *p;
    puts_("\n!!! TAN CONG: sw vao vung CODE (ghi de lenh dau cua twice()) !!!\n");
    puts_("  @0x"); put_hex((uint32_t)(uintptr_t)p, 8);
    puts_(" truoc = 0x"); put_hex(before, 8); puts_("\n");
    while (UART_ST_REG & 1u) { }
    *p = 0x53900513u;                        /* addi a0, zero, 1337 */
    delay_ms(10);                            /* de reporter in xong */
    puts_("  sau   = 0x"); put_hex(*p, 8);
    puts_(*p == before ? "  -> KHONG doi, lenh ghi bi chan\n" : "  -> DA BI SUA!\n");
    puts_("  twice(21) = "); put_dec(twice(21u)); puts_("\n");
}
#endif

#ifdef ATTACK_JUMP
static uint32_t shellcode[2];               /* .bss -> DATA RAM */
__attribute__((noinline)) void attack_jump(void)
{
    uint32_t (*fn)(void) = (uint32_t (*)(void))(uintptr_t)shellcode;
    shellcode[0] = 0x53900513u;              /* addi a0, zero, 1337 */
    shellcode[1] = 0x00008067u;              /* ret                 */
    puts_("\n!!! TAN CONG: nhay vao ma nam trong data RAM @0x");
    put_hex((uint32_t)(uintptr_t)shellcode, 8); puts_(" !!!\n");
    while (UART_ST_REG & 1u) { }
    puts_("  ket qua = "); put_dec(fn()); puts_("  -> TAN CONG THANH CONG?!\n");
}
#endif

/*------------------------------------------------------------ monitor */
/* Lenh doc/ghi bo nho qua UART, giong c_code/main.c cua tang_4k_apb.
 * Moi lenh deu la lw/lh/lb/sw/sh/sb THAT tren bus: CPU -> wrapper ->
 * fpga_system_memory / fpga_uart. Vi vay:
 *   - DATA RAM 0x0002_0000..0x0002_0FFF : doc/ghi duoc, gia tri duoc LUU.
 *     0x0002_0000..0x0002_00FF de trong -> vung thu an toan.
 *     (tu 0x0002_0100 la .data/.bss/stack cua firmware: ghi bay se hong)
 *   - CODE 0x0000_0000.. / TAG 0x0001_0000.. : doc duoc (thay ma da ky,
 *     tag Ascon); GHI bi wrapper chan -> [AUTH] FAULT: WRITE-PROT.
 *   - Dia chi khong co gi (vd 0x4000_2400): doc = 0, ghi bi bo qua.
 */
static void put_hexl(uint32_t v, int digits)        /* chu thuong nhu anh */
{
    int i;
    for (i = digits - 1; i >= 0; i--) {
        uint32_t n = (v >> (i << 2)) & 0xFu;
        putc_((char)(n < 10u ? '0' + n : 'a' + n - 10u));
    }
    puts_("\n");
}

static int getc_(void)
{
    while (!(UART_ST_REG & 2u)) { }
    return (int)(UART_RX_REG & 0xFFu);
}

#define LINE_MAX 64

/* doc 1 dong, co echo + backspace. Tra ve do dai (0 = dong rong). */
static uint32_t gets_(char *buf)
{
    uint32_t n = 0;
    for (;;) {
        int c = getc_();
        if (c == '\r' || c == '\n') {
            if (n == 0u) continue;          /* bo dong rong / LF sau CR */
            puts_("\n");
            buf[n] = 0;
            return n;
        }
        if (c == 8 || c == 127) {           /* backspace */
            if (n) { n--; puts_("\b \b"); }
            continue;
        }
        if (c < ' ' || n >= LINE_MAX - 1) continue;
        buf[n++] = (char)c;
        putc_((char)c);
    }
}

static const char *skip_sp(const char *p)
{
    while (*p == ' ' || *p == '\t') p++;
    return p;
}

/* doc 1 so hex (toi da 8 chu so). Tra ve 1 neu hop le. */
static int get_hex(const char **pp, uint32_t *v)
{
    const char *p = skip_sp(*pp);
    int nd = 0;
    *v = 0;
    for (;;) {
        char c = *p;
        uint32_t d;
        if      (c >= '0' && c <= '9') d = (uint32_t)(c - '0');
        else if (c >= 'a' && c <= 'f') d = (uint32_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') d = (uint32_t)(c - 'A' + 10);
        else break;
        *v = (*v << 4) | d;
        p++; nd++;
    }
    *pp = p;
    return nd > 0 && nd <= 8 && (*p == 0 || *p == ' ' || *p == '\t');
}

static void help(void)
{
    puts_("rb addr       : read byte\n");
    puts_("rh addr       : read half word\n");
    puts_("rw addr       : read word\n");
    puts_("wb addr value : write byte\n");
    puts_("wh addr value : write half word\n");
    puts_("ww addr value : write word\n");
    puts_("ti            : cycle / instret\n");
    puts_("   all numbers are hex\n");
    puts_("   DATA RAM 20000..200ff : vung thu (doc/ghi, luu that)\n");
    puts_("   CODE 0.. / TAG 10000..: chi doc (ghi -> WRITE-PROT)\n");
}

static void parse(const char *p)
{
    char c0, c1;
    uint32_t a, v;
    int size;                               /* 1 / 2 / 4 byte */

    p = skip_sp(p);
    c0 = p[0]; c1 = p[1];
    if (c0 == 0 || c1 == 0 || (p[2] != 0 && p[2] != ' ' && p[2] != '\t'))
        goto bad;
    p += 2;

    if (c0 == 'h' && c1 == 'e') { help(); return; }
    if (c0 == 't' && c1 == 'i') {
        puts_("cycle="); put_dec(rdcycle());
        puts_("  instret="); put_dec(rdinstret()); puts_("\n");
        return;
    }
    if (c0 != 'r' && c0 != 'w') goto bad;
    if      (c1 == 'b') size = 1;
    else if (c1 == 'h') size = 2;
    else if (c1 == 'w') size = 4;
    else goto bad;

    if (!get_hex(&p, &a)) goto bad;
    if (a & (uint32_t)(size - 1)) {         /* lech -> PicoRV32 se trap */
        puts_("dia chi phai chia het cho "); put_dec((uint32_t)size); puts_("\n");
        return;
    }

    if (c0 == 'r') {
        if (*skip_sp(p) != 0) goto bad;
        if (size == 1)      put_hexl(*(volatile uint8_t  *)(uintptr_t)a, 2);
        else if (size == 2) put_hexl(*(volatile uint16_t *)(uintptr_t)a, 4);
        else                put_hexl(*(volatile uint32_t *)(uintptr_t)a, 8);
        return;
    }

    if (!get_hex(&p, &v) || *skip_sp(p) != 0) goto bad;
    while (UART_ST_REG & 1u) { }            /* in xong truoc khi ghi,  */
    if (size == 1)      *(volatile uint8_t  *)(uintptr_t)a = (uint8_t)v;   /* neu bi */
    else if (size == 2) *(volatile uint16_t *)(uintptr_t)a = (uint16_t)v;  /* chan, */
    else                *(volatile uint32_t *)(uintptr_t)a = v;            /* dong */
    return;                                 /* [AUTH] FAULT khong bi chen giua */
bad:
    puts_("illegal command, he for help\n");
}

static void monitor(void)
{
    static char line[LINE_MAX];
    while (UART_ST_REG & 2u) (void)UART_RX_REG;   /* bo ky tu go luc khoi dong */
    puts_("\nenter he for a list of commands\n");
    for (;;) {
        puts_("> ");
        gets_(line);
        parse(line);
    }
}

/*====================================================================*/
int main(void)
{

    puts_("\n\n==================================================\n");
    puts_("  Journal MTD baseline -- static instruction integrity\n");
    puts_("  auth_soc: PicoRV32 + Ascon-128a | Tang Nano 20K\n");
    puts_("==================================================\n");
    puts_("  G = "); put_dec(CFG_G); puts_(" lenh/block   T = ");
    put_dec(CFG_T); puts_(" bit tag\n");

    run_tests();
    puts_("  => "); put_dec((uint32_t)(n_test - n_fail)); puts_("/");
    put_dec((uint32_t)n_test); puts_(" dung\n");

    bench();

#ifdef ATTACK_WCODE
    attack_wcode();
#endif
#ifdef ATTACK_JUMP
    attack_jump();
#endif

    monitor();
    return 0;
}
