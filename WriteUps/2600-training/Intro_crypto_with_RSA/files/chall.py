from Crypto.Util.number import *
from flag import FLAG

FLAG = bytes_to_long(FLAG)
e = 11
nbits = 2048
p = getPrime(nbits)
q = getPrime(nbits)
n = p*q

ct = pow(FLAG, e, n)

print(f"{ct=}")