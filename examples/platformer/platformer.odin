package platformer

import "core:fmt"
import s "../../"

main :: proc() {
	width: u32 = 850
	height: u32 = 450
    s.init_window("platformer", width, height)
    defer s.close_window()

    for !s.window_should_close() {
        s.begin_draw()

        s.end_draw()
    }
}


