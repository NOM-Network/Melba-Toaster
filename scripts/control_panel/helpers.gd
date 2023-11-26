extends Node
class_name CpHelpers

static var overrides := ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]
static var status_overrides := []

static func construct_model_control_buttons(
	type: String,
	parent: Node,
	controls: Dictionary,
	target_call = null
) -> void:
	var callback: Signal
	var button_type := Button
	match type:
		"animations":
			callback = Globals.play_animation

		"pinnable_assets":
			callback = Globals.pin_asset
			button_type = CheckButton

		"expressions":
			callback = Globals.set_expression

		"toggles":
			callback = Globals.play_animation
			button_type = CheckButton

	for control in controls:
		var button = button_type.new()
		button.text = control
		button.name = type.capitalize() + control.to_pascal_case()
		button.focus_mode = Control.FOCUS_NONE

		if type in ["toggles", "pinnable_assets"]:
			button.button_pressed = controls[control].enabled
			button.pressed.connect(target_call.bind(button))
		else:
			button.pressed.connect(func (): callback.emit(control))

		parent.add_child(button)

static func change_toggle_state(
	toggle: Button,
	button_pressed: bool,
	enabled_text := ">>> STOP <<<",
	disabled_text := "Start",
	apply_color = true,
):
	toggle.set_pressed_no_signal(button_pressed)
	toggle.text = enabled_text if button_pressed else disabled_text

	if apply_color:
		apply_color_override(toggle, button_pressed, Color.RED)

static func apply_color_override(
	node: Node,
	state: bool,
	active_color: Color,
	inactive_color = null,
):
	for i in overrides:
		if not state and not inactive_color:
			node.remove_theme_color_override(i)
		else:
			node.add_theme_color_override(i, active_color if state else inactive_color)

static func change_status_color(node: Button, active: bool) -> void:
	node.self_modulate = Color.GREEN if active else Color.RED

static func array_to_string(arr: Array) -> String:
	var s := ""
	for i in arr:
		s += String(i) + " "
	return s

static func clear_node(node: Node):
	for i in node.get_children():
		i.queue_free()
