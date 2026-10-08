"""Versioned terrain regions, true saved blocks, codecs and atomic mutation."""
import ctypes as C
import struct
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;SIZE=131264

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('region_init',[P,P]);valid=bind('region_valid',[P]);generate=bind('region_generate',[P,U,U]);get=bind('region_get',[P,P]);edit=bind('region_edit',[P,P,U]);encode=bind('region_encode',[P,P,U]);decode=bind('region_decode',[P,U,P])
gen0=bind('generate_section',[P,U,P]);gen1=bind('generate_section1',[P,U,P])
region=C.create_string_buffer(b'\xa5'*(SIZE+32),SIZE+32);cfg=(I*4)(42,-1,1,4)
assert init(region,cfg)==0 and valid(region)==0 and region.raw[SIZE:]==b'\xa5'*32
coords=(I*3)(-64,64,64);assert get(region,coords)==-2
for slot,version in [(0,0),(3,1),(12,0),(15,1)]:
 assert generate(region,slot,version)==1 and valid(region)==0
 section=C.create_string_buffer(8192);sc=(I*3)(-4+(slot&3),4,4+(slot>>2))
 assert (gen0 if version==0 else gen1)(section,42,sc)==0
 assert region.raw[192+slot*8192:192+(slot+1)*8192]==section.raw
 before=region.raw
 assert generate(region,slot,1-version)==0 and region.raw==before,'old recorded terrain regenerated'
 for y,z,x in [(0,0,0),(15,15,15),(7,13,3)]:
  coords[:]=(sc[0]*16+x,sc[1]*16+y,sc[2]*16+z)
  want=struct.unpack_from('<H',section.raw,2*(y*256+z*16+x))[0]
  assert get(region,coords)==want
coords[:]=(-64,70,64);old=get(region,coords)
assert edit(region,coords,5)==(0 if old==5 else 1) and get(region,coords)==5
wire=C.create_string_buffer(b'\xa5'*(SIZE+32),SIZE+32);assert encode(region,wire,SIZE)==SIZE
assert wire.raw[SIZE:]==b'\xa5'*32
# Independent full wire image and checksum, rather than just a roundtrip.
expected=bytearray(region.raw[:SIZE]);h=0xcbf29ce484222325
for i,b in enumerate(expected):h=((h^(0 if 56<=i<64 else b))*0x100000001b3)&((1<<64)-1)
struct.pack_into('<Q',expected,56,h);assert wire.raw[:SIZE]==expected
restored=C.create_string_buffer(b'\xa5'*(SIZE+32),SIZE+32)
assert decode(wire,SIZE,restored)==0 and restored.raw[:SIZE]==region.raw[:SIZE] and restored.raw[SIZE:]==b'\xa5'*32
# Corrupt wire fields are rejected without changing live ownership or source.
def repaired(data):
 data=bytearray(data);h=0xcbf29ce484222325
 for i,b in enumerate(data):h=((h^(0 if 56<=i<64 else b))*0x100000001b3)&((1<<64)-1)
 struct.pack_into('<Q',data,56,h);return C.create_string_buffer(bytes(data),SIZE)
before=restored.raw
for at in [0,8,24,32,40,48,56,64,68,192,8192, SIZE-1]:
 damaged=bytearray(expected);damaged[at]^=1;src=C.create_string_buffer(bytes(damaged),SIZE)
 assert decode(src,SIZE,restored)==-1 and restored.raw==before
for at,value,fmt in [(8,468750,'q'),(24,48,'q'),(32,65536,'Q'),(64,2,'I'),(68,1,'I'),(192,8,'H'),(192+8192,1,'H')]:
 damaged=bytearray(expected);struct.pack_into('<'+fmt,damaged,at,value);src=repaired(damaged)
 assert decode(src,SIZE,restored)==-1 and restored.raw==before,(at,value)
for length in [0,64,SIZE-1,SIZE+1]:assert decode(wire,length,restored)==-1 and restored.raw==before
small=C.create_string_buffer(b'\xa5'*32,32);assert encode(region,small,32)==-2 and small.raw==b'\xa5'*32
for slot,version in [(16,0),(0,2),(2,2**64-1)]:
 before=region.raw;assert generate(region,slot,version)==-1 and region.raw==before
for xyz in [(0,70,64),(-64,80,64),(-65,70,64),(30000000,70,64)]:
 coords[:]=xyz;before=region.raw;assert get(region,coords)==-1 and edit(region,coords,1)==-1 and region.raw==before
# Bedrock is validated and immutable independently for each generator.
for sy,version,y in [(0,0,0),(-16,1,-256)]:
 cfg[:]=(42,0,0,sy);assert init(region,cfg)==0 and generate(region,0,version)==1
 coords[:]=(0,y,0);before=region.raw;assert get(region,coords)==7 and edit(region,coords,0)==-1 and region.raw==before
 cfg[3]=-16;assert init(region,cfg)==0
 before=region.raw;assert generate(region,0,0)==-1 and region.raw==before
# Revision overflow rejects changes; malformed immutable floors reject loads.
cfg[:]=(42,0,0,-16);assert init(region,cfg)==0 and generate(region,0,1)==1
wire=C.create_string_buffer(SIZE);assert encode(region,wire,SIZE)==SIZE
bad_floor=bytearray(wire.raw);struct.pack_into('<H',bad_floor,192,1)
before=restored.raw;assert decode(repaired(bad_floor),SIZE,restored)==-1 and restored.raw==before
C.c_uint64.from_buffer(region,40).value=0x7fffffffffffffff
coords[:]=(0,-255,0);before=region.raw
assert edit(region,coords,5)==-1 and generate(region,1,1)==-1 and region.raw==before
assert generate(region,0,1)==0 and region.raw==before
# Extreme world borders and highest layer use global generator1, not local RNG.
for rx,rz,sy in [(-468750,468749,47),(468749,-468750,-16)]:
 cfg[:]=(42,rx,rz,sy);assert init(region,cfg)==0 and generate(region,15,1)==1 and valid(region)==0
 coords[:]=(rx*64+63,sy*16+15,rz*64+63);assert 0<=get(region,coords)<=7
before=region.raw
for field,value in [(1,-468751),(1,468750),(2,468750),(3,-17),(3,48)]:
 cfg[:]=(42,0,0,0);cfg[field]=value;assert init(region,cfg)==-1 and region.raw==before
print('PASS: mixed-generator saved blocks, negative/border coordinates, edits, bedrock, exact wire/checksum and rejected-state conservation')
