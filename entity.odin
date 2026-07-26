package main

import "base:intrinsics"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:os"
import "core:reflect"
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

Sprite_Sheet :: struct {
	frame_width, frame_height: u32,
	row_count:                 u16,
	column_count:              u16,
	clips:                     [Animation_State]Animation_Clip,
	material:                  renderer.Material,
}

Animation_State :: enum {
	Idle,
	Attack,
	Jump,
	Run,
}

Animation_Clip :: struct {
	row:      u16,
	columns:  u16,
	duration: u16,
}

Entity :: struct {
	name:          string,
	translate:     linalg.Vector3f32,
	scale:         linalg.Vector3f32,
	rotation:      f32,
	collision:     Collision,
	children:      []^Entity,
	mesh:          renderer.Mesh,
	update:        proc(e: ^Entity, input: bit_set[Keys], dt: f32),
	sprite_sheet:  Sprite_Sheet,
	solid_mat:     renderer.Material,
	state:         Animation_State,
	velocity:      [2]f32,
	on_ground:     bool,
	current_frame: u16,
	anim_elapsed:  f32,
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
	material := renderer.create_material(
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
		clip: Animation_Clip
		result.clips[anim_state] = {
			columns  = u16(tag.to - tag.from) + 1,
			row      = u16(id),
			duration = 100,
		}
	}

	return result, true
}

model_matrix :: proc(e: ^Entity) -> matrix[4, 4]f32 {
    if e.sprite_sheet != {} {
        aspect_ratio := f32(e.sprite_sheet.frame_width) / f32(e.sprite_sheet.frame_height)
        e.scale.x = e.scale.y * aspect_ratio
    }
    
	model :=
		linalg.matrix4_translate_f32(e.translate) *
		linalg.matrix4_rotate_f32(e.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32(e.scale)

	return model
}

// update_animation_state :: proc(e: ^Entity) {
// 	e.state = next_state
// }

update_animation :: proc(e: ^Entity, dt: f32) -> (renderer.Sprite_Offset, bool) {
	current_clip := e.sprite_sheet.clips[e.state]

	finished: bool
	frame_count := current_clip.columns
	frame_row := current_clip.row
	sprite_columns := f32(e.sprite_sheet.column_count)
	sprite_rows := f32(e.sprite_sheet.row_count)

	e.anim_elapsed += dt * 1000
	elapsed := f32(current_clip.duration) <= e.anim_elapsed
	// if single frame elapsed
	if elapsed {
		e.anim_elapsed = 0
		e.current_frame += 1
		if e.current_frame >= frame_count {
			finished = true
			e.current_frame = 0
		}
	}

	return {
			scale = {1 / sprite_columns, 1 / sprite_rows},
			offset = {
				f32(e.current_frame) / f32(sprite_columns),
				f32(frame_row) / f32(sprite_rows),
			},
		},
		finished
}

padding: f32 = 100
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

move_on_velocity :: proc(e: ^Entity, dt: f32) {
	e.translate.x += e.velocity.x * dt
	e.translate.y += e.velocity.y * dt
}
