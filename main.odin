package main

import "core:log"
import "core:mem"
import renderer "engine"
import sdl "vendor:sdl3"

main :: proc() {
	context.logger = log.create_console_logger()

	tracking_allocator: mem.Tracking_Allocator
	default_allocator := context.allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) {
		for _, value in a.allocation_map {
			log.warnf("%v: Leaked %v bytes\n", value.location, value.size)
		}

		mem.tracking_allocator_clear(a)
	}

	width: i32 = 1280
	height: i32 = 720
	r := renderer.init_window(width, height, "buzz")
	defer renderer.destroy_renderer(r)

	world := create_world(r)

	last_tick: u64
	main_loop: for {
		df := f32(sdl.GetTicks() - last_tick) / 1000
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
				if ev.key.scancode == .X do pressed += {.X}
			}
		}
		//NOTE: udpate physics
		for e in world {
			if e.update == nil do continue
			e.update(e, pressed, df)
			apply_physics(e, df)
		}

		//NOTE: collision
		for e, i in world {
			for e2 in world[i + 1:] {
				if e.category in e2.mask {
					collision, difference := collision_happen_entity(e, e2)
					if collision && e.on_collision != nil {
						e.on_collision(e, e2, difference)
					} else do e.on_ground = false
				}
			}
		}

		// NOTE: animation
		for e in world {
			#partial switch &v in e.visual {
			case Animated_Sprite:
				update_animation_state(e, &v)
				update_animation(&v, df)
			}
		}

		delete_all_dead_entites(&world)
		if (!renderer.begin_frame(r)) do continue
		//NOTE: draw
		for e in world {
			switch &v in e.visual {
			case Animated_Sprite:
				renderer.draw_texture(
					r,
					&v.sprite_sheet.texture,
					texture_source(e.fliped, &v),
					{x = e.translate.x, y = e.translate.y, w = e.scale.x, h = e.scale.y},
					0,
				)
			case renderer.Color:
				renderer.draw_rectangle(
					r,
					&v,
					{x = e.translate.x, y = e.translate.y, w = e.scale.x, h = e.scale.y},
					0,
				)
			}
		}
		renderer.end_frame(r)
		free_all(context.temp_allocator)
	}
	reset_tracking_allocator(&tracking_allocator)
}
