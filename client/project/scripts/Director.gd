extends Node

@export var character_krosh: Node
@export var character_yozhik: Node
@export var character_losyash: Node
@export var character_nyusha: Node
@export var character_barash: Node
@export var character_kopatych: Node
@export var character_karych: Node
@export var character_sovunya: Node
@export var character_pin: Node
@export var character_bibi: Node
@export var character_narrator: Node
@export var enabled: bool = true

var character_scenes: Array[PackedScene] = [
	preload("res://characters/krosh.tscn"),
	preload("res://characters/yozhik.tscn"),
	preload("res://characters/losyash.tscn"),
	preload("res://characters/nyusha.tscn"),
	preload("res://characters/barash.tscn"),
	preload("res://characters/kopatych.tscn"),
	preload("res://characters/karych.tscn"),
	preload("res://characters/sovunya.tscn"),
	preload("res://characters/pin.tscn"),
	preload("res://characters/bibi.tscn"),
	preload("res://characters/dicktor.tscn"),
]

var sounds_bibi = [
	preload("res://assets/sounds/bibi1.mp3"),
	preload("res://assets/sounds/bibi2.mp3"),
	preload("res://assets/sounds/bibi3.mp3"),
	preload("res://assets/sounds/bibi4.wav"),
	preload("res://assets/sounds/bibi5.wav"),
	preload("res://assets/sounds/bibi6.wav"),
	preload("res://assets/sounds/bibi7.mp3"),
]

var environments: Array[String] = [
	'day',
	'evening',
	'night',
]

var environment_resources = {
	'day':     preload("res://assets/environments/worldEnvironmentDay.tres"),
	'evening': preload("res://assets/environments/worldEnvironmentEvening.tres"),
	'night':   preload("res://assets/environments/worldEnvironmentNight.tres"),
	'dance':   preload("res://assets/environments/worldEnvironmentDance.tres"),
}

var light_cone_scene = preload("res://gear/light_cone.tscn")
var dancer_scene = preload("res://gear/dancer.tscn")
var dancers = ["krosh", "yozhik", "losyash", "nyusha", "kopatych", "barash", "karych", "pin", "sovunya"]
var dancer_animations = [
	'gamgam1', 
	'gamgam2',
]

var voicelines = {}
var mashup_events = {}

@onready var global = get_node("/root/Global")
@onready var episode_data = global.next_episode_data
@onready var episode_id = global.next_episode_id
@onready var episode_mode = global.next_episode_data["type"]

@onready var current_environment = 'dance' if episode_mode == 'mashup' else environments.pick_random()
@onready var beats_timer: Timer = Timer.new()
@onready var initial_ambient_colors = [
	%sun.light_color, 
	get_environment_resource().ambient_light_color
]

var current_beat_idx = 0
var beat_idx_since_last_drop = 0
var mashup_is_drop = false

signal turn_to_speaker(node: Node3D)
signal set_environment
signal mode_specific_setup(mode: String)
signal song_beat(beat_idx: int)
signal song_event(event: Dictionary)
signal set_dancer_anim(anim_name: String)

func _ready():
	if not enabled: return
	
	# populate voice lines objects & trigger UI stuff
	setup_voice_lines(episode_data, episode_id)
	%UI.start_episode(episode_data)
	
	mode_specific_setup.emit(episode_mode)
	if %MashupEffects: %MashupEffects.visible = episode_mode == 'mashup'
	
	# initialize environment
	randomize()
	%WorldEnvironment.environment = environment_resources.get(current_environment)
	if episode_mode == 'mashup': 
		set_env_bg_hue(randf())
		%UI.mashup_mode()
		for character in episode_data.get('characters'):
			var character_data = get_character(character)
			if character_data:
				dancers.erase(character_data[1])
	set_environment.emit()
	
	# initialize characters on scene
	setup_characters()
	add_donation_characters()
	
	# request new episode from the global script
	global.make_new_episode()
	
	
	# main actions cycle
	
	if episode_mode == 'dialog':
		global.time_to_play_music = true
			
		var actions = episode_data.dialogData.actions
		var idx = 0
		
		var first_target_character = get_character(actions[0].get('character'))
		if (first_target_character): turn_to_speaker.emit(first_target_character[0])
		await wait(randf_range(1, 5))
		
		for action in actions:
			var next_action = actions[idx+1] if idx < actions.size() - 1 else {}
			
			match action.get('type'):
				'line':
					var target_character = get_character(action.get('character'))
					var target_character_name = ""
					if target_character:
						target_character_name = target_character[1]
						%UI.show_subtitle(action.get('content'), target_character_name)
						target_character = target_character[0]
						
						turn_to_speaker.emit(target_character)
						if action.get('emotion'):
							target_character.set_mood(action.get('emotion'))
						target_character.begin_talking()
					else:
						%UI.show_subtitle(action.get('character') + ': ' + action.get('content'))
					
					if target_character_name == 'bibi':
						await play_audio_res(sounds_bibi.pick_random())
					elif voicelines.get(action.get('id')):
						await play_audio(voicelines.get(action.get('id')))
					else:
						await wait(2)
					
					if target_character:
						target_character.stop_talking()
						
					var next_target_character = get_character(next_action.get('character'))
					if next_target_character: turn_to_speaker.emit(next_target_character[0])
					
				'narration':
					%UI.show_subtitle(action.get('content'))
					if voicelines.get(action.get('id')):
						await play_audio(voicelines.get(action.get('id')))
					else:
						await wait(2)
				
			await wait(randf_range(.4, 1))
					
			idx+= 1
		
	elif episode_mode == 'mashup':
		global.stop_music()
		spawn_dancers()
		
		var target_character = get_character(episode_data.characters[0])
		target_character[0].position.x = 0
		target_character[0].position.z = 5
		target_character[0].target_rot = deg_to_rad(180)
		turn_to_speaker.emit(target_character[0])
		start_vocals_track(4.5)
		await wait(5)
		start_beats_timer(episode_data.mashupData.bpm, episode_data.mashupData.beatOffset)
		play_audio(voicelines.get('__mashup_mix'), 'Mashup Mix')
		await wait(episode_data.mashupData.lengthSeconds)
		stop_beats_timer()
		remove_dancers()
		await %UI.fade_to_black()
		
		
	# clear stuff up, before ending	
	%UI.hide_subtitle()
	global.clear_voice_lines(episode_id)
	
	# roll credits & other end-related things
	await wait(randf_range(0.1, 2))
	await %UI.end_episode()
	if get_node("/root/Global").next_episode_fetched:
		await %UI.clapper_transition()
		global.load_random_world()
	else:	
		global.load_intro_scene()
		
func start_vocals_track(delay: float):
	await wait(delay)
	play_audio(voicelines.get('__mashup_vocals'), 'Mashup Vocals')
	
func add_donation_characters():
	if episode_data.get('donations') == null: return
	for donation in episode_data.get('donations'):
		if donation.get("currency") != "RUB": continue
		if donation.get("amount") < 19: continue
		
		# pick a random character
		var scene: PackedScene = character_scenes.pick_random()
		var character = scene.instantiate()
		
		# set name
		character.name = donation.get("id")
		if character.get_node("name") != null and donation.get("author") != null:
			character.get_node("name").text = donation.get("author")
			character.get_node("name").modulate = Color.from_hsv(randf(), 1, 1)
		
		add_child(character)
		
		# set coordinates
		character.position = Vector3(randf_range(-15, 15), 0.2, randf_range(-15, 15))
		character.target_pos = character.position
		var size = randf_range(0.2, 0.5)
		character.scale = Vector3(size, size, size)


func setup_voice_lines(episode_data: Dictionary, episode_id: String):
	match episode_mode:
		'dialog':
			# download dialog episode's voice lines
			var lines = episode_data.dialogData.voiceLines
			for line_id in lines:
				var line = lines[line_id]
				if not line.get('fetched'): continue
				var path = "user://voicelines/" + episode_id + "/" + line_id + ".wav"
				if line.get('type') == 'mp3':
					path = "user://voicelines/" + episode_id +"/" + line_id + ".mp3"
				if line.get('type') == 'ogg':
					path = "user://voicelines/" + episode_id +"/" + line_id + ".ogg"
				voicelines[line_id] = path
		'mashup':
			voicelines["__mashup_mix"] = "user://voicelines/" + episode_id + "/mix.mp3"
			voicelines["__mashup_vocals"] = "user://voicelines/" + episode_id + "/vocals.mp3"
			
			for event in episode_data.mashupData.events:
				if not mashup_events.has(str(event.time)):
					mashup_events[str(event.time)] = [event]
				else:
					mashup_events[str(event.time)].append(event)


func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
	
func start_beats_timer(bpm: float, beatOffset: float):
	await wait(beatOffset)
	_on_beat()
	
	if bpm == 0: return
	beats_timer.wait_time = 60/bpm
	add_child(beats_timer)
	beats_timer.start()
	beats_timer.connect("timeout", _on_beat)
	
func stop_beats_timer():
	remove_child(beats_timer)
	beats_timer.disconnect("timeout", _on_beat)
	
func _on_beat():
	song_beat.emit(current_beat_idx)
	
	var current_beat_idx_str = str(current_beat_idx)
	var current_events = mashup_events.get(current_beat_idx_str) if mashup_events.has(current_beat_idx_str) else []
	
	for event in current_events:
		match event.type:
			'dropStart':
				spawn_light_cones()
				# spawn_dancers()
				toggle_dancers(true)
				set_dancer_anim.emit(dancer_animations.pick_random())
				mashup_is_drop = true
				beat_idx_since_last_drop = 0
				%UI.flash(.5)
			'dropEnd':
				remove_light_cones()
				# remove_dancers()
				toggle_dancers(false)
				mashup_is_drop = false
				%UI.flash(.5)
			'setSinger':
				var target_character = get_character(event.content)
				turn_to_speaker.emit(target_character[0])
				
		song_event.emit(event)
	
	# Change secondary lighting color
	if mashup_is_drop:
		set_secondary_lighting_color(random_party_color())
		if beat_idx_since_last_drop % 2 == 0:
			%UI.do_zoom_blur()
	else:
		reset_secondary_lighting_color()
		
	# Flash every 4 bars since last drop
	if beat_idx_since_last_drop > 0 and beat_idx_since_last_drop % 16 == 0:
		if mashup_is_drop: 
			%UI.flash(.3)
		
	# Change dancer animation every 1 bar since last drop
	if beat_idx_since_last_drop > 0 and beat_idx_since_last_drop % 4 == 0:
		if mashup_is_drop: 
			set_dancer_anim.emit(dancer_animations.pick_random())
	
	current_beat_idx += 1
	beat_idx_since_last_drop += 1
	
func set_secondary_lighting_color(color: Color):
	if %sun: 
		%sun.light_color = color
	get_environment_resource().ambient_light_color.h = color.h

func reset_secondary_lighting_color():
	if %sun: %sun.light_color = initial_ambient_colors[0]
	get_environment_resource().ambient_light_color = initial_ambient_colors[1]
	
func set_env_bg_hue(hue: float):
	var SKY_HUE_SHIFT = 0.35
	get_environment_resource().sky.sky_material.set_shader_parameter('Shift_Hue', hue + SKY_HUE_SHIFT)
	get_environment_resource().fog_light_color.h = hue
	get_environment_resource().ambient_light_color.h = hue
	initial_ambient_colors[1] = get_environment_resource().ambient_light_color
	
func spawn_light_cones(n: int = 16):
	for i in range(n):
		var light_cone_instance = light_cone_scene.instantiate()
		light_cone_instance.name = str('spawned', i)
		light_cone_instance.rotate_on_beat = true
		light_cone_instance.position = Vector3(randf_range(-10, 10), randf_range(4, 6), randf_range(5, 15))
		%MashupEffects.add_child(light_cone_instance)
		
func remove_light_cones():
	for child in %MashupEffects.get_children():
		if child.name.begins_with('spawned') or child.name.begins_with('@'):
			child.queue_free()
			
func spawn_dancers():
	var dancer_idx = 0
	for dancer_name in dancers:
		dancer_idx += 1
		var marker: Marker3D = %MashupEffects.get_node(str('dancer', dancer_idx))
		if not marker: continue
		var dancer = dancer_scene.instantiate()
		dancer.name = str('spwdncr', dancer_idx)
		dancer.character = dancer_name
		dancer.bpm = episode_data.mashupData.bpm
		dancer.position = marker.position
		dancer.hide()
		%MashupEffects.add_child(dancer)
		
func remove_dancers():
	for child in %MashupEffects.get_children():
		if child.name.begins_with('spwdncr') or child.name.begins_with('@'):
			child.queue_free()
	
func toggle_dancers(visible: bool):
	for child in %MashupEffects.get_children():
		if child.name.begins_with('spwdncr') or child.name.begins_with('@'):
			child.visible = visible

func play_audio (path: String, track_id: String = "Master"):
	if not FileAccess.file_exists(path):
		return
	
	print("PLAYING", path)
	var audio = AudioStreamPlayer.new()
	add_child(audio)
	var loader = AudioLoader.new()
	audio.stream = loader.loadfile(path)
	audio.bus = track_id
	audio.play()
	await audio.finished
	remove_child(audio)
	
func play_audio_res (res: Resource):
	var audio = AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = res
	audio.play()
	await audio.finished
	remove_child(audio)
		
func setup_characters():
	if not episode_data.get('characters').has('крош'): character_krosh.queue_free()
	if not episode_data.get('characters').has('ёжик') and not episode_data.get('characters').has('ежик'): character_yozhik.queue_free()
	if not episode_data.get('characters').has('лосяш'): character_losyash.queue_free()
	if not episode_data.get('characters').has('нюша'): character_nyusha.queue_free()
	if not episode_data.get('characters').has('бараш'): character_barash.queue_free()
	if not episode_data.get('characters').has('копатыч'): character_kopatych.queue_free()
	if not episode_data.get('characters').has('кар-карыч'): character_karych.queue_free()
	if not episode_data.get('characters').has('совунья') and not episode_data.get('characters').has('совуня'): character_sovunya.queue_free()
	if not episode_data.get('characters').has('пин'): character_pin.queue_free()
	if not episode_data.get('characters').has('биби'): character_bibi.queue_free()
	if not episode_data.get('characters').has('диктор'): character_narrator.queue_free()
	
func get_character(str):
	if str == 'крош':
		return [character_krosh, 'krosh']
	elif str in ['ёжик', 'ежик']:
		return [character_yozhik, 'yozhik']
	elif str == 'лосяш':
		return [character_losyash, 'losyash']
	elif str == 'нюша':
		return [character_nyusha, 'nyusha']
	elif str == 'бараш':
		return [character_barash, 'barash']
	elif str == 'копатыч':
		return [character_kopatych, 'kopatych']
	elif str == 'кар-карыч':
		return [character_karych, 'karych']
	elif str in ['совунья', 'совуня']:
		return [character_sovunya, 'sovunya']
	elif str == 'пин':
		return [character_pin, 'pin']
	elif str == 'биби':
		return [character_bibi, 'bibi']
	elif str == 'диктор':
		return [character_narrator, 'narrator']
		
func get_environment_resource():
	return %WorldEnvironment.environment
	
var prev_h = randf()
func random_party_color():
	prev_h += randf_range(0.2, 0.6)
	if prev_h > 1: prev_h -= 1
	return Color.from_hsv(prev_h, 1, 1)
