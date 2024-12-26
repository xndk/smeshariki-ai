extends Node

var DEBUG_MODE = false
var flags = {
	'REFETCH_EPISODE': true,
	'MUSIC': true,
	'DONATIONS': true,
	'YOUTUBE': false,
	'DEVSERVER': false,
}

var server_url = {
	'dev': "http://localhost:1984",
	'production': "http://main.emberglaze.ru"
}
var music = [
	preload("res://assets/music/scientific.mp3"),
	preload("res://assets/music/adventurous.mp3"),
	preload("res://assets/music/sinister.mp3"),
	preload("res://assets/music/chase.mp3"),
]

var worlds = [
	"res://scenes/worlds/polyana.tscn",
	"res://scenes/worlds/beach.tscn",
	"res://scenes/worlds/forest.tscn",
]

var credits = {
	"slides": [],
	"endNote": ""
}

var next_episode_id: String = ""
var next_episode_data: Dictionary = {}
var fetching_episode_data: Dictionary = {}
var next_episode_fetched: bool = false
var first_time: bool = true
var time_to_download_audio: bool = false
var time_to_play_music: bool = false

signal episode_ready()

@onready var music_elem = AudioStreamPlayer.new()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/root.tscn")

func start_generation_loop():
	randomize()
	add_child(music_elem)
	music_elem.volume_db = -20
	if flags.MUSIC and not flags.YOUTUBE:
		_music_player()
	
	_get_credits()
	
	make_new_episode()
	
func _music_player():
	while true:
		if time_to_play_music:
			if randf() > 0.8:
				await play_music_track()
				await wait(randf_range(1, 5))
			else:
				await wait(randf_range(8, 32))
		else:
			await wait(1)
			
func _get_credits():
	var credits_data = await getr('/api/episodes/credits', 5)
	if is_request_success(credits_data):
		credits = JSON.parse_string(credits_data[1])
			
func load_random_world():
	get_tree().change_scene_to_file(worlds.pick_random())

func load_intro_scene():
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func make_new_episode():
	
	_get_credits()
		
	if DEBUG_MODE:
		#make_test_mashup_episode()
		make_test_dialog_episode()
		return
	
	next_episode_fetched = false
	time_to_download_audio = false

	next_episode_id = random_id()
	var episode_req_data

	if not first_time or not flags.get('REFETCH_EPISODE'):
		episode_req_data = await generate_new_episode()
	else:
		episode_req_data = await get_last_episode()
		
	var episode_test_data = JSON.parse_string(episode_req_data[1])
	if episode_test_data != null:
		next_episode_id = episode_test_data.get('id')
		
	var fetched = is_request_success(episode_req_data)

	while not fetched:
		episode_req_data = await generate_new_episode()
		fetched = is_request_success(episode_req_data)
			
	first_time = false

	var refetch_data = await refetch_episode(episode_req_data)
	
	if refetch_data is bool and refetch_data == false:
		return
	else:
		next_episode_data = refetch_data
		
	next_episode_id = next_episode_data.get('id')
		
	make_dirs(next_episode_id)
	await setup_voice_lines(next_episode_id, next_episode_data)

	next_episode_fetched = true
	episode_ready.emit()


func clear_voice_lines(episode_id: String):
	if DEBUG_MODE:
		return
		
	var dir = DirAccess.open("user://")
	
	if (dir.dir_exists("voicelines/" + episode_id)):
		var dir2 = DirAccess.open("user://voicelines/" + episode_id)
		for fp in dir2.get_files():
			dir2.remove(fp)
	var dir2 = DirAccess.open("user://voicelines")
	dir2.remove(episode_id)

func make_dirs(episode_id: String):
	var dir = DirAccess.open("user://")
	
	if not dir.dir_exists("voicelines"):
		dir.make_dir("voicelines")
	if not dir.dir_exists("voicelines/" + episode_id):
		dir.make_dir("voicelines/" + episode_id)

func generate_new_episode():
	var episode_req_data = await postr('/api/episodes/new', {}, 60)
	return episode_req_data
	
func get_last_episode():
	var episode_req_data = await getr('/api/episodes/last', 15)
	return episode_req_data
	
func remove_episode(id: String):
	await postr('/api/episodes/remove', { 'id': id }, 5)
	
func refetch_episode(episode_req_data: Array):
	# re-fetch the current episode until the assets are fully fetched
	var episode_data = JSON.parse_string(episode_req_data[1])
	while not episode_data.get('isReady') == true:
		print("Re-fetching")
		await wait(2)
		episode_req_data = await getr(str('/api/episodes/get/', next_episode_id), 5)
		
		if not is_request_success(episode_req_data):
			print("Error re-fetching episode!")
			make_new_episode()
			return false
			
		episode_data = JSON.parse_string(episode_req_data[1])
		fetching_episode_data = episode_data
	return episode_data
	
func setup_voice_lines(episode_id: String, episode_data: Dictionary, redownload: bool = true):
	if episode_data.type == 'dialog':
		# download episode's voice lines
		var voice_lines = episode_data.dialogData.voiceLines
		for line_id in voice_lines:
			var line = voice_lines[line_id]
			if not line.get('fetched'): continue
			var path = "user://voicelines/" + episode_id +"/" + line_id + ".wav"
			if line.get('type') == 'mp3':
				path = "user://voicelines/" + episode_id +"/" + line_id + ".mp3"
			if line.get('type') == 'ogg':
				path = "user://voicelines/" + episode_id +"/" + line_id + ".ogg"
			if redownload:
				print(str("Downloading ", line_id, "..."), " to ", path)
				if line.get('url') == null: continue
				download(line.get('url'), path)
	elif episode_data.type == 'mashup':
		# download mashup audio
		var server = server_url.dev if flags.DEVSERVER else server_url.production
		var mix_url = str(server, "/api/audio/get/", episode_data.mashupData.audio.mix.split('.')[0], "?type=mashup")
		var vocals_url = str(server, "/api/audio/get/", episode_data.mashupData.audio.vocals.split('.')[0], "?type=mashup")
		
		var mix_path = "user://voicelines/" + episode_id + "/mix.mp3"
		var vocals_path = "user://voicelines/" + episode_id + "/vocals.mp3"
		
		print("Downloading mix to ", mix_path)
		await download(mix_url, mix_path)
		print("Downloading vocals to ", vocals_path)
		await download(vocals_url, vocals_path)
		print("Mashup audio ready")
			
func clapper_transition():
	var sfx = AudioStreamPlayer.new()
	add_child(sfx)
	sfx.stream = preload("res://assets/sounds/clapper.wav")
	sfx.play()
	await sfx.finished
	remove_child(sfx)
	
func play_music_track():
	music_elem.stream = music.pick_random()
	music_elem.play()
	await music_elem.finished
	
func stop_music():
	music_elem.emit_signal('finished')
	music_elem.stop()
	time_to_play_music = false
	
	
func postr(endpoint: String, body: Dictionary = {}, timeout: float = 0):
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = timeout
	var url = server_url.dev if flags.DEVSERVER else server_url.production
	http.request(url + endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	var data = await http.request_completed
	remove_child(http)
	
	var code: int = data[1]
	var text = data[3].get_string_from_utf8()
	
	return [ code, text ]

func getr(endpoint: String, timeout: float = 0):
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = timeout
	var url = server_url.dev if flags.DEVSERVER else server_url.production
	http.request(url + endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
	var data = await http.request_completed
	remove_child(http)
	
	var code: int = data[1]
	var text = data[3].get_string_from_utf8()
	
	return [ code, text ]

func download(url: String, path: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.download_chunk_size = 131072
	http.set_download_file(path)
	http.request(url)
	await http.request_completed
	remove_child(http)
	return true

func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)

func random_id():
	randomize()
	var letters = "0123456789abcdef"
	var id = ""
	for i in range(0, 8):
		id += letters[randi() % letters.length()]
	return id
	
func is_request_success(req):
	return req[0] >= 200 and req[0] < 300


func make_test_dialog_episode():
	next_episode_id = "456fecc8-bdf2-43e4-a4fc-fac5d37f6d13"
	next_episode_data = {
		"type": "dialog",
		"topic": "Трейлер",
		"author": "Лосось",
		"isPaid": true,
		"characters": ["копатыч", "лосяш", "крош", "ёжик", "нюша", "бараш", "кар-карыч", "совунья", "пин", "биби"],
		"dialogData": {
			"actions": [
				{
					"type": "line",
					"id": "bibi0",
					"character": "биби",
					"emotion": "neutral",
					"content": "аааааоаоаоа"
				},
				{
					"type": "line",
					"id": "barash3",
					"character": "бараш",
					"emotion": "neutral",
					"content": "Эй, народ! Вы не поверите, что я только что сделал."
				},
				{
					"type": "line",
					"id": "nyusha2",
					"character": "нюша",
					"emotion": "neutral",
					"content": "Что случилось, Бараш?"
				},
				{
					"type": "line",
					"id": "barash6",
					"character": "бараш",
					"emotion": "neutral",
					"content": "Я угнал летающий трамвай, и он упал прямо на дом Кар-Карыча."
				},
				{
					"type": "line",
					"id": "bibi2",
					"character": "биби",
					"emotion": "angry",
					"content": "Заза"
				},
				{
					"type": "line",
					"id": "yozhik1",
					"character": "ёжик",
					"emotion": "happy",
					"content": "Как ты умудрился угнать летающий трамвай, Бараш?"
				},
				{
					"type": "line",
					"id": "nyusha1",
					"character": "нюша",
					"emotion": "happy",
					"content": "Бараш, ты же знаешь, что это воровство."
				},
				{
					"type": "line",
					"id": "barash1",
					"character": "бараш",
					"emotion": "neutral",
					"content": "Ну, я видел, что оставили ключи в замки, и подумал - почему бы и нет?"
				},
				{
					"type": "line",
					"id": "bibi1",
					"character": "биби",
					"emotion": "nervous",
					"content": "База"
				},
				{
					"type": "line",
					"id": "sovunya1",
					"character": "совунья",
					"emotion": "nervous",
					"content": "Но почему трамвай вообще летал?"
				},
				{
					"type": "line",
					"id": "krosh1",
					"character": "крош",
					"emotion": "neutral",
					"content": "Это был экспериментальный летающий трамвай, но похоже, он не особо хорошо справляется с полётами."
				},
				{
					"type": "line",
					"id": "pin1",
					"character": "пин",
					"emotion": "neutral",
					"content": "Ну видимо, ему понадобится ещё немного работы."
				},
				{
					"type": "line",
					"id": "barash4",
					"character": "бараш",
					"emotion": "nervous",
					"content": "Я понял это сейчас, когда трамвай упал на дом Кар-Карычаю"
				},
				{
					"type": "line",
					"id": "karych2",
					"character": "кар-карыч",
					"emotion": "neutral",
					"content": "Что это за шум и грохот? Бараш, это ты опять что-то натворил?"
				},
				{
					"type": "line",
					"id": "barash5",
					"character": "бараш",
					"emotion": "neutral",
					"content": "Да, Кар-Карыч, это моя вина. Я действительно угнал летающий трамвай и он упал на твой дом. Прости."
				},
				{
					"type": "line",
					"id": "karych1",
					"character": "кар-карыч",
					"emotion": "neutral",
					"content": "Ооох, а я только что сделал ремонт в доме. Ну ладно, главное что ты в порядке."
				},
				{
					"type": "line",
					"id": "losyash1",
					"character": "лосяш",
					"emotion": "nervous",
					"content": "Бараш, будь осторожнее в следующий раз, ты же можешь натворить ещё больше неприятностей."
				},
				{
					"type": "line",
					"id": "bibi3",
					"character": "биби",
					"emotion": "neutral",
					"content": "База заза заза база"
				},
				{
					"type": "line",
					"id": "barash2",
					"character": "бараш",
					"emotion": "neutral",
					"content": "Вы правы, друзья, извините за беспорядок. Я больше ни за что не стану угонять, обещаю."
				},
			],
			"rawText": "заза",
			"voiceLines": {
				"barash1": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/1459340f-3a47-4b1f-abd6-f1488660616c",
					"type": "wav"
				},
				"barash2": {
					"character": "крош",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/355268c0-ee39-4a6c-9998-68d91ce87a4f",
					"type": "wav"
				},
				"sovunya1": {
					"character": "ёжик",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/cc3ced80-3d9b-4848-92cc-e2b3ab84d7e3",
					"type": "wav"
				},
				"barash3": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/2b7df21a-c9f5-49dc-9ba5-4bec4af2faf6",
					"type": "wav"
				},
				"losyash1": {
					"character": "крош",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/349d4602-7618-4bbd-9609-981777606967",
					"type": "wav"
				},
				"yozhik1": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/0ce41ccc-e74b-4a25-bc54-7d05a5bb2ad2",
					"type": "wav"
				},
				"barash4": {
					"character": "ёжик",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/6142780d-6117-4547-b09c-c9c3ef50b5ee",
					"type": "wav"
				},
				"nyusha1": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/3c698079-7408-4059-b1a0-189704abec34",
					"type": "wav"
				},
				"pin1": {
					"character": "крош",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/9619fff4-76fd-48ad-8adb-3409d4072d0d",
					"type": "wav"
				},
				"barash5": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/ed8048aa-f045-414a-a9b9-35deed0db49e",
					"type": "wav"
				},
				"nyusha2": {
					"character": "ёжик",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/a18c2b46-b3ef-4c82-885c-c530c4290e66",
					"type": "wav"
				},
				"karych1": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/53a9c7ae-c7c1-443f-a899-0922f998ebde",
					"type": "wav"
				},
				"karych2": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/53a9c7ae-c7c1-443f-a899-0922f998ebde",
					"type": "wav"
				},
				"barash6": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/53a9c7ae-c7c1-443f-a899-0922f998ebde",
					"type": "wav"
				},
				"krosh1": {
					"character": "лосяш",
					"fetched": true,
					"url": "http://localhost:1984/voiceLine/53a9c7ae-c7c1-443f-a899-0922f998ebde",
					"type": "wav"
				},
			},
		},
		"isReady": true,
		"progress": 13,
		"progressMax": 13,
		"donations": []
	}

	fetching_episode_data = next_episode_data
	next_episode_fetched = true
	episode_ready.emit()

func make_test_mashup_episode():
	next_episode_id = "b05"
	next_episode_data = {
		"type": "mashup",
		"topic": "Пин вспомнил сороковые",
		"author": "Лосось",
		"isPaid": true,
		"characters": ["пин"],
		"mashupData": {
			"audio": {
				"mix": "fa13630e-6013-49d8-afba-e3164114e688.mp3",
				"vocals": "46b0205f-25f6-4c5c-9f1c-c2a23b10d9f9.mp3"
			},
			"bpm": 155.3,
			"beatOffset": 0,
			"lengthSeconds": 178.549854,
			"lengthBeats": 462.14653877000006,
			"events": [
				{
					"type": "dropStart",
					"time": 36
				},
				{
					"type": "dropEnd",
					"time": 46
				},
				{
					"type": "dropStart",
					"time": 55
				},
				{
					"type": "dropEnd",
					"time": 63
				},
				{
					"type": "dropStart",
					"time": 72
				},
				{
					"type": "dropEnd",
					"time": 116
				},
				{
					"type": "dropStart",
					"time": 125
				},
				{
					"type": "dropEnd",
					"time": 126
				},
				{
					"type": "dropStart",
					"time": 133
				},
				{
					"type": "dropEnd",
					"time": 150
				},
				{
					"type": "dropStart",
					"time": 158
				},
				{
					"type": "dropEnd",
					"time": 165
				},
				{
					"type": "dropStart",
					"time": 177
				},
				{
					"type": "dropEnd",
					"time": 185
				},
				{
					"type": "dropStart",
					"time": 194
				},
				{
					"type": "dropEnd",
					"time": 195
				},
				{
					"type": "dropStart",
					"time": 210
				},
				{
					"type": "dropEnd",
					"time": 214
				},
				{
					"type": "dropStart",
					"time": 229
				},
				{
					"type": "dropEnd",
					"time": 242
				},
				{
					"type": "dropStart",
					"time": 254
				},
				{
					"type": "dropEnd",
					"time": 261
				},
				{
					"type": "dropStart",
					"time": 272
				},
				{
					"type": "dropEnd",
					"time": 273
				},
				{
					"type": "dropStart",
					"time": 281
				},
				{
					"type": "dropEnd",
					"time": 284
				},
				{
					"type": "dropStart",
					"time": 297
				},
				{
					"type": "dropEnd",
					"time": 312
				},
				{
					"type": "dropStart",
					"time": 330
				},
				{
					"type": "dropEnd",
					"time": 331
				},
				{
					"type": "dropStart",
					"time": 346
				},
				{
					"type": "dropEnd",
					"time": 355
				},
				{
					"type": "dropStart",
					"time": 363
				},
				{
					"type": "dropEnd",
					"time": 367
				},
				{
					"type": "dropStart",
					"time": 377
				},
				{
					"type": "dropEnd",
					"time": 383
				},
				{
					"type": "dropStart",
					"time": 406
				},
				{
					"type": "dropEnd",
					"time": 417
				},
				{
					"type": "dropStart",
					"time": 424
				},
				{
					"type": "dropEnd",
					"time": 436
				},
				{
					"type": "dropStart",
					"time": 450
				},
				{
					"type": "dropEnd",
					"time": 455
				}
			]
		},
		"isReady": true,
		"progress": 1,
		"progressMax": 1,
		"donations": []
	}

	fetching_episode_data = next_episode_data
	next_episode_fetched = true
	episode_ready.emit()
	
