"""Independent face expansion, winding, color and failure tests."""
import ctypes as C
import struct
import sys
lib=C.CDLL(sys.argv[1])
class Target(C.Structure):
    _fields_=[('buffer',C.c_void_p),('capacity',C.c_uint64),('x',C.c_int32),('y',C.c_int32),('z',C.c_int32)]
f=lib.faces_expand;f.argtypes=[C.c_void_p,C.c_uint64,C.POINTER(Target)];f.restype=C.c_int64
checks=0
def eq(a,b,label):
    global checks
    checks+=1
    if a!=b:raise AssertionError((label,a,b))
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
quads=[[(0,0,0),(0,0,1),(0,1,1),(0,1,0)],
       [(1,0,1),(1,0,0),(1,1,0),(1,1,1)],
       [(0,0,1),(0,0,0),(1,0,0),(1,0,1)],
       [(0,1,0),(0,1,1),(1,1,1),(1,1,0)],
       [(1,0,0),(0,0,0),(0,1,0),(1,1,0)],
       [(0,0,1),(1,0,1),(1,1,1),(0,1,1)]]
colors=[(0,0,0),(.55,.55,.58),(.48,.29,.16),(.24,.65,.22),(.86,.77,.48),(.48,.32,.17),(.18,.48,.17),(.24,.24,.27)]
shading=[.7,.8,.45,1,.6,.85]
normals=[(-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1)]
records=b''.join(struct.pack('<BBBBHH',15,7,0,d,b,0) for b in range(1,8) for d in range(6))
src=C.create_string_buffer(records)
vertex_count=len(records)//8*6
raw=(C.c_ubyte*(vertex_count*24+32))(*([0xA5]*(vertex_count*24+32)))
target=Target(C.addressof(raw)+16,vertex_count,-100,200,300)
eq(f(src,42,C.byref(target)),vertex_count,'vertex count')
actual=list(struct.iter_unpack('<ffffff',bytes(raw[16:-16])))
expected=[]
for b in range(1,8):
 for d in range(6):
  rgb=tuple(f32(f32(v)*f32(shading[d])) for v in colors[b])
  face_vertices=[]
  for corner in (0,1,2,0,2,3):
   x,y,z=quads[d][corner]
   face_vertices.append((float(15-100+x),float(7+200+y),float(300+z),*rgb))
  expected.extend(face_vertices)
  for t in (0,3):
   a,v,w=[p[:3] for p in face_vertices[t:t+3]]
   u=[v[i]-a[i] for i in range(3)];q=[w[i]-a[i] for i in range(3)]
   cross=(u[1]*q[2]-u[2]*q[1],u[2]*q[0]-u[0]*q[2],u[0]*q[1]-u[1]*q[0])
   eq(cross,normals[d],('outward winding',b,d,t))
for i,(a,e) in enumerate(zip(actual,expected)):eq(a,e,('vertex',i))
eq(bytes(raw[:16])+bytes(raw[-16:]),bytes([0xA5]*32),'canaries')
before=bytes(raw);target.capacity=vertex_count-1
eq(f(src,42,C.byref(target)),-2,'capacity error');eq(bytes(raw),before,'capacity atomicity')
target.capacity=vertex_count
for record in [struct.pack('<BBBBHH',16,0,0,0,1,0),struct.pack('<BBBBHH',0,16,0,0,1,0),
               struct.pack('<BBBBHH',0,0,16,0,1,0),struct.pack('<BBBBHH',0,0,0,6,1,0),
               struct.pack('<BBBBHH',0,0,0,0,0,0),struct.pack('<BBBBHH',0,0,0,0,8,0),
               struct.pack('<BBBBHH',0,0,0,0,1,1)]:
 eq(f(C.create_string_buffer(record),1,C.byref(target)),-1,'invalid record')
 eq(bytes(raw),before,'invalid record atomicity')
for axis in ('x','y','z'):
 old=getattr(target,axis);setattr(target,axis,1048577)
 eq(f(src,42,C.byref(target)),-1,'origin bound');eq(bytes(raw),before,'origin failure atomicity')
 setattr(target,axis,old)
eq(f(src,24577,C.byref(target)),-1,'face count bound')
eq(f(None,0,C.byref(target)),0,'empty expansion')
print(f'PASS: {checks} vertex expansion reference assertions')
