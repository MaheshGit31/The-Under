extends Node2D

const LINES_A := [
	["everyone left hours ago.", 1.1],
	["i stayed behind to finish my project in the old art room.", 1.4],
	["that's when i heard it.", 1.0],
	["a knock. from under the floor.", 0.6],
]
const LINES_B := [
	["slow. patient.", 0.9],
	["like it knew i was here.", 1.4],
]
const LINES_C := [
	["ow.", 0.9],
	["...where am i?", 1.3],
	["it's so dark. the walls never end.", 1.5],
	["i have to find a way out.", 1.6],
]

var F16: Font = load("res://fonts/pixel16.fnt")
var F8: Font = load("res://fonts/pixel8.fnt")
var line: Label
var stage: Node2D
var cover: ColorRect
var skip_line := false
var finished := false


func _ready() -> void:
	Game.reset()
	Game.play_music("intro", true, -5.0)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(640, 360)
	add_child(bg)
	stage = Node2D.new()
	add_child(stage)
	line = Label.new()
	line.add_theme_font_override("font", F16)
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", Color(0.91, 0.89, 0.82))
	line.position = Vector2(40, 150)
	line.size = Vector2(560, 60)
	line.custom_minimum_size = Vector2(560, 60)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.text = ""
	add_child(line)
	var hint := Label.new()
	hint.add_theme_font_override("font", F8)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.35, 0.33, 0.42))
	hint.text = "enter  next line      esc  skip"
	hint.position = Vector2(0, 340)
	hint.size = Vector2(640, 0)
	hint.custom_minimum_size = Vector2(640, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	cover = ColorRect.new()
	cover.color = Color(0, 0, 0, 1)
	cover.size = Vector2(640, 360)
	add_child(cover)
	_run()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		skip_line = true
	if event.is_action_pressed("menu"):
		_finish()


func _tick(sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if skip_line:
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _type(text: String, hold: float) -> void:
	line.text = text
	line.modulate.a = 1.0
	line.visible_characters = 0
	for i in text.length():
		line.visible_characters = i + 1
		if await _tick(0.045):
			line.visible_characters = -1
			skip_line = false
			break
	await _tick(hold)
	skip_line = false
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.25)
	await tw.finished


func _fade_cover(to: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(cover, "color:a", to, time)
	await tw.finished


func _run() -> void:
	await _fade_cover(0.0, 1.5)
	await _tick(0.6)
	for l in LINES_A:
		if finished:
			return
		await _type(l[0], l[1])
	for i in 3:
		Game.sfx("knock")
		_jolt(3.0)
		await _tick(0.55)
	await _tick(0.8)
	for l in LINES_B:
		if finished:
			return
		await _type(l[0], l[1])
	await _fall()
	if finished:
		return
	for l in LINES_C:
		if finished:
			return
		await _type(l[0], l[1])
	await _fade_cover(1.0, 0.8)
	_finish()


func _jolt(power: float) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(self, "position", Vector2(randf_range(-power, power), randf_range(-power, power)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _fall() -> void:
	await _fade_cover(1.0, 0.3)
	line.text = ""
	if ResourceLoader.exists("res://sprites/intro/fall_01.png"):
		await _fall_frames()
	else:
		await _fall_placeholder()
	Game.sfx("thud")
	_jolt(8.0)
	cover.color = Color(1, 1, 1, 1)
	await _fade_cover(1.0, 0.05)
	stage.queue_free()
	stage = Node2D.new()
	add_child(stage)
	await _tick(1.4)


func _fall_frames() -> void:
	var frames: Array = []
	var i := 1
	while ResourceLoader.exists("res://sprites/intro/fall_%02d.png" % i):
		frames.append(load("res://sprites/intro/fall_%02d.png" % i))
		i += 1
	var s := Sprite2D.new()
	s.centered = false
	s.scale = Vector2(2, 2)
	stage.add_child(s)
	await _fade_cover(0.0, 0.2)
	var cues := {0: "knock", 3: "knock", 6: "knock", 8: "crack", 12: "whoosh"}
	for idx in frames.size():
		s.texture = frames[idx]
		if cues.has(idx):
			Game.sfx(cues[idx])
			if cues[idx] != "whoosh":
				_jolt(2.0)
		await _tick(0.125)
	await _tick(0.2)


func _fall_placeholder() -> void:
	var ground := Sprite2D.new()
	ground.texture = load("res://sprites/tiles/tile_floor_01.png")
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 640, 360)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.modulate = Color(0.5, 0.5, 0.6)
	stage.add_child(ground)
	var hole := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(Vector2(cos(a), sin(a)) * (18.0 + randf_range(-3, 3)))
	hole.polygon = pts
	hole.color = Color.BLACK
	hole.position = Vector2(320, 190)
	hole.scale = Vector2(0.05, 0.05)
	stage.add_child(hole)
	var p := Sprite2D.new()
	p.texture = load("res://sprites/player/player_down_idle.png")
	p.position = Vector2(320, 180)
	p.scale = Vector2(4, 4)
	stage.add_child(p)
	await _fade_cover(0.0, 0.3)
	for i in 4:
		Game.sfx("knock")
		_jolt(2.0)
		await _tick(0.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(hole, "scale", Vector2(5.5, 5.5), 1.0)
	await tw.finished
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(p, "scale", Vector2(0.2, 0.2), 1.4).set_ease(Tween.EASE_IN)
	tw2.tween_property(p, "rotation", TAU * 1.5, 1.4)
	tw2.tween_property(p, "position", Vector2(320, 205), 1.4)
	tw2.tween_property(p, "modulate", Color(0.1, 0.1, 0.15), 1.4)
	await tw2.finished
	await _tick(0.2)


func _finish() -> void:
	if finished:
		return
	finished = true
	Game.intro_seen = true
	Game.stop_music()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
