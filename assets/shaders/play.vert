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
out float distanceXZ;
void main(){
 tint=color;texcoord=uv;
 if(hud==1){gl_Position=vec4(position,1.0);distanceXZ=0.0;return;}
 vec3 p=position-eye;
 float right=angles.y*p.x+angles.x*p.z;
 float ahead=angles.x*p.x-angles.y*p.z;
 float up=angles.w*p.y-angles.z*ahead;
 float depth=angles.z*p.y+angles.w*ahead;
 gl_Position=vec4(right*lens.y/lens.x,up*lens.y,1.0010422*depth-0.1000521,depth);
 distanceXZ=length(p.xz);
}
