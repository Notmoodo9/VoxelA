"""Independent seeded climate/heightfield model, bounds and destination canaries."""
import ctypes as C,random,struct,sys
lib=C.CDLL(sys.argv[1]);f=lib.landscape_sample;f.argtypes=[C.c_uint64,C.c_int64,C.c_int64,C.c_void_p];f.restype=C.c_int64
MASK=(1<<64)-1

def lattice(seed,x,z):
 n=(seed^((x*0xd6e8feb86659fd93)&MASK)^((z*0xa5a3564e27f8862f)&MASK))
 n=(n+0x9e3779b97f4a7c15)&MASK;n=((n^(n>>30))*0xbf58476d1ce4e5b9)&MASK;n=((n^(n>>27))*0x94d049bb133111eb)&MASK
 return (n^(n>>31))>>48

def fade(t):return (((((t*t)>>16)*t)>>16)*((((6*t-15*65536)*t)>>16)+10*65536))>>16

def noise(seed,x,z,k):
 step=1<<k;a=x//step;b=z//step;fx=fade(x%step*65536//step);fz=fade(z%step*65536//step)
 n=lattice(seed,a,b);m=lattice(seed,a,b+1)
 low=n+((lattice(seed,a+1,b)-n)*fx>>16);high=m+((lattice(seed,a+1,b+1)-m)*fx>>16)
 return low+((high-low)*fz>>16)

def model(seed,x,z):
 c=noise(seed,x,z,10);m=noise(seed^0x23456789,x,z,9);t=noise(seed^0x456789ab,x,z,10);h=64+(noise(seed^0x12345678,x,z,7)>>12);r=noise(seed^0x3456789a,x,z,8)-32768;b=0
 if c<24000:h=24+(c>>10);b=4
 elif c>49000:h=((c*3)>>9)-140;b=10 if t>=46000 and m<=23000 else 3
 elif -1100<=r<=1100:h=52;b=5
 elif t<20000:b=6
 elif m>55000:h+=24;b=9
 elif m>47000:h-=8;b=7
 elif m<26000:
  if t>=42000:h+=6;b=2
  else:b=8
 elif m>=36000:b=1
 return h,b,m,t
rng=random.Random(931);seen=set();checks=0
for seed,x,z in [(42,x,z) for x in range(-8192,8193,256) for z in range(-8192,8193,256)]+[(rng.getrandbits(64),rng.randrange(-30000000,30000000),rng.randrange(-30000000,30000000)) for _ in range(3000)]:
 out=C.create_string_buffer(b'\xa5'*32,32);assert f(seed,x,z,out)==0
 got=struct.unpack_from('<iIII',out);assert got==model(seed,x,z),(seed,x,z,got,model(seed,x,z));assert out.raw[16:]==b'\xa5'*16
 assert 0<=got[0]<768;seen.add(got[1]);checks+=1
assert seen==set(range(11)),seen
for x,z in [(-30000001,0),(30000000,0),(0,-30000001),(0,30000000)]:
 out=C.create_string_buffer(b'\xa5'*32,32);assert f(42,x,z,out)==-1 and out.raw==b'\xa5'*32
print(f'PASS: {checks} independent landscape samples; all 11 biomes, signed coordinates, bounds and canaries')
