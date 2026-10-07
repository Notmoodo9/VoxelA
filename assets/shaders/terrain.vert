#version 330 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec3 vertexColor;
void main() {
    vec3 p = position - vec3(16.0, 8.0, 16.0);
    gl_Position = vec4((p.x-p.z)/38.0,
                       (p.y*1.2+(p.x+p.z)*0.35)/25.0,
                       (p.x+p.z-p.y*0.5833333)/100.0, 1.0);
    vertexColor = color;
}
