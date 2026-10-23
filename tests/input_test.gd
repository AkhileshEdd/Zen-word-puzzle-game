extends Node
## Dev-only: drives the letter wheel with real mouse events (as touch is emulated).

func _ready() -> void:
	await get_tree().process_frame
	GameState.level = 6
	GameState.progress = {}
	GameState.pending_mode = "level"
	var g: Node = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(g)
	await get_tree().create_timer(1.0).timeout
	var word: String = g.words[0]
	var wheel: Control = g.wheel
	var letters: Array = wheel.letters()
	var used := {}
	var pts := []
	for ch in word:
		for i in letters.size():
			if letters[i] == ch and not used.has(i):
				used[i] = true
				pts.append(wheel.get_global_transform() * wheel._pos[i])
				break
	_mouse_button(pts[0], true)
	for p in pts:
		_mouse_move(p)
		await get_tree().process_frame
	_mouse_button(pts[pts.size() - 1], false)
	await get_tree().create_timer(0.5).timeout
	print("target ", word, " found: ", g.found.has(word))
	get_tree().quit()


func _mouse_button(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _mouse_move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
