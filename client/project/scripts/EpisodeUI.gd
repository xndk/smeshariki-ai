extends Control

var character_colors = {
	'krosh': Color.CYAN,
	'yozhik': Color.DEEP_PINK,
	'losyash': Color.GOLD,
	'nyusha': Color.PINK,
	'kopatych': Color.CORAL,
	'karych': Color.ROYAL_BLUE,
	'sovunya': Color.MEDIUM_PURPLE,
	'barash': Color.PLUM,
	'pin': Color.BLACK,
}

@onready var global = get_node("/root/Global")
var target_zoom_blur = 0.0
var current_zoom_blur = 0.0

func _ready():
	set_process(false)

func show_subtitle(text: String, character: String = ''):
	if character == 'bibi':
		%subtitle.text = ""
		return
		
	%subtitle.text = text
	var color = character_colors.get(character, Color.WHITE)
	%subtitle.label_settings.outline_color = Color.WHITE  if color == Color.BLACK else  Color.BLACK
	%subtitle.label_settings.font_color = character_colors.get(character, Color.WHITE)
	
func mashup_mode():
	%Vignette.modulate.a = 0.5
	%zoomblur.show()
	%InfoboxSlider.hide()
	%theme.hide()
	set_process(true)
	
	%mashupTitlecard.modulate = Color.TRANSPARENT
	%mashupTitlecard.show()
	
	await wait(1)
	await create_tween().tween_property(%mashupTitlecard, 'modulate', Color.WHITE, 0.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)\
		.finished
	await wait(2)
	create_tween().tween_property(%mashupTitlecard, 'modulate', Color.TRANSPARENT, 2)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	
func _process(delta):
	current_zoom_blur = target_zoom_blur
	target_zoom_blur -= target_zoom_blur * 5 * delta
	%zoomblur.material.set_shader_parameter('blur_power', current_zoom_blur * 0.001)
	
func hide_subtitle():
	%subtitle.text = ""
	
func start_episode(episode_data):
	%theme.text = "Тема: " + episode_data.topic.text
	if episode_data.topic.priority:
		%theme.modulate = Color.YELLOW
	
	%credits.set_topic_author(episode_data.topic.get('author'))
	%credits.build_credits(global.credits)
	
	%mashupName.text = episode_data.topic.text
	var singersText = ""
	for singer in episode_data.get("characters"):
		singersText += str(singer.to_pascal_case(), ", ")
	singersText = singersText.substr(0, len(singersText) - 2)
	%mashupSingers.text = singersText
	
	if not global.flags.DONATIONS:
		%slideDonations.queue_free()
	
	%clapper.set_topic(episode_data.topic.text)
	%clapper.set_progress(1, 1)
	%clapper.end()
	
func end_episode():
	%theme.hide()
	await %credits.play_credits()
		
func clapper_transition():
	var next_episode_data = get_node("/root/Global").next_episode_data
	%clapper.set_topic(next_episode_data.topic.text)
	%clapper.set_progress(next_episode_data.get("progress"), next_episode_data.get("progressMax"))
	%clapper.start()
	await wait(1)
	
func flash(intensity: float = .5):
	var tween = create_tween()
	target_zoom_blur = intensity * 50
	tween.tween_property(%flash, 'color', Color(1, 1, 1, intensity), 0.1)
	tween.tween_property(%flash, 'color', Color(1, 1, 1, 0), 0.6)
	
func do_zoom_blur():
	target_zoom_blur = 5
	
func fade_to_black(duration: float = 5.0):
	%black.modulate = Color.TRANSPARENT
	%black.show()
	await create_tween().tween_property(%black, 'modulate', Color.WHITE, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)\
		.finished

func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
