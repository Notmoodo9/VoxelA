"""Exact top surface compared against actual generated blocks plus shuffled edits."""
import ctypes as C,random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64
f=lib.terrain_surface;f.argtypes=[P,I,I,P];f.restype=I
g=lib.generated_block;g.argtypes=[U,P];g.restype=I
world=(U*12)();journal=(I*(8192*4))();world[0]=42;world[7]=C.addressof(journal)
rng=random.Random(1193);checks=0
for seed,x,z in [(42,0,0),(0,-30000000,29999999),(2**64-1,16000000,-16000000)]+[(rng.getrandbits(64),rng.randrange(-30000000,30000000),rng.randrange(-30000000,30000000)) for _ in range(350)]:
 world[0]=seed
 cells=[g(seed,(I*3)(x,y,z)) for y in range(256)]
 changes={y:rng.choice([0,0,0,1,2,4,5,6]) for y in rng.sample(range(1,256),rng.randrange(60))}
 # Also remove consecutive surface layers, ensuring the sampler sees exposed soil.
 top=max(y for y in range(256) if cells[y]);changes.update({y:0 for y in range(top-5,top+1)})
 records=[(x,y,z,b) for y,b in changes.items()]+[(x+1,255,z,5)]
 rng.shuffle(records);world[6]=len(records)
 for i,row in enumerate(records):
  for a,n in enumerate(row):journal[i*4+a]=n
 for y,b in changes.items():cells[y]=b
 top=max(y for y in range(256) if cells[y]);out=C.create_string_buffer(b'\xa5'*24,24)
 assert f(world,x,z,out)==0 and struct.unpack_from('<II',out)==(top+1,cells[top]);assert out.raw[8:]==b'\xa5'*16
 checks+=1
world[6]=0;world[0]=42
for x,z in [(-30000001,0),(30000000,0),(0,-30000001),(0,30000000)]:
 out=C.create_string_buffer(b'\xa5'*24,24);assert f(world,x,z,out)==-1 and out.raw==b'\xa5'*24
world[6]=8193;out=C.create_string_buffer(b'\xa5'*24,24);assert f(world,0,0,out)==-1 and out.raw==b'\xa5'*24
world[6]=1
for y,b in [(0,0),(256,1),(70,7),(-1,2)]:
 for a,n in enumerate((0,y,0,b)):journal[a]=n
 out=C.create_string_buffer(b'\xa5'*24,24);assert f(world,0,0,out)==-1 and out.raw==b'\xa5'*24
print(f'PASS: {checks} exact generator/journal surface comparisons, removed layers, towers, negative coordinates and rejected output conservation')
