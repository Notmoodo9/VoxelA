"""Independent signed region addressing and bounded deterministic path generation."""
import ctypes as C
import random
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64
address=lib.world_address;address.argtypes=[P,P];address.restype=I
path=lib.world_path;path.argtypes=[P,P,P];path.restype=I
coords=(I*3)();out=(I*4)();rng=random.Random(554)
for point in [(-30000000,-256,29999999),(-1,-1,-1),(0,0,0),(63,767,64)]+[tuple([rng.randrange(-30000000,30000000),rng.randrange(-256,768),rng.randrange(-30000000,30000000)]) for _ in range(1000)]:
 coords[:]=point;assert address(coords,out)==0
 x,y,z=point;assert list(out)==[x//64,z//64,y//16,((z//16)%4)*4+(x//16)%4]
for point in [(-30000001,0,0),(30000000,0,0),(0,-257,0),(0,768,0),(0,0,30000000)]:
 coords[:]=point;out[:]=[123]*4;assert address(coords,out)==-1 and list(out)==[123]*4
store=C.create_string_buffer(1024);buf=C.create_string_buffer(b'\xa5'*992,992);key=(I*3)()
for root in [b'/tmp/world',b'/tmp/world/',b'C:\\world\\', '/tmp/世界'.encode(),b'a'*880]:
 C.c_uint64.from_buffer(store,40).value=len(root);C.memmove(C.addressof(store)+48,root+b'\0',len(root)+1)
 for values in [(-468750,468749,-16),(0,0,0),(468749,-468750,47)]:
  key[:]=values;buf.raw=b'\xa5'*992;n=path(store,key,buf)
  expected=root+(b'' if root.endswith((b'/',b'\\')) else b'/')+('r_%d_%d_%d.vxr'%values).encode()
  assert n==len(expected) and buf.raw[:n+1]==expected+b'\0' and buf.raw[n+1:]==b'\xa5'*(991-n)
for values in [(-468751,0,0),(468750,0,0),(0,0,48)]:
 key[:]=values;before=buf.raw;assert path(store,key,buf)==-1 and buf.raw==before
print('PASS: 1004 signed global addresses, negative floors, vertical/world bounds, Unicode/Windows/max-length paths and canaries')
