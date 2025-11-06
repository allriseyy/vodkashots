# Bullet.gd
extends Area3D

@export var speed: float = 40.0
@export var lifetime: float = 3.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	monitoring = true
	monitorable = true
	# Auto-despawn after lifetime
	get_tree().create_timer(lifetime).timeout.connect(func(): queue_free())
	# Hit detection (enemies are CharacterBody3D -> body_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_transform.origin += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("enemies"):
		body.queue_free()   # make enemy disappear
		queue_free()        # bullet disappears too
