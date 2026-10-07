#version 330 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec3 vertexColor;
uniform vec3 cameraPan;
uniform vec2 cameraTurn; // sin(yaw), cos(yaw)
uniform vec2 cameraLens; // vertical half-size, drawable aspect
void main() {
    vec3 p = position - vec3(16.0, 8.0, 16.0) - cameraPan;
    float right = cameraTurn.y*p.x - cameraTurn.x*p.z;
    float forward = cameraTurn.x*p.x + cameraTurn.y*p.z;
    float up = 0.8660254*p.y + 0.5*forward;
    float depth = 0.8660254*forward - 0.5*p.y;
    gl_Position = vec4(right/(cameraLens.x*cameraLens.y),
                       up/cameraLens.x, depth/100.0, 1.0);
    vertexColor = color;
}
