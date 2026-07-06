package main
//
// import "core:math/linalg"
// import sdl "vendor:sdl3"
//
// Collision :: struct {
//     min_x, max_x, min_y, max_y: f32
// }
//
// Entity :: struct {
//     name: string,
// 	translate:  linalg.Vector3f32,
// 	scale:      linalg.Vector3f32,
// 	color:      [4]f32,
// 	rotation:      f32,
// 	collision: Collision,
// 	children:   []^Entity,
// 	material:   Material,
// 	update:     proc(e: ^Entity, dt: f32),
//     velocity: [2]f32
// }
//
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
