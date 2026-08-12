package main

Collision :: struct {
	min_x, max_x, min_y, max_y: f32,
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
