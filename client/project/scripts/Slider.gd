extends Control

@export var interval_seconds: float = 5.0
@export var start_randomly: bool = true
@export var start_index: int = 0

@onready var items = get_children()
@onready var items_total = items.size()
@onready var current_index = randi_range(0, items_total-1) if start_randomly else start_index

func _ready():
	for item in range(items_total):
		hide_item(item, false)
	show_item(current_index, false)
	
	while true:
		await wait(interval_seconds)
		await hide_item(current_index, true)
		current_index += 1
		if current_index >= items_total:
			current_index = 0
		await show_item(current_index, true)

func show_item(idx: int, animation: bool):
	var item = items[idx]
	if not item: return
	
	item.show()
	if animation:
		item.modulate = Color.TRANSPARENT
		var tween = create_tween().tween_property(item, 'modulate', Color.WHITE, 0.25)
		await tween.finished
	else:
		item.modulate = Color.WHITE
		
func hide_item(idx: int, animation: bool):
	var item = items[idx]
	if not item: return
	
	if animation:
		item.modulate = Color.WHITE
		var tween = create_tween().tween_property(item, 'modulate', Color.TRANSPARENT, 0.25)
		await tween.finished
	item.hide()
	
func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
