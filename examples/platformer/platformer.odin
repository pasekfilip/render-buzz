package platformer

import s "../../"

main :: proc() {
	width: u32 = 850
	height: u32 = 450
    s.init_window("platformer", width, height)
    defer s.close_window()
}


