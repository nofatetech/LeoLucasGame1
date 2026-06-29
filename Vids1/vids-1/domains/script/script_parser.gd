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
	# inline directives on a dialogue line fire at the line's start (Point/Span).
	var stripped := _strip_directives(rest)
	rest = stripped.text
	var emote := ""
	if rest.begins_with("("):                          # optional (emote) prefix
		var close := rest.find(")")
		if close != -1:
			emote = rest.substr(1, close - 1).strip_edges()
			rest = rest.substr(close + 1).strip_edges()
	ep.beats.append({
		"type": "say", "speaker": ep.resolve(alias),
		"text": rest, "emote": emote, "lang": lang, "scene": scene,
		"directives": stripped.events,
	})

# Directive-only line: each [..] becomes its own beat at the current playhead.
static func _parse_directive_line(line: String, ep: EpisodeScript) -> void:
	for ev in _strip_directives(line).events:
		ep.beats.append(ev)

# Pull every [verb: args] out of text, returning the cleaned text plus normalized events.
static func _strip_directives(text: String) -> Dictionary:
	var events := []
	var out := ""
	var j := 0
	while j < text.length():
		if text[j] == "[":
			var k := text.find("]", j)
			if k == -1:
				out += text.substr(j)
				break
			var ev := _normalize(text.substr(j + 1, k - j - 1))
			if not ev.is_empty():
				events.append(ev)
			j = k + 1
		else:
			out += text[j]
			j += 1
	return {"text": out.strip_edges(), "events": events}

# Turn a raw directive body into a beat-shaped event, or {} if unknown.
static func _normalize(inner: String) -> Dictionary:
	var verb := inner
	var args := ""
	var c := inner.find(":")
	if c != -1:
		verb = inner.substr(0, c).strip_edges()
		args = inner.substr(c + 1).strip_edges()
	var name := ""
	var action := ""
	var offset := 0.0
	for tok in args.split(" ", false):
		if tok.begins_with("+") or tok.begins_with("-"):
			offset = float(tok)
		elif tok == "start" or tok == "stop":
			action = tok
		else:
			name = tok
	match verb:
		"wait": return {"type": "wait", "seconds": float(name)}
		"sfx": return {"type": "sfx", "name": name, "offset": offset}
		"ambience": return {"type": "ambience", "name": name, "action": action if action else "start"}
		"music": return {"type": "music", "name": name, "action": action if action else "start"}
		_:
			push_warning("Directive not yet supported, skipped: [%s]" % verb)
			return {}

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
