package platformer

import _ "core:image/png"
import s "../../"

main :: proc() {
    width :: 1920
    height :: 1080

    s.init_window("platformer", width, height)
    defer s.close_window()

    for !s.window_should_close() {
        s.begin_draw()

        s.draw_rectangle({x = 300, y = 200, width = 500, height = 500}, s.BLUE)

        s.end_draw()
    }
}


