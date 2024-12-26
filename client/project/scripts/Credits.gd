extends Node

@onready var slides_elem = $slides
@onready var anim = $anim

var credits_slide_scene = preload("res://graphics/credits/CreditSlide.tscn")
var credits_slide_section_scene = preload("res://graphics/credits/CreditSlideSection.tscn")
var credits_end_note_scene = preload("res://graphics/credits/CreditEndNote.tscn")

var topic_author = ''

func build_credits(obj: Dictionary):
	var slide_idx = 0
	for slide in obj.get('slides'):
		var slide_elem = credits_slide_scene.instantiate()
		slide_elem.name = str('slide', slide_idx)
		
		for slide_section in slide.get('sections'):
			var slide_section_elem = credits_slide_section_scene.instantiate()
			slide_section_elem.set_title(slide_section.get('title'))
			slide_section_elem.set_columns(slide_section.get('columns'))
			
			for slide_section_item in slide_section.get('items'):
				var item_name = slide_section_item.get('name')
				if item_name == '$topicAuthor': item_name = topic_author
					
				if item_name != "" and item_name != null:
					slide_section_elem.add_item(item_name, slide_section_item.get('style'))
			
			slide_elem.add_child(slide_section_elem)
		
		slide_elem.hide()
		slides_elem.add_child(slide_elem)
		slide_idx+=1
		
	var end_note_elem = credits_end_note_scene.instantiate()
	end_note_elem.set_text(obj.get('endNote'))
	end_note_elem.hide()
	slides_elem.add_child(end_note_elem)


func play_credits():
	var slides = $slides.get_children()
	for slide in slides:
		slide.modulate = Color.TRANSPARENT
		slide.show()
		await create_tween().tween_property(slide, 'modulate', Color.WHITE, 0.2).finished
		await wait(1.1)
		await create_tween().tween_property(slide, 'modulate', Color.TRANSPARENT, 0.2).finished
		slide.hide()
		
	anim.play("credits")
	await anim.animation_finished
	
func set_topic_author(author):
	topic_author = author
		
func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)
