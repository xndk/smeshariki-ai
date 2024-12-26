extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 12
const ROLL_VELOCITY = -50
const LANE_WIDTH = 2


# Get the gravity from the project settings to be synced with RigidBody nodes.
@export var gravity = 24

var lane = 0
var target_position = 0

func _ready():
	get_node("char/AnimationPlayer").play("Walk1")
	get_node("char/AnimationPlayer").get_animation("Walk1").loop_mode = Animation.LOOP_LINEAR

func _physics_process(delta):
	
	# Lanes movement
	lane = clamp(lane, -1, 1)
	target_position = -lane * LANE_WIDTH
	position.x += (target_position - position.x) * 10 * delta
	position.z += (0 - position.z) * 10 * delta
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle Roll
	if Input.is_action_just_pressed("ui_down"):
		if not is_on_floor():
			velocity.y = ROLL_VELOCITY
		roll()
		
	if Input.is_action_just_pressed("ui_left"):
		lane+=1
	if Input.is_action_just_pressed("ui_right"):
		lane-=1

	move_and_slide()

func roll():
	scale.y = 0.5
	await wait(0.5)
	scale.y = 1


func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
