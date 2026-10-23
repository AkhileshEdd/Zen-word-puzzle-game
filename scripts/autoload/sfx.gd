extends Node
## Sound effects and the ambient music loop.

const SOUNDS := [
	"word_found", "bonus_word", "wrong", "already_found", "hint", "coin",
	"level_complete", "chapter_complete", "click", "shuffle",
]
const SELECT_NOTES := 9

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		_streams[s] = load("res://assets/audio/%s.wav" % s)
	for i in SELECT_NOTES:
		_streams["select_%d" % i] = load("res://assets/audio/select_%d.wav" % i)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	add_child(_music)
	var music_stream: Variant = load("res://assets/audio/music_zen.wav")
	if music_stream is AudioStreamWAV:
		var wav: AudioStreamWAV = music_stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate) - 1
		_music.stream = wav
	GameState.settings_changed.connect(_apply_music)
	_apply_music()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not GameState.sound_on or not _streams.has(sound) or _streams[sound] == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Rising pentatonic note for the n-th letter of the word being traced.
func play_select(index: int) -> void:
	play("select_%d" % clampi(index, 0, SELECT_NOTES - 1), 1.0, -3.0)


func click() -> void:
	play("click")


func _apply_music() -> void:
	if _music.stream == null:
		return
	if GameState.music_on and not _music.playing:
		_music.play()
	elif not GameState.music_on and _music.playing:
		_music.stop()
