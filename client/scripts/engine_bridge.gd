## Talks to the Python engine (`anachronism-server`) over stdin/stdout, one JSON line each way.
## The engine is the only authority on rules; this client only shows views and sends actions.
class_name EngineBridge
extends RefCounted

var _pipe: FileAccess
var _pid := -1
var _next_id := 1
var last_error := ""
var busy := false          ## a request is running on the worker thread
var _lock := Mutex.new()
var _worker: Thread


## Where the packaged app keeps the engine's files, Python and saves (user data folder).
const PACKED_ENGINE := "res://engine_src"


## Start the engine. Run from the source code (the Godot editor binary), it uses the Python
## project at `repo_root`; an exported app unpacks the copy bundled inside it instead.
func start(repo_root: String) -> bool:
	var args: PackedStringArray
	var uv := OS.get_environment("ANACHRONISM_UV")
	if OS.has_feature("editor"):
		if uv == "":
			uv = _find_uv()
		args = ["run", "--project", repo_root, "anachronism-server"]
	else:
		var engine := _unpack()
		if engine == "":
			return false
		uv = engine.path_join(_uv_file())
		var home := OS.get_user_data_dir()
		OS.set_environment("UV_PROJECT_ENVIRONMENT", home.path_join("python-env"))
		OS.set_environment("UV_PYTHON_INSTALL_DIR", home.path_join("python"))
		OS.set_environment("UV_PYTHON_PREFERENCE", "only-managed")  # never the Mac's old Python
		OS.set_environment("UV_CACHE_DIR", home.path_join("uv-cache"))
		OS.set_environment("ANACHRONISM_SAVES", home.path_join("saves"))
		args = ["run", "--project", engine, "--locked", "--no-dev", "anachronism-server"]
		if _windows():
			# nobody reads uv's progress lines, and a Windows pipe holds only 4 KB of them
			# before the writer blocks: keep uv silent there
			args.insert(1, "--quiet")
	# the engine reads and writes UTF-8 whatever the machine's code page is (Windows: cp1252)
	OS.set_environment("PYTHONUTF8", "1")
	var info := OS.execute_with_pipe(uv, args)
	if info.is_empty():
		last_error = "Could not start the game engine (%s)" % uv
		return false
	_pipe = info["stdio"]
	_pid = info["pid"]
	return true


## uv is often not on the PATH of apps started from the Finder, so look where it installs.
func _find_uv() -> String:
	if _windows():
		var profile := OS.get_environment("USERPROFILE")
		for candidate in [profile.path_join(".local/bin/uv.exe"), profile.path_join(".cargo/bin/uv.exe")]:
			if FileAccess.file_exists(candidate):
				return candidate
		return "uv"
	var home := OS.get_environment("HOME")
	for candidate in [home.path_join(".local/bin/uv"), home.path_join(".cargo/bin/uv"),
			"/opt/homebrew/bin/uv", "/usr/local/bin/uv"]:
		if FileAccess.file_exists(candidate):
			return candidate
	return "uv"


## Copies the bundled engine (Python source, lock file and uv) out of the app into the user
## data folder, once per build. Returns that folder, or "" on failure (see last_error).
func _unpack() -> String:
	var stamp := FileAccess.get_file_as_string(PACKED_ENGINE.path_join("STAMP")).strip_edges()
	if stamp == "":
		last_error = "This build of the game is missing its engine"
		return ""
	var target := OS.get_user_data_dir().path_join("engine-" + stamp)
	if not FileAccess.file_exists(target.path_join(_uv_file())):
		if not _copy_tree(PACKED_ENGINE, target):
			last_error = "Could not unpack the game engine into " + target
			return ""
		var dir := DirAccess.open(target.path_join("bin"))
		if _windows():
			# one build for every PC: Windows on ARM runs the x86-64 program as it stands
			dir.rename("uv-x86_64.exe", "uv.exe")
		else:
			var arch := "aarch64" if Engine.get_architecture_name() == "arm64" else "x86_64"
			dir.rename("uv-" + arch, "uv")
			OS.execute("/bin/chmod", ["+x", target.path_join("bin/uv")])
	return target


func _windows() -> bool:
	return OS.get_name() == "Windows"


## The bundled uv, inside the unpacked engine folder.
func _uv_file() -> String:
	return "bin/uv.exe" if _windows() else "bin/uv"


func _copy_tree(from: String, to: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(to) != OK:
		return false
	for file in DirAccess.get_files_at(from):
		var data := FileAccess.get_file_as_bytes(from.path_join(file))
		var out := FileAccess.open(to.path_join(file), FileAccess.WRITE)
		if out == null:
			return false
		out.store_buffer(data)
		out.close()
	for sub in DirAccess.get_directories_at(from):
		if not _copy_tree(from.path_join(sub), to.path_join(sub)):
			return false
	return true


## Send a command and wait for its reply. Returns the result, or null on error (see last_error).
## Send a request on a worker thread, so the window stays responsive while the engine thinks
## (a ruling by a language model can take several seconds). `done` is called on the main
## thread with the result, or null on failure (see `last_error`).
func request_async(cmd: String, args: Dictionary, done: Callable) -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
	busy = true
	_worker = Thread.new()
	_worker.start(func():
		var result: Variant = request(cmd, args)
		_finish.call_deferred(result, done))


func _finish(result: Variant, done: Callable) -> void:
	if _worker != null:
		_worker.wait_to_finish()
		_worker = null
	busy = false
	done.call(result)


func request(cmd: String, args: Dictionary = {}) -> Variant:
	_lock.lock()
	var result: Variant = _request(cmd, args)
	_lock.unlock()
	return result


func _request(cmd: String, args: Dictionary) -> Variant:
	if _pipe == null:
		last_error = "The game engine is not running"
		return null
	var id := _next_id
	_next_id += 1
	_pipe.store_line(JSON.stringify({"id": id, "cmd": cmd, "args": args}))
	_pipe.flush()
	var line := _pipe.get_line()
	var reply: Variant = JSON.parse_string(line)
	if typeof(reply) != TYPE_DICTIONARY:
		last_error = "The game engine sent an unreadable reply"
		return null
	if not reply.get("ok", false):
		last_error = str(reply.get("error", "unknown error"))
		return null
	return reply.get("result")


func stop() -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
	if _pipe != null:
		request("quit")
		_pipe = null
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
