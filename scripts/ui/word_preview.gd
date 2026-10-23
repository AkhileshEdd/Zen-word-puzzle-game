extends Control
## The pill above the wheel that shows the word being traced.

const UI := preload("res://scripts/ui/ui.gd")

var color: Color = Color(0.12, 0.3, 0.6)
var word: String = ""
var shake: float = 0.0:
	set(v):
		shake = v
		queue_redraw()
var _shake_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func set_word(w: String) -> void:
	if w != "" and _shake_tween:
		_shake_tween.kill()
		modulate = Color.WHITE
		scale = Vector2.ONE
		shake = 0.0
	word = w
	queue_redraw()


## Keep showing the word briefly, wiggle it and fade (wrong / repeated word).
func reject(w: String, tint: Color) -> void:
	word = w
	modulate = tint
	queue_redraw()
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i in 4:
		_shake_tween.tween_property(self, "shake", 14.0 if i % 2 == 0 else -14.0, 0.05)
	_shake_tween.tween_property(self, "shake", 0.0, 0.05)
	_shake_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_shake_tween.tween_callback(func() -> void:
		word = ""
		modulate = Color.WHITE
		queue_redraw())


## Flash the accepted word before it flies away.
func accept(w: String) -> void:
	word = w
	queue_redraw()
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	_shake_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	_shake_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_shake_tween.tween_callback(func() -> void:
		word = ""
		modulate = Color.WHITE
		queue_redraw())


func _draw() -> void:
	if word == "":
		return
	var fs := int(size.y * 0.62)
	var f := UI.font(true)
	var tw := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.2 * word.length()
	var w := tw + size.y * 0.9
	var rect := Rect2(Vector2((size.x - w) / 2.0 + shake, 0), Vector2(w, size.y))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size.y * 0.3))
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, rect)
	# Letter-spaced text.
	var x := rect.position.x + size.y * 0.45
	for ch in word:
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UI.draw_text_centered(self, ch, Vector2(x + cw / 2.0, size.y / 2.0), fs, Color.WHITE)
		x += cw + fs * 0.2
