extends Node
## Dev-only harness: drives the game and saves screenshots.
## godot --path . res://tests/runner.tscn -- <scene> <level> <out.png> [solve_count] [extra]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "game"
	var lvl := int(args[1]) if args.size() > 1 else 1
	var out: String = args[2] if args.size() > 2 else "/tmp/shot.png"
	var solve := int(args[3]) if args.size() > 3 else 0
	var extra: String = args[4] if args.size() > 4 else ""
	GameState.level = lvl
	GameState.progress = {}
	GameState.last_reward_day = GameState.today() if extra != "reward" else -1
	GameState.seen_hint_tip = true
	GameState.pending_mode = "daily" if extra == "daily" else "level"
	var cur: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	get_tree().root.add_child.call_deferred(cur)
	await get_tree().create_timer(1.2).timeout
	if scene == "game":
		var words: Array = cur.words
		for i in mini(solve, words.size()):
			cur._on_word_submitted(words[i], [])
			await get_tree().create_timer(0.25).timeout
		if extra == "bonus":
			var b: Array = cur.level["bonus"].keys()
			if b.size() > 0:
				cur._on_word_submitted(b[0], [])
		if extra == "hint":
			cur._on_hint()
			cur._on_burst()
		if extra == "drag":
			var wheel = cur.wheel
			wheel._selected = [0, 1, 2]
			wheel._dragging = true
			wheel._pointer = wheel.size / 2.0
			cur.preview.set_word(wheel.current_word())
			wheel.queue_redraw()
	if scene == "main_menu" and extra == "chapters":
		cur._close_popup()
		cur._open_chapters()
	if scene == "main_menu" and extra == "settings":
		cur._open_settings()
	var wait := float(args[5]) if args.size() > 5 else (3.5 if solve >= 99 else 1.2)
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
