"""Independent 3D interpolation and versioned section/cave contracts."""
import ctypes as C
import itertools
import random
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64
noise=lib.noise3;noise.argtypes=[U,P,U];noise.restype=I
column=lib.terrain1_column;column.argtypes=[U,I,I,P];column.restype=I
cave=lib.terrain1_cave;cave.argtypes=[U,P,I];cave.restype=I
block=lib.generated_block1;block.argtypes=[U,P,P];block.restype=I
section=lib.generate_section1;section.argtypes=[P,U,P];section.restype=I
landscape=lib.landscape_sample;landscape.argtypes=[U,I,I,P];landscape.restype=I
noise2=lib.noise2;noise2.argtypes=[U,I,I,U];noise2.restype=I
MASK=(1<<64)-1
# mix64 is the same frozen unsigned hash contract used by world noise.
def mix(v):
 v=(v+0x9e3779b97f4a7c15)&MASK
 v=((v^(v>>30))*0xbf58476d1ce4e5b9)&MASK
 v=((v^(v>>27))*0x94d049bb133111eb)&MASK
 return v^(v>>31)
def fade(t):
 t3=(((t*t)>>16)*t)>>16
 poly=(((6*t-15*65536)*t)>>16)+10*65536
 return (t3*poly)>>16
def n3(seed,x,y,z,shift):
 coords=(x,y,z);q=[a>>shift for a in coords]
 f=[fade(((a&((1<<shift)-1))<<16)>>shift) for a in coords]
 vals=[]
 for i in range(8):
  xx=q[0]+(i&1);yy=q[1]+((i>>1)&1);zz=q[2]+(i>>2)
  h=seed^((xx*0xd6e8feb86659fd93)&MASK)^((yy*0x9e3779b185ebca87)&MASK)^((zz*0xa5a3564e27f8862f)&MASK)
  vals.append(mix(h)>>48)
 for t in f:vals=[vals[i]+(((vals[i+1]-vals[i])*t)>>16) for i in range(0,len(vals),2)]
 return vals[0]
def cavity(seed,x,y,z,h):
 if y<-248 or y>h-8:return 0
 if abs(n3(seed^0x3412abcd,x,y,z,5)-32768)<=2600 and abs(n3(seed^0x7241def0,x,y,z,5)-32768)<=5500:return 1
 return int(y<-32 and n3(seed^0x57ab1923,x,y,z,6)>53000)
def expected(seed,x,y,z,data):
 h,biome=data[:2]
 if y==-256:return 7
 if y>h or cavity(seed,x,y,z,h):return 0
 if y<h-3 or biome==10:return 1
 if biome in (2,4,5):return 4
 return 3 if y==h else 2
rng=random.Random(1224);coords=(I*3)();checks=0
for shift in range(17):
 for _ in range(50):
  seed=rng.getrandbits(64);point=tuple(rng.randrange(-30000000,30000000) for _ in range(3));coords[:]=point
  got=noise(seed,coords,shift);want=n3(seed,*point,shift)
  assert got==want and 0<=got<=65535,(shift,point,got,want);checks+=1
assert noise(0,coords,17)==-1
# Axis interpolation agrees at shared lattice planes and negative coordinates.
for shift in (1,5,16):
 for axis in range(3):
  point=[-32,64,-128];point[axis]=-(1<<shift);coords[:]=point
  assert noise(42,coords,shift)==n3(42,*point,shift)
biomes=set();top=(C.c_int32*8)();base=(C.c_int32*4)()
for _ in range(1200):
 x,z=rng.randrange(-30000000,30000000),rng.randrange(-30000000,30000000)
 seed=rng.getrandbits(64)
 assert column(seed,x,z,top)==0 and landscape(seed,x,z,base)==0
 h=base[0]+(abs(noise2(seed^0x62417a35,x,z,8)-32768)>>7 if base[1] in (3,10) else 0)
 assert list(top[:4])==[h,*base[1:]] and -248<=h<=767 and top[6]==top[7]==0
 biomes.add(top[1])
 for y in (-256,-255,-248,-128,-32,0,h-8,h-7,h,h+1,767):
  coords[:]=(x,y,z)
  assert block(seed,coords,top)==expected(seed,x,y,z,list(top))
  assert cave(seed,coords,h)==cavity(seed,x,y,z,h);checks+=1
assert biomes==set(range(11)),biomes
# Section order and boundaries match the independently evaluated global world.
cave_air=0;underground_solid=0
for sx,sy,sz in [(0,-16,0),(-1,-8,1),(5,-3,-7),(0,4,0),(0,47,0),(1874999,-1,-1875000)]:
 buf=C.create_string_buffer(b'\xa5'*8224,8224);coords[:]=(sx,sy,sz)
 assert section(buf,42,coords)==0 and buf.raw[8192:]==b'\xa5'*32
 cells=C.cast(buf,C.POINTER(C.c_uint16));empty=solid=0
 for z,x in itertools.product(range(16),repeat=2):
  gx,gz=sx*16+x,sz*16+z;assert column(42,gx,gz,top)==0
  for y in range(16):
   gy=sy*16+y;want=expected(42,gx,gy,gz,list(top));got=cells[y*256+z*16+x]
   assert got==want,(gx,gy,gz,got,want);checks+=1
   empty+=got==0;solid+=got!=0
 if sy==-16:assert all(cells[z*16+x]==7 for z,x in itertools.product(range(16),repeat=2))
 if sy==47:assert empty==4096
 if sy in (-8,-3,-1):cave_air+=empty;underground_solid+=solid
assert cave_air>0 and underground_solid>0,(cave_air,underground_solid)
# Bounds reject before section output or column output mutation.
buf=C.create_string_buffer(b'\xa5'*8224,8224)
for xyz in [(0,-17,0),(0,48,0),(-1875001,0,0),(1875000,0,0),(0,0,1875000)]:
 coords[:]=xyz;assert section(buf,42,coords)==-1 and buf.raw==b'\xa5'*8224
out=C.create_string_buffer(b'\xa5'*32,32)
for x,z in [(-30000001,0),(30000000,0),(0,30000000)]:
 assert column(42,x,z,out)==-1 and out.raw==b'\xa5'*32
assert column(42,0,0,top)==0
for xyz in [(0,-257,0),(0,768,0),(30000000,0,0)]:
 coords[:]=xyz;assert block(42,coords,top)==-1 and cave(42,coords,top[0])==-1
coords[:]=(0,0,0);assert block(43,coords,top)==-1
print(f'PASS: {checks} independent 3D noise/block checks, 11 biome columns, full vertical range, shared global caves and section canaries')
