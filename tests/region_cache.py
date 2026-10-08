"""Independent LRU and dirty ownership model for bounded terrain cache."""
import ctypes as C
import random
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;SIZE=131264

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('region_cache_init',[P,P]);publish=bind('region_cache_publish',[P,U,P,U]);find=bind('region_cache_find',[P,P]);reserve=bind('region_cache_reserve',[P]);dirty=bind('region_cache_dirty',[P,U]);clean=bind('region_cache_clean',[P,U,U]);evict=bind('region_cache_evict',[P,U]);get=bind('region_cache_get',[P,U]);ri=bind('region_init',[P,P]);gen=bind('region_generate',[P,U,U]);edit=bind('region_edit',[P,P,U])
rng=random.Random(921);checks=0
for capacity in (1,2,8,64):
 pool=[C.create_string_buffer(SIZE+32) for _ in range(capacity)]
 entries=(U*(capacity*4))()
 for i,buf in enumerate(pool):entries[i*4]=C.addressof(buf);C.memset(C.addressof(buf)+SIZE,0xa5,32)
 ctx=(U*5)();cfg=(U*4)(42,1,capacity,C.addressof(entries));assert init(ctx,cfg)==0
 staged=C.create_string_buffer(SIZE);key=(I*3)();rcfg=(I*4)();clock=0;model=[None]*capacity
 for step in range(350):
  action=rng.randrange(5);slot=rng.randrange(capacity)
  before=bytes(ctx)+bytes(entries)+b''.join(buf.raw for buf in pool)
  if action==0:
   ident=(rng.randrange(-9,10),rng.randrange(-9,10),rng.randrange(-16,48));rcfg[:]=(42,*ident)
   assert ri(staged,rcfg)==0;persisted=rng.randrange(2)
   duplicate=any(row is not None and row['key']==ident for row in model)
   blocked=model[slot] is not None and model[slot]['saved']!=model[slot]['rev']
   want=-1 if duplicate else -2 if blocked else 1
   assert publish(ctx,slot,staged,persisted)==want
   if want==1:
    clock+=1;model[slot]={'key':ident,'rev':0,'saved':0 if persisted else -1,'age':clock}
   else:assert bytes(ctx)+bytes(entries)+b''.join(buf.raw for buf in pool)==before
  elif action==1:
   ident=model[slot]['key'] if model[slot] is not None else (23,24,4);key[:]=ident
   want=next((i for i,row in enumerate(model) if row is not None and row['key']==ident),-2)
   assert find(ctx,key)==want
   if want>=0:clock+=1;model[want]['age']=clock
   else:assert bytes(ctx)+bytes(entries)+b''.join(buf.raw for buf in pool)==before
  elif action==2:
   want=next((i for i,row in enumerate(model) if row is None),None)
   if want is None:
    victim=min(range(capacity),key=lambda i:model[i]['age'])
    want=-2 if model[victim]['saved']!=model[victim]['rev'] else victim
   assert reserve(ctx)==want
  elif action==3:
   row=model[slot];revision=0 if row is None else row['rev']
   assert clean(ctx,slot,revision)==(-1 if row is None else 0)
   if row is not None:row['saved']=revision
  else:
   row=model[slot];want=0 if row is None else -2 if row['rev']!=row['saved'] else 1
   assert evict(ctx,slot)==want
   if want==1:model[slot]=None
  assert ctx[4]==clock
  for i,row in enumerate(model):
   assert get(ctx,i)==(-2 if row is None else C.addressof(pool[i]))
   assert dirty(ctx,i)==int(row is not None and row['rev']!=row['saved'])
   assert pool[i].raw[SIZE:]==b'\xa5'*32
  checks+=1
# Actual terrain revision changes require a matching new persistence checkpoint.
capacity=1;buf=C.create_string_buffer(SIZE);entries=(U*4)(C.addressof(buf),0,0,0);ctx=(U*5)();cfg=(U*4)(42,1,1,C.addressof(entries));assert init(ctx,cfg)==0
rcfg[:]=(42,0,0,4);assert ri(staged,rcfg)==0 and gen(staged,0,0)==1
assert publish(ctx,0,staged,1)==1 and dirty(ctx,0)==0
old=entries[2];xyz=(I*3)(0,70,0);assert edit(buf,xyz,5)==1 and dirty(ctx,0)==1
assert clean(ctx,0,old)==-1 and dirty(ctx,0)==1 and evict(ctx,0)==-2 and reserve(ctx)==-2
assert clean(ctx,0,old+1)==0 and dirty(ctx,0)==0
# Incompatible/corrupt staged input never replaces resident state or its age.
before=bytes(ctx)+bytes(entries)+buf.raw
rcfg[:]=(43,1,0,4);assert ri(staged,rcfg)==0
assert publish(ctx,0,staged,1)==-1 and bytes(ctx)+bytes(entries)+buf.raw==before
rcfg[:]=(42,1,0,4);assert ri(staged,rcfg)==0
assert publish(ctx,0,staged,2)==-1 and bytes(ctx)+bytes(entries)+buf.raw==before
staged[48]=b'\x00'
assert publish(ctx,0,staged,1)==-1 and bytes(ctx)+bytes(entries)+buf.raw==before
# Clock exhaustion and bad bounds must not change any ownership.
ctx[4]=0x7fffffffffffffff;entries[1]=ctx[4];key[:]=(0,0,4)
before=bytes(ctx)+bytes(entries)+buf.raw
assert reserve(ctx)==0 and find(ctx,key)==-1
rcfg[:]=(42,1,0,4);assert ri(staged,rcfg)==0 and publish(ctx,0,staged,1)==-1
assert bytes(ctx)+bytes(entries)+buf.raw==before
for fn in (get,dirty,evict):assert fn(ctx,1)==-1
assert clean(ctx,1,0)==-1
for k in [(-468751,0,0),(468750,0,0),(0,0,48)]:key[:]=k;assert find(ctx,key)==-1
for invalid in [(42,2,1,C.addressof(entries)),(42,1,0,C.addressof(entries)),(42,1,65,C.addressof(entries)),(42,1,1,0)]:
 cfg[:]=invalid;assert init(ctx,cfg)==-1 and bytes(ctx)+bytes(entries)+buf.raw==before
print(f'PASS: {checks} independent LRU operations, capacities1/2/8/64, dirty eviction, stale checkpoints, exhaustion, rejection conservation and canaries')
