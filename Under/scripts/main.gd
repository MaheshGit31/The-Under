extends Node2D  # the game level: builds the map from levels/level1.txt

const TILE := 16  # tile size in pixels
const LEVEL_FILE := "res://levels/level1.txt"  # which maze to load

var astar := AStarGrid2D.new()  # pathfinding grid for the watcher
var open_tiles: Array = []  # every walkable tile (Vector2i)
var player: Player  # the player
var watcher: Watcher  # the monster
var hud: Hud  # on-screen ui
var width := 0  # level width in tiles
var height := 0  # level height in tiles
var grid: Array = []  # rows of text characters
var exit_pos := Vector2.ZERO
var heart_timer := 0.0
var started := false


func _ready() -> void:  # runs when the level starts
	Game.reset()  # fresh state
	randomize()  # different random floors and wandering each run
	_load_grid()  # read the text file
	var mod := CanvasModulate.new()  # darkens the whole world
	mod.color = Color(0.06, 0.06, 0.1)  # almost black blue
	add_child(mod)  # attach it
	_setup_astar()  # prepare pathfinding
	_build_tiles()  # place floors and walls
	_spawn_things()  # place player, watcher, key, door, exit
	Game.play_music("ambient", true, -6.0)
	Game.say("...where am i.", 2.2)
	Game.say("keep moving. there has to be a way out.", 3.0)


func _load_grid() -> void:  # reads the level text into a 2d array
	var f := FileAccess.open(LEVEL_FILE, FileAccess.READ)  # open the file
	var lines := f.get_as_text().strip_edges().split("\n")  # one string per row
	for line in lines:  # go through each row
		grid.append(line.strip_edges())  # store it
	height = grid.size()  # number of rows
	width = grid[0].length()  # number of columns


func _setup_astar() -> void:  # builds the pathfinding grid
	astar.region = Rect2i(0, 0, width, height)  # size of the grid
	astar.cell_size = Vector2(TILE, TILE)  # tile size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # only up, down, left, right
	astar.update()  # apply settings
	for y in height:  # every row
		for x in width:  # every column
			if grid[y][x] == "#":  # a wall
				astar.set_point_solid(Vector2i(x, y), true)  # cannot walk here
			else:  # walkable
				open_tiles.append(Vector2i(x, y))  # remember it


func tile_of(pos: Vector2) -> Vector2i:  # world position to tile coordinate
	return Vector2i(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))  # divide and round down


func tile_center(t: Vector2i) -> Vector2:  # tile coordinate to world position of its centre
	return Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0)  # middle of the tile


func _is_wall(x: int, y: int) -> bool:  # true if a tile is a wall (outside counts as wall)
	if x < 0 or y < 0 or x >= width or y >= height:  # off the map
		return true  # treat as wall
	return grid[y][x] == "#"  # look it up


func _build_tiles() -> void:  # creates the floor and wall sprites
	var floors: Array = []  # the three floor textures
	for i in [1, 2, 3]:  # numbers 1 to 3
		floors.append(load("res://sprites/tiles/tile_floor_0%d.png" % i))  # load each
	var wall_front: Texture2D = load("res://sprites/tiles/tile_wall_front.png")  # wall with a visible face
	var wall_top: Texture2D = load("res://sprites/tiles/tile_wall_top.png")  # plain wall top
	var wall_cracked: Texture2D = load("res://sprites/tiles/tile_wall_cracked.png")  # rare cracked wall
	for y in height:  # every row
		for x in width:  # every column
			var pos := Vector2(x * TILE, y * TILE)  # top left corner of the tile
			if _is_wall(x, y):  # wall tile
				var tex := wall_top  # default look
				if not _is_wall(x, y + 1):  # floor below, so we see the front face
					tex = wall_cracked if randf() < 0.08 else wall_front  # sometimes cracked
				_make_wall(pos, tex)  # build it
			else:  # floor tile
				var s := Sprite2D.new()  # floor picture
				s.texture = floors[randi() % 3] if randf() < 0.25 else floors[0]  # mostly the plain one
				s.centered = false  # position from the corner
				s.position = pos  # place it
				add_child(s)  # attach it


func _make_wall(pos: Vector2, tex: Texture2D) -> void:  # one solid wall tile
	var body := StaticBody2D.new()  # solid object
	body.position = pos + Vector2(TILE / 2.0, TILE / 2.0)  # centre of the tile
	body.collision_layer = 1  # walls are layer 1
	body.collision_mask = 0  # walls do not collide with anything themselves
	var s := Sprite2D.new()  # wall picture
	s.texture = tex  # chosen image
	body.add_child(s)  # attach picture
	var cs := CollisionShape2D.new()  # hitbox
	var rect := RectangleShape2D.new()  # rectangle hitbox
	rect.size = Vector2(TILE, TILE)  # full tile
	cs.shape = rect  # assign it
	body.add_child(cs)  # attach hitbox
	var occ := LightOccluder2D.new()  # blocks light so shadows work
	var poly := OccluderPolygon2D.new()  # shape that blocks light
	var h := TILE / 2.0  # half a tile
	poly.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])  # square
	poly.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
	occ.occluder = poly
	body.add_child(occ)  # attach occluder
	add_child(body)  # add the wall to the level


func _spawn_things() -> void:  # places everything marked in the level file
	for y in height:  # every row
		for x in width:  # every column
			var t := Vector2i(x, y)  # this tile
			var c: String = grid[y][x]  # its character
			match c:  # decide what to spawn
				"P":  # player start
					player = Player.new()  # make the player
					player.position = tile_center(t)  # place it
				"W":  # watcher spawn
					watcher = Watcher.new()  # make the watcher
					watcher.position = tile_center(t)  # place it
				"K":  # key
					var k := Pickup.new()  # make the key
					k.position = tile_center(t)  # place it
					add_child(k)  # add to level
				"D":  # locked door
					var d := Door.new()  # make the door
					d.position = tile_center(t)  # place it
					add_child(d)  # add to level
				"E":  # exit
					_make_exit(t)  # build the exit
	add_child(player)  # add the player (after floors so it draws above)
	player.camera.limit_left = 0  # stop the camera at the map edges
	player.camera.limit_top = 0  # top edge
	player.camera.limit_right = width * TILE  # right edge
	player.camera.limit_bottom = height * TILE  # bottom edge
	watcher.level = self  # tell the watcher about the level
	watcher.player = player  # and who to hunt
	add_child(watcher)  # add the watcher
	hud = Hud.new()  # create the ui
	add_child(hud)  # add it


func _make_exit(t: Vector2i) -> void:  # builds the exit door and its trigger
	var area := Area2D.new()  # trigger zone
	area.position = tile_center(t)  # place it
	exit_pos = area.position
	area.collision_layer = 0  # nothing hits it
	area.collision_mask = 2  # looks for the player
	var s := Sprite2D.new()  # exit picture
	s.texture = load("res://sprites/doors/door_exit_closed.png")  # closed exit image
	s.offset = Vector2(0, -8)  # 16x32 image sits on its tile
	area.add_child(s)  # attach picture
	var cs := CollisionShape2D.new()  # hitbox
	var rect := RectangleShape2D.new()  # rectangle
	rect.size = Vector2(12, 12)  # a bit smaller than a tile
	cs.shape = rect  # assign it
	area.add_child(cs)  # attach hitbox
	var glow := PointLight2D.new()  # faint green glow so the exit feels like hope
	glow.texture = Player.make_light_texture()  # soft round light
	glow.color = Color(0.5, 1.0, 0.6)  # green
	glow.energy = 0.5  # dim
	glow.texture_scale = 0.3  # small
	area.add_child(glow)  # attach light
	area.body_entered.connect(func(body: Node):  # when something enters
		if body is Player and not Game.game_over:  # the player, still alive
			Game.escaped = true  # you win
			s.texture = load("res://sprites/doors/door_exit_open.png")  # open the exit
			Game.sfx("escape")
			Game.say("sunlight. i made it.", 3.0))
	add_child(area)  # add to level


func player_caught() -> void:  # called by the watcher when it grabs you
	if Game.game_over or Game.escaped:  # already ended
		return  # nothing to do
	Game.game_over = true  # you died
	Game.chasing = false  # stop the chase state
	Game.shake(7.0, 0.9)
	Game.stop_music()
	Game.sfx("jumpscare")


func _process(delta: float) -> void:
	if Game.game_over or Game.escaped:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		elif Input.is_action_just_pressed("menu"):
			Game.reset()
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	var d := watcher.global_position.distance_to(player.global_position)
	var target := clampf((d - 40.0) / 170.0, 0.0, 1.0) * 100.0
	if Game.chasing:
		target = minf(target, 35.0)
	var speed := 55.0 if target < Game.atmosphere else 14.0
	Game.atmosphere = move_toward(Game.atmosphere, target, speed * delta)
	if Game.atmosphere < 60.0:
		Game.say_once("close1", "something is close. i can feel it.", 2.8)
	if Game.atmosphere < 28.0:
		Game.say_once("close2", "it's right behind me.", 2.2)
	if player.global_position.distance_to(exit_pos) < 90.0:
		Game.say_once("exit_near", "light. that has to be the exit.", 2.8)
	if Game.atmosphere < 45.0:
		heart_timer -= delta
		if heart_timer <= 0.0:
			heart_timer = remap(Game.atmosphere, 0.0, 45.0, 0.45, 1.1)
			Game.sfx("heartbeat", remap(Game.atmosphere, 0.0, 45.0, 2.0, -8.0))
