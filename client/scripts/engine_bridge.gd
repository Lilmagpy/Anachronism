## Talks to the Python engine (`anachronism-server`) over stdin/stdout, one JSON line each way.
## The engine is the only authority on rules; this client only shows views and sends actions.
class_name EngineBridge
extends RefCounted

var _pipe: FileAccess
var _pid := -1
var _next_id := 1
var last_error := ""


## Start the engine. `repo_root` is the folder holding pyproject.toml.
func start(repo_root: String) -> bool:
	var uv := OS.get_environment("ANACHRONISM_UV")
	if uv == "":
		uv = "uv"
	var info := OS.execute_with_pipe(uv, ["run", "--project", repo_root, "anachronism-server"])
	if info.is_empty():
		last_error = "Could not start the game engine (is uv installed?)"
		return false
	_pipe = info["stdio"]
	_pid = info["pid"]
	return true


## Send a command and wait for its reply. Returns the result, or null on error (see last_error).
func request(cmd: String, args: Dictionary = {}) -> Variant:
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
	if _pipe != null:
		request("quit")
		_pipe = null
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
