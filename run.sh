glslc ./shaders/glsl.vert -o ./shaders/spv.vert
glslc ./shaders/glsl.frag -o ./shaders/spv.frag
odin run .
