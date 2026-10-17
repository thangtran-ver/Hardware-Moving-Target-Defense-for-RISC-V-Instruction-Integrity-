#!/usr/bin/env python3
"""Independent Ascon-128a (v1.2) reference model, written from the spec.

Bitsliced S-box (boolean formulas, not a lookup table) so it is independent
of the table used in the RTL. Validated against the official
LWC_AEAD_KAT_128_128.txt from ascon/ascon-c tag v1.2.8 (ascon128av12).
"""
M = (1 << 64) - 1
IV_128A = 0x80800C0800000000


def rotr(x, n):
    return ((x >> n) | (x << (64 - n))) & M


def rnd(S, c):
    x0, x1, x2, x3, x4 = S
    x2 ^= c                                   # p_C
    x0 ^= x4; x4 ^= x3; x2 ^= x1              # p_S (bitsliced)
    t0 = (~x0 & M) & x1; t1 = (~x1 & M) & x2; t2 = (~x2 & M) & x3
    t3 = (~x3 & M) & x4; t4 = (~x4 & M) & x0
    x0 ^= t1; x1 ^= t2; x2 ^= t3; x3 ^= t4; x4 ^= t0
    x1 ^= x0; x0 ^= x4; x3 ^= x2; x2 = ~x2 & M
    x0 ^= rotr(x0, 19) ^ rotr(x0, 28)         # p_L
    x1 ^= rotr(x1, 61) ^ rotr(x1, 39)
    x2 ^= rotr(x2, 1) ^ rotr(x2, 6)
    x3 ^= rotr(x3, 10) ^ rotr(x3, 17)
    x4 ^= rotr(x4, 7) ^ rotr(x4, 41)
    return [x0, x1, x2, x3, x4]


def perm(S, rounds):
    for i in range(12 - rounds, 12):
        S = rnd(S, ((0xF - i) << 4) | i)
    return S


def sbox5(v):
    """5-bit S-box via the bitsliced formula (x0 = MSB)."""
    S = [(v >> (4 - k)) & 1 for k in range(5)]
    x0, x1, x2, x3, x4 = S
    x0 ^= x4; x4 ^= x3; x2 ^= x1
    t0 = (x0 ^ 1) & x1; t1 = (x1 ^ 1) & x2; t2 = (x2 ^ 1) & x3
    t3 = (x3 ^ 1) & x4; t4 = (x4 ^ 1) & x0
    x0 ^= t1; x1 ^= t2; x2 ^= t3; x3 ^= t4; x4 ^= t0
    x1 ^= x0; x0 ^= x4; x3 ^= x2; x2 ^= 1
    return (x0 << 4) | (x1 << 3) | (x2 << 2) | (x3 << 1) | x4


def b2i(b):
    return int.from_bytes(b, "big")


def i2b(x, n=8):
    return x.to_bytes(n, "big")


def encrypt_128a(key, nonce, ad, pt, trace=None):
    assert len(key) == 16 and len(nonce) == 16
    K0, K1 = b2i(key[:8]), b2i(key[8:])
    S = [IV_128A, K0, K1, b2i(nonce[:8]), b2i(nonce[8:])]
    if trace is not None: trace.append(("init", list(S)))
    S = perm(S, 12)
    S[3] ^= K0; S[4] ^= K1
    if trace is not None: trace.append(("post_init", list(S)))
    if len(ad):
        a = ad + b"\x80" + b"\x00" * (15 - len(ad) % 16)
        for i in range(0, len(a), 16):
            S[0] ^= b2i(a[i:i + 8]); S[1] ^= b2i(a[i + 8:i + 16])
            S = perm(S, 8)
            if trace is not None: trace.append(("ad_blk", list(S)))
    S[4] ^= 1
    p = pt + b"\x80" + b"\x00" * (15 - len(pt) % 16)
    ct = b""
    for i in range(0, len(p) - 16, 16):
        S[0] ^= b2i(p[i:i + 8]); S[1] ^= b2i(p[i + 8:i + 16])
        ct += i2b(S[0]) + i2b(S[1])
        S = perm(S, 8)
    i = len(p) - 16
    S[0] ^= b2i(p[i:i + 8]); S[1] ^= b2i(p[i + 8:i + 16])
    ct += (i2b(S[0]) + i2b(S[1]))[:len(pt) % 16]
    S[2] ^= K0; S[3] ^= K1
    if trace is not None: trace.append(("final_pre", list(S)))
    S = perm(S, 12)
    if trace is not None: trace.append(("final_perm", list(S)))
    tag = i2b(S[3] ^ K0) + i2b(S[4] ^ K1)
    return ct + tag


def mac_tag(key, nonce, ad):
    """Tag-only mode implemented by the RTL: Ascon-128a with empty plaintext."""
    return encrypt_128a(key, nonce, ad, b"")


def parse_kat(path):
    vecs, cur = [], {}
    for line in open(path):
        line = line.strip()
        if not line:
            if cur: vecs.append(cur); cur = {}
            continue
        k, _, v = line.partition("=")
        cur[k.strip()] = v.strip()
    if cur: vecs.append(cur)
    return vecs


if __name__ == "__main__":
    import sys
    kat = parse_kat(sys.argv[1] if len(sys.argv) > 1 else "LWC_AEAD_KAT_128_128.txt")
    bad = 0
    for v in kat:
        out = encrypt_128a(bytes.fromhex(v["Key"]), bytes.fromhex(v["Nonce"]),
                           bytes.fromhex(v["AD"]), bytes.fromhex(v["PT"]))
        if out.hex().upper() != v["CT"].upper():
            bad += 1
            print("MISMATCH Count", v["Count"])
    print(f"official KAT: {len(kat)} vectors, {bad} mismatches")
    assert [sbox5(i) for i in range(32)] == [
        0x04, 0x0b, 0x1f, 0x14, 0x1a, 0x15, 0x09, 0x02, 0x1b, 0x05, 0x08, 0x12,
        0x1d, 0x03, 0x06, 0x1c, 0x1e, 0x13, 0x07, 0x0e, 0x00, 0x0d, 0x11, 0x18,
        0x10, 0x0c, 0x01, 0x19, 0x16, 0x0a, 0x0f, 0x17]
    print("sbox formula == spec table: OK")
