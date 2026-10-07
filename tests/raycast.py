"""Independent voxel traversal and ray clipping reference tests."""
import ctypes as C
import math
import random
import sys
lib=C.CDLL(sys.argv[1]);U,S,P=C.c_uint64,C.c_int64,C.c_void_p
class Ray(C.Structure):_fields_=[('origin',C.c_double*3),('direction',C.c_double*3),('reach',C.c_double)]
class Hit(C.Structure):_fields_=[('cell',S*3),('face',S),('distance',C.c_double),('previous',S*3),('block',U)]
class Cache(C.Structure):_fields_=[('entries',P),('capacity',U),('count',U)]
def bind(name,args,result=S):
 f=getattr(lib,name);f.argtypes=args;f.restype=result;return f
init=bind('cache_init',[P,P,U]);insert=bind('cache_insert',[P,P,P,U],P)
cast=bind('world_raycast',[P,C.POINTER(Ray),C.POINTER(Hit)])
clip=bind('ray_box_interval',[C.POINTER(Ray),P,P])
camera_init=bind('camera_init',[P]);camera_ray=bind('camera_ray',[P,P,C.POINTER(Ray)])
checks=0
def eq(a,b,label):
 global checks
 checks+=1
 assert a==b,(label,a,b)
rng=random.Random(905)
cache=Cache();entries=(C.c_ubyte*(64*8))();init(C.byref(cache),entries,8)
blocks={};buffers=[]
for sx in (-1,0):
 for sy in (0,1):
  for sz in (-1,0):
   buf=(C.c_uint16*4096)()
   for _ in range(140):buf[rng.randrange(4096)]=rng.randrange(1,8)
   coords=(S*3)(sx,sy,sz);insert(C.byref(cache),coords,buf,len(buffers)+1)
   blocks[(sx,sy,sz)]=buf;buffers.append(buf)
# Reference visits with integer cells and explicit X/Y/Z minimum tie priority.
def reference(ray):
 o=list(ray.origin);d=list(ray.direction);norm=math.sqrt(sum(x*x for x in d));d=[x/norm for x in d]
 cell=[math.floor(x) for x in o];prev=cell[:];distance=0.0;face=6
 step=[1 if x>0 else -1 if x<0 else 0 for x in d]
 maximum=[((cell[a]+1-o[a])/d[a] if d[a]>0 else (cell[a]-o[a])/d[a] if d[a]<0 else math.inf) for a in range(3)]
 delta=[abs(1/x) if x else math.inf for x in d]
 for _ in range(2048):
  x,y,z=cell
  if not (-30000000<=x<30000000 and 0<=y<256 and -30000000<=z<30000000):return 3,None
  b=blocks.get((x//16,y//16,z//16))
  if b is None:return 2,None
  block=b[x%16+16*(z%16+16*(y%16))]
  if block:return 1,(tuple(cell),face,distance,tuple(prev),block)
  axis=min(range(3),key=lambda a:maximum[a])
  distance=maximum[axis]
  if distance>ray.reach:return 0,None
  prev=cell[:];cell[axis]+=step[axis];face=axis*2+(0 if step[axis]>0 else 1);maximum[axis]+=delta[axis]
 raise AssertionError('unbounded reference')
def verify(ray):
 hit=Hit();C.memset(C.byref(hit),0xA5,C.sizeof(hit));before=bytes(hit)
 status,result=reference(ray);eq(cast(C.byref(cache),C.byref(ray),C.byref(hit)),status,'cast status')
 if result:
  cell,face,distance,prev,block=result
  eq(tuple(hit.cell),cell,'hit cell');eq(hit.face,face,'entry face');eq(tuple(hit.previous),prev,'previous cell');eq(hit.block,block,'block')
  eq(math.isclose(hit.distance,distance,rel_tol=1e-12,abs_tol=1e-12),True,'distance')
 else:eq(bytes(hit),before,'miss/error preserves hit')
for _ in range(2500):
 o=[rng.uniform(-15.9,15.9),rng.uniform(.1,31.9),rng.uniform(-15.9,15.9)]
 d=[rng.uniform(-1,1) for _ in range(3)]
 verify(Ray((C.c_double*3)(*o),(C.c_double*3)(*d),rng.uniform(0,30)))
for o,d,r in [((0,1,0),(1,0,0),0),((0,1,0),(-1,0,0),5),((0,1,0),(1,1,1),5),
              ((0,0,0),(0,-1,0),5),((29999999.5,1,0),(1,0,0),5),((-16,1,-16),(0,1,0),256)]:
 verify(Ray((C.c_double*3)(*o),(C.c_double*3)(*d),r))
# Explicit inside-solid and tie vectors, independent of random fixture layout.
buffers[0][1+16*(1+16*1)]=1
verify(Ray((C.c_double*3)(-14.5,1.5,-14.5),(C.c_double*3)(1,0,0),5))
for ray in [Ray((C.c_double*3)(math.nan,1,0),(C.c_double*3)(1,0,0),5),
            Ray((C.c_double*3)(0,1,0),(C.c_double*3)(0,0,0),5),
            Ray((C.c_double*3)(0,1,0),(C.c_double*3)(2,0,0),5),
            Ray((C.c_double*3)(0,1,0),(C.c_double*3)(1,0,0),math.inf),
            Ray((C.c_double*3)(0,1,0),(C.c_double*3)(1,0,0),-1)]:
 hit=Hit();C.memset(C.byref(hit),0xA5,C.sizeof(hit));before=bytes(hit)
 eq(cast(C.byref(cache),C.byref(ray),C.byref(hit)),-1,'invalid ray');eq(bytes(hit),before,'invalid atomicity')
box=(C.c_double*6)(0,0,0,16,16,16)
for _ in range(1000):
 origin=[rng.uniform(-20,30) for _ in range(3)];direction=[rng.uniform(-1,1) for _ in range(3)]
 ray=Ray((C.c_double*3)(*origin),(C.c_double*3)(*direction),50)
 lo,hi=0,50
 for a in range(3):
  t=sorted([(0-origin[a])/direction[a],(16-origin[a])/direction[a]])
  lo=max(lo,t[0]);hi=min(hi,t[1])
 out=(C.c_double*2)(123,456);result=clip(C.byref(ray),box,out)
 eq(result,int(lo<=hi),'box intersection')
 if result:eq(abs(out[0]-lo)<1e-12 and abs(out[1]-hi)<1e-12,True,'box interval')
 else:eq(tuple(out),(123,456),'box miss preserves output')
for origin,expected in [((1,1,1),1),((-1,1,1),0)]:
 ray=Ray((C.c_double*3)(*origin),(C.c_double*3)(0,0,0),5);out=(C.c_double*2)(123,456)
 eq(clip(C.byref(ray),box,out),expected,'parallel slabs')
invalid_box=(C.c_double*6)(0,0,math.nan,16,16,16)
ray=Ray((C.c_double*3)(-100,0,0),(C.c_double*3)(0,1,0),5);out=(C.c_double*2)(123,456)
eq(clip(C.byref(ray),invalid_box,out),-1,'validate every slab before miss')
camera=(C.c_float*8)();camera_init(camera)
ray=Ray();screen=(U*4)(400,300,800,600)
eq(camera_ray(camera,screen,C.byref(ray)),1,'camera ray')
dot=sum(ray.direction[i]*(ray.origin[i]-[16,72,16][i]) for i in range(3))
eq(abs(dot+100)<1e-4,True,'camera ray starts at near depth')
eq(abs(sum(x*x for x in ray.direction)-1)<1e-6,True,'camera ray unit direction')
for screen,status in [((800,0,800,600),0),((0,0,0,600),-1),((0,0,800,16385),-1)]:
 before=bytes(ray);eq(camera_ray(camera,(U*4)(*screen),C.byref(ray)),status,'screen validation');eq(bytes(ray),before,'screen failure atomicity')
print(f'PASS: {checks} ray traversal/clipping/picking assertions')
