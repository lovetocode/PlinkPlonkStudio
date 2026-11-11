extends Control

const KEYBOARD := preload("res://scripts/keyboard.gd")
const DRUMS := preload("res://scripts/drums.gd")
const THEREMIN := preload("res://scripts/theremin.gd")

const NOTE_SEMI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const CHORDS := {
	"major": [0, 4, 7], "minor": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8],
	"sus2": [0, 2, 7], "sus4": [0, 5, 7], "7": [0, 4, 7, 10],
	"maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
}
const BLOCKS := ["bar", "loop", "track", "pattern"]
const MAX_RUN := 20000
const MAX_DEPTH := 24

const HELP := """PLONKSCRIPT QUICK REFERENCE

Indent with spaces. # starts a comment. Beats are numbers (4 = a whole bar in 4/4).

tempo 120            beats per minute (put at the top)
meter 4              beats per bar (default 4)
track NAME:          piano, piano2, drums, theremin, lyrics
bar:                 one measure; pads out to a full bar
loop 4:              repeat the indented lines
pattern NAME:        define reusable lines, then: play NAME  (or: play NAME 4)
rest 2               silence for 2 beats

PIANO / THEREMIN (notes play one after another)
instrument e_piano   any keyboard sound (chip_saw, organ, guitar, bass, 8bit_noise...)
note E4 1            pitch + beats (default 1). C4 = middle C. F#3, Bb2 work
chord C major 4      types: major minor dim aug sus2 sus4 7 maj7 min7
chord C3 minor 2     add an octave number to move it

THEREMIN
voice spooky         Classic Pure Buzzy Hollow Voice Spooky
glide A4 to E5 2     slide between pitches
vibrato 0.5          0 to 1

DRUMS (inside bar:, numbers are beat positions, 1 = start of bar)
kit rock             standard bongos electro rock disco soul psych
kick 1 3
snare 2 4
hat 1 1.5 2 2.5 3 3.5 4 4.5
Other names: open_hat tom clap click crash ride cowbell tambourine
rim_click brush snap shaker woodblock bongo_hi bongo_lo conga_hi conga_lo
echo_snare rev_cymbal finger_cymbal floor_tom 808_kick

LYRICS
say "words here" 4   shows the words, then waits 4 beats

MIXING
volume 80            per track (0 to 100)

REPL (box at the bottom)
Pick a track, type commands, separate with ;  then Enter:
  note C4 1; note E4 1; note G4 2
Keep copies what you just played into the editor.
"""

const EXAMPLE := """tempo 100

pattern groove:
    bar:
        kick 1 3
        snare 2 4
        hat 1 1.5 2 2.5 3 3.5 4 4.5

track drums:
    kit rock
    loop 4:
        play groove

track piano:
    instrument e_piano
    bar:
        chord C major 4
    bar:
        chord A minor 4
    bar:
        chord F major 4
    bar:
        chord G major 4

track theremin:
    rest 8
    bar:
        glide A4 to E5 4
    bar:
        note E5 2
        note G5 2

track lyrics:
    say "Plink plonk, here we go" 8
    say "Writing songs in code" 8
"""

var colors := {}:
	set(v):
		colors = v
		queue_redraw()

var kbs := []
var drums
var theremin

var lines := []
var events := []
var say_texts := []
var tracks := {}
var patterns := {}
var cur := {}
var bpm := 100.0
var bpb := 4.0
var kit := "Standard"
var err := ""
var guard := 0
var depth := 0
var total := 0.0

var playing := false
var play_beat := 0.0
var ev_i := 0
var say_i := 0
var glide := {}
var drum_vol := 1.0
var pool := []
var pool_i := 0

var editor: TextEdit
var help_view: TextEdit
var status: Label
var lyric_label: Label
var repl_track: OptionButton
var repl_edit: LineEdit
var history := []
var hist_i := 0
var last_repl := []
var last_track := "piano"

func _ready() -> void:
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "Rec"
		add_child(p)
		pool.append(p)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 8)
	root.add_child(bar)
	add_btn(bar, "Run", 100, start)
	add_btn(bar, "Stop", 100, stop_pressed)
	add_btn(bar, "Example", 120, load_example)
	add_btn(bar, "Help", 100, toggle_help)

	editor = TextEdit.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.placeholder_text = "Write PlonkScript here. Tap Example for a song, Help for commands."
	root.add_child(editor)

	help_view = TextEdit.new()
	help_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_view.editable = false
	help_view.text = HELP
	help_view.visible = false
	root.add_child(help_view)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)

	lyric_label = Label.new()
	lyric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lyric_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lyric_label.add_theme_font_size_override("font_size", 36)
	root.add_child(lyric_label)

	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 8)
	root.add_child(rb)
	repl_track = OptionButton.new()
	repl_track.custom_minimum_size = Vector2(140, 50)
	for t in ["piano", "piano2", "drums", "theremin"]:
		repl_track.add_item(t)
	rb.add_child(repl_track)
	repl_edit = LineEdit.new()
	repl_edit.custom_minimum_size = Vector2(0, 50)
	repl_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repl_edit.placeholder_text = "Try: note C4 1; note E4 1; note G4 2"
	repl_edit.text_submitted.connect(repl_submit)
	repl_edit.gui_input.connect(repl_key)
	rb.add_child(repl_edit)
	add_btn(rb, "Keep", 90, keep)

func add_btn(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 50)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colors.get("black", Color(0.1, 0.1, 0.1)))

func load_example() -> void:
	editor.text = EXAMPLE

func toggle_help() -> void:
	help_view.visible = not help_view.visible
	editor.visible = not help_view.visible

# ---------------- compiling ----------------

func fail(L: Dictionary, msg: String) -> void:
	if err == "":
		err = "Line %d: %s" % [L.no, msg]

func compile(src: String) -> bool:
	lines.clear()
	events.clear()
	say_texts.clear()
	tracks.clear()
	patterns.clear()
	cur = {}
	bpm = 100.0
	bpb = 4.0
	kit = "Standard"
	err = ""
	guard = 0
	depth = 0
	total = 0.0
	var n := 0
	for raw in src.split("\n"):
		n += 1
		var s: String = raw.replace("\t", "    ")
		var cm := s.find("#")
		if cm >= 0:
			var q := s.find("\"")
			if q < 0 or q > cm:
				s = s.substr(0, cm)
		if s.strip_edges() == "":
			continue
		var ind := s.length() - s.lstrip(" ").length()
		lines.append({"ind": ind, "txt": s.strip_edges(), "no": n})
	run_range(0, lines.size())
	if err != "":
		return false
	events.sort_custom(sort_events)
	for e in events:
		if e.type == "say":
			say_texts.append(e.text)
	return true

func sort_events(a: Dictionary, b: Dictionary) -> bool:
	if a.beat != b.beat:
		return a.beat < b.beat
	if a.pri != b.pri:
		return a.pri < b.pri
	return a.seq < b.seq

func run_range(a: int, b: int) -> void:
	depth += 1
	if depth > MAX_DEPTH:
		err = "Patterns are nested too deep (does a pattern play itself?)"
		depth -= 1
		return
	var i := a
	while i < b and err == "":
		var L: Dictionary = lines[i]
		var j := i + 1
		while j < b and lines[j].ind > L.ind:
			j += 1
		exec_line(L, i + 1, j)
		i = j
	depth -= 1

func add_ev(beat: float, type: String, extra := {}) -> void:
	var e := {"beat": snappedf(beat, 0.001), "type": type, "pri": 0 if type.ends_with("_off") else 1, "seq": events.size()}
	e.merge(extra)
	events.append(e)
	total = maxf(total, e.beat)

func num(L: Dictionary, w: PackedStringArray, i: int, def: float) -> float:
	if i >= w.size():
		return def
	if not w[i].is_valid_float():
		fail(L, "'%s' should be a number" % w[i])
		return def
	return float(w[i])

func need(L: Dictionary, kinds: Array) -> bool:
	if cur.is_empty():
		fail(L, "this goes inside a track:")
		return false
	if not kinds.has(cur.kind):
		fail(L, "that command doesn't work in a %s track" % cur.kind)
		return false
	return true

func parse_note(s: String, def_oct: int = 4) -> int:
	if s.length() < 1:
		return -1
	var letter := s.substr(0, 1).to_upper()
	if not NOTE_SEMI.has(letter):
		return -1
	var semi: int = NOTE_SEMI[letter]
	var k := 1
	if k < s.length() and s.substr(k, 1) == "#":
		semi += 1
		k += 1
	elif k < s.length() and s.substr(k, 1) == "b":
		semi -= 1
		k += 1
	var oct := def_oct
	if k < s.length():
		var rest := s.substr(k)
		if not rest.is_valid_int():
			return -1
		oct = int(rest)
	var m := 12 * (oct + 1) + semi
	if m < 0 or m > 127:
		return -1
	return m

func hz(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)

func norm(s: String) -> String:
	return s.to_lower().replace(" ", "_").replace("-", "_")

func resolve_drum(word: String) -> String:
	var key := norm(word)
	var names: Array = DRUMS.KITS[kit]
	for n in names:
		if norm(n) == key:
			return n
	for n in names:
		if norm(n).ends_with("_" + key):
			return n
	for k in DRUMS.KITS:
		for n in DRUMS.KITS[k]:
			if norm(n) == key:
				return n
	for k in DRUMS.KITS:
		for n in DRUMS.KITS[k]:
			if norm(n).ends_with("_" + key):
				return n
	return ""

func find_inst(word: String) -> String:
	var key := word.to_lower().replace("_", "").replace("-", "").replace(" ", "")
	for n in KEYBOARD.INSTRUMENTS:
		if n.to_lower().replace("-", "").replace(" ", "") == key:
			return n
	return ""

func find_voice(word: String) -> String:
	var key := word.to_lower()
	for n in THEREMIN.VOICES:
		if n.to_lower() == key:
			return n
	return ""

func track_kind(tn: String) -> String:
	match tn:
		"piano", "piano2":
			return "kb"
		"drums":
			return "drums"
		"theremin":
			return "theremin"
		"lyrics":
			return "lyrics"
	return ""

func exec_line(L: Dictionary, a: int, b: int) -> void:
	guard += 1
	if guard > MAX_RUN:
		fail(L, "song is too big (runaway loop?)")
		return
	var txt: String = L.txt
	var is_block := txt.ends_with(":")
	if is_block:
		txt = txt.left(txt.length() - 1).strip_edges()
	elif b > a:
		fail(L, "unexpected indent")
		return
	var w := txt.replace(",", " ").split(" ", false)
	if w.is_empty():
		fail(L, "empty command")
		return
	var cmd := w[0].to_lower()
	if is_block and not BLOCKS.has(cmd):
		fail(L, "'%s' doesn't end with a colon" % cmd)
		return
	if not is_block and BLOCKS.has(cmd):
		fail(L, "'%s' needs a colon at the end" % cmd)
		return

	match cmd:
		"tempo":
			if w.size() < 2:
				fail(L, "tempo looks like: tempo 120")
				return
			bpm = clampf(num(L, w, 1, 100.0), 20.0, 400.0)
		"meter":
			if w.size() < 2:
				fail(L, "meter looks like: meter 4")
				return
			bpb = clampf(num(L, w, 1, 4.0), 1.0, 16.0)
		"kit":
			if w.size() < 2:
				fail(L, "kit looks like: kit rock")
				return
			var found := ""
			for k in DRUMS.KIT_NAMES:
				if k.to_lower() == w[1].to_lower():
					found = k
			if found == "":
				fail(L, "unknown kit '%s'" % w[1])
				return
			kit = found
		"pattern":
			if w.size() < 2:
				fail(L, "pattern needs a name")
				return
			patterns[w[1].to_lower()] = [a, b]
		"play":
			if w.size() < 2 or not patterns.has(w[1].to_lower()):
				fail(L, "play needs a pattern defined above it")
				return
			var times := int(num(L, w, 2, 1.0))
			var r: Array = patterns[w[1].to_lower()]
			for k in clampi(times, 1, 256):
				run_range(r[0], r[1])
		"loop":
			if w.size() < 2:
				fail(L, "loop looks like: loop 4:")
				return
			var count := int(num(L, w, 1, 1.0))
			for k in clampi(count, 1, 256):
				run_range(a, b)
		"track":
			if w.size() < 2:
				fail(L, "track needs a name (piano, piano2, drums, theremin, lyrics)")
				return
			if not cur.is_empty():
				fail(L, "tracks can't be inside tracks")
				return
			var tn := w[1].to_lower()
			var kind := track_kind(tn)
			if kind == "":
				fail(L, "unknown track '%s'" % w[1])
				return
			if not tracks.has(tn):
				tracks[tn] = {"kind": kind, "cursor": 0.0, "bar_start": 0.0, "in_bar": false, "kb": 1 if tn == "piano2" else 0}
			cur = tracks[tn]
			run_range(a, b)
			cur = {}
		"bar":
			if cur.is_empty():
				fail(L, "bar goes inside a track:")
				return
			if cur.in_bar:
				fail(L, "bars can't be inside bars")
				return
			cur.cursor = ceilf(cur.cursor / bpb - 0.0001) * bpb
			cur.bar_start = cur.cursor
			cur.in_bar = true
			run_range(a, b)
			cur.in_bar = false
			var end: float = maxf(cur.cursor, cur.bar_start + bpb)
			cur.cursor = ceilf(end / bpb - 0.0001) * bpb
		"rest":
			if cur.is_empty():
				fail(L, "rest goes inside a track:")
				return
			cur.cursor += num(L, w, 1, 1.0)
		"note":
			do_note(L, w)
		"chord":
			do_chord(L, w)
		"glide":
			if not need(L, ["theremin"]):
				return
			if w.size() < 4 or w[2].to_lower() != "to":
				fail(L, "glide looks like: glide A4 to E5 2")
				return
			var m0 := parse_note(w[1])
			var m1 := parse_note(w[3])
			if m0 < 0 or m1 < 0:
				fail(L, "glide needs two notes, like A4 and E5")
				return
			var gb := num(L, w, 4, 1.0)
			if err != "" or gb <= 0.0:
				return
			var gt: float = cur.cursor
			add_ev(gt, "th_glide", {"dur": gb, "f0": hz(m0), "f1": hz(m1)})
			add_ev(gt + gb, "th_off")
			cur.cursor = gt + gb
		"vibrato":
			if not need(L, ["theremin"]):
				return
			add_ev(cur.cursor, "th_vib", {"depth": clampf(num(L, w, 1, 0.0), 0.0, 1.0)})
		"instrument":
			if not need(L, ["kb"]):
				return
			var inst := find_inst(w[1]) if w.size() > 1 else ""
			if inst == "":
				fail(L, "unknown instrument (try piano, e_piano, organ, guitar, bass, chip_saw...)")
				return
			if inst == "Sample":
				fail(L, "Sample can't be used in scripts yet")
				return
			add_ev(cur.cursor, "kb_inst", {"kb": cur.kb, "inst": inst})
		"voice":
			if not need(L, ["theremin"]):
				return
			var vn := find_voice(w[1]) if w.size() > 1 else ""
			if vn == "":
				fail(L, "voices: Classic Pure Buzzy Hollow Voice Spooky")
				return
			add_ev(cur.cursor, "th_voice", {"voice": vn})
		"volume":
			if cur.is_empty():
				fail(L, "volume goes inside a track:")
				return
			add_ev(cur.cursor, "vol", {"kind": cur.kind, "kb": cur.kb, "value": clampf(num(L, w, 1, 100.0), 0.0, 100.0)})
		"say":
			if cur.is_empty():
				fail(L, "say goes inside a track:")
				return
			var q1 := txt.find("\"")
			var q2 := txt.rfind("\"")
			if q1 < 0 or q2 <= q1:
				fail(L, "say looks like: say \"words\" 4")
				return
			var words := txt.substr(q1 + 1, q2 - q1 - 1)
			var rest := txt.substr(q2 + 1).strip_edges()
			var sb := bpb
			if rest != "":
				if not rest.is_valid_float():
					fail(L, "after the words, put the number of beats")
					return
				sb = float(rest)
			add_ev(cur.cursor, "say", {"text": words})
			cur.cursor += sb
		_:
			var real := ""
			if not cur.is_empty() and cur.kind == "drums":
				real = resolve_drum(w[0])
			if real != "":
				do_drum(L, w, real)
			else:
				fail(L, "I don't know '%s'. Tap Help for the command list." % w[0])

func do_note(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["kb", "theremin"]):
		return
	if w.size() < 2:
		fail(L, "note looks like: note E4 1")
		return
	var m := parse_note(w[1])
	if m < 0:
		fail(L, "'%s' is not a note (try C4, F#3, Bb2)" % w[1])
		return
	var beats := num(L, w, 2, 1.0)
	if err != "":
		return
	if beats <= 0.0:
		fail(L, "beats must be more than 0")
		return
	var t: float = cur.cursor
	if cur.kind == "kb":
		add_ev(t, "kb_on", {"kb": cur.kb, "note": m})
		add_ev(t + beats, "kb_off", {"kb": cur.kb, "note": m})
	else:
		add_ev(t, "th_on", {"freq": hz(m)})
		add_ev(t + beats, "th_off")
	cur.cursor = t + beats

func do_chord(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["kb"]):
		return
	if w.size() < 3:
		fail(L, "chord looks like: chord C major 4")
		return
	var root := parse_note(w[1], 4)
	if root < 0:
		fail(L, "'%s' is not a note (try C, F#3, Bb)" % w[1])
		return
	var q := w[2].to_lower()
	if not CHORDS.has(q):
		fail(L, "chord types: major minor dim aug sus2 sus4 7 maj7 min7")
		return
	var beats := num(L, w, 3, bpb)
	if err != "":
		return
	if beats <= 0.0:
		fail(L, "beats must be more than 0")
		return
	var t: float = cur.cursor
	for iv in CHORDS[q]:
		add_ev(t, "kb_on", {"kb": cur.kb, "note": root + iv})
		add_ev(t + beats, "kb_off", {"kb": cur.kb, "note": root + iv})
	cur.cursor = t + beats

func do_drum(L: Dictionary, w: PackedStringArray, real: String) -> void:
	if not cur.in_bar:
		fail(L, "drum hits go inside a bar:")
		return
	if w.size() < 2:
		fail(L, "'%s' needs beat numbers, like: %s 1 3" % [w[0], w[0]])
		return
	for i in range(1, w.size()):
		if not w[i].is_valid_float():
			fail(L, "'%s' should be a beat number" % w[i])
			return
		var pos := float(w[i])
		if pos < 1.0 or pos >= 1.0 + bpb:
			fail(L, "beat %s is outside the bar (1 to %s)" % [w[i], str(bpb)])
			return
		add_ev(cur.bar_start + pos - 1.0, "drum", {"name": real})

# ---------------- playback ----------------

func start() -> void:
	play_src(editor.text, false)

func stop_pressed() -> void:
	stop_play()
	status.text = "Stopped"

func play_src(src: String, from_repl: bool) -> void:
	stop_play()
	if not compile(src):
		status.text = err.substr(err.find(": ") + 2) if from_repl else err
		return
	if events.is_empty():
		status.text = "Nothing to play yet."
		return
	for k in kbs:
		k.set_level(1.0)
	drum_vol = 1.0
	theremin.vol_level = 0.6
	theremin.vib_depth = 0.0
	play_beat = 0.0
	ev_i = 0
	say_i = 0
	playing = true
	status.text = "Playing (%d bpm)" % int(bpm)

func stop_play() -> void:
	playing = false
	glide = {}
	for p in pool:
		p.stop()
	for k in kbs:
		k.script_off_all()
	if theremin and theremin.pitch_index == 9999:
		theremin.pitch_index = -1
	if lyric_label:
		lyric_label.text = ""

func _process(delta: float) -> void:
	if not playing:
		return
	play_beat += delta * bpm / 60.0
	while ev_i < events.size() and events[ev_i].beat <= play_beat:
		fire(events[ev_i])
		ev_i += 1
	if not glide.is_empty():
		var f: float = clampf((play_beat - glide.beat) / glide.dur, 0.0, 1.0)
		theremin.target_freq = glide.f0 * pow(glide.f1 / glide.f0, f)
	if play_beat > total + 2.0:
		stop_play()
		status.text = "Done"

func fire(e: Dictionary) -> void:
	match e.type:
		"kb_on":
			kbs[e.kb].script_on(e.note)
		"kb_off":
			kbs[e.kb].script_off(e.note)
		"kb_inst":
			kbs[e.kb].set_instrument(e.inst)
		"drum":
			play_drum(e.name)
		"th_on":
			glide = {}
			theremin.target_freq = e.freq
			theremin.pitch_index = 9999
		"th_off":
			glide = {}
			if theremin.pitch_index == 9999:
				theremin.pitch_index = -1
		"th_glide":
			glide = {"beat": e.beat, "dur": e.dur, "f0": e.f0, "f1": e.f1}
			theremin.target_freq = e.f0
			theremin.pitch_index = 9999
		"th_vib":
			theremin.vib_depth = e.depth
		"th_voice":
			theremin.set_voice(e.voice)
		"vol":
			var v: float = e.value / 100.0
			match e.kind:
				"kb":
					kbs[e.kb].set_level(v)
				"drums":
					drum_vol = v
				"theremin":
					theremin.vol_level = clampf(v * 0.6, 0.0, 1.0)
		"say":
			var shown: String = say_texts[say_i]
			if say_i + 1 < say_texts.size():
				shown += "\n\n" + say_texts[say_i + 1]
			lyric_label.text = shown
			say_i += 1

func play_drum(nm: String) -> void:
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = drums.get_sound(nm)
	p.volume_db = linear_to_db(maxf(drum_vol, 0.0001))
	p.play()

# ---------------- REPL ----------------

func editor_tempo() -> String:
	for l in editor.text.split("\n"):
		var s := l.strip_edges()
		if s.begins_with("tempo "):
			var v := s.substr(6).strip_edges()
			if v.is_valid_float():
				return v
	return "100"

func repl_submit(line: String) -> void:
	var s := line.strip_edges()
	if s == "":
		return
	history.append(s)
	hist_i = history.size()
	repl_edit.clear()
	if s.to_lower() == "help":
		if not help_view.visible:
			toggle_help()
		return
	last_repl.clear()
	var body := ""
	for c in s.split(";", false):
		var t: String = c.strip_edges()
		if t != "":
			last_repl.append(t)
			body += "        " + t + "\n"
	last_track = repl_track.get_item_text(repl_track.selected)
	var src := "tempo %s\ntrack %s:\n    bar:\n%s" % [editor_tempo(), last_track, body]
	play_src(src, true)

func repl_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_UP and history.size() > 0:
			hist_i = maxi(hist_i - 1, 0)
			repl_edit.text = history[hist_i]
			repl_edit.caret_column = repl_edit.text.length()
		elif e.keycode == KEY_DOWN and history.size() > 0:
			hist_i = mini(hist_i + 1, history.size())
			repl_edit.text = "" if hist_i >= history.size() else history[hist_i]
			repl_edit.caret_column = repl_edit.text.length()

func keep() -> void:
	if last_repl.is_empty():
		return
	var t := "\ntrack %s:\n    bar:\n" % last_track
	for c in last_repl:
		t += "        " + c + "\n"
	editor.text += t
