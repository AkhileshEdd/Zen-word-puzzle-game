extends Control
## Procedurally painted landscape: gradient sky, sun or moon, stars, aurora,
## drifting clouds, layered mountains with trees, water and ambient particles.
## Every chapter gets its own seed, so no two chapters look exactly alike.

var zen_theme: Dictionary = {}
var seed_value: int = 0
var animated: bool = true

var _t: float = 0.0
var _redraw_acc: float = 0.0
var _layers: Array = []
var _trees: Array = []
var _clouds: Array = []
var _stars: Array = []
var _particles: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)


func setup(p_theme: Dictionary, p_seed: int, p_animated: bool = true) -> void:
	zen_theme = p_theme
	seed_value = p_seed
	animated = p_animated
	_rebuild()
	_setup_particles()


func _process(delta: float) -> void:
	if not animated or zen_theme.is_empty():
		return
	_t += delta
	for c in _clouds:
		c["x"] += c["speed"] * delta
		if c["x"] > size.x + 200.0:
			c["x"] = -200.0
	# ~30 fps is plenty for slow ambient motion.
	_redraw_acc += delta
	if _redraw_acc >= 1.0 / 30.0:
		_redraw_acc = 0.0
		queue_redraw()


func _rebuild() -> void:
	if zen_theme.is_empty() or size.x < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_layers.clear()
	_trees.clear()
	var w := size.x
	var h := size.y
	var bases := [0.56, 0.66, 0.76]
	var amps := [0.16, 0.10, 0.06]
	for k in 3:
		noise.seed = seed_value * 31 + k * 101
		noise.frequency = [0.0028, 0.0045, 0.006][k] * (720.0 / maxf(w, 1.0))
		var pts := PackedVector2Array()
		var steps := 72
		var ridge := PackedVector2Array()
		for i in steps + 1:
			var x := -20.0 + (w + 40.0) * i / steps
			var n := noise.get_noise_1d(x * (720.0 / maxf(w, 1.0)))
			var hgt: float
			if k == 0:
				hgt = 1.0 - absf(n) * 1.6  # sharp ridged peaks far away
			else:
				hgt = 0.5 + 0.5 * n
			var y: float = h * bases[k] - h * amps[k] * hgt
			pts.append(Vector2(x, y))
			ridge.append(Vector2(x, y))
		pts.append(Vector2(w + 20.0, h + 10.0))
		pts.append(Vector2(-20.0, h + 10.0))
		_layers.append({"poly": pts, "ridge": ridge})
	var tree_kind: String = _tree_kind()
	if tree_kind != "":
		for k in [1, 2]:
			var rr: PackedVector2Array = _layers[k]["ridge"]
			var count := 26 if k == 2 else 18
			for i in count:
				var x := rng.randf_range(0.0, w)
				var y := _ridge_y(rr, x) + rng.randf_range(2.0, 16.0)
				var s := rng.randf_range(0.7, 1.25) * (1.0 if k == 2 else 0.6)
				_trees.append({"x": x, "y": y, "s": s, "layer": k})
		_trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["layer"] < b["layer"] or (a["layer"] == b["layer"] and a["y"] < b["y"]))
	_clouds.clear()
	if not zen_theme.get("night", false):
		for i in 4:
			_clouds.append({
				"x": rng.randf_range(-100.0, w), "y": rng.randf_range(h * 0.05, h * 0.38),
				"s": rng.randf_range(0.7, 1.4), "speed": rng.randf_range(4.0, 12.0)})
	_stars.clear()
	if zen_theme.get("night", false):
		for i in 110:
			_stars.append({
				"p": Vector2(rng.randf_range(0, w), rng.randf_range(0, h * 0.6)),
				"r": rng.randf_range(0.8, 2.4), "ph": rng.randf_range(0, TAU), "sp": rng.randf_range(0.8, 2.5)})
	if _particles:
		_particles.position = Vector2(w / 2.0, h / 2.0)
		_particles.emission_rect_extents = Vector2(w / 2.0, h / 2.0)
	queue_redraw()


func _tree_kind() -> String:
	match zen_theme.get("id", ""):
		"dawn", "lake", "forest", "snow", "night", "aurora":
			return "pine"
		"sakura", "autumn":
			return "round"
	return ""


func _ridge_y(ridge: PackedVector2Array, x: float) -> float:
	for i in range(1, ridge.size()):
		if ridge[i].x >= x:
			var a := ridge[i - 1]
			var b := ridge[i]
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return ridge[ridge.size() - 1].y


func _draw() -> void:
	if zen_theme.is_empty():
		return
	var w := size.x
	var h := size.y
	var sky: Array = zen_theme["sky"]
	_vgradient(0.0, h * 0.45, sky[0], sky[1])
	_vgradient(h * 0.45, h, sky[1], sky[2])

	var night: bool = zen_theme.get("night", false)
	for s in _stars:
		var a := 0.55 + 0.45 * sin(_t * s["sp"] + s["ph"])
		draw_circle(s["p"], s["r"], Color(1, 1, 1, a))
	if zen_theme.get("id", "") == "aurora":
		_draw_aurora(w, h)

	# Sun / moon with a soft glow.
	var sp: Vector2 = zen_theme["sun_pos"]
	var sc := Vector2(sp.x * w, sp.y * h)
	var sun_col: Color = zen_theme["sun"]
	var r := w * (0.06 if night else 0.085)
	for i in 14:
		draw_circle(sc, r * (3.6 - i * 0.18), Color(sun_col, 0.025))
	draw_circle(sc, r, sun_col)
	if night:
		draw_circle(sc + Vector2(r * 0.3, -r * 0.2), r * 0.18, Color(0.85, 0.85, 0.75, 0.6))
		draw_circle(sc + Vector2(-r * 0.35, r * 0.25), r * 0.12, Color(0.85, 0.85, 0.75, 0.6))

	for c in _clouds:
		_draw_cloud(Vector2(c["x"], c["y"]), c["s"])

	var hills: Array = zen_theme["hills"]
	var tree_kind := _tree_kind()
	for k in _layers.size():
		var col: Color = hills[k]
		draw_colored_polygon(_layers[k]["poly"], col)
		if k == 0 and zen_theme.get("id", "") in ["snow", "lake", "aurora"]:
			_draw_snowcaps(_layers[0]["ridge"], h)
		for t in _trees:
			if t["layer"] == k:
				_draw_tree(tree_kind, Vector2(t["x"], t["y"]), t["s"], col.darkened(0.18 if k == 2 else 0.1))

	if zen_theme.get("water", false):
		var top := h * 0.8
		var ground: Color = zen_theme["ground"]
		_vgradient(top, h, ground.lightened(0.15), ground.darkened(0.2))
		for i in 7:
			var y := top + 14.0 + i * (h - top) / 7.0
			var off := sin(_t * 0.6 + i) * 30.0
			draw_line(Vector2(w * 0.2 + off, y), Vector2(w * 0.55 + off, y), Color(1, 1, 1, 0.12), 3.0)
	else:
		var band := PackedVector2Array()
		for i in 25:
			var x := -10.0 + (w + 20.0) * i / 24.0
			band.append(Vector2(x, h * 0.9 + sin(i * 0.7 + seed_value) * 8.0))
		band.append(Vector2(w + 10.0, h + 10.0))
		band.append(Vector2(-10.0, h + 10.0))
		draw_colored_polygon(band, zen_theme["ground"])


func _vgradient(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w := size.x
	draw_polygon(
		PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _draw_cloud(p: Vector2, s: float) -> void:
	var col := Color(1, 1, 1, 0.28)
	draw_circle(p, 34.0 * s, col)
	draw_circle(p + Vector2(38, 8) * s, 28.0 * s, col)
	draw_circle(p + Vector2(-36, 10) * s, 24.0 * s, col)
	draw_circle(p + Vector2(10, 18) * s, 30.0 * s, col)


func _draw_snowcaps(ridge: PackedVector2Array, h: float) -> void:
	var col := Color(1, 1, 1, 0.85)
	for i in range(1, ridge.size() - 1):
		var p := ridge[i]
		if p.y < ridge[i - 1].y and p.y < ridge[i + 1].y and p.y < h * 0.52:
			var d := 26.0
			draw_colored_polygon(PackedVector2Array([
				p, p + Vector2(d, d * 0.9), p + Vector2(d * 0.4, d * 0.7),
				p + Vector2(0, d * 1.0), p + Vector2(-d * 0.4, d * 0.7), p + Vector2(-d, d * 0.9)]), col)


func _draw_tree(kind: String, p: Vector2, s: float, col: Color) -> void:
	if kind == "pine":
		for i in 3:
			var wv := (16.0 - i * 4.0) * s
			var y := p.y - i * 12.0 * s
			draw_colored_polygon(PackedVector2Array([
				Vector2(p.x - wv, y), Vector2(p.x + wv, y), Vector2(p.x, y - 22.0 * s)]), col)
	elif kind == "round":
		var leaf: Color = zen_theme["tile"]
		leaf = leaf.lightened(0.25)
		draw_rect(Rect2(p.x - 2.0 * s, p.y - 16.0 * s, 4.0 * s, 16.0 * s), col.darkened(0.3))
		draw_circle(Vector2(p.x, p.y - 22.0 * s), 14.0 * s, leaf)
		draw_circle(Vector2(p.x - 9.0 * s, p.y - 16.0 * s), 9.0 * s, leaf.darkened(0.08))
		draw_circle(Vector2(p.x + 9.0 * s, p.y - 16.0 * s), 9.0 * s, leaf.darkened(0.05))


func _draw_aurora(w: float, h: float) -> void:
	var cols := [Color(0.3, 1.0, 0.7), Color(0.6, 0.4, 1.0)]
	for band in 2:
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		var colors := PackedColorArray()
		var steps := 30
		for i in steps + 1:
			var x := w * i / steps
			var y := h * (0.18 + band * 0.1) + sin(x * 0.008 + _t * 0.35 + band * 2.0) * 40.0 + sin(x * 0.02 + _t * 0.2) * 14.0
			top.append(Vector2(x, y - 90.0))
			bottom.append(Vector2(x, y))
		var poly := PackedVector2Array()
		for p in top:
			poly.append(p)
			colors.append(Color(cols[band], 0.0))
		for i in range(bottom.size() - 1, -1, -1):
			poly.append(bottom[i])
			colors.append(Color(cols[band], 0.28))
		draw_polygon(poly, colors)


func _setup_particles() -> void:
	if _particles:
		_particles.queue_free()
		_particles = null
	if not animated or zen_theme.is_empty():
		return
	var p := CPUParticles2D.new()
	p.texture = _soft_texture(zen_theme["particles"] in ["petals", "leaves"])
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = size / 2.0
	p.emission_rect_extents = size / 2.0
	var kind: String = zen_theme["particles"]
	match kind:
		"snow":
			p.amount = 60
			p.lifetime = 12.0
			p.direction = Vector2(0.2, 1)
			p.spread = 20.0
			p.gravity = Vector2(4, 12)
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 40.0
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.4
			p.color = Color(1, 1, 1, 0.8)
		"petals", "leaves":
			p.amount = 22
			p.lifetime = 14.0
			p.direction = Vector2(0.5, 1)
			p.spread = 30.0
			p.gravity = Vector2(6, 10)
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 35.0
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.angle_max = 360.0
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
			p.color = Color(1.0, 0.72, 0.82, 0.9) if kind == "petals" else Color(0.95, 0.55, 0.2, 0.9)
		"fireflies":
			p.amount = 26
			p.lifetime = 7.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 20.0
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.45
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
			g.set_color(1, Color(1.0, 0.95, 0.5, 0.0))
			g.add_point(0.3, Color(1.0, 0.95, 0.55, 0.9))
			g.add_point(0.7, Color(1.0, 0.9, 0.4, 0.7))
			p.color_ramp = g
		_:
			p.amount = 30
			p.lifetime = 10.0
			p.direction = Vector2(0, -1)
			p.spread = 40.0
			p.gravity = Vector2(0, -3)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.3
			var g2 := Gradient.new()
			g2.set_color(0, Color(1, 1, 1, 0.0))
			g2.set_color(1, Color(1, 1, 1, 0.0))
			g2.add_point(0.5, Color(1, 1, 1, 0.55))
			p.color_ramp = g2
	p.preprocess = p.lifetime
	add_child(p)
	_particles = p


## A soft round (or petal shaped) sprite generated at runtime.
static func _soft_texture(petal: bool) -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2((x - s / 2.0 + 0.5) / (s / 2.0), (y - s / 2.0 + 0.5) / (s / 2.0))
			if petal:
				d.x *= 1.8
			var a := clampf(1.0 - d.length(), 0.0, 1.0)
			a = a if petal else pow(a, 1.5)
			if petal:
				a = 1.0 if a > 0.05 else a * 20.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
