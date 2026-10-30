extends Node2D

var F16: Font = load("res://fonts/pixel16.fnt")
var F8: Font = load("res://fonts/pixel8.fnt")
var eyes: Sprite2D
var logo: Sprite2D
var fog_a: Sprite2D
var fog_b: Sprite2D
var open_tex: Texture2D = load("res://sprites/watcher/eyes_open.png")
var blink_tex: Texture2D = load("res://sprites/watcher/eyes_blink.png")
var starting := false
var cover: ColorRect


func _ready() -> void:
	Game.reset()
	Game.play_music("title", true, -3.0)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.size = Vector2(640, 360)
	add_child(bg)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 640
	tex.height = 360
	tex.seamless = true
	fog_a = Sprite2D.new()
	fog_a.texture = tex
	fog_a.centered = false
	fog_a.modulate = Color(0.55, 0.6, 0.7, 0.16)
	add_child(fog_a)
	fog_b = Sprite2D.new()
	fog_b.texture = tex
	fog_b.centered = false
	fog_b.position = Vector2(640, 0)
	fog_b.modulate = Color(0.55, 0.6, 0.7, 0.16)
	add_child(fog_b)
	eyes = Sprite2D.new()
	eyes.texture = open_tex
	eyes.position = Vector2(320, 92)
	eyes.scale = Vector2(2, 2)
	eyes.modulate.a = 0.0
	add_child(eyes)
	var grow := create_tween().set_loops()
	grow.tween_property(eyes, "scale", Vector2(5, 5), 28.0)
	grow.tween_property(eyes, "scale", Vector2(2, 2), 0.01)
	var appear := create_tween()
	appear.tween_interval(1.5)
	appear.tween_property(eyes, "modulate:a", 1.0, 3.0)
	logo = Sprite2D.new()
	logo.texture = load("res://sprites/ui/ui_logo.png")
	logo.position = Vector2(320, 208)
	logo.scale = Vector2(1.5, 1.5)
	logo.modulate.a = 0.0
	add_child(logo)
	var lt := create_tween()
	lt.tween_interval(0.8)
	lt.tween_property(logo, "modulate:a", 1.0, 2.0)
	var start := _label("descend", F16, Color(0.91, 0.89, 0.82), Vector2(0, 276))
	add_child(start)
	var blink := create_tween().set_loops()
	blink.tween_property(start, "modulate:a", 0.2, 1.0)
	blink.tween_property(start, "modulate:a", 1.0, 1.0)
	add_child(_label("enter", F8, Color(0.5, 0.47, 0.56), Vector2(0, 300)))
	cover = ColorRect.new()
	cover.color = Color(0, 0, 0, 1)
	cover.size = Vector2(640, 360)
	add_child(cover)
	var ci := create_tween()
	ci.tween_property(cover, "color:a", 0.0, 1.2)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(_blink_eyes)
	add_child(timer)
	timer.start()


func _label(text: String, font: Font, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", (font as FontFile).fixed_size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	l.size = Vector2(640, 0)
	l.custom_minimum_size = Vector2(640, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _blink_eyes() -> void:
	eyes.texture = blink_tex
	await get_tree().create_timer(0.18).timeout
	eyes.texture = open_tex
	var timer := get_children().filter(func(n): return n is Timer)
	if not timer.is_empty():
		timer[0].wait_time = randf_range(2.5, 6.5)


func _process(delta: float) -> void:
	fog_a.position.x -= delta * 9.0
	fog_b.position.x -= delta * 9.0
	if fog_a.position.x <= -640.0:
		fog_a.position.x += 1280.0
	if fog_b.position.x <= -640.0:
		fog_b.position.x += 1280.0
	if randf() < 0.03 and not starting:
		logo.modulate.a = randf_range(0.55, 1.0)
	if Input.is_action_just_pressed("confirm") and not starting:
		starting = true
		Game.sfx("thud", -4.0)
		var tw := create_tween()
		tw.tween_property(cover, "color:a", 1.0, 1.0)
		tw.tween_callback(func():
			Game.stop_music()
			get_tree().change_scene_to_file("res://scenes/intro.tscn"))
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
