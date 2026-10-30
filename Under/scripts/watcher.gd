class_name Watcher  # the thing hunting you
extends CharacterBody2D  # moves by itself and slides along walls

enum State { PATROL, CHASE }  # what the watcher is doing

const PATROL_SPEED := 38.0  # slow creeping speed
const CHASE_SPEED := 78.0  # faster than walking (70) but slower than sprinting (112)
const LOSE_TIME := 5.0  # seconds without seeing you before it gives up
const CATCH_DISTANCE := 11.0  # how close it must get to catch you

var level  # the main scene (gives us the pathfinding grid)
var player: Player  # who we are hunting
var state := State.PATROL  # current behaviour
var path: Array = []  # list of tiles we still need to walk through
var anim: AnimatedSprite2D  # the sprite
var _repath_timer := 0.0  # counts down to the next path calculation
var _lose_timer := 0.0  # time since we last saw the player
var _had_chase_sound := false  # so the growl only plays once per chase


func _ready() -> void:  # runs when the watcher enters the scene
	collision_layer = 4  # the watcher lives on layer 4
	collision_mask = 1  # and collides with walls (layer 1)
	var shape := CollisionShape2D.new()  # hitbox node
	var rect := RectangleShape2D.new()  # rectangle hitbox
	rect.size = Vector2(10, 10)  # same size as the player
	shape.shape = rect  # assign it
	add_child(shape)  # attach it
	anim = AnimatedSprite2D.new()  # sprite node
	anim.sprite_frames = _build_frames()  # load animations
	anim.offset = Vector2(0, -8)  # lift the 24x32 sprite so its feet sit on the hitbox
	add_child(anim)  # attach it
	anim.play("idle")  # start idle
	var glow := PointLight2D.new()  # faint red glow so you can see it coming
	glow.texture = Player.make_light_texture()  # reuse the soft light texture
	glow.color = Color(0.9, 0.1, 0.1)  # red
	glow.energy = 0.45  # very dim
	glow.texture_scale = 0.28  # small radius
	add_child(glow)  # attach it


func _build_frames() -> SpriteFrames:  # builds idle, walk and chase animations
	var sf := SpriteFrames.new()  # container
	if sf.has_animation("default"):  # remove the unused default
		sf.remove_animation("default")  # remove it
	var sets := {  # animation name -> [frame prefix, frame count, fps]
		"idle": ["idle", 2, 2.0],  # slow breathing
		"walk": ["walk", 4, 5.0],  # creeping
		"chase": ["chase", 4, 10.0],  # sprinting at you
	}
	for anim_name in sets:  # build each animation
		var info: Array = sets[anim_name]  # its settings
		sf.add_animation(anim_name)  # create it
		sf.set_animation_loop(anim_name, true)  # loop
		sf.set_animation_speed(anim_name, info[2])  # frames per second
		for i in range(1, int(info[1]) + 1):  # frames numbered from 1
			var t: Texture2D = load("res://sprites/watcher/watcher_%s%d.png" % [info[0], i])  # load one frame
			sf.add_frame(anim_name, t)  # add it
	return sf  # done


func _physics_process(delta: float) -> void:  # runs every physics frame
	if Game.game_over or Game.escaped:  # the run ended
		velocity = Vector2.ZERO  # stop moving
		anim.play("idle")  # stand still
		return  # skip everything else
	var sees := _can_see_player()  # does it notice you right now
	if state == State.PATROL and sees:  # just spotted you
		state = State.CHASE  # start hunting
		_lose_timer = 0.0  # reset the give-up timer
		_repath_timer = 0.0  # calculate a path immediately
		Game.chasing = true  # tell the hud and music
		Game.play_music("chase")  # switch to chase music
		if not _had_chase_sound:  # first time this run
			Game.sfx("watcher_growl")
			Game.say("it saw me. run.", 2.0)
			_had_chase_sound = true  # do not repeat every time
	elif state == State.CHASE:  # already hunting
		if sees:  # still sees you
			_lose_timer = 0.0  # reset the timer
		else:  # lost sight
			_lose_timer += delta  # count up
			if _lose_timer > LOSE_TIME:  # gave up
				state = State.PATROL  # go back to patrolling
				path.clear()  # forget the route
				Game.chasing = false  # calm again
				Game.play_music("ambient")
				Game.say("i think i lost it. stay quiet.", 2.6)
	_repath_timer -= delta  # count down
	if _repath_timer <= 0.0:  # time to recalculate
		_repath_timer = 0.25  # four times a second
		_update_path()  # pick a new route
	_move_along_path()  # walk it
	_animate()  # pick the animation
	if global_position.distance_to(player.global_position) < CATCH_DISTANCE:  # touching the player
		level.player_caught()  # game over


func _can_see_player() -> bool:  # true if the watcher notices the player
	var d := global_position.distance_to(player.global_position)  # distance to the player
	var sight := 110.0 if Game.flashlight_on else 50.0  # flashlight makes you easier to spot
	if player.is_sprinting:  # running is loud
		sight += 70.0  # it can hear you from further
	if state == State.CHASE:  # already hunting
		sight += 40.0  # it is more alert
	if d > sight:  # too far away
		return false  # not noticed
	var space := get_world_2d().direct_space_state  # physics world
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)  # ray that only hits walls (layer 1)
	return space.intersect_ray(query).is_empty()  # true when nothing blocks the view


func _update_path() -> void:  # decides where to walk
	var my_tile: Vector2i = level.tile_of(global_position)  # tile we stand on
	if state == State.CHASE:  # hunting
		var target: Vector2i = level.tile_of(player.global_position)  # the player's tile
		path = level.astar.get_id_path(my_tile, target)  # route straight to the player
		return  # done
	if path.size() > 1:  # still walking somewhere
		return  # keep going
	var pick: Vector2i = my_tile  # where we will wander to
	if randf() < 0.35:  # sometimes drift towards the player
		var near: Array = level.open_tiles.filter(func(t: Vector2i): return Vector2(t).distance_to(Vector2(level.tile_of(player.global_position))) < 14.0)  # tiles close to the player
		if not near.is_empty():  # found some
			pick = near.pick_random()  # choose one
	else:  # otherwise wander anywhere
		pick = level.open_tiles.pick_random()  # random open tile
	path = level.astar.get_id_path(my_tile, pick)  # route there


func _move_along_path() -> void:  # steers towards the next tile on the path
	while path.size() > 0 and global_position.distance_to(level.tile_center(path[0])) < 3.0:  # reached the next tile
		path.pop_front()  # remove it from the list
	if path.is_empty():  # nowhere to go
		velocity = Vector2.ZERO  # stand still
	else:  # walk to the next tile centre
		var speed := CHASE_SPEED if state == State.CHASE else PATROL_SPEED  # pick a speed
		velocity = (level.tile_center(path[0]) - global_position).normalized() * speed  # move towards it
	move_and_slide()  # apply movement


func _animate() -> void:  # chooses idle, walk or chase animation
	if state == State.CHASE:  # hunting
		anim.play("chase")  # sprint animation
	elif velocity.length() > 1.0:  # moving slowly
		anim.play("walk")  # creeping animation
	else:  # standing
		anim.play("idle")  # breathing animation
	if absf(velocity.x) > 1.0:  # moving sideways
		anim.flip_h = velocity.x < 0.0  # face the direction it moves
