"""Gameplay format2 exact bytes, legacy migration and all-state atomic load."""
import ctypes as C
import struct
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);edit=bind('stream_edit',[P,P,U]);height=bind('terrain_height',[U,I,I]);pinit=bind('player_init',[P,P])
iinit=bind('inventory_init',[P]);add=bind('inventory_add',[P,U,U,U]);craft=bind('inventory_craft',[P,U])
encode=bind('game_encode',[P,P,P,P]);decode=bind('game_decode',[P,U,P,P]);oldencode=bind('walk_encode',[P,P,P,U])
world=(U*12)();entries=(C.c_ubyte*25600)();blocks=(C.c_ubyte*3276800)();edits=(I*32768)();player=(C.c_ubyte*80)();inventory=(C.c_ubyte*80)()
config=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(edits))
assert init(world,config)==0 and center(world,0,0)==1
assert pinit(player,(C.c_double*3)(.5,height(42,0,0)+1,.5))==0 and iinit(inventory)==0
assert craft(inventory,0)==1 and add(inventory,11,1,17)==1
struct.pack_into('<II',inventory,72,3,1)
assert edit(world,(I*3)(15,100,15),5)==1
out=(C.c_ubyte*262368)();target=(U*2)(C.addressof(out),262352);bundle=(U*2)(C.addressof(player),C.addressof(inventory));checks=0
def check(v,msg):
 global checks
 checks+=1;assert v,msg
def checksum(data):
 h=0xcbf29ce484222325
 for i,b in enumerate(data):h=((h^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
 return h
def repaired(b):
 b=bytearray(b);struct.pack_into('<Q',b,40,checksum(b));return bytes(b)
C.memset(out,0xa5,len(out));n=encode(world,player,inventory,target)
check(n==240,'encoded length')
header=bytearray(128);struct.pack_into('<8sIIIIQQ',header,0,b'VXAWALK\0',2,0,1,1,42,112);struct.pack_into('<Q',header,96,80);header[64:96]=bytes(player)[:32]
expected=repaired(header+struct.pack('<qqqQ',15,100,15,5)+bytes(inventory));valid=bytes(out[:n])
check(valid==expected and bytes(out[n:])==b'\xa5'*(len(out)-n),'exact independent bytes and canary')
pose=bytes(player)[:32];savedinventory=bytes(inventory)
iinit(inventory);struct.pack_into('<d',player,0,1.5)
inputbuf=C.create_string_buffer(valid);check(decode(inputbuf,n,world,bundle)==0,'roundtrip')
check(bytes(inventory)==savedinventory and bytes(player)[:32]==pose and inputbuf.raw[:n]==valid,'states/input immutable')
def reject(blob):
 before=tuple(bytes(x) for x in [world,player,inventory,entries,blocks,edits])
 check(decode(C.create_string_buffer(bytes(blob)),len(blob),world,bundle)==-1,'malformed accepted')
 check(before==tuple(bytes(x) for x in [world,player,inventory,entries,blocks,edits]),'failed load mutated state')
for i in range(n):
 b=bytearray(valid);b[i]^=0x80;reject(b)
for offset,value,fmt in [(8,3,'I'),(12,1,'I'),(16,2,'I'),(20,8193,'I'),(24,43,'Q'),(32,80,'Q'),(48,1,'Q'),(96,79,'Q'),(104,1,'Q'),(128,30000000,'q'),(136,0,'q'),(152,7,'Q'),(160,7,'H'),(162,65,'H'),(164,1,'H'),(166,1,'H'),(232,9,'I'),(236,2,'I'),(72,1.,'d')]:
 b=bytearray(valid);struct.pack_into('<'+fmt,b,offset,value);reject(repaired(b))
# Truncated but repaired outer checksum must reject before staging copy.
for k in range(128,n):reject(repaired(valid[:k]))
reject(valid+b'x');reject(b'');reject(valid[:127])
# A valid outer checksum cannot disguise duplicate/redundant world records.
b=bytearray(valid[:160]+valid[128:160]+valid[160:]);struct.pack_into('<I',b,20,2);struct.pack_into('<Q',b,32,144);reject(repaired(b))
b=bytearray(valid);struct.pack_into('<Q',b,152,0);reject(repaired(b))
C.memset(out,0xa5,len(out));before=bytes(out);target[1]=n-1
check(encode(world,player,inventory,target)==-2 and bytes(out)==before,'encode capacity atomic')
target[1]=262352;inventory[76]=2
check(encode(world,player,inventory,target)==-1 and bytes(out)==before,'invalid inventory output atomic')
iinit(inventory)
legacy_n=oldencode(world,player,out,262272);check(legacy_n==160,'legacy encode')
add(inventory,11,1,132);legacy=bytes(out[:legacy_n])
check(decode(C.create_string_buffer(legacy),legacy_n,world,bundle)==0,'legacy load')
fresh=(C.c_ubyte*80)();iinit(fresh);check(bytes(inventory)==bytes(fresh),'legacy starter migration')
# Max bounded journal exercises staging at maximum file size.
# Coordinates air above terrain are unique, off-body and canonical.
for i in range(8192):
 struct.pack_into('<qqqQ',edits,i*32,(i%128)-64,100,(i//128)-32,5)
world[6]=8192
check(encode(world,player,inventory,target)==262352,'max gameplay size')
check(decode(out,262352,world,bundle)==0,'max gameplay load')
check(bytes(out[262352:])==b'\xa5'*16,'max canary')
print(f'PASS: {checks} gameplay save/migration/atomic validation assertions')
