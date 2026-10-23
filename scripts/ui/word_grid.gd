extends Control
## The answer board: every target word gets a row of tiles. Words are sorted by
## length and laid out in as many columns as gives the biggest tiles.

signal tile_pressed(word_index: int, letter_index: int)

const Tile := preload("res://scripts/ui/tile.gd")
const MAX_TILE := 92.0

var words: Array = []
var color: Color = Color(0.12, 0.3, 0.6)
var empty_color: Color = Color(1, 1, 1, 0.55)
var pick_mode: bool = false:
	set(v):
		pick_mode = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		_update_pick_highlight()

var _tiles: Array = []  # Array[Array[Tile]]
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	resized.connect(_layout)


func setup(p_words: Array, p_color: Color, p_empty: Color = Color(1, 1, 1, 0.55)) -> void:
	words = p_words
	color = p_color
	empty_color = p_empty
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	for w in words:
		var row := []
		for ch in w:
			var t: Tile = Tile.new()
			add_child(t)
			t.setup(ch, color, empty_color)
			row.append(t)
		_tiles.append(row)
	_layout()


func _layout() -> void:
	var n := words.size()
	if n == 0 or size.x < 10.0:
		return
	var best_cols := 1
	var best_size := 0.0
	for cols in range(1, 5):
		var rows := ceili(float(n) / cols)
		if (cols - 1) * rows >= n:
			continue
		var width_units := 0.0
		for c in cols:
			width_units += _column_width(c, rows) * 1.12
		width_units += (cols - 1) * 0.5
		var s := minf(size.x / width_units, size.y / (rows * 1.12))
		s = minf(s, MAX_TILE)
		if s > best_size + 0.5:
			best_size = s
			best_cols = cols
	var rows_final := ceili(float(n) / best_cols)
	var s := best_size
	var step := s * 1.12
	var total_w := 0.0
	for c in best_cols:
		total_w += _column_width(c, rows_final) * step
	total_w += (best_cols - 1) * s * 0.5 - s * 0.12
	var total_h := rows_final * step - s * 0.12
	var x0 := (size.x - total_w) / 2.0
	var y0 := (size.y - total_h) / 2.0
	var x := x0
	for c in best_cols:
		for r in rows_final:
			var wi := c * rows_final + r
			if wi >= n:
				break
			var row: Array = _tiles[wi]
			for j in row.size():
				var t: Tile = row[j]
				t.size = Vector2(s, s)
				t.position = Vector2(x + j * step, y0 + r * step)
				t.pivot_offset = t.size / 2.0
		x += _column_width(c, rows_final) * step + s * 0.5


func _column_width(c: int, rows: int) -> int:
	var w := 0
	for r in rows:
		var wi := c * rows + r
		if wi < words.size():
			w = maxi(w, words[wi].length())
	return w


func tile(word_index: int, letter_index: int) -> Tile:
	return _tiles[word_index][letter_index]


func tile_global_center(word_index: int, letter_index: int) -> Vector2:
	var t: Tile = _tiles[word_index][letter_index]
	return t.get_global_transform() * (t.size / 2.0)


func tile_global_size() -> float:
	if _tiles.is_empty():
		return 60.0
	var t: Tile = _tiles[0][0]
	return t.size.x * get_global_transform().get_scale().x


func reveal_word(word_index: int, animate: bool = true, delay: float = 0.0) -> void:
	var row: Array = _tiles[word_index]
	for j in row.size():
		row[j].set_state(Tile.State.SOLVED, animate, delay + j * 0.06)


func reveal_letter(word_index: int, letter_index: int, animate: bool = true) -> void:
	var t: Tile = _tiles[word_index][letter_index]
	if t.state == Tile.State.EMPTY:
		t.set_state(Tile.State.HINT, animate)


func is_revealed(word_index: int, letter_index: int) -> bool:
	return _tiles[word_index][letter_index].state != Tile.State.EMPTY


func flash_word(word_index: int) -> void:
	var row: Array = _tiles[word_index]
	for j in row.size():
		row[j].bump(j * 0.04)


func celebrate() -> void:
	var k := 0
	for row in _tiles:
		for t in row:
			t.bump(k * 0.015)
			k += 1


func _update_pick_highlight() -> void:
	for row in _tiles:
		for t in row:
			t.highlight = 0.0
			t.queue_redraw()
	set_process(pick_mode)


func _process(delta: float) -> void:
	_t += delta
	var h := 0.5 + 0.5 * sin(_t * 6.0)
	for row in _tiles:
		for t in row:
			if t.state == Tile.State.EMPTY:
				t.highlight = h
				t.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not pick_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _tiles.size():
			for j in _tiles[i].size():
				var t: Tile = _tiles[i][j]
				if Rect2(t.position, t.size).grow(4.0).has_point(event.position) and t.state == Tile.State.EMPTY:
					tile_pressed.emit(i, j)
					accept_event()
					return
