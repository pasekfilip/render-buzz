package main
import sdl "vendor:sdl3"

Vertex :: struct {
	pos:   [2]f32,
	uv:    [2]f32,
	color: [4]u8,
}

Material :: struct {
    pipeline : ^sdl.GPUGraphicsPipeline
}

Shader_Type :: enum {
	Wireframe,
	Solid,
	Circle,
}

gpu: ^sdl.GPUDevice
window: ^sdl.Window

vert_quad := #load("./shaders/spv_quad.vert")
frag_quad := #load("./shaders/spv_quad.frag")

vert_circle := #load("./shaders/spv_circle.vert")
frag_circle := #load("./shaders/spv_circle.frag")

setup_pipeline :: proc(shader_type: Shader_Type) -> ^sdl.GPUGraphicsPipeline {
	vert_shader: ^sdl.GPUShader
	frag_shader: ^sdl.GPUShader

	vertex_attributes: []sdl.GPUVertexAttribute = {
		{location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0},
		{location = 1, buffer_slot = 0, format = .FLOAT2, offset = u32(offset_of(Vertex, uv))},
		{
			location = 2,
			buffer_slot = 0,
			format = .UBYTE4_NORM,
			offset = u32(offset_of(Vertex, color)),
		},
	}

    pipeline : ^sdl.GPUGraphicsPipeline

	switch (shader_type) {
	case .Solid:
		vert_shader = load_shader(vert_quad, .VERTEX, num_uniform_buffers = 2, num_samplers = 0)
		frag_shader = load_shader(frag_quad, .FRAGMENT, num_uniform_buffers = 1, num_samplers = 0)

        pipeline = create_pipeline(vert_shader, frag_shader, vertex_attributes)
        break
    case .Circle:
        vert_shader = load_shader(vert_circle, .VERTEX, num_uniform_buffers = 2, num_samplers = 0)
        frag_shader = load_shader(
            frag_circle,
            .FRAGMENT,
            num_uniform_buffers = 1,
            num_samplers = 0,
        )

        pipeline = create_pipeline(vert_shader, frag_shader, vertex_attributes)
        break
    case .Wireframe:
        vert_shader = load_shader(vert_circle, .VERTEX, num_uniform_buffers = 2, num_samplers = 0)
        frag_shader = load_shader(
			frag_circle,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 0,
		)

        pipeline = create_pipeline(vert_shader, frag_shader, vertex_attributes)
		break
	}

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	return pipeline
}

create_pipeline :: proc(vert_shader : ^sdl.GPUShader, frag_shader : ^sdl.GPUShader, vertex_attributes : []sdl.GPUVertexAttribute) -> ^sdl.GPUGraphicsPipeline{
    return sdl.CreateGPUGraphicsPipeline(
        gpu,
        {
            vertex_shader = vert_shader,
            fragment_shader = frag_shader,
            primitive_type = .TRIANGLELIST,
            target_info = {
                num_color_targets = 1,
                color_target_descriptions = &(sdl.GPUColorTargetDescription) {
                    format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
                },
            },
            vertex_input_state = {
                vertex_buffer_descriptions = raw_data(
                    []sdl.GPUVertexBufferDescription {
                        {
                            slot = 0,
                            pitch = size_of(Vertex),
                            input_rate = .VERTEX,
                            instance_step_rate = 0,
                        },
                    },
                ),
                num_vertex_buffers = 1,
                num_vertex_attributes = u32(len(vertex_attributes)),
                vertex_attributes = raw_data(vertex_attributes),
            },
        },
    )
}

load_shader :: proc(
	code: []u8,
	stage: sdl.GPUShaderStage,
	num_uniform_buffers: u32,
	num_samplers: u32,
) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(
		gpu,
		{
			code_size = len(code),
			code = raw_data(code),
			entrypoint = "main",
			format = {.SPIRV},
			stage = stage,
			num_uniform_buffers = num_uniform_buffers,
			num_samplers = num_samplers,
		},
	)
}
