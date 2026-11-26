class_name BattleSfxPool
extends RefCounted

var muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _last_play_ms: Dictionary = {}


func init(owner: Node, sound_names: Array[String], pool_size: int = 10) -> void:
	for nm in sound_names:
		var path := "res://Windows/Battle/assets/audio/%s.wav" % nm
		if ResourceLoader.exists(path):
			_streams[nm] = load(path)
	for _i in range(pool_size):
		var ap := AudioStreamPlayer.new()
		owner.add_child(ap)
		_players.append(ap)


func set_muted(v: bool) -> void:
	muted = v
	if muted:
		for ap in _players:
			ap.stop()


func toggle_mute() -> void:
	set_muted(not muted)
	if not muted:
		play("ui_click", 0.65)


func play(nm: String, vol: float = 0.6) -> void:
	if muted or not _streams.has(nm) or _players.is_empty():
		return
	var now := Time.get_ticks_msec()
	var prev: int = int(_last_play_ms.get(nm, 0))
	if now - prev < 65 and nm != "ui_click":
		return
	_last_play_ms[nm] = now
	var ap := _players[_next_idx % _players.size()]
	_next_idx += 1
	ap.stream = _streams[nm]
	ap.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	ap.pitch_scale = randf_range(0.92, 1.08)
	ap.play()
