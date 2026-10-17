#!/usr/bin/env python3
"""sign_code.py -- offline signer cho baseline static integrity.

Doc file code dang $readmemh (moi dong 1 word 32 bit, '@' = chi so word,
giong cach nap vao code_rom cua system_memory), tinh tag Ascon-128a v1.2
cho tung block G word va xuat:
  * code hex da dem 0 cho du block  (nap vao code_rom)
  * tag  hex                         (nap vao tag_rom)

Message (khop bit voi authenticated_memory_wrapper.v):
  nonce = PROGRAM_ID(8B) || IMAGE_ID(8B)          (big-endian)
  AD    = block_addr(4B) || word0(4B) || ... || word(G-1)(4B)   (big-endian)
  tag   = 128 bit; luu T bit dau, moi word 32 bit MSB truoc

Vi du:
  python sign_code.py fw.hex --out-code code.hex --out-tag tag.hex \
      --key 000102030405060708090A0B0C0D0E0F --program-id 1 --image-id 1
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ascon_ref import mac_tag  # noqa: E402  (model doc lap, khop 1089/1089 KAT)


def read_memh(path):
    """Doc file $readmemh -> dict {chi_so_word: gia_tri}."""
    mem, idx = {}, 0
    for line in open(path):
        line = line.split("//")[0]
        for tok in line.split():
            if tok.startswith("@"):
                idx = int(tok[1:], 16)
            else:
                mem[idx] = int(tok.replace("_", ""), 16) & 0xFFFFFFFF
                idx += 1
    return mem


def block_tag(key, nonce, addr, words):
    ad = addr.to_bytes(4, "big") + b"".join(w.to_bytes(4, "big") for w in words)
    return int.from_bytes(mac_tag(key, nonce, ad), "big")


def sign(mem, key, program_id, image_id, code_base, g, t):
    nonce = program_id.to_bytes(8, "big") + image_id.to_bytes(8, "big")
    nblk = max(mem) // g + 1 if mem else 0
    code, tags = [], []
    for b in range(nblk):
        words = [mem.get(b * g + j, 0) for j in range(g)]
        addr = code_base + b * 4 * g
        tag = block_tag(key, nonce, addr, words)
        code += words
        top = tag >> (128 - t)
        tags += [(top >> (t - 32 * (j + 1))) & 0xFFFFFFFF for j in range(t // 32)]
    return code, tags


def write_memh(path, words):
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("code_hex")
    ap.add_argument("--out-code", required=True)
    ap.add_argument("--out-tag", required=True)
    ap.add_argument("--key", default="000102030405060708090A0B0C0D0E0F")
    ap.add_argument("--program-id", type=lambda x: int(x, 0), default=1)
    ap.add_argument("--image-id", type=lambda x: int(x, 0), default=1)
    ap.add_argument("--code-base", type=lambda x: int(x, 0), default=0)
    ap.add_argument("--g", type=int, default=4, choices=[1, 2, 4, 8])
    ap.add_argument("--t", type=int, default=128, choices=[32, 64, 128])
    a = ap.parse_args()

    mem = read_memh(a.code_hex)
    code, tags = sign(mem, bytes.fromhex(a.key), a.program_id, a.image_id,
                      a.code_base, a.g, a.t)
    write_memh(a.out_code, code)
    write_memh(a.out_tag, tags)
    print(f"{len(code) // a.g} block (G={a.g}, T={a.t}): "
          f"{len(code)} word code, {len(tags)} word tag "
          f"(metadata {100 * len(tags) / max(len(code), 1):.1f}%)")


if __name__ == "__main__":
    main()
