extends Node2D
## Prototype-only: transparent window and stylized sprayer drawn from primitives.
## The overlay becomes click-through only after a separate, always-accessible control window exists.

const SPEED := 52.0
const METERS_PER_COIN := 10.0
const SAVE_PATH := "user://save.json"
var coins := 0
var distance_m := 0.0
var reward_progress := 0.0
var engine_level := 1
var autosave_elapsed := 0.0
var coins_label: Label
var distance_label: Label
var engine_label: Label
var upgrade_button: Button
const SPRAYER_SCALE := 0.40
const WINDOW_WIDTH := 440
const WINDOW_HEIGHT := 52
const EDGE_MARGIN := 2
const TASKBAR_OVERLAP := 14
var last_usable_rect := Rect2i()
var tractor_x := 80.0
var direction := 1.0
const TURN_DURATION := 0.32
var turning := false
var turn_elapsed := 0.0
var turn_from := 1.0
var facing_scale := 1.0
var wheel_phase := 0.0
var overlay_enabled := true
var garage: Window
var toggle_button: Button
var fps_button: Button
var status_label: Label
var spray_enabled := true
var paused := false
var tray: StatusIndicator
var tray_menu: PopupMenu
var tray_available := false
var meshy_strip: Texture2D
var spray_phase := 0.0
var sprayer_atlas: Texture2D
var sprayer_body: Texture2D
var sprayer_wheels: Array[Texture2D] = []

func _ready() -> void:
    get_viewport().transparent_bg = true
    var window := get_window()
    window.borderless = true
    window.transparent = true
    window.always_on_top = true
    Engine.max_fps = 30
    _load_sprite_layers()
    _load_progress()
    _position_above_taskbar()
    if DisplayServer.get_name() == "headless":
        return
    _create_control_window()
    _create_tray()
    if tray_available and OS.get_name() == "Windows":
        _hide_windows_from_taskbar()
    if garage.get_window_id() != DisplayServer.INVALID_WINDOW_ID:
        window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)

func _process(delta: float) -> void:
    var screen := DisplayServer.window_get_current_screen()
    var usable := DisplayServer.screen_get_usable_rect(screen)
    if usable != last_usable_rect:
        _position_above_taskbar()
    if not overlay_enabled or paused:
        return
    autosave_elapsed += delta
    if autosave_elapsed >= 30.0:
        autosave_elapsed = 0.0
        _save_progress()
    if turning:
        turn_elapsed = minf(turn_elapsed + delta, TURN_DURATION)
        # Turn in place: no position jump and no instantaneous mirroring.
        var t := turn_elapsed / TURN_DURATION
        facing_scale = lerpf(turn_from, -turn_from, smoothstep(0.0, 1.0, t))
        if turn_elapsed >= TURN_DURATION:
            turning = false
            direction = -turn_from
            facing_scale = direction
    else:
        var before_x := tractor_x
        tractor_x += direction * SPEED * pow(1.05, engine_level - 1) * delta
        wheel_phase += delta * 8.0
        spray_phase += delta * 7.0
        var right_bound := float(WINDOW_WIDTH) - 65.0
        var left_bound := 65.0
        if tractor_x >= right_bound or tractor_x <= left_bound:
            tractor_x = clampf(tractor_x, left_bound, right_bound)
            turning = true
            turn_elapsed = 0.0
            turn_from = direction
        _earn_distance(absf(tractor_x - before_x))
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
        _save_progress()

func _upgrade_cost() -> int:
    return int(ceil(10.0 * pow(1.5, engine_level - 1)))

func _earn_distance(amount: float) -> void:
    if amount <= 0.0:
        return
    distance_m += amount
    reward_progress += amount
    var earned := int(floor(reward_progress / METERS_PER_COIN))
    if earned > 0:
        reward_progress -= float(earned) * METERS_PER_COIN
        coins += earned
    _refresh_progress_ui()

func _upgrade_engine() -> void:
    var cost := _upgrade_cost()
    if coins < cost:
        return
    coins -= cost
    engine_level += 1
    _refresh_progress_ui()
    _save_progress()

func _refresh_progress_ui() -> void:
    if not is_instance_valid(coins_label):
        return
    coins_label.text = "Монеты: %d" % coins
    distance_label.text = "Пройдено: %.1f м" % distance_m
    engine_label.text = "Двигатель: уровень %d | скорость +%.1f%%" % [engine_level, (pow(1.05, engine_level - 1) - 1.0) * 100.0]
    upgrade_button.text = "Улучшить двигатель (%d монет)" % _upgrade_cost()
    upgrade_button.disabled = coins < _upgrade_cost()

func _save_progress() -> void:
    var data := {
        "version": 1,
        "coins": coins,
        "distance_m": distance_m,
        "reward_progress": reward_progress,
        "engine_level": engine_level
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Tuman: could not write save.json")
        return
    file.store_string(JSON.stringify(data))
    file.close()

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("Tuman: could not read save.json")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        push_warning("Tuman: invalid save.json, starting new progress")
        return
    var data: Dictionary = parsed
    if not (data.get("coins") is int or data.get("coins") is float) or not (data.get("distance_m") is int or data.get("distance_m") is float) or not (data.get("engine_level") is int or data.get("engine_level") is float):
        push_warning("Tuman: save.json has invalid fields")
        return
    coins = maxi(0, int(data["coins"]))
    distance_m = maxf(0.0, float(data["distance_m"]))
    engine_level = clampi(int(data["engine_level"]), 1, 100)
    reward_progress = clampf(float(data.get("reward_progress", 0.0)), 0.0, METERS_PER_COIN - 0.001)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _save_progress()
        get_tree().quit()

func _draw() -> void:
    if not overlay_enabled:
        return
    var x := tractor_x
    # Wheels visually overlap the taskbar top by a few pixels.
    var y := 30.0
    if meshy_strip != null:
        _draw_meshy_sprayer()
        return
    draw_set_transform(Vector2(x, y), 0.0, Vector2(facing_scale * SPRAYER_SCALE, SPRAYER_SCALE))
    if sprayer_atlas != null:
        _draw_atlas_sprayer()
        draw_set_transform(Vector2.ZERO)
        return
    if sprayer_body != null and sprayer_wheels.size() == 3:
        _draw_layered_sprayer()
        draw_set_transform(Vector2.ZERO)
        return
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
    # On a bottom-docked Windows taskbar, overlap its top edge slightly.
    # Other taskbar placements remain inside the usable desktop area.
    var target_x := usable.position.x + maxi(0, usable.size.x - WINDOW_WIDTH - EDGE_MARGIN)
    var target_y := usable.position.y + maxi(0, usable.size.y - WINDOW_HEIGHT - EDGE_MARGIN)
    var screen_rect := DisplayServer.screen_get_size(screen)
    var screen_position := DisplayServer.screen_get_position(screen)
    var bottom_taskbar := usable.end.y < screen_position.y + screen_rect.y
    if bottom_taskbar:
        target_y += TASKBAR_OVERLAP
    window.position = Vector2i(target_x, target_y)

func _create_control_window() -> void:
    # Separate native window: unlike the overlay, this window remains clickable.
    garage = Window.new()
    garage.visible = false
    garage.force_native = true
    garage.title = "Туман | Управление прототипом"
    garage.size = Vector2i(360, 390)
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
    heading.text = "ТУМАН: Гараж"
    layout.add_child(heading)
    status_label = Label.new()
    status_label.text = "Режим: патруль | 30 FPS"
    layout.add_child(status_label)
    coins_label = Label.new()
    layout.add_child(coins_label)
    distance_label = Label.new()
    layout.add_child(distance_label)
    engine_label = Label.new()
    layout.add_child(engine_label)
    upgrade_button = Button.new()
    upgrade_button.pressed.connect(_upgrade_engine)
    layout.add_child(upgrade_button)
    _refresh_progress_ui()
    var hint := Label.new()
    hint.text = "Туман зарабатывает монеты во время патруля."
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
    quit_button.pressed.connect(func() -> void:
        _save_progress()
        get_tree().quit()
    )
    layout.add_child(quit_button)
    # Garage remains hidden when a tray icon is available.
    if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
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
    if tray_available:
        garage.hide()
    else:
        get_tree().quit()

func _create_tray() -> void:
    tray_available = DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
    if not tray_available:
        return
    tray_menu = PopupMenu.new()
    tray_menu.add_item("Открыть гараж", 1)
    tray_menu.add_item("Пауза патруля", 2)
    tray_menu.add_separator()
    tray_menu.add_item("Выход", 3)
    tray_menu.id_pressed.connect(_on_tray_menu_item)
    add_child(tray_menu)
    tray = StatusIndicator.new()
    tray.tooltip = "ТУМАН: Битва за урожай"
    tray.icon = _make_tray_icon()
    tray.menu = tray_menu.get_path()
    tray.pressed.connect(_on_tray_pressed)
    add_child(tray)

func _make_tray_icon() -> Texture2D:
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    for y in range(10, 23):
        for x in range(3, 29):
            img.set_pixel(x, y, Color("f2a32b"))
    for y in range(4, 11):
        for x in range(10, 20):
            img.set_pixel(x, y, Color("69c4d9"))
    for cx in [9, 24]:
        for y in range(19, 29):
            for x in range(cx - 5, cx + 5):
                if Vector2(x - cx, y - 24).length_squared() < 25:
                    img.set_pixel(x, y, Color("27333b"))
    return ImageTexture.create_from_image(img)

func _on_tray_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
    if mouse_button == MOUSE_BUTTON_LEFT:
        _show_garage()

func _on_tray_menu_item(id: int) -> void:
    match id:
        1:
            _show_garage()
        2:
            paused = not paused
            tray_menu.set_item_text(1, "Продолжить патруль" if paused else "Пауза патруля")
            if is_instance_valid(status_label):
                status_label.text = "Режим: пауза" if paused else "Режим: патруль"
        3:
            get_tree().quit()

func _show_garage() -> void:
    garage.show()
    garage.grab_focus()


func _load_sprite_layers() -> void:
    if ResourceLoader.exists("res://assets/sprayer/tuman_wheels_strip.png"):
        meshy_strip = load("res://assets/sprayer/tuman_wheels_strip.png") as Texture2D
        return
    var root_path := "res://assets/sprayer/"
    if ResourceLoader.exists(root_path + "atlas.png"):
        sprayer_atlas = load(root_path + "atlas.png") as Texture2D
        return
    var body_path := root_path + "body.png"
    if not ResourceLoader.exists(body_path):
        return
    sprayer_body = load(body_path) as Texture2D
    for i in range(1, 4):
        var wheel_path := root_path + "wheel_%d.png" % i
        if not ResourceLoader.exists(wheel_path):
            sprayer_wheels.clear()
            return
        sprayer_wheels.append(load(wheel_path) as Texture2D)

func _draw_layered_sprayer() -> void:
    # Original image: 1536 x 614. Layers exported at 900 px wide.
    # Draw inside the existing 0.40 transform, producing ~100 px vehicle.
    var width := 250.0
    var height := width * 614.0 / 1536.0
    var left := -125.0
    var top := -height + 39.0
    draw_texture_rect(sprayer_body, Rect2(left, top, width, height), false)
    var centers := [Vector2(609, 442), Vector2(884, 440), Vector2(1266, 442)]
    for i in range(3):
        var center := Vector2(left + centers[i].x * width / 1536.0, top + centers[i].y * height / 614.0)
        var wheel_size := 2.0 * 138.0 * width / 1536.0
        draw_set_transform(Vector2(tractor_x, 30.0) + Vector2(facing_scale * SPRAYER_SCALE * center.x, SPRAYER_SCALE * center.y), wheel_phase * direction, Vector2(direction * SPRAYER_SCALE, SPRAYER_SCALE))
        draw_texture_rect(sprayer_wheels[i], Rect2(-wheel_size * 0.5, -wheel_size * 0.5, wheel_size, wheel_size), false)
    draw_set_transform(Vector2(tractor_x + 55.0, 30.0), 0.0, Vector2(direction * SPRAYER_SCALE, SPRAYER_SCALE))

func _draw_atlas_sprayer() -> void:
    # Atlas: 256x148. Body: 256x102; wheels: 43x43 at x=0,50,100 and y=104.
    # Draw body at ~100px on screen and animate each wheel separately.
    var body_rect := Rect2(0, 0, 256, 102)
    var local_size := Vector2(250, 100)
    var origin := Vector2(-125, -61)
    draw_texture_rect_region(sprayer_atlas, Rect2(origin, local_size), body_rect)
    var centers := [Vector2(609, 442), Vector2(884, 440), Vector2(1266, 442)]
    for i in range(3):
        var center := Vector2(origin.x + centers[i].x * local_size.x / 1536.0, origin.y + centers[i].y * local_size.y / 614.0)
        var size := 43.0
        draw_set_transform(Vector2(tractor_x + 55.0, 30.0) + Vector2(direction * SPRAYER_SCALE * center.x, SPRAYER_SCALE * center.y), wheel_phase * direction, Vector2(direction * SPRAYER_SCALE, SPRAYER_SCALE))
        draw_texture_rect_region(sprayer_atlas, Rect2(-size * 0.5, -size * 0.5, size, size), Rect2(i * 50, 104, 43, 43))
    draw_set_transform(Vector2(tractor_x + 55.0, 30.0), 0.0, Vector2(direction * SPRAYER_SCALE, SPRAYER_SCALE))

func _hide_windows_from_taskbar() -> void:
    # Windows-only helper. Keep tray available before hiding taskbar buttons.
    var source := "res://windows/hide_taskbar.ps1"
    if not FileAccess.file_exists(source):
        push_warning("Windows taskbar helper is missing; leaving taskbar buttons visible.")
        return
    var script_text := FileAccess.get_file_as_string(source)
    if script_text.is_empty():
        return
    var destination := "user://tuman_hide_taskbar.ps1"
    var output := FileAccess.open(destination, FileAccess.WRITE)
    if output == null:
        push_warning("Cannot write taskbar helper.")
        return
    output.store_string(script_text)
    output.close()
    var args := PackedStringArray([
        "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass", "-File",
        ProjectSettings.globalize_path(destination),
        "-TargetPid", str(OS.get_process_id())
    ])
    var helper_pid := OS.create_process("powershell.exe", args, false)
    if helper_pid <= 0:
        push_warning("Could not start Windows taskbar helper.")

func _draw_meshy_sprayer() -> void:
    # Pre-rendered Blender frames: realistic Meshy model, tiny runtime cost.
    var frame := posmod(int(floor(wheel_phase * 8.0 / TAU)), 8)
    var src := Rect2(frame * 256.0, 0.0, 256.0, 112.0)
    var w := 112.0
    var h := 49.0
    var center := Vector2(tractor_x, 26.0)
    draw_set_transform(center, 0.0, Vector2(facing_scale, 1.0))
    draw_texture_rect_region(meshy_strip, Rect2(-w * 0.5, -24.0, w, h), src)
    if spray_enabled and not paused and not turning:
        # Animated droplets emerge from the boom on the left of the sprayer.
        for i in range(8):
            var phase := fposmod(spray_phase + float(i) * 0.67, 1.0)
            var drop_x := -49.0 + float(i % 4) * 9.0
            var drop_y := 1.0 + phase * 17.0
            draw_circle(Vector2(drop_x, drop_y), 0.9 + phase * 0.4, Color(0.40, 0.82, 0.95, (1.0 - phase) * 0.65))
    draw_set_transform(Vector2.ZERO)
