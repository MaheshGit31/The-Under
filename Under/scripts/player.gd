class_name Player  # lets other scripts say "Player" as a type
extends CharacterBody2D  # a body we move ourselves and that slides along walls

const WALK_SPEED := 70.0  # pixels per second when walking
const SPRINT_SPEED := 112.0  # pixels per second when holding shift
const LIGHT_ON_SCALE := 1.05  # flashlight radius when on
const LIGHT_OFF_SCALE := 0.2  # tiny glow when the flashlight is off

var is_sprinting := false  # the watcher reads this to hear you
var facing := "down"  # which way the player looks: down, up or side
var anim: AnimatedSprite2D  # plays the walking animations
var light: PointLight2D  # the flashlight
var camera: Camera2D  # follows the player
var _step_timer := 0.0  # counts down to the next footstep sound


func _ready() -> void:  # runs when the player enters the scene
	collision_layer = 2  # the player lives on physics layer 2
	collision_mask = 9
	var shape := CollisionShape2D.new()  # the hitbox node
	var rect := RectangleShape2D.new()  # a rectangle hitbox
	rect.size = Vector2(10, 10)  # a bit smaller than a tile so corridors feel fair
	shape.shape = rect  # give the node its rectangle
	add_child(shape)  # attach it to the player
	anim = AnimatedSprite2D.new()  # create the sprite
	anim.sprite_frames = _build_frames()  # fill it with our animations
	add_child(anim)  # attach it
	anim.play("idle_down")  # start standing still
	light = PointLight2D.new()  # the flashlight node
	light.texture = make_light_texture()  # soft round light
	light.shadow_enabled = true  # walls block the light
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5  # softer shadow edges
	light.energy = 1.3  # how bright it is
	light.color = Color(1.0, 0.95, 0.8)  # slightly warm white
	light.texture_scale = LIGHT_ON_SCALE  # starts switched on
	add_child(light)  # attach it
	camera = Camera2D.new()  # camera that follows the player
	camera.zoom = Vector2(2, 2)  # zoom in for a claustrophobic view
	camera.position_smoothing_enabled = true  # smooth following
	camera.position_smoothing_speed = 8.0  # how quickly it catches up
	add_child(camera)  # attach it
	camera.make_current()  # use this camera


static func make_light_texture() -> Texture2D:  # builds a soft radial gradient (also used by other scripts)
	var grad := Gradient.new()  # color ramp
	grad.colors = PackedColorArray([Color.WHITE, Color.BLACK])  # bright centre to dark edge
	grad.offsets = PackedFloat32Array([0.0, 1.0])  # positions of those two colors
	var tex := GradientTexture2D.new()  # a 2D texture made from the ramp
	tex.gradient = grad  # use our ramp
	tex.fill = GradientTexture2D.FILL_RADIAL  # circle instead of a line
	tex.fill_from = Vector2(0.5, 0.5)  # start at the centre
	tex.fill_to = Vector2(1.0, 0.5)  # end at the middle of the right edge
	tex.width = 256  # texture width in pixels
	tex.height = 256  # texture height in pixels
	return tex  # hand it back


func _build_frames() -> SpriteFrames:  # creates every animation from the png files
	var sf := SpriteFrames.new()  # container for animations
	if sf.has_animation("default"):  # new SpriteFrames starts with one we do not need
		sf.remove_animation("default")  # remove it
	for dir in ["down", "up", "side"]:  # one set of animations per direction
		var idle: Texture2D = load("res://sprites/player/player_%s_idle.png" % dir)  # standing frame
		var w1: Texture2D = load("res://sprites/player/player_%s_walk1.png" % dir)  # first walking frame
		var w2: Texture2D = load("res://sprites/player/player_%s_walk2.png" % dir)  # second walking frame
		sf.add_animation("idle_" + dir)  # create the idle animation
		sf.set_animation_loop("idle_" + dir, true)  # it loops
		sf.add_frame("idle_" + dir, idle)  # one frame only
		sf.add_animation("walk_" + dir)  # create the walk animation
		sf.set_animation_loop("walk_" + dir, true)  # it loops
		sf.set_animation_speed("walk_" + dir, 7.0)  # frames per second
		for f in [w1, idle, w2, idle]:  # step, stand, step, stand
			sf.add_frame("walk_" + dir, f)  # add each frame in order
	return sf  # all done


func _process(_delta: float) -> void:
	var base := LIGHT_ON_SCALE if Game.flashlight_on else LIGHT_OFF_SCALE
	light.texture_scale = base * lerpf(0.5, 1.0, clampf(Game.atmosphere / 100.0, 0.0, 1.0))
	light.energy = 1.3 if Game.atmosphere > 25.0 else 1.3 * randf_range(0.35, 1.0)
	if Game.shake_time > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake_power
	else:
		camera.offset = Vector2.ZERO


func _physics_process(_delta: float) -> void:  # runs every physics frame
	if Game.game_over or Game.escaped:  # the run has ended
		velocity = Vector2.ZERO  # stand still
		anim.play("idle_" + facing)  # idle pose
		return  # skip the rest
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")  # direction from the keys
	is_sprinting = Input.is_action_pressed("sprint") and dir != Vector2.ZERO  # running only while moving
	velocity = dir * (SPRINT_SPEED if is_sprinting else WALK_SPEED)  # speed in that direction
	move_and_slide()  # move and slide along walls
	_animate(dir)  # pick the right animation
	_footsteps(_delta, dir)  # make step sounds
	if Input.is_action_just_pressed("flashlight"):  # F was pressed
		Game.flashlight_on = not Game.flashlight_on  # flip the flag
		Game.sfx("click")  # click sound if the file exists


func _animate(dir: Vector2) -> void:  # chooses animation and flipping
	if dir != Vector2.ZERO:  # moving
		if absf(dir.x) > absf(dir.y):  # mostly sideways
			facing = "side"  # use the side sprites
			anim.flip_h = dir.x < 0.0  # mirror for left
		else:  # mostly vertical
			facing = "down" if dir.y > 0.0 else "up"  # down or up
			anim.flip_h = false  # no mirroring
		anim.speed_scale = 1.6 if is_sprinting else 1.0  # animate faster when running
		anim.play("walk_" + facing)  # walking animation
	else:  # standing still
		anim.speed_scale = 1.0  # normal speed
		anim.play("idle_" + facing)  # idle animation


func _footsteps(delta: float, dir: Vector2) -> void:  # plays footstep sounds on a timer
	if dir == Vector2.ZERO:  # not moving
		_step_timer = 0.0  # reset
		return  # nothing to play
	_step_timer -= delta  # count down
	if _step_timer <= 0.0:  # time for a step
		_step_timer = 0.3 if is_sprinting else 0.5
		Game.sfx("step%d" % randi_range(1, 3), -11.0 if not is_sprinting else -7.0, randf_range(0.88, 1.12))
