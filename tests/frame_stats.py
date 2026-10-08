"""Independent averaged-FPS checks, stalls, zero deltas and buffer bounds."""
import ctypes as C
import random
import sys
lib=C.CDLL(sys.argv[1]);state=(C.c_uint64*5)();checks=0
init=lib.frame_stats_init;init.argtypes=[C.c_void_p];init.restype=C.c_int64
step=lib.frame_stats_step;step.argtypes=[C.c_void_p,C.c_uint64];step.restype=C.c_int64

def check(ok):
 global checks
 checks+=1;assert ok
state[3]=state[4]=0xaaaaaaaaaaaaaaaa
check(init(state)==0 and list(state[:3])==[0,0,0])
model=[0,0,0];rng=random.Random(77007)
for dt in [0]*20+[16]*100+[5000,0,0,1000,0xffffffff]+[rng.randrange(100) for _ in range(3000)]:
 model[0]+=dt;model[1]+=1
 if model[0]>=1000:
  model[2]=model[1]*1000//model[0];model[0]=model[1]=0
 check(step(state,dt)==0 and list(state[:3])==model)
 check(list(state[3:])==[0xaaaaaaaaaaaaaaaa]*2)
before=bytes(state)
check(step(state,0x100000000)==-1 and bytes(state)==before)
state[1]=0xffffffff;before=bytes(state)
check(step(state,0)==-1 and bytes(state)==before)
print(f'PASS: {checks} frame-rate sampling/zero-delta/stall/canary assertions')
