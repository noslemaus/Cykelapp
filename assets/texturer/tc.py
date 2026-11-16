"""Tiny client for TextureCraft's control channel: python3 tc.py '<json list of [method, params]>'"""
import base64, json, os, socket, sys, tempfile, time

PORT = 7878
def connect():
    path = os.path.join(tempfile.gettempdir(), f"texturecraft-control-{PORT}.token")
    for _ in range(60):
        if os.path.exists(path):
            try:
                s = socket.create_connection(("127.0.0.1", PORT), timeout=600)
                return s, open(path).read().strip()
            except OSError:
                pass
        time.sleep(0.5)
    raise SystemExit("ingen kontrollkanal")

s, token = connect()
f = s.makefile("rw")
_id = [0]
def call(method, params=None):
    _id[0] += 1
    f.write(json.dumps({"id": _id[0], "method": method, "params": params or {}}) + "\n"); f.flush()
    reply = json.loads(f.readline())
    if not reply.get("ok"):
        raise RuntimeError(f"{method}: {reply.get('error')}")
    return reply.get("result")

call("auth", {"token": token})
if __name__ == "__main__":
    steps = json.loads(sys.argv[1])
    for method, params in steps:
        out = params.pop("_save", None) if isinstance(params, dict) else None
        res = call(method, params)
        if out and isinstance(res, dict) and "png" in res:
            open(out, "wb").write(base64.b64decode(res["png"]))
            print(method, "->", out, res["width"], "x", res["height"])
        else:
            text = json.dumps(res, ensure_ascii=False)
            print(method, "->", text[:6000] + ("…" if len(text) > 6000 else ""))


def cmd(cid, params=None):
    return call("command.run", {"id": cid, "params": params or {}})
