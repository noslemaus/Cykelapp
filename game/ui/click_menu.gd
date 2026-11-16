extends RefCounted
## The menu over a ride for the Zwift Click: Y opens it and the ride's buttons get a white marker,
## the left Click's arrows move it (Controls.MENU_KEYS), A presses the marked button and B goes back
## (out of the settings, or closes the menu); Y again closes it. Used by the world HUD and the gym
## screen. The marker starts on Inställningar, not Avsluta: an A too many must not end the ride.

const FOCUS_RING := Color(1, 1, 1, 0.95)

var host: Control
var buttons: Array[Button] = []
var first: Button = null              # where the marker starts
var settings: Callable                # () -> the settings open over the ride, or null
var toggle_settings: Callable         # opens or closes them
var open := false


func _init(owner: Control, get_settings: Callable, settings_toggle: Callable) -> void:
    host = owner
    settings = get_settings
    toggle_settings = settings_toggle


func toggle() -> void:
    if open:
        close()
    else:
        open_menu()


func open_menu() -> void:
    open = true
    Controls.menu_open = true
    for b in buttons:
        if is_instance_valid(b):
            focusable(b)
    var s = settings.call()
    if s:
        focus_settings(s)
    elif first and is_instance_valid(first):
        first.grab_focus()


func close() -> void:
    if settings.call():
        toggle_settings.call()
    open = false
    Controls.menu_open = false
    if host.is_inside_tree():
        host.get_viewport().gui_release_focus()
    for b in buttons:
        if is_instance_valid(b):
            b.focus_mode = Control.FOCUS_NONE


## B: out of the settings back to the ride's buttons, or close the menu.
func back() -> void:
    if settings.call():
        toggle_settings.call()
        if first and is_instance_valid(first):
            first.grab_focus()
    else:
        close()


static func focusable(c: Control) -> void:
    c.focus_mode = Control.FOCUS_ALL
    var ring := StyleBoxFlat.new()
    ring.draw_center = false
    ring.set_border_width_all(4)
    ring.border_color = FOCUS_RING
    ring.set_corner_radius_all(18)
    ring.set_expand_margin_all(3)
    c.add_theme_stylebox_override("focus", ring)


## Everything in the settings that can be chosen gets the marker; the first tab gets it first.
func focus_settings(s: Node) -> void:
    var first_button: Control = null
    var stack: Array[Node] = [s]
    while not stack.is_empty():
        var n: Node = stack.pop_front()
        if n is BaseButton or (n is Range and not (n is ProgressBar)):
            focusable(n)
            if first_button == null and n is BaseButton and n.is_visible_in_tree():
                first_button = n
        stack.append_array(n.get_children())
    if first_button:
        first_button.grab_focus()
