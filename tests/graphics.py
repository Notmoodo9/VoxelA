"""Linux functional shader/upload/draw/readback and lifecycle test.

Optional second argument writes a PNG capture directly from OpenGL readback.
Run with a supported SDL driver, such as SDL_VIDEODRIVER=offscreen.
"""
import ctypes as C
import ctypes.util
import struct
import sys
import tempfile
from pathlib import Path
import zlib
sdl=C.CDLL(ctypes.util.find_library('SDL2-2.0') or 'libSDL2-2.0.so.0')
engine=C.CDLL(sys.argv[1])
def bind(lib,n,args,result):
 f=getattr(lib,n);f.argtypes=args;f.restype=result;return f
init=bind(sdl,'SDL_Init',[C.c_uint],C.c_int)
quit_sdl=bind(sdl,'SDL_Quit',[],None)
attr=bind(sdl,'SDL_GL_SetAttribute',[C.c_int,C.c_int],C.c_int)
window=bind(sdl,'SDL_CreateWindow',[C.c_char_p,C.c_int,C.c_int,C.c_int,C.c_int,C.c_uint],C.c_void_p)
context=bind(sdl,'SDL_GL_CreateContext',[C.c_void_p],C.c_void_p)
del_context=bind(sdl,'SDL_GL_DeleteContext',[C.c_void_p],None)
del_window=bind(sdl,'SDL_DestroyWindow',[C.c_void_p],None)
getproc=bind(sdl,'SDL_GL_GetProcAddress',[C.c_char_p],C.c_void_p)
geterror=bind(sdl,'SDL_GetError',[],C.c_char_p)
render_init=bind(engine,'terrain_init',[],C.c_int64)
draw=bind(engine,'terrain_draw',[],C.c_int64)
shutdown=bind(engine,'terrain_shutdown',[],C.c_int64)
camera_step=bind(engine,'terrain_camera_step',[C.c_uint64,C.c_uint64],C.c_int64)
camera_resize=bind(engine,'terrain_camera_resize',[C.c_uint64,C.c_uint64],C.c_int64)
compile_shader=bind(engine,'compile_shader',[C.c_uint,C.c_char_p],C.c_uint)
pick=bind(engine,'terrain_pick',[C.c_uint64]*4,C.c_int64)
selection=bind(engine,'terrain_get_selection',[C.c_void_p],C.c_int64)
select_block=bind(engine,'terrain_select_block',[C.c_uint64],C.c_int64)
apply_edit=bind(engine,'terrain_apply_edit',[C.c_uint64],C.c_int64)
edit_cell=bind(engine,'terrain_edit_cell',[C.c_void_p,C.c_uint64],C.c_int64)
get_block=bind(engine,'terrain_get_block',[C.c_void_p,C.c_void_p],C.c_int64)
snapshot_export=bind(engine,'terrain_snapshot_export',[C.c_void_p,C.c_uint64],C.c_int64)
snapshot_import=bind(engine,'terrain_snapshot_import',[C.c_void_p,C.c_uint64],C.c_int64)
terrain_save=bind(engine,'terrain_save',[C.c_char_p],C.c_int64)
terrain_load=bind(engine,'terrain_load',[C.c_char_p],C.c_int64)
unsaved=bind(engine,'terrain_has_unsaved_changes',[],C.c_int64)
section_state=bind(engine,'terrain_section_state',[C.c_uint64,C.c_void_p],C.c_int64)
def gl(name,args,result=None):
 p=getproc(name.encode());assert p,name
 return C.CFUNCTYPE(result,*args)(p)
def png(path,rgba,w,h):
 def chunk(tag,data):
  return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 # GL starts at the bottom; PNG scanlines start at the top.
 rows=b''.join(b'\0'+rgba[y*w*4:(y+1)*w*4] for y in range(h-1,-1,-1))
 data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
 with open(path,'wb') as f:f.write(data)
w=ctx=None
assert init(32)==0,geterror()
try:
 for a,v in [(17,3),(18,3),(21,1),(5,1),(6,24)]:assert attr(a,v)==0,geterror()
 w=window(b'VoxelA renderer test',0,0,800,600,2);assert w,geterror()
 ctx=context(w);assert ctx,geterror()
 viewport=gl('glViewport',[C.c_int]*4)
 clearcolor=gl('glClearColor',[C.c_float]*4)
 clear=gl('glClear',[C.c_uint])
 read=gl('glReadPixels',[C.c_int]*4+[C.c_uint,C.c_uint,C.c_void_p])
 error=gl('glGetError',[],C.c_uint)
 pixels=(C.c_ubyte*(800*600*4))()
 background=bytes([32,64,128,255])
 captures=[]
 for cycle in range(2):
  assert render_init()==0,'renderer initialization'
  if cycle == 0:
   assert compile_shader(0x8b31,b'#version 330 core\nthis is deliberately invalid GLSL')==0,'invalid shader was accepted'
   assert error()==0,'shader rejection left a GL error'
  viewport(0,0,800,600);clearcolor(.125,.25,.5,1)
  # Establish what this driver's untouched framebuffer actually contains.
  clear(0x4100);read(0,0,800,600,0x1908,0x1401,pixels)
  baseline=bytes(pixels)
  assert all(abs(baseline[i]-background[i])<=2 for i in range(4)),baseline[:4]
  assert draw()==0,'draw GL error'
  read(0,0,800,600,0x1908,0x1401,pixels)
  assert error()==0,'readback GL error'
  image=bytes(pixels)
  changed=sum(image[i:i+4]!=baseline[i:i+4] for i in range(0,len(image),4))
  assert 10000<changed<470000,('terrain coverage',changed)
  assert image[:4]==baseline[:4],'background corner overwritten'
  assert image[(300*800+400)*4:(300*800+400)*4+4]!=baseline[:4],'no terrain at center'
  captures.append(image)
  assert camera_step(1|128|256,100)==0,'camera controls'
  clear(0x4100);assert draw()==0
  read(0,0,800,600,0x1908,0x1401,pixels)
  moved=bytes(pixels)
  assert moved!=image,'camera controls did not affect drawing'
  assert camera_resize(0,600)==-1,'invalid camera aspect accepted'
  clear(0x4100);assert draw()==0;read(0,0,800,600,0x1908,0x1401,pixels)
  assert bytes(pixels)==moved,'invalid resize changed camera'
  assert camera_resize(1600,800)==0,'camera resize'
  clear(0x4100);assert draw()==0;read(0,0,800,600,0x1908,0x1401,pixels)
  assert bytes(pixels)!=moved,'aspect resize did not affect drawing'
  assert camera_resize(800,600)==0 and camera_step(2048,0)==0,'camera reset'
  clear(0x4100);assert draw()==0;read(0,0,800,600,0x1908,0x1401,pixels)
  assert bytes(pixels)==image,'reset did not restore original image'
  def capture():
   clear(0x4100);assert draw()==0
   read(0,0,800,600,0x1908,0x1401,pixels)
   assert error()==0
   return bytes(pixels)
  hit=(C.c_int64*9)()
  assert pick(400,300,800,600)==1 and selection(hit)==1,'center picking'
  original=hit[8];cell=(C.c_int64*3)(*hit[:3])
  assert 0<=cell[0]<32 and 64<=cell[1]<80 and 0<=cell[2]<32
  assert capture()!=image,'selection outline missing'
  assert apply_edit(0)==1,'break selected block'
  value=C.c_uint16(65535)
  assert get_block(cell,C.byref(value))==0 and value.value==0
  assert capture()!=image,'break did not rebuild mesh'
  assert apply_edit(0)==0,'stale selection accepted'
  assert edit_cell(cell,original)==1 and capture()==image,'restore mesh'
  assert edit_cell(cell,original)==0,'same-value edit'
  assert select_block(0)==-1 and select_block(7)==-1
  assert select_block(3)==0
  assert pick(400,300,800,600)==1 and selection(hit)==1
  adjacent=(C.c_int64*3)(*hit[5:8])
  assert apply_edit(1)==1,'placement'
  assert get_block(adjacent,C.byref(value))==0 and value.value==3
  assert capture()!=image,'placement did not rebuild mesh'
  assert camera_step(2048,0)==0
  assert get_block(adjacent,C.byref(value))==0 and value.value==3,'camera reset erased edits'
  assert edit_cell(adjacent,0)==1 and capture()==image
  for coords in [(32,72,0),(0,63,0),(-1,72,0)]:
   assert edit_cell((C.c_int64*3)(*coords),1)==0,'unloaded edit accepted'
  # Four-way section seam: edits on either side must restore identical geometry.
  for coords in [(15,72,15),(16,72,15),(15,72,16),(16,72,16)]:
   seam=(C.c_int64*3)(*coords)
   assert get_block(seam,C.byref(value))==0
   saved=value.value;replacement=0 if saved else 1
   assert edit_cell(seam,replacement)==1
   capture()
   assert edit_cell(seam,saved)==1 and capture()==image
  assert pick(0,0,800,600)==0 and selection(hit)==0
  assert pick(400,300,0,600)==-1
  assert apply_edit(2)==-1 and capture()==image
  state=(C.c_uint64*3)()
  def revisions():
   result=[]
   for i in range(4):
    assert section_state(i,state)==0
    result.append(tuple(state))
   return result
  snapshot=(C.c_ubyte*131136)()
  assert snapshot_export(snapshot,131136)==64,'restored baseline has overrides'
  seam=(C.c_int64*3)(15,79,15)
  assert get_block(seam,C.byref(value))==0
  saved=value.value;replacement=0 if saved else 1
  assert edit_cell(seam,replacement)==1 and unsaved()==1
  edited_image=capture();assert edited_image!=image
  length=snapshot_export(snapshot,131136)
  assert length==72,'single override encoding'
  assert edit_cell(seam,saved)==1 and capture()==image
  before=revisions()
  assert snapshot_import(snapshot,length)==0
  after=revisions()
  assert after[0][0]==before[0][0]+1 and after[1][0]==before[1][0]
  assert all(row[2]==1 for row in after),'load did not invalidate neighbor meshes'
  assert capture()==edited_image,'snapshot did not rebuild matching edited mesh'
  before=revisions()
  assert snapshot_import(snapshot,length)==0 and revisions()==before,'identical import changed revision'
  snapshot[40]^=1
  assert pick(400,300,800,600)==1
  selected_image=capture();before=revisions()
  assert snapshot_import(snapshot,length)==-1 and revisions()==before
  assert selection(hit)==1 and capture()==selected_image,'corrupt snapshot changed live selection/terrain'
  snapshot[40]^=1
  with tempfile.TemporaryDirectory(prefix='VoxelA graphics save ') as folder:
   path=Path(folder)/'edits.vxa';encoded=str(path).encode()
   assert terrain_save(encoded)==0 and unsaved()==0
   assert path.read_bytes()==bytes(snapshot[:length]),'save file differs from exported snapshot'
   assert edit_cell(seam,saved)==1 and capture()==image and unsaved()==1
   assert terrain_load(encoded)==0 and unsaved()==0 and capture()==edited_image
   # Real renderer destruction/recreation: generated baseline then explicit load.
   assert shutdown()==0 and render_init()==0 and unsaved()==0
   assert capture()==image,'fresh viewer retained prior edits'
   assert terrain_load(encoded)==0 and unsaved()==0 and capture()==edited_image
   assert edit_cell(seam,saved)==1 and capture()==image and unsaved()==1
   preserved=revisions()
   tmp=Path(str(path)+'.tmp');tmp.write_bytes(b'prior interrupted write')
   assert terrain_save(encoded)==-1 and unsaved()==1 and revisions()==preserved
   assert tmp.read_bytes()==b'prior interrupted write'
   assert path.read_bytes()==bytes(snapshot[:length]),'failed save altered committed file'
   tmp.unlink()
   path.write_bytes(b'corrupt')
   assert terrain_load(encoded)==-1 and revisions()==preserved and capture()==image
   assert terrain_load(str(Path(folder)/'missing').encode())==-1 and capture()==image
   assert terrain_save(str(Path(folder)/'absent'/'edits.vxa').encode())==-1 and unsaved()==1

  assert shutdown()==0 and shutdown()==0,'idempotent shutdown'
  assert error()==0,'cleanup GL error'
 assert captures[0]==captures[1],'renderer rebuild changed image'
 if len(sys.argv)>2:png(sys.argv[2],captures[0],800,600)
 print(f'PASS: terrain shaders, upload, full framebuffer ({changed} terrain pixels), camera controls/aspect/reset, picking/outline/edit mesh rebuild, transactional snapshots and restart save/load, invalid-shader rejection and idempotent cleanup')
finally:
 if ctx:
  shutdown();del_context(ctx)
 if w:del_window(w)
 quit_sdl()
