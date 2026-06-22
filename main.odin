package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"
import "vendor:sdl3/image"

vert_shader_code := #load("./shaders/spv.vert")
frag_shader_code := #load("./shaders/spv.frag")

main :: proc() {
	context.logger = log.create_console_logger()

	if !sdl.Init({.VIDEO}) do log.panicf("Could not load SDL {}", sdl.GetError())
	defer sdl.Quit()

	width: i32 = 1280
	height: i32 = 780

	window := sdl.CreateWindow("Render buzz", width, height, {})

	gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if !sdl.ClaimWindowForGPUDevice(gpu, window) do log.panicf("Could not claim window for GPU device {}", sdl.GetError())

	vert_shader := load_shader(
		gpu,
		vert_shader_code,
		.VERTEX,
		num_uniform_buffers = 1,
		num_samplers = 0,
	)
	frag_shader := load_shader(
		gpu,
		frag_shader_code,
		.FRAGMENT,
		num_uniform_buffers = 0,
		num_samplers = 1,
	)

	Vertex :: struct {
		pos:   [2]f32,
		uv:    [2]f32,
		color: [4]u8,
	}

	UBO :: struct {
		proj:  matrix[4, 4]f32,
		model: matrix[4, 4]f32,
	}

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

	pipeline := sdl.CreateGPUGraphicsPipeline(
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

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

    world_w, world_h : f32 = 10000, 10000

	vertices: []Vertex = {
		{pos = {0, 1}, uv = {0, 1}, color = {255, 0, 0, 255}},
		{pos = {1, 1}, uv = {1, 1}, color = {0, 255, 0, 255}},
		{pos = {1, 0}, uv = {1, 0}, color = {0, 0, 255, 255}},
		{pos = {0, 0}, uv = {0, 0}, color = {255, 0, 0, 255}},
	}

	ubo: UBO = {
		proj = linalg.matrix_ortho3d_f32(0, world_w, world_h, 0, 0, 1, false),
        model = linalg.matrix4_translate_f32({ 3000, 3000, 0 }) * linalg.matrix4_scale_f32({3000, 3000, 0})
	}

	indices: []u16 = {0, 1, 2, 0, 2, 3}

	surface := image.Load("./assets/luffy-elbaph.icon")
	converted := sdl.ConvertSurface(surface, .RGBA32)
	defer sdl.DestroySurface(surface)
	defer sdl.DestroySurface(converted)

	vertices_byte_size := len(vertices) * size_of(Vertex)
	indices_byte_size := len(indices) * size_of(indices[0])
	texture_byte_size := converted.pitch * converted.h
	transfer_buffer_size :=
		u32(vertices_byte_size) + u32(indices_byte_size) + u32(texture_byte_size)

	vertex_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	)

	index_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)

	texture := sdl.CreateGPUTexture(
		gpu,
		{
			type = .D2,
			width = u32(converted.w),
			height = u32(converted.h),
			usage = {.SAMPLER},
			format = .R8G8B8A8_UNORM,
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)

	transfer_buf := sdl.CreateGPUTransferBuffer(
		gpu,
		{usage = .UPLOAD, size = transfer_buffer_size},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(gpu, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))

	mem.copy(index_dest, raw_data(indices), indices_byte_size)
	texture_dest := mem.ptr_offset((^u8)(transfer_mem), vertices_byte_size + indices_byte_size)

	mem.copy(texture_dest, converted.pixels, int(texture_byte_size))
	sdl.UnmapGPUTransferBuffer(gpu, transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
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

	sdl.UploadToGPUTexture(
		copy_pass,
		{
			transfer_buffer = transfer_buf,
			offset = u32(vertices_byte_size + indices_byte_size),
			pixels_per_row = u32(converted.w),
			rows_per_layer = u32(converted.h),
		},
		{texture = texture, w = u32(converted.w), h = u32(converted.h), d = 1, mip_level = 0},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)

	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(gpu, transfer_buf)

	sampler := sdl.CreateGPUSampler(
		gpu,
		{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	)

	main_loop: for {
		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				if ev.key.scancode == .ESCAPE do break main_loop
			}
		}

		cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
		swapchain_tex: ^sdl.GPUTexture
		if !sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_tex, nil, nil) {
			log.panicf("Coudnt aciquire the gpu texture swap chain{}", sdl.GetError())
		}
		if swapchain_tex == nil {
			if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
			continue
		}
		color_target := sdl.GPUColorTargetInfo {
			texture     = swapchain_tex,
			load_op     = .CLEAR,
			clear_color = {0, 0.2, 0.4, 1},
			store_op    = .STORE,
		}

		render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
		sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
		sdl.BindGPUVertexBuffers(
			render_pass,
			0,
			&(sdl.GPUBufferBinding{buffer = vertex_buffer}),
			1,
		)
		sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._16BIT)
		sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
		sdl.BindGPUFragmentSamplers(
			render_pass,
			0,
			&(sdl.GPUTextureSamplerBinding{sampler = sampler, texture = texture}),
			1,
		)

		sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
		sdl.EndGPURenderPass(render_pass)
		if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
	}
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
