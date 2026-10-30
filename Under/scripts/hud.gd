class_name Hud
extends CanvasLayer

var F8: Font = load("res://fonts/pixel8.fnt")
var F16: Font = load("res://fonts/pixel16.fnt")
var F24: Font = load("res://fonts/pixel24.fnt")

var key_icon: Sprite2D
var light_icon: Sprite2D
var danger: ColorRect
var bar_fill: ColorRect
var bar_label: Label
var bar_root: Control
var box: Control
var box_label: Label
var queue: Array = []
var showing := false
var ended := false
var end_root: Control
var mission_root: Control
var mission_body: Control
var mission_rows: Array = []
var mission_tip: Label


func _ready() -> void:
	layer = 10
	danger = ColorRect.new()
	danger.color = Color(0.7, 0.0, 0.0, 0.0)
	danger.size = Vector2(640, 360)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(danger)
	var slot := Sprite2D.new()
	slot.texture = load("res://sprites/ui/ui_slot.png")
	slot.position = Vector2(24, 24)
	slot.scale = Vector2(1.5, 1.5)
	add_child(slot)
	key_icon = Sprite2D.new()
	key_icon.texture = load("res://sprites/items/item_key.png")
	key_icon.position = Vector2(24, 24)
	key_icon.visible = false
	add_child(key_icon)
	light_icon = Sprite2D.new()
	light_icon.texture = load("res://sprites/ui/ui_flashlight.png")
	light_icon.position = Vector2(54, 24)
	add_child(light_icon)
	_build_bar()
	_build_box()
	_build_mission()
	Game.dialogue.connect(_on_dialogue)


func _label(text: String, font: Font, color: Color, pos: Vector2, width: float = 0.0, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", (font as FontFile).fixed_size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, 0)
		l.custom_minimum_size = Vector2(width, 0)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_bar() -> void:
	bar_root = Control.new()
	bar_root.position = Vector2(468, 12)
	add_child(bar_root)
	bar_label = _label("atmosphere", F8, Color(0.91, 0.89, 0.82), Vector2(0, 0))
	bar_root.add_child(bar_label)
	var frame := ColorRect.new()
	frame.color = Color(0.91, 0.89, 0.82)
	frame.position = Vector2(0, 14)
	frame.size = Vector2(160, 10)
	bar_root.add_child(frame)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.07)
	back.position = Vector2(1, 15)
	back.size = Vector2(158, 8)
	bar_root.add_child(back)
	bar_fill = ColorRect.new()
	bar_fill.position = Vector2(2, 16)
	bar_fill.size = Vector2(156, 6)
	bar_root.add_child(bar_fill)


func _build_mission() -> void:
	mission_root = Control.new()
	mission_root.position = Vector2(436, 40)
	add_child(mission_root)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.02, 0.05, 0.6)
	back.size = Vector2(196, 14)
	mission_root.add_child(back)
	mission_root.add_child(_label("mission", F8, Color(0.91, 0.89, 0.82), Vector2(6, 2)))
	mission_root.add_child(_label("tab", F8, Color(0.45, 0.42, 0.52), Vector2(166, 2)))
	mission_body = Control.new()
	mission_body.position = Vector2(0, 14)
	mission_root.add_child(mission_body)
	var body_back := ColorRect.new()
	body_back.color = Color(0.03, 0.02, 0.05, 0.45)
	body_back.size = Vector2(196, 64)
	mission_body.add_child(body_back)
	var texts := ["find the key", "unlock the locked door", "find the exit and escape"]
	for i in texts.size():
		var box_sq := ColorRect.new()
		box_sq.position = Vector2(8, 7 + i * 13)
		box_sq.size = Vector2(6, 6)
		mission_body.add_child(box_sq)
		var inner := ColorRect.new()
		inner.position = Vector2(1, 1)
		inner.size = Vector2(4, 4)
		inner.color = Color(0.03, 0.02, 0.05)
		box_sq.add_child(inner)
		var l := _label(texts[i], F8, Color(0.91, 0.89, 0.82), Vector2(20, 5 + i * 13))
		mission_body.add_child(l)
		mission_rows.append([box_sq, inner, l])
	mission_tip = _label("", F8, Color(0.62, 0.35, 0.35), Vector2(8, 46))
	mission_body.add_child(mission_tip)


func _update_mission() -> void:
	if Input.is_action_just_pressed("mission"):
		mission_body.visible = not mission_body.visible
	var done := [Game.has_key or Game.door_open, Game.door_open, Game.escaped]
	var current := done.find(false)
	for i in mission_rows.size():
		var row: Array = mission_rows[i]
		var sq: ColorRect = row[0]
		var inner: ColorRect = row[1]
		var l: Label = row[2]
		if done[i]:
			sq.color = Color(0.45, 0.42, 0.52)
			inner.color = Color(0.45, 0.42, 0.52)
			l.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52))
		elif i == current:
			sq.color = Color(0.91, 0.89, 0.82)
			inner.color = Color(0.03, 0.02, 0.05)
			l.add_theme_color_override("font_color", Color(0.91, 0.89, 0.82))
		else:
			sq.color = Color(0.3, 0.28, 0.36)
			inner.color = Color(0.03, 0.02, 0.05)
			l.add_theme_color_override("font_color", Color(0.4, 0.38, 0.46))
	mission_tip.text = "run. break line of sight." if Game.chasing else "stay quiet. keep your distance."


func _build_box() -> void:
	box = Control.new()
	box.position = Vector2(40, 292)
	box.modulate.a = 0.0
	add_child(box)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.02, 0.05, 0.85)
	back.size = Vector2(560, 52)
	box.add_child(back)
	var edge := ColorRect.new()
	edge.color = Color(0.7, 0.18, 0.18)
	edge.size = Vector2(560, 2)
	box.add_child(edge)
	box_label = _label("", F16, Color(0.91, 0.89, 0.82), Vector2(12, 10), 536)
	box_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(box_label)


func _on_dialogue(text: String, duration: float) -> void:
	queue.append([text, duration])
	if not showing:
		_next_line()


func _next_line() -> void:
	if queue.is_empty():
		showing = false
		return
	showing = true
	var item: Array = queue.pop_front()
	box_label.text = item[0]
	box_label.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_property(box_label, "visible_ratio", 1.0, maxf(0.3, item[0].length() * 0.035))
	tw.tween_interval(item[1])
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_next_line)


func _process(delta: float) -> void:
	key_icon.visible = Game.has_key
	_update_mission()
	light_icon.modulate = Color.WHITE if Game.flashlight_on else Color(1, 1, 1, 0.25)
	var frac := clampf(Game.atmosphere / 100.0, 0.0, 1.0)
	bar_fill.size.x = 156.0 * frac
	bar_fill.color = Color(0.7, 0.18, 0.18).lerp(Color(0.91, 0.89, 0.82), frac)
	bar_root.modulate.a = 1.0 if frac > 0.3 else (0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 120.0)))
	bar_root.position = Vector2(468, 12) + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) if frac < 0.2 else Vector2.ZERO)
	var target := maxf(0.22 if Game.chasing else 0.0, (1.0 - frac) * 0.28)
	danger.color.a = move_toward(danger.color.a, target, delta * 0.6)
	if not ended and (Game.game_over or Game.escaped):
		ended = true
		if Game.game_over:
			_death()
		else:
			_win()


func _end_text(title: String, sub: String, color: Color, y: float) -> void:
	end_root.add_child(_label(title, F24, color, Vector2(0, y), 640, true))
	end_root.add_child(_label(sub, F16, Color(0.6, 0.57, 0.65), Vector2(0, y + 48), 640, true))
	var hint := _label("r  try again          esc  menu", F16, Color(0.91, 0.89, 0.82), Vector2(0, 300), 640, true)
	end_root.add_child(hint)
	var tw := create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.25, 0.9)
	tw.tween_property(hint, "modulate:a", 1.0, 0.9)


func _death() -> void:
	box.modulate.a = 0.0
	queue.clear()
	end_root = Control.new()
	add_child(end_root)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.size = Vector2(640, 360)
	black.modulate.a = 0.0
	end_root.add_child(black)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = Vector2(640, 360)
	end_root.add_child(flash)
	var face := Sprite2D.new()
	face.texture = load("res://sprites/watcher/watcher_chase3.png")
	face.position = Vector2(320, 190)
	face.scale = Vector2(11, 11)
	face.visible = false
	end_root.add_child(face)
	var tw := create_tween()
	tw.tween_property(black, "modulate:a", 1.0, 0.12)
	tw.tween_callback(func(): face.visible = true)
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	for i in 10:
		tw.tween_property(face, "position", Vector2(320 + randf_range(-14, 14), 190 + randf_range(-10, 10)), 0.05)
	tw.tween_property(face, "scale", Vector2(16, 16), 0.5)
	tw.tween_property(face, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		Game.play_music("death", false, -2.0)
		_end_text("you died", "nobody is coming for you", Color(0.8, 0.15, 0.15), 120))


func _win() -> void:
	box.modulate.a = 0.0
	queue.clear()
	end_root = Control.new()
	add_child(end_root)
	var fade := ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.04, 1)
	fade.size = Vector2(640, 360)
	fade.modulate.a = 0.0
	end_root.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 1.4)
	tw.tween_callback(func():
		Game.play_music("win", false, -2.0)
		_end_text("you made it out", "but something is still under there", Color(0.85, 0.9, 0.8), 120))
