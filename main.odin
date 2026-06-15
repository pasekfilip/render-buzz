package main

import "core:mem"
import "core:log"
import "core:math/linalg"
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

    Vec2 :: [2]f32

    vertex_buffer_descriptions := sdl.GPUVertexBufferDescription {
        slot = 0,
        pitch = size_of(Vec2),
        input_rate = .VERTEX,
        instance_step_rate = 0
    }
    vertex_attributes := sdl.GPUVertexAttribute {
        location = 0,
        buffer_slot = 0,
        format = .FLOAT2,
        offset = 0
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
                vertex_buffer_descriptions = &vertex_buffer_descriptions,
                num_vertex_buffers = 1,
                vertex_attributes = &vertex_attributes,
                num_vertex_attributes = 1
            },
		},
	)

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	UBO :: struct {
		proj: matrix[4, 4]f32,
	}

    w, h := f32(width), f32(height)
    ubo: UBO = {
        proj = linalg.matrix_ortho3d_f32(0, w, h, 0, 0, 1, false)
    }
    
    vertices : []Vec2 = {
        { 0, 390 },
        { 640, 0 },
        { 1280, 390 }
    }

    vertices_byte_size := len(vertices) * size_of(vertices[0])

    vertex_buffer := sdl.CreateGPUBuffer(gpu, {
        props = 0,
        size = u32(vertices_byte_size),
        usage = {.VERTEX}
    })

    transfer_buf := sdl.CreateGPUTransferBuffer(gpu,{
        usage = .UPLOAD,
        size = u32(vertices_byte_size),
    })

    transfer_mem := sdl.MapGPUTransferBuffer(gpu, transfer_buf, false)
    mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
    sdl.UnmapGPUTransferBuffer(gpu, transfer_buf)

    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
    copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

    sdl.UploadToGPUBuffer(copy_pass,
        {transfer_buffer = transfer_buf},
        {buffer = vertex_buffer, size = u32(vertices_byte_size)},
        false
    )

    sdl.EndGPUCopyPass(copy_pass)

    if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())

    sdl.ReleaseGPUTransferBuffer(gpu, transfer_buf)
    // begin copy pass
    // invoke upload commands
    // end copy pass and sumbit

	main_loop: for {
		// process events
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
        sdl.BindGPUVertexBuffers(render_pass, 0, &(sdl.GPUBufferBinding {buffer = vertex_buffer}), 1)
		sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
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
