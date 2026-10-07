"""Linux functional shader/upload/draw/readback and lifecycle test.

Optional second argument writes a PNG capture directly from OpenGL readback.
Run with a supported SDL driver, such as SDL_VIDEODRIVER=offscreen.
"""
import ctypes as C
import ctypes.util
import struct
import sys
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
compile_shader=bind(engine,'compile_shader',[C.c_uint,C.c_char_p],C.c_uint)
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
  assert shutdown()==0 and shutdown()==0,'idempotent shutdown'
  assert error()==0,'cleanup GL error'
 assert captures[0]==captures[1],'renderer rebuild changed image'
 if len(sys.argv)>2:png(sys.argv[2],captures[0],800,600)
 print(f'PASS: terrain shaders, upload, full framebuffer ({changed} terrain pixels), rebuild, invalid-shader rejection and idempotent cleanup')
finally:
 if ctx:
  shutdown();del_context(ctx)
 if w:del_window(w)
 quit_sdl()
