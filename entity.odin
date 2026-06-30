package main

import "core:math/linalg"
import sdl "vendor:sdl3"

Entity :: struct {
	translate:  linalg.Vector3f32,
	scale:      linalg.Vector3f32,
	color:      [4]f32,
	angle:      f32,
	collisions: [4]f32,
	parent:     ^Entity,
	material:   Material,
	udpate:     proc(e: ^Entity, dt: f32),
}

draw_entity :: proc(
	render_pass: ^sdl.GPURenderPass,
	cmd_buf: ^sdl.GPUCommandBuffer,
	entity: ^Entity,
) {
	parent_model: matrix[4, 4]f32
	next_parent: ^Entity = entity.parent

	if (current_pipeline != entity.material.pipeline) {
		current_pipeline = entity.material.pipeline
		sdl.BindGPUGraphicsPipeline(render_pass, entity.material.pipeline)
	}

	for next_parent != nil {
		parent_model =
			linalg.matrix4_translate_f32(next_parent.translate) *
			linalg.matrix4_rotate_f32(next_parent.angle, {0, 0, 1})

		model := parent_model * linalg.matrix4_scale_f32(next_parent.scale)

		color := next_parent.color

		sdl.PushGPUVertexUniformData(cmd_buf, 1, &model, size_of(matrix[4, 4]f32))
		sdl.PushGPUFragmentUniformData(cmd_buf, 0, &color, size_of(entity.color))
		sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
		next_parent = next_parent.parent
	}

	model :=
		linalg.matrix4_translate_f32(entity.translate) *
		linalg.matrix4_rotate_f32(entity.angle, {0, 0, 1}) *
		linalg.matrix4_scale_f32(entity.scale)

	parent_model *= model

	if (entity.parent == nil) {
		parent_model = model
	}

	color := entity.color

	sdl.PushGPUVertexUniformData(cmd_buf, 1, &parent_model, size_of(matrix[4, 4]f32))
	sdl.PushGPUFragmentUniformData(cmd_buf, 0, &color, size_of(entity.color))
	sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
}
