# MediaLibrary - resolves a slide/media name to a loadable asset for the Director's
# presentation layer. Mirrors AudioLibrary's philosophy: names resolve to real files under
# res://media/ (drop assets in by name later), and a missing asset yields a deterministic
# placeholder so a script renders before the art exists.
#
# Images: png / webp / jpg / svg (TextureRect). Video: ogv (Godot plays Ogg Theora natively;
# the Studio dock can transcode other formats in — see plan-moviemaking media notes).
class_name MediaLibrary
extends RefCounted

const MEDIA_DIR := "res://media"
const IMAGE_EXTS := ["png", "webp", "jpg", "jpeg", "svg"]
const VIDEO_EXTS := ["ogv"]

## Returns {kind: "image"|"video"|"missing", name, texture?: Texture2D, stream?: VideoStream}.
static func resolve(name: String) -> Dictionary:
	var path := _find(name)
	if path == "":
		return {"kind": "missing", "name": name}
	if path.get_extension().to_lower() in VIDEO_EXTS:
		return {"kind": "video", "name": name, "stream": load(path)}
	return {"kind": "image", "name": name, "texture": load(path)}

# Accept a direct res:// path, an explicit file under media/, or a bare name to probe by ext.
static func _find(name: String) -> String:
	if name == "":
		return ""
	var candidates := []
	if name.begins_with("res://"):
		candidates.append(name)
	elif name.get_extension() != "":
		candidates.append(MEDIA_DIR.path_join(name))
	else:
		for ext in IMAGE_EXTS + VIDEO_EXTS:
			candidates.append(MEDIA_DIR.path_join(name + "." + ext))
	for c in candidates:
		if ResourceLoader.exists(c):
			return c
	return ""
