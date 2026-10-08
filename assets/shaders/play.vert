#version 330 core
layout(location=0) in vec3 position;
layout(location=1) in vec3 color;
layout(location=2) in vec2 uv;
uniform vec3 eye;
uniform vec4 angles;
uniform vec2 lens;
uniform int hud;
out vec3 tint;
out vec2 texcoord;
out vec3 relativePosition;
out vec3 skyRay;
out vec3 lightCoord;
vec3 lightPoint(vec3 p){
 vec3 s=normalize(vec3(-0.455,0.808,-0.374));
 vec3 r=normalize(cross(vec3(0,1,0),s)),u=cross(s,r);
 p-=vec3(0,72,0);
 return vec3(dot(r,p)/64.0,dot(u,p)/96.0,-dot(s,p)/160.0);
}
void main(){
 tint=color;texcoord=uv;relativePosition=position-eye;skyRay=vec3(0.0);lightCoord=lightPoint(position)*0.5+0.5;
 if(hud==3){gl_Position=vec4(lightPoint(position),1.0);return;}
 if(hud==1 || hud==2){
  gl_Position=vec4(position,1.0);
  // Invert the same yaw/pitch and lens used by the world projection.
  float right=position.x*lens.x/lens.y;
  float up=position.y/lens.y;
  float ahead=angles.w-angles.z*up;
  skyRay=vec3(angles.y*right+angles.x*ahead,angles.w*up+angles.z,
              angles.x*right-angles.y*ahead);
  return;
 }
 vec3 p=relativePosition;
 float right=angles.y*p.x+angles.x*p.z;
 float ahead=angles.x*p.x-angles.y*p.z;
 float up=angles.w*p.y-angles.z*ahead;
 float depth=angles.z*p.y+angles.w*ahead;
 gl_Position=vec4(right*lens.y/lens.x,up*lens.y,1.0000122071*depth-0.1000006104,depth);
}
