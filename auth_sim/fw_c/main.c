#define OUT ((volatile unsigned int *)0x00020000)
int table[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};          /* .data -> DATA */
static volatile const unsigned int magic = 0xDEADBEEF;    /* .rodata -> CODE */
unsigned int counter;                                     /* .bss */

__attribute__((noinline)) unsigned int twice(unsigned int x) { return x + x; }

int main(void) {
    unsigned int s = 0;
    for (int i = 0; i < 10; i++) { s += table[i]; counter++; }
    OUT[0] = s;            /* 55 */
    OUT[1] = twice(s);     /* 110 */
    OUT[2] = magic;        /* 0xDEADBEEF */
    while (1) ;
}
