package main

import "core:log"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "renderer"
import sdl "vendor:sdl3"

Proj :: struct {
	proj: matrix[4, 4]f32,
}

main :: proc() {
	context.logger = log.create_console_logger()

	if !sdl.Init({.VIDEO}) do log.panicf("Could not load SDL {}", sdl.GetError())
	defer sdl.Quit()

	width: i32 = 1280
	height: i32 = 780

    r := renderer.init(width, height)

    texture := renderer.load_texture(r, "./assets/luffy-elbaph.jpg")

	world_w, world_h: f32 = f32(width * 10), f32(height * 10)
	left := -world_w / 2
	right := world_w / 2
	bottom := -world_h / 2
	top := world_h / 2


	// vertices: []Vertex = {
	// 	{pos = {-0.5, -0.5}, uv = {0, 1}, color = {255, 0, 0, 255}},
	// 	{pos = {0.5, -0.5}, uv = {1, 1}, color = {0, 255, 0, 255}},
	// 	{pos = {0.5, 0.5}, uv = {1, 0}, color = {0, 0, 255, 255}},
	// 	{pos = {-0.5, 0.5}, uv = {0, 0}, color = {255, 0, 0, 255}},
	// }
	//
	// proj: Proj = {
	// 	proj = linalg.matrix_ortho3d_f32(left, right, bottom, top, 0, 1, false),
	// }
	//
	// // 12800 x 7800
	//
	// move_player_1 :: proc(e: ^Entity, dt: f32) {
	// 	keys := sdl.GetKeyboardState(nil)
	// 	if keys[sdl.Scancode.W] {
	// 		e.translate.y += e.velocity.y * dt
	// 	}
	// 	if keys[sdl.Scancode.S] {
	// 		e.translate.y -= e.velocity.y * dt
	// 	}
	//
	// 	e.collision = {
	// 		min_x = e.translate.x - e.scale.x / 2,
	// 		max_x = e.translate.x + e.scale.x / 2,
	// 		min_y = e.translate.y - e.scale.y / 2,
	// 		max_y = e.translate.y + e.scale.y / 2,
	// 	}
	// }
	//
	// move_player_2 :: proc(e: ^Entity, dt: f32) {
	// 	keys := sdl.GetKeyboardState(nil)
	// 	if keys[sdl.Scancode.UP] {
	// 		e.translate.y += e.velocity.y * dt
	// 	}
	// 	if keys[sdl.Scancode.DOWN] {
	// 		e.translate.y -= e.velocity.y * dt
	// 	}
	//
	// 	e.collision = {
	// 		min_x = e.translate.x - e.scale.x / 2,
	// 		max_x = e.translate.x + e.scale.x / 2,
	// 		min_y = e.translate.y - e.scale.y / 2,
	// 		max_y = e.translate.y + e.scale.y / 2,
	// 	}
	// }
	//
	// move_ball :: proc(e: ^Entity, dt: f32) {
	// 	e.translate.x += e.velocity.x * dt
	// 	e.translate.y += e.velocity.y * dt
	//
	// 	e.collision = {
	// 		min_x = e.translate.x - e.scale.x / 2,
	// 		max_x = e.translate.x + e.scale.x / 2,
	// 		min_y = e.translate.y - e.scale.y / 2,
	// 		max_y = e.translate.y + e.scale.y / 2,
	// 	}
	// }
	//
	// player_1: Entity = {
	// 	translate = {-6200, 0, 1},
	// 	scale = {100, 1000, 1},
	// 	color = {1, 0, 0, 1},
	// 	material = {pipeline = pipelines[.Solid]},
	// 	update = move_player_1,
	// 	velocity = {0, 3000},
	// }
	//
	// player_2: Entity = {
	// 	translate = {6200, 0, 1},
	// 	scale = {100, 1000, 1},
	// 	color = {1, 0, 0, 1},
	// 	material = {pipeline = pipelines[.Solid]},
	// 	update = move_player_2,
	// 	velocity = {0, 3000},
	// }
	//
	// give_ball :: proc() -> ^Entity {
	// 	ball := new(Entity)
	// 	ball^ = Entity {
	// 		translate = {0, 0, 1},
	// 		scale = {150, 150, 1},
	// 		color = {0, 0, 1, 1},
	// 		material = {pipeline = pipelines[.Circle]},
	// 		update = move_ball,
	// 		velocity = {-4000 * rand.choice([]f32{-1, 1}), rand.float32_range(-1000, 1000)},
	// 	}
	//
	// 	return ball
	// }
	//
	//
	// collisions: []Entity = {
	// 	{
	// 		translate = {-4500, 0, 1},
	// 		scale = {300, 6000, 1},
	// 		color = {1, 0, 0, 1},
	// 		material = {pipeline = pipelines[.Wireframe]},
	// 	},
	// }
	//
	// indices: []u16 = {0, 1, 2, 0, 2, 3}
	//
	// solid_mat_e: []^Entity = {&player_1, &player_2}
	//
	// circle_mat_e: [dynamic]^Entity
	// append(&circle_mat_e, give_ball())
	//
	// vertices_byte_size := len(vertices) * size_of(Vertex)
	// indices_byte_size := len(indices) * size_of(indices[0])
	// transfer_buffer_size := u32(vertices_byte_size) + u32(indices_byte_size)
	//
	// vertex_buffer := sdl.CreateGPUBuffer(
	// 	renderer.device,
	// 	{props = 0, size = u32(vertices_byte_size), usage = {.VERTEX}},
	// )
	//
	// index_buffer := sdl.CreateGPUBuffer(
	// 	renderer.device,
	// 	{props = 0, size = u32(indices_byte_size), usage = {.INDEX}},
	// )
	//
	// transfer_buf := sdl.CreateGPUTransferBuffer(
	// 	renderer.device,
	// 	{usage = .UPLOAD, size = transfer_buffer_size},
	// )
	//
	// transfer_mem := sdl.MapGPUTransferBuffer(renderer.device, transfer_buf, false)
	// mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	// index_dest := mem.ptr_offset((^Vertex)(transfer_mem), len(vertices))
	//
	// mem.copy(index_dest, raw_data(indices), indices_byte_size)
	// // texture_dest := mem.ptr_offset((^u8)(transfer_mem), vertices_byte_size + indices_byte_size)
	// //
	// sdl.UnmapGPUTransferBuffer(renderer.device, transfer_buf)
	//
	// copy_cmd_buf := sdl.AcquireGPUCommandBuffer(renderer.device)
	// copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	//
	// sdl.UploadToGPUBuffer(
	// 	copy_pass,
	// 	{transfer_buffer = transfer_buf},
	// 	{buffer = vertex_buffer, size = u32(vertices_byte_size)},
	// 	false,
	// )
	//
	// sdl.UploadToGPUBuffer(
	// 	copy_pass,
	// 	{transfer_buffer = transfer_buf, offset = u32(vertices_byte_size)},
	// 	{buffer = index_buffer, size = u32(indices_byte_size)},
	// 	false,
	// )
	//
	// sdl.EndGPUCopyPass(copy_pass)
	//
	// if !sdl.SubmitGPUCommandBuffer(copy_cmd_buf) {
	// 	log.panicf("Could not submit command buffer {}", sdl.GetError())
	// }
	//
	// sdl.ReleaseGPUTransferBuffer(renderer.device, transfer_buf)
	//
	// // sampler := sdl.CreateGPUSampler(
	// // 	gpu,
	// // 	{min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST},
	// // )
	//
	// last_tick: u64
	// rotating := false
	// main_loop: for {
	// 	delta_af := f32(sdl.GetTicks() - last_tick) / 1000
	// 	last_tick = sdl.GetTicks()
	//
	// 	ev: sdl.Event
	// 	for sdl.PollEvent(&ev) {
	// 		#partial switch ev.type {
	// 		case .QUIT:
	// 			break main_loop
	// 		case .KEY_DOWN:
	// 			if ev.key.scancode == .ESCAPE do break main_loop
	// 			if ev.key.scancode == .R {
	// 				append(&circle_mat_e, give_ball())
	// 			}
	// 		}
	// 	}
	//
	// 	cmd_buf := sdl.AcquireGPUCommandBuffer(renderer.device)
	// 	swapchain_tex: ^sdl.GPUTexture
	// 	if !sdl.WaitAndAcquireGPUSwapchainTexture(
	// 		cmd_buf,
	// 		renderer.window,
	// 		&swapchain_tex,
	// 		nil,
	// 		nil,
	// 	) {
	// 		log.panicf("Coudnt aciquire the gpu texture swap chain{}", sdl.GetError())
	// 	}
	// 	if swapchain_tex == nil {
	// 		if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
	// 		continue
	// 	}
	// 	color_target := sdl.GPUColorTargetInfo {
	// 		texture     = swapchain_tex,
	// 		load_op     = .CLEAR,
	// 		clear_color = {0, 0.2, 0.4, 1},
	// 		store_op    = .STORE,
	// 	}
	//
	// 	render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
	// 	sdl.BindGPUVertexBuffers(
	// 		render_pass,
	// 		0,
	// 		&(sdl.GPUBufferBinding{buffer = vertex_buffer}),
	// 		1,
	// 	)
	// 	sdl.BindGPUIndexBuffer(render_pass, {buffer = index_buffer}, ._16BIT)
	//
	// 	sdl.PushGPUVertexUniformData(cmd_buf, 0, &proj, size_of(Proj))
	//
	// 	for entity in solid_mat_e {
	// 		entity.update(entity, delta_af)
	// 		draw_entity(render_pass, cmd_buf, entity)
	// 	}
	//
	// 	for entity in circle_mat_e {
	// 		entity.update(entity, delta_af)
	// 		draw_entity(render_pass, cmd_buf, entity)
	// 	}
	//
	// 	for &collision in collisions {
	// 		draw_entity(render_pass, cmd_buf, &collision)
	// 	}
	//
	// 	for paddle in solid_mat_e {
	// 		for ball in circle_mat_e {
	// 			paddle_collision :=
	// 				ball.collision.max_x >= paddle.collision.min_x &&
	// 				paddle.collision.max_x >= ball.collision.min_x &&
	// 				ball.collision.max_y >= paddle.collision.min_y &&
	// 				paddle.collision.max_y >= ball.collision.min_y
	//
	// 			wall_collision :=
	// 				(ball.collision.max_y >= top && ball.velocity.y > 0) ||
	// 				(bottom >= ball.collision.min_y && ball.velocity.y < 0)
	//
	//
	// 			if (paddle_collision) {
	// 				as_fuck := ball.translate.y - paddle.translate.y
	// 				ball.velocity.x *= -1.1
	// 				ball.velocity.y += as_fuck * 3
	// 			}
	//
	// 			if (wall_collision) {
	// 				ball.velocity.y *= -1.3
	// 			}
	// 		}
	// 	}
	//
	// 	// sdl.BindGPUFragmentSamplers(
	// 	// 	render_pass,
	// 	// 	0,
	// 	// 	&(sdl.GPUTextureSamplerBinding{sampler = sampler, texture = texture}),
	// 	// 	1,
	// 	// )
	//
	// 	sdl.EndGPURenderPass(render_pass)
	// 	if !sdl.SubmitGPUCommandBuffer(cmd_buf) do log.panicf("Could not submit command buffer {}", sdl.GetError())
	// }
}
