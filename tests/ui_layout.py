"""Independent inventory geometry and centered pointer mapping tests."""
import ctypes as C
import math,random,sys
lib=C.CDLL(sys.argv[1]);I=C.c_int64;P=C.c_void_p;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
pos=bind('inventory_ui_position',[I,I,P]);hit=bind('inventory_ui_slot',[I,I,I]);pointer=bind('inventory_ui_pointer',[P,I,I,P]);metrics=bind('inventory_ui_metrics',[P,P])
def check(v,m):
 global checks
 checks+=1;assert v,m

def xy(i,page):
 if page==1:return (32+i*64,330) if i<9 else None
 if i<36:return 160+(i%9)*36,88 if i<9 else 204-(i//9-1)*36
 if i<40:return 340+((i-36)%2)*36,334-((i-36)//2)*36
 return 448,316
for page in (0,1):
 size=32 if page==0 else 56
 for i in range(41):
  out=(I*3)(-5,-6,999);want=xy(i,page)
  if want is None:check(pos(i,page,out)==-1 and tuple(out)==(-5,-6,999),'invalid position');continue
  check(pos(i,page,out)==0 and tuple(out)==(*want,999),'slot position/canary')
  x,y=want
  for dx,dy in [(0,0),(size-1,0),(0,size-1),(size-1,size-1),(size//2,size//2)]:check(hit(x+dx,y+dy,page)==i,'slot edge')
  for dx,dy in [(-1,0),(size,0),(0,-1),(0,size)]:check(hit(x+dx,y+dy,page)==-1,'slot gap')
rng=random.Random(211)
for page in (0,1):
 for _ in range(2500):
  x,y=rng.randrange(-10,650),rng.randrange(-10,490);want=-1
  for i in range(41 if page==0 else 9):
   sx,sy=xy(i,page);size=32 if page==0 else 56
   if sx<=x<sx+size and sy<=y<sy+size:want=i;break
  check(hit(x,y,page)==want,'random hit')
for w,h in [(800,600),(1600,900),(600,900),(1920,1080),(640,480),(1280,960),(1000,600)]:
 dims=(C.c_uint32*2)(w,h);out=(C.c_float*4)(0,0,0,999);scale=min(w/640,h/480);ox=(w-640*scale)/2;oy=(h-480*scale)/2
 check(metrics(dims,out)==0 and abs(out[0]-scale)<1e-5 and abs(out[1]-ox)<1e-4 and abs(out[2]-oy)<1e-4 and out[3]==999,'uniform scale')
 for _ in range(500):
  x,y=rng.randrange(-1,w+1),rng.randrange(-1,h+1);vx=(x-ox)/scale;vy=(h-1-y-oy)/scale;valid=0<=x<w and 0<=y<h and 0<=vx<640 and 0<=vy<480;dst=(I*3)(-5,-6,999);got=pointer(dims,x,y,dst)
  if valid:check(got==0 and abs(dst[0]-math.floor(vx+1e-5))<=1 and abs(dst[1]-math.floor(vy+1e-5))<=1 and dst[2]==999,'pointer inverse')
  else:check(got==-1 and tuple(dst)==(-5,-6,999),'letterbox pointer rejection')
for w,h in [(0,600),(800,0),(0xffffffff,600)]:
 out=(C.c_float*3)(1,2,3);check(metrics((C.c_uint32*2)(w,h),out)==-1 and tuple(out)==(1,2,3),'invalid dimensions')
print(f'PASS: {checks} layout and pointer assertions')
