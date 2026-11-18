extends Node2D
## Prototype-only: transparent window and stylized sprayer drawn from primitives.
## The overlay becomes click-through only after a separate, always-accessible control window exists.

const SPEED := 52.0
const SPRAYER_SCALE := 0.48
const WINDOW_WIDTH := 440
const WINDOW_HEIGHT := 64
const EDGE_MARGIN := 2
var last_usable_rect := Rect2i()
var tractor_x := 30.0
var direction := 1.0
var wheel_phase := 0.0
var overlay_enabled := true
var garage: Window
var toggle_button: Button
var fps_button: Button
var status_label: Label
var spray_enabled := true

func _ready() -> void:
    get_viewport().transparent_bg = true
    var window := get_window()
    window.borderless = true
    window.transparent = true
    window.always_on_top = true
    Engine.max_fps = 30
    _position_above_taskbar()
    if DisplayServer.get_name() == "headless":
        return
    _create_control_window()
    if garage.get_window_id() != DisplayServer.INVALID_WINDOW_ID:
        window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)

func _process(delta: float) -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable := DisplayServer.screen_get_usable_rect(screen)
    if usable != last_usable_rect:
        _position_above_taskbar()
    if not overlay_enabled:
        return
    tractor_x += direction * SPEED * delta
    wheel_phase += delta * 8.0
    if tractor_x > float(WINDOW_WIDTH) - 105.0:
        tractor_x = float(WINDOW_WIDTH) - 105.0
        direction = -1.0
    elif tractor_x < 15.0:
        tractor_x = 15.0
        direction = 1.0
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        get_tree().quit()

func _draw() -> void:
    if not overlay_enabled:
        return
    var x := tractor_x
    # Compact sprayer: wheel bottoms sit just 5-6 px above the taskbar.
    var y := 36.0
    draw_set_transform(Vector2(x + 55.0, y), 0.0, Vector2(direction * SPRAYER_SCALE, SPRAYER_SCALE))
    # Rounded orange chassis, slimmer cabin, glass, tank and folding boom.
    draw_colored_polygon(PackedVector2Array([
        Vector2(-57, -7), Vector2(-50, -16), Vector2(43, -16),
        Vector2(55, -7), Vector2(53, 13), Vector2(-56, 13)
    ]), Color("ed8c17"))
    draw_rect(Rect2(-47, 5, 92, 7), Color("c66c14"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(-28, -15), Vector2(-22, -49), Vector2(9, -49),
        Vector2(21, -15)
    ]), Color("f5b43d"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(-18, -43), Vector2(6, -43), Vector2(14, -20),
        Vector2(-23, -20)
    ]), Color("8bd0dc"))
    draw_line(Vector2(-4, -42), Vector2(-4, -21), Color("d5f4f4"), 2.0)
    draw_rect(Rect2(24, -35, 29, 19), Color("f6bc48"))
    draw_line(Vector2(51, -9), Vector2(87, -9), Color("666c6a"), 4.0)
    draw_line(Vector2(86, -9), Vector2(103, -2), Color("747a75"), 3.0)
    for wheel_x in [-34.0, 36.0]:
        draw_circle(Vector2(wheel_x, 23), 16.0, Color("242b30"))
        draw_circle(Vector2(wheel_x, 23), 10.0, Color("39434a"))
        draw_circle(Vector2(wheel_x, 23), 5.0, Color("d1d7d6"))
        draw_line(Vector2(wheel_x, 23), Vector2(wheel_x + cos(wheel_phase) * 8.0, 23 + sin(wheel_phase) * 8.0), Color("f1f1df"), 2.0)
    if spray_enabled:
        for i in range(3):
            draw_circle(Vector2(94 + i * 6, 12 + i * 7), 2.0, Color(0.35, 0.87, 0.81, 0.5))
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
    var target_x := usable.position.x + maxi(0, usable.size.x - WINDOW_WIDTH - EDGE_MARGIN)
    var target_y := usable.position.y + maxi(0, usable.size.y - WINDOW_HEIGHT - EDGE_MARGIN)
    window.position = Vector2i(target_x, target_y)

func _create_control_window() -> void:
    # Separate native window: unlike the overlay, this window remains clickable.
    garage = Window.new()
    garage.visible = false
    garage.force_native = true
    garage.title = "Туман | Управление прототипом"
    garage.size = Vector2i(340, 270)
    garage.unresizable = true
    garage.transparent = false
    garage.borderless = false
    garage.always_on_top = false
    garage.close_requested.connect(_on_garage_close_requested)
    add_child(garage)
    var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
    garage.position = usable.position + Vector2i(30, 30)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 12)
    garage.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var layout := VBoxContainer.new()
    margin.add_child(layout)
    var heading := Label.new()
    heading.text = "ТУМАН: технический прототип"
    layout.add_child(heading)
    status_label = Label.new()
    status_label.text = "Режим: патруль | 30 FPS"
    layout.add_child(status_label)
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
    var spray_button := Button.new()
    spray_button.text = "Распыление: вкл."
    spray_button.pressed.connect(func() -> void:
        spray_enabled = not spray_enabled
        spray_button.text = "Распыление: вкл." if spray_enabled else "Распыление: выкл."
        queue_redraw()
    )
    layout.add_child(spray_button)
    var quit_button := Button.new()
    quit_button.text = "Выход из игры"
    quit_button.pressed.connect(func() -> void: get_tree().quit())
    layout.add_child(quit_button)
    garage.show()

func _toggle_overlay() -> void:
    overlay_enabled = not overlay_enabled
    toggle_button.text = "Скрыть Тумана" if overlay_enabled else "Показать Тумана"
    if is_instance_valid(status_label):
        status_label.text = "Режим: %s | %d FPS" % ["патруль" if overlay_enabled else "скрыт", Engine.max_fps]
    queue_redraw()

func _toggle_fps() -> void:
    Engine.max_fps = 15 if Engine.max_fps == 30 else 30
    fps_button.text = "FPS: %d (переключить)" % Engine.max_fps
    if is_instance_valid(status_label):
        status_label.text = "Режим: %s | %d FPS" % ["патруль" if overlay_enabled else "скрыт", Engine.max_fps]

func _on_garage_close_requested() -> void:
    # Closing the control window exits: never strand an unclickable overlay.
    get_tree().quit()
