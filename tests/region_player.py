"""Independent full-height region player wire format and atomic corruption checks."""
import ctypes as C
import math, struct, sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
encode=bind('region_player_encode',[U,P,P,P]);decode=bind('region_player_decode',[P,U,U,P]);pinit=bind('player_init',[P,P]);iinit=bind('inventory36_init',[P])
player=C.create_string_buffer(80);inv=C.create_string_buffer(336);assert pinit(player,(C.c_double*3)(-.5,-128,.5))==0 and iinit(inv)==0
struct.pack_into('<ff',player,24,.5,-.25);struct.pack_into('<HHHH',inv,304,5,3,0,0);struct.pack_into('<f',player,64,1.5)
out=C.create_string_buffer(448);C.memset(out,0xa5,448)
assert encode(42,player,inv,out)==432

def checksum(b):
 h=0xcbf29ce484222325
 for i,x in enumerate(b):h=((h^(0 if 32<=i<40 else x))*0x100000001b3)&((1<<64)-1)
 return h
def repair(b):
 b=bytearray(b);struct.pack_into('<Q',b,32,checksum(b));return bytes(b)
header=bytearray(64);struct.pack_into('<8sIIQQ',header,0,b'VXAPLYR1',1,64,42,432)
expected=repair(header+player.raw[:32]+inv.raw);valid=out.raw[:432]
assert valid==expected and out.raw[432:]==b'\xa5'*16
bundle=(U*2)(C.addressof(player),C.addressof(inv));source=C.create_string_buffer(valid)
C.memset(inv,0,336);assert decode(source,432,42,bundle)==0
assert player.raw[:32]==valid[64:96] and inv.raw==valid[96:] and source.raw[:432]==valid
assert struct.unpack_from('<f',player,64)[0]==1.5 and struct.unpack_from('<d',player,48)[0]==0
checks=0
def reject(data,seed=42):
 global checks
 before=player.raw+inv.raw;assert decode(C.create_string_buffer(data),len(data),seed,bundle)==-1
 assert player.raw+inv.raw==before;checks+=1
for i in range(432):
 b=bytearray(valid);b[i]^=128;reject(bytes(b))
for offset,fmt,value in [(8,'I',2),(12,'I',65),(16,'Q',43),(24,'Q',433),(40,'Q',1),(64,'d',math.nan),(72,'d',math.inf),(72,'d',-256),(72,'d',767),(80,'d',30000000),(88,'f',4),(92,'f',2),(96,'H',65535),(98,'H',65),(400,'H',7),(404,'H',1)]:
 b=bytearray(valid);struct.pack_into('<'+fmt,b,offset,value);reject(repair(b))
reject(valid,43)
for n in [0,63,64,95,96,431,433]:reject((valid+b'x')[:n])
for y in (-255,400,766.2):
 struct.pack_into('<d',player,8,y);assert encode(42,player,inv,out)==432 and decode(out,432,42,bundle)==0
struct.pack_into('<d',player,8,767);before=out.raw;assert encode(42,player,inv,out)==-1 and out.raw==before
print(f'PASS: exact region player/336-byte crafting wire, full-height poses, aspect/reset, {checks} atomic malformed/checksum/seed rejections and output canaries')
