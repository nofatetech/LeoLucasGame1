# ScriptParser - turns an episode .md into an EpisodeScript. Subset of docs/timeline-spec.md:
# frontmatter (episode/title/cast), "## Scene:" headers, dialogue lines, and [wait]/directives.
# Forward-compatible: unknown directives warn and are skipped, never fatal.
class_name ScriptParser
extends RefCounted

static func parse_file(path: String) -> EpisodeScript:
	if not FileAccess.file_exists(path):
		push_error("Episode not found: " + path)
		return EpisodeScript.new()
	return parse_text(FileAccess.get_file_as_string(path))

static func parse_text(text: String) -> EpisodeScript:
	var ep := EpisodeScript.new()
	var lines := text.split("\n")
	var i := 0

	# --- frontmatter ---
	if lines.size() > 0 and lines[0].strip_edges() == "---":
		i = 1
		while i < lines.size() and lines[i].strip_edges() != "---":
			_parse_front_line(lines[i], ep)
			i += 1
		i += 1   # skip closing ---

	# --- body ---
	var scene := ""
	while i < lines.size():
		var line := lines[i].strip_edges()
		i += 1
		if line == "":
			continue
		if line.begins_with("## Scene:"):
			scene = line.substr(9).strip_edges()
			continue
		if line.begins_with("#"):
			continue                                  # heading / comment
		if line.begins_with("["):
			_parse_directive_line(line, ep)           # [wait] becomes a beat; others warn
			continue
		var colon := line.find(":")
		if colon > 0:
			_parse_dialogue(line, colon, scene, ep)
	return ep

static func _parse_dialogue(line: String, colon: int, scene: String, ep: EpisodeScript) -> void:
	var alias := line.substr(0, colon).strip_edges()
	var rest := line.substr(colon + 1).strip_edges()
	# optional per-line language override: "leo@en: ..."
	var lang := ""
	var at := alias.find("@")
	if at != -1:
		lang = alias.substr(at + 1).strip_edges()
		alias = alias.substr(0, at).strip_edges()
	var emote := ""
	if rest.begins_with("("):                          # optional (emote) prefix
		var close := rest.find(")")
		if close != -1:
			emote = rest.substr(1, close - 1).strip_edges()
			rest = rest.substr(close + 1).strip_edges()
	ep.beats.append({
		"type": "say", "speaker": ep.resolve(alias),
		"text": rest, "emote": emote, "lang": lang, "scene": scene,
	})

static func _parse_directive_line(line: String, ep: EpisodeScript) -> void:
	for d in _extract_directives(line):
		if d.verb == "wait":
			ep.beats.append({"type": "wait", "seconds": float(d.args)})
		else:
			push_warning("Directive not yet supported, skipped: [%s]" % d.verb)

static func _extract_directives(line: String) -> Array:
	var out := []
	var j := 0
	while j < line.length():
		if line[j] == "[":
			var k := line.find("]", j)
			if k == -1:
				break
			out.append(_parse_directive(line.substr(j + 1, k - j - 1)))
			j = k + 1
		else:
			j += 1
	return out

static func _parse_directive(inner: String) -> Dictionary:
	var c := inner.find(":")
	if c != -1:
		return {"verb": inner.substr(0, c).strip_edges(), "args": inner.substr(c + 1).strip_edges()}
	return {"verb": inner.strip_edges(), "args": ""}

static func _parse_front_line(raw: String, ep: EpisodeScript) -> void:
	var line := raw.strip_edges()
	var colon := line.find(":")
	if colon <= 0:
		return
	var key := line.substr(0, colon).strip_edges()
	var val := line.substr(colon + 1).strip_edges()
	match key:
		"episode": ep.episode = _unquote(val)
		"title": ep.title = _unquote(val)
		"language": ep.language = _unquote(val)
		"cast": ep.cast = _parse_inline_map(val)

static func _parse_inline_map(val: String) -> Dictionary:
	var out := {}
	val = val.strip_edges()
	if val.begins_with("{"): val = val.substr(1)
	if val.ends_with("}"): val = val.substr(0, val.length() - 1)
	for pair in val.split(","):
		var c := pair.find(":")
		if c != -1:
			out[pair.substr(0, c).strip_edges()] = pair.substr(c + 1).strip_edges()
	return out

static func _unquote(s: String) -> String:
	s = s.strip_edges()
	if s.length() >= 2 and (s.begins_with("\"") and s.ends_with("\"")):
		return s.substr(1, s.length() - 2)
	return s
