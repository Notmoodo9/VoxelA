"""Independent recorded-edge extraction and rational transition reference."""
import ctypes as C
import random, sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
edge=bind('legacy_edge_profile',[P,U,P]);blend=bind('terrain1_blend_column',[U,P,P,P]);column=bind('terrain1_column',[U,I,I,P]);section=bind('generate_section_blend',[P,U,P,P]);native_section=bind('generate_section1',[P,U,P]);block=bind('generated_block1',[U,P,P])
rng=random.Random(51023);coords=(I*3)();native=C.create_string_buffer(32);actual=C.create_string_buffer(48);profile=C.create_string_buffer(264);mask=U.from_buffer(profile);heights=(C.c_int32*64).from_buffer(profile,8)
# Actual sections include removed tops, floating player builds and asymmetric edges.
sections=[(C.c_uint16*4096)() for _ in range(16)];ptrs=(U*16)(*[C.addressof(s) for s in sections]);tops=[rng.randrange(1,256) for _ in range(256)]
for cell,h in enumerate(tops):
 sections[0][cell]=7
 for y in range(1,h+1):sections[y//16][(y%16)*256+cell]=rng.randrange(1,7)
for face in range(4):
 result=C.create_string_buffer(b'\xa5'*80,80)
 assert edge(ptrs,face,result)==0
 indices=[z*16+(0 if face==0 else 15) for z in range(16)] if face<2 else [x+(0 if face==2 else 240) for x in range(16)]
 assert list((C.c_int32*16).from_buffer(result))==[tops[i] for i in indices]
 assert result.raw[64:]==b'\xa5'*16
# Validation must inspect all sections, including blocks away from selected face.
sections[9][1023]=8;before=actual.raw
assert edge(ptrs,0,actual)==-1 and actual.raw==before
sections[9][1023]=0
assert edge(ptrs,4,actual)==-1 and actual.raw==before
sections[0][17]=0;assert edge(ptrs,0,actual)==-1 and actual.raw==before;sections[0][17]=7
saved=ptrs[10];ptrs[10]=0;assert edge(ptrs,1,actual)==-1 and actual.raw==before;ptrs[10]=saved

def expected(h,x,z,m):
 d=[x%16,15-x%16,z%16,15-z%16]
 faces=[i for i in range(4) if m&(1<<i)]
 samples={i:heights[i*16+(z%16 if i<2 else x%16)] for i in faces}
 touching=[i for i in faces if d[i]==0]
 if touching:return sum(samples[i] for i in touching)//len(touching)
 w=1
 for i in faces:w*=d[i]**2
 numerator=h*w;denominator=w
 for i in faces:
  weight=(16-d[i])**2
  for j in faces:
   if i!=j:weight*=d[j]**2
  numerator+=samples[i]*weight;denominator+=weight
 return numerator//denominator
checks=0
for m in range(16):
 mask.value=m
 for i in range(64):heights[i]=rng.randrange(256)
 for x,z in [(x-32,z-16) for x in range(16) for z in range(16)]:
  coords[:]=(x,0,z);assert column(42,x,z,native)==0
  C.memset(actual,0xa5,48);assert blend(42,coords,profile,actual)==0
  h=C.c_int32.from_buffer(native).value
  assert C.c_int32.from_buffer(actual).value==expected(h,x,z,m)
  assert actual.raw[4:32]==native.raw[4:] and actual.raw[32:]==b'\xa5'*16
  checks+=1
# Global signed samples exercise all climate profiles and extreme terrain.
for _ in range(512):
 x,z=rng.randrange(-30000000,30000000),rng.randrange(-30000000,30000000)
 seed=rng.getrandbits(64);mask.value=rng.randrange(16)
 for i in range(64):heights[i]=rng.randrange(256)
 coords[:]=(x,0,z);assert column(seed,x,z,native)==0 and blend(seed,coords,profile,actual)==0
 assert C.c_int32.from_buffer(actual).value==expected(C.c_int32.from_buffer(native).value,x,z,mask.value)
 assert actual.raw[4:32]==native.raw[4:];checks+=1
# Validate world limits and every active edge sample before mutation.
mask.value=1;heights[15]=256;before=actual.raw
assert blend(42,coords,profile,actual)==-1 and actual.raw==before
heights[15]=-1;assert blend(42,coords,profile,actual)==-1 and actual.raw==before
heights[15]=70;mask.value=16;assert blend(42,coords,profile,actual)==-1 and actual.raw==before
mask.value=0;coords[0]=30000000;assert blend(42,coords,profile,actual)==-1 and actual.raw==before
# Section cells match independently blended heights and established block policy.
out=C.create_string_buffer(8224);other=C.create_string_buffer(8192)
for sx,sy,sz,m in [(-2,4,-1,0),(-2,4,-1,5),(0,-16,0,15),(1874999,47,-1875000,3),(0,0,0,1)]:
 mask.value=m
 for i in range(64):heights[i]=rng.randrange(64,96)
 sc=(I*3)(sx,sy,sz);C.memset(out,0xa5,8224)
 assert section(out,42,sc,profile)==0 and out.raw[8192:]==b'\xa5'*32
 cells=(C.c_uint16*4096).from_buffer(out)
 for z in range(16):
  for x in range(16):
   gx,gz=sx*16+x,sz*16+z;assert column(42,gx,gz,native)==0
   C.c_int32.from_buffer(native).value=expected(C.c_int32.from_buffer(native).value,gx,gz,m)
   for y in range(16):
    coords[:]=(gx,sy*16+y,gz)
    assert cells[y*256+z*16+x]==block(42,coords,native)
 if m==0:
  assert native_section(other,42,sc)==0 and out.raw[:8192]==other.raw
mask.value=16;before=out.raw
assert section(out,42,(I*3)(0,0,0),profile)==-1 and out.raw==before
mask.value=0;assert section(out,42,(I*3)(0,48,0),profile)==-1 and out.raw==before
# Region publication is staged and never rewrites an occupied section.
rinit=bind('region_init',[P,P]);rgen=bind('region_generate_blend',[P,U,P]);rvalid=bind('region_valid',[P])
region=C.create_string_buffer(131296);C.memset(region,0xa5,131296)
assert rinit(region,(I*4)(42,-1,0,4))==0
mask.value=1
for i in range(16):heights[i]=70+i
assert rgen(region,3,profile)==1 and rvalid(region)==0
assert section(other,42,(I*3)(-1,4,0),profile)==0
assert region.raw[192+3*8192:192+4*8192]==other.raw
assert U.from_buffer(region,40).value==1 and region.raw[131264:]==b'\xa5'*32
before=region.raw;mask.value=16
assert rgen(region,3,profile)==0 and region.raw==before
assert rgen(region,2,profile)==-1 and region.raw==before
mask.value=0;U.from_buffer(region,40).value=(1<<63)-1;before=region.raw
assert rgen(region,2,profile)==-1 and region.raw==before
assert rgen(region,16,profile)==-1 and region.raw==before
print(f'PASS: recorded edited-edge extraction, {checks} independent blend columns, all masks/corners, full-height sections, no-edge equivalence and rejection canaries')
