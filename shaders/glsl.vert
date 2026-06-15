#version 460

layout(set=1, binding=0) uniform UBO {
    mat4 proj;
};

layout(location=0) in vec2 pos;

void main() {
    gl_Position = proj * vec4(pos, 0, 1);
}
