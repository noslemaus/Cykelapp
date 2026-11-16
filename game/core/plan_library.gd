extends RefCounted
## Training plans: a goal and a series of sessions in a set order (res://plans/*.json, made by
## assets/pass/generera_planer.py). Each session is a Workout that knows its plan and place in it.
##   {"id", "name", "goal", "color", "sessions": [{"name", "category", "description", "steps"}]}

const Workout = preload("res://core/workout.gd")


## [{"id", "name", "goal", "color", "sessions": Array of Workout}], in the plans' set order.
static func load_all(dir_path: String) -> Array:
    var list := []
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return list
    var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".json"))
    files.sort()
    for file in files:
        var data = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
        if typeof(data) != TYPE_DICTIONARY:
            push_error("Kunde inte läsa planen %s" % file)
            continue
        var plan := {"id": str(data.get("id", file.get_basename())), "name": str(data.get("name", "")),
            "goal": str(data.get("goal", "")), "color": str(data.get("color", "5c6475")), "sessions": [],
            "order": int(data.get("order", 999))}
        var i := 0
        for s in data.get("sessions", []):
            var w := Workout.new()
            if w.parse(s, "%s-%d" % [plan["id"], i + 1]):
                w.plan_id = plan["id"]
                w.plan_index = i
                plan["sessions"].append(w)
                i += 1
        list.append(plan)
    list.sort_custom(func(a, b): return a["order"] < b["order"])
    return list


static func total_seconds(plan: Dictionary) -> float:
    var t := 0.0
    for w in plan["sessions"]:
        t += w.duration
    return t
