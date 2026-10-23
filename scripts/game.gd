extends Control
## Main puzzle screen: answer grid on top, letter wheel at the bottom, hint
## buttons around the wheel, plus all feedback (flying letters, combos, bonus
## jar, coins) and the level-complete screen.

const UI := preload("res://scripts/ui/ui.gd")
const Themes := preload("res://scripts/themes.gd")
const Background := preload("res://scripts/ui/background.gd")
const LetterWheel := preload("res://scripts/ui/letter_wheel.gd")
const WordGrid := preload("res://scripts/ui/word_grid.gd")
const WordPreview := preload("res://scripts/ui/word_preview.gd")
const IconButton := preload("res://scripts/ui/icon_button.gd")
const Tile := preload("res://scripts/ui/tile.gd")

const COMBO_PRAISE := ["Good!", "Great!", "Excellent!", "Amazing!", "Awesome!", "Unbelievable!", "Legendary!"]
const DONE_PRAISE := ["Splendid!", "Marvelous!", "Brilliant!", "Excellent!", "Fantastic!",
	"Superb!", "Wonderful!", "Outstanding!", "Magnificent!", "Impressive!", "Genius!", "Sublime!"]
const COMBO_WINDOW := 6.0

var mode: String = "level"
var level_num: int = 1
var day: int = 0
var level: Dictionary = {}
var words: Array = []
var found: Dictionary = {}
var bonus_found: Dictionary = {}
var revealed: Dictionary = {}
var zen_theme: Dictionary = {}
var tile_color: Color
var combo: int = 0
var last_word_time: float = -100.0
var busy: bool = false
var hinted: bool = false
var progress_key: String = ""

var bg: Background
var grid: WordGrid
var wheel: LetterWheel
var preview: WordPreview
var fx: Control
var overlay_layer: Control
var title_label: Label
var subtitle_label: Label
var coin_label: Label
var coin_pill: PanelContainer
var back_btn: IconButton
var shuffle_btn: IconButton
var jar_btn: IconButton
var hint_btn: IconButton
var spot_btn: IconButton
var burst_btn: IconButton
var toast_panel: PanelContainer
var toast_label: Label
var finger: Control

var _toast_tween: Tween
var _shown_coins: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mode = GameState.pending_mode
	_build_ui()
	_load_level()
	resized.connect(_layout)
	GameState.coins_changed.connect(_on_coins_changed)
	_layout()
	_intro_animation()
	_maybe_show_tips()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()


# --- construction -------------------------------------------------------------

func _build_ui() -> void:
	bg = Background.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	grid = WordGrid.new()
	add_child(grid)
	grid.tile_pressed.connect(_on_tile_picked)

	preview = WordPreview.new()
	add_child(preview)

	wheel = LetterWheel.new()
	add_child(wheel)
	wheel.word_changed.connect(_on_word_changed)
	wheel.word_submitted.connect(_on_word_submitted)

	back_btn = _icon_button("back", Color(1, 1, 1, 0.85))
	back_btn.pressed.connect(_go_home)

	title_label = UI.label("Level 1", 42, Color.WHITE, true, 6)
	add_child(title_label)
	subtitle_label = UI.label("", 24, Color(1, 1, 1, 0.92), false, 4)
	add_child(subtitle_label)

	coin_pill = PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.12, 0.22, 0.55), 30, false))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var coin_icon := CoinIcon.new()
	coin_icon.custom_minimum_size = Vector2(40, 40)
	hb.add_child(coin_icon)
	coin_label = UI.label(str(GameState.coins), 32, Color.WHITE, true)
	coin_label.custom_minimum_size = Vector2(80, 0)
	hb.add_child(coin_label)
	coin_pill.add_child(hb)
	coin_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_pill)
	_shown_coins = GameState.coins

	shuffle_btn = _icon_button("shuffle", Color(1, 1, 1, 0.92))
	shuffle_btn.pressed.connect(_on_shuffle)
	jar_btn = _icon_button("jar", Color(1, 1, 1, 0.92))
	jar_btn.pressed.connect(_on_jar_pressed)
	hint_btn = _icon_button("bulb", Color(1, 1, 1, 0.92))
	hint_btn.cost = GameState.HINT_COST
	hint_btn.pressed.connect(_on_hint)
	spot_btn = _icon_button("target", Color(1, 1, 1, 0.92))
	spot_btn.cost = GameState.SPOTLIGHT_COST
	spot_btn.pressed.connect(_on_spotlight)
	burst_btn = _icon_button("bolt", Color(1, 1, 1, 0.92))
	burst_btn.cost = GameState.BURST_COST
	burst_btn.pressed.connect(_on_burst)

	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.12, 0.22, 0.82), 26, false))
	toast_label = UI.label("", 28, Color.WHITE)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	add_child(toast_panel)

	fx = Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)


func _icon_button(kind: String, color: Color) -> IconButton:
	var b: IconButton = IconButton.new()
	b.icon_kind = kind
	b.bg_color = color
	add_child(b)
	return b


func _load_level() -> void:
	var chapter := 0
	if mode == "daily":
		day = GameState.today()
		level = LevelDB.get_daily(day)
		zen_theme = Themes.get_theme(day)
		progress_key = "D%d" % day
		var date := Time.get_date_dict_from_system()
		title_label.text = "Daily Puzzle"
		subtitle_label.text = "%s %d" % [_month_name(date["month"]), date["day"]]
		bg.setup(zen_theme, day)
	else:
		level_num = GameState.level
		level = LevelDB.get_level(level_num)
		chapter = GameState.chapter_of(level_num)
		zen_theme = Themes.for_chapter(chapter)
		progress_key = "L%d" % level_num
		title_label.text = "Level %d" % level_num
		var pos := (level_num - 1) % GameState.chapter_size() + 1
		subtitle_label.text = "%s  ·  %d/%d" % [Themes.chapter_name(chapter), pos, GameState.chapter_size()]
		bg.setup(zen_theme, chapter)
	tile_color = zen_theme["tile"]
	words = level["words"]
	grid.setup(words, tile_color, zen_theme.get("empty", Color(1, 1, 1, 0.55)))
	preview.color = tile_color
	for b in [hint_btn, spot_btn, burst_btn, shuffle_btn, jar_btn, back_btn]:
		b.icon_color = tile_color
		b.refresh()

	# Scramble the letters deterministically so a level always looks the same.
	var letters: Array = []
	for ch in String(level["base"]):
		letters.append(ch)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(progress_key)
	for attempt in 12:
		for i in range(letters.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: String = letters[i]
			letters[i] = letters[j]
			letters[j] = tmp
		if not words.has("".join(letters)):
			break
	wheel.set_letters(letters, tile_color)

	# Restore an in-progress level.
	var p := GameState.progress_for(progress_key)
	hinted = bool(p.get("hinted", false))
	for w in p.get("found", []):
		var wi := words.find(w)
		if wi >= 0:
			found[w] = true
			grid.reveal_word(wi, false)
	for key in p.get("revealed", []):
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() == 2:
			var wi := int(parts[0])
			var li := int(parts[1])
			if wi < words.size() and li < String(words[wi]).length():
				revealed[key] = true
				grid.reveal_letter(wi, li, false)
	for w in p.get("bonus", []):
		bonus_found[w] = true
	_update_jar()


func _month_name(m: int) -> String:
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][clampi(m - 1, 0, 11)]


func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return Vector2.ZERO
	var k := size.y / float(screen.y)
	return Vector2(safe.position.y * k, (screen.y - safe.end.y) * k)


func _layout() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var insets := _safe_insets()
	var top := insets.x + 12.0
	var bottom := insets.y

	back_btn.size = Vector2(76, 76)
	back_btn.position = Vector2(16, top + 4)
	title_label.size = Vector2(w - 400, 52)
	title_label.position = Vector2(200, top)
	subtitle_label.size = Vector2(w - 300, 32)
	subtitle_label.position = Vector2(150, top + 50)
	coin_pill.reset_size()
	coin_pill.position = Vector2(w - coin_pill.size.x - 16, top + 10)

	var r := minf(minf(w * 0.34, h * 0.165), 300.0)
	var wc := Vector2(w / 2.0, h - bottom - r - maxf(36.0, h * 0.035))
	wheel.size = Vector2(r * 2.0, r * 2.0)
	wheel.position = wc - Vector2(r, r)

	var ph := 72.0
	preview.size = Vector2(w, ph)
	preview.position = Vector2(0, wc.y - r - ph - 22.0)

	var grid_top := top + 104.0
	var grid_bottom := preview.position.y - 14.0
	grid.position = Vector2(20, grid_top)
	grid.size = Vector2(w - 40, maxf(100.0, grid_bottom - grid_top))

	var bs := 96.0
	var lx := maxf(bs / 2.0 + 10.0, wc.x - r - bs * 0.42)
	var rx := minf(w - bs / 2.0 - 10.0, wc.x + r + bs * 0.42)
	_place(shuffle_btn, Vector2(lx, wc.y - r * 0.55), bs)
	_place(jar_btn, Vector2(lx, wc.y + r * 0.6), bs)
	_place(hint_btn, Vector2(rx, wc.y - r * 0.72), bs)
	_place(spot_btn, Vector2(rx, wc.y + r * 0.02), bs)
	_place(burst_btn, Vector2(rx, wc.y + r * 0.76), bs)

	toast_label.custom_minimum_size = Vector2(minf(w - 80, 560) - 36, 0)
	toast_label.reset_size()
	toast_panel.reset_size()
	toast_panel.position = Vector2((w - toast_panel.size.x) / 2.0, preview.position.y - toast_panel.size.y - 8.0)


func _place(c: Control, center: Vector2, s: float) -> void:
	c.size = Vector2(s, s)
	c.position = center - c.size / 2.0


func _intro_animation() -> void:
	var k := 0
	for wi in words.size():
		for li in String(words[wi]).length():
			var t: Control = grid.tile(wi, li)
			t.scale = Vector2.ZERO
			var tw := t.create_tween()
			tw.tween_interval(0.1 + k * 0.012)
			tw.tween_property(t, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			k += 1
	wheel.scale = Vector2(0.8, 0.8)
	wheel.modulate.a = 0.0
	wheel.pivot_offset = wheel.size / 2.0
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(wheel, "scale", Vector2.ONE, 0.45).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(wheel, "modulate:a", 1.0, 0.3).set_delay(0.15)


func _maybe_show_tips() -> void:
	if mode == "level" and level_num == 1 and found.is_empty():
		wheel.show_hint_path(words[0])
		await get_tree().create_timer(0.8).timeout
		_show_toast("Swipe across the letters to make a word!", 0.0)
		_start_finger()
	elif mode == "level" and level_num >= 3 and not GameState.seen_hint_tip:
		GameState.seen_hint_tip = true
		GameState.save_game()
		await get_tree().create_timer(1.0).timeout
		_show_toast("Stuck? Tap the light bulb to reveal a letter.", 4.0)
		_glow(hint_btn)


# --- input handlers -----------------------------------------------------------

func _on_word_changed(w: String) -> void:
	preview.set_word(w)


func _on_word_submitted(word: String, points: Array) -> void:
	if busy:
		return
	if word.length() < 3:
		preview.set_word("")
		return
	var wi := words.find(word)
	if wi >= 0:
		if found.has(word):
			Sfx.play("already_found")
			grid.flash_word(wi)
			preview.reject(word, Color(1, 1, 1, 0.9))
			_show_toast("Already found", 1.0)
			return
		_solve_word(wi, points, true)
	elif level["bonus"].has(word):
		if bonus_found.has(word):
			Sfx.play("already_found")
			preview.reject(word, Color(1, 1, 1, 0.9))
			_show_toast("Bonus word already found", 1.0)
			return
		_collect_bonus(word, points)
	else:
		Sfx.play("wrong")
		GameState.vibrate(30)
		preview.reject(word, Color(1.0, 0.82, 0.82))
		combo = 0


func _solve_word(wi: int, points: Array, by_player: bool) -> void:
	var word: String = words[wi]
	found[word] = true
	for li in word.length():
		revealed.erase("%d:%d" % [wi, li])
	_save_progress()
	GameState.words_found += 1
	Sfx.play("word_found")
	GameState.vibrate(20)
	if by_player:
		preview.accept(word)
	_fly_letters(wi, points)

	if by_player:
		if finger:
			_stop_finger()
			_hide_toast()
		wheel.clear_hint_path()
		var now := Time.get_ticks_msec() / 1000.0
		combo = combo + 1 if now - last_word_time < COMBO_WINDOW else 1
		last_word_time = now
		if combo >= 2:
			_show_praise(COMBO_PRAISE[mini(combo - 2, COMBO_PRAISE.size() - 1)])
		if mode == "level" and level_num == 1 and found.size() == 1 and words.size() > 1:
			_show_toast("Great! Find every word to finish the level.", 2.5)

	if found.size() == words.size():
		_on_level_complete()


func _fly_letters(wi: int, points: Array) -> void:
	var word: String = words[wi]
	var s: float = grid.tile_global_size()
	var center := preview.global_position + preview.size / 2.0
	for li in word.length():
		var target: Vector2 = grid.tile_global_center(wi, li)
		var start: Vector2 = points[li] if li < points.size() else center
		var t: Tile = Tile.new()
		fx.add_child(t)
		t.size = Vector2(s, s)
		t.setup(word[li], tile_color)
		t.state = Tile.State.SOLVED
		t.position = start - t.size / 2.0
		t.scale = Vector2(1.25, 1.25)
		var real: Tile = grid.tile(wi, li)
		var tw := t.create_tween()
		tw.tween_interval(li * 0.045)
		tw.set_parallel(true)
		tw.tween_property(t, "position", target - t.size / 2.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(t, "scale", Vector2.ONE, 0.32)
		tw.set_parallel(false)
		tw.tween_callback(func() -> void:
			real.set_state(Tile.State.SOLVED, true)
			t.queue_free())
	var last_target: Vector2 = grid.tile_global_center(wi, word.length() - 1)
	get_tree().create_timer(0.32 + word.length() * 0.045).timeout.connect(func() -> void: _sparkle(last_target, tile_color.lightened(0.5), 14))


func _collect_bonus(word: String, points: Array) -> void:
	bonus_found[word] = true
	_save_progress()
	Sfx.play("bonus_word")
	preview.accept(word)
	GameState.bonus_total += 1
	GameState.bonus_progress += 1
	var start: Vector2 = preview.global_position + preview.size / 2.0
	if not points.is_empty():
		start = points[points.size() / 2]
	var target := jar_btn.global_position + jar_btn.size / 2.0
	var star := StarFx.new()
	star.size = Vector2(56, 56)
	star.position = start - star.size / 2.0
	fx.add_child(star)
	var tw := star.create_tween()
	tw.set_parallel(true)
	tw.tween_property(star, "position", target - star.size / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(star, "rotation", TAU, 0.55)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		star.queue_free()
		_bump(jar_btn)
		_update_jar()
		_check_jar())
	if not GameState.seen_bonus_tip:
		GameState.seen_bonus_tip = true
		_show_toast("Bonus word! Fill the jar with %d bonus words to earn coins." % GameState.BONUS_TARGET, 3.5)
	else:
		_show_toast("Bonus word: %s" % word, 1.2)
	GameState.save_game()


func _check_jar() -> void:
	if GameState.bonus_progress >= GameState.BONUS_TARGET:
		GameState.bonus_progress -= GameState.BONUS_TARGET
		GameState.save_game()
		_update_jar()
		_show_toast("Bonus jar full! +%d coins" % GameState.BONUS_REWARD, 2.0)
		_fly_coins(jar_btn.global_position + jar_btn.size / 2.0, GameState.BONUS_REWARD)


func _update_jar() -> void:
	jar_btn.fill = float(GameState.bonus_progress) / GameState.BONUS_TARGET
	jar_btn.badge_text = "%d/%d" % [GameState.bonus_progress, GameState.BONUS_TARGET]
	jar_btn.refresh()


func _on_jar_pressed() -> void:
	var list := bonus_found.keys()
	if list.is_empty():
		_show_toast("Find extra words to fill the bonus jar. Every %d words = %d coins!" % [GameState.BONUS_TARGET, GameState.BONUS_REWARD], 3.0)
	else:
		list.sort()
		_show_toast("Bonus words: " + ", ".join(PackedStringArray(list)), 3.5)


func _on_shuffle() -> void:
	Sfx.play("shuffle")
	wheel.shuffle()


# --- hints --------------------------------------------------------------------

func _unrevealed_cells() -> Array:
	var cells := []
	for wi in words.size():
		if found.has(words[wi]):
			continue
		for li in String(words[wi]).length():
			if not revealed.has("%d:%d" % [wi, li]):
				cells.append(Vector2i(wi, li))
	return cells


func _on_hint() -> void:
	if busy:
		return
	_cancel_pick_mode()
	var cells := _unrevealed_cells()
	if cells.is_empty():
		return
	if not GameState.spend(GameState.HINT_COST):
		_no_coins()
		return
	# Reveal the next letter of the shortest unfinished word (feels most helpful).
	var best: Vector2i = cells[0]
	for c in cells:
		var lc := String(words[c.x]).length()
		var lb := String(words[best.x]).length()
		if lc < lb or (lc == lb and c.x == best.x and c.y < best.y):
			best = c
	_mark_hinted()
	_fly_star_to(hint_btn.global_position + hint_btn.size / 2.0, best, 0.0)


func _on_spotlight() -> void:
	if busy:
		return
	if grid.pick_mode:
		_cancel_pick_mode()
		return
	if _unrevealed_cells().is_empty():
		return
	if GameState.coins < GameState.SPOTLIGHT_COST:
		_no_coins()
		return
	grid.pick_mode = true
	spot_btn.glow = 1.0
	spot_btn.refresh()
	_show_toast("Tap any empty tile to reveal its letter.", 0.0)


func _cancel_pick_mode() -> void:
	if grid.pick_mode:
		grid.pick_mode = false
		spot_btn.glow = 0.0
		spot_btn.refresh()
		_hide_toast()


func _on_tile_picked(wi: int, li: int) -> void:
	if not GameState.spend(GameState.SPOTLIGHT_COST):
		_cancel_pick_mode()
		_no_coins()
		return
	_cancel_pick_mode()
	_mark_hinted()
	_fly_star_to(spot_btn.global_position + spot_btn.size / 2.0, Vector2i(wi, li), 0.0)


func _on_burst() -> void:
	if busy:
		return
	_cancel_pick_mode()
	var cells := _unrevealed_cells()
	if cells.is_empty():
		return
	if not GameState.spend(GameState.BURST_COST):
		_no_coins()
		return
	_mark_hinted()
	cells.shuffle()
	var from := burst_btn.global_position + burst_btn.size / 2.0
	for i in mini(5, cells.size()):
		_fly_star_to(from, cells[i], i * 0.12)


func _mark_hinted() -> void:
	hinted = true
	GameState.hints_used += 1
	_save_progress()


func _fly_star_to(from: Vector2, cell: Vector2i, delay: float) -> void:
	var key := "%d:%d" % [cell.x, cell.y]
	revealed[key] = true  # reserve immediately so parallel hints pick other cells
	var star := StarFx.new()
	star.size = Vector2(48, 48)
	star.position = from - star.size / 2.0
	star.modulate.a = 0.0
	fx.add_child(star)
	var target: Vector2 = grid.tile_global_center(cell.x, cell.y)
	var tw := star.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(star, "modulate:a", 1.0, 0.05)
	tw.set_parallel(true)
	tw.tween_property(star, "position", target - star.size / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(star, "rotation", TAU, 0.45)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		star.queue_free()
		_reveal_cell(cell.x, cell.y))
	Sfx.play("hint")


func _reveal_cell(wi: int, li: int) -> void:
	if found.has(words[wi]):
		return
	revealed["%d:%d" % [wi, li]] = true
	grid.reveal_letter(wi, li, true)
	_sparkle(grid.tile_global_center(wi, li), Color(1, 0.95, 0.6), 8)
	_save_progress()
	var complete := true
	for k in String(words[wi]).length():
		if not revealed.has("%d:%d" % [wi, k]):
			complete = false
			break
	if complete:
		_solve_word(wi, [], false)


func _no_coins() -> void:
	Sfx.play("wrong")
	_show_toast("Not enough coins. Solve levels and fill the bonus jar to earn more!", 2.5)
	_bump(coin_pill)


# --- level complete -----------------------------------------------------------

func _on_level_complete() -> void:
	busy = true
	wheel.enabled = false
	_cancel_pick_mode()
	_stop_finger()
	var chapter_done := false
	var reward := 0
	var extra := []
	if mode == "daily":
		var first_time := not GameState.daily_done()
		GameState.complete_daily()
		GameState.progress = {}
		GameState.save_game()
		if first_time:
			reward = GameState.DAILY_PUZZLE_REWARD
			extra.append("Daily streak: %d day%s" % [GameState.daily_streak, "" if GameState.daily_streak == 1 else "s"])
	else:
		chapter_done = level_num % GameState.chapter_size() == 0
		reward = GameState.LEVEL_REWARD
		if not hinted:
			reward += 5
			extra.append("No hints bonus  +5")
		if chapter_done:
			reward += GameState.CHAPTER_REWARD
			extra.append("Chapter complete  +%d" % GameState.CHAPTER_REWARD)
		GameState.complete_level()
		if level_num == 1:
			GameState.tutorial_done = true
			GameState.save_game()
	await get_tree().create_timer(0.75).timeout
	grid.celebrate()
	Sfx.play("chapter_complete" if chapter_done else "level_complete")
	_confetti()
	await get_tree().create_timer(0.9).timeout
	_show_complete_overlay(reward, chapter_done, extra)


func _show_complete_overlay(reward: int, chapter_done: bool, extra: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.35, 0.3)
	var fade := create_tween().set_parallel(true)
	for c in [grid, wheel, preview, toast_panel, shuffle_btn, jar_btn, hint_btn, spot_btn, burst_btn]:
		fade.tween_property(c, "modulate:a", 0.0, 0.3)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	dim.add_child(box)

	var praise_text: String = DONE_PRAISE[(level_num + day) % DONE_PRAISE.size()]
	if chapter_done:
		praise_text = "Chapter Complete!"
	var banner := PanelContainer.new()
	var accent: Color = zen_theme["accent"]
	banner.add_theme_stylebox_override("panel", UI.box(accent, 28, true, Color(1, 1, 1, 0.6), 3))
	var praise := UI.label(praise_text.to_upper(), 56, Color.WHITE, true, 8)
	praise.custom_minimum_size = Vector2(0, 110)
	banner.add_child(praise)
	var banner_wrap := CenterContainer.new()
	banner_wrap.add_child(banner)
	box.add_child(banner_wrap)

	var sub_text := "Daily Puzzle solved!" if mode == "daily" else "Level %d complete" % level_num
	box.add_child(UI.label(sub_text, 36, Color.WHITE, true, 6))

	if mode == "level":
		var chapter := GameState.chapter_of(level_num)
		var pos := (level_num - 1) % GameState.chapter_size() + 1
		var bar := ChapterBar.new()
		bar.custom_minimum_size = Vector2(0, 110)
		bar.title = Themes.chapter_name(chapter)
		bar.total = GameState.chapter_size()
		bar.value = float(pos - 1)
		bar.target = float(pos)
		bar.color = tile_color
		box.add_child(bar)

	if bonus_found.size() > 0:
		box.add_child(UI.label("Bonus words found: %d" % bonus_found.size(), 28, Color(1, 1, 1, 0.9)))
	for line in extra:
		box.add_child(UI.label(line, 28, UI.GOLD, true, 4))

	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 12)
	var ci := CoinIcon.new()
	ci.custom_minimum_size = Vector2(56, 56)
	reward_row.add_child(ci)
	var reward_label := UI.label("+0", 52, Color.WHITE, true, 6)
	reward_row.add_child(reward_label)
	if reward > 0:
		box.add_child(reward_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	var btn_text := "Continue" if mode == "level" else "Back to Menu"
	var next_btn := UI.button(btn_text, Color(0.2, 0.7, 0.35), 40, Vector2(380, 100))
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(next_btn)
	box.add_child(btn_wrap)
	if mode == "level":
		var home := UI.button("Home", Color(1, 1, 1, 0.85), 30, Vector2(220, 74), UI.TEXT_DARK)
		var home_wrap := CenterContainer.new()
		home_wrap.add_child(home)
		box.add_child(home_wrap)
		home.pressed.connect(_go_home)
		next_btn.pressed.connect(_next_level)
	else:
		next_btn.pressed.connect(_go_home)

	await get_tree().process_frame
	var k := 0
	for c in box.get_children():
		if c is Control:
			UI.pop_in(c, k * 0.08)
			k += 1
	if reward > 0:
		await get_tree().create_timer(0.5).timeout
		var tw := create_tween()
		tw.tween_method(func(v: int) -> void: reward_label.text = "+%d" % v, 0, reward, 0.6)
		_fly_coins(ci.global_position + ci.size / 2.0, reward)


func _next_level() -> void:
	GameState.pending_mode = "level"
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _save_progress() -> void:
	var p := GameState.progress_for(progress_key)
	p["found"] = found.keys()
	p["revealed"] = revealed.keys()
	p["bonus"] = bonus_found.keys()
	p["hinted"] = hinted
	GameState.save_game()


# --- feedback effects ---------------------------------------------------------

func _on_coins_changed(new_coins: int) -> void:
	if new_coins < _shown_coins:
		_shown_coins = new_coins
		coin_label.text = str(new_coins)


func _fly_coins(from: Vector2, amount: int) -> void:
	var n := clampi(amount / 5, 4, 10)
	var target := coin_pill.global_position + Vector2(30, coin_pill.size.y / 2.0)
	var start_coins := _shown_coins
	GameState.add_coins(amount)
	for i in n:
		var c := CoinIcon.new()
		c.size = Vector2(40, 40)
		c.position = from - c.size / 2.0 + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		fx.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(c, "position", target - c.size / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var idx := i
		tw.tween_callback(func() -> void:
			c.queue_free()
			Sfx.play("coin", 1.0 + idx * 0.03, -6.0)
			_shown_coins = start_coins + int(round(float(amount) * (idx + 1) / n))
			coin_label.text = str(_shown_coins)
			_bump(coin_pill))


func _bump(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _glow(b: IconButton) -> void:
	var tw := create_tween().set_loops(4)
	tw.tween_method(func(v: float) -> void:
		b.glow = v
		b.refresh(), 0.0, 1.0, 0.4)
	tw.tween_method(func(v: float) -> void:
		b.glow = v
		b.refresh(), 1.0, 0.0, 0.4)


func _show_praise(text: String) -> void:
	var l := UI.label(text, 64, Color.WHITE, true, 10)
	l.add_theme_color_override("font_outline_color", tile_color.darkened(0.2))
	fx.add_child(l)
	l.size = Vector2(size.x, 90)
	l.position = Vector2(0, grid.position.y + grid.size.y * 0.5 - 45)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


func _show_toast(text: String, duration: float) -> void:
	toast_label.text = text
	toast_panel.reset_size()
	_layout()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	if duration > 0.0:
		_toast_tween.tween_interval(duration)
		_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.3)


func _hide_toast() -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.2)


func _sparkle(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = Background._soft_texture(false)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	p.position = at
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _confetti() -> void:
	var colors := [UI.GOLD, tile_color.lightened(0.3), Color(1, 0.5, 0.6), Color(0.5, 0.9, 1.0), Color.WHITE]
	for i in 5:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.explosiveness = 0.85
		p.amount = 40
		p.lifetime = 2.4
		p.direction = Vector2(0, -1)
		p.spread = 60.0
		p.gravity = Vector2(0, 500)
		p.initial_velocity_min = 500.0
		p.initial_velocity_max = 950.0
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.scale_amount_min = 6.0
		p.scale_amount_max = 11.0
		p.color = colors[i]
		p.position = Vector2(size.x * (0.1 + 0.2 * i), size.y + 10)
		fx.add_child(p)
		p.emitting = true
		get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func _start_finger() -> void:
	_stop_finger()
	var pts: Array = wheel.hint_path_points()
	if pts.size() < 2:
		return
	finger = FingerFx.new()
	finger.size = Vector2(60, 60)
	fx.add_child(finger)
	var tw := finger.create_tween().set_loops()
	tw.tween_callback(func() -> void:
		finger.position = pts[0] - finger.size / 2.0
		finger.modulate.a = 0.0)
	tw.tween_property(finger, "modulate:a", 1.0, 0.2)
	for i in range(1, pts.size()):
		tw.tween_property(finger, "position", pts[i] - finger.size / 2.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(finger, "modulate:a", 0.0, 0.25)
	tw.tween_interval(0.4)


func _stop_finger() -> void:
	if finger and is_instance_valid(finger):
		finger.queue_free()
	finger = null


# --- small drawn helpers ------------------------------------------------------

class CoinIcon:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		UI.draw_coin(self, size / 2.0, r * 0.9)


class StarFx:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = size / 2.0

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_circle(size / 2.0, r, Color(1, 0.95, 0.6, 0.35))
		UI.draw_star(self, size / 2.0, r * 0.9, UI.GOLD)


class FingerFx:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c + Vector2(0, 4), 24, Color(0, 0, 0, 0.2))
		draw_circle(c, 24, Color(1, 1, 1, 0.92))
		draw_arc(c, 30, 0, TAU, 32, Color(1, 1, 1, 0.6), 3.0, true)


class ChapterBar:
	extends Control
	var title: String = ""
	var total: int = 20
	var value: float = 0.0
	var target: float = 1.0
	var color: Color = Color.BLUE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_method(func(v: float) -> void:
			value = v
			queue_redraw(), value, target, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var w := size.x
		UI.draw_text_centered(self, "%s   %d/%d" % [title, int(round(value)), total], Vector2(w / 2.0, 22), 28, Color.WHITE)
		var bar := Rect2(Vector2(30, 56), Vector2(w - 120, 34))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.3)
		bg.set_corner_radius_all(17)
		draw_style_box(bg, bar)
		var fillw := bar.size.x * clampf(value / total, 0.0, 1.0)
		if fillw > 4.0:
			var fg := StyleBoxFlat.new()
			fg.bg_color = UI.GOLD
			fg.set_corner_radius_all(17)
			draw_style_box(fg, Rect2(bar.position, Vector2(maxf(fillw, 34.0), bar.size.y)))
		UI.draw_icon(self, "gift", Vector2(bar.end.x + 44, bar.get_center().y), 34, Color(0.95, 0.75, 0.25))
