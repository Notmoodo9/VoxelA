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
frametime=bind(engine,'play_frame_time',[C.c_uint64])
menutab=bind(engine,'play_menu_tab',[]);menuaction=bind(engine,'play_menu_action',[C.c_uint64,C.c_uint64,C.c_uint64]);pointer=bind(engine,'play_menu_pointer',[C.c_uint64,C.c_uint64]);menurelease=bind(engine,'play_menu_release',[C.c_uint64,C.c_uint64])
menu=bind(engine,'play_menu',[C.c_uint64]);menuopen=bind(engine,'play_menu_open',[]);menuclick=bind(engine,'play_menu_click',[C.c_uint64,C.c_uint64])
mine=bind(engine,'play_mine',[C.c_uint64,C.c_uint64]);mode=bind(engine,'play_mode',[C.c_uint64]);craft=bind(engine,'play_craft',[C.c_uint64]);getinventory=bind(engine,'play_get_inventory',[C.c_void_p])
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
 # Storage/standard controls work independently of the hotbar.
 inv36=(C.c_ubyte*304)();assert menu(1)==0
 assert menuaction(40,340,2)==1 # shift dirt into storage
 assert getinventory(inv36)==0 and struct.unpack_from('<HH',inv36,72)==(2,32)
 assert menuaction(40,280,1)==1 # split storage stack into cursor
 assert getinventory(inv36)==0 and struct.unpack_from('<HH',inv36,296)==(2,16)
 assert menuaction(104,280,1)==1 # place one in next storage slot
 assert getinventory(inv36)==0 and struct.unpack_from('<HH',inv36,80)==(2,1)
 assert menuaction(168,280,0)==1 # place remaining15
 assert menuaction(168,280,2)==1 # shift remaining15 back to hotbar
 assert menuaction(104,340,0)==1 # pick up starter wood
 assert pointer(552,160)==0 and menurelease(552,160)==1 # drag into last storage slot
 assert getinventory(inv36)==0 and struct.unpack_from('<HH',inv36,280)==(5,8)
 assert menu(0)==0 and stop()==0 and start()==0 and capture()==image
 # Real scaled inventory panel, read-only availability and clickable recipes.
 menu_inventory=(C.c_ubyte*304)()
 assert getinventory(menu_inventory)==0;fresh_inventory=bytes(menu_inventory)
 assert menu(2)==-1 and menuopen()==0 and menu(1)==0 and menuopen()==1
 panel=capture();assert panel!=image,'inventory panel absent'
 if len(sys.argv)>3:png(sys.argv[3],panel)
 assert getplayer(pose)==0;menu_pose=bytes(pose)
 assert step(1,100)==0 and look(100,100)==0 and getplayer(pose)==0 and bytes(pose)==menu_pose,'menu did not pause player'
 assert apply(0)==0 and mine(1,100)==0
 assert menutab()==0
 for x,y in [(640,340),(31,340),(90,340),(40,201),(10,10)]:assert menuclick(x,y)==0,'menu gap hit'
 assert menuclick(40,132)==0 and getinventory(menu_inventory)==0 and bytes(menu_inventory)==fresh_inventory,'locked recipe consumed resources'
 # Move dirt to the last slot, craft using items spread across slots.
 assert menuclick(40,340)==1 and menuclick(552,340)==1
 assert getinventory(menu_inventory)==0 and struct.unpack_from('<HHHH',menu_inventory,64)==(2,32,0,0)
 assert menuclick(50,220)==1 and menuclick(50,220)==1
 assert menuclick(50,178)==1 and menuclick(50,136)==1
 assert getinventory(menu_inventory)==0
 assert struct.unpack_from('<HHHH',menu_inventory,24)==(10,1,60,0),'click crafting failed'
 # A whole tool moves with its durability; closing a selected source loses none.
 assert menuclick(232,340)==1 and menuclick(296,340)==1
 assert getinventory(menu_inventory)==0 and struct.unpack_from('<HHHH',menu_inventory,32)==(10,1,60,0)
 assert menuclick(296,340)==1
 assert getinventory(menu_inventory)==0;rearranged=bytes(menu_inventory)
 with tempfile.TemporaryDirectory(prefix='VoxelA inventory menu ') as menu_folder:
  menu_path=str(Path(menu_folder)/'inventory.vxa').encode()
  assert save(menu_path)==0,'saving with a selected menu source failed'
  assert menuclick(360,340)==1 and getinventory(menu_inventory)==0 and bytes(menu_inventory)!=rearranged
  assert load(menu_path)==0 and getinventory(menu_inventory)==0 and bytes(menu_inventory)==rearranged,'menu arrangement/tool persistence'
  # Successful loading clears the source highlight; this is a fresh selection.
  assert menuclick(296,340)==1
 assert menu(0)==0 and menuopen()==0
 assert getinventory(menu_inventory)==0
 assert sum(struct.unpack_from('<H',menu_inventory,i*8)[0]==10 for i in range(36))==1 and bytes(menu_inventory[296:])==bytes(8)
 assert stop()==0 and start()==0 and capture()==image,'menu state did not reset'
 for _ in range(60):assert frametime(17)==0
 assert capture()!=image,'FPS display did not update'
 assert frametime(0x100000000)==-1
 assert stop()==0 and start()==0 and capture()==image,'FPS sample reset'
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
 inv=(C.c_ubyte*304)();assert getinventory(inv)==0
 assert struct.unpack_from('<HH',inv,0)==(2,32)
 assert original in [2,3,4,6],original
 # Hold duration and release reset are tested through the real renderer API.
 assert mine(2,100)==-1
 assert mine(1,100)==0 and get(cell)==original
 progress=capture();assert progress!=image,'mining progress HUD'
 assert mine(0,0)==0
 required={2:350,3:350,4:300,6:150}[original]
 for elapsed_ms in range(0,required-100,100):assert mine(1,100)==0 and get(cell)==original
 remaining=required-((required-101)//100+1)*100
 assert mine(1,max(remaining,1))==1 and get(cell)==0,'hold-to-mine completion'
 assert getinventory(inv)==0
 assert struct.unpack_from('<HH',inv,0)==(2,33),'grass dirt pickup'
 removed=capture();assert removed!=image
 assert edit(cell,original)==1 and get(cell)==original
 assert getplayer(pose)==0
 feet=C.cast(pose,C.POINTER(C.c_double))
 body=(C.c_int64*3)(int(feet[0]//1),int(feet[1]//1),int(feet[2]//1))
 assert edit(body,1)==0,'player suffocating placement accepted'
 assert select(0)==-1 and select(10)==-1 and select(9)==0
 assert mode(2)==-1 and mode(1)==0
 assert getinventory(inv)==0;creative_slots=bytes(inv)[:288]
 assert pick()==1 and apply(0)==1 and getinventory(inv)==0
 assert bytes(inv)[:288]==creative_slots,'creative changed inventory'
 assert edit(cell,original)==1 and mode(0)==0 and select(1)==0
 assert pick()==1 and hit(h)==1
 placed=(C.c_int64*3)(*h[5:8])
 assert get(placed)==0 and apply(1)==1 and get(placed)==2,'inventory placement'
 assert getinventory(inv)==0 and struct.unpack_from('<H',inv,2)[0]==32,'placement did not consume'
 assert edit(placed,0)==1
 assert craft(0)==1 and craft(0)==1 and craft(1)==1 and craft(2)==1
 assert getinventory(inv)==0
 slots=[struct.unpack_from('<HHHH',inv,i*8) for i in range(9)]
 tool_slot=next(i for i,slot in enumerate(slots) if slot[0]==10)
 assert select(tool_slot+1)==0 and pick()==1
 assert edit(cell,1)==1 and pick()==1
 for _ in range(7):assert mine(1,100)==0 and get(cell)==1
 assert mine(1,100)==1 and get(cell)==0,'pickaxe mining'
 assert getinventory(inv)==0 and struct.unpack_from('<H',inv,tool_slot*8+4)[0]==59,'tool durability'
 assert edit(cell,original)==1
 assert select(9)==0 and pick()==1
 assert edit(cell,1)==1 and pick()==1
 assert mine(1,100)==0 and get(cell)==1,'bare-hand stone mining accepted'
 assert edit(cell,original)==1
 assert select(tool_slot+1)==0

 with tempfile.TemporaryDirectory(prefix='VoxelA player save ') as folder:
  path=Path(folder)/'world.vxa';encoded=str(path).encode()
  assert edit(cell,0)==1 and save(encoded)==0
  assert getinventory(inv)==0;persisted_inventory=bytes(inv)
  assert getplayer(pose)==0;persisted=bytes(pose)[:32]
  assert step(8,100)==0 and look(200,40)==0
  assert stop()==0 and start()==0
  assert load(encoded)==0 and get(cell)==0
  assert getinventory(inv)==0 and bytes(inv)==persisted_inventory,'inventory/tools/mode not restored'
  assert getplayer(pose)==0 and bytes(pose)[:32]==persisted,'player pose not restored'
  loaded=capture()
  path.write_bytes(b'invalid')
  assert load(encoded)==-1 and get(cell)==0 and getplayer(pose)==0 and bytes(pose)[:32]==persisted
  # Failure message may change HUD; world and pose must remain identical.
  assert capture()!=loaded
  path.unlink()
  assert save(str(Path(folder)/'missing'/'world.vxa').encode())==-1
  # Full bags refuse the world edit and retain tool durability. A final-use
  # tool can free its own slot for the pickup, without duplicating either.
  assert edit(cell,original)==1 and save(encoded)==0
  baseline=bytearray(path.read_bytes())
  def install_inventory(slots,selected=0):
   data=bytearray(baseline)
   data[-304:]=b''.join(struct.pack('<HHHH',*slot) for slot in slots)+bytes((36-len(slots))*8)+struct.pack('<II',selected,0)+bytes(8)
   checksum=0xcbf29ce484222325
   for i,b in enumerate(data):checksum=((checksum^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
   struct.pack_into('<Q',data,40,checksum);path.write_bytes(data)
   assert load(encoded)==0 and pick()==1
  full=[[10,1,5,0]]+[[8,64,0,0] for _ in range(35)]
  install_inventory(full)
  assert getinventory(inv)==0;before_inventory=bytes(inv)
  for _ in range(4):assert mine(1,100)==0
  assert get(cell)==original and getinventory(inv)==0 and bytes(inv)==before_inventory,'full bag consumed terrain or tool'
  held_full=bytearray(path.read_bytes());held_full[-8:]=struct.pack('<HHHH',5,1,0,0)
  checksum=0xcbf29ce484222325
  for i,b in enumerate(held_full):checksum=((checksum^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
  struct.pack_into('<Q',held_full,40,checksum);path.write_bytes(held_full)
  assert load(encoded)==0 and menuopen()==1 and getinventory(inv)==0
  held_inventory=bytes(inv)
  assert menu(0)==-2 and menuopen()==1 and getinventory(inv)==0 and bytes(inv)==held_inventory,'full cursor closing lost items'
  install_inventory([[10,1,1,0]]+[[8,64,0,0] for _ in range(35)])
  assert menu(0)==0 and capturemode(1)==0
  assert edit(cell,1)==1 and pick()==1
  for _ in range(7):assert mine(1,100)==0
  assert mine(1,100)==1 and get(cell)==0 and getinventory(inv)==0
  assert struct.unpack_from('<HHHH',inv,0)==(1,1,0,0),'last-use tool pickup transaction'
  assert edit(cell,original)==1
  # Inventory staging must also roll back when the world journal is full.
  maximum=bytearray(baseline[:128])
  struct.pack_into('<I',maximum,20,8192);struct.pack_into('<Q',maximum,32,8192*32+304)
  for i in range(8192):maximum.extend(struct.pack('<qqqQ',i%128,100,i//128,5))
  maximum.extend(struct.pack('<HHHH',2,32,0,0)+struct.pack('<HHHH',5,8,0,0)+bytes(272)+struct.pack('<II',0,0)+bytes(8))
  checksum=0xcbf29ce484222325
  for i,b in enumerate(maximum):checksum=((checksum^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
  struct.pack_into('<Q',maximum,40,checksum);path.write_bytes(maximum)
  assert load(encoded)==0 and pick()==1 and getinventory(inv)==0
  before_inventory=bytes(inv)
  for _ in range(3):assert mine(1,100)==0
  assert mine(1,50)==-2 and get(cell)==original and getinventory(inv)==0
  assert bytes(inv)==before_inventory,'failed terrain edit consumed inventory'
  # Inventory reset on a successful legacy load, without requiring a new world.
  legacy=bytearray(baseline[:-304]);struct.pack_into('<I',legacy,8,1)
  struct.pack_into('<Q',legacy,32,len(legacy)-128);struct.pack_into('<Q',legacy,96,0)
  checksum=0xcbf29ce484222325
  for i,b in enumerate(legacy):checksum=((checksum^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
  struct.pack_into('<Q',legacy,40,checksum);path.write_bytes(legacy)
  assert load(encoded)==0 and getinventory(inv)==0
  assert struct.unpack_from('<HHHH',inv,0)==(2,32,0,0),'legacy gameplay migration'
  assert mode(1)==0 and save(encoded)==0
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
 print('PASS: first-person perspective, original texture atlas, HUD, walking, mouse look, collision-safe edits, finite inventory, timed mining, tool wear, crafting, Creative, saved gameplay restart and idempotent GL cleanup')
finally:
 if ctx:stop();delcontext(ctx)
 if w:delwindow(w)
 quit()
