"""First-person OpenGL textures/HUD/movement/edit/restart integration."""
import ctypes as C
import ctypes.util
from pathlib import Path
import sys
import tempfile
import struct,zlib
sdl=C.CDLL(ctypes.util.find_library('SDL2-2.0') or 'libSDL2-2.0.so.0');engine=C.CDLL(sys.argv[1])
def bind(lib,n,args,result=C.c_int64):
 f=getattr(lib,n);f.argtypes=args;f.restype=result;return f
init=bind(sdl,'SDL_Init',[C.c_uint],C.c_int);quit=bind(sdl,'SDL_Quit',[],None)
attr=bind(sdl,'SDL_GL_SetAttribute',[C.c_int,C.c_int],C.c_int)
window=bind(sdl,'SDL_CreateWindow',[C.c_char_p,C.c_int,C.c_int,C.c_int,C.c_int,C.c_uint],C.c_void_p)
context=bind(sdl,'SDL_GL_CreateContext',[C.c_void_p],C.c_void_p)
delcontext=bind(sdl,'SDL_GL_DeleteContext',[C.c_void_p],None);delwindow=bind(sdl,'SDL_DestroyWindow',[C.c_void_p],None)
getproc=bind(sdl,'SDL_GL_GetProcAddress',[C.c_char_p],C.c_void_p)
start=bind(engine,'play_init',[]);draw=bind(engine,'play_draw',[]);stop=bind(engine,'play_shutdown',[])
look=bind(engine,'play_look',[C.c_int64,C.c_int64]);step=bind(engine,'play_step',[C.c_uint64,C.c_uint64]);resize=bind(engine,'play_resize',[C.c_uint64,C.c_uint64])
getplayer=bind(engine,'play_get_player',[C.c_void_p]);pick=bind(engine,'play_pick',[]);hit=bind(engine,'play_get_hit',[C.c_void_p]);select=bind(engine,'play_select',[C.c_uint64]);apply=bind(engine,'play_apply',[C.c_uint64]);edit=bind(engine,'play_edit_cell',[C.c_void_p,C.c_uint64]);get=bind(engine,'play_get_block',[C.c_void_p])
save=bind(engine,'play_save',[C.c_char_p]);load=bind(engine,'play_load',[C.c_char_p]);capturemode=bind(engine,'play_set_capture',[C.c_uint64]);setseed=bind(engine,'play_seed',[C.c_uint64]);height=bind(engine,'terrain_height',[C.c_uint64,C.c_int64,C.c_int64])
def gl(n,args,result=None):return C.CFUNCTYPE(result,*args)(getproc(n.encode()))
def png(path,data):
 def ch(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 rows=b''.join(b'\0'+data[y*3200:(y+1)*3200] for y in range(599,-1,-1))
 Path(path).write_bytes(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',800,600,8,6,0,0,0))+ch(b'IDAT',zlib.compress(rows))+ch(b'IEND',b''))
w=ctx=None
assert init(32)==0
try:
 for a,v in [(17,3),(18,3),(21,1),(5,1),(6,24)]:assert attr(a,v)==0
 w=window(b'VoxelA first person test',0,0,800,600,2);assert w
 ctx=context(w);assert ctx
 viewport=gl('glViewport',[C.c_int]*4);clearcolor=gl('glClearColor',[C.c_float]*4);clear=gl('glClear',[C.c_uint]);read=gl('glReadPixels',[C.c_int]*4+[C.c_uint,C.c_uint,C.c_void_p]);error=gl('glGetError',[],C.c_uint)
 pixels=(C.c_ubyte*1920000)();pose=(C.c_ubyte*80)()
 viewport(0,0,800,600);clearcolor(.55,.75,.94,1)
 def capture():
  clear(0x4100);assert draw()==0,'first-person GL draw'
  read(0,0,800,600,0x1908,0x1401,pixels);assert error()==0
  return bytes(pixels)
 assert start()==0,'initialization'
 image=capture();assert len(set(image[i:i+3] for i in range(0,len(image),4)))>200,'no texture/fog variation'
 assert getplayer(pose)==0
 initial=bytes(pose)
 assert capturemode(0)==0;paused=capture();assert paused!=image,'pause HUD missing'
 assert capturemode(1)==0 and capture()==image
 assert look(100,40)==0 and capture()!=image,'mouse perspective'
 assert step(1,100)==0 and getplayer(pose)==0
 assert bytes(pose)[:24]!=initial[:24],'player did not walk'
 before=capture();assert resize(0,600)==-1 and capture()==before
 assert resize(1600,800)==0 and capture()!=before
 assert resize(800,600)==0
 # Reset renderer to a deterministic fresh player.
 assert stop()==0 and stop()==0 and start()==0 and capture()==image
 assert look(0,200)==0 and pick()==1,'five-block aim ray'
 h=(C.c_int64*9)();assert hit(h)==1
 cell=(C.c_int64*3)(*h[:3]);original=h[8]
 assert apply(0)==1 and get(cell)==0,'aimed removal'
 removed=capture();assert removed!=image
 assert edit(cell,original)==1 and get(cell)==original
 assert getplayer(pose)==0
 feet=C.cast(pose,C.POINTER(C.c_double))
 body=(C.c_int64*3)(int(feet[0]//1),int(feet[1]//1),int(feet[2]//1))
 assert edit(body,1)==0,'player suffocating placement accepted'
 assert select(0)==-1 and select(7)==-1 and select(5)==0
 with tempfile.TemporaryDirectory(prefix='VoxelA player save ') as folder:
  path=Path(folder)/'world.vxa';encoded=str(path).encode()
  assert edit(cell,0)==1 and save(encoded)==0
  assert getplayer(pose)==0;persisted=bytes(pose)[:32]
  assert step(8,100)==0 and look(200,40)==0
  assert stop()==0 and start()==0
  assert load(encoded)==0 and get(cell)==0
  assert getplayer(pose)==0 and bytes(pose)[:32]==persisted,'player pose not restored'
  loaded=capture()
  path.write_bytes(b'invalid')
  assert load(encoded)==-1 and get(cell)==0 and getplayer(pose)==0 and bytes(pose)[:32]==persisted
  # Failure message may change HUD; world and pose must remain identical.
  assert capture()!=loaded
  path.unlink()
  assert save(str(Path(folder)/'missing'/'world.vxa').encode())==-1
  # Large coordinates exercise the actual rebased GPU path, not only CPU math.
  assert save(encoded)==0
  distant=bytearray(path.read_bytes())
  struct.pack_into('<ddd',distant,64,16000000.5,height(42,16000000,-16000000)+1,-15999999.5)
  checksum=0xcbf29ce484222325
  for i,b in enumerate(distant):checksum=((checksum^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
  struct.pack_into('<Q',distant,40,checksum);path.write_bytes(distant)
  assert load(encoded)==0 and getplayer(pose)==0
  farpose=C.cast(pose,C.POINTER(C.c_double))
  assert farpose[0]==16000000.5 and farpose[2]==-15999999.5
  farimage=capture()
  assert len(set(farimage[i:i+3] for i in range(0,len(farimage),4)))>50,'distant texture rendering failed'
  assert farimage[(100*800+100)*4:(100*800+100)*4+3]!=bytes([140,191,240]),'distant terrain disappeared'
  assert save(encoded)==0 and stop()==0 and start()==0 and load(encoded)==0
  assert capture()==farimage,'distant save/rebase mismatch'

 assert stop()==0 and stop()==0 and error()==0
 assert setseed(43)==0 and start()==0 and getplayer(pose)==0
 assert C.cast(pose,C.POINTER(C.c_double))[1]==height(43,0,0)+1,'configured seed spawn'
 capture();assert stop()==0 and setseed(42)==0
 if len(sys.argv)>2:png(sys.argv[2],image)
 print('PASS: first-person perspective, original texture atlas, HUD, walking, mouse look, collision-safe edits, saved player/world restart and idempotent GL cleanup')
finally:
 if ctx:stop();delcontext(ctx)
 if w:delwindow(w)
 quit()
