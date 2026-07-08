package main

import "core:log"
import "core:math/linalg"
import "renderer"
import sdl "vendor:sdl3"

main :: proc() {
	context.logger = log.create_console_logger()

	width: i32 = 1280
	height: i32 = 780
    r := renderer.init(width, height)
    defer renderer.destroy(r)

    texture := renderer.load_texture(r, "./assets/random_solider.png")

	move_player_1 :: proc(e: ^Entity, dt: f32) {
		keys := sdl.GetKeyboardState(nil)
		if keys[sdl.Scancode.W] {
			e.translate.y += e.velocity.y * dt
		}
		if keys[sdl.Scancode.S] {
			e.translate.y -= e.velocity.y * dt
		}

		e.collision = {
			min_x = e.translate.x - e.scale.x / 2,
			max_x = e.translate.x + e.scale.x / 2,
			min_y = e.translate.y - e.scale.y / 2,
			max_y = e.translate.y + e.scale.y / 2,
		}
	}

	player_1: Entity = {
		translate = {-6200, 0, 1},
		scale = {100, 1000, 1},
		color = {1, 0, 0, 1},
		material = {pipeline = r.pipelines[.Solid]},
		update = move_player_1,
        mesh = renderer.create_quad_mesh(r),
		velocity = {0, 3000},
	}

	solid_mat_e: []^Entity = {&player_1}

	// circle_mat_e: [dynamic]^Entity
	// append(&circle_mat_e, give_ball())

	last_tick: u64
	main_loop: for {
		delta_af := f32(sdl.GetTicks() - last_tick) / 1000
		last_tick = sdl.GetTicks()

		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				if ev.key.scancode == .ESCAPE do break main_loop
			}
		}
        renderer.begin_frame(r)

		for entity in solid_mat_e {
			entity.update(entity, delta_af)
            m := model_matrix(entity)
			renderer.draw(r, &entity.mesh, &entity.material, &m)
		}

		// sdl.BindGPUFragmentSamplers(
		// 	render_pass,
		// 	0,
		// 	&(sdl.GPUTextureSamplerBinding{sampler = sampler, texture = texture}),
		// 	1,
		// )

        renderer.end_frame(r)
	}

}
