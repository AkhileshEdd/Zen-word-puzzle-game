extends Node
## Persistent player state: progress, coins, settings, daily rewards and the
## in-progress state of the current level (so a level can be resumed).

signal coins_changed(coins: int)
signal settings_changed

const SAVE_PATH := "user://save.json"
const START_COINS := 200
const BONUS_TARGET := 10
const BONUS_REWARD := 25
const LEVEL_REWARD := 10
const CHAPTER_REWARD := 50
const DAILY_PUZZLE_REWARD := 60
const HINT_COST := 25
const SPOTLIGHT_COST := 50
const BURST_COST := 90
const DAILY_REWARDS := [20, 30, 40, 50, 60, 80, 150]

const RANKS := [
	[1, "Seedling"], [21, "Sprout"], [61, "Novice"], [121, "Apprentice"],
	[241, "Wordsmith"], [401, "Scholar"], [601, "Poet"], [901, "Sage"],
	[1301, "Philosopher"], [1801, "Zen Master"], [2501, "Enlightened"],
]

var level: int = 1
var coins: int = START_COINS
var bonus_progress: int = 0
var bonus_total: int = 0
var words_found: int = 0
var hints_used: int = 0

var sound_on: bool = true
var music_on: bool = true
var haptics_on: bool = true

var last_reward_day: int = -1
var reward_streak: int = 0
var daily_done_day: int = -1
var daily_streak: int = 0

var tutorial_done: bool = false
var seen_bonus_tip: bool = false
var seen_hint_tip: bool = false

## In-progress level: {"key": "L12" / "D20123", "found": [], "revealed": [], "bonus": []}
var progress: Dictionary = {}

## Set by menus before switching to the game scene: "level" or "daily".
var pending_mode: String = "level"


func _ready() -> void:
	load_game()


func today() -> int:
	var t := Time.get_unix_time_from_system()
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return int(floor((t + bias * 60.0) / 86400.0))


func chapter_size() -> int:
	return LevelDB.chapter_size


func chapter_of(level_num: int) -> int:
	return (level_num - 1) / chapter_size()


func rank_name(level_num: int = -1) -> String:
	if level_num < 0:
		level_num = level
	var title: String = RANKS[0][1]
	for r in RANKS:
		if level_num >= r[0]:
			title = r[1]
	return title


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_game()


func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_game()
	return true


func vibrate(ms: int = 12) -> void:
	if haptics_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- daily login reward -------------------------------------------------------

func can_claim_reward() -> bool:
	return last_reward_day != today()


## Day (0-6) of the 7-day reward cycle that would be claimed today.
func reward_day_index() -> int:
	if last_reward_day == today() - 1:
		return reward_streak % DAILY_REWARDS.size()
	if last_reward_day == today():
		return (reward_streak - 1) % DAILY_REWARDS.size()
	return 0


func claim_reward() -> int:
	if not can_claim_reward():
		return 0
	if last_reward_day == today() - 1:
		reward_streak += 1
	else:
		reward_streak = 1
	last_reward_day = today()
	var amount: int = DAILY_REWARDS[(reward_streak - 1) % DAILY_REWARDS.size()]
	add_coins(amount)
	return amount


# --- daily puzzle -------------------------------------------------------------

func daily_done() -> bool:
	return daily_done_day == today()


func complete_daily() -> void:
	if daily_done():
		return
	if daily_done_day == today() - 1:
		daily_streak += 1
	else:
		daily_streak = 1
	daily_done_day = today()
	add_coins(DAILY_PUZZLE_REWARD)


# --- level progress -----------------------------------------------------------

func progress_for(key: String) -> Dictionary:
	if progress.get("key", "") != key:
		progress = {"key": key, "found": [], "revealed": [], "bonus": [], "hinted": false}
	return progress


func complete_level() -> void:
	level += 1
	progress = {}
	save_game()


func save_game() -> void:
	var data := {
		"level": level, "coins": coins, "bonus_progress": bonus_progress,
		"bonus_total": bonus_total, "words_found": words_found, "hints_used": hints_used,
		"sound_on": sound_on, "music_on": music_on, "haptics_on": haptics_on,
		"last_reward_day": last_reward_day, "reward_streak": reward_streak,
		"daily_done_day": daily_done_day, "daily_streak": daily_streak,
		"tutorial_done": tutorial_done, "seen_bonus_tip": seen_bonus_tip,
		"seen_hint_tip": seen_hint_tip, "progress": progress,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	level = int(d.get("level", 1))
	coins = int(d.get("coins", START_COINS))
	bonus_progress = int(d.get("bonus_progress", 0))
	bonus_total = int(d.get("bonus_total", 0))
	words_found = int(d.get("words_found", 0))
	hints_used = int(d.get("hints_used", 0))
	sound_on = bool(d.get("sound_on", true))
	music_on = bool(d.get("music_on", true))
	haptics_on = bool(d.get("haptics_on", true))
	last_reward_day = int(d.get("last_reward_day", -1))
	reward_streak = int(d.get("reward_streak", 0))
	daily_done_day = int(d.get("daily_done_day", -1))
	daily_streak = int(d.get("daily_streak", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	seen_bonus_tip = bool(d.get("seen_bonus_tip", false))
	seen_hint_tip = bool(d.get("seen_hint_tip", false))
	var p: Variant = d.get("progress", {})
	progress = p if typeof(p) == TYPE_DICTIONARY else {}


func reset_progress() -> void:
	level = 1
	coins = START_COINS
	bonus_progress = 0
	bonus_total = 0
	words_found = 0
	hints_used = 0
	tutorial_done = false
	seen_bonus_tip = false
	seen_hint_tip = false
	progress = {}
	daily_done_day = -1
	daily_streak = 0
	coins_changed.emit(coins)
	save_game()


func set_setting(key: String, value: bool) -> void:
	set(key, value)
	save_game()
	settings_changed.emit()
