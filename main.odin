package main

import "core:fmt"
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

	move_player_1 :: proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
		keys := sdl.GetKeyboardState(nil)
		if keys[sdl.Scancode.W] {
			e.translate.y += e.velocity.y * dt
		}
		if keys[sdl.Scancode.S] {
			e.translate.y -= e.velocity.y * dt
		}
		if .J in input {
			attack_sprite := &e.sprites[.Attack]
			update_animation_state(e, attack_sprite.anim_conf, .Attack)
		}

		e.collision = {
			min_x = e.translate.x - e.scale.x / 2,
			max_x = e.translate.x + e.scale.x / 2,
			min_y = e.translate.y - e.scale.y / 2,
			max_y = e.translate.y + e.scale.y / 2,
		}
	}

	player_1: Entity = {
		translate = {0, 0, 1},
		scale     = {5000, 5000, 1},
		color     = {1, 0, 0, 1},
		update    = move_player_1,
		mesh      = renderer.create_quad_mesh(r),
		state     = .Idle,
		velocity  = {0, 3000},
	}

    material := renderer.create_material(
        r,
		"./assets/main-guy.png",
        r.pipelines[.Textured],
    )

    player_1.sprites[.Idle] = 
    {
        matetrial = material,
        anim_conf = {
            frame_count = 4,
            frame_duration = 0.1,
            current_frame = 1,
            frame_width = 100,
            frame_height = 32,
        }
    }

    player_1.sprites[.Attack] = 
    {
        matetrial = material,
        anim_conf = {

            frame_count = 5,
            frame_duration = 0.1,
            current_frame = 5,
            frame_width = 100,
            frame_height = 32,
            next_animation = .Idle,
        }
    }

	solid_mat_e: []^Entity = {&player_1}

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
			}
		}
		if (!renderer.begin_frame(r)) do continue

		for entity in solid_mat_e {
			entity.update(entity, pressed, delta_af)
			cur_sprite := &entity.sprites[entity.state]
			sprite_offset, finished := update_animation(&cur_sprite.anim_conf, delta_af)
			if (finished) do update_animation_state(entity, cur_sprite.anim_conf, cur_sprite.anim_conf.next_animation)
			m := model_matrix(entity)

			renderer.draw(r, &entity.mesh, &cur_sprite.matetrial, &sprite_offset, &m)
		}

		renderer.end_frame(r)
	}
}
