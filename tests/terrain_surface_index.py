"""Indexed queries must match the existing generator/edit oracle exactly."""
import ctypes as C
import random
import sys
import time
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64
build=lib.terrain_surface_index_build;build.argtypes=[P,P];build.restype=I
indexed=lib.terrain_surface_indexed;indexed.argtypes=[P,I,I,P];indexed.restype=I
plain=lib.terrain_surface;plain.argtypes=[P,I,I,P];plain.restype=I
world=(U*12)();world[0]=42
journal=(I*(8192*4))();world[7]=C.addressof(journal)
rng=random.Random(912)
rows=[(0,y,0,0) for y in range(1,80)]
rows += [(0,180,0,5),(-29999999,255,29999999,6),(16000000,190,-16000000,1)]
occupied={(x,y,z) for x,y,z,b in rows}
while len(rows)<8192:
 x,z=rng.randrange(-1024,1024),rng.randrange(-1024,1024)
 y=rng.randrange(1,256)
 if (x,y,z) in occupied:continue
 occupied.add((x,y,z));rows.append((x,y,z,rng.randrange(7)))
rng.shuffle(rows)
for i,row in enumerate(rows):
 for j,value in enumerate(row):journal[i*4+j]=value
world[6]=len(rows)
scratch=C.create_string_buffer(b'\xa5'*(98336+32),98336+32)
assert build(world,scratch)==0 and scratch.raw[98336:]==b'\xa5'*32
queries=[(x,z) for x,y,z,b in rows[:500]]+[(0,0),(-29999999,29999999),(16000000,-16000000)]
queries += [(rng.randrange(-30000000,30000000),rng.randrange(-30000000,30000000)) for _ in range(500)]
a=(C.c_uint32*2)();b=(C.c_uint32*2)()
for x,z in queries:
 assert plain(world,x,z,a)==0 and indexed(scratch,x,z,b)==0
 assert list(a)==list(b),(x,z,list(a),list(b))
for x,z in [(-30000001,0),(30000000,0),(0,30000000)]:
 b[:]=(123,456);assert indexed(scratch,x,z,b)==-1 and list(b)==[123,456]
# Invalid inputs must preserve the entire prepared index, including its canary.
original=scratch.raw;old=list(journal[:4])
for bad in [(0,256,0,1),(30000000,70,0,1),(0,70,0,7)]:
 journal[:4]=bad
 assert build(world,scratch)==-1 and scratch.raw==original
journal[:4]=old
world[6]=8193;assert build(world,scratch)==-1 and scratch.raw==original
# World changes require rebuilding; rebuilding removes stale column links.
world[6]=0;world[0]=43;assert build(world,scratch)==0
for x,z in queries[:20]:
 assert plain(world,x,z,a)==0 and indexed(scratch,x,z,b)==0 and list(a)==list(b)
world[6]=8192;world[0]=42;assert build(world,scratch)==0
# Report timing for a representative dense-journal workload; no brittle threshold.
def elapsed(fn,ctx):
 start=time.perf_counter()
 for x,z in queries:assert fn(ctx,x,z,b)==0
 return time.perf_counter()-start
slow=elapsed(plain,world);fast=elapsed(indexed,scratch)
print(f'PASS: {len(queries)} dense-journal indexed/oracle queries, bounds, rebuilds and canaries; scan {slow:.4f}s, index {fast:.4f}s')
