"""Independent container ownership/interaction models, pairing and fixed wire codec."""
import ctypes as C
from collections import Counter
import random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('container_init',[P,P,I]);valid=bind('container_valid',[P]);click=bind('container_click',[P,P,I,I]);quick=bind('container_quick',[P,P,I,I]);clear=bind('container_clear',[P,P]);pairvalid=bind('container_pair_valid',[P]);pairclick=bind('container_pair_click',[P,P,I,I]);pairquick=bind('container_pair_quick',[P,P,I,I]);encode=bind('container_encode',[P,U,P,U]);decode=bind('container_decode',[P,U,P,U]);invinit=bind('inventory36_init',[P]);invvalid=bind('inventory36_valid',[P])
chest=(C.c_ubyte*264)();other=(C.c_ubyte*264)();inv=(C.c_ubyte*320)();empty=(0,0,0,0)
def check(v,m):
 global checks
 checks+=1;assert v,m

def fresh(kind=1):
 C.memset(chest,0xa5,264);C.memset(other,0xa5,264);C.memset(inv,0xa5,320)
 check(init(chest,(I*3)(-1,100,-16),kind)==0,'init');check(init(other,(I*3)(0,100,-16),1)==0,'second init');invinit(inv)
def record(buffer,offset):return struct.unpack_from('<HHHH',buffer,offset)
def put(buffer,offset,slot):struct.pack_into('<HHHH',buffer,offset,*slot)
def snap():return bytes(chest),bytes(other),bytes(inv)
def canaries():return bytes(chest[248:])==b'\xa5'*16 and bytes(other[248:])==b'\xa5'*16 and bytes(inv[304:])==b'\xa5'*16
fresh();check(valid(chest)==0 and bytes(chest[32:248])==bytes(216),'empty validation')
for kind in (0,3,-1):
 before=snap();check(init(chest,(I*3)(0,100,0),kind)==-1 and snap()==before,'invalid kind init')
for position in [(-30000001,0,0),(30000000,0,0),(0,-1,0),(0,256,0),(0,0,30000000)]:
 before=snap();check(init(chest,(I*3)(*position),1)==-1 and snap()==before,'invalid position init')
# Full-stack and right split retain complete records, including tool wear.
put(chest,32,(5,63,0,0));check(click(chest,inv,0,1)==1 and record(chest,32)==(5,31,0,0) and record(inv,296)==(5,32,0,0),'right half')
check(click(chest,inv,1,1)==1 and record(chest,40)==(5,1,0,0),'place one')
check(click(chest,inv,0,0)==1 and record(chest,32)==(5,62,0,0) and record(inv,296)==empty,'merge cursor')
put(chest,48,(11,1,17,0));check(click(chest,inv,2,0)==1 and record(inv,296)==(11,1,17,0),'tool pickup');check(click(chest,inv,26,1)==1 and record(chest,240)==(11,1,17,0),'tool one-place')
check(quick(chest,inv,26,0)==1 and any(record(inv,i*8)==(11,1,17,0) for i in range(36)),'tool quick transfer')
# Partial destination capacity preserves the remainder.
fresh()
for i in range(36):put(inv,i*8,(8,64,0,0))
put(inv,0,(8,60,0,0));put(chest,32,(8,10,0,0));check(quick(chest,inv,0,0)==1 and record(chest,32)==(8,6,0,0) and record(inv,0)==(8,64,0,0),'partial quick')
before=snap();check(quick(chest,inv,0,0)==0 and snap()==before,'full quick no-op');check(clear(chest,inv)==0 and snap()==before,'clear atomic full')
put(inv,8,empty);check(clear(chest,inv)==1 and record(chest,32)==empty,'clear contents')
# table grid accepts only nine cells and must have zero trailing slots.
fresh(2);check(click(chest,inv,8,0)==0,'table ninth cell');before=snap();check(click(chest,inv,9,0)==-1 and snap()==before,'table limit');put(chest,104,(5,1,0,0));check(valid(chest)==-1,'table padding')
fresh();pair=(U*2)(C.addressof(chest),C.addressof(other));check(pairvalid(pair)==0,'adjacent pair')
put(other,240,(9,6,0,0));check(pairclick(pair,inv,53,0)==1 and record(inv,296)==(9,6,0,0),'paired last slot');check(pairclick(pair,inv,27,0)==1 and record(other,32)==(9,6,0,0),'paired first right cell')
for i in range(27):put(chest,32+i*8,(8,64,0,0))
put(inv,16,(8,10,0,0));check(pairquick(pair,inv,2,1)==1 and record(other,40)==(8,10,0,0),'second half overflow');check(pairquick(pair,inv,28,0)==1 and record(other,40)==empty,'paired quick return')
for xyz in [(0,101,-16),(1,100,-16),(0,100,-15),(-1,100,-16)]:
 init(other,(I*3)(*xyz),1);check(pairvalid(pair)==-1,'invalid pair separation/duplicate location')
init(other,(I*3)(-1,100,-15),1);check(pairvalid(pair)==0,'Z adjacent');alias=(U*2)(C.addressof(chest),C.addressof(chest));check(pairvalid(alias)==-1,'pair alias')
# Invalid slot/action/direction and malformed records never mutate either owner.
fresh()
for fn,args in [(click,(27,0)),(click,(0,2)),(quick,(27,0)),(quick,(36,1)),(quick,(0,2))]:
 before=snap();check(fn(chest,inv,*args)==-1 and snap()==before,'invalid transaction')
for offset,value in [(24,0),(28,1),(32,7),(34,65),(36,1),(38,1)]:
 fresh();put(chest,32,(5,1,0,0));struct.pack_into('<H',chest,offset,value);before=snap();check(valid(chest)==-1 and click(chest,inv,0,0)==-1 and quick(chest,inv,0,0)==-1 and clear(chest,inv)==-1 and snap()==before,'malformed transactions')
# Independently model mouse and partial quick operations across bag + chest.
def modelclick(cell,cursor,action):
 if action==0:
  if not cursor[0]:return empty,cell
  if cell[0]==cursor[0] and cursor[0]<10:
   n=min(cursor[1],64-cell[1]);return (cell[0],cell[1]+n,0,0),((cursor[0],cursor[1]-n,0,0) if cursor[1]>n else empty)
  return cursor,cell
 if not cursor[0]:
  if not cell[0]:return cell,cursor
  n=(cell[1]+1)//2;return ((cell[0],cell[1]-n,cell[2],0) if cell[1]>n else empty),(cell[0],n,cell[2],0)
 if cell[0] and (cell[0]!=cursor[0] or cursor[0]>=10 or cell[1]==64):return cell,cursor
 dst=(cursor[0],cell[1]+1 if cell[0] else 1,cursor[2],0)
 return dst,((cursor[0],cursor[1]-1,cursor[2],0) if cursor[1]>1 else empty)
def move(source,dest):
 if not source[0]:return source,dest
 remaining=source[1];dest=dest.copy()
 for phase in (0,1):
  for i,slot in enumerate(dest):
   if remaining==0:break
   if phase==0:
    if source[0]>=10 or slot[0]!=source[0]:continue
    n=min(64-slot[1],remaining);dest[i]=(slot[0],slot[1]+n,slot[2],0)
   else:
    if slot[0]:continue
    n=min(1 if source[0]>=10 else 64,remaining);dest[i]=(source[0],n,source[2],0)
   remaining-=n
 return ((source[0],remaining,source[2],0) if remaining else empty),dest
fresh();rng=random.Random(5411)
for i in range(27):
 item=rng.choice([0,1,5,8,9,10,11]);put(chest,32+i*8,empty if item==0 else (item,1 if item>=10 else rng.randrange(1,65),rng.randrange(1,61) if item==10 else rng.randrange(1,133) if item==11 else 0,0))
for i in range(36):
 item=rng.choice([0,2,5,8,10,11]);put(inv,i*8,empty if item==0 else (item,1 if item>=10 else rng.randrange(1,65),60 if item==10 else 132 if item==11 else 0,0))
def totals():
 result=Counter()
 for slot in [record(chest,32+i*8) for i in range(27)]+[record(inv,i*8) for i in range(36)]+[record(inv,296)]:
  if slot[0]:result[(slot[0],slot[2])]+=slot[1]
 return result
initial=totals()
for _ in range(4000):
 cells=[record(chest,32+i*8) for i in range(27)];bag=[record(inv,i*8) for i in range(36)];cursor=record(inv,296);action=rng.randrange(3)
 if action<2:
  index=rng.randrange(27);old=cells[index],cursor;cells[index],cursor=modelclick(*old,action);expected=int(old!=(cells[index],cursor));got=click(chest,inv,index,action)
 else:
  direction=rng.randrange(2);index=rng.randrange(27 if direction==0 else 36)
  if direction==0:old=cells[index];cells[index],bag=move(old,bag);expected=int(old!=cells[index])
  else:old=bag[index];bag[index],cells=move(old,cells);expected=int(old!=bag[index])
  got=quick(chest,inv,index,direction)
 check(got==expected,f'random return action={action} index={index} got={got} want={expected} old={old} cursor={cursor}')
 check([record(chest,32+i*8) for i in range(27)]==cells and [record(inv,i*8) for i in range(36)]==bag and record(inv,296)==cursor,'random independent model')
 check(totals()==initial and valid(chest)==0 and invvalid(inv)==0 and canaries(),'random conservation/canary')
# Exact independently encoded standalone container blob.
fresh();put(chest,32,(11,1,17,0));put(chest,240,(8,64,0,0));out=(C.c_ubyte*304)();C.memset(out,0xa5,304);seed=0xffffffffffffffff
check(encode(chest,seed,out,288)==288,'encode length')
def repaired(data):
 data=bytearray(data);h=0xcbf29ce484222325
 for i,b in enumerate(data):h=((h^(0 if 24<=i<32 else b))*0x100000001b3)&0xffffffffffffffff
 struct.pack_into('<Q',data,24,h);return bytes(data)
header=struct.pack('<8sIIQQQ',b'VXACONT\0',1,1,seed,0,0);expected=repaired(header+bytes(chest[:248]));check(bytes(out[:288])==expected and bytes(out[288:])==b'\xa5'*16,'exact wire/canary')
saved=bytes(chest);init(chest,(I*3)(1,1,1),1);inputbuf=C.create_string_buffer(expected);check(decode(inputbuf,288,chest,seed)==0 and bytes(chest)==saved and inputbuf.raw[:288]==expected,'roundtrip immutable input')
for i in range(288):
 b=bytearray(expected);b[i]^=0x80;before=bytes(chest);check(decode(C.create_string_buffer(bytes(b)),288,chest,seed)==-1 and bytes(chest)==before,'checksum atomic')
for offset,value,fmt in [(8,2,'I'),(12,2,'I'),(16,1,'Q'),(32,1,'Q'),(40,30000000,'q'),(48,-1,'q'),(64,3,'I'),(68,1,'I'),(72,7,'H'),(74,2,'H'),(76,133,'H'),(78,1,'H')]:
 b=bytearray(expected);struct.pack_into('<'+fmt,b,offset,value);before=bytes(chest);check(decode(C.create_string_buffer(repaired(b)),288,chest,seed)==-1 and bytes(chest)==before,'repaired malformed blob')
for n in [0,39,287,289]:
 before=bytes(chest);check(decode(inputbuf,n,chest,seed)==-1 and bytes(chest)==before,'exact length')
before=bytes(out);check(encode(chest,seed,out,287)==-2 and bytes(out)==before,'encode capacity atomic')
check(canaries(),'final canaries')
print(f'PASS: {checks} container interaction, pairing, conservation and codec assertions')
