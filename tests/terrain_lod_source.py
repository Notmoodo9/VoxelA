"""Explicit signed surface provider: topology provenance and failure propagation."""
import ctypes as C,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64
build=lib.terrain_lod_build_source;build.argtypes=[P,P];build.restype=I
Callback=getattr(C,'WINFUNCTYPE',C.CFUNCTYPE)(I,P,I,I,P)
state={'mode':'valid','calls':0,'target':None}
@Callback
def sampler(ctx,x,z,out):
 state['calls']+=1
 if state['target']==(x,z):return -1
 if state['mode']=='fail' and state['calls']>=7:return -1
 y=(x%16)+(z%16)-240
 if state['mode']=='height':y=-256
 block=5 if state['mode']!='block' else 99
 C.c_int32.from_address(out).value=y
 C.c_uint32.from_address(out+4).value=block
 return 0
source=(U*2)(0,C.cast(sampler,P).value)
buf=C.create_string_buffer(b'Z'*(65536*32+32),65536*32+32)
scratch=C.create_string_buffer(b'Z'*(360480+32),360480+32)
cfg=(U*8)(0,C.addressof(buf),65536,8,8,128,99,0)
assert build(cfg,source)==0 and 0<cfg[6]<65536
expected=buf.raw[:cfg[6]*32];count=cfg[6];calls=state['calls']
for x,y,z,*_ in struct.iter_unpack('<8f',expected):
 gx=int(x);gz=int(z) # center8 makes vertices equal global coordinates
 # Seam bottoms have constant block-top profiles; top vertices match sampler.
 assert -240<=y<=-210 and x==gx and z==gz
 if abs(x-8)!=40 and abs(z-8)!=40:assert y==(gx%16)+(gz%16)-240
 assert all(abs(a-b)<1e-6 for a,b in zip(_[:3],(.47,.32,.19)))
assert buf.raw[count*32:]==b'Z'*(len(buf)-count*32)
cfg[7]=C.addressof(scratch);state['calls']=0
assert build(cfg,source)==0 and cfg[6]==count and buf.raw[:count*32]==expected
assert state['calls']<calls and scratch.raw[360480:]==b'Z'*32
# Error at later samples must propagate through corner/fan/seam paths.
for mode in ('fail','height','block'):
 state.update(mode=mode,calls=0);cfg[6]=123
 assert build(cfg,source)==-1 and cfg[6]==123
state.update(mode='valid',calls=0)
# Fail specifically at a stitched intermediate point and an inside-block seam.
for target in ((48,-31),(47,-32)):
 state.update(target=target,calls=0);cfg[6]=123
 assert build(cfg,source)==-1 and cfg[6]==123, target
state['target']=None
for invalid in (None,(U*2)(0,0)):
 cfg[6]=123;assert build(cfg,invalid)==-1 and cfg[6]==123
print(f'PASS: {count} signed-height progressive source vertices, unchanged legacy topology, memoization, callback errors/invalid samples and ABI callback mapping')
