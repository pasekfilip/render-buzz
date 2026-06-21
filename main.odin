package main

import "core:fmt"
import "vendor:sdl3/image"
import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"

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

	vert_shader := load_shader(gpu, vert_shader_code, .VERTEX, 1)
	frag_shader := load_shader(gpu, frag_shader_code, .FRAGMENT, 0)

	Vertex :: struct {
		pos:   [2]f32,
		uv:    [2]f32,
		color: [4]u8,
	}

	UBO :: struct {
		proj: matrix[4, 4]f32,
	}

    vertex_attributes : []sdl.GPUVertexAttribute = 
    {
        {
            location = 0,
            buffer_slot = 0,
            format = .FLOAT2,
            offset = 0,
        },
        {
            location = 1,
            buffer_slot = 0,
            format = .FLOAT2,
            offset = u32(offset_of(Vertex, uv))
        },
        {
            location = 2,
            buffer_slot = 0,
            format = .UBYTE4_NORM,
            offset = u32(offset_of(Vertex, color))
        }
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
				vertex_buffer_descriptions = raw_data([]sdl.GPUVertexBufferDescription { 
                    {
                        slot = 0,
                        pitch = size_of(Vertex),
                        input_rate = .VERTEX,
                        instance_step_rate = 0
                    }
				}),
				num_vertex_buffers = 1,
				num_vertex_attributes = u32(len(vertex_attributes)),
				vertex_attributes = raw_data(vertex_attributes)
			},
		},
	)

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)


	w, h := f32(width), f32(height)
	ubo: UBO = {
		proj = linalg.matrix_ortho3d_f32(0, w, h, 0, 0, 1, false),
	}

	vertices: []Vertex = {
        { pos = { 320, 585 }, uv = { 0, 1 },  color = { 255, 0, 0, 255 }},
        { pos = { 960, 585 }, uv = { 1, 1 },  color = { 0, 255, 0, 255 }},
        { pos = { 960, 195 }, uv = { 1, 0 },  color = { 0, 0, 255, 255 }},
        { pos = { 320, 195 }, uv = { 0, 0 },  color = { 255, 0, 0, 255 }},
    }

	indices: []u16 = {0, 1, 2, 0, 2, 3}

    surface := image.Load("./assets/luffy-elbaph.icon")
    fmt.println(surface.format)
    converted := sdl.ConvertSurface(surface, .RGBA32)
    defer sdl.DestroySurface(surface)
    defer sdl.DestroySurface(converted)

	vertices_byte_size := len(vertices) * size_of(Vertex)
	indices_byte_size := len(indices) * size_of(indices[0])

	vertex_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	)

	index_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)

	transfer_buf := sdl.CreateGPUTransferBuffer(
		gpu,
		{usage = .UPLOAD, size = u32(vertices_byte_size) + u32(indices_byte_size)},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(gpu, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))

	mem.copy(index_dest, raw_data(indices), indices_byte_size)
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

	sdl.EndGPUCopyPass(copy_pass)

	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(gpu, transfer_buf)

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

		sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
		sdl.BindGPUVertexBuffers(
			render_pass,
			0,
			&(sdl.GPUBufferBinding{buffer = vertex_buffer}),
			1,
		)
		sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._16BIT)

		sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
		sdl.EndGPURenderPass(render_pass)
		if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
	}
}

load_shader :: proc(
	device: ^sdl.GPUDevice,
	code: []u8,
	stage: sdl.GPUShaderStage,
	num_uniform_buffer: u32,
) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(
		device,
		{
			code_size = len(code),
			code = raw_data(code),
			entrypoint = "main",
			format = {.SPIRV},
			stage = stage,
			num_uniform_buffers = num_uniform_buffer,
		},
	)
}
