# CharacterArt - builds a character's LOOK at runtime from CharacterData, for the shared
# data-driven base scene (character_base.tscn). Bespoke hand-authored .tscn characters don't
# use this — they draw their own nodes. Two modes: flat procedural shapes, or image cutouts.
#
# Everything is drawn to the same native footprint the composition assumes: feet at origin,
# ~224px tall, head centred at (0,-168) — matching the hand-authored cast so a data character
# frames identically. See Director._CHAR_NATIVE_H.
class_name CharacterArt
extends RefCounted

const NATIVE_H := 224.0
const HEAD_Y := -168.0
const HEAD_R := 56.0

## Populate `char` (root) + its "Mouth" node with visuals derived from `data`.
static func build(char: Node2D, data: CharacterData) -> void:
	if data == null:
		return
	var mouth := char.get_node_or_null("Mouth") as Node2D
	if data.look == "image":
		_build_image(char, mouth, data)
	else:
		_build_procedural(char, mouth, data)

# --- procedural: flat shapes, parametrised by colour (our default look) ---

static func _build_procedural(char: Node2D, mouth: Node2D, data: CharacterData) -> void:
	# Body: a simple trapezoid standing on the origin.
	_add_polygon(char, "Body", PackedVector2Array([
		Vector2(-34, 0), Vector2(34, 0), Vector2(44, -118), Vector2(-44, -118)]),
		data.body_color)
	# Head: a disc.
	_add_polygon(char, "Head", _circle(HEAD_R), data.skin_color, Vector2(0, HEAD_Y))
	# Hair: an upper cap (drawn before eyes so eyes sit on top).
	if data.has_hair:
		_add_polygon(char, "Hair", _cap(HEAD_R + 2.0), data.hair_color, Vector2(0, HEAD_Y))
	# Eyes: whites + pupils.
	for side in [-1, 1]:
		var at := Vector2(20 * side, HEAD_Y - 8)
		_add_polygon(char, "EyeWhite%d" % side, _circle(13, 12), Color.WHITE, at)
		_add_polygon(char, "Pupil%d" % side, _circle(5, 10), data.eye_color, at)
	# Mouth: one shape the Mouth node scales open (single-shape mode of mouth.gd).
	if mouth:
		mouth.position = Vector2(0, -140)
		_add_polygon(mouth, "Shape", PackedVector2Array([
			Vector2(22, 0), Vector2(0, 14), Vector2(-22, 0), Vector2(0, -14)]),
			Color(0.1, 0.05, 0.05))

# --- image: PNG/WebP/SVG cutouts (public-domain / photo cast) ---

static func _build_image(char: Node2D, mouth: Node2D, data: CharacterData) -> void:
	if data.body_texture == null:
		# No art yet — fall back to a neutral procedural body so the script still renders.
		_build_procedural(char, mouth, data)
		return
	# Auto-scale the figure to the native height so composition frames it like any character,
	# then centre it with feet on the origin.
	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = data.body_texture
	var h := float(data.body_texture.get_height())
	var s := (NATIVE_H / h) if h > 0.0 else 1.0
	body.scale = Vector2(s, s)
	body.centered = true
	body.position = Vector2(0, -NATIVE_H * 0.5)
	char.add_child(body)
	# Mouth: swap between closed/open cutouts when both are supplied (2-shape mode of mouth.gd).
	if mouth and data.mouth_closed and data.mouth_open:
		mouth.position = data.mouth_offset
		_add_sprite(mouth, "Closed", data.mouth_closed)
		_add_sprite(mouth, "Open", data.mouth_open)

# --- primitives ---

static func _add_polygon(parent: Node, name: String, poly: PackedVector2Array,
		color: Color, at := Vector2.ZERO) -> void:
	var p := Polygon2D.new()
	p.name = name
	p.polygon = poly
	p.color = color
	p.position = at
	parent.add_child(p)

static func _add_sprite(parent: Node, name: String, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.name = name
	s.texture = tex
	parent.add_child(s)

static func _circle(radius: float, sides := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

## A filled upper cap (top half of a disc) — a simple hairline.
static func _cap(radius: float, sides := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides + 1:
		var a := PI + PI * float(i) / float(sides)   # PI..TAU sweeps the top rim
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
