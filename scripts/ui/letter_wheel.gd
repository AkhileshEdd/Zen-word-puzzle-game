extends Control
## The circular letter wheel. Drag across letters to spell a word; drag back
## onto the previous letter to undo it; release to submit.

signal word_changed(word: String)
signal word_submitted(word: String, points: Array)

const UI := preload("res://scripts/ui/ui.gd")

var color: Color = Color(0.12, 0.3, 0.6)
var enabled: bool = true

var _letters: Array = []
var _pos: Array = []        # current (animated) local position of each letter
var _slot_of: Array = []    # slot index on the circle for each letter
var _selected: Array = []
var _pop: Array = []
var _pointer: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _hint_path: Array = []  # tutorial: letter indexes to pulse
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_snap_positions)


func set_letters(letters: Array, p_color: Color) -> void:
	_letters = letters.duplicate()
	color = p_color
	_slot_of.clear()
	_pop.clear()
	for i in _letters.size():
		_slot_of.append(i)
		_pop.append(0.0)
	_selected.clear()
	_snap_positions()


func letters() -> Array:
	return _letters


func show_hint_path(word: String) -> void:
	_hint_path.clear()
	var used := {}
	for ch in word:
		for i in _letters.size():
			if _letters[i] == ch and not used.has(i):
				used[i] = true
				_hint_path.append(i)
				break
	queue_redraw()


func clear_hint_path() -> void:
	_hint_path.clear()
	queue_redraw()


func hint_path_points() -> Array:
	var pts := []
	for i in _hint_path:
		pts.append(global_position + _pos[i] * get_global_transform().get_scale())
	return pts


func _radius() -> float:
	return minf(size.x, size.y) / 2.0


func _letter_radius() -> float:
	var n := _letters.size()
	var k := 0.25 if n <= 4 else (0.22 if n <= 6 else 0.19)
	return _radius() * k


func _slot_position(slot: int) -> Vector2:
	var n := maxi(1, _letters.size())
	var a := -PI / 2.0 + TAU * slot / n
	var ring := _radius() - _letter_radius() * 1.25
	return size / 2.0 + Vector2(cos(a), sin(a)) * ring


func _snap_positions() -> void:
	_pos.clear()
	for i in _letters.size():
		_pos.append(_slot_position(_slot_of[i]))
	queue_redraw()


func shuffle() -> void:
	if _letters.size() < 2 or _dragging:
		return
	var old := _slot_of.duplicate()
	var tries := 0
	while tries < 10:
		_slot_of.shuffle()
		tries += 1
		if _slot_of != old:
			break
	for i in _letters.size():
		var from: Vector2 = _pos[i]
		var to := _slot_position(_slot_of[i])
		var idx := i
		var tw := create_tween()
		tw.tween_method(func(v: Vector2) -> void: _set_pos(idx, v), from, to, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _set_pos(i: int, v: Vector2) -> void:
	if i < _pos.size():
		_pos[i] = v
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var dirty := not _hint_path.is_empty()
	for i in _pop.size():
		if _pop[i] > 0.0:
			_pop[i] = maxf(0.0, _pop[i] - delta * 5.0)
			dirty = true
	if dirty:
		queue_redraw()


func _hit(p: Vector2, generous: bool) -> int:
	var lr := _letter_radius() * (1.25 if generous else 0.95)
	for i in _letters.size():
		if p.distance_to(_pos[i]) <= lr:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var i := _hit(event.position, true)
			if i >= 0:
				_dragging = true
				_selected = [i]
				_pointer = event.position
				_on_selected(i)
			accept_event()
		elif _dragging:
			_finish()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pointer = event.position
		var i := _hit(event.position, false)
		if i >= 0:
			if _selected.has(i):
				if _selected.size() >= 2 and _selected[_selected.size() - 2] == i:
					_selected.pop_back()
					Sfx.play_select(_selected.size() - 1)
					word_changed.emit(current_word())
			else:
				_selected.append(i)
				_on_selected(i)
		queue_redraw()
		accept_event()


func _on_selected(i: int) -> void:
	_pop[i] = 1.0
	Sfx.play_select(_selected.size() - 1)
	GameState.vibrate(8)
	word_changed.emit(current_word())
	queue_redraw()


func current_word() -> String:
	var w := ""
	for i in _selected:
		w += _letters[i]
	return w


func _finish() -> void:
	var word := current_word()
	var pts := []
	var xf := get_global_transform()
	for i in _selected:
		pts.append(xf * _pos[i])
	_dragging = false
	_selected.clear()
	queue_redraw()
	word_changed.emit("")
	word_submitted.emit(word, pts)


func cancel() -> void:
	_dragging = false
	_selected.clear()
	word_changed.emit("")
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := _radius()
	draw_circle(c, r, Color(1, 1, 1, 0.42))
	draw_arc(c, r - 2.0, 0, TAU, 96, Color(1, 1, 1, 0.75), 3.0, true)
	if _letters.is_empty():
		return
	var lr := _letter_radius()
	var lw := lr * 0.32
	# Connection lines.
	for k in range(1, _selected.size()):
		draw_line(_pos[_selected[k - 1]], _pos[_selected[k]], color, lw, true)
	if _dragging and not _selected.is_empty():
		draw_line(_pos[_selected[_selected.size() - 1]], _pointer, color, lw, true)
		draw_circle(_pointer, lw / 2.0, color)
	# Tutorial hint: pulsing rings on the letters of the first word.
	if not _hint_path.is_empty() and not _dragging:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		for k in _hint_path.size():
			draw_arc(_pos[_hint_path[k]], lr * (1.05 + 0.12 * pulse), 0, TAU, 48, Color(color, 0.5 + 0.4 * pulse), 4.0, true)
	var font_size := int(lr * 1.45)
	for i in _letters.size():
		var p: Vector2 = _pos[i]
		var sel := _selected.has(i)
		if sel:
			var rr: float = lr * (1.0 + 0.18 * _pop[i])
			draw_circle(p + Vector2(0, 3), rr, color.darkened(0.35))
			draw_circle(p, rr, color)
			UI.draw_text_centered(self, _letters[i], p, font_size, Color.WHITE)
		else:
			UI.draw_text_centered(self, _letters[i], p, font_size, UI.TEXT_DARK)
