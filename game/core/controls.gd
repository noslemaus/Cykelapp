extends Node
## The game's actions and what triggers them, autoloaded as `Controls`. Keyboard keys and the
## buttons of the Zwift Click pair both become the same Godot input actions, so the screens only
## ever ask Input for an action ("styr_vanster", "tyngre" …). Which Click button does what is a
## setting (Settings.button_bindings); the keyboard keys are fixed.

## Actions in the order they are offered, with the label shown when binding and their keys.
const ACTIONS := [
    ["ingen", "Ingenting", []],
    ["styr_vanster", "Sväng vänster", [KEY_A]],
    ["styr_hoger", "Sväng höger", [KEY_D]],
    ["tyngre", "Tyngre (växel, watt eller intensitet)", [KEY_UP]],
    ["lattare", "Lättare (växel, watt eller intensitet)", [KEY_DOWN]],
    ["titta_vanster", "Titta vänster", [KEY_LEFT]],
    ["titta_hoger", "Titta höger", [KEY_RIGHT]],
    ["nasta_steg", "Nästa steg i passet", [KEY_ENTER, KEY_KP_ENTER]],
    ["paus", "Paus", [KEY_SPACE]],
    ["byt_lage", "Byt ERG/SIM", [KEY_M]],
    ["skjut", "Skjut (stridsvagnen i fri cykling)", [KEY_F]],
    ["installningar", "Inställningar under turen", [KEY_ESCAPE]],
    ["meny", "Menyn under turen (visa/dölj)", [KEY_TAB]],
    ["karta", "Stora kartan (visa/dölj)", [KEY_K]],
]

## The ten buttons of a Click v2 pair, as the bridge names them, with a label for the settings.
const BUTTONS := [
    ["v_vanster", "Vänster Click: vänster"], ["v_hoger", "Vänster Click: höger"],
    ["v_upp", "Vänster Click: upp"], ["v_ner", "Vänster Click: ner"], ["v_vaxla", "Vänster Click: −"],
    ["h_a", "Höger Click: A"], ["h_b", "Höger Click: B"], ["h_y", "Höger Click: Y"], ["h_z", "Höger Click: Z"],
    ["h_vaxla", "Höger Click: +"],
]

## Out of the box: steer with the left arrows, shift with − and +, Y opens the menu over the ride,
## Z shoots (the tank), A skips to the next step and B switches ERG/SIM.
const DEFAULT_BINDINGS := {
    "v_vanster": "styr_vanster", "v_hoger": "styr_hoger", "v_upp": "ingen", "v_ner": "ingen",
    "v_vaxla": "lattare", "h_vaxla": "tyngre", "h_y": "meny", "h_z": "skjut",
    "h_a": "nasta_steg", "h_b": "byt_lage",
}

## While the menu over the ride is open, the left arrows move between its buttons, A presses the
## one marked and B goes back, whatever they are bound to; Y (the menu button) closes it again.
const MENU_KEYS := {"v_vanster": "ui_left", "v_hoger": "ui_right", "v_upp": "ui_up", "v_ner": "ui_down",
    "h_a": "ui_accept", "h_b": "ui_cancel"}

var menu_open := false              # set by the world HUD

signal button_seen(id: String, down: bool)   # every Click press, for the settings page

var _held := {}     # button id → action it pressed (released even if the binding changes meanwhile)


func _ready() -> void:
    for a in ACTIONS:
        var action: String = a[0]
        if action == "ingen" or InputMap.has_action(action):
            continue
        InputMap.add_action(action)
        for key in a[2]:
            var ev := InputEventKey.new()
            ev.keycode = key
            InputMap.action_add_event(action, ev)


## A Click button went down or up: press or release the action bound to it.
func press(id: String, down: bool) -> void:
    button_seen.emit(id, down)
    var action: String = _held.get(id, "") if not down else binding(id)
    if down and menu_open and action != "meny":
        action = MENU_KEYS.get(id, action)       # the menu button always closes the menu again
    if down:
        _held[id] = action
    else:
        _held.erase(id)
    if action == "" or action == "ingen" or not InputMap.has_action(action):
        return
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = down
    Input.parse_input_event(ev)


func binding(id: String) -> String:
    return Settings.button_bindings.get(id, DEFAULT_BINDINGS.get(id, "ingen"))


