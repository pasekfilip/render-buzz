package main

import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"

Proj :: struct {
    proj: matrix[4, 4]f32,
}

render_pass : ^sdl.GPURenderPass
current_pipeline : ^sdl.GPUGraphicsPipeline

pipelines : [Shader_Type]^sdl.GPUGraphicsPipeline

main :: proc() {
	context.logger = log.create_console_logger()

	if !sdl.Init({.VIDEO}) do log.panicf("Could not load SDL {}", sdl.GetError())
	defer sdl.Quit()

	width: i32 = 1280
	height: i32 = 780

	window = sdl.CreateWindow("Render buzz", width, height, {})

	gpu = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if !sdl.ClaimWindowForGPUDevice(gpu, window) do log.panicf("Could not claim window for GPU device {}", sdl.GetError())

    for type in Shader_Type {
        pipelines[type] = setup_pipeline(type)
    }

	world_w, world_h: f32 = f32(width * 10), f32(height * 10)

	vertices: []Vertex = {
		{pos = {-0.5, -0.5}, uv = {0, 1}, color = {255, 0, 0, 255}},
		{pos = {0.5, -0.5}, uv = {1, 1}, color = {0, 255, 0, 255}},
		{pos = {0.5, 0.5}, uv = {1, 0}, color = {0, 0, 255, 255}},
		{pos = {-0.5, 0.5}, uv = {0, 0}, color = {255, 0, 0, 255}},
	}

	proj: Proj = {
		proj = linalg.matrix_ortho3d_f32(
			-world_w / 2,
			world_w / 2,
			-world_h / 2,
			world_h / 2,
			0,
			1,
			false,
		),
	}

	tank_1: Entity = {
		translate = {0, 400, 1},
		scale     = {150, 800, 1},
		color     = {1, 0, 0, 1},
		parent    = &(Entity) {
			translate = {0, 0, 1},
			scale = {500, 1000, 1},
			color = {0, 1, 0, 1},
			parent = nil,
		},
	}
	// 12800 width
	// 7800 height

	walls: []Entity = {
		{
            translate = {-4500, 0, 1},
            scale = {150, 6000, 1},
            color = {0, 0, 0, 1}
        },
		{
            translate = {4500, 0, 1},
            scale = {150, 6000, 1},
            color = {0, 0, 0, 1}
        },
		{
            translate = {0, 3000, 1},
            scale = {9150, 150, 1},
            color = {0, 0, 0, 1}
        },
	}

    foo :: proc() {

    }

	entities: [dynamic]Entity
	bullets: [dynamic]Entity

	append(&entities, tank_1)
	for wall in walls {
		append(&entities, wall)
	}

	indices: []u16 = {0, 1, 2, 0, 2, 3}

	// surface := image.Load("./assets/luffy-elbaph.icon")
	// converted := sdl.ConvertSurface(surface, .RGBA32)
	// defer sdl.DestroySurface(surface)
	// defer sdl.DestroySurface(converted)

	vertices_byte_size := len(vertices) * size_of(Vertex)
	indices_byte_size := len(indices) * size_of(indices[0])
	// texture_byte_size := converted.pitch * converted.h
	transfer_buffer_size := u32(vertices_byte_size) + u32(indices_byte_size)

	vertex_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	)

	index_buffer := sdl.CreateGPUBuffer(
		gpu,
		{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	)

	// texture := sdl.CreateGPUTexture(
	// 	gpu,
	// 	{
	// 		type = .D2,
	// 		width = u32(converted.w),
	// 		height = u32(converted.h),
	// 		usage = {.SAMPLER},
	// 		format = .R8G8B8A8_UNORM,
	// 		layer_count_or_depth = 1,
	// 		num_levels = 1,
	// 	},
	// )

	transfer_buf := sdl.CreateGPUTransferBuffer(
		gpu,
		{usage = .UPLOAD, size = transfer_buffer_size},
	)

	transfer_mem := sdl.MapGPUTransferBuffer(gpu, transfer_buf, false)
	mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))

	mem.copy(index_dest, raw_data(indices), indices_byte_size)
	// texture_dest := mem.ptr_offset((^u8)(transfer_mem), vertices_byte_size + indices_byte_size)
	//
	// mem.copy(texture_dest, converted.pixels, int(texture_byte_size))
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

	// sdl.UploadToGPUTexture(
	// 	copy_pass,
	// 	{
	// 		transfer_buffer = transfer_buf,
	// 		offset = u32(vertices_byte_size + indices_byte_size),
	// 		pixels_per_row = u32(converted.w),
	// 		rows_per_layer = u32(converted.h),
	// 	},
	// 	{texture = texture, w = u32(converted.w), h = u32(converted.h), d = 1, mip_level = 0},
	// 	false,
	// )

	sdl.EndGPUCopyPass(copy_pass)

	if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
		log.panicf("Could not submit command buffer {}", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(gpu, transfer_buf)

	// sampler := sdl.CreateGPUSampler(
	// 	gpu,
	// 	{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	// )


	last_tick: u64
	rotating := false
	speed: f32 = 2000
	rotate_speed: f32 = 2
	main_loop: for {
		delta_af := f32(sdl.GetTicks() - last_tick) / 1000
		last_tick = sdl.GetTicks()

		move_x := -linalg.sin(entities[0].parent.angle)
		move_y := linalg.cos(entities[0].parent.angle)
		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				if ev.key.scancode == .ESCAPE do break main_loop
				if ev.key.scancode == .SPACE {
					bullet: Entity = {
						scale = {150, 150, 1},
						color = {0, 0, 1, 1},
                        material = {
                            pipeline = pipelines[.Circle]
                        }
					}
					bullet.translate.x += entities[0].parent.translate.x + move_x * 800
					bullet.translate.y += entities[0].parent.translate.y + move_y * 800
					bullet.angle = entities[0].parent.angle
					append(&bullets, bullet)
				}
			}
		}

		keys := sdl.GetKeyboardState(nil)
		if keys[sdl.Scancode.D] {
			// rotating = true
			entities[0].parent.angle -= rotate_speed * delta_af
		}
		if keys[sdl.Scancode.A] {
			// rotating = true
			entities[0].parent.angle += rotate_speed * delta_af
		}
		if keys[sdl.Scancode.W] && !rotating {
			entities[0].parent.translate.x += (speed * move_x) * delta_af
			entities[0].parent.translate.y += (speed * move_y) * delta_af
		}
		if keys[sdl.Scancode.S] && !rotating {
			entities[0].parent.translate.x -= (speed * move_x) * delta_af
			entities[0].parent.translate.y -= (speed * move_y) * delta_af
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
		sdl.BindGPUGraphicsPipeline(render_pass, pipelines[.Solid])
		sdl.BindGPUVertexBuffers(
			render_pass,
			0,
			&(sdl.GPUBufferBinding{buffer = vertex_buffer}),
			1,
		)
		sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._16BIT)

		sdl.PushGPUVertexUniformData(cmd_buf, 0, &proj, size_of(Proj))

		for &entity in entities {
			draw_entity(render_pass, cmd_buf, &entity)
		}

		for &bullet in bullets {
			bullet.translate.x += -linalg.sin(bullet.angle) * speed * delta_af
			bullet.translate.y += linalg.cos(bullet.angle) * speed * delta_af
			draw_entity(render_pass, cmd_buf, &bullet)
		}

		// sdl.BindGPUFragmentSamplers(
		// 	render_pass,
		// 	0,
		// 	&(sdl.GPUTextureSamplerBinding{sampler = sampler, texture = texture}),
		// 	1,
		// )

		sdl.EndGPURenderPass(render_pass)
		if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
	}
}

