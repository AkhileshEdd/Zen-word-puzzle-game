extends Control
## Home screen: play button, daily puzzle, daily login reward, chapter journey
## and settings.

const UI := preload("res://scripts/ui/ui.gd")
const Themes := preload("res://scripts/themes.gd")
const Background := preload("res://scripts/ui/background.gd")
const IconButton := preload("res://scripts/ui/icon_button.gd")
const Tile := preload("res://scripts/ui/tile.gd")

var zen_theme: Dictionary
var bg: Background
var coin_label: Label
var logo: Control
var popup_root: Control
var reward_btn: IconButton
var daily_btn: IconButton
var _t: float = 0.0
var _logo_tiles: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var chapter := GameState.chapter_of(GameState.level)
	zen_theme = Themes.for_chapter(chapter)
	bg = Background.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	bg.setup(zen_theme, chapter)
	_build(chapter)
	GameState.coins_changed.connect(func(c: int) -> void: coin_label.text = str(c))
	if GameState.can_claim_reward():
		await get_tree().create_timer(0.6).timeout
		_open_daily_reward()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if popup_root and is_instance_valid(popup_root):
			_close_popup()
		else:
			get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	for i in _logo_tiles.size():
		var t: Control = _logo_tiles[i]
		t.position.y = t.get_meta("base_y") + sin(_t * 1.6 + i * 0.6) * 6.0


func _build(chapter: int) -> void:
	var tile_color: Color = zen_theme["tile"]
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Top bar.
	var top := MarginContainer.new()
	var top_pad := 16
	if OS.has_feature("mobile"):
		top_pad += int(DisplayServer.get_display_safe_area().position.y * size.y / maxf(1.0, DisplayServer.screen_get_size().y))
	top.add_theme_constant_override("margin_top", top_pad)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	var gear := _round_button("gear", tile_color, Vector2(76, 76))
	gear.pressed.connect(_open_settings)
	top_row.add_child(gear)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var coin_pill := PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.12, 0.22, 0.55), 30, false))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2(40, 40)
	hb.add_child(coin)
	coin_label = UI.label(str(GameState.coins), 32, Color.WHITE, true)
	coin_label.custom_minimum_size = Vector2(80, 0)
	hb.add_child(coin_label)
	coin_pill.add_child(hb)
	var pill_center := CenterContainer.new()
	pill_center.add_child(coin_pill)
	top_row.add_child(pill_center)

	# Logo.
	var logo_space := Control.new()
	logo_space.custom_minimum_size = Vector2(0, 300)
	logo_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(logo_space)
	logo = Control.new()
	logo_space.add_child(logo)
	logo_space.resized.connect(func() -> void: _layout_logo(logo_space))
	for word in ["ZEN", "WORD"]:
		for ch in word:
			var t: Tile = Tile.new()
			logo.add_child(t)
			t.setup(ch, tile_color)
			t.state = Tile.State.SOLVED
			_logo_tiles.append(t)
	var tagline := UI.label("Relax  ·  Unwind  ·  Spell", 30, Color.WHITE, false, 5)
	tagline.name = "Tagline"
	logo.add_child(tagline)

	# Center panel with rank + chapter progress.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	root.add_child(info)
	info.add_child(UI.label("Rank: %s" % GameState.rank_name(), 34, Color.WHITE, true, 6))
	var pos := (GameState.level - 1) % GameState.chapter_size()
	info.add_child(UI.label("%s  ·  %d/%d" % [Themes.chapter_name(chapter), pos, GameState.chapter_size()], 28, Color(1, 1, 1, 0.95), false, 5))

	var play_space := CenterContainer.new()
	play_space.custom_minimum_size = Vector2(0, 170)
	root.add_child(play_space)
	var play := UI.button("Level %d" % GameState.level, Color(0.2, 0.72, 0.36), 50, Vector2(440, 124))
	play.pressed.connect(_play)
	play_space.add_child(play)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	# Feature buttons.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	root.add_child(row)
	daily_btn = _feature(row, "calendar", "Daily", tile_color, _play_daily)
	if GameState.daily_done():
		daily_btn.badge_text = "Done"
	elif GameState.daily_streak > 0 and GameState.daily_done_day == GameState.today() - 1:
		daily_btn.badge_text = "%d day" % GameState.daily_streak
	reward_btn = _feature(row, "gift", "Reward", tile_color, _open_daily_reward)
	if GameState.can_claim_reward():
		var g := create_tween().set_loops()
		g.tween_method(_set_reward_glow, 0.0, 1.0, 0.6)
		g.tween_method(_set_reward_glow, 1.0, 0.0, 0.6)
	_feature(row, "book", "Journey", tile_color, _open_chapters)

	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 70)
	root.add_child(bottom)


func _set_reward_glow(v: float) -> void:
	if GameState.can_claim_reward():
		reward_btn.glow = v
	else:
		reward_btn.glow = 0.0
	reward_btn.refresh()


func _layout_logo(space: Control) -> void:
	var s := minf(118.0, space.size.x / 5.0)
	var gap := s * 0.12
	var lines := [["Z", "E", "N"], ["W", "O", "R", "D"]]
	var k := 0
	var y := space.size.y / 2.0 - s - gap - 30.0
	for line in lines:
		var w: float = line.size() * s + (line.size() - 1) * gap
		var x := (space.size.x - w) / 2.0
		for j in line.size():
			var t: Control = _logo_tiles[k]
			t.size = Vector2(s, s)
			t.position = Vector2(x + j * (s + gap), y)
			t.set_meta("base_y", y)
			k += 1
		y += s + gap
	var tagline: Label = logo.get_node("Tagline")
	tagline.size = Vector2(space.size.x, 40)
	tagline.position = Vector2(0, y + 18)


func _round_button(kind: String, color: Color, sz: Vector2) -> IconButton:
	var b: IconButton = IconButton.new()
	b.icon_kind = kind
	b.icon_color = color
	b.bg_color = Color(1, 1, 1, 0.9)
	b.custom_minimum_size = sz
	return b


func _feature(row: HBoxContainer, kind: String, text: String, color: Color, cb: Callable) -> IconButton:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var b := _round_button(kind, color, Vector2(112, 112))
	b.pressed.connect(cb)
	col.add_child(b)
	col.add_child(UI.label(text, 28, Color.WHITE, true, 5))
	row.add_child(col)
	return b


func _play() -> void:
	GameState.pending_mode = "level"
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _play_daily() -> void:
	GameState.pending_mode = "daily"
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# --- popups -------------------------------------------------------------------

func _popup(title: String) -> VBoxContainer:
	_close_popup()
	popup_root = ColorRect.new()
	(popup_root as ColorRect).color = Color(0.02, 0.03, 0.1, 0.55)
	popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.add_child(center)
	var panel := PanelContainer.new()
	var sb := UI.box(Color(0.97, 0.97, 1.0), 36)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(minf(size.x - 50, 640), 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tl := UI.label(title, 44, zen_theme["tile"], true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := UI.button("X", Color(0.85, 0.3, 0.3), 30, Vector2(64, 64))
	close.pressed.connect(_close_popup)
	head.add_child(close)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0, CONNECT_ONE_SHOT)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	return vb


func _close_popup() -> void:
	if popup_root and is_instance_valid(popup_root):
		popup_root.queue_free()
	popup_root = null


func _open_daily_reward() -> void:
	var vb := _popup("Daily Reward")
	var claimable := GameState.can_claim_reward()
	var today_idx := GameState.reward_day_index()
	vb.add_child(UI.label("Come back every day for bigger rewards!", 26, UI.TEXT_DARK))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	vb.add_child(gc)
	var tile_color: Color = zen_theme["tile"]
	for i in GameState.DAILY_REWARDS.size():
		var cell := PanelContainer.new()
		var done := i < today_idx or (i == today_idx and not claimable)
		var is_today := i == today_idx and claimable
		var col := tile_color if is_today else (Color(0.75, 0.78, 0.85) if done else Color(0.9, 0.92, 0.96))
		cell.add_theme_stylebox_override("panel", UI.box(col, 20, is_today))
		cell.custom_minimum_size = Vector2(124, 140)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		var txt_col := Color.WHITE if is_today else UI.TEXT_DARK
		cv.add_child(UI.label("Day %d" % (i + 1), 24, txt_col, true))
		var ci := CoinIcon.new()
		ci.custom_minimum_size = Vector2(44, 44)
		cv.add_child(ci)
		cv.add_child(UI.label(("Done" if done else str(GameState.DAILY_REWARDS[i])), 28, txt_col, true))
		cell.add_child(cv)
		grid.add_child(cell)
	var btn_text := "Claim" if claimable else "Come back tomorrow"
	var btn := UI.button(btn_text, Color(0.2, 0.72, 0.36) if claimable else Color(0.6, 0.62, 0.7), 34, Vector2(380, 92))
	btn.disabled = not claimable
	var bc := CenterContainer.new()
	bc.add_child(btn)
	vb.add_child(bc)
	btn.pressed.connect(func() -> void:
		var amount := GameState.claim_reward()
		if amount > 0:
			Sfx.play("coin")
			Sfx.play("level_complete", 1.0, -6.0)
			_set_reward_glow(0.0)
		_close_popup())


func _open_chapters() -> void:
	var vb := _popup("Your Journey")
	var current := GameState.chapter_of(GameState.level)
	vb.add_child(UI.label("%d levels  ·  %d chapters" % [LevelDB.level_count(), ceili(float(LevelDB.level_count()) / GameState.chapter_size())], 24, UI.TEXT_DARK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(size.y * 0.62, 900))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	var shown := current + 6
	var current_card: Control = null
	for c in shown:
		var card := _chapter_card(c, current)
		list.add_child(card)
		if c == current:
			current_card = card
	if current_card:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(current_card) and is_instance_valid(scroll):
			scroll.scroll_vertical = int(maxf(0.0, current_card.position.y - 40))


func _chapter_card(c: int, current: int) -> Control:
	var cs := GameState.chapter_size()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(22)
	sb.bg_color = Color(0, 0, 0, 0)
	card.add_theme_stylebox_override("panel", sb)
	var preview := Background.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(preview)
	preview.setup(Themes.for_chapter(c), c, false)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.15 if c <= current else 0.55)
	card.add_child(shade)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	card.add_child(m)
	var row := HBoxContainer.new()
	m.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var name_l := UI.label(Themes.chapter_name(c), 36, Color.WHITE, true, 6)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(name_l)
	var range_l := UI.label("Levels %d - %d" % [c * cs + 1, (c + 1) * cs], 24, Color.WHITE, false, 4)
	range_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(range_l)
	var status := StatusIcon.new()
	status.custom_minimum_size = Vector2(70, 70)
	if c < current:
		status.kind = "check"
	elif c == current:
		status.kind = "progress"
		status.progress = float((GameState.level - 1) % cs) / cs
	else:
		status.kind = "lock"
	var sc := CenterContainer.new()
	sc.add_child(status)
	row.add_child(sc)
	return card


func _open_settings() -> void:
	var vb := _popup("Settings")
	for entry in [["Sound", "sound_on"], ["Music", "music_on"], ["Vibration", "haptics_on"]]:
		var row := HBoxContainer.new()
		var l := UI.label(entry[0], 34, UI.TEXT_DARK, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var key: String = entry[1]
		var on: bool = GameState.get(key)
		var b := UI.button("ON" if on else "OFF", Color(0.2, 0.72, 0.36) if on else Color(0.6, 0.62, 0.7), 28, Vector2(150, 70))
		b.pressed.connect(func() -> void:
			var v: bool = not GameState.get(key)
			GameState.set_setting(key, v)
			b.text = "ON" if v else "OFF"
			var col := Color(0.2, 0.72, 0.36) if v else Color(0.6, 0.62, 0.7)
			b.add_theme_stylebox_override("normal", UI.box(col, 35))
			b.add_theme_stylebox_override("hover", UI.box(col.lightened(0.08), 35)))
		row.add_child(b)
		vb.add_child(row)
	vb.add_child(HSeparator.new())
	var stats := [
		"Levels completed: %d" % (GameState.level - 1),
		"Words found: %d" % GameState.words_found,
		"Bonus words: %d" % GameState.bonus_total,
		"Hints used: %d" % GameState.hints_used,
	]
	for s in stats:
		var l2 := UI.label(s, 26, UI.TEXT_DARK)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vb.add_child(l2)
	vb.add_child(HSeparator.new())
	var reset := UI.button("Reset progress", Color(0.85, 0.3, 0.3), 26, Vector2(300, 70))
	var rc := CenterContainer.new()
	rc.add_child(reset)
	vb.add_child(rc)
	reset.pressed.connect(func() -> void:
		if reset.text == "Reset progress":
			reset.text = "Tap again to confirm"
		else:
			GameState.reset_progress()
			get_tree().reload_current_scene())
	var credits := UI.label("Font: Fredoka (SIL OFL). Words: SCOWL & ENABLE.", 20, Color(0.4, 0.42, 0.5))
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(credits)


class CoinIcon:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UI.draw_coin(self, size / 2.0, minf(size.x, size.y) / 2.0 * 0.9)


class StatusIcon:
	extends Control
	var kind: String = "lock"
	var progress: float = 0.0

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c, r, Color(1, 1, 1, 0.9))
		match kind:
			"check":
				UI.draw_icon(self, "check", c, r, Color(0.2, 0.7, 0.35))
			"lock":
				UI.draw_icon(self, "lock", c, r * 0.9, Color(0.45, 0.47, 0.55))
			_:
				draw_arc(c, r * 0.7, -PI / 2.0, -PI / 2.0 + TAU * maxf(progress, 0.02), 40, Color(0.2, 0.7, 0.35), r * 0.22, true)
				UI.draw_text_centered(self, "%d%%" % int(progress * 100), c, int(r * 0.5), UI.TEXT_DARK)
