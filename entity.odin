package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:os"
import "core:reflect"
import "renderer"

MAX_CLIP_FRAMES :: 16

Keys :: enum {
	W,
	A,
	S,
	D,
	J,
	SPACE,
	X,
}

Collision :: struct {
	min_x, max_x, min_y, max_y: f32,
}

Sprite_Sheet :: struct {
	frame_width, frame_height: u32,
	row_count:                 u16,
	column_count:              u16,
	clips:                     [Animation_State]Animation_Clip,
	material:                  renderer.Material,
}

Animation_State :: enum {
	Idle,
	Thrust,
	Jump,
	Run,
}

Animation_Clip :: struct {
	durations:   [MAX_CLIP_FRAMES]u16,
	row:         u16,
	columns:     u16,
	hit_frames:  bit_set[0 ..< MAX_CLIP_FRAMES],
	transitions: []Transition,
	hitbox:      Hitbox,
}

Transition :: struct {
	to:        Animation_State,
	condition: proc(e: ^Entity) -> bool,
}

Hitbox :: struct {
	offset: [3]f32,
	size:   [3]f32,
}

Layer :: enum {
	Ground,
	Enemy,
	Player,
}

Entity :: struct {
	name:           string,
	health:         u16,
	translate:      [3]f32,
	scale:          [3]f32,
	rotation:       f32,
	collision:      Collision,
	children:       []^Entity,
	mesh:           renderer.Mesh,
	update:         proc(e: ^Entity, input: bit_set[Keys], dt: f32),
	on_hit:         proc(e: ^Entity, e2: ^Entity),
	on_collision:   proc(e: ^Entity, e2: ^Entity, difference: [2]f32),
	sprite_sheet:   Sprite_Sheet,
	solid_mat:      renderer.Material,
	state:          Animation_State,
	velocity:       [2]f32,
	on_ground:      bool,
	current_frame:  u16,
	anim_elapsed:   f32,
	fliped:         bool,
	attack_pressed: bool,
	anim_finished:  bool,
	category:       Layer,
	mask:           bit_set[Layer],
	damage:         u16,
	is_dead:        bool,
	has_swing_hit:  bool,
}

Sprite_Conf :: struct {
	frames: []Frame,
	meta:   Meta,
}

Frame :: struct {
	source_size: Frame_Size `json:"sourceSize"`,
	duration:    u16,
}

Frame_Size :: struct {
	w, h: u32,
}

Meta :: struct {
	format:     string,
	size:       Sprite_Size,
	frame_tags: []Frame_Tag `json:"frameTags"`,
}

Sprite_Size :: struct {
	w: u32,
	h: u32,
}

Frame_Tag :: struct {
	name: string,
	from: u8,
	to:   u8,
}

parse_sprite_sheet :: proc(r: ^renderer.Renderer, sprite_name: string) -> (Sprite_Sheet, bool) {
	material := renderer.create_texture_material(
		r,
		fmt.tprintf("./assets/%s.png", sprite_name),
		r.pipelines[.Textured],
	)
	sprite_conf_bytes, err := os.read_entire_file(
		fmt.tprintf("./assets/%s.json", sprite_name),
		context.allocator,
	)
	defer delete(sprite_conf_bytes, context.allocator)

	if err != nil {
		log.error(err)
		return {}, false
	}

	sprite_conf: Sprite_Conf
	err2 := json.unmarshal(sprite_conf_bytes, &sprite_conf)
	defer free(&sprite_conf)
	if err2 != nil {
		log.error(err)
		return {}, false
	}
	if (len(sprite_conf.frames) <= 0) {
		log.error("wtf bro frames where")
		return {}, false
	}

	result: Sprite_Sheet = {
		material     = material,
		column_count = u16(sprite_conf.meta.size.w / sprite_conf.frames[0].source_size.w),
		row_count    = u16(sprite_conf.meta.size.h / sprite_conf.frames[0].source_size.h),
		frame_width  = sprite_conf.frames[0].source_size.w,
		frame_height = sprite_conf.frames[0].source_size.h,
	}

	for tag, id in sprite_conf.meta.frame_tags {
		anim_state, err3 := reflect.enum_from_name(Animation_State, tag.name)
		if !err3 {
			log.error("frame tag dosent match the animation states")
			return {}, false
		}

		durations: [MAX_CLIP_FRAMES]u16
		for frame, id in sprite_conf.frames[tag.from:tag.to + 1] {
			durations[id] = frame.duration
		}
		result.clips[anim_state] = {
			durations = durations,
			columns   = u16(tag.to - tag.from) + 1,
			row       = u16(id),
		}
	}

	return result, true
}

model_matrix :: proc(e: ^Entity) -> matrix[4, 4]f32 {
	if e.sprite_sheet.column_count > 1 {
		aspect_ratio := f32(e.sprite_sheet.frame_width) / f32(e.sprite_sheet.frame_height)
		e.scale.x = e.scale.y * aspect_ratio
	}

	model :=
		linalg.matrix4_translate_f32(e.translate) *
		linalg.matrix4_rotate_f32(e.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32(e.scale)

	return model
}

update_animation_state :: proc(e: ^Entity) {
	transitions := e.sprite_sheet.clips[e.state].transitions

	for transition in transitions {
		if transition.condition(e) {
			e.state = transition.to
			e.anim_elapsed = 0
			e.current_frame = 0
			e.has_swing_hit = false
		}
	}
}

update_animation :: proc(e: ^Entity, dt: f32) -> renderer.Sprite_Offset {
	current_clip := e.sprite_sheet.clips[e.state]

	frame_count := current_clip.columns
	frame_row := current_clip.row
	sprite_columns := f32(e.sprite_sheet.column_count)
	sprite_rows := f32(e.sprite_sheet.row_count)

	e.anim_elapsed += dt * 1000
	elapsed := f32(current_clip.durations[e.current_frame]) <= e.anim_elapsed
	// if single frame elapsed
	if elapsed {
		e.anim_finished = false
		e.anim_elapsed = 0
		e.current_frame += 1
		if e.current_frame >= frame_count {
			e.anim_finished = true
			e.current_frame = 0
		}
	}

	scale_x := 1 / sprite_columns
	offset_x := e.current_frame
	if e.fliped {
		scale_x *= -1
		offset_x += 1
	}

	return {
		scale = {scale_x, 1 / sprite_rows},
		offset = {f32(offset_x) / f32(sprite_columns), f32(frame_row) / f32(sprite_rows)},
	}
}

collision_happen :: proc(
	translate_1: [3]f32,
	scale_1: [3]f32,
	translate_2: [3]f32,
	scale_2: [3]f32,
) -> (
	bool,
	[2]f32,
) {
	col_e1: Collision = {
		min_x = translate_1.x - scale_1.x / 2,
		max_x = translate_1.x + scale_1.x / 2,
		min_y = translate_1.y - scale_1.y / 2,
		max_y = translate_1.y + scale_1.y / 2,
	}

	col_e2: Collision = {
		min_x = translate_2.x - scale_2.x / 2,
		max_x = translate_2.x + scale_2.x / 2,
		min_y = translate_2.y - scale_2.y / 2,
		max_y = translate_2.y + scale_2.y / 2,
	}

	collided :=
		col_e1.min_y <= col_e2.max_y &&
		col_e1.max_y >= col_e2.min_y &&
		col_e1.min_x <= col_e2.max_x &&
		col_e1.max_x >= col_e2.min_x

	// meaning e1 overlfowed on which side
	overflow_x_right := col_e1.max_x - col_e2.min_x
	overflow_x_left := col_e2.max_x - col_e1.min_x

	overflow_y_top := col_e1.max_y - col_e2.min_y
	overflow_y_bottom := col_e2.max_y - col_e1.min_y

	swap_sign := overflow_x_right < overflow_x_left
	difference: [2]f32
	if swap_sign {
		difference = {
			-min(overflow_x_right, overflow_x_left),
			min(overflow_y_bottom, overflow_y_top),
		}
	} else {
		difference = {
			min(overflow_x_right, overflow_x_left),
			min(overflow_y_bottom, overflow_y_top),
		}
	}

	return collided, difference
}

collision_happen_entity :: proc(e1: ^Entity, e2: ^Entity) -> (bool, [2]f32) {
	return collision_happen(e1.translate, e1.scale, e2.translate, e2.scale)
}

apply_physics :: proc(e: ^Entity, dt: f32) {
	if !e.on_ground do e.velocity.y -= gravity * dt
	if abs(e.velocity.x) > 0 {
		e.velocity.x *= 0.9
	}
	if abs(e.velocity.x) < 10 {
		e.velocity.x = 0
	}

	e.translate.x += e.velocity.x * dt
	e.translate.y += e.velocity.y * dt
}

delete_all_dead_entites :: proc(sprite_e: ^[dynamic]^Entity, collision_e: ^[dynamic]^Entity) {

	for e, i in sprite_e {
		if e.is_dead do unordered_remove(sprite_e, i)
	}

	for e, i in collision_e {
		if e.is_dead do unordered_remove(collision_e, i)
	}
}
