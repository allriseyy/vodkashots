extends CharacterBody3D

@export var speed := 3.5
@export var acceleration := 20.0
@export var turn_speed := 10.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var player: Node3D
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float

func _ready() -> void:
	# start a bit above ground to avoid clipping
	global_transform.origin += Vector3.UP * 1.0

	# agent setup
	agent.path_desired_distance = 0.25
	agent.target_desired_distance = 0.25
	agent.avoidance_enabled = true
	# use the world's nav map (use method, not property assignment)
	agent.set_navigation_map(get_world_3d().navigation_map)

	# find the player by group
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player == null or !is_instance_valid(player):
		return

	# gravity
	if !is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# keep target fresh
	agent.target_position = player.global_transform.origin

	# desired horizontal velocity
	var desired_vel := Vector3.ZERO
	if !agent.is_navigation_finished():
		var next_point := agent.get_next_path_position()
		var dir := next_point - global_transform.origin
		dir.y = 0.0
		if dir.length() > 0.001:
			dir = dir.normalized()
			desired_vel = dir * speed

	# fallback: straight toward player if nav not ready/valid
	if desired_vel == Vector3.ZERO:
		var dir_fallback := player.global_transform.origin - global_transform.origin
		dir_fallback.y = 0.0
		if dir_fallback.length() > 0.001:
			dir_fallback = dir_fallback.normalized()
			desired_vel = dir_fallback * speed

	# smooth acceleration on XZ
	var curr_h := Vector3(velocity.x, 0.0, velocity.z)
	var new_h := curr_h.lerp(desired_vel, clamp(acceleration * delta / max(0.0001, speed), 0.0, 1.0))
	velocity.x = new_h.x
	velocity.z = new_h.z

	move_and_slide()

	# yaw toward player smoothly
	var look_pos := player.global_transform.origin
	look_pos.y = global_transform.origin.y
	var target_basis := (Transform3D(Basis(), global_transform.origin).looking_at(look_pos, Vector3.UP)).basis
	global_transform.basis = global_transform.basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
