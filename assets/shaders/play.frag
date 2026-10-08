#version 330 core
in vec3 tint;
in vec2 texcoord;
in float distanceXZ;
uniform sampler2D atlas;
uniform int hud;
out vec4 fragmentColor;
void main(){
 vec4 sampleColor=texcoord.x<0.0?vec4(1.0):texture(atlas,texcoord);
 if(sampleColor.a<0.5)discard;
 vec3 rgb=tint*sampleColor.rgb;
 if(hud==0)rgb=mix(rgb,vec3(0.55,0.75,0.94),smoothstep(24.0,32.0,distanceXZ));
 fragmentColor=vec4(rgb,1.0);
}
