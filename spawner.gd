extends Node3D

@export var enemy_scene: PackedScene
@export var player_path: NodePath
@export var spawn_interval := 1.0
@export var spawn_radius := 15.0
@export var max_alive := 60

# Spawn safety tweaks
@export var min_player_gap := 2.0
@export var above_floor_offset := 0.2
@export var ray_top := 10.0
@export var ray_down := 100.0
@export var max_attempts := 8

var _timer: Timer
var _alive := 0
var _player: Node3D
var _last_spawn_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Find player (by path first, then by group)
	_player = get_node_or_null(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	# Defer timer start so everything is inside the tree
	call_deferred("_start_timer")

	randomize()
	print("Spawner ready, will spawn enemies every ", spawn_interval, "s.")
	if enemy_scene == null:
		push_warning("Spawner: No enemy_scene assigned in Inspector.")
	if _player == null:
		push_warning("Spawner: No player found (set player_path or add your Player to group 'player').")

func _start_timer() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = spawn_interval
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_timer.start()

func _on_timeout() -> void:
	if enemy_scene == null:
		return
	if _player == null or !is_instance_valid(_player) or !_player.is_inside_tree():
		return
	if _alive >= max_alive:
		return

	# Safe read of player position
	var player_origin: Vector3 = _player.global_transform.origin

	# Find valid spawn position near the player
	if !_find_spawn_pos(player_origin):
		# Fallback: spawn near player
		var angle := randf() * TAU
		_last_spawn_pos = player_origin + Vector3(cos(angle), 1.0, sin(angle)) * spawn_radius

	# Instantiate and add enemy
	var enemy := enemy_scene.instantiate()
	if enemy is Node3D:
		var parent := get_tree().current_scene
		if parent == null:
			parent = get_parent() if get_parent() != null else get_tree().root
		parent.add_child(enemy)

		# ✅ Set transform AFTER it's inside the tree
		enemy.global_position = _last_spawn_pos  # simpler and safer than global_transform.origin

		_alive += 1
		enemy.tree_exited.connect(func(): _alive = max(_alive - 1, 0))

# Try navmesh snap first (no collider needed), then physics ray, with retries.
func _find_spawn_pos(player_origin: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false

	var nav_map := world.navigation_map
	var space := world.direct_space_state

	for i in range(max_attempts):
		var angle := randf() * TAU
		var ring_pos := player_origin + Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
		if ring_pos.distance_to(player_origin) < min_player_gap:
			continue

		# 1) nearest navmesh point
		var nav_point := NavigationServer3D.map_get_closest_point(nav_map, ring_pos)
		if nav_point != Vector3.ZERO:
			_last_spawn_pos = nav_point + Vector3.UP * above_floor_offset
			return true

		# 2) raycast down (requires colliders)
		var from := ring_pos + Vector3.UP * ray_top
		var to := ring_pos + Vector3.DOWN * ray_down
		var params := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(params)
		if hit.has("position"):
			_last_spawn_pos = (hit["position"] as Vector3) + Vector3.UP * above_floor_offset
			return true

	return false
