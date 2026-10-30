class_name Door  # the locked door that needs the key
extends StaticBody2D  # solid until unlocked

var sprite: Sprite2D  # what the door looks like
var body_shape: CollisionShape2D  # the solid part
var open := false  # true after unlocking


func _ready() -> void:  # runs when the door enters the scene
	collision_layer = 8  # layer 8 so only the player is blocked, the watcher walks through
	collision_mask = 0  # the door itself collides with nothing
	sprite = Sprite2D.new()  # create the picture
	sprite.texture = load("res://sprites/doors/door_locked.png")  # closed door image
	sprite.offset = Vector2(0, -8)  # 16x32 image sits on its tile with the top sticking up
	add_child(sprite)  # attach it
	body_shape = CollisionShape2D.new()  # hitbox node
	var rect := RectangleShape2D.new()  # rectangle hitbox
	rect.size = Vector2(16, 16)  # one full tile
	body_shape.shape = rect  # assign it
	add_child(body_shape)  # attach it
	var area := Area2D.new()  # trigger zone slightly bigger than the door
	area.collision_layer = 0  # it is not a thing others can hit
	area.collision_mask = 2  # it only looks for the player (layer 2)
	var az := CollisionShape2D.new()  # zone shape
	var ar := RectangleShape2D.new()  # rectangle zone
	ar.size = Vector2(24, 24)  # reaches a bit outside the door
	az.shape = ar  # assign it
	area.add_child(az)  # attach shape to zone
	add_child(area)  # attach zone to door
	area.body_entered.connect(_on_body_entered)  # call us when someone touches it


func _on_body_entered(body: Node) -> void:  # something stepped near the door
	if open or not body is Player:  # already open or not the player
		return  # ignore
	if Game.has_key:  # player carries the key
		open = true  # unlock
		sprite.texture = load("res://sprites/doors/door_open.png")  # swap to the open picture
		body_shape.set_deferred("disabled", true)  # let the player walk through
		Game.has_key = false
		Game.door_open = true
		Game.sfx("door_unlock")
		Game.say("it clicked. the way forward is open.")
	else:  # no key
		Game.sfx("door_locked")
		Game.say_once("locked_%d" % int(Time.get_ticks_msec() / 8000), "locked. i need a key.", 2.4)
