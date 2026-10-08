"""Playable break-anything/suitability policy; legacy rules remain frozen."""
import ctypes as C
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64
init=lib.inventory36_init;init.argtypes=[P];init.restype=I
valid=lib.inventory36_valid;valid.argtypes=[P];valid.restype=I
duration=lib.survival_mine_duration;duration.argtypes=[P,U];duration.restype=I
drop=lib.survival_mine_drop;drop.argtypes=[P,U];drop.restype=I
inv=(C.c_uint16*152)();checks=0
for selected in range(9):
 for item,wear in [(0,0),(1,0),(2,0),(5,0),(8,0),(9,0),(10,1),(10,60),(11,1),(11,132)]:
  assert init(inv)==0
  inv[selected*4:selected*4+4]=(item,int(item!=0),wear,0)
  inv[144]=selected
  assert valid(inv)==0
  before=bytes(inv)
  for block in range(1,7):
   want_time=({10:800,11:400}.get(item,6000) if block==1 else {2:350,3:350,4:300,5:1200,6:150}[block])
   want_drop=0 if block==1 and item not in (10,11) else 2 if block==3 else block
   assert duration(inv,block)==want_time and drop(inv,block)==want_drop,(selected,item,block)
   assert bytes(inv)==before,'query mutated inventory';checks+=1
  for block in (0,7,8,2**64-1):assert duration(inv,block)==-1 and drop(inv,block)==-1
  inv[146]=1
  for block in range(1,7):assert duration(inv,block)==1 and drop(inv,block)==0
assert init(inv)==0
inv[144]=9
assert duration(inv,1)==-1 and drop(inv,1)==-1
print(f'PASS: {checks} mining duration/drop cases, every hotbar slot, suitability, last-use picks, Creative and invalid-state rejection')
