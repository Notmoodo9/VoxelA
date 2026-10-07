"""Independent section cache and visible-face reference tests."""
import ctypes as C
import random
import struct
import sys
lib=C.CDLL(sys.argv[1])
U,S,P=C.c_uint64,C.c_int64,C.c_void_p
checks=0
def bind(n,args,result=S):
    f=getattr(lib,n);f.argtypes=args;f.restype=result;return f
def eq(a,b,context):
    global checks
    checks+=1
    if a!=b: raise AssertionError((context,a,b))
neighbor=bind('face_neighbor',[U,U])
mesh=bind('mesh_build',[P,P,P,U])
init=bind('cache_init',[P,P,U])
find=bind('cache_find',[P,P],P)
insert=bind('cache_insert',[P,P,P,U],P)
edit=bind('cache_edit',[P,P,U,U])
lookup=bind('cache_get',[P,P,C.POINTER(C.c_uint16)])
class Entry(C.Structure):
    _fields_=[('x',S),('y',S),('z',S),('blocks',P),('token',U),('revision',U),('saved',U),('dirty',U)]
class Cache(C.Structure):
    _fields_=[('entries',P),('capacity',U),('count',U)]
def coords(x,y,z): return (S*3)(x,y,z)
def section(values=None): return (C.c_uint16*4096)(*(values or [0]*4096))
directions=[(-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1)]
for y in range(16):
 for z in range(16):
  for x in range(16):
   i=x+16*(z+16*y)
   for d,(dx,dy,dz) in enumerate(directions):
    nx,ny,nz=x+dx,y+dy,z+dz
    boundary=not (0<=nx<16 and 0<=ny<16 and 0<=nz<16)
    j=(nx%16)+16*((nz%16)+16*(ny%16))
    eq(neighbor(i,d),j+(4096 if boundary else 0),('neighbor',x,y,z,d))
eq(neighbor(4096,0),-1,'invalid cell');eq(neighbor(0,6),-1,'invalid direction')
def reference(blocks,neighbors):
 result=[]
 for y in range(16):
  for z in range(16):
   for x in range(16):
    b=blocks[x+16*(z+16*y)]
    if not b: continue
    for d,(dx,dy,dz) in enumerate(directions):
     nx,ny,nz=x+dx,y+dy,z+dz
     if 0<=nx<16 and 0<=ny<16 and 0<=nz<16:
      other=blocks[nx+16*(nz+16*ny)]
     elif neighbors[d] is None: other=0
     else: other=neighbors[d][nx%16+16*(nz%16+16*(ny%16))]
     if other==b or other in (1,2,3,4,5,7):continue
     result.append(struct.pack('<BBBBHH',x,y,z,d,b,0))
 return b''.join(result)
rng=random.Random(1024)
empty=section();solid=section([1]*4096)
single=section();single[0]=1
pair=section();pair[0]=1;pair[1]=2
cutout=section();cutout[0]=6;cutout[1]=6
cases=[(empty,[None]*6),(single,[None]*6),(pair,[None]*6),(cutout,[None]*6),
       (solid,[None]*6),(solid,[solid]*6),(solid,[None,solid,None,None,None,None])]
for _ in range(5):
 cases.append((section([rng.randrange(8) for _ in range(4096)]),
               [section([rng.randrange(8) for _ in range(4096)]) if rng.randrange(2) else None for _ in range(6)]))
for number,(blocks,neighbors) in enumerate(cases):
 pointers=(P*6)(*[C.addressof(n) if n is not None else None for n in neighbors])
 expected=reference(blocks,neighbors);count=len(expected)//8
 eq(mesh(blocks,pointers,None,0),count,('count query',number))
 raw=(C.c_ubyte*(len(expected)+32))(*([0xA5]*(len(expected)+32)))
 out=C.cast(C.byref(raw,16),P)
 eq(mesh(blocks,pointers,out,count),count,('mesh',number))
 eq(bytes(raw[16:-16]),expected,('all records',number))
 eq(bytes(raw[:16])+bytes(raw[-16:]),bytes([0xA5]*32),'mesh canaries')
 if count:
  before=bytes(raw)
  eq(mesh(blocks,pointers,out,count-1),-2,'capacity rejection')
  eq(bytes(raw),before,'capacity failure atomicity')
 eq(mesh(blocks,None,None,0),len(reference(blocks,[None]*6))//8,'missing neighbors')
bad=section();bad[4095]=8
out=(C.c_ubyte*48)(*([0xA5]*48))
eq(mesh(bad,None,out,6),-1,'invalid source ID');eq(bytes(out),bytes([0xA5]*48),'invalid source atomicity')
pointers=(P*6)(C.addressof(bad),None,None,None,None,None)
eq(mesh(single,pointers,out,6),-1,'invalid neighbor ID');eq(bytes(out),bytes([0xA5]*48),'invalid neighbor atomicity')
entries=(Entry*8)();cache=Cache()
eq(C.sizeof(Entry),64,'entry layout');eq(C.sizeof(Cache),24,'header layout')
eq(init(C.byref(cache),entries,8),0,'cache init')
positions=[(0,1,0),(-1,1,0),(1,1,0),(0,0,0),(0,2,0),(0,1,-1),(0,1,1),(1,2,0)]
sections=[section() for _ in positions]
for k,xyz in enumerate(positions):
 ptr=insert(C.byref(cache),coords(*xyz),sections[k],k+1)
 eq(ptr,C.addressof(entries[k]),('insert',xyz));eq(find(C.byref(cache),coords(*xyz)),ptr,('find',xyz))
# Arrival must invalidate already loaded face-neighbors, but not diagonals.
for e in entries:e.dirty=0
# Direct arrival invalidation primitive is also useful for eventual removals.
touch=bind('cache_touch_neighbors',[P,P])
eq(touch(C.byref(cache),C.byref(entries[0])),0,'touch neighbors')
eq([e.dirty for e in entries],[0,1,1,1,1,1,1,0],'face neighbors only')
for xyz in [(0,1,0),(10,1,0),(-1875001,1,0),(0,-1,0)]:
 before=bytes(entries)+bytes(cache)
 eq(insert(C.byref(cache),coords(*xyz),empty,99),None,('rejected insertion',xyz))
 eq(bytes(entries)+bytes(cache),before,'insertion failure atomicity')
eq(find(C.byref(cache),coords(10,1,0)),None,'missing lookup')
for idx,affected in [(0,[0,1,3,5]),(4095,[0,2,4,6]),(1+16*(1+16*1),[0])]:
 for e in entries:e.dirty=0
 eq(edit(C.byref(cache),C.byref(entries[0]),idx,1),0,'edit')
 eq([i for i,e in enumerate(entries) if e.dirty],affected,('dirty propagation',idx))
 revision=entries[0].revision
 for e in entries:e.dirty=0
 eq(edit(C.byref(cache),C.byref(entries[0]),idx,1),0,'idempotent edit')
 eq(entries[0].revision,revision,'idempotent revision')
 eq([e.dirty for e in entries],[0]*8,'idempotent no invalidation')
for xyz, expected_status, expected_value in [((0,16,0),0,1),((-1,16,0),0,0),((16,16,0),0,0),
                                            ((100,16,0),1,123),((0,-1,0),2,123),
                                            ((30000000,16,0),2,123),((-30000001,16,0),2,123)]:
 value=C.c_uint16(123)
 eq(lookup(C.byref(cache),coords(*xyz),C.byref(value)),expected_status,('lookup status',xyz))
 eq(value.value,expected_value,('lookup value',xyz))
# Actual arrival invalidation, including duplicate/full failure isolation.
arrival_entries=(Entry*2)();arrival=Cache();arrival_blocks=[section(),section()]
init(C.byref(arrival),arrival_entries,2)
insert(C.byref(arrival),coords(0,1,0),arrival_blocks[0],1)
arrival_entries[0].dirty=0
insert(C.byref(arrival),coords(1,1,0),arrival_blocks[1],2)
eq(arrival_entries[0].dirty,1,'arrival invalidates existing neighbor')
for idx,b in [(4096,1),(0,8),(2**64-1,1)]:
 before=bytes(entries)+bytes(sections[0])
 eq(edit(C.byref(cache),C.byref(entries[0]),idx,b),-1,'invalid edit')
 eq(bytes(entries)+bytes(sections[0]),before,'edit failure atomicity')
foreign=Entry();eq(edit(C.byref(cache),C.byref(foreign),0,1),-1,'foreign entry')
entries[0].revision=2**64-1
before=bytes(entries)+bytes(sections[0])
eq(edit(C.byref(cache),C.byref(entries[0]),10,2),-1,'revision overflow')
eq(bytes(entries)+bytes(sections[0]),before,'overflow atomicity')
print(f'PASS: {checks} chunk/cache/mesh reference assertions')
