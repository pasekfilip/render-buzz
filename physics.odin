package main

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
