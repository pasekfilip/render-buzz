#version 460

layout(set = 3, binding = 0) uniform Color {
    vec4 u_color;
};

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in vec4 frag_color;

layout(location = 0) out vec4 color;

void main() {
    float circle = length(frag_uv - vec2(0.5, 0.5));

    if(circle > 0.5) discard;

    color = u_color;
}
