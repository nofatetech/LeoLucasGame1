# Studio dock - browse a Show's seasons/episodes and Preview/Render them.
# Pure tooling: it shells out to the SAME render CLI we use by hand (see docs/export.md),
# so the panel adds no engine logic. UI is built in code to avoid a fragile .tscn.
@tool
extends VBoxContainer

const MAIN_SCENE := "res://scenes/main.tscn"

var _tree: Tree
var _status: Label
var _show: Show

var _render_pid: int = -1
var _render_target: EpisodeRef = null
var _queue: Array = []
var _poll: Timer

func _enter_tree() -> void:
	_build_ui()
	_reload()

# --- UI ---

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 0)
	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = "🎬 Studio"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_add_button(header, "Reload", _reload)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 220)
	add_child(_tree)

	var actions := HBoxContainer.new()
	add_child(actions)
	_add_button(actions, "Preview", _on_preview)
	_add_button(actions, "Render", _on_render)
	_add_button(actions, "Render all", _on_render_all)
	_add_button(actions, "Open output", _on_open_output)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_poll = Timer.new()
	_poll.wait_time = 1.0
	_poll.timeout.connect(_check_render)
	add_child(_poll)

func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _reload() -> void:
	_show = _find_show()
	_tree.clear()
	if _show == null:
		_status.text = "No Show .tres found under res://shows/"
		return
	var root := _tree.create_item()
	var show_item := _tree.create_item(root)
	show_item.set_text(0, "%s   (lang=%s, %dfps)" % [_show.title, _show.default_language, _show.fps])
	for season in _show.seasons:
		var s_item := _tree.create_item(show_item)
		s_item.set_text(0, "S%02d  %s" % [season.number, season.title])
		for ep in season.episodes:
			var e_item := _tree.create_item(s_item)
			var mark := "✅" if ep.status == "rendered" else "•"
			e_item.set_text(0, "%s E%02d  %s" % [mark, ep.number, ep.title])
			e_item.set_metadata(0, ep)
	_status.text = "Loaded '%s'" % _show.title

# --- actions ---

func _on_preview() -> void:
	var ep := _selected_episode()
	if ep == null:
		return
	OS.create_process(_godot_bin(), [
		"--path", _project_dir(), MAIN_SCENE,
		"--", "--episode", ep.md_path, "--language", _structural_language(ep)])
	_status.text = "Preview: %s" % ep.title

func _on_render() -> void:
	var ep := _selected_episode()
	if ep:
		_render_one(ep)

func _on_render_all() -> void:
	if _show == null:
		return
	_queue.clear()
	for season in _show.seasons:
		for ep in season.episodes:
			_queue.append(ep)
	_status.text = "Queued %d episodes" % _queue.size()
	_next_in_queue()

func _on_open_output() -> void:
	var ep := _selected_episode()
	if ep and ep.last_output != "" and FileAccess.file_exists(ep.last_output):
		OS.shell_open(ep.last_output.get_base_dir())
	elif _show:
		var dir := ProjectSettings.globalize_path(_show.output_dir)
		DirAccess.make_dir_recursive_absolute(dir)
		OS.shell_open(dir)

# --- render plumbing ---

func _render_one(ep: EpisodeRef) -> void:
	if _render_pid != -1 and OS.is_process_running(_render_pid):
		_status.text = "Render busy — wait for the current one"
		return
	var out_dir := ProjectSettings.globalize_path(_show.output_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out := out_dir.path_join(ep.md_path.get_file().get_basename() + ".avi")
	var args := [
		"--path", _project_dir(),
		"--fixed-fps", str(_show.fps),
		"--write-movie", out,
		MAIN_SCENE,
		"--", "--render", "--episode", ep.md_path, "--language", _structural_language(ep)]
	_render_pid = OS.create_process(_godot_bin(), args)
	if _render_pid <= 0:
		_status.text = "Failed to launch render"
		return
	_render_target = ep
	ep.last_output = out
	_status.text = "Rendering '%s' → %s" % [ep.title, out.get_file()]
	_poll.start()

func _check_render() -> void:
	if _render_pid == -1:
		_poll.stop()
		return
	if OS.is_process_running(_render_pid):
		return
	# finished
	_render_pid = -1
	if _render_target:
		_render_target.status = "rendered"
		_save_show()
		_status.text = "Done: %s" % _render_target.last_output.get_file()
		_render_target = null
		_reload()
	if _queue.is_empty():
		_poll.stop()
	else:
		_next_in_queue()

func _next_in_queue() -> void:
	if not _queue.is_empty():
		_render_one(_queue.pop_front())

# --- helpers ---

# Structural language fallback (below the .md's own `language:`): episode -> season -> show.
func _structural_language(ep: EpisodeRef) -> String:
	if ep.language != "":
		return ep.language
	for season in _show.seasons:
		if season.episodes.has(ep):
			return season.language if season.language != "" else _show.default_language
	return _show.default_language

func _selected_episode() -> EpisodeRef:
	var item := _tree.get_selected()
	if item == null:
		_status.text = "Select an episode first"
		return null
	var meta = item.get_metadata(0)
	if meta is EpisodeRef:
		return meta
	_status.text = "Select an episode (not a show/season row)"
	return null

func _save_show() -> void:
	if _show and _show.resource_path != "":
		ResourceSaver.save(_show, _show.resource_path)

func _godot_bin() -> String:
	return OS.get_executable_path()

func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://")

func _find_show() -> Show:
	for path in _tres_under("res://shows"):
		var r = load(path)
		if r is Show:
			return r
	return null

func _tres_under(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out += _tres_under(path)
		elif name.ends_with(".tres"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	return out
