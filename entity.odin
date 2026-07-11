package main

import "core:math/linalg"
import "renderer"

Keys :: enum {
    W,
    A,
    S,
    D,
    J
}

Collision :: struct {
	min_x, max_x, min_y, max_y: f32,
}

Sprite :: struct {
    anim_conf: Animation_Conf,
    matetrial: renderer.Material
}

Animation_State :: enum {
    Idle,
    Attack,
    Jump,
}

Animation_Conf :: struct {
    row: u32,
    frame_count:    u32,
    frame_height: u32,
    frame_width: u32,
    current_frame:  u32,
    frame_duration: f32,
    elapsed:        f32,
    next_animation: Animation_State
}

Entity :: struct {
	name:      string,
	translate: linalg.Vector3f32,
	scale:     linalg.Vector3f32,
	color:     [4]f32,
	rotation:  f32,
	collision: Collision,
	children:  []^Entity,
	mesh:      renderer.Mesh,
	update:    proc(e: ^Entity, input: bit_set[Keys], dt: f32),
    sprites: [Animation_State]Sprite,
    state: Animation_State,
	velocity:  [2]f32,
}

model_matrix :: proc(e: ^Entity) -> matrix[4, 4]f32 {
	model :=
		linalg.matrix4_translate_f32(e.translate) *
		linalg.matrix4_rotate_f32(e.rotation, {0, 0, 1}) *
		linalg.matrix4_scale_f32(e.scale)

	return model
}

update_animation_state :: proc(e: ^Entity, anim_conf: Animation_Conf, state: Animation_State) {
    aspect_ratio := f32(anim_conf.frame_width) / f32(anim_conf.frame_height)
    e.scale.x = e.scale.y * aspect_ratio
    e.state = state
}

update_animation :: proc(anim_conf: ^Animation_Conf, dt: f32) -> (renderer.SpriteOffset, bool) {
    finished : bool
	cur_frame := anim_conf.current_frame
	frame_count := anim_conf.frame_count

	anim_conf.elapsed += dt
	elapsed := anim_conf.frame_duration <= anim_conf.elapsed
    if elapsed {
        anim_conf.elapsed = 0
        if anim_conf.current_frame == frame_count do finished = true
        anim_conf.current_frame = (cur_frame % frame_count) + 1
    }
	return {scale = {1 / f32(frame_count), 1}, offset = {f32(cur_frame) / f32(frame_count), 0}}, finished
}

create_sprite :: proc(r: ^renderer.Renderer, path: string, anim_conf: Animation_Conf) -> Sprite {
    material := renderer.create_material(
        r,
        path,
        r.pipelines[.Textured],
    )

    return {
        matetrial = material,
        anim_conf = anim_conf
    }
}

// draw_entity :: proc(
// 	render_pass: ^sdl.GPURenderPass,
// 	cmd_buf: ^sdl.GPUCommandBuffer,
// 	entity: ^Entity,
// ) {
// 	root_transform: matrix[4, 4]f32
//
// 	if (current_pipeline != entity.material.pipeline) {
// 		current_pipeline = entity.material.pipeline
// 		sdl.BindGPUGraphicsPipeline(render_pass, entity.material.pipeline)
// 	}
//
//     root_transform =
//         linalg.matrix4_translate_f32(entity.translate) *
//         linalg.matrix4_rotate_f32(entity.rotation, {0, 0, 1})
//     root_model := root_transform * linalg.matrix4_scale_f32(entity.scale)
//     color := entity.color
//
//     sdl.PushGPUVertexUniformData(cmd_buf, 1, &root_model, size_of(matrix[4, 4]f32))
//     sdl.PushGPUFragmentUniformData(cmd_buf, 0, &color, size_of(entity.color))
//     sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
//
//     for entity in entity.children {
//         model :=
//             linalg.matrix4_translate_f32(entity.translate) *
//             linalg.matrix4_rotate_f32(entity.rotation, {0, 0, 1}) *
//             linalg.matrix4_scale_f32(entity.scale)
//
//         root_transform *= model
//
//         color := entity.color
//
//         sdl.PushGPUVertexUniformData(cmd_buf, 1, &root_transform, size_of(matrix[4, 4]f32))
//         sdl.PushGPUFragmentUniformData(cmd_buf, 0, &color, size_of(entity.color))
//         sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
//     }
// }
