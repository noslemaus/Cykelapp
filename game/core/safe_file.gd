extends RefCounted
## Saving files that must not be lost: progress.json, settings.cfg and strava.cfg.
##
## A save writes "<file>.tmp" first and then renames it over the file, so a crash or a full disk in
## the middle of a save leaves the old file whole instead of a half-written one. The file it replaces
## is kept as "<file>.bak", which `read_text` falls back on when the file itself cannot be read.
## Files with keys (strava.cfg, `private`) are made readable by their owner only and get no backup.


## Write `text` to `path` safely. Returns true when it was saved.
static func write_text(path: String, text: String, private := false) -> bool:
    var tmp := path + ".tmp"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        push_error("Kunde inte spara %s (fel %d)" % [path, FileAccess.get_open_error()])
        return false
    file.store_string(text)
    file.close()
    return _replace(tmp, path, private)


## Save a ConfigFile to `path` safely.
static func save_config(cfg: ConfigFile, path: String, private := false) -> bool:
    var tmp := path + ".tmp"
    var err := cfg.save(tmp)
    if err != OK:
        push_error("Kunde inte spara %s (fel %d)" % [path, err])
        return false
    return _replace(tmp, path, private)


## The text of `path`, or of its backup when the file is missing, empty or fails `valid`
## (for example JSON that no longer parses). "" when neither can be read.
static func read_text(path: String, valid := Callable()) -> String:
    for p in [path, path + ".bak"]:
        if not FileAccess.file_exists(p):
            continue
        var text := FileAccess.get_file_as_string(p)
        if text.strip_edges() == "":
            continue
        if valid.is_valid() and not valid.call(text):
            print("%s gick inte att läsa, provar säkerhetskopian" % p)
            continue
        return text
    return ""


## True when `text` is a JSON object (a quiet check: no error is printed for broken text).
static func is_json_object(text: String) -> bool:
    var json := JSON.new()
    return json.parse(text) == OK and json.data is Dictionary


## Load a ConfigFile from `path`, or from its backup when the file is missing or broken.
static func load_config(cfg: ConfigFile, path: String) -> Error:
    var err := cfg.load(path)
    if err != OK and FileAccess.file_exists(path + ".bak"):
        err = cfg.load(path + ".bak")
    return err


static func _replace(tmp: String, path: String, private: bool) -> bool:
    var real_tmp := ProjectSettings.globalize_path(tmp)
    var real := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(real + ".bak"):
        DirAccess.remove_absolute(real + ".bak")
    if private:
        # Keys: readable by you only, and no backup that would keep them after Strava is unlinked.
        FileAccess.set_unix_permissions(real_tmp, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
    elif FileAccess.file_exists(real):
        DirAccess.copy_absolute(real, real + ".bak")
    # rename() replaces the file in one step on macOS, so there is never a moment without it.
    var err := DirAccess.rename_absolute(real_tmp, real)
    if err != OK:
        push_error("Kunde inte byta in %s (fel %d)" % [path, err])
        return false
    return true


## A file name part made of lower-case letters, digits and dashes (å, ä and ö kept, or made a and o
## with `ascii`), at most 60 characters: "Japan · Kom igång 3/10" → "japan-kom-igång-3-10". Never a
## path separator or a dot.
static func slug(text: String, ascii := false) -> String:
    var out := ""
    var plain := {"å": "a", "ä": "a", "ö": "o", "é": "e", "ü": "u"}
    for ch in text.to_lower():
        if ascii and plain.has(ch):
            ch = plain[ch]
        out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch in "åäöéü" else "-"
    while out.contains("--"):
        out = out.replace("--", "-")
    out = out.trim_prefix("-").trim_suffix("-").left(60).trim_suffix("-")
    return out if out != "" else "tur"
