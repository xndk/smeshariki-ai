extends CharacterBody3D

@export var meshBody: MeshInstance3D
@export var meshEyebrows: MeshInstance3D
@export var meshEyes: MeshInstance3D
@export var anim: AnimationPlayer
@export var billboard: Sprite3D

@export var propMicrophone: Node3D

@export var animateEyeExpressions: bool = false
@export var animateEyelidBlink: bool = false
@export var animateTalk: bool = false

@export var speed: float = 4

@export var anims_walk: Array[String] = ["Walk1"]
@export var anims_idle: Array[String] = ["Idle1"]
@export var anims_talk: Array[String] = []
@export var anims_sing_idle: Array[String] = ["sing/SingIdle1"]

@onready var mouthControlY = [meshBody, 'blend_shapes/Mouth Close']
@onready var mouthControlX = [meshBody, 'blend_shapes/Mouth Converge']
@onready var mouthControlMood = [meshBody, 'blend_shapes/Mood Sad']
@onready var eyebrowsControlAngry = [meshEyebrows, 'blend_shapes/Angry']
@onready var eyebrowsControlSad = [meshEyebrows, 'blend_shapes/Sad']
@onready var eyesControlBlink = [meshEyes, 'blend_shapes/Blink']
@onready var eyesControlAngry = [meshEyes, 'blend_shapes/Angry']
@onready var eyesControlSad = [meshEyes, 'blend_shapes/Sad']
@onready var eyelidsControlBlink = [meshEyebrows, 'blend_shapes/Blink']

@onready var director = %Director
@onready var vocals_audio_bus = AudioServer.get_bus_effect_instance(2, 0)

var moods = {
	# [
	#   mouth mood (0 - happy, 1 - sad), 
	#   eyebrows mood (-1 - sad, 0 - normal, 1 - angry)
	# ]
	'neutral': [0.4, 0],
	'happy': [0, 0],
	'sad': [0.65, -1],
	'angry': [1, 1],
	'nervous': [0, -1],
	'evil': [0, 1],
}
var mood_names = ['neutral', 'happy', 'sad', 'angry', 'nervous', 'evil']

var sing_animations = [
	preload("res://assets/animations/dance/SingIdle1.res"),
]
var sing_animation_names = [
	"SingIdle1",
]

var talking = false
var walking = false
var clearing_blocking = false
var is_mashup = false
var sing_anim_started = false
var sing_loudness = 0
var walking_range_x = Vector2(-7, 7)
var walking_range_z = Vector2(-7, 7)

@onready var target_rot = rotation.y
@onready var current_rot = rotation.y

var target_velocity = Vector3.ZERO
signal stopped_walking

@onready var target_pos = position
@onready var target_elevation = position.y

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	
	set_mood('neutral')
	if meshBody:
		tween_blend_shape(mouthControlY, 1, 0)
		tween_blend_shape(mouthControlX, 0, 0)
	
	if director:
		director.connect("turn_to_speaker", turn_to_speaker)
		director.connect("mode_specific_setup", mode_specific_setup)
		director.connect("song_event", song_event)
	
	_ready_thread2()
	_ready_thread3()
	
	if billboard:
		billboard.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		set_process(true)
	else:
		set_process(false)
		
	if propMicrophone: propMicrophone.hide()

func _ready_thread2():
	while true:
		await wait(randf_range(3, 10))
		await blink()
		
func _ready_thread3():
	anim.play(anims_idle.pick_random())
		
	while true:
		await wait(randf_range(5, 20))
		if not talking:
			await walk_to(Vector3(randf_range(walking_range_x.x, walking_range_x.y), position.y, randf_range(walking_range_z.x, walking_range_z.y)))
			
func mode_specific_setup(mode):
	if mode == 'mashup':
		is_mashup = true
		set_process(true)
		walking_range_z = Vector2(0, 6)
		
		if propMicrophone: propMicrophone.show()
		
		if billboard:
			billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		
		anim.speed_scale = 1.0 / 120 * director.episode_data.mashupData.bpm
		var anim_lib = AnimationLibrary.new()
		for i in range(len(sing_animations)):
			anim_lib.add_animation(sing_animation_names[i], sing_animations[i])
		anim.add_animation_library("sing", anim_lib)
		
		begin_singing()
	
func song_event(event):
	sing_anim_started = true
	anim.play(anims_sing_idle.pick_random())
	
	
func _process(_delta):
	if billboard:
		var camera_pos = get_viewport().get_camera_3d().global_transform.origin
		camera_pos.y = 0
		billboard.look_at(camera_pos, Vector3(0, 1, 0))
		billboard.rotate_y(deg_to_rad(180))
	if is_mashup:
		sing_loudness = clamp(vocals_audio_bus.get_magnitude_for_frequency_range(0, 10000).length() * 50, 0, 1)
		
func _physics_process(delta):
	current_rot += (target_rot - current_rot) * 8 * delta
	rotation.y = current_rot
	velocity += (target_velocity - velocity) * 10 * delta
	
	var should_stop_walking = move_and_slide()
	var arrived_at_target = position.distance_to(target_pos) < (speed * delta) or not walking or (should_stop_walking and randf() > 0.9)
	
	if arrived_at_target:
		target_velocity = Vector3.ZERO
		walking = false
		stopped_walking.emit()
	else:
		walking = true
		target_velocity = (target_pos - position).normalized() * speed
		turn_to(target_pos)
		
	if walking:
		if not anim.current_animation in anims_walk:
			anim.play(anims_walk.pick_random())
	elif talking and animateTalk:
		pass	
	else:
		if is_mashup:
			if sing_anim_started:
				if not anim.current_animation in anims_sing_idle: 
					anim.play("RESET")
					anim.play(anims_sing_idle.pick_random())
			else:
				if not anim.current_animation in anims_idle: 
					anim.play(anims_idle.pick_random())
				
			var cam_pos = get_viewport().get_camera_3d().global_position
			cam_pos.y = position.y
			turn_to(cam_pos)
		else:
			if not anim.current_animation in anims_idle:
				anim.play(anims_idle.pick_random())
		
	position.y = target_elevation
		
func attempt_clear_blocking(normal: Vector3):
	if clearing_blocking: return
	
	var slide_x = 2 if normal.x < 0 else -2

	var input_offset = Vector3(slide_x, 0, randf_range(-1, 1))
	var camera_spin = get_viewport().get_camera_3d().global_rotation.y
	var world_offset = input_offset.rotated(Vector3(0, 1, 0), camera_spin)
	var target_new_pos = position + world_offset
	target_new_pos.y = position.y
	
	clearing_blocking = true
	await walk_to(target_new_pos)
	clearing_blocking = false
		
func walk_to(to: Vector3):
	target_pos = to
	walking = true
	anim.play("Walk1")
	await stopped_walking


func begin_talking():
	talking = true
	if animateTalk:
		anim.play(anims_talk.pick_random())
	while talking:
		var t = randf_range(.05, .2)
		if meshBody:
			tween_blend_shape(mouthControlY, randf_range(0, 1), t)
			tween_blend_shape(mouthControlX, randf_range(0, 1), t)
		await wait(t)
		
func stop_talking():
	talking = false
	if meshBody:
		tween_blend_shape(mouthControlY, 1, 0.5)
		tween_blend_shape(mouthControlX, 0, 0.5)
		
func begin_singing():
	while true:
		var t = randf_range(.05, .2)
		if meshBody:
			var mouth_y_val = 1.0 - sing_loudness
			var mouth_x_val = randf_range(0, 1) * min(sing_loudness * 6, 1)
			
			tween_blend_shape(mouthControlY, mouth_y_val, t)
			tween_blend_shape(mouthControlX, mouth_x_val, t)
		await wait(t)
	
func set_mood(mood: String):
	var mood_data = moods.get(mood, moods.get('neutral'))
	var mouth_mood = mood_data[0]
	var eyebrows_angry = clamp(mood_data[1], 0, 1)
	var eyebrows_sad = clamp(-mood_data[1], 0, 1)
	if meshBody:
		tween_blend_shape(mouthControlMood, mouth_mood, 0.25)
	tween_blend_shape(eyebrowsControlAngry, eyebrows_angry, 0.25)
	tween_blend_shape(eyebrowsControlSad, eyebrows_sad, 0.25)
	if animateEyeExpressions:
		tween_blend_shape(eyesControlAngry, eyebrows_angry, 0.25)
		tween_blend_shape(eyesControlSad, eyebrows_sad, 0.25)
	
func blink():
	if animateEyelidBlink:
		await tween_blend_shape(eyelidsControlBlink, 1, 0.05)
		await tween_blend_shape(eyelidsControlBlink, 0, 0.25)
	else:
		await tween_blend_shape(eyesControlBlink, 1, 0.05)
		await tween_blend_shape(eyesControlBlink, 0, 0.25)


func tween_blend_shape(blend_shape: Array, val: float, time: float):
	var tween = create_tween().tween_property(blend_shape[0], blend_shape[1], val, time).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var finished = false
	tween.connect("finished", func (): finished = true)
	await tween.finished
	
func set_blend_shape(blend_shape: Array, val: float):
	blend_shape[0].set(blend_shape[1], val)
	
func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
	
func turn_to(target: Vector3):
	look_at(target)
	rotate_y(deg_to_rad(180))
	target_rot = rotation.y
	rotation.y = current_rot
	
func turn_to_speaker(node: Node3D):
	if node == self: return
	await wait(randf_range(0, 2))
	turn_to(node.position)
	walking = false
	stopped_walking.emit()
