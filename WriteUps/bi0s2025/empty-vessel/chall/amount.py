from sage.all import *

F = Zmod(2**256)
# length * amount = 1 % 2**256
# <=> if length = 3 then amount = inverse(3) mod 2**256
amount = F(3)**-1
length = 3
print(amount)
print(F(length) * F(amount) == 1)