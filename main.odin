package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "renderer"
import sdl "vendor:sdl3"

gravity: f32 = 1000
drag: f32 = 0.8
speed: f32 = 100

main :: proc() {
	context.logger = log.create_console_logger()

	width: i32 = 1280
	height: i32 = 720
	r := renderer.init(width, height)
	defer renderer.destroy_renderer(r)

	quad_mesh := renderer.create_quad_mesh(r)
	defer renderer.destroy_mesh(r, quad_mesh)
	red_mat := renderer.create_solid_material(r, {0.2, 0.5, 0, 1})

	ground: Entity = {
		translate = {0, -30, 1},
		scale     = {100, 10, 1},
		mesh      = quad_mesh,
		solid_mat = red_mat,
	}

	move_player_1 :: proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
		if (!e.on_ground) do e.velocity.y -= gravity * dt

		keys := sdl.GetKeyboardState(nil)

		if keys[sdl.Scancode.A] {
			e.velocity.x -= speed
		}

		if keys[sdl.Scancode.D] {
			e.velocity.x += speed
		}

		if .J in input {
			// update_animation_state(e, .Attack)
		}
		if .SPACE in input && e.on_ground == true {
			e.velocity.y += 300
		}

		e.velocity.x *= drag * dt * 100
	}
    sprite_sheet, ok:= parse_sprite_sheet(r, "running-bones")
	defer renderer.destroy_material(r, sprite_sheet.material)
    if !ok do fmt.println("didnt parse sheet")

	player_1: Entity = {
		translate = {0, 0, 1},
		scale     = {20, 20, 1},
		update    = move_player_1,
		mesh      = quad_mesh,
		state     = .Idle,
		velocity  = {0, 0},
        current_frame = 0,
        sprite_sheet = sprite_sheet
	}

	sprite_mat_e: []^Entity = {&player_1}
	solid_mat_e: []^Entity = {&ground}

	last_tick: u64
	main_loop: for {
		delta_af := f32(sdl.GetTicks() - last_tick) / 1000
		last_tick = sdl.GetTicks()

		pressed: bit_set[Keys]
		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				if ev.key.scancode == .ESCAPE do break main_loop
				if ev.key.scancode == .J do pressed += {.J}
				if ev.key.scancode == .SPACE do pressed += {.SPACE}
			}
		}
		if (!renderer.begin_frame(r)) do continue

		for entity in sprite_mat_e {
			entity.update(entity, pressed, delta_af)
			move_on_velocity(entity, delta_af)
			sprite_offset, finished := update_animation(entity, delta_af)
			// if (finished) do update_animation_state(entity)
			m := model_matrix(entity)
			renderer.draw_sprite(r, &entity.mesh, &entity.sprite_sheet.material, &sprite_offset, &m)
		}

		for entity in solid_mat_e {
            // fmt.println(entity)
			m := model_matrix(entity)
			renderer.draw_solid(r, &entity.mesh, &entity.solid_mat, &m)
		}

		// check collisions
		for character in sprite_mat_e {
			for ground in solid_mat_e {
				if (collision_happen(character, ground)) {
					character.on_ground = true
					character.velocity.y = 0
				} else do character.on_ground = false
			}
		}

		renderer.end_frame(r)
	}
}
