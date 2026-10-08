#version 330 core
in vec3 tint;
in vec2 texcoord;
in vec3 relativePosition;
in vec3 skyRay;
uniform vec3 eye;
uniform sampler2D atlas;
uniform sampler2D shadowMap;
in vec3 lightCoord;
uniform int hud;
uniform int quality;
out vec4 fragmentColor;
const vec3 sun=normalize(vec3(-0.455,0.808,-0.374));
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),
            mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
vec3 sky(vec3 ray,bool clouds){
 float elevation=max(ray.y,0.0);
 vec3 c=mix(vec3(0.53,0.45,0.70),vec3(0.07,0.13,0.40),pow(elevation,0.55));
 float facing=max(dot(ray,sun),0.0);
 c+=vec3(1.0,0.71,0.36)*(pow(facing,24.0)*0.13+smoothstep(0.9991,0.9996,facing)*1.7);
 if(clouds && quality>0 && ray.y>0.025){
  vec2 p=ray.xz/ray.y*2.2+vec2(7.1,3.8);
  float n=noise(p)*0.65+noise(p*2.03)*0.25;
  if(quality==2)n+=noise(p*4.09)*0.10;
  float cover=smoothstep(0.49,0.70,n)*smoothstep(0.025,0.18,ray.y);
  c=mix(c,mix(vec3(0.51,0.49,0.68),vec3(1.0,0.85,0.83),n),cover*0.88);
 }
 return c;
}
vec3 display(vec3 linearColor){
 // Bounded filmic shoulder, followed by linear-to-display conversion.
 vec3 mapped=linearColor*(2.51*linearColor+0.03)/(linearColor*(2.43*linearColor+0.59)+0.14);
 return pow(clamp(mapped,0.0,1.0),vec3(1.0/2.2));
}
float sunlight(float diffuse){
 if(quality==0 || any(lessThan(lightCoord,vec3(0))) || any(greaterThan(lightCoord,vec3(1))))return 1.0;
 float bias=max(0.00018,0.0012*(1.0-diffuse));
 float visibility=0.0;
 if(quality==1){
  for(int y=0;y<2;y++)for(int x=0;x<2;x++)
   visibility+=step(lightCoord.z-bias,texture(shadowMap,lightCoord.xy+(vec2(x,y)-0.5)/1024.0).r);
  return visibility*0.25;
 }
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++)
  visibility+=step(lightCoord.z-bias,texture(shadowMap,lightCoord.xy+vec2(x,y)/1024.0).r);
 return visibility/9.0;
}
void main(){
 if(hud==2){fragmentColor=vec4(display(sky(normalize(skyRay),true)),1.0);return;}
 vec4 sampleColor=texcoord.x<0.0?vec4(1.0):texture(atlas,texcoord);
 if(sampleColor.a<0.5)discard;
 if(hud==3){fragmentColor=vec4(1.0);return;}
 // UI and the selection outline retain legible, unlit colors.
 if(hud==1 || texcoord.x<0.0){fragmentColor=vec4(tint*sampleColor.rgb,1.0);return;}
 vec3 normal=normalize(cross(dFdx(relativePosition),dFdy(relativePosition)));
 if(!gl_FrontFacing)normal=-normal;
 vec3 albedo=pow(sampleColor.rgb,vec3(2.2));
 float diffuse=max(dot(normal,sun),0.0);
 vec3 ambient=mix(vec3(0.16,0.18,0.22),vec3(0.35,0.43,0.54),normal.y*0.5+0.5);
 vec3 rgb=albedo*(ambient+vec3(1.0,0.85,0.66)*diffuse*sunlight(diffuse)*1.15);
 float distanceXZ=length(relativePosition.xz);
 float fog=smoothstep(18.0,32.0,distanceXZ);
 if(quality>0){
  // Low-altitude haze adds depth without obscuring nearby mining targets.
  float haze=(1.0-exp(-distanceXZ*0.008))*exp(-max(relativePosition.y,0.0)*0.03);
  fog=max(fog,haze*0.45);
 }
 rgb=mix(rgb,sky(normalize(relativePosition),false),fog);
 fragmentColor=vec4(display(rgb),1.0);
}
