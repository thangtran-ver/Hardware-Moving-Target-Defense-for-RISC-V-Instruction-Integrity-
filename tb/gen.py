import sys; sys.path.insert(0,'.')  # ascon_v12.py = pyascon commit 055d3bb (Ascon v1.2)
import ascon_v12 as A
key=bytes(range(16)); nonce=bytes(range(16,32))
with open('vec.txt','w') as f:
  for L in [0,1,5,15,16,17,20,32,40]:
    ad=bytes((0xA0+i)&0xff for i in range(L))
    ct=A.ascon_encrypt(key,nonce,ad,b"","Ascon-128a")
    tag=ct.hex()
    adp=ad+bytes(48-L)
    f.write(f"{L:02x} {adp.hex()} {tag}\n")
print(open('vec.txt').read())
