"""Gameplay format4 exact bytes, legacy migration and all-state atomic load."""
import ctypes as C
import struct
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);edit=bind('stream_edit',[P,P,U]);height=bind('terrain_height',[U,I,I]);pinit=bind('player_init',[P,P])
iinit=bind('inventory36_init',[P]);add=bind('inventory36_add',[P,U,U,U]);craft=bind('inventory36_craft',[P,U])
encode=bind('game_grid_encode',[P,P,P,P]);decode=bind('game_grid_decode',[P,U,P,P]);oldencode=bind('walk_encode',[P,P,P,U])
world=(U*12)();entries=(C.c_ubyte*25600)();blocks=(C.c_ubyte*3276800)();edits=(I*32768)();player=(C.c_ubyte*80)();inventory=(C.c_ubyte*336)()
config=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(edits))
assert init(world,config)==0 and center(world,0,0)==1
assert pinit(player,(C.c_double*3)(.5,height(42,0,0)+1,.5))==0 and iinit(inventory)==0
assert craft(inventory,0)==1 and add(inventory,11,1,17)==1
transfer=bind('inventory36_transfer',[P,U,U]);assert transfer(inventory,3,35)==1
struct.pack_into('<HHHH',inventory,296,9,3,0,0)
struct.pack_into('<II',inventory,288,3,1)
struct.pack_into('<HHHH',inventory,304,5,3,0,0)
struct.pack_into('<HHHH',inventory,328,8,2,0,0)
assert edit(world,(I*3)(15,100,15),5)==1
out=(C.c_ubyte*262624)();target=(U*2)(C.addressof(out),262608);bundle=(U*2)(C.addressof(player),C.addressof(inventory));checks=0
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
check(n==496,'encoded length')
header=bytearray(128);struct.pack_into('<8sIIIIQQ',header,0,b'VXAWALK\0',4,0,1,1,42,368);struct.pack_into('<Q',header,96,336);header[64:96]=bytes(player)[:32]
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
for offset,value,fmt in [(8,5,'I'),(12,1,'I'),(16,2,'I'),(20,8193,'I'),(24,43,'Q'),(32,80,'Q'),(48,1,'Q'),(96,79,'Q'),(104,1,'Q'),(128,30000000,'q'),(136,0,'q'),(152,7,'Q'),(160,7,'H'),(162,65,'H'),(164,1,'H'),(166,1,'H'),(448,9,'I'),(452,2,'I'),(456,7,'H'),(458,65,'H'),(462,1,'H'),(72,1.,'d'),(464,7,'H'),(466,65,'H'),(468,1,'H'),(470,1,'H')]:
 b=bytearray(valid);struct.pack_into('<'+fmt,b,offset,value);reject(repaired(b))
# Truncated but repaired outer checksum must reject before staging copy.
for k in range(128,n):reject(repaired(valid[:k]))
reject(valid+b'x');reject(b'');reject(valid[:127])
# A valid outer checksum cannot disguise duplicate/redundant world records.
b=bytearray(valid[:160]+valid[128:160]+valid[160:]);struct.pack_into('<I',b,20,2);struct.pack_into('<Q',b,32,400);reject(repaired(b))
b=bytearray(valid);struct.pack_into('<Q',b,152,0);reject(repaired(b))
C.memset(out,0xa5,len(out));before=bytes(out);target[1]=n-1
check(encode(world,player,inventory,target)==-2 and bytes(out)==before,'encode capacity atomic')
target[1]=262608;inventory[292]=2
check(encode(world,player,inventory,target)==-1 and bytes(out)==before,'invalid inventory output atomic')
iinit(inventory)
legacy_n=oldencode(world,player,out,262272);check(legacy_n==160,'legacy encode')
add(inventory,11,1,132);legacy=bytes(out[:legacy_n])
check(decode(C.create_string_buffer(legacy),legacy_n,world,bundle)==0,'legacy load')
fresh=(C.c_ubyte*336)();iinit(fresh);check(bytes(inventory)==bytes(fresh),'legacy starter migration')
# Existing format2 data keeps all nine items, metadata and tool wear.
old=(C.c_ubyte*80)();oldinit=bind('inventory_init',[P]);oldadd=bind('inventory_add',[P,U,U,U]);oldenc=bind('game_encode',[P,P,P,P])
oldinit(old);oldadd(old,11,1,17);struct.pack_into('<II',old,72,2,1)
legacy2_n=oldenc(world,player,old,target)
legacy2=bytes(out[:legacy2_n])
check(decode(out,legacy2_n,world,bundle)==0,'format2 load')
check(bytes(inventory[:72])==bytes(old[:72]) and bytes(inventory[72:288])==bytes(216) and bytes(inventory[288:296])==bytes(old[72:80]) and bytes(inventory[296:])==bytes(40),'format2 slot/meta migration')
for offset,value in [(legacy2_n-4,2),(legacy2_n-8,9),(legacy2_n-80,7)]:
 b=bytearray(legacy2);b[offset]=value;reject(repaired(b))
# Format3 migration preserves cursor/carried items, empties all new grid cells.
old3=(C.c_ubyte*304)();iinit(old3);struct.pack_into('<HHHH',old3,296,8,12,0,0)
old3enc=bind('game36_encode',[P,P,P,P]);old3n=old3enc(world,player,old3,target)
check(decode(out,old3n,world,bundle)==0,'format3 load')
check(bytes(inventory[:304])==bytes(old3) and bytes(inventory[304:])==bytes(32),'format3 grid migration')
# Invalid grid data must be rejected before writing the output.
struct.pack_into('<HHHH',inventory,304,7,1,0,0);before=bytes(out)
check(encode(world,player,inventory,target)==-1 and bytes(out)==before,'grid encode atomic')
struct.pack_into('<Q',inventory,304,0)
# Max bounded journal exercises staging at maximum file size.
# Coordinates air above terrain are unique, off-body and canonical.
for i in range(8192):
 struct.pack_into('<qqqQ',edits,i*32,(i%128)-64,100,(i//128)-32,5)
world[6]=8192
check(encode(world,player,inventory,target)==262608,'max gameplay size')
check(decode(out,262608,world,bundle)==0,'max gameplay load')
check(bytes(out[262608:])==b'\xa5'*16,'max canary')
print(f'PASS: {checks} grid gameplay save/migration/atomic validation assertions')
