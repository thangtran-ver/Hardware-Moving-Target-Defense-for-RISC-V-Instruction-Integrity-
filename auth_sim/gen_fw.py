#!/usr/bin/env python3
"""gen_fw.py -- sinh firmware test RV32I (assembler mini, chi dung cho TB).

Bien the:
  main   : vong lap tong 1..10, goi ham, load/store, ghi marker 0xDEADBEEF, spin
  inject : nhay vao data RAM 0x0002_0100 (ma chen) -> phai fault (region check)
  wcode  : main + 1 lenh store vao vung CODE -> phai fault, code khong doi
Ket qua mong doi o DATA: [0]=55, [1]=110, [2]=0xDEADBEEF
"""
import sys


def r(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def i_(imm, rs1, f3, rd, op): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def s_(imm, rs2, rs1, f3): return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23
def b_(imm, rs2, rs1, f3):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63
def u_(imm20, rd, op): return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def j_(imm, rd):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F

def ADD(rd, a, b): return lambda pc, L: r(0, b, a, 0, rd, 0x33)
def ADDI(rd, a, imm): return lambda pc, L: i_(imm, a, 0, rd, 0x13)
def LW(rd, a, imm): return lambda pc, L: i_(imm, a, 2, rd, 0x03)
def SW(src, a, imm): return lambda pc, L: s_(imm, src, a, 2)
def LUI(rd, imm20): return lambda pc, L: u_(imm20, rd, 0x37)
def JALR(rd, a, imm): return lambda pc, L: i_(imm, a, 0, rd, 0x67)
def BNE(a, b, lab): return lambda pc, L: b_(L[lab] - pc, b, a, 1)
def JAL(rd, lab): return lambda pc, L: j_(L[lab] - pc, rd)
NOP = ADDI(0, 0, 0)


def assemble(prog):
    labels, pc, items = {}, 0, []
    for x in prog:
        if isinstance(x, str):
            labels[x] = pc
        else:
            items.append((pc, x)); pc += 4
    return [f(pc, labels) for pc, f in items]


def program(variant):
    head = {
        "main":   [],
        "wcode":  [],
        "inject": [LUI(7, 0x20), ADDI(7, 7, 0x100), JALR(0, 7, 0)],
    }[variant]
    body = [
        LUI(10, 0x20),            # x10 = 0x0002_0000 (DATA)
        ADDI(2, 0, 0), ADDI(3, 0, 1), ADDI(4, 0, 11),
        "loop", ADD(2, 2, 3), ADDI(3, 3, 1), BNE(3, 4, "loop"),
        SW(2, 10, 0),             # DATA[0] = 55
        ADDI(11, 2, 0), JAL(1, "func"),
        SW(11, 10, 4),            # DATA[1] = 110
    ]
    if variant == "wcode":
        body += [SW(11, 0, 0)]    # ghi vao CODE[0] -> phai bi chan
    body += [
        LUI(6, 0xDEADC), ADDI(6, 6, -0x111),
        SW(6, 10, 8),             # DATA[2] = 0xDEADBEEF (marker)
        "spin", JAL(0, "spin"),
        NOP,
        "func", ADD(11, 11, 11), JALR(0, 1, 0),
    ]
    return assemble(head + body)


if __name__ == "__main__":
    v, out = sys.argv[1], sys.argv[2]
    words = program(v)
    with open(out, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")
    if v == "inject":   # ma chen trong data RAM (word 0x40 = 0x0002_0100)
        inj = assemble([LUI(6, 0x12345), SW(6, 10, 8), "s", JAL(0, "s")])
        with open(out.replace(".hex", "_data.hex"), "w") as f:
            f.write("@40\n" + "".join(f"{w:08x}\n" for w in inj))
