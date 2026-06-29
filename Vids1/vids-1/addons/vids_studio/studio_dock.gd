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
var _ffmpeg_checked := false
var _ffmpeg_ok := false
var _new_menu: PopupMenu
var _template_paths: Array = []

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
	_add_button(actions, "New…", _on_new_from_template)
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
	# Preview shows shaders at the default window size (resolution/aspect is a render-time concern).
	OS.create_process(_godot_bin(), [
		"--path", _project_dir(), MAIN_SCENE,
		"--", "--episode", ep.md_path, "--language", _structural_language(ep),
		"--style", _structural_style(ep)])
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

# --- new from template ---

# Pop a menu of the format skeletons in templates/episodes/; choosing one copies it into
# episodes/ and registers an EpisodeRef so it shows in the tree, ready to edit + render.
func _on_new_from_template() -> void:
	_template_paths = _list_templates()
	if _template_paths.is_empty():
		_status.text = "No templates in res://templates/episodes/"
		return
	if _show == null:
		_status.text = "Load a Show first (none under res://shows/)"
		return
	if _new_menu == null:
		_new_menu = PopupMenu.new()
		_new_menu.id_pressed.connect(_create_from_template)
		add_child(_new_menu)
	_new_menu.clear()
	for idx in _template_paths.size():
		_new_menu.add_item(_template_paths[idx].get_file().get_basename().capitalize(), idx)
	_new_menu.reset_size()
	_new_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))

func _create_from_template(idx: int) -> void:
	var src: String = _template_paths[idx]
	var format := src.get_file().get_basename()
	# Pick a unique destination so repeated "New" calls never clobber an existing episode.
	var dest := "res://episodes/new_%s.md" % format
	var n := 2
	while FileAccess.file_exists(dest):
		dest = "res://episodes/new_%s_%d.md" % [format, n]
		n += 1
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		_status.text = "Could not write " + dest
		return
	f.store_string(FileAccess.get_file_as_string(src))
	f.close()
	var season = _show.seasons[0] if not _show.seasons.is_empty() else _new_season()
	var ep := EpisodeRef.new()
	ep.md_path = dest
	ep.title = "New %s" % format.capitalize()
	ep.number = season.episodes.size() + 1
	season.episodes.append(ep)
	_save_show()
	_reload()
	_status.text = "Created %s — edit it, then Render" % dest.get_file()

func _new_season() -> Season:
	var s := Season.new()
	s.title = "Season 1"
	_show.seasons.append(s)
	return s

func _list_templates() -> Array:
	var out := []
	var dir := "res://templates/episodes"
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".md") and name != "README.md":
			out.append(dir.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

# --- render plumbing ---

func _render_one(ep: EpisodeRef) -> void:
	if _render_pid != -1 and OS.is_process_running(_render_pid):
		_status.text = "Render busy — wait for the current one"
		return
	var out_dir := ProjectSettings.globalize_path(_show.output_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out := out_dir.path_join(ep.md_path.get_file().get_basename() + ".avi")
	var style := _structural_style(ep)
	_write_override(style)   # resolution is baked at launch via override.cfg
	var args := [
		"--path", _project_dir(),
		"--fixed-fps", str(_show.fps),
		"--write-movie", out,
		MAIN_SCENE,
		"--", "--render", "--episode", ep.md_path,
		"--language", _structural_language(ep), "--style", style]
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
	_clear_override()
	if _render_target:
		# Godot's MJPEG AVI plays poorly in many players; transcode to MP4 when ffmpeg exists.
		_render_target.last_output = _maybe_transcode(_render_target.last_output)
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

# Render style: episode override else show default.
func _structural_style(ep: EpisodeRef) -> String:
	return ep.style if ep.style != "" else _show.style

# Movie Maker bakes the project viewport size at launch, so a non-default resolution must
# come from override.cfg (written before launch, removed when the render finishes).
func _write_override(style_name: String) -> void:
	var s := StyleLibrary.get_style(style_name)
	if s == null or not s.has_resolution():
		return
	var f := FileAccess.open("res://override.cfg", FileAccess.WRITE)
	if f:
		f.store_string("[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\n" % [
			s.resolution.x, s.resolution.y])
		f.close()

func _clear_override() -> void:
	var p := ProjectSettings.globalize_path("res://override.cfg")
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

# --- transcode ---

# AVI(MJPEG) -> MP4(H.264) so the output plays in every player/browser.
# No-op (returns the AVI) when ffmpeg isn't on PATH, so renders still succeed.
func _maybe_transcode(avi_path: String) -> String:
	if avi_path == "" or not FileAccess.file_exists(avi_path):
		return avi_path
	if avi_path.get_extension().to_lower() != "avi":
		return avi_path
	if not _ffmpeg_available():
		return avi_path
	var mp4 := avi_path.get_basename() + ".mp4"
	var out: Array = []
	var code := OS.execute("ffmpeg", [
		"-y", "-i", avi_path,
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac",
		mp4], out, true)
	if code == 0 and FileAccess.file_exists(mp4):
		DirAccess.remove_absolute(avi_path)  # keep just the playable one
		return mp4
	return avi_path  # leave the AVI if transcode failed

func _ffmpeg_available() -> bool:
	if not _ffmpeg_checked:
		_ffmpeg_checked = true
		_ffmpeg_ok = OS.execute("ffmpeg", ["-version"]) == 0
	return _ffmpeg_ok

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
