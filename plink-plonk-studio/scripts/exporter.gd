extends Node

signal finished(message)

const CFG := "user://plink_settings.cfg"
const STYLES := ["Wave line", "Wave points", "Spectrum bars", "Spectrum (CQT)"]

var ffmpeg_dir := ""
var style := 0
var width := 1280
var height := 720
var color := "33ff66"
var busy := false
var thread: Thread

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) == OK:
		ffmpeg_dir = str(c.get_value("ffmpeg", "dir", ""))
		style = clampi(int(c.get_value("video", "style", 0)), 0, STYLES.size() - 1)

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("ffmpeg", "dir", ffmpeg_dir)
	c.set_value("video", "style", style)
	c.save(CFG)

func set_dir(d: String) -> void:
	ffmpeg_dir = d
	save_settings()
	finished.emit("FFmpeg folder set to " + d)

func ffmpeg_path() -> String:
	if ffmpeg_dir == "":
		return "ffmpeg"
	var exe := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	return ffmpeg_dir.path_join(exe)

func filter_text() -> String:
	var sz := "%dx%d" % [width, height]
	match style:
		1:
			return "[0:a]showwaves=s=%s:mode=point:r=30:colors=0x%s,format=yuv420p[v]" % [sz, color]
		2:
			return "[0:a]showfreqs=s=%s:mode=bar:fscale=log:colors=0x%s,format=yuv420p[v]" % [sz, color]
		3:
			return "[0:a]showcqt=s=%s:fps=30,format=yuv420p[v]" % sz
	return "[0:a]showwaves=s=%s:mode=cline:r=30:colors=0x%s,format=yuv420p[v]" % [sz, color]

func build_args(wav: String, mp4: String) -> PackedStringArray:
	return PackedStringArray(["-y", "-i", wav, "-filter_complex", filter_text(),
		"-map", "[v]", "-map", "0:a", "-c:v", "libx264", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-b:a", "192k", "-shortest", mp4])

func script_text(wav: String, mp4: String) -> String:
	var parts: Array = ["'" + ffmpeg_path().replace("'", "'\\''") + "'"]
	for a in build_args(wav, mp4):
		parts.append("'" + a.replace("'", "'\\''") + "'")
	return "#!/bin/sh\n" + " ".join(PackedStringArray(parts)) + "\n"

func make_mp4(wav: String, mp4: String) -> void:
	if busy:
		finished.emit("Still making the last video, wait for it to finish.")
		return
	busy = true
	thread = Thread.new()
	thread.start(_run.bind(ffmpeg_path(), build_args(wav, mp4), wav, mp4))

func _run(path: String, args: PackedStringArray, wav: String, mp4: String) -> void:
	var out := []
	var code := OS.execute(path, args, out, true)
	call_deferred("_done", code, out, wav, mp4)

func _done(code: int, out: Array, wav: String, mp4: String) -> void:
	thread.wait_to_finish()
	busy = false
	if code == 0:
		finished.emit("MP4 saved: " + mp4)
		return
	var msg := "Couldn't run FFmpeg from here. " if code == -1 else "FFmpeg failed (code %d). " % code
	if code != -1 and out.size() > 0:
		msg += "\n" + str(out[0]).right(300) + "\n"
	var sh := mp4.get_basename() + "_make_mp4.sh"
	var f := FileAccess.open(sh, FileAccess.WRITE)
	if f:
		f.store_string(script_text(wav, mp4))
		f.close()
		msg += "I saved the command to " + sh + ". In Termux run:  sh '" + sh + "'"
	finished.emit(msg)
