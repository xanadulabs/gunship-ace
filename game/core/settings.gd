extends Node
## Options and campaign progress, saved under user://.

const PATH := "user://settings.cfg"
const SAVE_PATH := "user://progress.cfg"

var master := 0.8
var music := 0.6
var sfx := 0.8
var fullscreen := false
var shake := true
var scheme := "classic"        # "classic" rotate and thrust, "modern" strafe on A and D
var bindings: Dictionary = {}  # action -> Array of serialized events, only for overrides
var unlocked := 1
var best: Dictionary = {}      # mission index (string) -> best score
var seen_help := false


func _ready() -> void:
	load_all()
	apply_window()


func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = float(cfg.get_value("audio", "master", master))
		music = float(cfg.get_value("audio", "music", music))
		sfx = float(cfg.get_value("audio", "sfx", sfx))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		shake = bool(cfg.get_value("video", "shake", shake))
		scheme = str(cfg.get_value("controls", "scheme", scheme))
		bindings = cfg.get_value("controls", "bindings", {})
		seen_help = bool(cfg.get_value("misc", "seen_help", false))
	var prog := ConfigFile.new()
	if prog.load(SAVE_PATH) == OK:
		unlocked = int(prog.get_value("campaign", "unlocked", 1))
		best = prog.get_value("campaign", "best", {})


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "shake", shake)
	cfg.set_value("controls", "scheme", scheme)
	cfg.set_value("controls", "bindings", bindings)
	cfg.set_value("misc", "seen_help", seen_help)
	cfg.save(PATH)


func save_progress() -> void:
	var prog := ConfigFile.new()
	prog.set_value("campaign", "unlocked", unlocked)
	prog.set_value("campaign", "best", best)
	prog.save(SAVE_PATH)


func record_win(index: int, score: int, count: int) -> void:
	unlocked = clampi(maxi(unlocked, index + 2), 1, count)
	var key := str(index)
	if score > int(best.get(key, 0)):
		best[key] = score
	save_progress()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web"):
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_window()
	save_settings()
