package main

import "core:fmt"
import "core:math/linalg"
import "renderer"

Keys :: enum {
	W,
	A,
	S,
	D,
	J,
    SPACE,
}

Collision :: struct {
	min_x, max_x, min_y, max_y: f32,
}

Sprite :: struct {
	anim_conf: Animation_Conf,
	matetrial: renderer.Material,
}

Animation_State :: enum {
	Idle,
	Attack,
	Jump,
}

Animation_Conf :: struct {
	current_row:    u32,
	row_count:      u32,
	column_count:   u32,
	frame_count:    u32,
	frame_height:   u32,
	frame_width:    u32,
	current_frame:  u32,
	frame_duration: f32,
	elapsed:        f32,
	next_animation: Animation_State,
}

Entity :: struct {
	name:      string,
	translate: linalg.Vector3f32,
	scale:     linalg.Vector3f32,
	rotation:  f32,
	collision: Collision,
	children:  []^Entity,
	mesh:      renderer.Mesh,
	update:    proc(e: ^Entity, input: bit_set[Keys], dt: f32),
	sprites:   [Animation_State]Sprite,
    solid_mat: renderer.Material,
	state:     Animation_State,
	velocity:  [2]f32,
    on_ground: bool
}

model_matrix :: proc(e: ^Entity) -> matrix[4, 4]f32 {
	model :=
		linalg.matrix4_translate_f32(e.translate) *
		linalg.matrix4_rotate_f32(e.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32(e.scale)

	return model
}

scale_vertices_for_texture :: proc(e: ^Entity, anim_conf: Animation_Conf) {
	aspect_ratio := f32(anim_conf.frame_width) / f32(anim_conf.frame_height)
	e.scale.x = e.scale.y * aspect_ratio
}

update_animation_state :: proc(e: ^Entity, next_state: Animation_State) {
	e.state = next_state
}

update_animation :: proc(anim_conf: ^Animation_Conf, dt: f32) -> (renderer.SpriteOffset, bool) {
	finished: bool
	frame_count := anim_conf.frame_count
	cur_row := anim_conf.current_row
	row_count := anim_conf.row_count

	anim_conf.elapsed += dt
	elapsed := anim_conf.frame_duration <= anim_conf.elapsed
	if elapsed {
		anim_conf.elapsed = 0
		anim_conf.current_frame += 1
		if anim_conf.current_frame >= frame_count {
			finished = true
			anim_conf.current_frame = 0
		}
	}

	return {
			scale = {1 / f32(anim_conf.column_count), 1 / f32(row_count)},
			offset = {
				f32(anim_conf.current_frame) / f32(anim_conf.column_count),
				f32(cur_row) / f32(row_count),
			},
		},
		finished
}

create_sprite :: proc(r: ^renderer.Renderer, path: string, anim_conf: Animation_Conf) -> Sprite {
	material := renderer.create_material(r, path, r.pipelines[.Textured])

	return {matetrial = material, anim_conf = anim_conf}
}

padding :f32= 100
collision_happen :: proc(e1: ^Entity, e2: ^Entity) -> bool {
    col_e1: Collision = {
        min_x = e1.translate.x - e1.scale.x / 2,
        max_x = e1.translate.x + e1.scale.x / 2,
        min_y = (e1.translate.y - e1.scale.y / 1.9),
        max_y = e1.translate.y + e1.scale.y / 1.9,
    }

    col_e2: Collision = {
        min_x = e2.translate.x - e2.scale.x / 2,
        max_x = e2.translate.x + e2.scale.x / 2,
        min_y = e2.translate.y - e2.scale.y / 2,
        max_y = e2.translate.y + e2.scale.y / 2,
    }

    collided := col_e1.min_y <= col_e2.max_y

    return collided
}

move_on_velocity :: proc(e: ^Entity) {
    e.translate.x += e.velocity.x
    e.translate.y += e.velocity.y
}
