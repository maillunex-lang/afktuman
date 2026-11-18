extends Node2D
## Prototype-only: transparent window and stylized sprayer drawn from primitives.
## Click-through is intentionally NOT enabled until an independent exit/control path exists.

const SPEED := 85.0
const WIDTH := 720.0
var tractor_x := 80.0
var direction := 1.0
var wheel_phase := 0.0

func _ready() -> void:
    get_viewport().transparent_bg = true
    var window := get_window()
    window.borderless = true
    window.transparent = true
    window.always_on_top = true
    Engine.max_fps = 30
    # Do not assume the taskbar is at the bottom or DPI is 100%.
    # Real placement relative to Windows work area is a later, testable step.

func _process(delta: float) -> void:
    tractor_x += direction * SPEED * delta
    wheel_phase += delta * 8.0
    if tractor_x > WIDTH - 125.0:
        tractor_x = WIDTH - 125.0
        direction = -1.0
    elif tractor_x < 15.0:
        tractor_x = 15.0
        direction = 1.0
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        get_tree().quit()

func _draw() -> void:
    var x := tractor_x
    var y := 83.0
    draw_set_transform(Vector2(x + 65.0, y), 0.0, Vector2(direction, 1.0))
    draw_rect(Rect2(-58, -12, 116, 34), Color("ef9b1b"))
    draw_rect(Rect2(-28, -36, 47, 27), Color("f8bc4d"))
    draw_rect(Rect2(-21, -31, 29, 17), Color("9ad6e2"))
    draw_rect(Rect2(20, -27, 34, 20), Color("e4aa30"))
    draw_line(Vector2(55, 4), Vector2(90, 4), Color("a16a25"), 3.0)
    draw_line(Vector2(90, 4), Vector2(90, 19), Color("a16a25"), 3.0)
    for wheel_x in [-34.0, 37.0]:
        draw_circle(Vector2(wheel_x, 25), 13.0, Color("28333e"))
        draw_circle(Vector2(wheel_x, 25), 5.0, Color("b7bec7"))
        draw_line(Vector2(wheel_x, 25), Vector2(wheel_x + cos(wheel_phase) * 9.0, 25 + sin(wheel_phase) * 9.0), Color("d9e1e9"), 2.0)
    for i in range(3):
        draw_circle(Vector2(92 + i * 7, 25 + i * 5), 2.0, Color(0.32, 0.82, 0.75, 0.7))
    draw_set_transform(Vector2.ZERO)
