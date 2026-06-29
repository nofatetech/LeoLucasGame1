# Logger - simple level-gated logging, mirrors the sibling project's convention.
extends Node

enum Level { DEBUG, INFO, WARNING, ERROR }

var current_level: Level = Level.DEBUG

func debug(msg: String, context: String = "") -> void:
	if current_level <= Level.DEBUG:
		_print("DEBUG", msg, context)

func info(msg: String, context: String = "") -> void:
	if current_level <= Level.INFO:
		_print("INFO ", msg, context)

func warning(msg: String, context: String = "") -> void:
	if current_level <= Level.WARNING:
		_print("WARN ", msg, context)

func error(msg: String, context: String = "") -> void:
	_print("ERROR", msg, context)
	push_error(msg)

func _print(prefix: String, msg: String, context: String) -> void:
	var ctx := " [" + context + "]" if context else ""
	print("[%s]%s %s" % [prefix, ctx, msg])
