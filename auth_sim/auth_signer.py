#!/usr/bin/env python3
"""auth_signer.py -- sinh code/tag/data hex cho baseline static integrity.

Khop bit voi authenticated_memory_wrapper (cac khoi auth_*.v) + ascon_top:
  * Lenh KHONG ma hoa: code_rom chua lenh plaintext, chi them tag xac thuc.
  * Moi block G word (G lenh) co 1 tag Ascon-128a v1.2 (plaintext rong):
        nonce = PROGRAM_ID(8 B) || IMAGE_ID(8 B)                  (big-endian)
        AD    = block_addr(4 B) || word0(4 B) || ... || word(G-1)  (big-endian)
        tag   = 128 bit; luu T bit dau, moi word 32 bit MSB truoc
  * Tag cua block i nam o TAG_BASE + i * (T/8)  ->  tag_rom[i * T/32 ...]
  * Word lenh = 4 byte little-endian trong bo nho RISC-V (giong $readmemh vao code_rom).

Lenh con:
  sign   : firmware -> code.hex, tag.hex (+ data.hex)
  check  : tinh lai tag tu code.hex, so voi tag.hex, bao block sai
  trace  : in nonce, tung beat AD (a_ad_data/a_ad_nbytes/a_ad_last) va tag
           mong doi cua 1 dia chi -> doi chieu waveform
  selftest: kiem tra Ascon voi vector chuan

Dau vao firmware (chon 1):
  --elf  fw.elf              ELF32 RISC-V (khuyen dung: lay dung dia chi tung segment)
  --bin  fw.bin --bin-base 0 file nhi phan tho
  --memh fw.hex              $readmemh 32 bit/word, '@' = chi so word
                             (vd. objcopy -O verilog --verilog-data-width=4 neu da nap
                              thang vao RAM 32 bit duoc)
  --vhex fw.vh               objcopy -O verilog (1 byte/token, '@' = dia chi byte)

Vi du:
  python auth_signer.py sign --elf fw.elf --out-code code.hex --out-tag tag.hex --out-data data.hex
  python auth_signer.py check --code code.hex --tag tag.hex
  python auth_signer.py trace --code code.hex --tag tag.hex --addr 0x14
"""
import argparse
import struct
import sys

# =========================================================== Ascon-128a v1.2
_M = (1 << 64) - 1
_IV_128A = 0x80800C0800000000


def _rotr(x, n):
    return ((x >> n) | (x << (64 - n))) & _M


def _round(S, c):
    x0, x1, x2, x3, x4 = S
    x2 ^= c
    x0 ^= x4; x4 ^= x3; x2 ^= x1
    t0 = (~x0 & _M) & x1; t1 = (~x1 & _M) & x2; t2 = (~x2 & _M) & x3
    t3 = (~x3 & _M) & x4; t4 = (~x4 & _M) & x0
    x0 ^= t1; x1 ^= t2; x2 ^= t3; x3 ^= t4; x4 ^= t0
    x1 ^= x0; x0 ^= x4; x3 ^= x2; x2 = ~x2 & _M
    x0 ^= _rotr(x0, 19) ^ _rotr(x0, 28)
    x1 ^= _rotr(x1, 61) ^ _rotr(x1, 39)
    x2 ^= _rotr(x2, 1) ^ _rotr(x2, 6)
    x3 ^= _rotr(x3, 10) ^ _rotr(x3, 17)
    x4 ^= _rotr(x4, 7) ^ _rotr(x4, 41)
    return [x0, x1, x2, x3, x4]


def _perm(S, rounds):
    for i in range(12 - rounds, 12):
        S = _round(S, ((0xF - i) << 4) | i)
    return S


def ascon128a_mac(key, nonce, ad):
    """Ascon-128a v1.2 voi plaintext rong -> tag 16 byte (dung nhu ascon_top)."""
    b2i = lambda b: int.from_bytes(b, "big")
    K0, K1 = b2i(key[:8]), b2i(key[8:])
    S = _perm([_IV_128A, K0, K1, b2i(nonce[:8]), b2i(nonce[8:])], 12)
    S[3] ^= K0; S[4] ^= K1
    if ad:
        a = ad + b"\x80" + b"\x00" * (15 - len(ad) % 16)
        for i in range(0, len(a), 16):
            S[0] ^= b2i(a[i:i + 8]); S[1] ^= b2i(a[i + 8:i + 16])
            S = _perm(S, 8)
    S[4] ^= 1
    S[0] ^= 0x8000000000000000          # padding plaintext rong
    S[2] ^= K0; S[3] ^= K1
    S = _perm(S, 12)
    return (S[3] ^ K0).to_bytes(8, "big") + (S[4] ^ K1).to_bytes(8, "big")


# Vector chuan Ascon-128a v1.2 (key 00..0F, nonce 10..1F, PT rong; khop ascon-c v1.2.8 KAT)
_KAT = [
    ("", "6db880ca0cfa1d6af9a82abe364084d9"),
    ("a0", "04e4dfedde163ddb50be3e5d861d2a02"),
    ("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf", "499b9882933852ec8f0060f00766d8cd"),
    ("a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3", "2b9a1e9a16476960464a84a6d1211a99"),
]


def selftest(verbose=False):
    key, nonce = bytes(range(16)), bytes(range(16, 32))
    for ad, tag in _KAT:
        got = ascon128a_mac(key, nonce, bytes.fromhex(ad)).hex()
        if got != tag:
            raise SystemExit(f"selftest FAIL: AD={ad or '(rong)'} got {got} exp {tag}")
    if verbose:
        print(f"selftest PASS: {len(_KAT)} vector Ascon-128a v1.2")


# =========================================================== doc firmware
def _mem_put_bytes(mem, addr, data):
    for i, b in enumerate(data):
        mem[addr + i] = b


def load_elf(path):
    """Doc cac PT_LOAD cua ELF32 little-endian -> {dia_chi_byte: byte}."""
    raw = open(path, "rb").read()
    if raw[:4] != b"\x7fELF" or raw[4] != 1 or raw[5] != 1:
        raise SystemExit("chi ho tro ELF32 little-endian (RISC-V rv32)")
    e_phoff, = struct.unpack_from("<I", raw, 28)
    e_phentsize, e_phnum = struct.unpack_from("<HH", raw, 42)
    mem = {}
    for i in range(e_phnum):
        p_type, p_off, p_vaddr, p_paddr, p_filesz, p_memsz, _, _ = \
            struct.unpack_from("<8I", raw, e_phoff + i * e_phentsize)
        if p_type != 1 or p_memsz == 0:          # PT_LOAD
            continue
        seg = raw[p_off:p_off + p_filesz] + b"\x00" * (p_memsz - p_filesz)
        _mem_put_bytes(mem, p_paddr, seg)        # LMA: noi du lieu duoc nap
    return mem


def load_bin(path, base):
    mem = {}
    _mem_put_bytes(mem, base, open(path, "rb").read())
    return mem


def load_vhex(path):
    """objcopy -O verilog (1 byte/token, '@' = dia chi byte)."""
    mem, addr = {}, 0
    for line in open(path):
        for tok in line.split("//")[0].split():
            if tok.startswith("@"):
                addr = int(tok[1:], 16)
            else:
                if len(tok) != 2:
                    raise SystemExit("--vhex chi nhan 1 byte/token; file 4 byte/token dung --memh")
                mem[addr] = int(tok, 16); addr += 1
    return mem


def read_memh_words(path):
    """$readmemh 32 bit: {chi_so_word: gia_tri}."""
    words, idx = {}, 0
    for line in open(path):
        for tok in line.split("//")[0].split():
            if tok.startswith("@"):
                idx = int(tok[1:], 16)
            else:
                words[idx] = int(tok.replace("_", ""), 16) & 0xFFFFFFFF; idx += 1
    return words


def load_memh(path, base=0):
    mem = {}
    for idx, w in read_memh_words(path).items():
        _mem_put_bytes(mem, base + 4 * idx, w.to_bytes(4, "little"))
    return mem


def words_in(mem, base, limit):
    """Lay cac word (little-endian) trong [base, limit] -> {chi_so_word: gia_tri}."""
    out = {}
    for a in mem:
        if base <= a <= limit:
            out.setdefault((a - base) // 4, None)
    for i in list(out):
        b = bytes(mem.get(base + 4 * i + k, 0) for k in range(4))
        out[i] = int.from_bytes(b, "little")
    return out


# =========================================================== ky
class Cfg:
    def __init__(self, a):
        self.key = bytes.fromhex(a.key)
        if len(self.key) != 16:
            raise SystemExit("--key phai 16 byte (32 ky tu hex)")
        self.pid, self.iid = a.program_id, a.image_id
        self.code_base, self.code_limit = a.code_base, a.code_limit
        self.tag_base, self.g, self.t = a.tag_base, a.g, a.t
        self.nonce = self.pid.to_bytes(8, "big") + self.iid.to_bytes(8, "big")
        self.nblk_max = (self.code_limit - self.code_base + 1) // (4 * self.g)

    def block_ad(self, blk, words):
        addr = self.code_base + blk * 4 * self.g
        return addr.to_bytes(4, "big") + b"".join(w.to_bytes(4, "big") for w in words)

    def block_tag_words(self, blk, words):
        tag = int.from_bytes(ascon128a_mac(self.key, self.nonce, self.block_ad(blk, words)), "big")
        top = tag >> (128 - self.t)
        return [(top >> (self.t - 32 * (j + 1))) & 0xFFFFFFFF for j in range(self.t // 32)]


def write_memh(path, words, header):
    with open(path, "w") as f:
        f.write(f"// {header}\n")
        for w in words:
            f.write(f"{w:08x}\n")


def cmd_sign(a):
    selftest()
    c = Cfg(a)
    if a.elf:    mem = load_elf(a.elf)
    elif a.bin:  mem = load_bin(a.bin, a.bin_base)
    elif a.vhex: mem = load_vhex(a.vhex)
    else:        mem = load_memh(a.memh, a.code_base)

    code_w = words_in(mem, c.code_base, c.code_limit)
    if not code_w:
        raise SystemExit("khong co byte nao trong vung CODE: kiem tra --code-base/--code-limit va linker script")
    outside = [x for x in mem if not (c.code_base <= x <= c.code_limit)
               and not (a.data_base <= x < a.data_base + a.data_size)]
    if outside:
        print(f"CANH BAO: {len(outside)} byte nam ngoai CODE va DATA (vd. 0x{min(outside):08x}), bo qua")

    nblk = c.nblk_max if a.full else (max(code_w) // c.g + 1)
    if nblk > c.nblk_max:
        raise SystemExit("firmware vuot qua CODE_LIMIT")
    code, tags = [], []
    for b in range(nblk):
        words = [code_w.get(b * c.g + j, 0) for j in range(c.g)]
        code += words
        tags += c.block_tag_words(b, words)

    hdr = (f"G={c.g} T={c.t} PROGRAM_ID={c.pid} IMAGE_ID={c.iid} "
           f"CODE_BASE=0x{c.code_base:08x} TAG_BASE=0x{c.tag_base:08x}")
    write_memh(a.out_code, code, "code " + hdr)
    write_memh(a.out_tag, tags, "tag " + hdr)
    msg = (f"{nblk} block, {len(code)} word code ({4 * len(code)} B), {len(tags)} word tag "
           f"({4 * len(tags)} B, metadata {100.0 * len(tags) / len(code):.1f}%)")
    if a.tag_rom_words and len(tags) > a.tag_rom_words:
        msg += f"\nCANH BAO: tag can {len(tags)} word > tag_rom {a.tag_rom_words} word"

    if a.out_data:
        data_w = words_in(mem, a.data_base, a.data_base + a.data_size - 1)
        n = (max(data_w) + 1) if data_w else 0
        write_memh(a.out_data, [data_w.get(i, 0) for i in range(n)],
                   f"data DATA_BASE=0x{a.data_base:08x}")
        msg += f"\ndata: {n} word -> {a.out_data}"
    print(msg)


def _load_signed(a):
    c = Cfg(a)
    code_w = read_memh_words(a.code)
    tag_w = read_memh_words(a.tag)
    nblk = (max(code_w) // c.g + 1) if code_w else 0
    return c, code_w, tag_w, nblk


def cmd_check(a):
    selftest()
    c, code_w, tag_w, nblk = _load_signed(a)
    tw, bad = c.t // 32, 0
    for b in range(nblk):
        words = [code_w.get(b * c.g + j, 0) for j in range(c.g)]
        exp = c.block_tag_words(b, words)
        got = [tag_w.get(b * tw + j) for j in range(tw)]
        if got != exp:
            bad += 1
            addr = c.code_base + b * 4 * c.g
            print(f"SAI block {b} (0x{addr:08x}): tag_rom {''.join(f'{x:08x}' if x is not None else '????????' for x in got)}"
                  f" | tinh lai {''.join(f'{x:08x}' for x in exp)}")
    print(f"check: {nblk} block, {bad} block sai")
    sys.exit(1 if bad else 0)


def cmd_trace(a):
    selftest()
    c, code_w, tag_w, _ = _load_signed(a)
    addr = a.addr
    blk = (addr - c.code_base) // (4 * c.g)
    blk_base = c.code_base + blk * 4 * c.g
    words = [code_w.get(blk * c.g + j, 0) for j in range(c.g)]
    ad = c.block_ad(blk, words)
    full = ascon128a_mac(c.key, c.nonce, ad).hex()
    tw = c.t // 32
    print(f"addr        = 0x{addr:08x}  -> block {blk}, blk_base 0x{blk_base:08x}, "
          f"word_off {(addr - blk_base) // 4}")
    print(f"code words  = {' '.join(f'{w:08x}' for w in words)}")
    print(f"a_nonce     = {c.nonce.hex()}")
    nbeats = (len(ad) + 15) // 16
    for i in range(nbeats):
        chunk = ad[16 * i:16 * i + 16]
        print(f"beat {i}: a_ad_data = {(chunk + bytes(16 - len(chunk))).hex()}  "
              f"a_ad_nbytes = {len(chunk)}  a_ad_last = {int(i == nbeats - 1)}")
    print(f"a_tag (mong doi)      = {full}")
    print(f"tag so sanh (T={c.t}) = {full[:c.t // 4]}")
    print(f"tag_addr    = 0x{c.tag_base + blk * (c.t // 8):08x}  (tag_rom[{blk * tw}..{blk * tw + tw - 1}])")
    got = [tag_w.get(blk * tw + j) for j in range(tw)]
    got_s = "".join(f"{x:08x}" if x is not None else "????????" for x in got)
    print(f"tag_rom     = {got_s}  -> {'KHOP' if got_s == full[:c.t // 4] else 'KHONG KHOP'}")


# =========================================================== CLI
def _int(x):
    return int(x, 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--key", default="000102030405060708090A0B0C0D0E0F", help="K_code, 32 ky tu hex")
        p.add_argument("--program-id", type=_int, default=1)
        p.add_argument("--image-id", type=_int, default=1)
        p.add_argument("--code-base", type=_int, default=0x00000000)
        p.add_argument("--code-limit", type=_int, default=0x00001FFF)
        p.add_argument("--tag-base", type=_int, default=0x00010000)
        p.add_argument("--g", type=int, default=4, choices=[1, 2, 4, 8], help="so lenh moi block")
        p.add_argument("--t", type=int, default=128, choices=[32, 64, 128], help="so bit tag")

    s = sub.add_parser("sign", help="firmware -> code/tag/data hex")
    src = s.add_mutually_exclusive_group(required=True)
    src.add_argument("--elf"); src.add_argument("--bin"); src.add_argument("--memh"); src.add_argument("--vhex")
    s.add_argument("--bin-base", type=_int, default=0)
    s.add_argument("--out-code", required=True)
    s.add_argument("--out-tag", required=True)
    s.add_argument("--out-data")
    s.add_argument("--data-base", type=_int, default=0x00020000)
    s.add_argument("--data-size", type=_int, default=0x1000)
    s.add_argument("--full", action="store_true", help="ky toan bo vung CODE (dem 0 den CODE_LIMIT)")
    s.add_argument("--tag-rom-words", type=int, default=2048, help="kich thuoc tag_rom de canh bao")
    common(s)

    for name in ("check", "trace"):
        p = sub.add_parser(name)
        p.add_argument("--code", required=True)
        p.add_argument("--tag", required=True)
        if name == "trace":
            p.add_argument("--addr", type=_int, required=True)
        common(p)

    sub.add_parser("selftest")
    a = ap.parse_args()
    {"sign": cmd_sign, "check": cmd_check, "trace": cmd_trace,
     "selftest": lambda _: selftest(True)}[a.cmd](a)


if __name__ == "__main__":
    main()
