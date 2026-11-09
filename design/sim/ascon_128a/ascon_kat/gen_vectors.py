#!/usr/bin/env python3
"""Doc file KAT LWC cua Ascon-128a, loc cac vector co PT rong (loi RTL chi xac thuc AD)
va ghi ra kat_vectors.txt cho testbench.
Moi dong: KEY(32 hex) NONCE(32 hex) ADLEN(dec) AD(64 hex, can trai, pad 0) TAG(32 hex)
Voi PT rong thi CT cua KAT chinh la tag 16 byte."""
import sys, os
here = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "LWC_AEAD_KAT_128_128_ascon128a.txt")
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "kat_vectors.txt")
recs, cur = [], {}
for line in open(src):
    line = line.strip()
    if not line:
        if cur: recs.append(cur); cur = {}
        continue
    k, v = line.split("=", 1); cur[k.strip()] = v.strip()
if cur: recs.append(cur)
n = 0
with open(dst, "w") as f:
    for r in recs:
        if r["PT"] != "":
            continue
        ad = r["AD"]; adlen = len(ad) // 2
        assert adlen <= 32 and len(r["CT"]) == 32
        f.write(f'{r["Key"]} {r["Nonce"]} {adlen} {ad.ljust(64, "0")} {r["CT"]}\n')
        n += 1
print(f"{n} vector (PT rong) -> {dst}")
