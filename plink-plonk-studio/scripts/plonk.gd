extends Control

const KEYBOARD := preload("res://scripts/keyboard.gd")
const DRUMS := preload("res://scripts/drums.gd")
const THEREMIN := preload("res://scripts/theremin.gd")

const NOTE_SEMI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const CHORDS := {
	"major": [0, 4, 7], "minor": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8],
	"sus2": [0, 2, 7], "sus4": [0, 5, 7], "7": [0, 4, 7, 10],
	"maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
	"6": [0, 4, 7, 9], "min6": [0, 3, 7, 9], "add9": [0, 4, 7, 14],
	"9": [0, 4, 7, 10, 14], "power": [0, 7],
}
const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
	"pentatonic": [0, 2, 4, 7, 9],
	"minor_pentatonic": [0, 3, 5, 7, 10],
	"blues": [0, 3, 5, 6, 7, 10],
}
const ARP_DIRS := ["up", "down", "updown", "random"]
const BLOCKS := ["bar", "measure", "loop", "track", "pattern", "every", "except"]
const BOTH := ["transpose"]
const NOSUB := ["let", "pattern", "track", "play", "loop", "include"]
const KINDS := ["keys", "drums", "theremin", "lyrics"]
const STATE_EVENTS := ["kb_inst", "th_voice", "vol", "tempo", "th_vib", "fx"]
const FX_SLOT := {"reverb": 1, "delay": 2, "distortion": 3, "lowpass": 4, "highpass": 5, "chorus": 6}
const FX_DEFAULT := {"reverb": 0.4, "delay": 0.5, "distortion": 0.4, "lowpass": 1200.0, "highpass": 800.0, "chorus": 1.0, "pan": 0.0}
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const HIT_CHARS := "xXo.-|_"
const MAX_RUN := 20000
const MAX_DEPTH := 24
const TPQ := 480
const TAIL_SEC := 1.5
const KEYWORDS := ["tempo", "meter", "track", "pattern", "play", "loop", "every", "except", "bar", "measure",
	"rest", "volume", "velocity", "vel", "instrument", "octave", "note", "chord", "arp", "progression", "deg",
	"key", "let", "include", "swing", "humanize", "transpose", "kit", "voice", "glide", "vibrato", "say", "as", "to", "sample", "pitch", "reverb", "delay", "distortion", "lowpass", "highpass", "chorus", "pan"] 
const GM_DRUMS := {
	"Kick": 36, "808 Kick": 36, "Rock Kick": 36, "Disco Kick": 36, "Soft Kick": 36, "Psych Kick": 36,
	"Snare": 38, "Rock Snare": 38, "Disco Snare": 38, "Echo Snare": 38, "Rim Click": 37, "Snap": 37,
	"Clap": 39, "Hat": 42, "Open Hat": 46, "Tom": 45, "808 Tom": 45, "Rock Tom": 45, "Floor Tom": 41,
	"Crash": 49, "Ride": 51, "Cowbell": 56, "Tambourine": 54, "Woodblock": 76, "Shaker": 70,
	"Bongo Hi": 60, "Bongo Lo": 61, "Conga Hi": 63, "Conga Lo": 64, "Click": 75, "Brush": 38,
	"Rev Cymbal": 49, "Finger Cymbal": 53, "Slap": 37,
}

const HELP := """PLONKSCRIPT QUICK REFERENCE

Indent with spaces. # starts a comment. Beats are numbers (4 = a whole measure in 4/4).

GLOBAL
tempo 120            beats per minute (top of song)
meter 4              beats per measure
key C minor          key + scale: major minor dorian phrygian lydian
                     mixolydian harmonic_minor pentatonic minor_pentatonic blues
swing 0.3            0 to 1, pushes off-beat 8ths late
humanize 0.02        small random timing/volume wobble (same every run)
let root = C3        variable, use it anywhere:  note root 2
include groove       pastes in groove.plonk (looked for next to the last
                     script you saved or loaded)

STRUCTURE
track NAME KIND:     KIND is keys, drums, theremin or lyrics
                     (names piano, keys, drums, theremin, lyrics need no kind)
measure 3:           jump to measure 3 and write its notes inside
bar:                 the next measure (use inside loops and patterns)
loop 4:              repeat the indented lines
loop 4 as n:         same, and n = 1, 2, 3, 4 on each pass
every 4:             inside a loop: only on passes 4, 8, 12...
except 4:            inside a loop: on every pass EXCEPT 4, 8, 12...
pattern NAME:        define reusable lines, then: play NAME  (or: play NAME 4)
rest 2               silence for 2 beats
volume 80            per track (0 to 100)
velocity 80          default note loudness for the track (0 to 100)
transpose 2          shift pitch in semitones (also: transpose 2:  with a block)
tempo 140            inside a track: change tempo from here
tempo 100 to 140 8   inside a track: ramp the tempo over 8 beats

KEYS AND THEREMIN
instrument glass_harmonica   piano e_piano organ harpsichord xylophone
   glass_harmonica guitar bass saw chip_saw pulse_12 pulse_25 triangle
   8bit_noise 8bit_metal vrc6_saw curtis_wah curtis_clean square
octave 5             default octave for notes written without a number
note E4 1            pitch + beats. Add  vel 80  for loudness
deg 3 1              note by scale degree of the key (8 = octave up, -1 = below,
                     3b = flattened). Add vel 80
chord C major 4      major minor dim aug sus2 sus4 7 maj7 min7 6 min6 add9 9 power
arp C major 4 up 0.5 notes one by one: ROOT TYPE BEATS DIRECTION STEP OCTAVES
                     direction: up down updown random.  arp C minor 4 updown 0.25 2
progression I V vi IV 4        chords by roman numeral in the key, 4 beats each
progression I V vi IV 4 arp up 0.25   same, arpeggiated
                     (upper = major, lower = minor, V7, vii dim = viio, bVII ok)

THEREMIN
voice spooky         classic pure buzzy hollow voice spooky
glide A4 to E5 2     slide between pitches
vibrato 0.5          0 to 1

DRUMS (inside a measure)
kit disco            standard bongos electro rock disco soul psych
kick 1 3             beat positions (1 = start of the measure)
hat x.x.x.x.         or a step string. x = hit, X = accent, o = ghost, . = rest
                     steps spread evenly over the measure (16 chars = 16ths)
snare 2 4 vel 90     vel works here too
Names: kick snare hat open_hat tom clap click crash ride cowbell tambourine
rim_click brush snap shaker woodblock bongo_hi bongo_lo conga_hi conga_lo
echo_snare rev_cymbal finger_cymbal floor_tom 808_kick

EFFECTS (inside a track, they apply from that point on)
reverb 0.4   delay 0.5 (in beats)   distortion 0.4   lowpass 1200
highpass 800   chorus 1   pan -0.5      add  off  to switch one off.
Change them mid-song for sweeps:  lowpass 300 ... later ... lowpass 4000

SAMPLES (in a drums track, inside a bar)
sample take_1 1 3                 plays a sound by name at those beats
sample sound_2 1 2 3 4 pitch 5 vel 80
   Names come from the mixer (Take 1 = take_1), "keyboard", or a
   file like kick.wav saved next to your script.

KEYS TO SCRIPT
File > "Keys to script: start", play the piano, then File > STOP.
Your notes land in the editor as tracks, snapped to 16ths.

LYRICS
say "words here" 4   shows the words, then waits 4 beats

TOP BUTTONS
Run plays from the Bar number next to it. Save/Load keep scripts as .plonk files.
WAV records the song to a WAV, MP4 makes a waveform video, MIDI writes a .mid file.

REPL (box at the bottom)
Pick keys, drums or theremin, type commands separated by ;  then Enter:
  instrument organ; note C4 1; note E4 1; note G4 2
Keep copies what you just played into the editor.
"""

const EXAMPLE := """tempo 100
key C major
swing 0.15
let lead_oct = 5

pattern groove:
    bar:
        kick  x...x...x...x...
        snare ....x.......x...
        hat   x.x.x.x.x.x.x.x.

pattern fill:
    bar:
        kick  x...x...x...x.x.
        snare x.x.x.x.xxxxxxxx

track beat drums:
    kit disco
    loop 4:
        except 4:
            play groove
        every 4:
            play fill

track chords keys:
    instrument e_piano
    octave 4
    volume 70
    progression I vi IV V 4

track arp keys:
    instrument pulse_25
    octave 3
    volume 40
    progression I vi IV V 4 arp updown 0.25

track lead keys:
    instrument glass_harmonica
    octave lead_oct
    measure 1:
        deg 3 2
        deg 5 2
    measure 2:
        deg 6 2
        deg 3 2
    measure 3:
        deg 4 2
        deg 6 2
    measure 4:
        deg 5 4 vel 90

track ghost theremin:
    voice spooky
    measure 4:
        glide G4 to G5 4

track words lyrics:
	say "Plink plonk, here we go" 8
	say "Writing songs in code" 8
"""

var colors := {}:
	set(v):
		colors = v
		queue_redraw()

var kbs := []        # not used any more, kept so main.gd still works
var drums
var theremin         # not used any more, kept so main.gd still works
var exporter         # set by main.gd

var mixer            # set by main.gd
var sample_map := {}
var file_samples := {}
var cur_pitch := 0.0
var recording := false
var rec_notes := []
var rec_open := {}
var rec_t0 := -1.0

var lines := []
var events := []
var say_texts := []
var tracks := {}
var patterns := {}
var vars := {}
var cur := {}
var bpm := 100.0
var play_bpm := 100.0
var bpb := 4.0
var kit := "Standard"
var key_root := 0
var scale_name := "major"
var swing := 0.0
var humanize := 0.0
var loop_idx := 1
var rng := RandomNumberGenerator.new()
var err := ""
var err_line := 0
var marked_line := -1
var guard := 0
var depth := 0
var nest := 0
var total := 0.0

var synths := {}
var synth_kinds := {}
var glides := {}
var drum_vols := {}

var playing := false
var play_beat := 0.0
var ev_i := 0
var say_i := 0
var pool := []
var pool_i := 0

var exporting := false
var export_wav_path := ""
var export_mp4_path := ""
var rec_fx: AudioEffectRecord

var script_dir := ""
var fd: FileDialog
var fd_kind := ""

var editor: CodeEdit
var help_view: TextEdit
var status: Label
var lyric_label: Label
var from_box: SpinBox
var repl_track: OptionButton
var repl_edit: LineEdit
var history := []
var hist_i := 0
var last_repl := []
var last_track := "keys"

func _ready() -> void:
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "Rec"
		add_child(p)
		pool.append(p)

	var rec_bus := AudioServer.get_bus_index("Rec")
	if rec_bus >= 0:
		rec_fx = AudioEffectRecord.new()
		AudioServer.add_bus_effect(rec_bus, rec_fx)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 8)
	root.add_child(bar)
	add_btn(bar, "Run", 90, start)
	add_btn(bar, "Stop", 90, stop_pressed)
	from_box = SpinBox.new()
	from_box.min_value = 1
	from_box.max_value = 999
	from_box.value = 1
	from_box.prefix = "From bar "
	from_box.custom_minimum_size = Vector2(190, 50)
	bar.add_child(from_box)
	add_btn(bar, "Example", 110, load_example)
	add_btn(bar, "Help", 80, toggle_help)
	add_btn(bar, "Save", 80, func(): pick_script(true))
	add_btn(bar, "Load", 80, func(): pick_script(false))
	add_btn(bar, "WAV", 80, func(): pick_export("wav"))
	add_btn(bar, "MP4", 80, func(): pick_export("mp4"))
	add_btn(bar, "MIDI", 90, func(): pick_export("mid"))

	editor = CodeEdit.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.placeholder_text = "Write PlonkScript here. Tap Example for a song, Help for commands."
	editor.gutters_draw_line_numbers = true
	editor.highlight_current_line = true
	editor.indent_automatic = true
	editor.indent_use_spaces = true
	editor.indent_size = 4
	editor.add_theme_color_override("line_number_color", Color(0.65, 0.65, 0.7))
	editor.text_changed.connect(clear_marks)
	var hl := CodeHighlighter.new()
	hl.number_color = Color(1.0, 0.8, 0.4)
	for kw in KEYWORDS:
		hl.add_keyword_color(kw, Color(0.5, 0.8, 1.0))
	hl.add_color_region("#", "", Color(0.55, 0.55, 0.6), true)
	hl.add_color_region("\"", "\"", Color(0.6, 1.0, 0.6))
	editor.syntax_highlighter = hl
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
	for t in ["keys", "drums", "theremin"]:
		repl_track.add_item(t)
	rb.add_child(repl_track)
	repl_edit = LineEdit.new()
	repl_edit.custom_minimum_size = Vector2(0, 50)
	repl_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repl_edit.placeholder_text = "Try: instrument organ; note C4 1; note E4 1"
	repl_edit.text_submitted.connect(repl_submit)
	repl_edit.gui_input.connect(repl_key)
	rb.add_child(repl_edit)
	add_btn(rb, "Keep", 90, keep)

	fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.file_selected.connect(on_fd_pick)
	add_child(fd)

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
	clear_marks()

func toggle_help() -> void:
	help_view.visible = not help_view.visible
	editor.visible = not help_view.visible

# ---------------- error marks ----------------

func mark_line(n: int) -> void:
	if help_view.visible:
		toggle_help()
	var i := clampi(n - 1, 0, editor.get_line_count() - 1)
	editor.set_line_background_color(i, Color(0.75, 0.1, 0.1, 0.55))
	marked_line = i
	editor.set_caret_line(i)
	editor.center_viewport_to_caret()

func clear_marks() -> void:
	if marked_line < 0:
		return
	for i in editor.get_line_count():
		editor.set_line_background_color(i, Color(0, 0, 0, 0))
	marked_line = -1

func show_error(from_repl: bool) -> void:
	status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	status.text = err.substr(err.find(": ") + 2) if from_repl else err
	if not from_repl and err_line > 0:
		mark_line(err_line)

func show_status(msg: String) -> void:
	status.remove_theme_color_override("font_color")
	status.text = msg

# ---------------- script files ----------------

func pick_script(save: bool) -> void:
	fd_kind = "script_save" if save else "script_load"
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = PackedStringArray(["*.plonk ; PlonkScript"])
	if script_dir != "":
		fd.current_dir = script_dir
	if save:
		fd.current_file = "song.plonk"
	fd.popup_centered_ratio(0.8)

func pick_export(kind: String) -> void:
	fd_kind = "export_" + kind
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	match kind:
		"wav":
			fd.filters = PackedStringArray(["*.wav ; WAV audio"])
			fd.current_file = "song.wav"
		"mp4":
			fd.filters = PackedStringArray(["*.mp4 ; MP4 video"])
			fd.current_file = "song.mp4"
		_:
			fd.filters = PackedStringArray(["*.mid ; MIDI file"])
			fd.current_file = "song.mid"
	if script_dir != "":
		fd.current_dir = script_dir
	fd.popup_centered_ratio(0.8)

func on_fd_pick(path: String) -> void:
	match fd_kind:
		"script_save":
			if not path.ends_with(".plonk"):
				path += ".plonk"
			script_dir = path.get_base_dir()
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				show_status("Couldn't save " + path)
				return
			f.store_string(editor.text)
			f.close()
			show_status("Saved " + path)
		"script_load":
			script_dir = path.get_base_dir()
			editor.text = FileAccess.get_file_as_string(path)
			clear_marks()
			show_status("Loaded " + path.get_file())
		"export_wav":
			if not path.to_lower().ends_with(".wav"):
				path += ".wav"
			start_export(path, "")
		"export_mp4":
			if exporter == null:
				show_status("MP4 export isn't hooked up (see main.gd changes).")
				return
			if not path.to_lower().ends_with(".mp4"):
				path += ".mp4"
			start_export(path.get_basename() + ".wav", path)
		"export_mid":
			export_midi(path)

func load_script_text(sname: String) -> String:
	var fname := sname if sname.ends_with(".plonk") else sname + ".plonk"
	for dir in [script_dir, "user://plonk"]:
		if dir == "":
			continue
		var p: String = dir.path_join(fname)
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return ""

# ---------------- synth instances (one hidden synth per track) ----------------

func get_synth(tn: String, kind: String) -> Control:
	if synths.has(tn):
		if synth_kinds[tn] == kind:
			return synths[tn]
		synths[tn].queue_free()
	var s: Control
	if kind == "keys":
		s = KEYBOARD.new()
	else:
		s = THEREMIN.new()
	s.visible = false
	add_child(s)
	synths[tn] = s
	synth_kinds[tn] = kind
	if kind == "keys":
		s.set_instrument("Piano")
	return s

# ---------------- compiling ----------------

func fail(L: Dictionary, msg: String) -> void:
	if err == "":
		var f: String = L.get("file", "")
		err_line = int(L.get("outer", L.no))
		err = "Line %d%s: %s" % [L.no, (" (in " + f + ")") if f != "" else "", msg]

func compile(src: String) -> bool:
	lines.clear()
	events.clear()
	say_texts.clear()
	tracks.clear()
	patterns.clear()
	vars.clear()
	sample_map.clear()
	cur = {}
	bpm = 100.0
	bpb = 4.0
	kit = "Standard"
	key_root = 0
	scale_name = "major"
	swing = 0.0
	humanize = 0.0
	loop_idx = 1
	rng.seed = 1
	err = ""
	err_line = 0
	guard = 0
	depth = 0
	nest = 0
	total = 0.0
	read_lines(src, 0, "", 0, 0)
	if err != "":
		return false
	run_range(0, lines.size())
	if err != "":
		return false
	events.sort_custom(sort_events)
	for e in events:
		if e.type == "say":
			say_texts.append(e.text)
	return true

func read_lines(src: String, level: int, file: String, outer_no: int, base: int) -> void:
	var n := 0
	for raw in src.split("\n"):
		n += 1
		var s: String = raw.replace("\t", "    ")
		var cm := -1
		var in_q := false
		for k in s.length():
			var ch := s.substr(k, 1)
			if ch == "\"":
				in_q = not in_q
			elif ch == "#" and not in_q:
				cm = k
				break
		if cm >= 0:
			s = s.substr(0, cm)
		if s.strip_edges() == "":
			continue
		var ind := s.length() - s.lstrip(" ").length() + base
		var t := s.strip_edges()
		var info := {"no": n, "file": file, "outer": n if level == 0 else outer_no}
		if t.begins_with("include "):
			var iname := t.substr(8).strip_edges().trim_prefix("\"").trim_suffix("\"")
			if level >= 6:
				fail(info, "includes are nested too deep")
				return
			var txt := load_script_text(iname)
			if txt == "":
				fail(info, "can't find script '%s' (save it as %s.plonk next to this script)" % [iname, iname])
				return
			read_lines(txt, level + 1, iname, info.outer, ind)
			if err != "":
				return
			continue
		lines.append({"ind": ind, "txt": t, "no": n, "file": file, "outer": info.outer})

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

func beats_at(L: Dictionary, w: PackedStringArray, i: int, def: float) -> float:
	if i >= w.size() or w[i] == "vel":
		return def
	return num(L, w, i, def)

func opt_vel(L: Dictionary, w: PackedStringArray) -> float:
	var i := w.find("vel")
	if i < 0:
		return cur.vel
	if i + 1 >= w.size() or not w[i + 1].is_valid_float():
		fail(L, "vel needs a number from 0 to 100")
		return cur.vel
	return clampf(float(w[i + 1]) / 100.0, 0.0, 1.0)

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
		"piano", "keys":
			return "keys"
		"drums":
			return "drums"
		"theremin":
			return "theremin"
		"lyrics":
			return "lyrics"
	return ""

# swing: moves the off-beat eighth later, everything else bends around it
func sw(b: float) -> float:
	if swing <= 0.0:
		return b
	var d := swing * 0.1667
	var i := floorf(b)
	var f := b - i
	if f < 0.5:
		return i + f * (0.5 + d) / 0.5
	return i + 0.5 + d + (f - 0.5) * (0.5 - d) / 0.5

func scale_midi(d: int, sname: String = "") -> int:
	var sc: Array = SCALES[sname if sname != "" else scale_name]
	var n := sc.size()
	var idx := d - 1 if d > 0 else d
	var oct := floori(float(idx) / n)
	var step := posmod(idx, n)
	return 12 * (int(cur.oct) + 1) + key_root + int(sc[step]) + 12 * oct

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
	if is_block and not (BLOCKS.has(cmd) or BOTH.has(cmd)):
		fail(L, "'%s' doesn't end with a colon" % cmd)
		return
	if not is_block and BLOCKS.has(cmd):
		fail(L, "'%s' needs a colon at the end" % cmd)
		return

	# variables
	if not NOSUB.has(cmd):
		for k in range(1, w.size()):
			if vars.has(w[k]):
				w[k] = vars[w[k]]
	elif cmd == "loop" and w.size() > 1 and vars.has(w[1]):
		w[1] = vars[w[1]]
	elif cmd == "play" and w.size() > 2 and vars.has(w[2]):
		w[2] = vars[w[2]]

	match cmd:
		"let":
			if w.size() < 3:
				fail(L, "let looks like: let root = C3")
				return
			var val: String = w[w.size() - 1]
			if vars.has(val):
				val = vars[val]
			vars[w[1]] = val
		"tempo":
			if w.size() < 2:
				fail(L, "tempo looks like: tempo 120")
				return
			var t0 := clampf(num(L, w, 1, 100.0), 20.0, 400.0)
			if err != "":
				return
			if cur.is_empty():
				bpm = t0
			elif w.size() >= 5 and w[2].to_lower() == "to":
				var t1 := clampf(num(L, w, 3, t0), 20.0, 400.0)
				var span := num(L, w, 4, 4.0)
				if err != "" or span <= 0.0:
					return
				var steps := maxi(int(span * 4.0), 1)
				for s in steps + 1:
					add_ev(cur.cursor + span * s / steps, "tempo", {"bpm": lerpf(t0, t1, float(s) / steps)})
			else:
				add_ev(cur.cursor, "tempo", {"bpm": t0})
		"meter":
			if w.size() < 2:
				fail(L, "meter looks like: meter 4")
				return
			bpb = clampf(num(L, w, 1, 4.0), 1.0, 16.0)
		"swing":
			swing = clampf(num(L, w, 1, 0.0), 0.0, 1.0)
		"humanize":
			humanize = clampf(num(L, w, 1, 0.0), 0.0, 0.5)
		"key":
			if w.size() < 2:
				fail(L, "key looks like: key C minor")
				return
			var kr := parse_note(w[1], 4)
			if kr < 0:
				fail(L, "'%s' is not a note (try C, F#, Bb)" % w[1])
				return
			key_root = kr % 12
			scale_name = "major"
			if w.size() > 2:
				var sn := norm(w[2])
				if not SCALES.has(sn):
					fail(L, "scales: " + ", ".join(PackedStringArray(SCALES.keys())))
					return
				scale_name = sn
		"kit":
			if w.size() < 2:
				fail(L, "kit looks like: kit disco")
				return
			var found := ""
			for k in DRUMS.KIT_NAMES:
				if k.to_lower() == w[1].to_lower():
					found = k
			if found == "":
				fail(L, "unknown kit '%s' (standard bongos electro rock disco soul psych)" % w[1])
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
			var times := 1
			var ai := 2
			if w.size() > 2 and w[2].to_lower() != "as":
				times = int(num(L, w, 2, 1.0))
				ai = 3
			var pas := ""
			if w.size() > ai + 1 and w[ai].to_lower() == "as":
				pas = w[ai + 1]
			var r: Array = patterns[w[1].to_lower()]
			var saved_p := loop_idx
			nest += 1
			for k in clampi(times, 1, 256):
				loop_idx = k + 1
				if pas != "":
					vars[pas] = str(k + 1)
				run_range(r[0], r[1])
			nest -= 1
			loop_idx = saved_p
		"loop":
			if w.size() < 2:
				fail(L, "loop looks like: loop 4:")
				return
			var count := int(num(L, w, 1, 1.0))
			var as_name := ""
			if w.size() >= 4 and w[2].to_lower() == "as":
				as_name = w[3]
			var saved_l := loop_idx
			nest += 1
			for k in clampi(count, 1, 256):
				loop_idx = k + 1
				if as_name != "":
					vars[as_name] = str(k + 1)
				run_range(a, b)
			nest -= 1
			loop_idx = saved_l
		"every", "except":
			var en := int(num(L, w, 1, 1.0))
			if err != "":
				return
			if en < 1:
				fail(L, "%s needs a number of 1 or more" % cmd)
				return
			var hit := loop_idx % en == 0
			if hit == (cmd == "every"):
				run_range(a, b)
		"track":
			if w.size() < 2:
				fail(L, "track looks like: track lead keys:")
				return
			if not cur.is_empty():
				fail(L, "tracks can't be inside tracks")
				return
			var tn := w[1].to_lower()
			var kind := ""
			if w.size() > 2:
				kind = w[2].to_lower()
				if kind == "piano":
					kind = "keys"
			else:
				kind = track_kind(tn)
			if not KINDS.has(kind):
				fail(L, "what kind of track is '%s'? Write: track %s keys:  (or drums, theremin, lyrics)" % [w[1], w[1]])
				return
			if tracks.has(tn) and tracks[tn].kind != kind:
				fail(L, "track '%s' was already made as a different kind" % w[1])
				return
			if not tracks.has(tn):
				var bn := "Rec"
				if kind != "lyrics":
					bn = ensure_bus(tn)
				tracks[tn] = {"name": tn, "kind": kind, "cursor": 0.0, "bar_start": 0.0, "in_bar": false, "oct": 4, "vel": 1.0, "xpose": 0, "bus": bn}
				if kind == "keys" or kind == "theremin":
					var sy = get_synth(tn, kind)
					sy.set_bus(bn)
			cur = tracks[tn]
			run_range(a, b)
			cur = {}
		"bar", "measure":
			if cur.is_empty():
				fail(L, "%s goes inside a track:" % cmd)
				return
			if cur.in_bar:
				fail(L, "measures can't be inside measures")
				return
			if w.size() > 1:
				if nest > 0:
					fail(L, "numbered measures can't be inside a loop or pattern (use plain bar:)")
					return
				var mi := int(num(L, w, 1, 1.0))
				if err != "":
					return
				if mi < 1:
					fail(L, "measures start at 1")
					return
				cur.cursor = (mi - 1) * bpb
			else:
				cur.cursor = ceilf(cur.cursor / bpb - 0.0001) * bpb
			cur.bar_start = cur.cursor
			cur.in_bar = true
			run_range(a, b)
			cur.in_bar = false
			var end: float = maxf(cur.cursor, cur.bar_start + bpb)
			cur.cursor = ceilf(end / bpb - 0.0001) * bpb
		"octave":
			if cur.is_empty():
				fail(L, "octave goes inside a track:")
				return
			var o := int(num(L, w, 1, 4.0))
			if err != "":
				return
			cur.oct = clampi(o, 0, 9)
		"transpose":
			if cur.is_empty():
				fail(L, "transpose goes inside a track:")
				return
			var tx := int(num(L, w, 1, 0.0))
			if err != "":
				return
			if is_block:
				var old: int = cur.xpose
				cur.xpose = tx
				run_range(a, b)
				cur.xpose = old
			else:
				cur.xpose = tx
		"velocity":
			if cur.is_empty():
				fail(L, "velocity goes inside a track:")
				return
			cur.vel = clampf(num(L, w, 1, 100.0), 0.0, 100.0) / 100.0
		"rest":
			if cur.is_empty():
				fail(L, "rest goes inside a track:")
				return
			cur.cursor += num(L, w, 1, 1.0)
		"note":
			do_note(L, w)
		"deg":
			do_deg(L, w)
		"chord":
			do_chord(L, w)
		"arp":
			do_arp(L, w)
		"progression":
			do_prog(L, w)
		"reverb", "delay", "distortion", "lowpass", "highpass", "chorus", "pan":
			if cur.is_empty():
				fail(L, "%s goes inside a track:" % cmd)
				return
			if cur.kind == "lyrics":
				fail(L, "effects don't work on lyrics tracks")
				return
			var fv: float = FX_DEFAULT[cmd]
			if w.size() > 1:
				if w[1].to_lower() == "off":
					fv = 0.0
				else:
					fv = num(L, w, 1, fv)
			if err != "":
				return
			add_ev(cur.cursor, "fx", {"trk": cur.name, "fx": cmd, "value": fv})
		"sample":
			do_sample(L, w)
		"glide":
			if not need(L, ["theremin"]):
				return
			if w.size() < 4 or w[2].to_lower() != "to":
				fail(L, "glide looks like: glide A4 to E5 2")
				return
			var m0 := parse_note(w[1], cur.oct)
			var m1 := parse_note(w[3], cur.oct)
			if m0 < 0 or m1 < 0:
				fail(L, "glide needs two notes, like A4 and E5")
				return
			var gb := num(L, w, 4, 1.0)
			if err != "" or gb <= 0.0:
				return
			var gt: float = cur.cursor
			var xp := int(cur.xpose)
			add_ev(gt, "th_glide", {"trk": cur.name, "dur": gb, "f0": hz(m0 + xp), "f1": hz(m1 + xp)})
			add_ev(gt + gb, "th_off", {"trk": cur.name})
			cur.cursor = gt + gb
		"vibrato":
			if not need(L, ["theremin"]):
				return
			add_ev(cur.cursor, "th_vib", {"trk": cur.name, "depth": clampf(num(L, w, 1, 0.0), 0.0, 1.0)})
		"instrument":
			if not need(L, ["keys"]):
				return
			var inst := find_inst(w[1]) if w.size() > 1 else ""
			if inst == "":
				fail(L, "unknown instrument (try piano, e_piano, organ, glass_harmonica, guitar, bass, chip_saw...)")
				return
			if inst == "Sample":
				fail(L, "Sample can't be used in scripts yet")
				return
			add_ev(cur.cursor, "kb_inst", {"trk": cur.name, "inst": inst})
		"voice":
			if not need(L, ["theremin"]):
				return
			var vn := find_voice(w[1]) if w.size() > 1 else ""
			if vn == "":
				fail(L, "voices: classic pure buzzy hollow voice spooky")
				return
			add_ev(cur.cursor, "th_voice", {"trk": cur.name, "voice": vn})
		"volume":
			if cur.is_empty():
				fail(L, "volume goes inside a track:")
				return
			add_ev(cur.cursor, "vol", {"kind": cur.kind, "trk": cur.name, "value": clampf(num(L, w, 1, 100.0), 0.0, 100.0)})
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
func emit_drum(real: String, t: float, v: float) -> void:
	if not real.begins_with("@"):
		drums.get_sound(real)
	var on := sw(t)
	var vv := v
	if humanize > 0.0:
		on = maxf(on + rng.randf_range(-humanize, humanize), 0.0)
		vv = clampf(vv * (1.0 + rng.randf_range(-humanize, humanize) * 2.0), 0.05, 1.0)
	add_ev(on, "drum", {"name": real, "trk": cur.name, "vel": vv, "pitch": cur_pitch})
# ---------------- note emitters ----------------

func emit_kb(note: int, t: float, dur: float, vel: float) -> void:
	var m := clampi(note + int(cur.xpose), 0, 127)
	var on := sw(t)
	var off := sw(t + dur)
	var v := vel
	if humanize > 0.0:
		on = maxf(on + rng.randf_range(-humanize, humanize), 0.0)
		v = clampf(v * (1.0 + rng.randf_range(-humanize, humanize) * 2.0), 0.05, 1.0)
	off = maxf(off, on + 0.03)
	add_ev(on, "kb_on", {"trk": cur.name, "note": m, "vel": v})
	add_ev(off, "kb_off", {"trk": cur.name, "note": m})

func put_pitch(m: int, beats: float, vel: float) -> void:
	var t: float = cur.cursor
	if cur.kind == "keys":
		emit_kb(m, t, beats, vel)
	else:
		var mm := m + int(cur.xpose)
		add_ev(sw(t), "th_on", {"trk": cur.name, "freq": hz(mm)})
		add_ev(sw(t + beats), "th_off", {"trk": cur.name})
	cur.cursor = t + beats



func do_note(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["keys", "theremin"]):
		return
	if w.size() < 2:
		fail(L, "note looks like: note E4 1")
		return
	var m := parse_note(w[1], cur.oct)
	if m < 0:
		fail(L, "'%s' is not a note (try C4, F#3, Bb2, or just E)" % w[1])
		return
	var beats := beats_at(L, w, 2, 1.0)
	var v := opt_vel(L, w)
	if err != "":
		return
	if beats <= 0.0:
		fail(L, "beats must be more than 0")
		return
	put_pitch(m, beats, v)

func do_deg(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["keys", "theremin"]):
		return
	if w.size() < 2:
		fail(L, "deg looks like: deg 3 1  (scale degree, then beats)")
		return
	var tok := w[1]
	var adj := 0
	if tok.ends_with("#"):
		adj = 1
		tok = tok.left(tok.length() - 1)
	elif tok.ends_with("b"):
		adj = -1
		tok = tok.left(tok.length() - 1)
	if not tok.is_valid_int() or int(tok) == 0:
		fail(L, "'%s' isn't a scale degree (1 to 7, 8 = octave up, -1 = below)" % w[1])
		return
	var beats := beats_at(L, w, 2, 1.0)
	var v := opt_vel(L, w)
	if err != "":
		return
	if beats <= 0.0:
		fail(L, "beats must be more than 0")
		return
	put_pitch(scale_midi(int(tok)) + adj, beats, v)

func do_chord(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["keys"]):
		return
	if w.size() < 3:
		fail(L, "chord looks like: chord C major 4")
		return
	var root := parse_note(w[1], cur.oct)
	if root < 0:
		fail(L, "'%s' is not a note (try C, F#3, Bb)" % w[1])
		return
	var q := w[2].to_lower()
	if not CHORDS.has(q):
		fail(L, "chord types: " + ", ".join(PackedStringArray(CHORDS.keys())))
		return
	var beats := beats_at(L, w, 3, bpb)
	var v := opt_vel(L, w)
	if err != "":
		return
	if beats <= 0.0:
		fail(L, "beats must be more than 0")
		return
	var t: float = cur.cursor
	for iv in CHORDS[q]:
		emit_kb(root + int(iv), t, beats, v)
	cur.cursor = t + beats

func arp_emit(notes: Array, t0: float, beats: float, dir: String, step: float, vel: float) -> void:
	var seq: Array = notes.duplicate()
	if dir == "down":
		seq.reverse()
	elif dir == "updown" and notes.size() > 2:
		var back: Array = notes.slice(1, notes.size() - 1)
		back.reverse()
		seq.append_array(back)
	var i := 0
	while i * step < beats - 0.0001:
		var t := i * step
		var n: int
		if dir == "random":
			n = seq[rng.randi() % seq.size()]
		else:
			n = seq[i % seq.size()]
		emit_kb(n, t0 + t, minf(step, beats - t), vel)
		i += 1

func do_arp(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["keys"]):
		return
	if w.size() < 3:
		fail(L, "arp looks like: arp C major 4 up 0.5")
		return
	var root := parse_note(w[1], cur.oct)
	if root < 0:
		fail(L, "'%s' is not a note (try C, F#3, Bb)" % w[1])
		return
	var q := w[2].to_lower()
	if not CHORDS.has(q):
		fail(L, "chord types: " + ", ".join(PackedStringArray(CHORDS.keys())))
		return
	var beats := beats_at(L, w, 3, bpb)
	var dir := "up"
	var step := 0.5
	var octs := 1
	if w.size() > 4 and w[4] != "vel":
		dir = w[4].to_lower()
		if not ARP_DIRS.has(dir):
			fail(L, "arp directions: up down updown random")
			return
	if w.size() > 5 and w[5] != "vel":
		step = num(L, w, 5, 0.5)
	if w.size() > 6 and w[6] != "vel":
		octs = int(num(L, w, 6, 1.0))
	var v := opt_vel(L, w)
	if err != "":
		return
	if beats <= 0.0 or step <= 0.0:
		fail(L, "beats and step must be more than 0")
		return
	var notes: Array = []
	for o in clampi(octs, 1, 4):
		for iv in CHORDS[q]:
			notes.append(root + int(iv) + 12 * o)
	arp_emit(notes, cur.cursor, beats, dir, step, v)
	cur.cursor += beats

func parse_roman(tok: String) -> Dictionary:
	var s := tok
	var shift := 0
	if s.begins_with("b") and s.length() > 1:
		shift = -1
		s = s.substr(1)
	elif s.begins_with("#"):
		shift = 1
		s = s.substr(1)
	var k := 0
	while k < s.length() and "IVXivx".contains(s.substr(k, 1)):
		k += 1
	if k == 0:
		return {}
	var numeral := s.substr(0, k)
	var suffix := s.substr(k).to_lower()
	var degs := {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7}
	var low := numeral.to_lower()
	if not degs.has(low):
		return {}
	var upper := numeral == numeral.to_upper()
	var q := "major" if upper else "minor"
	match suffix:
		"":
			pass
		"7":
			q = "7" if upper else "min7"
		"maj7":
			q = "maj7"
		"o", "dim":
			q = "dim"
		"+", "aug":
			q = "aug"
		"sus2", "sus4":
			q = suffix
		"6":
			q = "6" if upper else "min6"
		"9":
			q = "9"
		_:
			return {}
	var sn := scale_name if SCALES[scale_name].size() == 7 else "major"
	return {"root": scale_midi(int(degs[low]), sn) + shift, "q": q}

func do_prog(L: Dictionary, w: PackedStringArray) -> void:
	if not need(L, ["keys"]):
		return
	var list: Array = []
	var i := 1
	while i < w.size() and not w[i].is_valid_float() and w[i] != "arp" and w[i] != "vel":
		var rc := parse_roman(w[i])
		if rc.is_empty():
			fail(L, "'%s' isn't a roman numeral chord (try I ii V7 vi bVII)" % w[i])
			return
		list.append(rc)
		i += 1
	if list.is_empty():
		fail(L, "progression looks like: progression I V vi IV 4")
		return
	var beats := bpb
	if i < w.size() and w[i].is_valid_float():
		beats = float(w[i])
		i += 1
	var dir := ""
	var step := 0.5
	if i < w.size() and w[i] == "arp":
		dir = "up"
		i += 1
		if i < w.size() and ARP_DIRS.has(w[i].to_lower()):
			dir = w[i].to_lower()
			i += 1
		if i < w.size() and w[i].is_valid_float():
			step = float(w[i])
	var v := opt_vel(L, w)
	if err != "":
		return
	if beats <= 0.0 or step <= 0.0:
		fail(L, "beats and step must be more than 0")
		return
	for ch in list:
		var notes: Array = []
		for iv in CHORDS[ch.q]:
			notes.append(int(ch.root) + int(iv))
		if dir == "":
			for n in notes:
				emit_kb(int(n), cur.cursor, beats, v)
		else:
			arp_emit(notes, cur.cursor, beats, dir, step, v)
		cur.cursor += beats

func is_hit_token(s: String) -> bool:
	if s == "":
		return false
	for k in s.length():
		if not HIT_CHARS.contains(s.substr(k, 1)):
			return false
	return true

func do_drum(L: Dictionary, w: PackedStringArray, real: String) -> void:
	if not cur.in_bar:
		fail(L, "drum hits go inside a measure (bar:)")
		return
	if w.size() < 2:
		fail(L, "'%s' needs beat numbers or a step string, like: %s 1 3" % [w[0], w[0]])
		return
	var endi := w.size()
	var base_v: float = cur.vel
	var vi := w.find("vel")
	if vi >= 0:
		if vi + 1 >= w.size() or not w[vi + 1].is_valid_float():
			fail(L, "vel needs a number from 0 to 100")
			return
		base_v = clampf(float(w[vi + 1]) / 100.0, 0.0, 1.0)
		endi = vi
	if endi < 2:
		fail(L, "'%s' needs beat numbers or a step string, like: %s 1 3" % [w[0], w[0]])
		return
	if is_hit_token(w[1]):
		var pat := ""
		for i in range(1, endi):
			if not is_hit_token(w[i]):
				fail(L, "'%s' isn't part of a step string (use x X o . -)" % w[i])
				return
			pat += w[i]
		pat = pat.replace("|", "")
		if pat.length() == 0:
			return
		var step_len := bpb / pat.length()
		for k in pat.length():
			var c := pat.substr(k, 1)
			var v := 0.0
			if c == "X":
				v = base_v
			elif c == "x":
				v = base_v * 0.8
			elif c == "o":
				v = base_v * 0.4
			if v > 0.0:
				emit_drum(real, cur.bar_start + k * step_len, v)
		return
	for i in range(1, endi):
		if not w[i].is_valid_float():
			fail(L, "'%s' should be a beat number" % w[i])
			return
		var pos := float(w[i])
		if pos < 1.0 or pos >= 1.0 + bpb:
			fail(L, "beat %s is outside the measure (1 to %s)" % [w[i], str(bpb)])
			return
		emit_drum(real, cur.bar_start + pos - 1.0, base_v)

# ---------------- playback ----------------

func start() -> void:
	play_src(editor.text, false, int(from_box.value))

func stop_pressed() -> void:
	var was := exporting
	stop_play()
	show_status("Export cancelled." if was else "Stopped")

func play_src(src: String, from_repl: bool, start_bar: int = 1) -> void:
	stop_play()
	clear_marks()
	if not compile(src):
		show_error(from_repl)
		return
	for tn in synths.keys():
		if not tracks.has(tn):
			synths[tn].queue_free()
			synths.erase(tn)
			synth_kinds.erase(tn)
	if events.is_empty():
		show_status("Nothing to play yet.")
		return
	for tn in synths:
		if synth_kinds[tn] == "keys":
			synths[tn].set_level(1.0)
			if not from_repl:
				synths[tn].set_instrument("Piano")
		else:
			synths[tn].vol_level = 0.6
			synths[tn].vib_depth = 0.0
			if not from_repl:
				synths[tn].set_voice("Classic")
	for tn in tracks:
		if tracks[tn].bus != "Rec":
			reset_bus(tracks[tn].bus)
	drum_vols.clear()
	play_bpm = bpm
	var start_beat := maxf((start_bar - 1) * bpb, 0.0)
	ev_i = 0
	say_i = 0
	while ev_i < events.size() and events[ev_i].beat < start_beat:
		var e: Dictionary = events[ev_i]
		if STATE_EVENTS.has(e.type):
			fire(e)
		elif e.type == "say":
			say_i += 1
		ev_i += 1
	play_beat = start_beat
	playing = true
	show_status("Playing (%d bpm)" % int(bpm))

func stop_play(cancel_export: bool = true) -> void:
	playing = false
	glides.clear()
	for p in pool:
		p.stop()
	for tn in synths:
		if synth_kinds[tn] == "keys":
			synths[tn].script_off_all()
		elif synths[tn].pitch_index == 9999:
			synths[tn].pitch_index = -1
	if lyric_label:
		lyric_label.text = ""
	if cancel_export and exporting:
		finish_export(false)

func _process(delta: float) -> void:
	if not playing:
		return
	play_beat += delta * play_bpm / 60.0
	while ev_i < events.size() and events[ev_i].beat <= play_beat:
		fire(events[ev_i])
		ev_i += 1
	for trk in glides:
		var g: Dictionary = glides[trk]
		var f: float = clampf((play_beat - g.beat) / g.dur, 0.0, 1.0)
		synths[trk].target_freq = g.f0 * pow(g.f1 / g.f0, f)
	if play_beat > total + TAIL_SEC * play_bpm / 60.0:
		var was := exporting
		stop_play(false)
		if was:
			finish_export(true)
		else:
			show_status("Done")

func fire(e: Dictionary) -> void:
	match e.type:
		"kb_on":
			synths[e.trk].script_on(e.note, e.get("vel", 1.0))
		"kb_off":
			synths[e.trk].script_off(e.note)
		"kb_inst":
			synths[e.trk].set_instrument(e.inst)
		"drum":
			play_drum(e.name, e.trk, e.get("vel", 1.0), e.get("pitch", 0.0))
		"fx":
			apply_fx(e.trk, e.fx, e.value)
		"tempo":
			play_bpm = e.bpm
		"th_on":
			glides.erase(e.trk)
			var th = synths[e.trk]
			th.target_freq = e.freq
			th.pitch_index = 9999
		"th_off":
			glides.erase(e.trk)
			var th2 = synths[e.trk]
			if th2.pitch_index == 9999:
				th2.pitch_index = -1
		"th_glide":
			glides[e.trk] = {"beat": e.beat, "dur": e.dur, "f0": e.f0, "f1": e.f1}
			var th3 = synths[e.trk]
			th3.target_freq = e.f0
			th3.pitch_index = 9999
		"th_vib":
			synths[e.trk].vib_depth = e.depth
		"th_voice":
			synths[e.trk].set_voice(e.voice)
		"vol":
			var v: float = e.value / 100.0
			match e.kind:
				"keys":
					synths[e.trk].set_level(v)
				"drums":
					drum_vols[e.trk] = v
				"theremin":
					synths[e.trk].vol_level = clampf(v * 0.6, 0.0, 1.0)
		"say":
			var shown: String = say_texts[say_i]
			if say_i + 1 < say_texts.size():
				shown += "\n\n" + say_texts[say_i + 1]
			lyric_label.text = shown
			say_i += 1

func play_drum(nm: String, trk: String, vel: float, pitch: float = 0.0) -> void:
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = sample_map[nm] if nm.begins_with("@") else drums.get_sound(nm)
	p.bus = tracks[trk].bus if tracks.has(trk) else "Rec"
	p.pitch_scale = pow(2.0, pitch / 12.0)
	p.volume_db = linear_to_db(maxf(drum_vols.get(trk, 1.0) * vel, 0.0001))
	p.play()

# ---------------- export: WAV / MP4 ----------------

func start_export(wav_path: String, mp4_path: String) -> void:
	if rec_fx == null:
		show_status("Can't record: the Rec audio bus wasn't found.")
		return
	export_wav_path = wav_path
	export_mp4_path = mp4_path
	rec_fx.set_recording_active(false)
	play_src(editor.text, false, 1)
	if playing:
		exporting = true
		rec_fx.set_recording_active(true)
		show_status("Exporting... the song is recorded live, so wait for it to finish. Stop cancels.")

func finish_export(ok: bool) -> void:
	exporting = false
	rec_fx.set_recording_active(false)
	if not ok:
		return
	var wav: AudioStreamWAV = rec_fx.get_recording()
	if wav == null:
		show_status("Nothing was recorded.")
		return
	if wav.save_to_wav(export_wav_path) != OK:
		show_status("Couldn't save " + export_wav_path)
		return
	if export_mp4_path != "" and exporter != null:
		show_status("WAV saved. Making the MP4...")
		exporter.make_mp4(export_wav_path, export_mp4_path)
	else:
		show_status("Saved " + export_wav_path)

# ---------------- export: MIDI ----------------

func be(v: int, n: int) -> PackedByteArray:
	var o := PackedByteArray()
	for i in range(n - 1, -1, -1):
		o.append((v >> (8 * i)) & 0xFF)
	return o

func vlq(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	var parts: Array = [v & 0x7F]
	v >>= 7
	while v > 0:
		parts.push_front((v & 0x7F) | 0x80)
		v >>= 7
	for p in parts:
		out.append(int(p))
	return out

func tempo_meta(b: float) -> PackedByteArray:
	var us := int(60000000.0 / maxf(b, 1.0))
	var o := PackedByteArray([0xFF, 0x51, 0x03])
	o.append_array(be(us, 3))
	return o

func vel_byte(e: Dictionary) -> int:
	return clampi(int(float(e.get("vel", 1.0)) * 127.0), 1, 127)

func midi_track(evs: Array, tname: String) -> PackedByteArray:
	evs.sort_custom(func(x, y): return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
	var d := PackedByteArray()
	var nb := tname.to_utf8_buffer()
	d.append_array(vlq(0))
	d.append(0xFF)
	d.append(0x03)
	d.append_array(vlq(nb.size()))
	d.append_array(nb)
	var last := 0
	for e in evs:
		d.append_array(vlq(int(e[0]) - last))
		last = int(e[0])
		d.append_array(e[2])
	d.append_array(vlq(0))
	d.append(0xFF)
	d.append(0x2F)
	d.append(0x00)
	var out := PackedByteArray()
	out.append_array("MTrk".to_ascii_buffer())
	out.append_array(be(d.size(), 4))
	out.append_array(d)
	return out

func export_midi(path: String) -> void:
	stop_play()
	clear_marks()
	if not compile(editor.text):
		show_error(false)
		return
	if not path.to_lower().ends_with(".mid"):
		path += ".mid"
	var chans := {}
	var per := {}
	var nxt := 0
	var cond: Array = [[0, 0, tempo_meta(bpm)]]
	var last_note := {}
	for e in events:
		var t := int(round(e.beat * TPQ))
		if e.type == "tempo":
			cond.append([t, 0, tempo_meta(e.bpm)])
			continue
		if not ["kb_on", "kb_off", "drum", "th_on", "th_glide", "th_off"].has(e.type):
			continue
		var tn: String = e.trk
		if not chans.has(tn):
			if tracks[tn].kind == "drums":
				chans[tn] = 9
			else:
				if nxt == 9:
					nxt += 1
				chans[tn] = mini(nxt, 15)
				nxt += 1
			per[tn] = []
		var ch: int = chans[tn]
		var arr: Array = per[tn]
		match e.type:
			"kb_on":
				arr.append([t, 1, PackedByteArray([0x90 | ch, int(e.note), vel_byte(e)])])
			"kb_off":
				arr.append([t, 0, PackedByteArray([0x80 | ch, int(e.note), 0])])
			"drum":
				var g: int = GM_DRUMS.get(e.name, 37)
				arr.append([t, 1, PackedByteArray([0x99, g, vel_byte(e)])])
				arr.append([t + 60, 0, PackedByteArray([0x89, g, 0])])
			"th_on", "th_glide":
				var fq: float = e.freq if e.type == "th_on" else e.f0
				var n := clampi(int(round(69.0 + 12.0 * log(fq / 440.0) / log(2.0))), 0, 127)
				if last_note.has(tn):
					arr.append([t, 0, PackedByteArray([0x80 | ch, int(last_note[tn]), 0])])
				last_note[tn] = n
				arr.append([t, 1, PackedByteArray([0x90 | ch, n, 100])])
			"th_off":
				if last_note.has(tn):
					arr.append([t, 0, PackedByteArray([0x80 | ch, int(last_note[tn]), 0])])
					last_note.erase(tn)
	var out := PackedByteArray()
	out.append_array("MThd".to_ascii_buffer())
	out.append_array(be(6, 4))
	out.append_array(be(1, 2))
	out.append_array(be(per.size() + 1, 2))
	out.append_array(be(TPQ, 2))
	out.append_array(midi_track(cond, "Conductor"))
	for tn in per:
		out.append_array(midi_track(per[tn], tn))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		show_status("Couldn't save " + path)
		return
	f.store_buffer(out)
	f.close()
	show_status("Saved MIDI: " + path)

# ---------------- REPL ----------------

func editor_tempo() -> String:
	for l in editor.text.split("\n"):
		var s := l.strip_edges()
		if s.begins_with("tempo "):
			var v := s.substr(6).strip_edges()
			if v.is_valid_float():
				return v
	return "100"

func editor_prelude() -> String:
	var out := "tempo %s\n" % editor_tempo()
	for l in editor.text.split("\n"):
		if l.begins_with("key ") or l.begins_with("let ") or l.begins_with("meter "):
			out += l + "\n"
	return out

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
	var src := editor_prelude() + "track %s:\n    bar:\n%s" % [last_track, body]
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
	
# ---------------- per-track effects ----------------

func ensure_bus(tn: String) -> String:
	var bn := "PT " + tn
	if AudioServer.get_bus_index(bn) < 0:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, bn)
		AudioServer.set_bus_send(bi, "Rec")
	return bn

func reset_bus(bn: String) -> void:
	var bi := AudioServer.get_bus_index(bn)
	if bi < 0:
		return
	while AudioServer.get_bus_effect_count(bi) > 0:
		AudioServer.remove_bus_effect(bi, 0)
	AudioServer.add_bus_effect(bi, AudioEffectPanner.new())
	var fxs := [AudioEffectReverb.new(), AudioEffectDelay.new(), AudioEffectDistortion.new(),
		AudioEffectLowPassFilter.new(), AudioEffectHighPassFilter.new(), AudioEffectChorus.new()]
	for fx in fxs:
		AudioServer.add_bus_effect(bi, fx)
		AudioServer.set_bus_effect_enabled(bi, AudioServer.get_bus_effect_count(bi) - 1, false)

func apply_fx(tn: String, which: String, v: float) -> void:
	if not tracks.has(tn):
		return
	var bi := AudioServer.get_bus_index(str(tracks[tn].bus))
	if bi < 0:
		return
	if which == "pan":
		var pn = AudioServer.get_bus_effect(bi, 0)
		pn.pan = clampf(v, -1.0, 1.0)
		return
	var slot: int = FX_SLOT[which]
	var fx = AudioServer.get_bus_effect(bi, slot)
	match which:
		"reverb":
			fx.room_size = 0.8
			fx.wet = clampf(v, 0.0, 1.0)
		"delay":
			var ms := clampf(v * 60000.0 / play_bpm, 10.0, 1500.0)
			fx.tap1_delay_ms = ms
			fx.tap2_delay_ms = minf(ms * 2.0, 1500.0)
			fx.feedback_delay_ms = ms
		"distortion":
			fx.drive = clampf(v, 0.0, 1.0)
		"lowpass", "highpass":
			fx.cutoff_hz = clampf(v, 20.0, 20000.0)
	AudioServer.set_bus_effect_enabled(bi, slot, v > 0.0)

# ---------------- samples in scripts ----------------

func find_sample(sname: String) -> AudioStreamWAV:
	var key := norm(sname)
	if mixer != null:
		for t in mixer.tracks:
			if norm(str(t.name)) == key and t.stream is AudioStreamWAV:
				return t.stream
	if key == "keyboard" and kbs.size() > 0 and kbs[0].sample != null:
		return kbs[0].sample
	var fname := sname if sname.to_lower().ends_with(".wav") else sname + ".wav"
	for dir in [script_dir, "user://plonk"]:
		if dir == "":
			continue
		var p: String = dir.path_join(fname)
		if FileAccess.file_exists(p):
			if not file_samples.has(p):
				file_samples[p] = AudioStreamWAV.load_from_file(p)
			return file_samples[p]
	return null

func sample_names() -> String:
	var out: Array = []
	if mixer != null:
		for t in mixer.tracks:
			out.append(norm(str(t.name)))
	if kbs.size() > 0 and kbs[0].sample != null:
		out.append("keyboard")
	if out.is_empty():
		return "none yet (send a take to the mixer, or save a .wav next to your script)"
	return ", ".join(PackedStringArray(out))

func do_sample(L: Dictionary, w: PackedStringArray) -> void:
	if cur.is_empty() or cur.kind != "drums":
		fail(L, "sample goes inside a drums track, inside a bar:")
		return
	if w.size() < 3:
		fail(L, "sample looks like: sample take_1 1 3  (name, then beat positions)")
		return
	var wav := find_sample(w[1])
	if wav == null:
		fail(L, "no sample called '%s'. Available: %s" % [w[1], sample_names()])
		return
	var args := w.slice(1)
	var pi := args.find("pitch")
	var semis := 0.0
	if pi >= 0:
		if pi + 1 >= args.size() or not args[pi + 1].is_valid_float():
			fail(L, "pitch needs a number of semitones")
			return
		semis = float(args[pi + 1])
		args.remove_at(pi + 1)
		args.remove_at(pi)
	var key := "@" + norm(w[1])
	sample_map[key] = wav
	cur_pitch = semis
	do_drum(L, args, key)
	cur_pitch = 0.0

# ---------------- record keys into the script ----------------

func has_tempo() -> bool:
	for l in editor.text.split("\n"):
		if l.strip_edges().begins_with("tempo "):
			return true
	return false

func note_name(m: int) -> String:
	return NOTE_NAMES[m % 12] + str(m / 12 - 1)

func fmt(x: float) -> String:
	return str(snappedf(x, 0.01))

func rec_begin() -> void:
	recording = true
	rec_notes.clear()
	rec_open.clear()
	rec_t0 = -1.0

func on_key_down(note: int) -> void:
	if not recording:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if rec_t0 < 0.0:
		rec_t0 = now
	rec_open[note] = now - rec_t0

func on_key_up(note: int) -> void:
	if not recording or not rec_open.has(note):
		return
	var now := Time.get_ticks_msec() / 1000.0 - rec_t0
	rec_notes.append({"note": note, "s": rec_open[note], "e": now})
	rec_open.erase(note)

func rec_end(fallback_bpm: float) -> void:
	recording = false
	if rec_t0 >= 0.0:
		var tnow := Time.get_ticks_msec() / 1000.0 - rec_t0
		for n in rec_open:
			rec_notes.append({"note": n, "s": rec_open[n], "e": tnow})
	rec_open.clear()
	if rec_notes.is_empty():
		show_status("No keys were played.")
		return
	rec_notes.sort_custom(func(a, b): return a.s < b.s)
	var tempo := fallback_bpm
	if has_tempo():
		tempo = float(editor_tempo())
	var spb := 60.0 / tempo
	var grid := 0.25
	var items := []
	for n in rec_notes:
		var s := snappedf(n.s / spb, grid)
		var d := maxf(snappedf((n.e - n.s) / spb, grid), grid)
		items.append({"note": int(n.note), "s": s, "e": s + d})
	# overlapping notes (chords) go to extra tracks
	var lane_end := []
	var lane_items := []
	for it in items:
		var placed := false
		for li in lane_end.size():
			if lane_end[li] <= it.s + 0.0001:
				lane_items[li].append(it)
				lane_end[li] = it.e
				placed = true
				break
		if not placed:
			lane_end.append(it.e)
			lane_items.append([it])
	var take := 1
	while editor.text.contains("track rec%d_" % take):
		take += 1
	var inst := "piano"
	if kbs.size() > 0 and kbs[0].instrument != "Sample":
		inst = norm(kbs[0].instrument)
	var out := "\n# recorded from the keyboard\n"
	for li in lane_items.size():
		out += "track rec%d_%d keys:\n    instrument %s\n" % [take, li + 1, inst]
		var cursor := 0.0
		for it in lane_items[li]:
			if it.s - cursor > 0.0001:
				out += "    rest %s\n" % fmt(it.s - cursor)
			out += "    note %s %s\n" % [note_name(it.note), fmt(it.e - it.s)]
			cursor = it.e
		out += "\n"
	if not has_tempo():
		editor.text = ("tempo %d\n" % int(round(fallback_bpm))) + editor.text
	editor.text += out
	clear_marks()
	show_status("Wrote %d notes into %d track(s). Tap Run to hear them." % [items.size(), lane_items.size()])
	
	
