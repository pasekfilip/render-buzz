#version 460

layout(set = 1, binding = 0) uniform Proj {
    mat4 proj;
};

layout(set = 1, binding = 1) uniform Model {
    mat4 model;
};

layout(location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4 color;

layout(location = 0) out vec2 frag_uv;
layout(location = 1) out vec4 frag_color;

void main() {
    gl_Position = proj * model * vec4(pos, 0, 1);
    frag_uv = uv;
    frag_color = color;
}
