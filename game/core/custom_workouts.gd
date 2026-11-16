extends RefCounted
## Your own workouts (Egna pass): made in the workout editor (ui/workout_editor.gd), copied from
## another workout, or imported from Zwift's .zwo files (core/zwo.gd). Each is a JSON file in the
## game's workout format in user://egna-pass/, with "custom": true, so the library shows them under
## Egna pass and they ride like any other.

const Workout = preload("res://core/workout.gd")
const Zwo = preload("res://core/zwo.gd")
const SafeFile = preload("res://core/safe_file.gd")

const DIR := "user://egna-pass"


static func load_all(dir := DIR) -> Array:
    var list := []
    if not DirAccess.dir_exists_absolute(dir):      # nothing made yet (a new player)
        return list
    for file in DirAccess.get_files_at(dir):
        if not file.ends_with(".json"):
            continue
        var data = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
        var w := Workout.new()
        if data is Dictionary and w.parse(data, file.get_basename()):
            w.custom = true
            list.append(w)
    return list


## Save a workout (the game's JSON format) and return its id; `id` "" makes a new one from the name.
static func save(data: Dictionary, id := "", dir := DIR) -> String:
    DirAccess.make_dir_recursive_absolute(dir)
    if id == "":
        id = "egen-" + SafeFile.slug(str(data.get("name", "pass")), true)
        var n := 2
        var base := id
        while FileAccess.file_exists(dir.path_join(id + ".json")):
            id = "%s-%d" % [base, n]
            n += 1
    var copy := data.duplicate(true)
    copy["custom"] = true
    SafeFile.write_text(dir.path_join(id + ".json"), JSON.stringify(copy, "  "))
    return id


static func delete(id: String, dir := DIR) -> void:
    if id.begins_with("egen-"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(id + ".json")))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(id + ".json.bak")))


static func is_own(id: String) -> bool:
    return id.begins_with("egen-")


## Import a .zwo file: returns {"id"} or {"error"}.
static func import_zwo(path: String, dir := DIR) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text == "":
        return {"error": "Kunde inte läsa %s." % path.get_file()}
    var data := Zwo.parse(text)
    if data.has("error"):
        return data
    var check := Workout.new()
    if not check.parse(data):
        return {"error": "Passet i %s gick inte att använda." % path.get_file()}
    return {"id": save(data, "", dir), "name": data["name"]}
