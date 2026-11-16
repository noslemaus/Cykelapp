"""Pretend Strava API for the Strava test, so strava.com is never contacted.

    python3 -I tests/strava_mock.py 47013 /tmp/strava-mock.log

Then: godot --headless --path . -- --stravatest=http://127.0.0.1:47013
Answers /oauth/token (code + refresh), /api/v3/uploads and /api/v3/uploads/<id>,
and logs what the app sent (checks the FIT header and the form fields).
"""
import json
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 47013
LOG = open(sys.argv[2] if len(sys.argv) > 2 else "/dev/stdout", "a", buffering=1)
seen_external_ids = set()


def log(text):
    LOG.write(time.strftime("%H:%M:%S ") + text + "\n")


def multipart_fields(body, content_type):
    boundary = content_type.split("boundary=", 1)[1].encode()
    fields = {}
    for part in body.split(b"--" + boundary):
        if b"\r\n\r\n" not in part:
            continue
        head, value = part.split(b"\r\n\r\n", 1)
        value = value[:-2] if value.endswith(b"\r\n") else value
        name = head.split(b'name="', 1)[1].split(b'"', 1)[0].decode()
        fields[name] = value
    return fields


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        return self.rfile.read(int(self.headers.get("Content-Length", 0)))

    def do_POST(self):
        if self.path == "/oauth/token":
            form = dict(urllib.parse.parse_qsl(self.body().decode()))
            log(f"token: grant={form.get('grant_type')} client_id={form.get('client_id')}")
            if form.get("client_id") != "12345" or form.get("client_secret") != "test-secret":
                return self.reply(401, {"message": "Authorization Error"})
            if form.get("grant_type") == "authorization_code" and form.get("code") == "testcode":
                return self.reply(200, {"token_type": "Bearer", "access_token": "acc1", "refresh_token": "ref1",
                                        "expires_at": int(time.time()) + 21600,
                                        "athlete": {"firstname": "Test", "lastname": "Testsson"}})
            if form.get("grant_type") == "refresh_token" and form.get("refresh_token") == "ref1":
                return self.reply(200, {"token_type": "Bearer", "access_token": "acc2", "refresh_token": "ref2",
                                        "expires_at": int(time.time()) + 21600})
            return self.reply(400, {"message": "Bad Request"})
        if self.path == "/api/v3/uploads":
            auth = self.headers.get("Authorization", "")
            fields = multipart_fields(self.body(), self.headers.get("Content-Type", ""))
            fit = fields.get("file", b"")
            log(f"upload: auth={auth} data_type={fields.get('data_type')} name={fields.get('name', b'').decode()} "
                f"trainer={fields.get('trainer')} external_id={fields.get('external_id')} "
                f"fit_bytes={len(fit)} fit_header_ok={fit[8:12] == b'.FIT'}")
            if not auth.startswith("Bearer acc"):
                return self.reply(401, {"message": "Authorization Error"})
            if fields.get("data_type") != b"fit" or fit[8:12] != b".FIT":
                return self.reply(400, {"message": "Bad Request"})
            external_id = fields.get("external_id")
            if external_id in seen_external_ids:
                return self.reply(201, {"id": 43, "id_str": "43", "activity_id": None,
                                        "status": "There was an error processing your activity.",
                                        "error": f"{external_id.decode()} duplicate of activity 777"})
            seen_external_ids.add(external_id)
            return self.reply(201, {"id": 42, "id_str": "42", "activity_id": None, "error": None,
                                    "status": "Your activity is still being processed."})
        self.reply(404, {"message": "Not Found"})

    def do_GET(self):
        if self.path == "/api/v3/uploads/42":
            log("poll: upload 42")
            return self.reply(200, {"id": 42, "id_str": "42", "activity_id": 777, "error": None,
                                    "status": "Your activity is ready."})
        self.reply(404, {"message": "Not Found"})


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
