#!/usr/bin/env python3
"""Generate all vector files for tb_unit.v and tb_ascon_mac_top.v.
Run from the project verify/ directory:   python gen_vectors.py
Golden model: ascon_ref.py (independent, checked here against the official
LWC_AEAD_KAT_128_128.txt of ascon/ascon-c tag v1.2.8, crypto_aead/ascon128av12).
"""
import os, random
import ascon_ref as R

HERE = os.path.dirname(os.path.abspath(__file__))
P = lambda *a: os.path.join(HERE, *a)
MAXB = 256

# ---- 0) golden model sanity: full official KAT (1089 vectors, PT and AD 0..32 B)
kat = R.parse_kat(P('LWC_AEAD_KAT_128_128.txt'))
bad = sum(R.encrypt_128a(bytes.fromhex(v['Key']), bytes.fromhex(v['Nonce']),
                         bytes.fromhex(v['AD']), bytes.fromhex(v['PT'])).hex().upper() != v['CT']
          for v in kat)
assert bad == 0, f'golden model mismatches official KAT ({bad})'
print(f'golden model vs official KAT: {len(kat)} vectors, 0 mismatches')

# ---- 1) unit vectors
random.seed(2026)
M = R.M
with open(P('sbox_vec.txt'), 'w') as f:          # 32 offsets: every bit lane sees all 32 inputs
    for off in range(32):
        xs = [0] * 5; ys = [0] * 5
        for i in range(64):
            v = (i + off) % 32; o = R.sbox5(v)
            for k in range(5):
                xs[k] |= ((v >> (4 - k)) & 1) << i
                ys[k] |= ((o >> (4 - k)) & 1) << i
        f.write(' '.join(f'{w:016x}' for w in xs + ys) + '\n')

def lin(S):
    x0, x1, x2, x3, x4 = S; r = R.rotr
    return [x0 ^ r(x0, 19) ^ r(x0, 28), x1 ^ r(x1, 61) ^ r(x1, 39), x2 ^ r(x2, 1) ^ r(x2, 6),
            x3 ^ r(x3, 10) ^ r(x3, 17), x4 ^ r(x4, 7) ^ r(x4, 41)]

def states(n):
    for s in ([0] * 5, [M] * 5, [1 << 63] * 5, [1] * 5):
        yield s
    for _ in range(n):
        yield [random.getrandbits(64) for _ in range(5)]

with open(P('lin_vec.txt'), 'w') as f:
    for S in states(500):
        f.write(' '.join(f'{w:016x}' for w in S + lin(S)) + '\n')
with open(P('round_vec.txt'), 'w') as f:
    for S in states(500):
        i = random.randrange(12); c = ((0xF - i) << 4) | i
        f.write(' '.join(f'{w:016x}' for w in S) + f' {c:02x} ' +
                ' '.join(f'{w:016x}' for w in R.rnd(S, c)) + '\n')
for nr in (8, 12):
    with open(P(f'p{nr}_vec.txt'), 'w') as f:
        for S in states(1000):
            f.write(' '.join(f'{w:016x}' for w in S + R.perm(S, nr)) + '\n')

# ---- 2) top-level vectors: L key nonce term0 ad(MSB-aligned, 256 B) tag
random.seed(20261006)
rows = []
def add(key, nonce, ad, tag, term0=0):
    rows.append((len(ad), key, nonce, term0, ad, tag))

for v in kat:                                       # official KAT, PT empty (AD 0..32 B)
    if v['PT'] == '':
        add(bytes.fromhex(v['Key']), bytes.fromhex(v['Nonce']), bytes.fromhex(v['AD']),
            bytes.fromhex(v['CT']))
n_kat = len(rows)
for line in open(P('..', 'tb', 'vec.txt')):          # user's tb/vec.txt
    L, adp, tag = line.split(); L = int(L, 16)
    add(bytes(range(16)), bytes(range(16, 32)), bytes.fromhex(adp)[:L], bytes.fromhex(tag))
n_user = len(rows) - n_kat
edges = [0, 1, 2, 7, 8, 9, 14, 15, 16, 17, 18, 31, 32, 33, 47, 48, 49, 63, 64, 65,
         127, 128, 129, 255, 256]
for i in range(3000):                               # random, edge-weighted lengths
    L = random.choice(edges) if i % 2 == 0 else random.randint(0, MAXB)
    k, n, ad = random.randbytes(16), random.randbytes(16), random.randbytes(L)
    term0 = 1 if (L > 0 and L % 16 == 0 and random.random() < 0.5) else 0
    add(k, n, ad, R.mac_tag(k, n, ad), term0)
assert n_kat == 33 and n_user == 9                  # tb_ascon_mac_top.v: NCLEAN = 42
with open(P('top_vec.txt'), 'w') as f:
    for L, k, n, t0, ad, tag in rows:
        f.write(f'{L:03x} {k.hex()} {n.hex()} {t0:x} {(ad + bytes(MAXB - L)).hex()} {tag.hex()}\n')
print(f'top_vec.txt: {len(rows)} vectors ({n_kat} official KAT, {n_user} tb/vec.txt, '
      f'{len(rows) - n_kat - n_user} random)')
