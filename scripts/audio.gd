extends Node
## أصوات مولّدة بالكود: صوت المحرك، المطر والهوا والموج، وأصوات الالتقاط والرعد

const RATE := 22050.0

var engine_player := AudioStreamPlayer.new()
var amb_player := AudioStreamPlayer.new()
var sfx_player := AudioStreamPlayer.new()
var engine_pb: AudioStreamGeneratorPlayback
var amb_pb: AudioStreamGeneratorPlayback

var rpm := 0.0
var engine_load := 0.0
var rain := 0.0
var wind := 0.3
var waves := 0.0
var engine_on := true

var _ph := 0.0
var _ph2 := 0.0
var _lp := 0.0
var _alp := 0.0
var _alp2 := 0.0
var _wave_t := 0.0
var _sounds := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in [engine_player, amb_player]:
		var g := AudioStreamGenerator.new()
		g.mix_rate = RATE
		g.buffer_length = 0.12
		p.stream = g
		add_child(p)
		p.play()
	engine_player.volume_db = -9.0
	amb_player.volume_db = -6.0
	add_child(sfx_player)
	engine_pb = engine_player.get_stream_playback()
	amb_pb = amb_player.get_stream_playback()
	_sounds["pickup"] = _make_tones([660.0, 880.0, 1320.0], 0.07)
	_sounds["rare"] = _make_tones([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.08)
	_sounds["fuel"] = _make_tones([440.0, 554.0], 0.09)
	_sounds["thunder"] = _make_noise_burst(2.5)
	_sounds["error"] = _make_tones([220.0, 180.0], 0.12)
	_sounds["crash"] = _make_crash(0.7, 0.35)
	_sounds["crack"] = _make_crash(0.45, 0.8)
	_sounds["horn"] = _make_horn(0.9)


func play(snd: String, vol_db := -4.0) -> void:
	if not _sounds.has(snd):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[snd]
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _process(_delta: float) -> void:
	_fill_engine()
	_fill_ambient()


func _fill_engine() -> void:
	if engine_pb == null:
		return
	var n := engine_pb.get_frames_available()
	var f := 32.0 + rpm * 120.0
	var vol := (0.18 + engine_load * 0.22) if engine_on else 0.0
	for i in n:
		_ph = fmod(_ph + f / RATE, 1.0)
		_ph2 = fmod(_ph2 + f * 0.5 / RATE, 1.0)
		var saw := _ph * 2.0 - 1.0
		var pulse := 1.0 if _ph2 < 0.3 else -0.4
		var s := saw * 0.55 + pulse * 0.35 + (randf() - 0.5) * 0.12 * (0.3 + engine_load)
		_lp += (s - _lp) * (0.12 + rpm * 0.18)
		var v := _lp * vol
		engine_pb.push_frame(Vector2(v, v))


func _fill_ambient() -> void:
	if amb_pb == null:
		return
	var n := amb_pb.get_frames_available()
	var rv := clampf(rain, 0.0, 1.6) * 0.22
	var wv := clampf(wind, 0.0, 3.0) * 0.05
	for i in n:
		_wave_t += 1.0 / RATE
		var w := randf() - 0.5
		_alp += (w - _alp) * 0.5
		_alp2 += (w - _alp2) * 0.02
		var surf := (sin(_wave_t * 0.9) * 0.5 + 0.5)
		surf = surf * surf * waves * 0.5
		var v := _alp * rv + _alp2 * (wv + surf) * 3.0
		amb_pb.push_frame(Vector2(v, v))


func _make_tones(freqs: Array, dur: float) -> AudioStreamWAV:
	var total := int(RATE * dur * freqs.size())
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var k := mini(int(float(i) / (RATE * dur)), freqs.size() - 1)
		var t := float(i) / RATE
		var local := fmod(t, dur) / dur
		var env := (1.0 - local) * minf(local * 20.0, 1.0)
		var s := sin(TAU * freqs[k] * t) * 0.6 + sin(TAU * freqs[k] * 2.0 * t) * 0.15
		data.encode_s16(i * 2, int(clampf(s * env * 0.6, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.data = data
	return wav


func _make_noise_burst(dur: float) -> AudioStreamWAV:
	var total := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(total * 2)
	var lp := 0.0
	var lp2 := 0.0
	for i in total:
		var t := float(i) / total
		lp += (randf() - 0.5 - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		var env := pow(1.0 - t, 2.0) * minf(t * 30.0, 1.0) * (0.7 + 0.3 * sin(t * 40.0))
		data.encode_s16(i * 2, int(clampf(lp2 * env * 14.0, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.data = data
	return wav


## صوت تكسير: ضوضاء خشنة تخف بسرعة. bright = حدة الصوت (خشب أعلى، حجر أوطى)
func _make_crash(dur: float, bright: float) -> AudioStreamWAV:
	var total := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(total * 2)
	var lp := 0.0
	var hold := 0.0
	for i in total:
		var t := float(i) / total
		if i % int(8 + (1.0 - bright) * 40) == 0:
			hold = randf() * 2.0 - 1.0
		lp += (hold - lp) * (0.15 + bright * 0.5)
		var env := pow(1.0 - t, 3.0) * minf(t * 200.0, 1.0)
		var crackle := 1.0 if randf() < 0.02 * (1.0 - t) else 0.0
		var sv := lp * env * 0.9 + (randf() - 0.5) * crackle * env
		data.encode_s16(i * 2, int(clampf(sv, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.data = data
	return wav



## زمّور شاحنة: نغمتين مع بعض
func _make_horn(dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := clampf(t * 30.0, 0.0, 1.0) * clampf((dur - t) * 12.0, 0.0, 1.0)
		var v := (signf(sin(TAU * 233.0 * t)) * 0.5 + signf(sin(TAU * 294.0 * t)) * 0.5) * 0.28 + sin(TAU * 466.0 * t) * 0.1
		var s16 := int(clampf(v * env, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s16)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.data = data
	return w
