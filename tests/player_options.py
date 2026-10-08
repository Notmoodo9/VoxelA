"""Independent settings, timers, decimal formatting and Creative-flight models."""
import ctypes as C,struct,random,math,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
si=bind('settings_init',[P]);sv=bind('settings_valid',[P]);ss=bind('settings_set',[P,I,I]);lens=bind('settings_lens',[P,P]);mouse=bind('settings_mouse',[P,I,I,P]);ai=bind('autosave_init',[P,U]);poll=bind('autosave_poll',[P,U,U]);finish=bind('autosave_finish',[P,U,I]);formatn=bind('format_i64',[I,P]);wi=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);edit=bind('stream_edit',[P,P,U]);pi=bind('player_init',[P,P]);fly=bind('player_fly',[P,P,U,U])
def check(v,msg):
 global checks
 checks+=1;assert v,msg
rng=random.Random(4097);settings=(C.c_uint32*8)();check(si(settings)==0 and list(settings)==[95,100,0,0,0,100,0,0],'settings defaults');bounds=[(60,110),(10,300),(0,1),(0,1),(0,1),(25,400)]
for field,(lo,hi) in enumerate(bounds):
 for value in (-1,0,lo-1,lo,hi,hi+1,2**32):
  before=bytes(settings);ok=lo<=value<=hi;check(ss(settings,field,value)==(0 if ok else -1),'setting bounds');check(bytes(settings)==before if not ok else settings[field]==value,'invalid setting atomic')
for field in (-1,6,7,8):
 before=bytes(settings);check(ss(settings,field,1)==-1 and bytes(settings)==before,'transient fields protected')
si(settings)
for fov in range(60,111):
 ss(settings,0,fov);out=(C.c_float*2)(-7,123);check(lens(settings,out)==0 and math.isclose(out[0],1/math.tan(math.radians(fov)/2),rel_tol=2e-6) and out[1]==123,'vertical FOV lens model')
for _ in range(3000):
 sensitivity=rng.randint(10,300);invert=rng.randrange(2);ss(settings,1,sensitivity);ss(settings,2,invert);dx=rng.randint(-1001,1001);dy=rng.randint(-1001,1001);out=(I*3)(777,888,999);valid=abs(dx)<=1000 and abs(dy)<=1000
 check(mouse(settings,dx,dy,out)==(0 if valid else -1),'scaled mouse status')
 expected=[max(-1000,min(1000,math.trunc(dx*sensitivity/100))),max(-1000,min(1000,math.trunc(dy*sensitivity/100)))*(-1 if invert else 1),999] if valid else [777,888,999]
 check(list(out)==expected,'scaled mouse independent model')
for value in [-2**63,2**63-1,-1,0,1,10,-10,30000000,-30000000]+[rng.randint(-2**63,2**63-1) for _ in range(2000)]:
 out=C.create_string_buffer(32);C.memset(out,165,32);want=str(value).encode();check(formatn(value,out)==len(want) and out.raw[:len(want)+1]==want+b'\0' and out.raw[len(want)+1:]==b'\xa5'*(31-len(want)),'signed decimal/canary')
clock=(C.c_uint32*4)();check(ai(clock,100)==0 and list(clock)==[100,100,1,0],'timer init')
for tick,reason,want in ((300099,0,0),(300100,0,1),(300101,0,0),(310099,0,0),(310100,0,1)):
 check(poll(clock,tick,reason)==want,'five-minute due / retry backoff')
check(finish(clock,310100,-1)==0 and list(clock)==[100,310100,1,2**32-1],'failure keeps last success');check(poll(clock,320100,0)==1 and finish(clock,320100,0)==0 and clock[0]==320100,'successful retry advances timer')
for reason in (1,2):check(poll(clock,320101,reason)==1,'pause/exit immediate')
ai(clock,2**32-150000);check(poll(clock,149999,0)==0 and poll(clock,150000,0)==1,'SDL tick-wrap arithmetic')
now=rng.randrange(2**32);ai(clock,now);model=[now,now,1,0]
for _ in range(5000):
 now=(now+rng.randint(0,200000))%(2**32);reason=rng.choice((0,0,0,1,2));want=int(reason!=0 or (((now-model[0])%2**32)>=300000 and ((now-model[1])%2**32)>=10000));check(poll(clock,now,reason)==want,'timer model due')
 if want:
  model[1]=now;result=rng.choice((0,0,-1));check(finish(clock,now,result)==0,'timer finish');model[1]=now;model[3]=0 if not result else 2**32-1
  if not result:model[0]=now
 check(list(clock)==model,'timer model state')
for args in ((clock,2**32,0),(clock,now,3)):
 before=bytes(clock);check(poll(*args)==-1 and bytes(clock)==before,'invalid timer request atomic')
world=(U*12)();entries=C.create_string_buffer(25600);blocks=C.create_string_buffer(3276800);edits=C.create_string_buffer(262144);config=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(edits));wi(world,config);center(world,0,0);player=C.create_string_buffer(80)
for mask in range(128):
 for dt in (0,17,100,400,1000):
  pi(player,(C.c_double*3)(.5,150,.5));before=player.raw;check(fly(world,player,mask,dt)==0,'flight input accepted')
  forward=int(bool(mask&1))-int(bool(mask&2));side=int(bool(mask&8))-int(bool(mask&4));up=int(bool(mask&16))-int(bool(mask&64));norm=math.sqrt(forward*forward+side*side+up*up);distance=(20 if mask&32 else 10)*min(dt,400)/1000;want=(.5+side*distance/norm,150+up*distance/norm,.5-forward*distance/norm) if norm else (.5,150,.5);actual=struct.unpack_from('<3d',player)
  check(all(math.isclose(a,b,abs_tol=1e-9) for a,b in zip(actual,want)),'normalized three-axis flight model')
  if dt:check((struct.unpack_from('<dQ',player,48)+struct.unpack_from('<Q',player,72))==(0,0,0),'no gravity or jump latch while flying')
for mask in (128,255,2**64-1):
 before=player.raw;check(fly(world,player,mask,100)==-1 and player.raw==before,'invalid flight mask atomic')
# Collision and ceiling safety with ten-ms substeps, even at maximum frame delta.
for y in range(148,155):
 for z in range(-10,11):edit(world,(I*3)(2,y,z),5)
pi(player,(C.c_double*3)(.5,150,.5));fly(world,player,8|32,400);check(.5<=struct.unpack_from('<d',player)[0]<=1.700001,'flight does not tunnel through wall')
edit(world,(I*3)(0,152,0),5);pi(player,(C.c_double*3)(.5,150,.5));fly(world,player,16,400);check(150<=struct.unpack_from('<d',player,8)[0]<=150.200001,'flight respects ceiling')
print(f'player options: {checks} settings/timer/format/flight checks passed')
