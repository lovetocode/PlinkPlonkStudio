class_name WebIO

static var _cb
static var _then: Callable

static func is_web() -> bool:
	return OS.has_feature("web")

# Use this instead of fd.popup_centered_ratio(0.8)
static func show(fd: FileDialog) -> void:
	if not is_web():
		fd.popup_centered_ratio(0.8)
	elif fd.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		_pick(fd)
	else:
		_save(fd)

static func _accept(fd: FileDialog) -> String:
	var out := PackedStringArray()
	for f in fd.filters:
		for p in f.split(";")[0].split(","):
			out.append(p.strip_edges().replace("*", ""))
	return ",".join(out)

static func _pick(fd: FileDialog) -> void:
	_cb = JavaScriptBridge.create_callback(_got)
	JavaScriptBridge.get_interface("window").webioCb = _cb
	_then = func(path): fd.file_selected.emit(path)
	JavaScriptBridge.eval("(function(){var i=document.createElement('input');i.type='file';i.accept='%s';i.onchange=function(){var f=i.files[0];if(!f)return;var r=new FileReader();r.onload=function(){var d=r.result;window.webioCb(f.name,d.substring(d.indexOf(',')+1));};r.readAsDataURL(f);};i.click();})();" % _accept(fd))

static func _got(args: Array) -> void:
	var path := "user://" + str(args[0])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(Marshalls.base64_to_raw(str(args[1])))
	f.close()
	_then.call(path)

static func _save(fd: FileDialog) -> void:
	var path := "user://" + (fd.current_file if fd.current_file != "" else "file.bin")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	fd.file_selected.emit(path)
	download(path)

# Sends a user:// file to the browser as a download. Does nothing off-web
# or if the file isn't there yet.
static func download(path: String) -> void:
	if not is_web() or not FileAccess.file_exists(path):
		return
	JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), path.get_file())
