extends Node2D
## Prototype-only: transparent window and stylized sprayer drawn from primitives.
## The overlay becomes click-through only after a separate, always-accessible control window exists.

const SPEED := 85.0
const WINDOW_WIDTH := 720
const WINDOW_HEIGHT := 160
const EDGE_MARGIN := 8
var last_usable_rect := Rect2i()
var tractor_x := 80.0
var direction := 1.0
var wheel_phase := 0.0
var overlay_enabled := true
var garage: Window
var toggle_button: Button
var fps_button: Button

func _ready() -> void:
    get_viewport().transparent_bg = true
    var window := get_window()
    window.borderless = true
    window.transparent = true
    window.always_on_top = true
    Engine.max_fps = 30
    _position_above_taskbar()
    _create_control_window()
    # Do not enable click-through unless the separate control window was created.
    if is_instance_valid(garage):
        window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
    # P001: use the Windows usable rectangle instead of assuming screen size/DPI.
    # The click-through flag remains OFF until an independent control path exists.

func _process(delta: float) -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable := DisplayServer.screen_get_usable_rect(screen)
    if usable != last_usable_rect:
        _position_above_taskbar()
    tractor_x += direction * SPEED * delta
    wheel_phase += delta * 8.0
    if tractor_x > float(WINDOW_WIDTH) - 125.0:
        tractor_x = float(WINDOW_WIDTH) - 125.0
        direction = -1.0
    elif tractor_x < 15.0:
        tractor_x = 15.0
        direction = 1.0
    if overlay_enabled:
        queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        get_tree().quit()

func _draw() -> void:
    if not overlay_enabled:
        return
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

func _position_above_taskbar() -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable := DisplayServer.screen_get_usable_rect(screen)
    if usable.size.x <= 0 or usable.size.y <= 0:
        return
    last_usable_rect = usable
    var window := get_window()
    # Anchor to the bottom-right of the usable area, not the monitor boundary.
    # On non-bottom taskbars this means inside the usable desktop area.
    var target_x := usable.position.x + max(0, usable.size.x - WINDOW_WIDTH - EDGE_MARGIN)
    var target_y := usable.position.y + max(0, usable.size.y - WINDOW_HEIGHT - EDGE_MARGIN)
    window.position = Vector2i(target_x, target_y)

func _create_control_window() -> void:
    # Separate native window: unlike the overlay, this window remains clickable.
    garage = Window.new()
    garage.title = "Туман | Управление прототипом"
    garage.size = Vector2i(310, 210)
    garage.unresizable = true
    garage.transparent = false
    garage.borderless = false
    garage.always_on_top = false
    garage.close_requested.connect(_on_garage_close_requested)
    add_child(garage)
    var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
    garage.position = usable.position + Vector2i(30, 30)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 12)
    garage.add_child(margin)

    var layout := VBoxContainer.new()
    margin.add_child(layout)
    var heading := Label.new()
    heading.text = "ТУМАН: технический прототип"
    layout.add_child(heading)
    var hint := Label.new()
    hint.text = "Оверлей пропускает клики.\nЭто окно оставь для управления."
    layout.add_child(hint)
    toggle_button = Button.new()
    toggle_button.text = "Скрыть Тумана"
    toggle_button.pressed.connect(_toggle_overlay)
    layout.add_child(toggle_button)
    fps_button = Button.new()
    fps_button.text = "FPS: 30 (переключить)"
    fps_button.pressed.connect(_toggle_fps)
    layout.add_child(fps_button)
    var quit_button := Button.new()
    quit_button.text = "Выход из игры"
    quit_button.pressed.connect(func() -> void: get_tree().quit())
    layout.add_child(quit_button)
    garage.show()

func _toggle_overlay() -> void:
    overlay_enabled = not overlay_enabled
    toggle_button.text = "Скрыть Тумана" if overlay_enabled else "Показать Тумана"
    queue_redraw()

func _toggle_fps() -> void:
    Engine.max_fps = 15 if Engine.max_fps == 30 else 30
    fps_button.text = "FPS: %d (переключить)" % Engine.max_fps

func _on_garage_close_requested() -> void:
    # Closing the control window exits: never strand an unclickable overlay.
    get_tree().quit()
