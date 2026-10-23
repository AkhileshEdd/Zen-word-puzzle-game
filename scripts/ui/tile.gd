extends Control
## One letter cell of the answer grid.

const UI := preload("res://scripts/ui/ui.gd")

enum State { EMPTY, HINT, SOLVED }

var letter: String = ""
var state: State = State.EMPTY
var color: Color = Color(0.12, 0.3, 0.6)
var empty_color: Color = Color(1, 1, 1, 0.55)
var highlight: float = 0.0

var _empty_box: StyleBoxFlat
var _solved_box: StyleBoxFlat
var _shadow_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)


func setup(p_letter: String, p_color: Color, p_empty: Color = Color(1, 1, 1, 0.55)) -> void:
	letter = p_letter
	color = p_color
	empty_color = p_empty
	_make_boxes()
	queue_redraw()


func _on_resized() -> void:
	pivot_offset = size / 2.0
	_make_boxes()


func _make_boxes() -> void:
	var r := int(maxf(4.0, size.x * 0.2))
	_empty_box = StyleBoxFlat.new()
	_empty_box.bg_color = empty_color
	_empty_box.set_corner_radius_all(r)
	_empty_box.border_color = Color(color, 0.35)
	_empty_box.set_border_width_all(maxi(1, int(size.x * 0.03)))
	_solved_box = StyleBoxFlat.new()
	_solved_box.bg_color = color
	_solved_box.set_corner_radius_all(r)
	_solved_box.border_color = color.lightened(0.18)
	_solved_box.border_width_top = maxi(1, int(size.x * 0.04))
	_shadow_box = StyleBoxFlat.new()
	_shadow_box.bg_color = color.darkened(0.4)
	_shadow_box.set_corner_radius_all(r)


func set_state(s: State, animate: bool = false, delay: float = 0.0) -> void:
	if not animate:
		state = s
		queue_redraw()
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		state = s
		queue_redraw())
	tw.tween_property(self, "scale", Vector2(1.22, 1.22), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func bump(delay: float = 0.0) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _empty_box == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var fs := int(size.y * 0.66)
	match state:
		State.EMPTY:
			draw_style_box(_empty_box, rect)
		State.HINT:
			draw_style_box(_empty_box, rect)
			UI.draw_text_centered(self, letter, size / 2.0, fs, color)
		State.SOLVED:
			draw_style_box(_shadow_box, Rect2(Vector2(0, size.y * 0.06), size))
			draw_style_box(_solved_box, rect)
			UI.draw_text_centered(self, letter, size / 2.0, fs, Color.WHITE)
	if highlight > 0.0:
		draw_rect(rect.grow(-2.0), Color(1, 1, 1, 0.35 * highlight), false, 3.0)
