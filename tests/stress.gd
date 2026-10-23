extends Node
## Dev-only: plays through levels by submitting every answer, to catch runtime errors.

func _ready() -> void:
	await get_tree().process_frame
	var levels := [1, 2, 3, 19, 20, 21, 100, 500, 999, 1500, 2000, 2999, 3000, 3001, 4500]
	for lvl in levels:
		GameState.level = lvl
		GameState.progress = {}
		GameState.pending_mode = "level"
		var g: Node = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(g)
		await get_tree().create_timer(0.5).timeout
		g._on_word_submitted("ZZZ", [])
		var b: Array = g.level["bonus"].keys()
		if b.size() > 0:
			g._on_word_submitted(b[0], [])
			g._on_word_submitted(b[0], [])
		g._on_hint()
		g._on_burst()
		g._on_spotlight()
		g._on_tile_picked(g.words.size() - 1, 0)
		await get_tree().create_timer(0.6).timeout
		for w in g.words:
			g._on_word_submitted(w, [])
		g._on_word_submitted(g.words[0], [])
		await get_tree().create_timer(3.0).timeout
		print("level ", lvl, " ok -> now ", GameState.level, " coins ", GameState.coins)
		g.queue_free()
		await get_tree().process_frame
	GameState.pending_mode = "daily"
	var d: Node = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(d)
	await get_tree().create_timer(0.5).timeout
	for w in d.words:
		d._on_word_submitted(w, [])
	await get_tree().create_timer(3.0).timeout
	print("daily ok, done=", GameState.daily_done(), " streak ", GameState.daily_streak)
	d.queue_free()
	var m: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(m)
	await get_tree().create_timer(1.0).timeout
	m._open_chapters()
	m._open_settings()
	m._open_daily_reward()
	await get_tree().create_timer(0.5).timeout
	print("menu ok")
	get_tree().quit()
