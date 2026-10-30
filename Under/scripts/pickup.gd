class_name Pickup  # the key lying in a dead end
extends Area2D  # detects the player touching it

var sprite: Sprite2D  # the key picture


func _ready() -> void:  # runs when the key enters the scene
	collision_layer = 0  # nothing needs to hit the key
	collision_mask = 2  # it only looks for the player
	sprite = Sprite2D.new()  # create the picture
	sprite.texture = load("res://sprites/items/item_key.png")  # key image
	add_child(sprite)  # attach it
	var cs := CollisionShape2D.new()  # hitbox node
	var rect := RectangleShape2D.new()  # rectangle hitbox
	rect.size = Vector2(14, 14)  # almost a full tile
	cs.shape = rect  # assign it
	add_child(cs)  # attach it
	var glow := PointLight2D.new()  # little glow so you can spot it
	glow.texture = Player.make_light_texture()  # soft round light
	glow.color = Color(1.0, 0.9, 0.4)  # gold
	glow.energy = 0.6  # dim
	glow.texture_scale = 0.2  # small
	add_child(glow)  # attach it
	body_entered.connect(_on_body_entered)  # call us when touched


func _process(_delta: float) -> void:  # bobs the key up and down
	sprite.position.y = sin(Time.get_ticks_msec() / 250.0) * 1.5  # gentle float


func _on_body_entered(body: Node) -> void:  # something touched the key
	if body is Player:  # only the player can pick it up
		Game.has_key = true  # now carrying it
		Game.sfx("pickup")
		Game.say("a key. rusted, but it should still work.")
		Game.say("there has to be a locked door somewhere.", 2.6)
		queue_free()  # remove the key from the world
