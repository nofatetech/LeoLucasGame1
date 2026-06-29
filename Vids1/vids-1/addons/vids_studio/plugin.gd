# Vids Studio - editor plugin that mounts the Studio dock.
@tool
extends EditorPlugin

const DockScript := preload("res://addons/vids_studio/studio_dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Studio"
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.free()
