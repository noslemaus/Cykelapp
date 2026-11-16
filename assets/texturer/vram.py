"""Import the painted models' extracted textures VRAM-compressed (fast to load, a quarter of the
memory) instead of Godot's lossless default, which decoded some 300 images every time a world was
built (it added seconds to the load), and at most TEXTURE_CAP (1024) pixels across.

    python3 assets/texturer/vram.py      (then: godot --headless --path game --import)
"""
import glob
import os

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game")
# At most this many pixels wide or high (TEXTURE_CAP=0 for none). TextureCraft paints big parts at
# 2048; at the game's distances 1024 looks the same and the packaged game is a third the size.
CAP = int(os.environ.get("TEXTURE_CAP", "1024"))
changed = 0
capped = 0
for path in glob.glob(os.path.join(GAME, "world", "*", "models", "*_tex_*.import")):
    text = open(path, encoding="utf-8").read()
    new = text
    if "compress/mode=0" in new:
        new = new.replace("compress/mode=0", "compress/mode=2")
        changed += 1
    if "process/size_limit=%d" % CAP not in new:
        import re
        new = re.sub(r"process/size_limit=\d+", "process/size_limit=%d" % CAP, new)
        capped += 1
    if new != text:
        open(path, "w", encoding="utf-8").write(new)
print(f"{changed} texturer satta till VRAM-komprimering, {capped} fick taket {CAP} px")
