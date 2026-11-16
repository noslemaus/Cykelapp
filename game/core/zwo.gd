extends RefCounted
## Zwift workout files (.zwo) into the game's own workout format (core/workout.gd), so workouts
## from Zwift, What's on Zwift or a coach can be ridden here. A .zwo is XML:
##   <workout_file><name>…</name><description>…</description><workout> … </workout></workout_file>
## with the blocks Warmup, Cooldown and Ramp (PowerLow → PowerHigh), SteadyState and SolidState
## (Power), IntervalsT (Repeat, OnDuration/OnPower, OffDuration/OffPower), FreeRide and MaxEffort
## (no target) and textevent (coaching text, left out). Power is a share of FTP, durations seconds,
## Cadence (CadenceLow/CadenceResting on intervals) the suggested rpm.


## {"name", "description", "category", "custom": true, "steps": […]}, or {"error": "…"}.
static func parse(text: String) -> Dictionary:
    var xml := XMLParser.new()
    if xml.open_buffer(text.to_utf8_buffer()) != OK:
        return {"error": "Filen går inte att läsa som XML."}
    var out := {"name": "", "description": "", "category": "", "custom": true, "steps": []}
    var field := ""
    var in_workout := false
    while xml.read() == OK:
        match xml.get_node_type():
            XMLParser.NODE_ELEMENT:
                var tag := xml.get_node_name()
                var lower := tag.to_lower()
                if lower == "workout":
                    in_workout = true
                elif lower in ["name", "description", "category"] and not in_workout:
                    field = lower
                elif in_workout:
                    var step := _block(lower, _attributes(xml))
                    if not step.is_empty():
                        out["steps"].append(step)
            XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
                if field != "":
                    out[field] = (str(out[field]) + xml.get_node_data()).strip_edges()
            XMLParser.NODE_ELEMENT_END:
                if xml.get_node_name().to_lower() == "workout":
                    in_workout = false
                field = ""
    if out["steps"].is_empty():
        return {"error": "Hittade inga block i passet."}
    if str(out["name"]) == "":
        out["name"] = "Importerat pass"
    out["category"] = _category(str(out["category"]))
    return out


static func _attributes(xml: XMLParser) -> Dictionary:
    var a := {}
    for i in xml.get_attribute_count():
        a[xml.get_attribute_name(i).to_lower()] = xml.get_attribute_value(i)
    return a


static func _block(tag: String, a: Dictionary) -> Dictionary:
    var duration := float(a.get("duration", "0"))
    var cadence := int(float(a.get("cadence", a.get("cadencelow", "0"))))
    var step := {}
    match tag:
        "warmup", "cooldown", "ramp":
            var low := float(a.get("powerlow", a.get("power", "0.5")))
            var high := float(a.get("powerhigh", a.get("power", "0.5")))
            step = {"type": "ramp", "duration": duration, "from": low, "to": high}
            if tag != "ramp":
                step["label"] = "Uppvärmning" if tag == "warmup" else "Nedvarvning"
        "steadystate", "solidstate":
            var p := float(a.get("power", a.get("powerlow", "0.5")))
            if a.has("powerlow") and a.has("powerhigh") and not a.has("power"):
                p = (float(a["powerlow"]) + float(a["powerhigh"])) * 0.5
            step = {"type": "steady", "duration": duration, "power": p}
        "intervalst":
            var on := {"duration": float(a.get("onduration", "60")),
                "power": float(a.get("onpower", a.get("powerhigh", "1.0")))}
            var off := {"duration": float(a.get("offduration", "60")),
                "power": float(a.get("offpower", a.get("powerlow", "0.5")))}
            if cadence > 0:
                on["cadence"] = cadence
            if a.has("cadenceresting"):
                off["cadence"] = int(float(a["cadenceresting"]))
            return {"type": "intervals", "repeat": maxi(int(a.get("repeat", "1")), 1), "on": on, "off": off}
        "freeride", "maxeffort":
            step = {"type": "free", "duration": duration}
            if tag == "maxeffort":
                step["label"] = "Allt du har"
        _:
            return {}
    if duration <= 0.0:
        return {}
    if cadence > 0:
        step["cadence"] = cadence
    return step


## Zwift's categories as the game's (core/workout.gd CATEGORY_NAMES); "" when it does not say.
static func _category(text: String) -> String:
    var t := text.to_lower()
    for pair in [["recovery", "recovery"], ["endurance", "endurance"], ["tempo", "sweetspot"], ["sweet", "sweetspot"],
            ["threshold", "threshold"], ["vo2", "vo2max"], ["ftp", "ftptest"], ["climb", "climbing"], ["sprint", "sprint"]]:
        if t.contains(pair[0]):
            return pair[1]
    return ""
