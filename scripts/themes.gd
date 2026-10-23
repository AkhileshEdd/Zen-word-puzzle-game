extends RefCounted
## Visual themes. Every chapter (20 levels) gets the next theme and a place name,
## so the scenery keeps changing as the player progresses.

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func count() -> int:
	return all().size()


static func get_theme(index: int) -> Dictionary:
	var list := all()
	return list[posmod(index, list.size())]


static func for_chapter(chapter: int) -> Dictionary:
	return get_theme(chapter)


## Display name for a chapter (0-based), e.g. "Lotus Lake II".
static func chapter_name(chapter: int) -> String:
	var theme := for_chapter(chapter)
	var places: Array = theme["places"]
	var cycle := chapter / count()
	var place: String = places[cycle % places.size()]
	var round_num := cycle / places.size()
	if round_num > 0:
		place += " " + _roman(round_num + 1)
	return place


static func _roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	for i in vals.size():
		while n >= vals[i]:
			out += syms[i]
			n -= vals[i]
	return out


static func _c(hex: String) -> Color:
	return Color.html(hex)


static func _build() -> Array:
	return [
		{
			"id": "dawn",
			"places": ["Misty Dawn", "Quiet Valley", "Morning Dew", "Pine Hollow", "Soft Horizon"],
			"sky": [_c("#6f9fe6"), _c("#b9b6ea"), _c("#f6c7d8")],
			"sun": _c("#fff4dc"), "sun_pos": Vector2(0.72, 0.5), "night": false,
			"hills": [_c("#9fb3dc"), _c("#6f8fb5"), _c("#3f7a4e")],
			"ground": _c("#4b8a3a"), "water": false,
			"tile": _c("#1e4f93"), "accent": _c("#2b6cd1"), "particles": "dust",
		},
		{
			"id": "lake",
			"places": ["Lotus Lake", "Still Waters", "Mirror Bay", "Crystal Shore", "Heron Cove"],
			"sky": [_c("#3f7fd8"), _c("#88b9ef"), _c("#d9ecfb")],
			"sun": _c("#ffffff"), "sun_pos": Vector2(0.25, 0.38), "night": false,
			"hills": [_c("#dfe8f3"), _c("#7f97b0"), _c("#2c5a3c")],
			"ground": _c("#2f6fa8"), "water": true,
			"tile": _c("#5b4de6"), "accent": _c("#6c5cf0"), "particles": "dust",
		},
		{
			"id": "forest",
			"places": ["Bamboo Grove", "Whispering Pines", "Moss Garden", "Fern Valley", "Cedar Path"],
			"sky": [_c("#5fb3b0"), _c("#a9d8c2"), _c("#eaf4d6")],
			"sun": _c("#fffbe0"), "sun_pos": Vector2(0.65, 0.4), "night": false,
			"hills": [_c("#9cc7a8"), _c("#5d9a6d"), _c("#2f6b3f")],
			"ground": _c("#2c5f34"), "water": false,
			"tile": _c("#23845a"), "accent": _c("#2fa36f"), "particles": "fireflies",
		},
		{
			"id": "sunset",
			"places": ["Golden Hour", "Amber Sky", "Coral Coast", "Ember Ridge", "Evening Glow"],
			"sky": [_c("#5a4fa3"), _c("#e7799a"), _c("#ffc27a")],
			"sun": _c("#ffe1a8"), "sun_pos": Vector2(0.5, 0.6), "night": false,
			"hills": [_c("#b8679a"), _c("#7a3f78"), _c("#3e2450")],
			"ground": _c("#2e1b3c"), "water": false,
			"tile": _c("#e2552c"), "accent": _c("#f06a3a"), "particles": "dust",
		},
		{
			"id": "snow",
			"places": ["Silent Peaks", "Frost Summit", "White Ridge", "Glacier Pass", "Winter Calm"],
			"sky": [_c("#7d8aa6"), _c("#c9b8c7"), _c("#f1dcd6")],
			"sun": _c("#fff1ea"), "sun_pos": Vector2(0.3, 0.45), "night": false,
			"hills": [_c("#eef1f6"), _c("#c3cad8"), _c("#8d98ad")],
			"ground": _c("#e8edf4"), "water": false,
			"tile": _c("#d9432c"), "accent": _c("#e8543a"), "particles": "snow",
			"empty": Color(0.42, 0.47, 0.62, 0.32),
		},
		{
			"id": "desert",
			"places": ["Sand Whisper", "Dune Sea", "Oasis Rest", "Copper Canyon", "Sun Temple"],
			"sky": [_c("#4b9ad6"), _c("#9fcbe6"), _c("#f6e3b5")],
			"sun": _c("#fff7d1"), "sun_pos": Vector2(0.78, 0.35), "night": false,
			"hills": [_c("#e8c48a"), _c("#d79e5c"), _c("#b8743a")],
			"ground": _c("#c98a47"), "water": false,
			"tile": _c("#c4661b"), "accent": _c("#de7d25"), "particles": "dust",
		},
		{
			"id": "night",
			"places": ["Moonlit Path", "Starry Hill", "Lantern Night", "Midnight Pond", "Owl's Rest"],
			"sky": [_c("#0d1538"), _c("#26306a"), _c("#4b4f8c")],
			"sun": _c("#f5f1d0"), "sun_pos": Vector2(0.75, 0.3), "night": true,
			"hills": [_c("#3a3f78"), _c("#262a58"), _c("#151837")],
			"ground": _c("#10132c"), "water": false,
			"tile": _c("#3e55c4"), "accent": _c("#f2c14e"), "particles": "fireflies",
		},
		{
			"id": "aurora",
			"places": ["Northern Lights", "Polar Dream", "Aurora Fields", "Frozen Fjord", "Sky Dance"],
			"sky": [_c("#06213a"), _c("#0f4c5c"), _c("#2a7f7a")],
			"sun": _c("#e9fff5"), "sun_pos": Vector2(0.2, 0.28), "night": true,
			"hills": [_c("#1d4a5a"), _c("#123544"), _c("#0a2230")],
			"ground": _c("#dfeff2"), "water": false,
			"tile": _c("#138f86"), "accent": _c("#3bd1b4"), "particles": "snow",
			"empty": Color(1, 1, 1, 0.35),
		},
		{
			"id": "sakura",
			"places": ["Cherry Blossom", "Petal Stream", "Spring Garden", "Pink Temple", "Blossom Hill"],
			"sky": [_c("#8fb8ef"), _c("#f0c5df"), _c("#ffe6ee")],
			"sun": _c("#fff6f8"), "sun_pos": Vector2(0.7, 0.42), "night": false,
			"hills": [_c("#c8b3dd"), _c("#a07fb8"), _c("#5d8f55")],
			"ground": _c("#6aa257"), "water": false,
			"tile": _c("#d4437a"), "accent": _c("#e75a8f"), "particles": "petals",
		},
		{
			"id": "autumn",
			"places": ["Maple Trail", "Harvest Moon", "Amber Woods", "Falling Leaves", "Rustic Hollow"],
			"sky": [_c("#5e88c4"), _c("#e3b48c"), _c("#f7dcae")],
			"sun": _c("#fff0d0"), "sun_pos": Vector2(0.28, 0.46), "night": false,
			"hills": [_c("#d39a6a"), _c("#b4602f"), _c("#6e3a1f")],
			"ground": _c("#7a4a22"), "water": false,
			"tile": _c("#b4501f"), "accent": _c("#d9692b"), "particles": "leaves",
		},
	]
