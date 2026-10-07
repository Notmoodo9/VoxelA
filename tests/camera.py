"""Movement invariants for the shared assembly spectator camera."""
import ctypes as C
import math
import sys
lib=C.CDLL(sys.argv[1])
State=C.c_float*8
init=lib.camera_init;init.argtypes=[C.POINTER(C.c_float)];init.restype=C.c_int64
resize=lib.camera_resize;resize.argtypes=[C.POINTER(C.c_float),C.c_uint64,C.c_uint64];resize.restype=C.c_int64
step=lib.camera_step;step.argtypes=[C.POINTER(C.c_float),C.c_uint64,C.c_uint64];step.restype=C.c_int64
checks=0
def check(condition,why):
 global checks
 checks+=1
 assert condition,why
def state():
 s=State();check(init(s)==0,'init');return s
s=state();check(tuple(s[:3])==(0,0,0),'initial pan');check(s[4]==22,'initial zoom')
check(resize(s,1920,1080)==0,'resize');check(abs(s[5]-16/9)<1e-6,'aspect')
for w,h in [(0,600),(800,0),(16385,600),(800,16385),(2**64-1,1)]:
 before=bytes(s);check(resize(s,w,h)==-1,'invalid dimensions');check(bytes(s)==before,'resize failure atomicity')
for mask in [0,1,2,4,8,16,32,1|8,1|8|16,1024|1]:
 s=state();check(step(s,mask,100)==0,'movement update')
 distance=math.sqrt(sum(v*v for v in s[:3]))
 expected=0 if mask==0 else 2.4 if mask&1024 else 1.0
 check(abs(distance-expected)<1e-5,('normalized speed',mask,distance))
s=state();check(step(s,1|2|4|8|16|32|64|128|256|512,100)==0,'opposites')
check(tuple(s[:3])==(0,0,0) and s[4]==22,'opposite actions cancel')
a,b=state(),state();step(a,1,100);step(b,1,2**64-1);check(bytes(a)==bytes(b),'elapsed clamped')
a,b=state(),state();step(a,1,100)
for _ in range(10):step(b,1,10)
check(all(abs(a[i]-b[i])<1e-5 for i in range(8)),'frame-time independence tolerance')
s=state()
for _ in range(1000):
 step(s,128,100)
 check(-math.pi-1e-6<=s[3]<=math.pi+1e-6,'bounded yaw')
 check(abs(s[6]**2+s[7]**2-1)<1e-6,'unit rotation')
for mask,expected in [(256,8),(512,80)]:
 s=state()
 for _ in range(1000):step(s,mask,100)
 check(s[4]==expected,'zoom clamp')
s=state();resize(s,1600,600);step(s,1|64|256,100);check(step(s,2048,100)==0,'reset')
check(tuple(s[:3])==(0,0,0) and s[4]==22,'reset position/zoom')
check(abs(s[5]-1600/600)<1e-6,'reset preserves aspect')
before=bytes(s);check(step(s,4096,100)==-1,'unknown mask');check(bytes(s)==before,'input failure atomicity')
print(f'PASS: {checks} camera movement assertions')
