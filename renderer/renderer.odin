package renderer
import "core:image"
import _ "core:image/jpeg"
import "core:log"
import "core:mem"
import sdl "vendor:sdl3"

Vertex :: struct {
	pos:   [2]f32,
	uv:    [2]f32,
	color: [4]u8,
}

Shader_Type :: enum {
	Wireframe,
	Solid,
	Circle,
}

Renderer :: struct {
	device:      ^sdl.GPUDevice,
	window:      ^sdl.Window,
	render_pass: ^sdl.GPURenderPass,
	pipelines:   [Shader_Type]^sdl.GPUGraphicsPipeline,
}

Material :: struct {
	pipeline: ^sdl.GPUGraphicsPipeline,
}

vert_quad := #load("../shaders/spv_quad.vert")
frag_quad := #load("../shaders/spv_quad.frag")

vert_circle := #load("../shaders/spv_circle.vert")
frag_circle := #load("../shaders/spv_circle.frag")

init :: proc(width: i32, height: i32) -> ^Renderer {
	renderer := new(Renderer)
	renderer.window = sdl.CreateWindow("Render buzz", width, height, {})

	renderer.device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if !sdl.ClaimWindowForGPUDevice(renderer.device, renderer.window) do log.panicf("Could not claim window for GPU device {}", sdl.GetError())

	for type in Shader_Type {
		renderer.pipelines[type] = setup_pipeline(renderer, type)
	}

	if (!sdl.SetGPUSwapchainParameters(renderer.device, renderer.window, sdl.GPUSwapchainComposition.SDR, sdl.GPUPresentMode.VSYNC)) do return nil

	return renderer
}

load_texture :: proc(r: ^Renderer, path: string) -> ^sdl.GPUTexture {
	img, err := image.load_from_file(path, {.alpha_add_if_missing})
    log.error(err)

	texture := sdl.CreateGPUTexture(
		r.device,
		{
			type = .D2,
			width = u32(img.width),
			height = u32(img.height),
			usage = {.SAMPLER},
			format = .R8G8B8A8_UNORM,
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)
	texture_byte_size := img.width * img.height * 4

	transfer_buf := sdl.CreateGPUTransferBuffer(
		r.device,
		{usage = .UPLOAD, size = u32(img.width * img.height * 4)},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(r.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(img.pixels.buf), int(texture_byte_size))

	sdl.UnmapGPUTransferBuffer(r.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(r.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(
		copy_pass,
		{
			transfer_buffer = transfer_buf,
			pixels_per_row = u32(img.width),
			rows_per_layer = u32(img.height),
		},
		{texture = texture, w = u32(img.width), h = u32(img.height), d = 1, mip_level = 0},
		false,
	)

	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(r.device, transfer_buf)
	sdl.EndGPUCopyPass(copy_pass)

	return texture
}

setup_pipeline :: proc(renderer: ^Renderer, shader_type: Shader_Type) -> ^sdl.GPUGraphicsPipeline {
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

	pipeline: ^sdl.GPUGraphicsPipeline

	switch (shader_type) {
	case .Solid:
		vert_shader = load_shader(
			renderer.device,
			vert_quad,
			.VERTEX,
			num_uniform_buffers = 2,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			renderer.device,
			frag_quad,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 0,
		)

		pipeline = create_pipeline(renderer, vert_shader, frag_shader, vertex_attributes, .FILL)
		break
	case .Circle:
		vert_shader = load_shader(
			renderer.device,
			vert_circle,
			.VERTEX,
			num_uniform_buffers = 2,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			renderer.device,
			frag_circle,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 0,
		)

		pipeline = create_pipeline(renderer, vert_shader, frag_shader, vertex_attributes, .FILL)
		break
	case .Wireframe:
		vert_shader = load_shader(
			renderer.device,
			vert_quad,
			.VERTEX,
			num_uniform_buffers = 2,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			renderer.device,
			frag_quad,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 0,
		)

		pipeline = create_pipeline(renderer, vert_shader, frag_shader, vertex_attributes, .LINE)
		break
	}

	sdl.ReleaseGPUShader(renderer.device, vert_shader)
	sdl.ReleaseGPUShader(renderer.device, frag_shader)

	return pipeline
}

create_pipeline :: proc(
	renderer: ^Renderer,
	vert_shader: ^sdl.GPUShader,
	frag_shader: ^sdl.GPUShader,
	vertex_attributes: []sdl.GPUVertexAttribute,
	fill_mode: sdl.GPUFillMode,
) -> ^sdl.GPUGraphicsPipeline {
	return sdl.CreateGPUGraphicsPipeline(
		renderer.device,
		{
			vertex_shader = vert_shader,
			fragment_shader = frag_shader,
			primitive_type = .TRIANGLELIST,
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &(sdl.GPUColorTargetDescription) {
					format = sdl.GetGPUSwapchainTextureFormat(renderer.device, renderer.window),
				},
			},
			rasterizer_state = {fill_mode = fill_mode},
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
	device: ^sdl.GPUDevice,
	code: []u8,
	stage: sdl.GPUShaderStage,
	num_uniform_buffers: u32,
	num_samplers: u32,
) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(
		device,
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
