"""LOD topology, progressive spacing, shared seam profiles and source provenance."""
import ctypes as C,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64
build=lib.terrain_lod_build;build.argtypes=[P];build.restype=I
surface=lib.terrain_surface;surface.argtypes=[P,I,I,P];surface.restype=I
world=(U*12)();world[0]=42;journal=(I*32)();world[7]=C.addressof(journal)
# A saved column is visible in LOD even when outside the resident block cache.
for a,n in enumerate((72,180,8,5)):journal[a]=n
world[6]=1
colors=[(0,0,0),(.48,.51,.55),(.45,.30,.19),(.35,.52,.22),(.8,.7,.46),(.47,.32,.19),(.23,.43,.20),(.2,.21,.25)]
checks=0
for radius,cx,cz in [(32,8,8),(48,8,8),(64,8,8),(128,8,8),(4096,16000008,-15999992), (256,-29999992,29999992)]:
 buf=C.create_string_buffer(b'\xa5'*(65536*32+32),65536*32+32);cfg=(U*8)(C.addressof(world),C.addressof(buf),65536,cx & (2**64-1),cz & (2**64-1),radius,99,0)
 assert build(cfg)==0
 count=cfg[6];assert count<=65536 and count%6==0
 assert buf.raw[count*32:]==b'\xa5'*(len(buf)-count*32),'capacity/canary overwrite'
 if radius<=40:assert count==0;continue
 vertices=[struct.unpack_from('<8f',buf.raw,i*32) for i in range(count)]
 outer=64;inner=40;step=4;offset=0;levels=[];out=(C.c_uint32*2)()
 while True:
  levels.append(step)
  for z in range(-outer,outer,step):
   for x in range(-outer,outer,step):
    if -inner<=x<inner and -inner<=z<inner:continue
    corners=[(cx+x,cz+z),(cx+x+step,cz+z),(cx+x+step,cz+z+step),(cx+x,cz+z+step)]
    if any(not(-30000000<=a<30000000 and -30000000<=b<30000000) for a,b in corners):continue
    edge= (-inner<=x<inner and z in (-inner-step,inner)) or (-inner<=z<inner and x in (-inner-step,inner))
    top_count=(15 if inner==40 else 9) if edge else 6
    top=vertices[offset:offset+top_count];offset+=top_count
    for v in top:
     a,b=int(v[0]+cx-8),int(v[2]+cz-8)
     assert cx+x<=a<=cx+x+step and cz+z<=b<=cz+z+step
     assert surface(world,a,b,out)==0
     assert v[:3]==(a-cx+8,float(out[0]),b-cz+8),('non-world surface',a,b,v,out[:])
     assert all(abs(v[3+i]-colors[out[1]][i])<1e-6 for i in range(3));checks+=1
    area=0
    for i in range(0,top_count,3):
     a,b,c=top[i:i+3]
     signed=(b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2])
     assert signed>0,('winding/degenerate triangle',a,b,c)
     area+=signed
    assert area==2*step*step,('cell coverage',area,step)
    if edge:
     if z==-inner-step:a,b=corners[3],corners[2]
     elif z==inner:a,b=corners[0],corners[1]
     elif x==-inner-step:a,b=corners[1],corners[2]
     else:a,b=corners[0],corners[3]
     spacing=1 if inner==40 else step//2
     positions={(v[0],v[2]) for v in top}
     for fraction in range(0,step+1,spacing):
      px=a[0]+(b[0]-a[0])*fraction//step;pz=a[1]+(b[1]-a[1])*fraction//step
      assert (px-cx+8,pz-cz+8) in positions,'missing shared edge vertex'
     if inner==40:
      seam=vertices[offset:offset+step*6];assert len(seam)==step*6
      for segment in range(step):
       points=[]
       for fraction in (segment,segment+1):
        px=a[0]+(b[0]-a[0])*fraction//step;pz=a[1]+(b[1]-a[1])*fraction//step
        assert surface(world,px,pz,out)==0
        points.append((px-cx+8,float(out[0]),pz-cz+8))
       px,pz=points[0][0]+cx-8,points[0][2]+cz-8
       if px-cx==40:px-=1
       if pz-cz==40:pz-=1
       assert surface(world,int(px),int(pz),out)==0
       quad=points+[(points[j][0],float(out[0]),points[j][2]) for j in (1,0)]
       for v,k in zip(seam[segment*6:segment*6+6],[0,3,2,0,2,1]):
        assert v[:3]==quad[k],('block seam profiles',v,quad[k]);checks+=1
        assert abs(v[0]-8)==inner or abs(v[2]-8)==inner
      offset+=step*6
  if outer>=radius:break
  inner=outer;outer*=2;step*=2
 assert offset==count and levels==[4*2**i for i in range(len(levels))],(offset,count,levels)
 # Optional memoization must give identical geometry and retain its canary.
 expected=buf.raw[:count*32];cache=C.create_string_buffer(b'\xa5'*(360480+32),360480+32)
 cfg[7]=C.addressof(cache);assert build(cfg)==0 and cfg[6]==count and buf.raw[:count*32]==expected
 assert cache.raw[360480:]==b'\xa5'*32
 # Edges of each coarse triangle are joined to the finer edge; no buried offset.
 assert count>0
# Maximum-size canonical journals exercise the optimized renderer, including
# raised columns and removals at sampled positions, not only isolated queries.
dense=(I*(8192*4))()
for i in range(8192):
 dense[i*4:i*4+4]=(-512+(i%128)*8,72+i%120,-256+(i//128)*8,0 if i%3==0 else 5)
world[6]=8192;world[7]=C.addressof(dense)
cfg=(U*8)(C.addressof(world),C.addressof(buf),65536,8,8,256,99,0)
assert build(cfg)==0;expected=buf.raw[:cfg[6]*32];count=cfg[6]
cfg[7]=C.addressof(cache)
assert build(cfg)==0 and cfg[6]==count and buf.raw[:count*32]==expected,'dense indexed mesh differs'
assert cache.raw[360480:]==b'\xa5'*32
world[6]=1;world[7]=C.addressof(journal)
# Rejections preserve buffer and count.
buf=C.create_string_buffer(b'\xa5'*64,64);cfg=(U*8)(C.addressof(world),C.addressof(buf),2,8,8,64,123,0)
assert build(cfg)==-2 and cfg[6]==123 and buf.raw==b'\xa5'*64
cfg[2]=65536
for index,value in [(5,0),(5,4097),(3,9),(4,7)]:
 old=cfg[index];cfg[index]=value;assert build(cfg)==-1 and cfg[6]==123 and buf.raw==b'\xa5'*64;cfg[index]=old
# Invalid canonical journal rejects the whole mesh before destination mutation.
for row in [(0,256,0,1),(0,70,0,7),(30000000,70,0,1)]:
 for a,n in enumerate(row):journal[a]=n
 assert build(cfg)==-1 and cfg[6]==123 and buf.raw==b'\xa5'*64
print(f'PASS: {checks} world-derived LOD vertices, progressive rings, seam planes, far edits, limits, boundaries and canaries')
