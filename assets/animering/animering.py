"""The game's vector animations and its icon, made in AniCraft (ArtCraft's 2D animation app) through
its headless engine: the intro at start-up, the loop on the loading screen and the app icon
(game/ikon.png).

    python3 assets/animering/animering.py          (python3 assets/animering/animering.py ikon: only the icon)

Writes the AniCraft files (assets/animering/<name>.anicraft, open and change them in AniCraft),
renders them as PNG frames (assets/animering/render/<name>/, not in git) and turns those into Ogg
Theora videos with Godot's movie writer (game/ui/animering/<name>.ogv), which the game plays: a
picture per frame as textures would take hundreds of MB of video memory. Run
`godot --headless --import` in game/ afterwards.

The cyclist is drawn frame by frame from a small rig: two-bone legs (hip, knee, foot) that follow the
pedals, a crank, and wheels whose spokes turn with the road. The title uses AniCraft's motion tweens.
"""
import json
import math
import os
import shutil
import subprocess
import sys

CLI = "/Applications/AniCraft.app/Contents/MacOS/anicraft-cli"
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
RENDER = os.path.join(HERE, "render")            # the PNG frames (kept out of git)

TEAL = "#14b8a6"
GOLD = "#ffd34d"
WHITE = "#f3f5f9"
SKIN = "#e0b394"
SKIN_FAR = "#b98d70"
SHORTS = "#3b4252"
SHORTS_FAR = "#2a2f3a"
SPOKE = "#9aa1aa"
CRANK = "#c8ccd4"


class AniCraft:
    """AniCraft's engine over JSON lines (anicraft-cli serve)."""

    def __init__(self):
        self.p = subprocess.Popen([CLI, "serve"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True)
        self.p.stdout.readline()                       # {"ready": true, …}
        self.n = 0

    def __call__(self, cmd, **params):
        self.n += 1
        self.p.stdin.write(json.dumps({"id": self.n, "cmd": cmd, "params": params}) + "\n")
        self.p.stdin.flush()
        reply = json.loads(self.p.stdout.readline())
        if not reply.get("ok"):
            sys.exit("AniCraft sa nej till %s %s: %s" % (cmd, params, reply.get("error")))
        return reply.get("result", {})

    def close(self):
        self.p.stdin.close()
        self.p.wait()


class Cyclist:
    """Draws the cyclist (facing right) at `cx` on the ground line `ground`, `s` times life size of the
    rig below (in rig units, y up from the ground), with the crank at `crank` radians (turning
    forward) and the wheels turned `wheel` radians."""

    R = 48.0
    REAR, FRONT = (-72.0, 48.0), (74.0, 48.0)
    BB = (0.0, 40.0)
    SEAT, HEAD_TUBE = (-24.0, 118.0), (54.0, 112.0)
    HIP, SHOULDER = (-22.0, 134.0), (40.0, 180.0)
    THIGH, SHIN, CRANK_LEN = 62.0, 60.0, 22.0

    def __init__(self, ani, cx, ground, s):
        self.a, self.cx, self.g, self.s = ani, cx, ground, s

    def p(self, pt):
        return (self.cx + self.s * pt[0], self.g - self.s * pt[1])

    def line(self, a, b, colour, width):
        (x0, y0), (x1, y1) = self.p(a), self.p(b)
        self.a("draw.line", x0=x0, y0=y0, x1=x1, y1=y1, stroke=colour, stroke_width=width * self.s, cap="round",
               object=True)

    def circle(self, c, r, stroke=None, fill=None, width=0.0):
        x, y = self.p(c)
        rr = r * self.s
        args = dict(x=x - rr, y=y - rr, w=2 * rr, h=2 * rr, fill=fill or "#00000000", object=True)
        if stroke:
            args.update(stroke=stroke, stroke_width=width * self.s)
        self.a("draw.ellipse", **args)

    def foot(self, crank):
        # Forward pedalling turns the crank clockwise as seen from the right side (y up).
        return (self.BB[0] + self.CRANK_LEN * math.cos(-crank), self.BB[1] + self.CRANK_LEN * math.sin(-crank))

    def knee(self, foot):
        hx, hy = self.HIP
        dx, dy = foot[0] - hx, foot[1] - hy
        d = min(math.hypot(dx, dy), self.THIGH + self.SHIN - 0.01)
        base = math.atan2(dy, dx)
        bend = math.acos((self.THIGH ** 2 + d * d - self.SHIN ** 2) / (2 * self.THIGH * d))
        return (hx + self.THIGH * math.cos(base + bend), hy + self.THIGH * math.sin(base + bend))   # knee forward

    def leg(self, crank, far):
        f = self.foot(crank)
        k = self.knee(f)
        self.line(self.HIP, k, SHORTS_FAR if far else SHORTS, 17)
        self.line(k, f, SKIN_FAR if far else SKIN, 12)
        self.line((f[0] - 6, f[1] - 2), (f[0] + 12, f[1] - 2), "#1f2124", 7)                      # shoe

    def wheel(self, hub, turn):
        self.circle(hub, self.R, stroke=WHITE, width=7)
        for k in range(3):
            ang = turn + k * math.tau / 3
            a = (hub[0] + self.R * 0.9 * math.cos(ang), hub[1] + self.R * 0.9 * math.sin(ang))
            b = (hub[0] - self.R * 0.9 * math.cos(ang), hub[1] - self.R * 0.9 * math.sin(ang))
            self.line(a, b, SPOKE, 2.5)
        self.circle(hub, 5, fill=CRANK)

    def draw(self, crank, wheel):
        far = crank + math.pi
        self.leg(far, True)
        self.line(self.BB, self.foot(far), "#6b7280", 5)
        self.wheel(self.REAR, -wheel)
        self.wheel(self.FRONT, -wheel)
        for a, b, w in ((self.REAR, self.BB, 7), (self.REAR, self.SEAT, 6), (self.SEAT, self.BB, 7),
                        (self.BB, self.HEAD_TUBE, 8), (self.SEAT, self.HEAD_TUBE, 7), (self.HEAD_TUBE, self.FRONT, 6)):
            self.line(a, b, TEAL, w)
        self.line(self.HEAD_TUBE, (62, 122), CRANK, 6)                                            # stem
        self.line((62, 122), (74, 118), CRANK, 6)                                                 # bar
        self.line((-40, 127), (-10, 127), WHITE, 7)                                               # saddle
        self.circle(self.BB, 13, stroke=CRANK, width=4)                                           # chainring
        self.line(self.BB, self.foot(crank), CRANK, 5)
        self.leg(crank, False)
        self.line(self.HIP, self.SHOULDER, GOLD, 27)                                              # torso
        self.line(self.SHOULDER, (58, 152), GOLD, 11)                                             # upper arm
        self.line((58, 152), (72, 122), SKIN, 9)                                                  # forearm
        self.circle((60, 202), 16, fill=SKIN)                                                     # head
        hx, hy = self.p((60, 208))
        r = 19 * self.s
        self.a("draw.path", d="M %f %f A %f %f 0 0 1 %f %f Z" % (hx - r, hy, r, r, hx + r, hy), fill=TEAL, object=True)
        self.line((74, 210), (84, 204), TEAL, 6)                                                  # visor


def frame_by_frame(ani, layer, frames, draw):
    """Draw `draw(f)` on its own keyframe for every frame on `layer`."""
    for f in range(frames):
        ani("timeline.goto", frame=f)
        ani("layer.select", layer=layer)
        if f > 0:
            ani("timeline.insert_blank_keyframe", layer=layer, frame=f)
        draw(f)


def ease_out(t):
    t = min(max(t, 0.0), 1.0)
    return 1.0 - (1.0 - t) ** 3


def intro(path):
    """The intro, 3.2 s: the cyclist rides in from the left leaving a teal trail on the road, and
    "Cykelapp" fades up beside it with a teal line drawn under it."""
    W, H, FPS, N = 1600, 900, 30, 96
    a = AniCraft()
    a("file.new", width=W, height=H, fps=FPS)
    a("doc.set_stage", background="#12161d")
    bg = a("layer.new", name="mark")["layer"]
    trail = a("layer.new", name="spår")["layer"]
    rider = a("layer.new", name="cyklist")["layer"]
    title = a("layer.new", name="titel")["layer"]
    line = a("layer.new", name="linje")["layer"]
    ground = 660.0
    s = 1.75

    def x_at(f):
        return -320.0 + 720.0 * ease_out(f / 54.0) + max(f - 54, 0) * 1.4

    # The ground: a faint road line and a glow low on the horizon.
    a("timeline.goto", frame=0)
    a("layer.select", layer=bg)
    a("draw.path", d="M 0 %f L 0 560 Q 220 500 430 545 T 860 530 T 1260 548 T 1600 520 L 1600 %f Z" % (ground, ground),
      fill="#161e2a", object=True)
    a("draw.path", d="M 0 %f L 0 600 Q 300 575 620 598 T 1240 590 T 1600 600 L 1600 %f Z" % (ground, ground),
      fill="#1a2433", object=True)
    a("draw.line", x0=0, y0=ground + 2, x1=W, y1=ground + 2, stroke="#2a3342", stroke_width=4, object=True)
    a("timeline.insert_frame", layer=bg, frame=0, count=N - 1)

    def draw_trail(f):
        rear = x_at(f) + s * Cyclist.REAR[0]
        if rear > -16:
            a("draw.line", x0=-20, y0=ground - 3, x1=rear, y1=ground - 3, stroke=TEAL, stroke_width=6, cap="round",
              object=True)

    frame_by_frame(a, trail, N, draw_trail)

    def draw_rider(f):
        x = x_at(f)
        travelled = x_at(f) + 320.0
        Cyclist(a, x, ground, s).draw(crank=f * math.tau / 11.0, wheel=travelled / (Cyclist.R * s))

    frame_by_frame(a, rider, N, draw_rider)

    # The title: in on frame 26, fading up and rising 30 px until frame 50.
    a("timeline.goto", frame=26)
    a("layer.select", layer=title)
    a("timeline.insert_blank_keyframe", layer=title, frame=26)
    a("text.create", text="Cykelapp", x=760, y=420, size=170, bold=True, color=WHITE)
    a("timeline.insert_frame", layer=title, frame=26, count=N - 27)
    a("timeline.create_motion_tween", layer=title, frame=26)
    a("motion.set_key", layer=title, property="alpha", value=0, frame=26)
    a("motion.set_key", layer=title, property="alpha", value=100, frame=50)
    a("motion.set_key", layer=title, property="y", value=452, frame=26)
    a("motion.set_key", layer=title, property="y", value=420, frame=50)
    a("motion.set_ease", layer=title, frame=30, easing="ease_out")

    # A teal line drawn under the title, frame by frame.
    def draw_line(f):
        t = ease_out((f - 46) / 18.0)
        if 560 * t > 3.0:
            a("draw.line", x0=768, y0=640, x1=768 + 690 * t, y1=640, stroke=TEAL, stroke_width=10, cap="round",
              object=True)

    frame_by_frame(a, line, N, draw_line)
    a("file.save", path=path, confirm=True)
    a.close()


def loading(path):
    """The loading loop, 16 frames: the cyclist pedals on the spot, the wheels turn and the road's
    dashes run past; the last frame leads into the first."""
    W, H, FPS, N = 720, 300, 30, 16
    a = AniCraft()
    a("file.new", width=W, height=H, fps=FPS)
    a("doc.set_stage", background="#0a1f29")          # main.gd's cover colour
    road = a("layer.new", name="väg")["layer"]
    rider = a("layer.new", name="cyklist")["layer"]
    ground = 262.0
    period = 90.0

    def draw_road(f):
        a("draw.line", x0=0, y0=ground + 2, x1=W, y1=ground + 2, stroke="#24414d", stroke_width=4, object=True)
        off = -(f * period / N)
        x = off
        while x < W:
            a("draw.line", x0=x, y0=ground + 16, x1=x + 36, y1=ground + 16, stroke="#2f5866", stroke_width=5,
              cap="round", object=True)
            x += period

    frame_by_frame(a, road, N, draw_road)
    # One crank turn per loop, and a third of a wheel turn (the three spokes look the same again).
    frame_by_frame(a, rider, N, lambda f: Cyclist(a, W / 2 - 10, ground, 1.05).draw(
        crank=f * math.tau / N, wheel=f * (math.tau / 3) / N))
    a("file.save", path=path, confirm=True)
    a.close()


def icon(path):
    """The app icon, 1024 × 1024: the cyclist from the intro on a dark rounded square (macOS's icon
    grid: an 824 px square with 185 px corners, transparent around it), a pale moon, the hills and the
    teal road with speed lines behind the bike."""
    W = 1024
    a = AniCraft()
    a("file.new", width=W, height=W, fps=30)
    a("doc.set_stage", background="#00000000")
    a("layer.new", name="ikon")
    a("draw.rect", x=100, y=100, w=824, h=824, radius=185, fill="#12161d", object=True)
    a("draw.ellipse", x=560, y=180, w=280, h=280, fill="#1d2838", object=True)               # a pale low moon
    a("draw.path", d="M 112 770 L 112 668 Q 300 620 480 660 Q 700 690 912 646 L 912 770 Z", fill="#1a2433",
      object=True)
    ground = 770.0
    a("draw.line", x0=150, y0=ground + 6, x1=874, y1=ground + 6, stroke=TEAL, stroke_width=16, cap="round",
      object=True)
    for y, x0, x1 in ((520, 140, 250), (600, 160, 236), (680, 140, 220)):
        a("draw.line", x0=x0, y0=y, x1=x1, y1=y, stroke=TEAL, stroke_width=13, cap="round", object=True)
    Cyclist(a, 540, ground, 2.4).draw(crank=0.8, wheel=0.35)
    a("file.save", path=path, confirm=True)
    a.close()
    out = os.path.join(GAME, "ikon.png")
    if os.path.exists(out):
        os.remove(out)                    # the render will not replace a file
    r = subprocess.run([CLI, "render", path, "--out", out], capture_output=True, text=True)
    print("ikon", r.stdout.strip() or r.stderr.strip())


def render(name):
    src = os.path.join(HERE, name + ".anicraft")
    out = os.path.join(RENDER, name)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    scale = "1.2" if name == "intro" else "1.0"
    r = subprocess.run([CLI, "render-seq", src, "--out-dir", out, "--scale", scale], capture_output=True, text=True)
    print(name, r.stdout.strip() or r.stderr.strip())


def video(name, size):
    """The frames as an Ogg Theora video (what Godot plays), made by Godot's own movie writer:
    main.gd --film shows one frame per rendered frame at a fixed 30 fps."""
    os.makedirs(os.path.join(GAME, "ui", "animering"), exist_ok=True)
    out = os.path.join(GAME, "ui", "animering", name + ".ogv")
    r = subprocess.run(["godot", "--path", GAME, "--write-movie", out, "--fixed-fps", "30", "--resolution", size,
                        "--", "--film=" + name], capture_output=True, text=True)
    print(name, "→", out, "%.1f MB" % (os.path.getsize(out) / 1e6) if os.path.exists(out) else r.stderr[-400:])


if __name__ == "__main__":
    icon(os.path.join(HERE, "ikon.anicraft"))
    if sys.argv[1:] == ["ikon"]:
        sys.exit(0)
    intro(os.path.join(HERE, "intro.anicraft"))
    loading(os.path.join(HERE, "laddning.anicraft"))
    for name in ("intro", "laddning"):
        render(name)
    video("intro", "1920x1080")
    video("laddning", "720x300")
