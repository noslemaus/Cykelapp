extends Node
## Strava: OAuth login through the browser and activity upload. Autoloaded as `Strava`.
##
## Login: the app opens strava.com/oauth/authorize; Strava redirects the browser to
## http://localhost:47012/strava?code=…, which a tiny local server here answers. The code is then
## exchanged for tokens. The client ID and secret (the rider's own Strava API app) and the tokens live only in
## user://strava.cfg on this Mac. Uploads are FIT files sent to /api/v3/uploads; the upload is then
## polled until Strava reports the activity id (or an error such as a duplicate).

signal changed                       # login state or status text changed
signal upload_finished(ok: bool, message: String, url: String)

const CALLBACK_PORT := 47012
const SCOPE := "read,activity:write"
const SafeFile = preload("res://core/safe_file.gd")

var api_base := "https://www.strava.com"    # developer tests point this at a local mock
var config_path := "user://strava.cfg"      # developer tests use a separate file
var open_browser := true

var client_id := ""
var client_secret := ""
var access_token := ""
var refresh_token := ""
var expires_at := 0
var athlete_name := ""
var status := ""
var busy := false

var _server: TCPServer = null
var _state := ""
var _peer: StreamPeerTCP = null     # browser connection being read
var _peer_text := ""
var _peer_since := 0


func _ready() -> void:
    load_config()


## Switch to another config file (developer tests), forgetting everything loaded so far.
func use_config(path: String) -> void:
    config_path = path
    client_id = ""
    client_secret = ""
    access_token = ""
    refresh_token = ""
    expires_at = 0
    athlete_name = ""
    load_config()


func load_config() -> void:
    var cfg := ConfigFile.new()
    if SafeFile.load_config(cfg, config_path) != OK:
        return
    # A file saved before the keys were kept private: make it readable by you only.
    FileAccess.set_unix_permissions(ProjectSettings.globalize_path(config_path),
        FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
    client_id = str(cfg.get_value("app", "client_id", ""))
    client_secret = str(cfg.get_value("app", "client_secret", ""))
    access_token = str(cfg.get_value("token", "access", ""))
    refresh_token = str(cfg.get_value("token", "refresh", ""))
    expires_at = int(cfg.get_value("token", "expires_at", 0))
    athlete_name = str(cfg.get_value("token", "athlete", ""))


func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("app", "client_id", client_id)
    cfg.set_value("app", "client_secret", client_secret)
    cfg.set_value("token", "access", access_token)
    cfg.set_value("token", "refresh", refresh_token)
    cfg.set_value("token", "expires_at", expires_at)
    cfg.set_value("token", "athlete", athlete_name)
    SafeFile.save_config(cfg, config_path, true)      # the keys: readable by you only


func has_app() -> bool:
    return client_id != "" and client_secret != ""


func is_linked() -> bool:
    return refresh_token != ""


func set_app(id: String, secret: String) -> void:
    client_id = id.strip_edges()
    client_secret = secret.strip_edges()
    _save()
    _set_status(tr("Uppgifterna är sparade. Tryck Koppla Strava."))


func unlink() -> void:
    access_token = ""
    refresh_token = ""
    expires_at = 0
    athlete_name = ""
    _save()
    _set_status(tr("Strava är bortkopplat."))


func _set_status(text: String) -> void:
    status = text
    changed.emit()


# --- Login ------------------------------------------------------------------------------------

## Open the Strava consent page and wait for the browser to come back to localhost.
## Returns the authorize URL (developer tests follow it themselves).
func begin_login() -> String:
    if not has_app():
        _set_status(tr("Fyll i Client ID och Client Secret först."))
        return ""
    if _server:
        _server.stop()
    _server = TCPServer.new()
    if _server.listen(CALLBACK_PORT, "127.0.0.1") != OK:
        _server = null
        _set_status(tr("Port %d är upptagen, kan inte ta emot svaret från Strava.") % CALLBACK_PORT)
        return ""
    _state = Crypto.new().generate_random_bytes(16).hex_encode()     # unguessable, unlike randi()
    var redirect := "http://localhost:%d/strava" % CALLBACK_PORT
    var url := "%s/oauth/authorize?client_id=%s&response_type=code&redirect_uri=%s&approval_prompt=auto&scope=%s&state=%s" % [
        api_base, client_id.uri_encode(), redirect.uri_encode(), SCOPE.uri_encode(), _state]
    if open_browser:
        OS.shell_open(url)
    _set_status(tr("Godkänn i webbläsaren som öppnades…"))
    return url


func pending_state() -> String:
    return _state


## Read the browser's request a frame at a time. Browsers sometimes open idle connections
## first, so a connection that sends nothing for 3 s is dropped and the next one is taken.
func _process(_delta: float) -> void:
    if _server == null:
        return
    if _peer == null and _server.is_connection_available():
        _peer = _server.take_connection()
        _peer_text = ""
        _peer_since = Time.get_ticks_msec()
    if _peer == null:
        return
    _peer.poll()
    var available := _peer.get_available_bytes()
    if available > 0:
        _peer_text += _peer.get_utf8_string(available)
    if _peer_text.contains("\r\n"):
        var peer := _peer
        _peer = null
        _handle_callback(peer, _peer_text)
    elif Time.get_ticks_msec() - _peer_since > 3000:
        _peer.disconnect_from_host()
        _peer = null


func _handle_callback(peer: StreamPeerTCP, request: String) -> void:
    var line := request.get_slice("\r\n", 0)          # GET /strava?state=…&code=… HTTP/1.1
    var target := line.get_slice(" ", 1)
    if not target.begins_with("/strava"):
        _reply(peer, 404, "Hittades inte.")
        return
    var query := _parse_query(target.get_slice("?", 1))
    var message := ""
    if query.get("state", "") != _state:
        message = tr("Svaret från Strava hörde inte till den här inloggningen. Försök igen.")
    elif query.has("error"):
        message = tr("Strava-inloggningen avbröts (%s).") % query["error"]
    elif not str(query.get("scope", "")).contains("activity:write"):
        message = tr("Du behöver godkänna att appen får ladda upp aktiviteter. Försök igen och kryssa i den rutan.")
    _reply(peer, 200, message if message != "" else tr("Klart! Du kan stänga den här fliken och gå tillbaka till Cykelapp."))
    _server.stop()
    _server = null
    if message != "":
        _set_status(message)
        return
    _exchange_code(str(query.get("code", "")))


func _parse_query(text: String) -> Dictionary:
    var result := {}
    for pair in text.split("&", false):
        var kv := pair.split("=", true, 1)
        result[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else ""
    return result


func _reply(peer: StreamPeerTCP, code: int, text: String) -> void:
    var html := "<!doctype html><meta charset=utf-8><title>Cykelapp</title>" \
        + "<body style='font-family:-apple-system,sans-serif;background:#12161d;color:#f3f5f9;padding:60px'>" \
        + "<h2>%s</h2></body>" % text.xml_escape()
    var body := html.to_utf8_buffer()
    var head := "HTTP/1.1 %d OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [code, body.size()]
    peer.put_data(head.to_utf8_buffer() + body)
    peer.disconnect_from_host()


func _exchange_code(code: String) -> void:
    _set_status(tr("Hämtar nycklar från Strava…"))
    var res: Dictionary = await _token_request("grant_type=authorization_code&code=%s" % code.uri_encode())
    if res.is_empty():
        return
    var athlete = res.get("athlete", {})
    if athlete is Dictionary:
        athlete_name = ("%s %s" % [athlete.get("firstname", ""), athlete.get("lastname", "")]).strip_edges()
    _save()
    _set_status(tr("Kopplad till Strava%s.") % (tr(" som ") + athlete_name if athlete_name != "" else ""))


## POST /oauth/token. Stores the tokens and returns the JSON, or {} on failure.
func _token_request(grant: String) -> Dictionary:
    var body := "client_id=%s&client_secret=%s&%s" % [client_id.uri_encode(), client_secret.uri_encode(), grant]
    var res: Dictionary = await _http(HTTPClient.METHOD_POST, api_base + "/oauth/token",
        ["Content-Type: application/x-www-form-urlencoded"], body.to_utf8_buffer())
    if not res["ok"] or not (res["json"] is Dictionary) or not res["json"].has("access_token"):
        _set_status(tr("Strava svarade med fel %d. Stämmer Client ID och Client Secret?") % res["code"])
        return {}
    var json: Dictionary = res["json"]
    access_token = str(json["access_token"])
    refresh_token = str(json.get("refresh_token", refresh_token))
    expires_at = int(json.get("expires_at", 0))
    _save()
    return json


func _ensure_token() -> bool:
    if access_token != "" and Time.get_unix_time_from_system() < expires_at - 120:
        return true
    if refresh_token == "":
        _set_status(tr("Koppla Strava i inställningarna först."))
        return false
    var res: Dictionary = await _token_request("grant_type=refresh_token&refresh_token=%s" % refresh_token.uri_encode())
    return not res.is_empty()


# --- Upload -----------------------------------------------------------------------------------

## Upload a FIT file and wait until Strava has made an activity of it. Emits upload_finished.
func upload(fit_path: String, name: String, description: String) -> void:
    if busy:
        return
    busy = true
    _set_status(tr("Laddar upp till Strava…"))
    var result: Array = await _upload(fit_path, name, description)
    busy = false
    _set_status(result[1])
    upload_finished.emit(result[0], result[1], result[2])


func _upload(fit_path: String, name: String, description: String) -> Array:
    if not await _ensure_token():
        return [false, status, ""]
    var bytes := FileAccess.get_file_as_bytes(fit_path)
    if bytes.is_empty():
        return [false, tr("Hittar inte FIT-filen."), ""]
    var boundary := "cykelapp" + Crypto.new().generate_random_bytes(12).hex_encode()
    var fields := {
        "data_type": "fit",
        "name": name,
        "description": description,
        "trainer": "1",
        "external_id": fit_path.get_file(),
    }
    var res: Dictionary = await _http(HTTPClient.METHOD_POST, api_base + "/api/v3/uploads",
        ["Authorization: Bearer " + access_token, "Content-Type: multipart/form-data; boundary=" + boundary],
        _multipart(fields, fit_path.get_file(), bytes, boundary))
    if not (res["json"] is Dictionary):
        return [false, tr("Uppladdningen misslyckades (fel %d).") % res["code"], ""]
    var upload_info: Dictionary = res["json"]
    for attempt in 20:
        if upload_info.get("error") != null and str(upload_info.get("error")) != "":
            return [false, _explain(str(upload_info["error"])), ""]
        if upload_info.get("activity_id") != null:
            var url := "https://www.strava.com/activities/%d" % int(upload_info["activity_id"])
            return [true, tr("Uppladdat till Strava!"), url]
        await get_tree().create_timer(2.0).timeout
        var poll: Dictionary = await _http(HTTPClient.METHOD_GET, "%s/api/v3/uploads/%s" % [api_base, str(upload_info.get("id_str", upload_info.get("id")))],
            ["Authorization: Bearer " + access_token], PackedByteArray())
        if poll["json"] is Dictionary:
            upload_info = poll["json"]
    return [false, tr("Strava bearbetar fortfarande passet. Titta i Strava om en stund."), ""]


func _explain(error: String) -> String:
    if error.to_lower().contains("duplicate"):
        return tr("Strava har redan det här passet (dubblett). Kanske kom det via Garmin?")
    return tr("Strava kunde inte ta emot passet: %s") % error


func _multipart(fields: Dictionary, file_name: String, file_bytes: PackedByteArray, boundary: String) -> PackedByteArray:
    var body := PackedByteArray()
    for key in fields:
        body += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, key, str(fields[key])]).to_utf8_buffer()
    body += ("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % [boundary, file_name]).to_utf8_buffer()
    body += file_bytes
    body += ("\r\n--%s--\r\n" % boundary).to_utf8_buffer()
    return body


## One HTTP request: {"ok", "code", "json"}.
func _http(method: int, url: String, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
    var request := HTTPRequest.new()
    request.timeout = 30.0
    add_child(request)
    if request.request_raw(url, headers, method, body) != OK:
        request.queue_free()
        return {"ok": false, "code": 0, "json": null}
    var response: Array = await request.request_completed
    request.queue_free()
    var text := (response[3] as PackedByteArray).get_string_from_utf8()
    var code: int = response[1]
    return {
        "ok": response[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300,
        "code": code,
        "json": JSON.parse_string(text) if text != "" else null,
    }
