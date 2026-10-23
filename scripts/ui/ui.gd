extends RefCounted
## Shared UI helpers: fonts, styled buttons/panels, vector icons and small tweens.

const FONT_SEMIBOLD := "res://assets/fonts/Fredoka-SemiBold.ttf"
const FONT_BOLD := "res://assets/fonts/Fredoka-Bold.ttf"
const TEXT_DARK := Color(0.16, 0.18, 0.28)
const GOLD := Color(1.0, 0.78, 0.22)

static var _fonts: Dictionary = {}


static func font(bold: bool = false) -> Font:
	var path := FONT_BOLD if bold else FONT_SEMIBOLD
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


static func box(color: Color, radius: int = 24, shadow: bool = true, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.22)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
	if border > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 32, color: Color = Color.WHITE, bold: bool = false, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, color: Color, font_size: int = 36, min_size: Vector2 = Vector2(280, 88), text_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.5))
	var radius := int(min_size.y / 2)
	b.add_theme_stylebox_override("normal", box(color, radius))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.08), radius))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.12), radius))
	b.add_theme_stylebox_override("hover_pressed", box(color.darkened(0.12), radius))
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.3), radius, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_press_feedback(b)
	return b


## Little squash on press + click sound, used by every button in the game.
static func add_press_feedback(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)
	if c is BaseButton:
		var b: BaseButton = c
		b.button_down.connect(func() -> void: c.create_tween().tween_property(c, "scale", Vector2(0.94, 0.94), 0.06))
		b.button_up.connect(func() -> void: c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		b.pressed.connect(func() -> void: Sfx.click())


static func pop_in(c: Control, delay: float = 0.0) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)


## Draw text centred on a point inside a CanvasItem._draw().
static func draw_text_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color: Color, bold: bool = true) -> void:
	var f := font(bold)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0
	ci.draw_string(f, Vector2(center.x - w / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0.75, 0.45, 0.05))
	ci.draw_circle(c, r, Color(1.0, 0.76, 0.18))
	ci.draw_circle(c, r * 0.72, Color(1.0, 0.86, 0.35))
	ci.draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.9, 0.6, 0.1), maxf(1.5, r * 0.1), true)
	draw_star(ci, c, r * 0.42, Color(0.92, 0.6, 0.1))


static func draw_star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)


## Simple vector icons so the game needs no image assets.
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(2.0, r * 0.16)
	match kind:
		"shuffle":
			for s in [-1.0, 1.0]:
				var start := PI * (0.15 if s > 0 else 1.15)
				ci.draw_arc(c, r * 0.62, start, start + PI * 0.75, 20, color, w, true)
				var a := start + PI * 0.75
				var tip := c + Vector2(cos(a), sin(a)) * r * 0.62
				var tangent := Vector2(-sin(a), cos(a))
				var normal := Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(PackedVector2Array([
					tip + tangent * r * 0.32,
					tip + normal * r * 0.24 - tangent * r * 0.05,
					tip - normal * r * 0.24 - tangent * r * 0.05]), color)
		"bulb":
			ci.draw_circle(c + Vector2(0, -r * 0.18), r * 0.45, color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.22, r * 0.18), Vector2(r * 0.44, r * 0.3)), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, r * 0.52), Vector2(r * 0.36, r * 0.1)), color)
			ci.draw_circle(c + Vector2(-r * 0.15, -r * 0.3), r * 0.11, Color(1, 1, 1, 0.75))
		"target":
			ci.draw_arc(c, r * 0.55, 0, TAU, 32, color, w, true)
			ci.draw_circle(c, r * 0.2, color)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * r * 0.4, c + d * r * 0.78, color, w, true)
		"bolt":
			var pts := PackedVector2Array([
				c + Vector2(0.12, -0.75) * r, c + Vector2(-0.42, 0.1) * r, c + Vector2(-0.04, 0.1) * r,
				c + Vector2(-0.16, 0.75) * r, c + Vector2(0.42, -0.12) * r, c + Vector2(0.04, -0.12) * r])
			ci.draw_colored_polygon(pts, color)
		"back":
			ci.draw_line(c + Vector2(r * 0.45, 0), c + Vector2(-r * 0.4, 0), color, w * 1.2, true)
			ci.draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.05, -r * 0.4), color, w * 1.2, true)
			ci.draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.05, r * 0.4), color, w * 1.2, true)
		"gear":
			for i in 8:
				var a := i * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.35, c + Vector2(cos(a), sin(a)) * r * 0.7, color, r * 0.26)
			ci.draw_circle(c, r * 0.5, color)
			ci.draw_arc(c, r * 0.18, 0, TAU, 16, Color(1, 1, 1, 0.9), r * 0.12, true)
		"calendar":
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.45), Vector2(r * 1.2, r * 1.05)), color)
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.45), Vector2(r * 1.2, r * 0.3)), color.darkened(0.25))
			for x in [-0.3, 0.3]:
				ci.draw_line(c + Vector2(x * r, -r * 0.65), c + Vector2(x * r, -r * 0.35), color.darkened(0.25), w)
		"book":
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.5), Vector2(r * 0.56, r)), color)
			ci.draw_rect(Rect2(c - Vector2(-r * 0.04, r * 0.5), Vector2(r * 0.56, r)), color)
		"gift":
			ci.draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.2), Vector2(r * 1.2, r * 0.8)), color)
			ci.draw_rect(Rect2(c - Vector2(r * 0.7, r * 0.42), Vector2(r * 1.4, r * 0.3)), color.lightened(0.15))
			ci.draw_rect(Rect2(c - Vector2(r * 0.1, r * 0.42), Vector2(r * 0.2, r * 1.02)), Color(0.9, 0.2, 0.25))
			ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.55), r * 0.17, Color(0.9, 0.2, 0.25))
			ci.draw_circle(c + Vector2(r * 0.2, -r * 0.55), r * 0.17, Color(0.9, 0.2, 0.25))
		"star":
			draw_star(ci, c, r * 0.7, color)
		"flame":
			ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.45, color)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.45, r * 0.15), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.45, r * 0.15)]), color)
			ci.draw_circle(c + Vector2(0, r * 0.32), r * 0.22, Color(1, 0.9, 0.5))
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.12, 0.35) * r, c + Vector2(0.5, -0.35) * r]), color, w * 1.4, true)
		"lock":
			var sw := r * 0.11
			var top := c + Vector2(0, -r * 0.22)
			ci.draw_arc(top, r * 0.26, PI, TAU, 20, color, sw, true)
			ci.draw_line(top + Vector2(-r * 0.26, 0), top + Vector2(-r * 0.26, r * 0.22), color, sw, true)
			ci.draw_line(top + Vector2(r * 0.26, 0), top + Vector2(r * 0.26, r * 0.22), color, sw, true)
			var body := StyleBoxFlat.new()
			body.bg_color = color
			body.set_corner_radius_all(int(r * 0.1))
			ci.draw_style_box(body, Rect2(c + Vector2(-r * 0.42, -r * 0.02), Vector2(r * 0.84, r * 0.62)))
			ci.draw_circle(c + Vector2(0, r * 0.22), r * 0.08, Color(1, 1, 1, 0.9))
		_:
			ci.draw_circle(c, r * 0.4, color)
