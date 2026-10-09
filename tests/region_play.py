"""Actual OpenGL player upgrades, streams full-height regions and persists state."""
import ctypes as C
import ctypes.util
import os, struct, sys, tempfile
from pathlib import Path
sdl=C.CDLL(ctypes.util.find_library('SDL2-2.0') or 'libSDL2-2.0.so.0');engine=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64

def bind(lib,n,args,result=I):
 f=getattr(lib,n);f.argtypes=args;f.restype=result;return f
init=bind(sdl,'SDL_Init',[C.c_uint],C.c_int);quit=bind(sdl,'SDL_Quit',[],None);attr=bind(sdl,'SDL_GL_SetAttribute',[C.c_int,C.c_int],C.c_int);win=bind(sdl,'SDL_CreateWindow',[C.c_char_p,C.c_int,C.c_int,C.c_int,C.c_int,C.c_uint],P);context=bind(sdl,'SDL_GL_CreateContext',[P],P);dc=bind(sdl,'SDL_GL_DeleteContext',[P],None);dw=bind(sdl,'SDL_DestroyWindow',[P],None);proc=bind(sdl,'SDL_GL_GetProcAddress',[C.c_char_p],P)
start=bind(engine,'play_init',[]);stop=bind(engine,'play_shutdown',[]);draw=bind(engine,'play_draw',[]);save=bind(engine,'play_save',[C.c_char_p]);load=bind(engine,'play_load',[C.c_char_p]);openworld=bind(engine,'play_region_open',[C.c_char_p]);seed=bind(engine,'play_region_seed',[C.c_char_p]);getplayer=bind(engine,'play_get_player',[P]);getinv=bind(engine,'play_get_inventory',[P]);getgrid=bind(engine,'play_get_crafting',[P]);edit=bind(engine,'play_edit_cell',[P,U]);get=bind(engine,'play_get_block',[P]);mode=bind(engine,'play_mode',[U]);space=bind(engine,'play_space_press',[U]);step=bind(engine,'play_step',[U,U]);far=bind(engine,'play_far_distance',[U])
player=C.create_string_buffer(80);inventory=C.create_string_buffer(304);grid=C.create_string_buffer(32)
def state():
 assert getplayer(player)==0 and getinv(inventory)==0 and getgrid(grid)==0
 return player.raw[:32],inventory.raw+grid.raw
oldcwd=os.getcwd();w=ctx=None;assert init(32)==0
try:
 for a,v in [(17,3),(18,3),(21,1),(5,1),(6,24)]:assert attr(a,v)==0
 w=win(b'VoxelA region player test',0,0,800,600,2);assert w
 ctx=context(w);assert ctx
 def gl(n,args,result=None):return C.CFUNCTYPE(result,*args)(proc(n.encode()))
 viewport=gl('glViewport',[C.c_int]*4);clear=gl('glClear',[C.c_uint]);read=gl('glReadPixels',[C.c_int]*4+[C.c_uint,C.c_uint,P]);error=gl('glGetError',[],C.c_uint)
 pixels=C.create_string_buffer(800*600*4);viewport(0,0,800,600)
 def capture():
  clear(0x4100);assert draw()==0
  read(0,0,800,600,0x1908,0x1401,pixels);assert error()==0
  return pixels.raw
 with tempfile.TemporaryDirectory(prefix='VoxelA GL region adoption ') as folder:
  os.chdir(folder);root=Path(folder)/'upgraded';root.mkdir();path=str(root).encode();oldsave=Path('voxela-world.vxa')
  assert start()==0 and save(b'voxela-world.vxa')==0
  legacy=oldsave.read_bytes();before=state()
  lock=root/'r_-1_-1_0.vxr.tmp';lock.write_bytes(b'other writer')
  assert openworld(path)==-1 and state()==before
  assert not (root/'legacy-player.vxa').exists() and (root/'upgrade-source.vxa').read_bytes()==legacy
  lock.unlink();assert stop()==0 and start()==0
  assert mode(1)==0 and save(b'voxela-world.vxa')==0
  retained=oldsave.read_bytes();assert retained!=legacy
  assert openworld(path)==0 and state()==before,'resumed upgrade did not retain frozen player/inventory'
  assert (root/'legacy-player.vxa').read_bytes()==legacy and oldsave.read_bytes()==retained
  image=capture();assert len({image[i:i+3] for i in range(0,len(image),4)})>100
  assert far(128)==0;capture() # region horizon guard must not draw legacy heights
  for y in (-128,400):assert edit((I*3)(1,y,0),5)>=0 and get((I*3)(1,y,0))==5
  capture()
  assert mode(1)==0 and space(1000)==0 and space(1100)==1
  for _ in range(350):assert step(16,100)==0
  pose,items=state();assert struct.unpack_from('<d',pose,8)[0]>256,'full-height player collision/flight rejected'
  assert save(b'ignored-legacy-path.vxa')==0
  saved=(root/'player.vxp').read_bytes();assert len(saved)==432 and saved[:8]==b'VXAPLYR1'
  assert saved[64:96]==pose and saved[96:]==items and not Path('ignored-legacy-path.vxa').exists()
  assert oldsave.read_bytes()==retained
  # Failed state replacement retains the older saved state and live inventory.
  lock=root/'player.vxp.tmp';lock.write_bytes(b'other writer');assert mode(0)==0
  live=state();assert save(b'ignored')==-1 and state()==live and (root/'player.vxp').read_bytes()==saved
  lock.unlink();assert load(b'ignored')==0 and state()==(pose,items)
  # Corrupt and checksum-valid blocked poses cannot partially replace live state.
  damaged=bytearray(saved);damaged[-1]^=128;(root/'player.vxp').write_bytes(damaged)
  live=state();assert load(b'ignored')==-1 and state()==live
  blocked=bytearray(saved);struct.pack_into('<ddd',blocked,64,1.5,400,.5)
  h=0xcbf29ce484222325
  for i,b in enumerate(blocked):h=((h^(0 if 32<=i<40 else b))*0x100000001b3)&((1<<64)-1)
  struct.pack_into('<Q',blocked,32,h);(root/'player.vxp').write_bytes(blocked)
  assert load(b'ignored')==-1 and state()==live;capture()
  (root/'player.vxp').write_bytes(saved)
  assert stop()==0 and stop()==0
  assert seed(path)==0 and start()==0 and openworld(path)==0
  assert state()==(pose,items),'region restart lost full-height player/inventory'
  for y in (-128,400):assert get((I*3)(1,y,0))==5
  capture();assert stop()==0 and stop()==0
finally:
 os.chdir(oldcwd)
 if ctx:stop();dc(ctx)
 if w:dw(w)
 quit()
print('PASS: real GL region upgrade, preserved legacy/state, full-height Creative flight/edits, save/load/restart, failed writes, corrupt/blocked poses and horizon guard')
