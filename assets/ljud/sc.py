"""Tiny client for SoundCraft's control channel (JSON lines on localhost, like TextureCraft's):
python3 sc.py '<json list of [method, params]>'. Start SoundCraft with --control 7879 first."""
import json, os, socket, sys, tempfile, time

PORT = int(os.environ.get("SC_PORT", "7879"))


def connect():
    path = os.path.join(tempfile.gettempdir(), f"soundcraft-control-{PORT}.token")
    for _ in range(60):
        try:
            s = socket.create_connection(("127.0.0.1", PORT), timeout=900)
            token = open(path).read().strip() if os.path.exists(path) else ""
            return s, token
        except OSError:
            time.sleep(0.5)
    raise SystemExit("ingen kontrollkanal")


s, token = connect()
f = s.makefile("rw")
_id = [0]


def call(method, params=None):
    _id[0] += 1
    f.write(json.dumps({"id": _id[0], "method": method, "params": params or {}}) + "\n")
    f.flush()
    reply = json.loads(f.readline())
    if not reply.get("ok", "error" not in reply):
        raise RuntimeError(f"{method}: {reply.get('error')}")
    return reply.get("result", reply)


if token:
    try:
        call("auth", {"token": token})
    except RuntimeError as e:
        print("auth:", e)

if __name__ == "__main__":
    for method, params in json.loads(sys.argv[1]):
        try:
            res = call(method, params)
        except RuntimeError as e:
            print(method, "FEL", e)
            continue
        text = json.dumps(res, ensure_ascii=False)
        print(method, "->", text[:8000] + ("…" if len(text) > 8000 else ""))
