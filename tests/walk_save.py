"""Independent player/world save bytes, metadata checksums, atomic rejection."""
import ctypes as C
import math
import struct
import sys
import random
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);get=bind('stream_get',[P,P]);edit=bind('stream_edit',[P,P,U]);height=bind('terrain_height',[U,I,I])
pinit=bind('player_init',[P,P]);encode=bind('walk_encode',[P,P,P,U]);decode=bind('walk_decode',[P,U,P,P])
world=(U*12)();entries=(C.c_ubyte*25600)();blocks=(C.c_ubyte*3276800)();edits=(I*32768)();player=(C.c_ubyte*80)()
config=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(edits))
coords=lambda x,y,z:(I*3)(x,y,z)
assert init(world,config)==0 and center(world,0,0)==1
feet=(C.c_double*3)(.5,height(42,0,0)+1,.5);assert pinit(player,feet)==0
checks=0
def check(v,msg='walk save assertion'):
 global checks
 checks+=1
 assert v,msg

def checksum(data):
 value=0xcbf29ce484222325
 for i,b in enumerate(data):value=((value^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
 return value

def reference():
 records=bytes(edits)[:world[6]*32]
 head=bytearray(128)
 struct.pack_into('<8sIIIIQQ',head,0,b'VXAWALK\0',1,0,1,world[6],42,len(records))
 head[64:96]=bytes(player)[:32]
 blob=head+records;struct.pack_into('<Q',blob,40,checksum(blob));return bytes(blob)

out=(C.c_ubyte*262272)()
for p in [coords(15,79,15),coords(-20,100,-20),coords(30,100,30)]:
 current=get(world,p);check(edit(world,p,0 if current else 5)==1)
length=encode(world,player,out,262272)
check(length==224 and bytes(out[:length])==reference(),'independent exact save bytes')
valid=bytes(out[:length])
check(center(world,10,-10)==1)
check(decode(C.create_string_buffer(valid),length,world,player)==0)
check(get(world,coords(-20,100,-20))==5,'saved off-origin override')
check(bytes(out[:length])==reference(),'pose or journal roundtrip')
check(center(world,10,-10)==1 and center(world,0,0)==1)
check(get(world,coords(15,79,15))==struct.unpack_from('<Q',valid,152)[0])

def reject(blob):
 before=(bytes(world),bytes(player),bytes(edits),bytes(entries),bytes(blocks))
 check(decode(C.create_string_buffer(blob),len(blob),world,player)==-1,'corrupt save accepted')
 check(before==(bytes(world),bytes(player),bytes(edits),bytes(entries),bytes(blocks)),'failed load changed world/player/cache')

def repaired(blob):
 b=bytearray(blob);struct.pack_into('<Q',b,40,checksum(b));return bytes(b)
for i in range(128):
 b=bytearray(valid);b[i]^=0x80;reject(bytes(b))
for n in [0,1,63,127,128,159,223]:reject(valid[:n])
reject(valid+b'x')
for offset,value,fmt in [(8,2,'I'),(12,1,'I'),(16,2,'I'),(20,8193,'I'),(24,43,'Q'),(48,1,'Q'),(56,1,'Q'),(96,1,'Q'),(128,30000000,'q'),(136,0,'q'),(136,256,'q'),(144,-30000001,'q'),(152,7,'Q')]:
 b=bytearray(valid);struct.pack_into('<'+fmt,b,offset,value);reject(repaired(b))
for offset,value,fmt in [(64,float('nan'),'d'),(72,float('inf'),'d'),(80,30000000.,'d'),(72,0.,'d'),(72,255.,'d'),(88,4.,'f'),(92,-2.,'f')]:
 b=bytearray(valid);struct.pack_into('<'+fmt,b,offset,value);reject(repaired(b))
b=bytearray(valid);b[160:192]=b[128:160];reject(repaired(b))
b=bytearray(valid);struct.pack_into('<Q',b,184,0);reject(repaired(b)) # redundant air override
# A checksummed but embedded player is unsafe, even if the pose is in bounds.
b=bytearray(valid);struct.pack_into('<d',b,72,1.);reject(repaired(b))
C.memset(out,0xa5,len(out));before=bytes(out)
check(encode(world,player,out,length-1)==-2 and bytes(out)==before,'capacity write')
print(f'PASS: {checks} player/world save checksum/pose/transaction assertions')
