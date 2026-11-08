extends Node
## Sound: a music player, a rotor loop, and a pool of one-shot players.

const POOL := 14
const LOOPED := ["rotor", "music_mission", "music_title"]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _rotor: AudioStreamPlayer
var _music_name := ""
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_rotor = AudioStreamPlayer.new()
	_rotor.bus = "SFX"
	_rotor.volume_db = -60.0
	add_child(_rotor)
	apply_volumes()


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _db(Settings.master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _db(Settings.music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _db(Settings.sfx))


func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


func stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := "res://audio/%s.wav" % sound
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s is AudioStreamWAV and LOOPED.has(sound):
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_streams[sound] = s
	return s


func play(sound: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.0) -> void:
	if min_gap > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(_last_play.get(sound, -10.0)) < min_gap:
			return
		_last_play[sound] = now
	var s := stream(sound)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	if track == "":
		_music.stop()
		return
	_music.stream = stream(track)
	_music.volume_db = -4.0
	_music.play()


func rotor(on: bool, speed01 := 0.0, lift01 := 0.0) -> void:
	if not on:
		if _rotor.playing:
			_rotor.stop()
		return
	if not _rotor.playing:
		_rotor.stream = stream("rotor")
		_rotor.play()
	_rotor.volume_db = -9.0 + speed01 * 3.0 - lift01 * 3.0
	_rotor.pitch_scale = 0.95 + speed01 * 0.12
