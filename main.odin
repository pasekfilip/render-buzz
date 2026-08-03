package main

import "core:slice"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "renderer"
import sdl "vendor:sdl3"

gravity: f32 = 250
speed: f32 = 50
max_speed: f32 = 50
jump: f32 = 100

main :: proc() {
	context.logger = log.create_console_logger()

	width: i32 = 1280
	height: i32 = 720
	r := renderer.init(width, height)
	defer renderer.destroy_renderer(r)

	quad_mesh := renderer.create_quad_mesh(r)
	defer renderer.destroy_mesh(r, quad_mesh)
	red_mat := renderer.create_material(r, {0.2, 0.5, 0, 1}, .Solid)
	debug_box := renderer.create_material(r, {0.0, .8, 0, 1}, .Wireframe)

	ground: Entity = {
		translate = {0, -30, 1},
		scale     = {200, 10, 1},
		mesh      = quad_mesh,
		solid_mat = red_mat,
		category  = .Ground,
		mask      = {.Player, .Enemy},
	}

	sprite_sheet, ok := parse_sprite_sheet(r, "running-bones")
	defer renderer.destroy_material(r, sprite_sheet.material)
	if !ok do fmt.println("didnt parse sheet")

	idle := make([]Transition, 2)
	idle[0] = {
		to = .Run,
		condition = proc(e: ^Entity) -> bool {
			return abs(e.velocity.x) > 0 && e.on_ground
		},
	}
	idle[1] = {
		to = .Thrust,
		condition = proc(e: ^Entity) -> bool {
			return e.attack_pressed
		},
	}

	run := make([]Transition, 2)
	run[0] = {
		to = .Idle,
		condition = proc(e: ^Entity) -> bool {
			return abs(e.velocity.x) < 10
		},
	}
	run[1] = {
		to = .Thrust,
		condition = proc(e: ^Entity) -> bool {
			return e.attack_pressed
		},
	}

	attack := make([]Transition, 1)
	attack[0] = {
		to = .Idle,
		condition = proc(e: ^Entity) -> bool {
			return e.anim_finished
		},
	}
	sprite_sheet.clips[.Idle].transitions = idle
	sprite_sheet.clips[.Run].transitions = run
	sprite_sheet.clips[.Thrust].transitions = attack

	defer delete(idle)
	defer delete(run)
	defer delete(attack)

	sprite_sheet.clips[.Thrust].hit_frames = {2, 3}
	sprite_sheet.clips[.Thrust].hitbox = {
		offset = {10, -2, 0},
		size   = {10, 10, 1},
	}

	update_player :: proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
		keys := sdl.GetKeyboardState(nil)

		if keys[sdl.Scancode.A] {
			e.fliped = true
			if e.velocity.x > -max_speed do e.velocity.x -= speed
		} else if keys[sdl.Scancode.D] {
			e.fliped = false
			if e.velocity.x < max_speed do e.velocity.x += speed
		}

		if .J in input do e.attack_pressed = true
		else do e.attack_pressed = false

		if .SPACE in input && e.on_ground == true {
			e.on_ground = false
			e.velocity.y = jump
		}
	}

	on_collision :: proc(e: ^Entity, e2: ^Entity, difference: [2]f32) {
		#partial switch e2.category {
		case .Ground:
			e.translate.y += difference.y
			e.on_ground = true
			e.velocity.y = 0
			break
		case .Enemy:
			// e.velocity.x += difference.x * 10
			break
		}
	}

	on_hit :: proc(e: ^Entity, e2: ^Entity) {
        if e.has_swing_hit do return
        e2.health -= e.damage
        e.has_swing_hit = true
	}

	player: Entity = {
		name          = "Player",
		damage        = 50,
		translate     = {0, 0, 1},
		scale         = {20, 20, 1},
		update        = update_player,
		on_collision  = on_collision,
		on_hit        = on_hit,
		mesh          = quad_mesh,
		state         = .Idle,
		velocity      = {0, 0},
		current_frame = 0,
		sprite_sheet  = sprite_sheet,
		category      = .Player,
		mask          = {.Ground, .Enemy},
	}

	enemy: Entity = {
        health = 100,
		name = "enemy",
		translate = {-50, 0, 1},
		scale = {20, 20, 1},
		update = proc(e: ^Entity, input: bit_set[Keys], dt: f32) {
			if e.health <= 0 do e.is_dead = true
		},
		on_collision = on_collision,
		mesh = quad_mesh,
		state = .Idle,
		velocity = {0, 0},
		current_frame = 0,
		sprite_sheet = sprite_sheet,
		category = .Enemy,
		mask = {.Ground, .Player},
	}

	sprite_mat_e: [dynamic]^Entity
    append(&sprite_mat_e, &player)
    append(&sprite_mat_e, &enemy)
	solid_mat_e: []^Entity = {&ground}

	all_e: [dynamic]^Entity

    for e in sprite_mat_e { append(&all_e, e) }
    for e in solid_mat_e { append(&all_e, e) }

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
				if ev.key.scancode == .X do pressed += {.X}
			}
		}
		if (!renderer.begin_frame(r)) do continue

		for e in sprite_mat_e {
			e.update(e, pressed, delta_af)
			apply_physics(e, delta_af)
			update_animation_state(e)
			sprite_offset := update_animation(e, delta_af)
			m := model_matrix(e)
			renderer.draw_sprite(r, &e.mesh, &e.sprite_sheet.material, &sprite_offset, &m)

			hitbox := e.sprite_sheet.clips[e.state].hitbox
			if e.fliped do hitbox.offset.x *= -1
			debug_box_position := e.translate + hitbox.offset
			model :=
				linalg.matrix4_translate_f32(debug_box_position) *
				linalg.matrix4_scale_f32(hitbox.size)

			renderer.draw_solid(r, &quad_mesh, &debug_box, &model)
		}

		for entity in solid_mat_e {
			m := model_matrix(entity)
			renderer.draw_solid(r, &entity.mesh, &entity.solid_mat, &m)
		}

		for e, i in all_e {
			for e2 in all_e[i + 1:] {
				if e.category in e2.mask {
					collision, difference := collision_happen_entity(e, e2)
					if collision && e.on_collision != nil {
						e.on_collision(e, e2, difference)
					} else do e.on_ground = false

					curr_anim := e.sprite_sheet.clips[e.state]
					if int(e.current_frame) in curr_anim.hit_frames {
						if e.fliped do curr_anim.hitbox.offset.x *= -1
						debug_box_position := e.translate + curr_anim.hitbox.offset
						collision, difference := collision_happen(
							debug_box_position,
							curr_anim.hitbox.size,
							e2.translate,
							e2.scale,
						)
						if (collision) do e.on_hit(e, e2)
					}
				}
			}
		}
        delete_all_dead_entites(&sprite_mat_e, &all_e)
		renderer.end_frame(r)
	}
}
