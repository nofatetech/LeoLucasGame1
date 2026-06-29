# Mouth - the one moving part the Director drives. Attach to a "Mouth" node inside a
# cast scene. Hand-edit it two ways:
#   - Simple: one child shape (e.g. a Polygon2D). It scales vertically with openness.
#   - South-Park style: 2+ child shapes (closed -> open order). It swaps between them.
# Either way the contract to Character is just set_open(amount).
class_name Mouth
extends Node2D

## Vertical scale when fully closed, for the single-shape (scaling) mode.
@export var min_scale: float = 0.12

func set_open(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	var shapes := _shapes()
	if shapes.size() >= 2:
		# Discrete swap: pick the shape for this openness, hide the rest.
		var idx := clampi(int(amount * shapes.size()), 0, shapes.size() - 1)
		for i in shapes.size():
			shapes[i].visible = (i == idx)
	else:
		# Single shape: stretch it open.
		scale.y = lerpf(min_scale, 1.0, amount)

func _shapes() -> Array:
	var out := []
	for c in get_children():
		if c is CanvasItem:
			out.append(c)
	return out
