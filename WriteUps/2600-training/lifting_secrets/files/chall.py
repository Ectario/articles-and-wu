from sage.all import *
from Crypto.Util.number import bytes_to_long, inverse
from flag import FLAG
from random import randrange

p = 2^222 - 117 # strong prime from https://safecurves.cr.yp.to/
F = FiniteField(p)
E = EllipticCurve(F, [0, 1, 0, 1, 3]) 

assert E.order().is_prime()

texts = bytearray(FLAG)
mask = 0x1fffffffffffff
r = randrange(1, p)
for i, x in enumerate(texts):
    lifted = False
    added = 0
    while not lifted:
        try:
            P = E.lift_x(F(x))
            Q = r*P
            print(f"{added}: {int(Q.xy()[0])^mask}")
            lifted = True
        except:
            x+=1
            added+=1