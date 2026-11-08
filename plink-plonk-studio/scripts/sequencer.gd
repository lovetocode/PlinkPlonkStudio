extends Control

signal render_ready(list: Array)

const ROW_H := 72.0
const LABEL_W := 200.0
const RULER_H := 36.0
const TOP_H := 120.0
const BOT_H := 64.0
const OUT_RATE := 44100
const POOL := 16
const BAR_OPTIONS := [4, 8, 16, 32]
const SNAPS := [0.25, 0.5, 1.0, 4.0]
const SNAP_NAMES := ["Snap 1/16", "Snap 1/8", "Snap 1/4", "Snap bar"]
const ZOOMS := [20.0, 40.0, 80.0, 160.0]

var colors := {"white": Color.WHITE, "black": Color.BLACK, "pressed": Color(0.4, 0.7, 1.0), "border": Color.DIM_GRAY}:
	set(value):
		colors = value
		queue_redraw()
		if grid:
			grid.queue_redraw()

var drums
var bpm := 100
var lanes := []
var bars := 8
var snap_i := 1
var zoom_i := 2
var scroll_x := 0.0
var scroll_y := 0.0
var sel_lane := -1
var sel_clip := -1
var playing := false
var cursor := 0.0
var play_beat := 0.0
var pool := []
var pool_i := 0

var grid: Control
var head: HFlowContainer
var foot: HBoxContainer
var play_btn: Button
var drum_menu: MenuButton
var snap_btn: OptionButton
var bars_btn: OptionButton
var sel_label: Label
var mute_btn: Button
var fd: FileDialog

var pressing := false
var dragging := false
var mode := ""
var press_pos := Vector2.ZERO
var start_sx := 0.0
var start_sy := 0.0
var drag_off := 0.0
var rename_dlg: ConfirmationDialog
var rename_edit: LineEdit

func _ready() -> void:
	clip_contents = true
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Monitor"
		add_child(p)
		pool.append(p)

	grid = Control.new()
	grid.clip_contents = true
	grid.draw.connect(draw_grid)
	grid.gui_input.connect(grid_input)
	add_child(grid)
	
	head = HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	head.add_theme_constant_override("v_separation", 6)
	add_child(head)
	play_btn = add_btn(head, "Play", 110, toggle_play)
	drum_menu = MenuButton.new()
	drum_menu.text = "+ Drum"
	drum_menu.custom_minimum_size = Vector2(120, 50)
	drum_menu.get_popup().about_to_popup.connect(fill_drum_menu)
	drum_menu.get_popup().id_pressed.connect(on_drum_item)
	head.add_child(drum_menu)
	add_btn(head, "+ Lane", 110, add_empty_lane)
	add_btn(head, "Load WAV", 130, func(): fd.popup_centered_ratio(0.8))
	snap_btn = OptionButton.new()
	snap_btn.custom_minimum_size = Vector2(150, 50)
	for n in SNAP_NAMES:
		snap_btn.add_item(n)
	snap_btn.select(snap_i)
	snap_btn.item_selected.connect(on_snap)
	head.add_child(snap_btn)
	bars_btn = OptionButton.new()
	bars_btn.custom_minimum_size = Vector2(120, 50)
	for b in BAR_OPTIONS:
		bars_btn.add_item(str(b) + " bars")
	bars_btn.select(BAR_OPTIONS.find(bars))
	bars_btn.item_selected.connect(on_bars)
	head.add_child(bars_btn)
	add_btn(head, "Zoom -", 100, func(): change_zoom(-1))
	add_btn(head, "Zoom +", 100, func(): change_zoom(1))
	add_btn(head, "Clear", 90, clear_all)
	add_btn(head, "Send to mixer", 180, send_to_mixer)

	foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	add_child(foot)
	sel_label = Label.new()
	sel_label.custom_minimum_size = Vector2(240, 50)
	sel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(sel_label)
	mute_btn = add_btn(foot, "Mute", 100, toggle_mute)
	mute_btn.toggle_mode = true
	add_btn(foot, "Rename", 120, start_rename)
	add_btn(foot, "Test", 90, test_sel)
	add_btn(foot, "Del clip", 120, delete_clip)
	add_btn(foot, "Del lane", 120, delete_lane)

	fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.wav ; WAV audio"])
	fd.file_selected.connect(on_file)
	add_child(fd)
	
	rename_dlg = ConfirmationDialog.new()
	rename_dlg.title = "Rename lane"
	rename_edit = LineEdit.new()
	rename_edit.custom_minimum_size = Vector2(400, 50)
	rename_edit.text_submitted.connect(on_rename_submit)
	rename_dlg.add_child(rename_edit)
	rename_dlg.confirmed.connect(on_rename)
	add_child(rename_dlg)

	resized.connect(do_layout)
	do_layout()
	add_lane("Track 1", null)

func add_btn(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func do_layout() -> void:
	head.position = Vector2(8, 6)
	head.size = Vector2(size.x - 16, TOP_H - 8)
	foot.position = Vector2(8, size.y - BOT_H + 7)
	foot.size = Vector2(size.x - 16, 50)
	grid.position = Vector2(0, TOP_H)
	grid.size = Vector2(size.x, maxf(size.y - TOP_H - BOT_H, 0.0))
	clamp_scroll()
	grid.queue_redraw()

# ---------- helpers ----------

func ppb() -> float:
	return ZOOMS[zoom_i]

func snap() -> float:
	return SNAPS[snap_i]

func total_beats() -> float:
	return bars * 4.0

func pos_to_beat(x: float) -> float:
	return (x - LABEL_W + scroll_x) / ppb()

func lane_at(y: float) -> int:
	return floori((y - RULER_H + scroll_y) / ROW_H)

# displayed/clickable width of a clip, in beats (at least one snap cell)
func lane_beats(lane: Dictionary) -> float:
	var w: AudioStreamWAV = lane.wav
	var n := 0.0
	if w:
		n = w.get_length() * bpm / 60.0
	return maxf(n, snap())

func has_lane() -> bool:
	return sel_lane >= 0 and sel_lane < lanes.size()

func on_snap(i: int) -> void:
	snap_i = i
	grid.queue_redraw()

func on_bars(i: int) -> void:
	set_bars(BAR_OPTIONS[i])

func set_bars(b: int) -> void:
	bars = b
	bars_btn.select(BAR_OPTIONS.find(b))
	cursor = minf(cursor, total_beats())
	clamp_scroll()
	grid.queue_redraw()

func change_zoom(d: int) -> void:
	var w := grid.size.x - LABEL_W
	var center := (scroll_x + w / 2.0) / ppb()
	zoom_i = clampi(zoom_i + d, 0, ZOOMS.size() - 1)
	scroll_x = center * ppb() - w / 2.0
	clamp_scroll()
	grid.queue_redraw()

func clamp_scroll() -> void:
	var max_x := maxf(total_beats() * ppb() + 60.0 - (grid.size.x - LABEL_W), 0.0)
	var max_y := maxf(lanes.size() * ROW_H - (grid.size.y - RULER_H), 0.0)
	scroll_x = clampf(scroll_x, 0.0, max_x)
	scroll_y = clampf(scroll_y, 0.0, max_y)

# ---------- lanes ----------

func add_lane(lane_name: String, wav: AudioStreamWAV) -> void:
	lanes.append({"name": lane_name, "wav": wav, "mute": false, "clips": []})
	sel_lane = lanes.size() - 1
	sel_clip = -1
	update_sel()
	clamp_scroll()
	grid.queue_redraw()


func fill_drum_menu() -> void:
	var p := drum_menu.get_popup()
	p.clear()
	if drums == null:
		return
	for i in drums.names.size():
		p.add_item(drums.names[i], i)
	p.add_separator()
	p.add_item("Whole kit", 100)

func on_drum_item(id: int) -> void:
	if id == 100:
		add_kit()
	else:
		add_drum(id)


func add_kit() -> void:
	if drums == null:
		return
	for i in drums.names.size():
		add_drum(i)
	sel_lane = lanes.size() - drums.names.size()
	update_sel()

func update_sel() -> void:
	if has_lane():
		var lane: Dictionary = lanes[sel_lane]
		sel_label.text = lane.name
		mute_btn.set_pressed_no_signal(lane.mute)
	else:
		sel_label.text = "No lane"
		mute_btn.set_pressed_no_signal(false)

func toggle_mute() -> void:
	if has_lane():
		lanes[sel_lane].mute = mute_btn.button_pressed
		grid.queue_redraw()

func test_sel() -> void:
	if has_lane():
		play_sound(lanes[sel_lane].wav)

func delete_clip() -> void:
	if not has_lane():
		return
	var clips: Array = lanes[sel_lane].clips
	if sel_clip >= 0 and sel_clip < clips.size():
		clips.remove_at(sel_clip)
	sel_clip = -1
	grid.queue_redraw()

func delete_lane() -> void:
	if not has_lane():
		return
	lanes.remove_at(sel_lane)
	sel_lane = mini(sel_lane, lanes.size() - 1)
	sel_clip = -1
	clamp_scroll()
	update_sel()
	grid.queue_redraw()

func clear_all() -> void:
	for lane in lanes:
		lane.clips.clear()
	sel_clip = -1
	grid.queue_redraw()

func play_sound(w: AudioStreamWAV) -> void:
	if w == null:
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % POOL
	p.stream = w
	p.play()

# ---------- playback (preview inside the sequencer) ----------

func toggle_play() -> void:
	if playing:
		stop_play()
	else:
		start_play()

func start_play() -> void:
	playing = true
	play_beat = cursor
	play_btn.text = "Stop"

func stop_play() -> void:
	playing = false
	play_beat = cursor
	for p in pool:
		p.stop()
	play_btn.text = "Play"
	grid.queue_redraw()

func end_play() -> void:
	playing = false
	play_beat = cursor
	play_btn.text = "Play"
	grid.queue_redraw()

func _process(delta: float) -> void:
	if not playing:
		return
	var prev := play_beat
	play_beat += delta * bpm / 60.0
	for lane in lanes:
		if lane.mute:
			continue
		for c in lane.clips:
			if c.start >= prev and c.start < play_beat:
				play_sound(lane.wav)
	if play_beat >= total_beats():
		end_play()
		return
	var x := LABEL_W + play_beat * ppb() - scroll_x
	if x > grid.size.x - 30.0 or x < LABEL_W:
		scroll_x = play_beat * ppb() - 80.0
		clamp_scroll()
	if is_visible_in_tree():
		grid.queue_redraw()

# ---------- render lanes into WAVs for the mixer ----------

func send_to_mixer() -> void:
	var spb := 60.0 / bpm
	var song_len := 0.0
	for lane in lanes:
		if lane.mute or lane.wav == null:
			continue
		var w: AudioStreamWAV = lane.wav
		for c in lane.clips:
			if c.start < total_beats():
				song_len = maxf(song_len, c.start * spb + w.get_length())
	if song_len <= 0.0:
		return
	var out := []
	for lane in lanes:
		if lane.mute or lane.wav == null or lane.clips.is_empty():
			continue
		var wav := render_lane(lane, song_len)
		if wav:
			out.append({"name": "Seq " + lane.name, "wav": wav})
	if out.is_empty():
		return
	stop_play()
	render_ready.emit(out)

func render_lane(lane: Dictionary, song_len: float) -> AudioStreamWAV:
	var src: AudioStreamWAV = lane.wav
	if src.format != AudioStreamWAV.FORMAT_16_BITS:
		push_error("Only 16-bit sounds can be rendered: " + lane.name)
		return null
	var chans := 2 if src.stereo else 1
	var sd := src.data
	var frames := sd.size() / (2 * chans)
	var ratio := float(src.mix_rate) / OUT_RATE
	var out_frames := int(frames / ratio)
	var mono := PackedFloat32Array()
	mono.resize(out_frames)
	for i in out_frames:
		var si := int(i * ratio)
		var v := sd.decode_s16(si * chans * 2) / 32768.0
		if chans == 2:
			v = (v + sd.decode_s16((si * chans + 1) * 2) / 32768.0) * 0.5
		mono[i] = v
	var n := int(song_len * OUT_RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var spb := 60.0 / bpm
	for c in lane.clips:
		if c.start >= total_beats():
			continue
		var start := int(c.start * spb * OUT_RATE)
		for i in out_frames:
			var o := start + i
			if o >= n:
				break
			buf[o] += mono[i]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = OUT_RATE
	w.stereo = false
	w.data = data
	return w

# ---------- drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.black)

func draw_grid() -> void:
	var font := ThemeDB.fallback_font
	var pc: Color = colors.pressed
	var bc: Color = colors.border
	var wc: Color = colors.white
	var kc: Color = colors.black
	var gw := grid.size.x
	var gh := grid.size.y
	var p := ppb()
	var total := total_beats()
	grid.draw_rect(Rect2(0, 0, gw, gh), kc)
	if lanes.is_empty():
		var hint: Color = pc if kc.get_luminance() < 0.5 else wc
		grid.draw_string(font, Vector2(20, 90), "Tap + Drum or Load WAV, then tap a lane to place clips.", HORIZONTAL_ALIGNMENT_LEFT, gw - 40, 24, hint)

	var first_beat := maxf(floorf(scroll_x / p), 0.0)
	var last_beat := minf(ceilf((scroll_x + gw - LABEL_W) / p), total)
	var lanes_bottom := minf(gh, RULER_H + lanes.size() * ROW_H - scroll_y)

	# lane backgrounds
	for r in lanes.size():
		var y := RULER_H + r * ROW_H - scroll_y
		if y > gh or y + ROW_H < RULER_H:
			continue
		var bg: Color = wc.lerp(kc, 0.8 if r % 2 == 0 else 0.7)
		if r == sel_lane:
			bg = bg.lerp(pc, 0.15)
		grid.draw_rect(Rect2(LABEL_W, y, gw - LABEL_W, ROW_H - 2), bg)

	# grid lines
	var step := minf(snap(), 1.0)
	if step * p < 8.0:
		step = 1.0
	var k := int(first_beat / step)
	while k * step <= last_beat:
		var b := k * step
		var lx := LABEL_W + b * p - scroll_x
		var lc: Color
		var lw := 1.0
		if fmod(b, 4.0) < 0.001:
			lc = Color(bc, 0.95)
			lw = 3.0
		elif fmod(b, 1.0) < 0.001:
			lc = Color(bc, 0.6)
			lw = 2.0
		else:
			lc = Color(bc, 0.25)
		grid.draw_line(Vector2(lx, RULER_H), Vector2(lx, lanes_bottom), lc, lw)
		k += 1

	# clips
	for r in lanes.size():
		var y := RULER_H + r * ROW_H - scroll_y
		if y > gh or y + ROW_H < RULER_H:
			continue
		var lane: Dictionary = lanes[r]
		var cw: float = lane_beats(lane) * p
		var clips: Array = lane.clips
		for i in clips.size():
			var cs: float = clips[i].start
			var x: float = LABEL_W + cs * p - scroll_x
			if x + cw < LABEL_W or x > gw:
				continue
			var rect := Rect2(x + 1, y + 5, maxf(cw - 2, 4.0), ROW_H - 12)
			var col: Color = pc
			if lane.mute:
				col = col.lerp(kc, 0.6)
			grid.draw_rect(rect, col)
			var is_sel := (r == sel_lane and i == sel_clip)
			var edge: Color = bc
			var edge_w := 2.0
			if is_sel:
				edge = Color.WHITE
				edge_w = 4.0
			grid.draw_rect(rect, edge, false, edge_w)
			if cw > 50.0:
				var tc: Color = kc if col.get_luminance() > 0.5 else Color.WHITE
				grid.draw_string(font, Vector2(x + 8, y + ROW_H / 2.0 + 7), lane.name, HORIZONTAL_ALIGNMENT_LEFT, cw - 12, 20, tc)

	# dim everything after the end of the song
	var end_x := LABEL_W + total * p - scroll_x
	if end_x < gw:
		var sx := maxf(end_x, LABEL_W)
		grid.draw_rect(Rect2(sx, RULER_H, gw - sx, gh - RULER_H), Color(kc, 0.6))

	# lane labels
	grid.draw_rect(Rect2(0, RULER_H, LABEL_W, gh - RULER_H), kc)
	for r in lanes.size():
		var y := RULER_H + r * ROW_H - scroll_y
		if y > gh or y + ROW_H < RULER_H:
			continue
		var lane: Dictionary = lanes[r]
		var lab: Color = pc if r == sel_lane else wc
		if lane.mute:
			lab = lab.lerp(kc, 0.6)
		var lab_rect := Rect2(4, y + 4, LABEL_W - 8, ROW_H - 10)
		grid.draw_rect(lab_rect, lab)
		grid.draw_rect(lab_rect, bc, false, 2.0)
		var ltc: Color = kc if lab.get_luminance() > 0.5 else Color.WHITE
		grid.draw_string(font, Vector2(14, y + ROW_H / 2.0 + 8), lane.name, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 24, 24, ltc)

	# ruler
	var ruler_bg: Color = wc.lerp(kc, 0.45)
	var ruler_tx: Color = kc if ruler_bg.get_luminance() > 0.5 else Color.WHITE
	grid.draw_rect(Rect2(LABEL_W, 0, gw - LABEL_W, RULER_H), ruler_bg)
	var bb := (int(first_beat) / 4) * 4
	while bb <= last_beat:
		var rx := LABEL_W + bb * p - scroll_x
		grid.draw_line(Vector2(rx, 0), Vector2(rx, RULER_H), ruler_tx, 2.0)
		grid.draw_string(font, Vector2(rx + 6, 26), str(bb / 4 + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ruler_tx)
		bb += 4
	grid.draw_rect(Rect2(0, 0, LABEL_W, RULER_H), kc)
	var corner: Color = pc if kc.get_luminance() < 0.5 else wc
	grid.draw_string(font, Vector2(12, 26), "Bar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, corner)

	# start marker + playhead
	var cx := LABEL_W + cursor * p - scroll_x
	if cx >= LABEL_W and cx <= gw:
		grid.draw_line(Vector2(cx, 0), Vector2(cx, gh), Color(pc, 0.8), 2.0)
	if playing:
		var px := LABEL_W + play_beat * p - scroll_x
		if px >= LABEL_W and px <= gw:
			grid.draw_line(Vector2(px, 0), Vector2(px, gh), Color.WHITE, 4.0)

# ---------- input ----------

func grid_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			begin_press(e.position)
		else:
			end_press(e.position)
	elif e is InputEventMouseMotion and pressing:
		move_press(e.position)

func hit_clip(pos: Vector2) -> Vector2i:
	var r := lane_at(pos.y)
	if r < 0 or r >= lanes.size():
		return Vector2i(-1, -1)
	var b := pos_to_beat(pos.x)
	var lane: Dictionary = lanes[r]
	var w := lane_beats(lane)
	var clips: Array = lane.clips
	for i in range(clips.size() - 1, -1, -1):
		var cs: float = clips[i].start
		if b >= cs and b < cs + w:
			return Vector2i(r, i)
	return Vector2i(-1, -1)

func begin_press(pos: Vector2) -> void:
	pressing = true
	dragging = false
	press_pos = pos
	start_sx = scroll_x
	start_sy = scroll_y
	mode = ""
	if pos.y < RULER_H:
		mode = "ruler"
	elif pos.x < LABEL_W:
		mode = "label"
	else:
		var hit := hit_clip(pos)
		if hit.x >= 0:
			mode = "clip"
			sel_lane = hit.x
			sel_clip = hit.y
			var cs: float = lanes[hit.x].clips[hit.y].start
			drag_off = pos_to_beat(pos.x) - cs
			update_sel()
			grid.queue_redraw()
		else:
			mode = "scroll"

func move_press(pos: Vector2) -> void:
	if not dragging and pos.distance_to(press_pos) > 20.0:
		dragging = true
	if not dragging:
		return
	if mode == "clip":
		var clips: Array = lanes[sel_lane].clips
		var edge := snappedf(pos_to_beat(pos.x) - drag_off, snap())
		clips[sel_clip].start = clampf(edge, 0.0, total_beats() - snap())
	else:
		if mode != "label":
			scroll_x = start_sx - (pos.x - press_pos.x)
		if mode != "ruler":
			scroll_y = start_sy - (pos.y - press_pos.y)
		clamp_scroll()
	grid.queue_redraw()

func end_press(pos: Vector2) -> void:
	if pressing and not dragging:
		if mode == "ruler":
			cursor = clampf(snappedf(pos_to_beat(pos.x), snap()), 0.0, total_beats())
			play_beat = cursor
		elif mode == "label":
			var r := lane_at(pos.y)
			if r >= 0 and r < lanes.size():
				sel_lane = r
				sel_clip = -1
				update_sel()
		elif mode == "scroll":
			place_clip(pos)
	pressing = false
	mode = ""
	grid.queue_redraw()

func place_clip(pos: Vector2) -> void:
	var r := lane_at(pos.y)
	if r < 0 or r >= lanes.size():
		return
	var s := snap()
	var start := floorf(pos_to_beat(pos.x) / s) * s
	if start < 0.0 or start >= total_beats():
		return
	var lane: Dictionary = lanes[r]
	if lane.wav == null:
		return
	lane.clips.append({"start": start})
	sel_lane = r
	sel_clip = lane.clips.size() - 1
	play_sound(lane.wav)
	update_sel()

# ---------- project save/load ----------

func get_state() -> Dictionary:
	var out := []
	for lane in lanes:
		var starts := []
		for c in lane.clips:
			starts.append(c.start)
		out.append({"name": lane.name, "mute": lane.mute, "clips": starts, "wav": pack_wav(lane.wav)})
	return {"bars": bars, "lanes": out}

func set_state(d: Dictionary) -> void:
	if not d.has("lanes"):
		return
	lanes.clear()
	for e in d["lanes"]:
		var w := unpack_wav(e.get("wav", {}))
		if w == null:
			continue
		add_lane(e.get("name", "Lane"), w)
		var lane: Dictionary = lanes[lanes.size() - 1]
		lane.mute = bool(e.get("mute", false))
		for s in e.get("clips", []):
			lane.clips.append({"start": float(s)})
	var b: int = d.get("bars", 8)
	set_bars(b if BAR_OPTIONS.has(b) else 8)
	sel_lane = 0 if lanes.size() > 0 else -1
	sel_clip = -1
	scroll_x = 0.0
	scroll_y = 0.0
	cursor = 0.0
	play_beat = 0.0
	if lanes.is_empty():
		add_lane("Track 1", null)
	update_sel()
	grid.queue_redraw()

func pack_wav(w: AudioStreamWAV) -> Dictionary:
	if w == null:
		return {}
	return {"format": w.format, "mix_rate": w.mix_rate, "stereo": w.stereo, "data": w.data}

func unpack_wav(d: Dictionary) -> AudioStreamWAV:
	if d.is_empty():
		return null
	var w := AudioStreamWAV.new()
	w.format = d.format
	w.mix_rate = d.mix_rate
	w.stereo = d.stereo
	w.data = d.data
	return w
	
func on_file(path: String) -> void:
	var wav := AudioStreamWAV.load_from_file(path)
	if wav == null:
		push_error("Couldn't load " + path)
		return
	put_sound(path.get_file().get_basename(), wav)

func add_drum(i: int) -> void:
	put_sound(drums.names[i], drums.players[i].stream)

# fills the selected lane if it's empty, otherwise makes a new lane
func put_sound(lane_name: String, wav: AudioStreamWAV) -> void:
	if has_lane() and lanes[sel_lane].wav == null:
		var lane: Dictionary = lanes[sel_lane]
		lane.wav = wav
		if str(lane.name).begins_with("Track "):
			lane.name = lane_name
		update_sel()
		grid.queue_redraw()
	else:
		add_lane(lane_name, wav)

func add_empty_lane() -> void:
	add_lane("Track " + str(lanes.size() + 1), null)

func start_rename() -> void:
	if not has_lane():
		return
	rename_edit.text = lanes[sel_lane].name
	rename_dlg.popup_centered(Vector2i(500, 160))
	rename_edit.grab_focus()
	rename_edit.select_all()

func on_rename_submit(_t: String) -> void:
	on_rename()
	rename_dlg.hide()

func on_rename() -> void:
	if not has_lane():
		return
	var n := rename_edit.text.strip_edges()
	if n != "":
		lanes[sel_lane].name = n
	update_sel()
	grid.queue_redraw()
