extends RefCounted
## Loads every workout JSON file in a folder, sorted by length then name.

const Workout = preload("res://core/workout.gd")


static func load_all(dir_path: String) -> Array:
    var list := []
    var dir := DirAccess.open(dir_path)
    if dir == null:
        push_error("Hittar inte passmappen %s" % dir_path)
        return list
    for file in dir.get_files():
        if not file.ends_with(".json"):
            continue
        var data = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
        var workout := Workout.new()
        if typeof(data) == TYPE_DICTIONARY and workout.parse(data, file.get_basename()):
            list.append(workout)
        else:
            push_error("Kunde inte läsa passet %s" % file)
    list.sort_custom(func(a, b): return a.duration < b.duration or (a.duration == b.duration and a.name < b.name))
    return list
