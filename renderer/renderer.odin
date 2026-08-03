package renderer
import "core:image"
import _ "core:image/png"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"

Sprite_Offset :: struct {
	scale:  [2]f32,
	offset: [2]f32,
}

Vertex :: struct {
	pos:   [3]f32,
	uv:    [2]f32,
	color: [4]u8,
}

Shader_Type :: enum {
	Wireframe,
	Solid,
	Circle,
	Textured,
}

Renderer :: struct {
	device:      ^sdl.GPUDevice,
	window:      ^sdl.Window,
	render_pass: ^sdl.GPURenderPass,
	cmd_buf:     ^sdl.GPUCommandBuffer,
	pipelines:   [Shader_Type]^sdl.GPUGraphicsPipeline,
	projection:  matrix[4, 4]f32,
}

Material :: struct {
	pipeline:    ^sdl.GPUGraphicsPipeline,
	texture:     ^sdl.GPUTexture,
	sampler:     ^sdl.GPUSampler,
	solid_color: [4]f32,
}

Mesh :: struct {
	vertex_buffer: ^sdl.GPUBuffer,
	index_buffer:  ^sdl.GPUBuffer,
	num_indices:   u32,
}

vert_quad := #load("../shaders/spv_quad.vert")
frag_quad := #load("../shaders/spv_quad.frag")

vert_circle := #load("../shaders/spv_circle.vert")
frag_circle := #load("../shaders/spv_circle.frag")

frag_texture := #load("../shaders/spv_texture.frag")

init :: proc(width: i32, height: i32) -> ^Renderer {
	if !sdl.Init({.VIDEO}) do log.panicf("Could not load SDL {}", sdl.GetError())

	renderer := new(Renderer)
	renderer.window = sdl.CreateWindow("Render buzz", width, height, {})

	renderer.device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if !sdl.ClaimWindowForGPUDevice(renderer.device, renderer.window) do log.panicf("Could not claim window for GPU device {}", sdl.GetError())

	for type in Shader_Type {
		renderer.pipelines[type] = setup_pipeline(renderer, type)
	}

	world_w, world_h: f32 = f32(width / 4), f32(height / 4)
	left := -world_w / 2
	right := world_w / 2
	bottom := -world_h / 2
	top := world_h / 2

	renderer.projection = linalg.matrix_ortho3d_f32(left, right, bottom, top, 0, 1, false)

	if (!sdl.SetGPUSwapchainParameters(renderer.device, renderer.window, sdl.GPUSwapchainComposition.SDR, sdl.GPUPresentMode.VSYNC)) do return nil

	return renderer
}

destroy_renderer :: proc(r: ^Renderer) {
	for pipeline in r.pipelines {
		sdl.ReleaseGPUGraphicsPipeline(r.device, pipeline)
	}
	sdl.DestroyGPUDevice(r.device)
	sdl.DestroyWindow(r.window)
	sdl.Quit()
}

create_quad_mesh :: proc(r: ^Renderer) -> Mesh {
	vertices: []Vertex = {
		{pos = {-0.5, -0.5, 1}, uv = {0, 1}, color = {30, 30, 0, 255}},
		{pos = {0.5, -0.5, 1}, uv = {1, 1}, color = {30, 30, 0, 255}},
		{pos = {0.5, 0.5, 1}, uv = {1, 0}, color = {30, 30, 0, 255}},
		{pos = {-0.5, 0.5, 1}, uv = {0, 0}, color = {30, 30, 0, 255}},
	}

	// vertices: []Vertex = {
	// 	{pos = {-0.5, -0.5, 1}, uv = {1, 1}, color = {30, 30, 0, 255}},
	//        {pos = {0.5, -0.5, 1}, uv = {0, 1}, color = {30, 30, 0, 255}},
	// 	{pos = {0.5, 0.5, 1}, uv = {0, 0}, color = {30, 30, 0, 255}},
	// 	{pos = {-0.5, 0.5, 1}, uv = {1, 0}, color = {30, 30, 0, 255}},
	// }

	indices: []u32 = {0, 1, 2, 0, 2, 3}
	return create_mesh(r, vertices, indices)
}

create_mesh :: proc(r: ^Renderer, vertices: []Vertex, indices: []u32) -> Mesh {
	vertices_byte_size := len(vertices) * size_of(Vertex)
	indices_byte_size := len(indices) * size_of(indices[0])
	transfer_buffer_size := u32(vertices_byte_size) + u32(indices_byte_size)

	vertex_buffer := sdl.CreateGPUBuffer(
		r.device,
		{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	)

	index_buffer := sdl.CreateGPUBuffer(
		r.device,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)

	transfer_buf := sdl.CreateGPUTransferBuffer(
		r.device,
		{usage = .UPLOAD, size = transfer_buffer_size},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(r.device, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)

	index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))
	mem.copy(index_dest, raw_data(indices), indices_byte_size)

	sdl.UnmapGPUTransferBuffer(r.device, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(r.device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buf},
		{buffer = vertex_buffer, size = u32(vertices_byte_size)},
		false,
	)
	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buf, offset = u32(vertices_byte_size)},
		{buffer = index_buffer, size = u32(indices_byte_size)},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(r.device, transfer_buf)

	return Mesh {
		vertex_buffer = vertex_buffer,
		index_buffer = index_buffer,
		num_indices = u32(len(indices)),
	}
}

destroy_mesh :: proc(r: ^Renderer, mesh: Mesh) {
	sdl.ReleaseGPUBuffer(r.device, mesh.vertex_buffer)
	sdl.ReleaseGPUBuffer(r.device, mesh.index_buffer)
}

begin_frame :: proc(r: ^Renderer) -> bool {
	r.cmd_buf = sdl.AcquireGPUCommandBuffer(r.device)
	swapchain_tex: ^sdl.GPUTexture
	if !sdl.WaitAndAcquireGPUSwapchainTexture(r.cmd_buf, r.window, &swapchain_tex, nil, nil) {
		log.panicf("Coudnt aciquire the gpu texture swap chain{}", sdl.GetError())
	}
	if swapchain_tex == nil {
		if !sdl.SubmitGPUCommandBuffer(r.cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
		return false
	}

	color_target := sdl.GPUColorTargetInfo {
		texture     = swapchain_tex,
		load_op     = .CLEAR,
		clear_color = {0, 0.2, 0.4, 1},
		store_op    = .STORE,
	}

	r.render_pass = sdl.BeginGPURenderPass(r.cmd_buf, &color_target, 1, nil)

	sdl.PushGPUVertexUniformData(r.cmd_buf, 0, &r.projection, size_of(r.projection))
	return true
}

end_frame :: proc(r: ^Renderer) {
	sdl.EndGPURenderPass(r.render_pass)
	if !sdl.SubmitGPUCommandBuffer(r.cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
}

draw_sprite :: proc(
	r: ^Renderer,
	mesh: ^Mesh,
	material: ^Material,
	sprite_offset: ^Sprite_Offset,
	model_matrix: ^matrix[4, 4]f32,
) {
	sdl.BindGPUGraphicsPipeline(r.render_pass, material.pipeline)
	sdl.BindGPUVertexBuffers(
		r.render_pass,
		0,
		&(sdl.GPUBufferBinding{buffer = mesh.vertex_buffer}),
		1,
	)
	sdl.BindGPUIndexBuffer(r.render_pass, {buffer = mesh.index_buffer}, ._32BIT)
	sdl.PushGPUVertexUniformData(r.cmd_buf, 1, model_matrix, size_of(matrix[4, 4]f32))

	sdl.PushGPUVertexUniformData(r.cmd_buf, 2, sprite_offset, size_of(Sprite_Offset))
	sdl.BindGPUFragmentSamplers(
		r.render_pass,
		0,
		&(sdl.GPUTextureSamplerBinding{sampler = material.sampler, texture = material.texture}),
		1,
	)

	sdl.DrawGPUIndexedPrimitives(r.render_pass, mesh.num_indices, 1, 0, 0, 0)
}

draw_solid :: proc(
	r: ^Renderer,
	mesh: ^Mesh,
	material: ^Material,
	model_matrix: ^matrix[4, 4]f32,
) {
	sdl.BindGPUGraphicsPipeline(r.render_pass, material.pipeline)
	sdl.BindGPUVertexBuffers(
		r.render_pass,
		0,
		&(sdl.GPUBufferBinding{buffer = mesh.vertex_buffer}),
		1,
	)
	sdl.BindGPUIndexBuffer(r.render_pass, {buffer = mesh.index_buffer}, ._32BIT)
	sdl.PushGPUVertexUniformData(r.cmd_buf, 1, model_matrix, size_of(matrix[4, 4]f32))
	sdl.PushGPUFragmentUniformData(r.cmd_buf, 0, &material.solid_color, size_of([4]f32))

	sdl.DrawGPUIndexedPrimitives(r.render_pass, mesh.num_indices, 1, 0, 0, 0)
}

create_material :: proc(r: ^Renderer, solid_color: [4]f32, shader_type: Shader_Type) -> Material {
	return {pipeline = r.pipelines[shader_type], solid_color = solid_color}
}

create_texture_material :: proc(
	r: ^Renderer,
	path: string,
	pipeline: ^sdl.GPUGraphicsPipeline,
) -> Material {
	img, err := image.load_from_file(path, {.alpha_add_if_missing})
	if (err != nil) {
		log.error(err)
		return {}
	}

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

	sdl.EndGPUCopyPass(copy_pass)
	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(r.device, transfer_buf)

	sampler := sdl.CreateGPUSampler(
		r.device,
		{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	)

	return {pipeline = pipeline, texture = texture, sampler = sampler}
}

destroy_material :: proc(r: ^Renderer, mat: Material) {
	sdl.ReleaseGPUSampler(r.device, mat.sampler)
	sdl.ReleaseGPUTexture(r.device, mat.texture)
}

setup_pipeline :: proc(renderer: ^Renderer, shader_type: Shader_Type) -> ^sdl.GPUGraphicsPipeline {
	vert_shader: ^sdl.GPUShader
	frag_shader: ^sdl.GPUShader

	vertex_attributes: []sdl.GPUVertexAttribute = {
		{location = 0, buffer_slot = 0, format = .FLOAT3, offset = 0},
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
			num_uniform_buffers = 3,
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
			num_uniform_buffers = 3,
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

	case .Textured:
		vert_shader = load_shader(
			renderer.device,
			vert_quad,
			.VERTEX,
			num_uniform_buffers = 3,
			num_samplers = 0,
		)
		frag_shader = load_shader(
			renderer.device,
			frag_texture,
			.FRAGMENT,
			num_uniform_buffers = 1,
			num_samplers = 1,
		)

		pipeline = create_pipeline(renderer, vert_shader, frag_shader, vertex_attributes, .FILL)
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
					blend_state = {
						enable_blend = true,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						color_blend_op = .ADD,
						src_alpha_blendfactor = .ONE,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						alpha_blend_op = .ADD,
					},
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
