extends BaseButton
## Round button with a vector icon, an optional coin-cost badge and an optional
## fill meter (used for the bonus-word jar).

const UI := preload("res://scripts/ui/ui.gd")

var icon_kind: String = "bulb"
var bg_color: Color = Color.WHITE
var icon_color: Color = Color(0.15, 0.3, 0.6)
var cost: int = 0
var badge_text: String = ""
var fill: float = -1.0
var glow: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	UI.add_press_feedback(self)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	if glow > 0.0:
		draw_circle(c, r + 10.0 * glow, Color(1, 0.9, 0.4, 0.35 * glow))
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.18))
	draw_circle(c, r, bg_color)
	if icon_kind == "jar":
		_draw_jar(c, r)
	else:
		UI.draw_icon(self, icon_kind, c, r * 0.85, icon_color)
	if cost > 0:
		var bw := r * 1.7
		var bh := r * 0.62
		var rect := Rect2(Vector2(c.x - bw / 2.0, c.y + r - bh * 0.55), Vector2(bw, bh))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.15, 0.25, 0.9)
		sb.set_corner_radius_all(int(bh / 2.0))
		draw_style_box(sb, rect)
		UI.draw_coin(self, Vector2(rect.position.x + bh * 0.5, rect.get_center().y), bh * 0.36)
		UI.draw_text_centered(self, str(cost), rect.get_center() + Vector2(bh * 0.28, 0), int(bh * 0.72), Color.WHITE)
	if badge_text != "":
		var bw2 := r * 1.5
		var bh2 := r * 0.6
		var rect2 := Rect2(Vector2(c.x - bw2 / 2.0, c.y + r - bh2 * 0.55), Vector2(bw2, bh2))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.13, 0.15, 0.25, 0.9)
		sb2.set_corner_radius_all(int(bh2 / 2.0))
		draw_style_box(sb2, rect2)
		UI.draw_text_centered(self, badge_text, rect2.get_center(), int(bh2 * 0.72), Color.WHITE)


func _draw_jar(c: Vector2, r: float) -> void:
	var body := Rect2(c + Vector2(-r * 0.48, -r * 0.42), Vector2(r * 0.96, r * 0.98))
	var neck := Rect2(c + Vector2(-r * 0.32, -r * 0.62), Vector2(r * 0.64, r * 0.2))
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.8, 0.9, 1.0, 0.6)
	glass.set_corner_radius_all(int(r * 0.25))
	glass.border_color = icon_color
	glass.set_border_width_all(maxi(2, int(r * 0.08)))
	draw_style_box(glass, body)
	if fill > 0.0:
		var h := (body.size.y - r * 0.16) * clampf(fill, 0.0, 1.0)
		var fr := Rect2(Vector2(body.position.x + r * 0.08, body.end.y - r * 0.08 - h), Vector2(body.size.x - r * 0.16, h))
		var gold := StyleBoxFlat.new()
		gold.bg_color = UI.GOLD
		gold.set_corner_radius_all(int(r * 0.16))
		draw_style_box(gold, fr)
	draw_rect(neck, icon_color)
	UI.draw_star(self, body.get_center() + Vector2(0, r * 0.05), r * 0.26, Color(1, 1, 1, 0.9))
