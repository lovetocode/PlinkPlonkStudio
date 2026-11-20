extends Control

signal render_ready(list: Array, target: String)

const RATE := 22050
const RULER_H := 34.0
const TOP_H := 120.0
const BOT_H := 120.0
const MAX_LAYERS := 6
const BAR_OPTIONS := [2, 4, 8, 16]
const LUT_N := 1024
const DRUM_STEP := 0.5
const DRUM_NAMES := ["Hat", "Clap", "Snare", "Kick"]
const DEFAULTS := ["Square lead", "Bass", "Drums", "Pulse lead", "Saw", "Sine"]
const KEYS := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const SCALES := {
	"Major pentatonic": [0, 2, 4, 7, 9],
	"Minor pentatonic": [0, 3, 5, 7, 10],
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Minor": [0, 2, 3, 5, 7, 8, 10],
	"Blues": [0, 3, 5, 6, 7, 10],
	"Chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
}
# wave: 0 square, 1 pulse 25%, 2 triangle, 3 saw, 4 sine
const INST_NAMES := ["Square lead", "Pulse lead", "Bass", "Saw", "Sine", "Drums"]
const INSTS := {
	"Square lead": {"wave": 0, "base": 60, "octs": 2},
	"Pulse lead": {"wave": 1, "base": 60, "octs": 2},
	"Bass": {"wave": 2, "base": 36, "octs": 2},
	"Saw": {"wave": 3, "base": 48, "octs": 2},
	"Sine": {"wave": 4, "base": 60, "octs": 2},
	"Drums": {"wave": -1, "base": 0, "octs": 0},
}
const LAYER_COLORS := [
	Color(1.0, 0.4, 0.4), Color(0.4, 0.8, 1.0), Color(0.5, 1.0, 0.5),
	Color(1.0, 0.85, 0.3), Color(0.8, 0.5, 1.0), Color(1.0, 0.6, 0.2),
]

var colors := {"white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY}:
	set(value):
		colors = value
		queue_redraw()
		if canvas:
			canvas.queue_redraw()

var bpm := 100:
	set(v):
		bpm = v
		mark_all_dirty()

var layers := []
var sel := 0
var bars := 4
var scale_name := "Minor pentatonic"
var root := 0
var snap_on := true
var loop_on := true
var playing := false
var play_beat := 0.0

var drawing := false
var cur_stroke := PackedVector2Array()
var last_pos := Vector2.ZERO
var paint_mode := ""
var gesture_add := []
var gesture_del := []

var live_on := false
var live_hz := 440.0
var live_f := 440.0
var live_amp := 0.0
var live_ph := 0.0
var live_kind := 0
var live_player: AudioStreamPlayer
var live_pb: AudioStreamGeneratorPlayback

var lut_cache := {}
var players := []
var drum_pool := []
var drum_pool_i := 0
var drum_buf := []
var drum_wav := []

var canvas: Control
var head: HFlowContainer
var foot: HFlowContainer
var layer_row: HBoxContainer
var play_btn: Button
var loop_btn: Button
var snap_btn: Button
var bars_btn: OptionButton
var scale_btn: OptionButton
var key_btn: OptionButton
var inst_btn: OptionButton
var mute_btn: Button

func _ready() -> void:
	clip_contents = true
	make_drums()
	for i in MAX_LAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Monitor"
		add_child(p)
		players.append(p)
	for i in 6:
		var dp := AudioStreamPlayer.new()
		dp.bus = "Monitor"
		add_child(dp)
		drum_pool.append(dp)

	live_player = AudioStreamPlayer.new()
	live_player.bus = "Rec"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	live_player.stream = gen
	add_child(live_player)
	live_player.play()
	live_pb = live_player.get_stream_playback()

	canvas = Control.new()
	canvas.clip_contents = true
	canvas.draw.connect(draw_canvas)
	canvas.gui_input.connect(canvas_input)
	add_child(canvas)

	head = HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	head.add_theme_constant_override("v_separation", 6)
	add_child(head)
	play_btn = add_btn(head, "Play", 100, toggle_play)
	loop_btn = add_btn(head, "Loop", 90, func(): loop_on = loop_btn.button_pressed)
	loop_btn.toggle_mode = true
	loop_btn.button_pressed = true
	bars_btn = add_option(head, ["2 bars", "4 bars", "8 bars", "16 bars"], 120, on_bars)
	bars_btn.select(BAR_OPTIONS.find(bars))
	scale_btn = add_option(head, SCALES.keys(), 170, on_scale)
	scale_btn.select(SCALES.keys().find(scale_name))
	key_btn = add_option(head, KEYS, 80, on_key)
	snap_btn = add_btn(head, "Snap", 90, func(): set_snap(snap_btn.button_pressed))
	snap_btn.toggle_mode = true
	snap_btn.button_pressed = true
	add_btn(head, "Undo", 90, undo)
	add_btn(head, "Clear", 90, clear_layer)
	add_btn(head, "To mixer", 130, func(): send("mixer"))
	add_btn(head, "To sequencer", 160, func(): send("seq"))

	foot = HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 8)
	foot.add_theme_constant_override("v_separation", 6)
	add_child(foot)
	layer_row = HBoxContainer.new()
	layer_row.add_theme_constant_override("separation", 6)
	foot.add_child(layer_row)
	add_btn(foot, "+ Layer", 110, func(): add_layer())
	inst_btn = add_option(foot, INST_NAMES, 150, on_inst)
	mute_btn = add_btn(foot, "Mute", 90, toggle_mute)
	mute_btn.toggle_mode = true
	add_btn(foot, "Del layer", 120, delete_layer)

	resized.connect(do_layout)
	do_layout()
	add_layer()

func add_btn(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func add_option(parent: Control, items: Array, w: float, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(w, 50)
	for it in items:
		o.add_item(str(it))
	o.item_selected.connect(cb)
	parent.add_child(o)
	return o

func do_layout() -> void:
	head.position = Vector2(8, 6)
	head.size = Vector2(size.x - 16, TOP_H - 8)
	foot.position = Vector2(8, size.y - BOT_H + 6)
	foot.size = Vector2(size.x - 16, BOT_H - 8)
	canvas.position = Vector2(0, TOP_H)
	canvas.size = Vector2(size.x, maxf(size.y - TOP_H - BOT_H, 0.0))
	canvas.queue_redraw()

# ---------- layers ----------

func add_layer() -> void:
	if layers.size() >= MAX_LAYERS:
		return
	layers.append({"inst": DEFAULTS[layers.size()], "mute": false, "strokes": [], "hits": [],
		"undo": [], "wav": null, "dirty": true})
	sel = layers.size() - 1
	refresh_ui()

func refresh_ui() -> void:
	for c in layer_row.get_children():
		c.queue_free()
	for i in layers.size():
		var b := Button.new()
		b.text = str(i + 1) + " " + layers[i].inst
		b.toggle_mode = true
		b.button_pressed = (i == sel)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 50)
		b.pressed.connect(select_layer.bind(i))
		layer_row.add_child(b)
	inst_btn.select(INST_NAMES.find(layers[sel].inst))
	mute_btn.set_pressed_no_signal(layers[sel].mute)
	canvas.queue_redraw()

func select_layer(i: int) -> void:
	sel = i
	refresh_ui()

func on_inst(i: int) -> void:
	layers[sel].inst = INST_NAMES[i]
	layers[sel].dirty = true
	refresh_ui()

func toggle_mute() -> void:
	layers[sel].mute = mute_btn.button_pressed
	canvas.queue_redraw()

func delete_layer() -> void:
	stop_play()
	layers.remove_at(sel)
	if layers.is_empty():
		add_layer()
		return
	sel = clampi(sel, 0, layers.size() - 1)
	refresh_ui()

func clear_layer() -> void:
	var l: Dictionary = layers[sel]
	l.strokes.clear()
	l.hits.clear()
	l.undo.clear()
	l.dirty = true
	canvas.queue_redraw()

func undo() -> void:
	var l: Dictionary = layers[sel]
	if l.undo.is_empty():
		return
	var u: Dictionary = l.undo.pop_back()
	if u.has("stroke"):
		l.strokes.pop_back()
	else:
		for h in u.add:
			l.hits.erase(h)
		for h in u.del:
			l.hits.append(h)
	l.dirty = true
	canvas.queue_redraw()

func is_drum(l: Dictionary) -> bool:
	return l.inst == "Drums"

# ---------- settings ----------

func on_bars(i: int) -> void:
	bars = BAR_OPTIONS[i]
	stop_play()
	mark_all_dirty()
	canvas.queue_redraw()

func on_scale(i: int) -> void:
	scale_name = SCALES.keys()[i]
	mark_all_dirty()
	canvas.queue_redraw()

func on_key(i: int) -> void:
	root = i
	mark_all_dirty()

func set_snap(on: bool) -> void:
	snap_on = on
	mark_all_dirty()
	canvas.queue_redraw()

func mark_all_dirty() -> void:
	lut_cache.clear()
	for l in layers:
		l.dirty = true

# ---------- geometry ----------

func total_beats() -> float:
	return bars * 4.0

func plot_h() -> float:
	return maxf(canvas.size.y - RULER_H, 1.0)

func x_to_beat(x: float) -> float:
	return clampf(x / maxf(canvas.size.x, 1.0) * total_beats(), 0.0, total_beats())

func beat_to_x(b: float) -> float:
	return b / total_beats() * canvas.size.x

func y_to_pitch(y: float) -> float:
	return clampf(1.0 - (y - RULER_H) / plot_h(), 0.0, 1.0)

func pitch_to_y(p: float) -> float:
	return RULER_H + (1.0 - p) * plot_h()

# ---------- pitch table (y -> Hz), snapped to the scale if Snap is on ----------

func get_lut(inst_name: String) -> PackedFloat32Array:
	if not lut_cache.has(inst_name):
		lut_cache[inst_name] = build_lut(inst_name)
	return lut_cache[inst_name]

func build_lut(inst_name: String) -> PackedFloat32Array:
	var info: Dictionary = INSTS[inst_name]
	var octs: int = info.octs
	var span := octs * 12
	var base: int = int(info.base) + root
	var tones := []
	for o in octs + 1:
		for iv in SCALES[scale_name]:
			var s: int = o * 12 + int(iv)
			if s <= span:
				tones.append(s)
	var lut := PackedFloat32Array()
	lut.resize(LUT_N + 1)
	for i in LUT_N + 1:
		var semis := float(i) / LUT_N * span
		if snap_on:
			var best := 0.0
			var best_d := 999.0
			for t in tones:
				var d := absf(float(t) - semis)
				if d < best_d:
					best_d = d
					best = float(t)
			semis = best
		lut[i] = 440.0 * pow(2.0, (base + semis - 69.0) / 12.0)
	return lut

func wave(kind: int, ph: float) -> float:
	if kind == 0:
		return 1.0 if ph < 0.5 else -1.0
	elif kind == 1:
		return 1.0 if ph < 0.25 else -1.0
	elif kind == 2:
		return 4.0 * absf(ph - 0.5) - 1.0
	elif kind == 3:
		return 2.0 * ph - 1.0
	return sin(TAU * ph)

# ---------- synth drums ----------

func make_drums() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	drum_buf.clear()
	drum_wav.clear()

	var hat := PackedFloat32Array()
	hat.resize(int(0.07 * RATE))
	var prev := 0.0
	for i in hat.size():
		var nz := rng.randf_range(-1.0, 1.0)
		hat[i] = (nz - prev) * exp(-float(i) / RATE * 70.0) * 0.5
		prev = nz
	drum_buf.append(hat)

	var clap := PackedFloat32Array()
	clap.resize(int(0.2 * RATE))
	for i in clap.size():
		var t := float(i) / RATE
		var env := exp(-t * 28.0)
		if t >= 0.012:
			env += 0.7 * exp(-(t - 0.012) * 28.0)
		if t >= 0.024:
			env += 0.5 * exp(-(t - 0.024) * 28.0)
		clap[i] = rng.randf_range(-1.0, 1.0) * env * 0.35
	drum_buf.append(clap)

	var snare := PackedFloat32Array()
	snare.resize(int(0.22 * RATE))
	for i in snare.size():
		var t := float(i) / RATE
		var tone := sin(TAU * 190.0 * t) * exp(-t * 28.0) * 0.5
		var nz := rng.randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.5
		snare[i] = tone + nz
	drum_buf.append(snare)

	var kick := PackedFloat32Array()
	kick.resize(int(0.3 * RATE))
	var kph := 0.0
	for i in kick.size():
		var t := float(i) / RATE
		kph += (50.0 + 140.0 * exp(-t * 28.0)) / RATE
		kick[i] = sin(TAU * kph) * exp(-t * 9.0) * 0.9
	drum_buf.append(kick)

	for b in drum_buf:
		drum_wav.append(to_wav(b))

func play_drum(lane: int) -> void:
	var p: AudioStreamPlayer = drum_pool[drum_pool_i]
	drum_pool_i = (drum_pool_i + 1) % drum_pool.size()
	p.stream = drum_wav[lane]
	p.play()

# ---------- rendering a layer into a WAV ----------

func to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.95 / peak if peak > 0.95 else 1.0
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func render_layer(l: Dictionary) -> AudioStreamWAV:
	var spb := 60.0 / bpm
	var n := int((total_beats() * spb + 0.5) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	if is_drum(l):
		for h in l.hits:
			var s0 := int(h.x * spb * RATE)
			var d: PackedFloat32Array = drum_buf[int(h.y)]
			for i in d.size():
				if s0 + i >= n:
					break
				buf[s0 + i] += d[i]
	else:
		var info: Dictionary = INSTS[l.inst]
		var lut := get_lut(l.inst)
		for s in l.strokes:
			render_stroke(buf, s, int(info.wave), lut, spb)
	return to_wav(buf)

func render_stroke(buf: PackedFloat32Array, pts_in: PackedVector2Array, kind: int, lut: PackedFloat32Array, spb: float) -> void:
	if pts_in.size() == 0:
		return
	var pts := pts_in.duplicate()
	var last := pts[pts.size() - 1]
	if last.x - pts[0].x < 0.25:
		pts.append(Vector2(pts[0].x + 0.25, last.y))
	var n_pts := pts.size()
	var s0 := int(pts[0].x * spb * RATE)
	var count := int((pts[n_pts - 1].x - pts[0].x) * spb * RATE)
	var seg := 0
	var f := lut[clampi(int(pts[0].y * LUT_N), 0, LUT_N)]
	var ph := 0.0
	for i in count:
		var o := s0 + i
		if o >= buf.size():
			break
		var tb := pts[0].x + float(i) / RATE / spb
		while seg < n_pts - 2 and pts[seg + 1].x <= tb:
			seg += 1
		var a := pts[seg]
		var b := pts[seg + 1]
		var dt := b.x - a.x
		var p := b.y
		if dt > 0.000001:
			p = lerpf(a.y, b.y, clampf((tb - a.x) / dt, 0.0, 1.0))
		var target := lut[clampi(int(p * LUT_N), 0, LUT_N)]
		f += (target - f) * 0.02
		ph += f / RATE
		ph -= floorf(ph)
		var env := minf(1.0, minf(float(i) / 110.0, float(count - i) / 220.0))
		buf[o] += wave(kind, ph) * env * 0.3

# ---------- playback ----------

func toggle_play() -> void:
	if playing:
		stop_play()
	else:
		start_play()

func start_play() -> void:
	stop_players()
	var any := false
	for i in layers.size():
		var l: Dictionary = layers[i]
		if l.mute or (l.strokes.is_empty() and l.hits.is_empty()):
			continue
		if l.dirty or l.wav == null:
			l.wav = render_layer(l)
			l.dirty = false
		players[i].stream = l.wav
		players[i].play()
		any = true
	if not any:
		return
	playing = true
	play_beat = 0.0
	play_btn.text = "Stop"

func stop_play() -> void:
	playing = false
	play_btn.text = "Play"
	stop_players()
	canvas.queue_redraw()

func stop_players() -> void:
	for p in players:
		p.stop()

func _process(delta: float) -> void:
	if live_pb:
		var n := live_pb.get_frames_available()
		var tgt := 0.25 if live_on else 0.0
		for i in n:
			live_amp += (tgt - live_amp) * 0.002
			live_f += (live_hz - live_f) * 0.01
			live_ph += live_f / RATE
			live_ph -= floorf(live_ph)
			var s := wave(live_kind, live_ph) * live_amp
			live_pb.push_frame(Vector2(s, s))
	if playing:
		play_beat += delta * bpm / 60.0
		if play_beat >= total_beats():
			if loop_on:
				start_play()
			else:
				stop_play()
		if is_visible_in_tree():
			canvas.queue_redraw()

# ---------- sending out ----------

func send(target: String) -> void:
	var out := []
	for i in layers.size():
		var l: Dictionary = layers[i]
		if l.mute or (l.strokes.is_empty() and l.hits.is_empty()):
			continue
		if l.dirty or l.wav == null:
			l.wav = render_layer(l)
			l.dirty = false
		out.append({"name": "Draw " + str(i + 1) + " " + l.inst, "wav": l.wav})
	if out.is_empty():
		return
	stop_play()
	render_ready.emit(out, target)

# ---------- drawing input ----------

func canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			begin_draw(e.position)
		else:
			end_draw()
	elif e is InputEventMouseMotion and drawing:
		move_draw(e.position)

func hit_at(pos: Vector2) -> Vector2:
	var t := floorf(x_to_beat(pos.x) / DRUM_STEP) * DRUM_STEP
	t = minf(t, total_beats() - DRUM_STEP)
	var lane := clampi(int((pos.y - RULER_H) / plot_h() * DRUM_NAMES.size()), 0, DRUM_NAMES.size() - 1)
	return Vector2(t, lane)

func paint_hit(l: Dictionary, h: Vector2) -> void:
	if paint_mode == "add" and not l.hits.has(h):
		l.hits.append(h)
		gesture_add.append(h)
		play_drum(int(h.y))
		l.dirty = true
	elif paint_mode == "del" and l.hits.has(h):
		l.hits.erase(h)
		gesture_del.append(h)
		l.dirty = true

func begin_draw(pos: Vector2) -> void:
	if pos.y < RULER_H:
		return
	var l: Dictionary = layers[sel]
	drawing = true
	last_pos = pos
	if is_drum(l):
		gesture_add = []
		gesture_del = []
		var h := hit_at(pos)
		paint_mode = "del" if l.hits.has(h) else "add"
		paint_hit(l, h)
	else:
		cur_stroke = PackedVector2Array([Vector2(x_to_beat(pos.x), y_to_pitch(pos.y))])
		live_kind = int(INSTS[l.inst].wave)
		live_hz = get_lut(l.inst)[clampi(int(cur_stroke[0].y * LUT_N), 0, LUT_N)]
		live_f = live_hz
		live_on = true
	canvas.queue_redraw()

func move_draw(pos: Vector2) -> void:
	var l: Dictionary = layers[sel]
	if is_drum(l):
		paint_hit(l, hit_at(pos))
	else:
		if pos.distance_to(last_pos) < 3.0:
			return
		last_pos = pos
		# pen can only move forward in time; dragging backwards just moves up/down
		var t := maxf(x_to_beat(pos.x), cur_stroke[cur_stroke.size() - 1].x)
		var p := y_to_pitch(pos.y)
		cur_stroke.append(Vector2(t, p))
		live_hz = get_lut(l.inst)[clampi(int(p * LUT_N), 0, LUT_N)]
	canvas.queue_redraw()

func end_draw() -> void:
	if not drawing:
		return
	drawing = false
	live_on = false
	var l: Dictionary = layers[sel]
	if is_drum(l):
		if not gesture_add.is_empty() or not gesture_del.is_empty():
			l.undo.append({"add": gesture_add, "del": gesture_del})
	elif cur_stroke.size() > 0:
		l.strokes.append(cur_stroke)
		l.undo.append({"stroke": true})
		l.dirty = true
	cur_stroke = PackedVector2Array()
	canvas.queue_redraw()

# ---------- drawing the canvas ----------

func draw_stroke(pts: PackedVector2Array, col: Color) -> void:
	if pts.is_empty():
		return
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(Vector2(beat_to_x(p.x), pitch_to_y(p.y)))
	canvas.draw_circle(arr[0], 8.0, col)
	if arr.size() > 1:
		canvas.draw_polyline(arr, col, 6.0, true)

func draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	var w := canvas.size.x
	var h := canvas.size.y
	var pc: Color = colors.pressed
	var bc: Color = colors.border
	var kc: Color = colors.black
	var wc: Color = colors.white
	var plot := plot_h()
	var total := total_beats()
	var l: Dictionary = layers[sel]
	canvas.draw_rect(Rect2(0, 0, w, h), kc)

	if is_drum(l):
		var lh := plot / DRUM_NAMES.size()
		for i in DRUM_NAMES.size():
			var y := RULER_H + i * lh
			canvas.draw_rect(Rect2(0, y, w, lh - 2), kc.lerp(wc, 0.12 if i % 2 == 0 else 0.06))
			canvas.draw_string(font, Vector2(10, y + lh / 2.0 + 8), DRUM_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(wc, 0.5))
	else:
		var info: Dictionary = INSTS[l.inst]
		var octs: int = info.octs
		var span := octs * 12
		for o in octs + 1:
			for iv in SCALES[scale_name]:
				var s: int = o * 12 + int(iv)
				if s > span:
					continue
				var y := pitch_to_y(float(s) / span)
				var is_root := int(iv) == 0
				var lc := Color(pc, 0.55) if is_root else Color(bc, 0.45)
				canvas.draw_line(Vector2(0, y), Vector2(w, y), lc, 3.0 if is_root else 1.0)

	for b in range(int(total) + 1):
		var x := beat_to_x(b)
		var is_bar := (b % 4 == 0)
		var gc := Color(bc, 0.8) if is_bar else Color(bc, 0.25)
		canvas.draw_line(Vector2(x, RULER_H), Vector2(x, h), gc, 3.0 if is_bar else 1.0)

	var ruler_bg := wc.lerp(kc, 0.5)
	var ruler_tx: Color = kc if ruler_bg.get_luminance() > 0.5 else Color.WHITE
	canvas.draw_rect(Rect2(0, 0, w, RULER_H), ruler_bg)
	for b in range(0, int(total), 4):
		canvas.draw_string(font, Vector2(beat_to_x(b) + 6, 25), str(b / 4 + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ruler_tx)

	var any := false
	for i in layers.size():
		var ly: Dictionary = layers[i]
		if not ly.strokes.is_empty() or not ly.hits.is_empty():
			any = true
		var col: Color = LAYER_COLORS[i % LAYER_COLORS.size()]
		var a := 1.0 if i == sel else 0.3
		if ly.mute:
			a *= 0.4
		col = Color(col, a)
		if is_drum(ly):
			var lh := plot / DRUM_NAMES.size()
			for hit in ly.hits:
				var hv: Vector2 = hit
				var x := beat_to_x(hv.x)
				var y := RULER_H + hv.y * lh
				canvas.draw_rect(Rect2(x + 1, y + 4, maxf(beat_to_x(DRUM_STEP) - 2, 4.0), lh - 10), col)
		else:
			for s in ly.strokes:
				draw_stroke(s, col)
	if drawing and not is_drum(l):
		draw_stroke(cur_stroke, LAYER_COLORS[sel % LAYER_COLORS.size()])

	if not any and not drawing:
		canvas.draw_string(font, Vector2(20, RULER_H + 60), "Draw left to right: up = higher note. Drums layer: tap or drag to paint hits.", HORIZONTAL_ALIGNMENT_LEFT, w - 40, 24, pc)

	if playing:
		var px := beat_to_x(play_beat)
		canvas.draw_line(Vector2(px, 0), Vector2(px, h), Color.WHITE, 4.0)

# ---------- project save / load ----------

func get_state() -> Dictionary:
	var out := []
	for l in layers:
		out.append({"inst": l.inst, "mute": l.mute, "strokes": l.strokes, "hits": l.hits})
	return {"bars": bars, "scale": scale_name, "root": root, "snap": snap_on, "layers": out}

func set_state(d: Dictionary) -> void:
	if not d.has("layers"):
		return
	stop_play()
	layers.clear()
	var b: int = int(d.get("bars", 4))
	bars = b if BAR_OPTIONS.has(b) else 4
	var sc: String = str(d.get("scale", scale_name))
	scale_name = sc if SCALES.has(sc) else "Minor pentatonic"
	root = clampi(int(d.get("root", 0)), 0, 11)
	snap_on = bool(d.get("snap", true))
	for e in d["layers"]:
		var inst: String = str(e.get("inst", "Square lead"))
		if not INSTS.has(inst):
			inst = "Square lead"
		layers.append({"inst": inst, "mute": bool(e.get("mute", false)),
			"strokes": e.get("strokes", []).duplicate(), "hits": e.get("hits", []).duplicate(),
			"undo": [], "wav": null, "dirty": true})
	if layers.is_empty():
		add_layer()
	sel = 0
	bars_btn.select(BAR_OPTIONS.find(bars))
	scale_btn.select(SCALES.keys().find(scale_name))
	key_btn.select(root)
	snap_btn.set_pressed_no_signal(snap_on)
	mark_all_dirty()
	refresh_ui()
