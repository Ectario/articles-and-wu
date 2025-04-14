from Crypto.Util.number import *
from flag import FLAG

FLAG = bytes_to_long(FLAG)

p = 2^222 - 117 # strong prime from https://safecurves.cr.yp.to/
F1 = FiniteField(p)
E1 = EllipticCurve(F1, [0, 1, 0, 1, 3]) 

q  = 2^221 - 3 # strong prime from https://safecurves.cr.yp.to/
F2 = FiniteField(q)
E2 = EllipticCurve(F2, [0, 1, 0, 1, 3]) 

r = 2^224 - 2^96 + 1 # strong prime from https://safecurves.cr.yp.to/
F3 = FiniteField(r)
E3 = EllipticCurve(F3, [0, 1, 0, 1, 3]) 

P = E1.random_point()
Q = E2.random_point()
R = E3.random_point()

s = (int(P[0]) * int(Q[0]) * int(R[0]))

print(f"{F1(s)=}")
print(f"{F2(s)=}")
print(f"{F3(s)=}")

s += int(R[0])

assert s > FLAG

print(f"s XOR flag={s ^^ FLAG}")
print(f"{R[1]=}")