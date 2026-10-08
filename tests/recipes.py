"""Independent shaped recipe matching in both grid sizes and registry metadata."""
import ctypes as C
import itertools,random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
match=bind('recipe_match',[P,I,P]);info=bind('recipe_info',[I,P]);missing=bind('recipe_missing',[P,I,P]);invinit=bind('inventory36_init',[P])
recipes=[(1,1,[(5,)],8,4,0),(1,2,[(8,),(8,)],9,4,0),(3,3,[(8,8,8),(0,9,0),(0,9,0)],10,1,60),(3,3,[(1,1,1),(0,9,0),(0,9,0)],11,1,132)]
def check(v,m):
 global checks
 checks+=1;assert v,m

def expected(items,width):
 occupied=[(i%width,i//width) for i,v in enumerate(items) if v]
 if not occupied:return 0,None
 x0=min(x for x,y in occupied);x1=max(x for x,y in occupied);y0=min(y for x,y in occupied);y1=max(y for x,y in occupied)
 pattern=[tuple(items[y*width+x] for x in range(x0,x1+1)) for y in range(y0,y1+1)]
 for index,(w,h,shape,item,count,dur) in enumerate(recipes):
  if (x1-x0+1,y1-y0+1)==(w,h) and pattern==shape:return item|(count<<16)|(dur<<32),index
 return 0,None

def exercise(items,width):
 grid=(C.c_ubyte*(len(items)*8+16))()
 for i,item in enumerate(items):struct.pack_into('<HHHH',grid,i*8,item,(1 if item>=10 else 3) if item else 0,(60 if item==10 else 132 if item==11 else 0),0)
 C.memset(C.byref(grid,len(items)*8),0xa5,16);index=(C.c_uint32*2)(999,888);before=bytes(grid);result=match(grid,width,index);want,which=expected(items,width)
 check(result==want,'independent recipe pattern');check(index[0]==(999 if which is None else which) and index[1]==888,'index output/canary');check(bytes(grid)==before,'immutable input')
for items in itertools.product([0,1,5,8,9],repeat=4):exercise(items,2)
for width in (2,3):
 for x in range(width):
  for y in range(width):
   items=[0]*(width*width);items[y*width+x]=5;exercise(items,width)
 for x in range(width):
  for y in range(width-1):
   items=[0]*(width*width);items[y*width+x]=items[(y+1)*width+x]=8;exercise(items,width)
for w,h,shape,*_ in recipes[2:]:
 items=[v for row in shape for v in row];exercise(items,3)
 for i in range(9):
  changed=items.copy();changed[i]=5;exercise(changed,3)
rng=random.Random(611)
for _ in range(4000):exercise([rng.choice([0,0,1,5,8,9,10,11]) for _ in range(9)],3)
for index,(w,h,shape,item,count,dur) in enumerate(recipes):
 out=(C.c_ubyte*48)();C.memset(out,0xa5,48);check(info(index,out)==0,'recipe info');pattern=[0]*9
 for y,row in enumerate(shape):
  for x,v in enumerate(row):pattern[y*3+x]=v
 expectedbytes=struct.pack('<IIQ9H6x',w,h,item|(count<<16)|(dur<<32),*pattern)
 check(bytes(out[:40])==expectedbytes and bytes(out[40:])==b'\xa5'*8,'immutable registry layout')
for width in (0,1,4,-1):
 index=(C.c_uint32*2)(999,888);check(match((C.c_ubyte*72)(),width,index)==-1 and tuple(index)==(999,888),'invalid width')
for offset,value in [(0,7),(2,65),(4,1),(6,1)]:
 grid=(C.c_ubyte*72)();struct.pack_into('<HHHH',grid,0,5,1,0,0);struct.pack_into('<H',grid,offset,value);index=(C.c_uint32*2)(999,888);before=bytes(grid);check(match(grid,3,index)==-1 and tuple(index)==(999,888) and bytes(grid)==before,'invalid item records')
out=(C.c_ubyte*40)();C.memset(out,0xa5,40);before=bytes(out);check(info(4,out)==-1 and bytes(out)==before,'invalid recipe metadata')
# Missing ingredient counts come from the immutable shapes, include grid,
# exclude held cursor, preserve live state, and retain stable ingredient order.
for _ in range(2000):
 state=(C.c_ubyte*336)();invinit(state)
 for offset in list(range(0,288,8))+[296,304,312,320,328]:
  item=rng.choice([0,1,5,8,9,10,11]);struct.pack_into('<HHHH',state,offset,item,(1 if item>=10 else rng.randrange(1,65)) if item else 0,60 if item==10 else 132 if item==11 else 0,0)
 index=rng.randrange(4);shape=recipes[index][2];order=[];needed={}
 for row in shape:
  for item in row:
   if item:
    if item not in needed:order.append(item);needed[item]=0
    needed[item]+=1
 for offset in list(range(0,288,8))+[304,312,320,328]:
  item,count=struct.unpack_from('<HH',state,offset)
  if item in needed:needed[item]=max(0,needed[item]-count)
 expected=[0]*4
 for i,item in enumerate(order):expected[i*2:i*2+2]=[item,needed[item]]
 result=(C.c_uint32*5)(999,999,999,999,888);before=bytes(state)
 check(missing(state,index,result)==sum(needed.values()) and list(result)==expected+[888] and bytes(state)==before,'missing amounts/ownership/canary')
state=(C.c_ubyte*336)();invinit(state);struct.pack_into('<HHHH',state,296,5,8,0,0);struct.pack_into('<HHHH',state,8,0,0,0,0)
result=(C.c_uint32*4)(999,999,999,999);check(missing(state,0,result)==1 and list(result)==[5,1,0,0],'held cursor not an ingredient')
for index in (-1,4):
 before=bytes(result);check(missing(state,index,result)==-1 and bytes(result)==before,'invalid missing recipe')
struct.pack_into('<I',state,292,2);before=bytes(result);check(missing(state,0,result)==-1 and bytes(result)==before,'invalid missing state')
print(f'PASS: {checks} immutable shaped recipe registry assertions')
