"""The ride music, made in SoundCraft through its control channel: French touch with a touch of
80s Tour de France electro. 120 BPM in A minor, 16 bars that loop, in six layers (stems) the game
fades in and out with your power zone (game/core/musik.gd):

    matta    soft pad, whole chords                    (always, quieter as it gets harder)
    bas      disco octave bass                         (from zone 1)
    trummor  four-on-the-floor kick, clap, off-beat hat (from zone 2)
    ackord   filtered chord stabs on the off-beats     (from zone 3)
    extra    16th hats, open hats, fills and crashes    (from zone 4)
    melodi   square-wave arpeggio, then a hook          (zone 5 and up)

Start SoundCraft with `--control 7879` and run:  python3 -I musik.py <out dir>
Each stem is rendered with two extra bars of tail; the tail is folded back onto the start so the
loop is seamless (reverb and delay carry over the loop point)."""
import array
import os
import sys
import wave

OUT = sys.argv[1] if len(sys.argv) > 1 else "../../game/audio/musik"
sys.argv = sys.argv[:1]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "sc.py")).read().split("if __name__")[0])

RATE = 32000          # plenty for background music, and a third smaller than 48 kHz
BPM = 120
PPQ = 960
BAR = 4 * PPQ
BARS = 16
TAIL_BARS = 2
SAMPLES_PER_BAR = RATE * 60 * 4 // BPM

# Two bars per chord: Am7  Dm9  G(add9)  Cmaj7 | Am7  Dm9  Fmaj7  E7
CHORDS = [
    (45, [57, 60, 64, 67]),
    (38, [53, 57, 60, 64]),
    (43, [55, 57, 59, 62]),
    (36, [55, 59, 60, 64]),
    (45, [57, 60, 64, 67]),
    (38, [53, 57, 60, 64]),
    (41, [53, 57, 60, 64]),
    (40, [56, 59, 62, 64]),
]


def chord_at(bar):
    return CHORDS[(bar // 2) % len(CHORDS)]


def note(pitch, start, length, velocity):
    return {"pitch": int(pitch), "start_ticks": int(start), "length_ticks": int(max(length, 30)), "velocity": int(velocity)}


def pad():
    notes = []
    for bar in range(0, BARS, 2):
        _, voicing = chord_at(bar)
        for p in voicing:
            notes.append(note(p, bar * BAR, 2 * BAR - 120, 78))
    return notes


def bass():
    notes = []
    pattern = [(0, 0, 112), (2, 12, 92), (4, 0, 104), (6, 12, 90), (8, 0, 108), (10, 12, 92), (12, 0, 100), (13, 0, 70), (14, 12, 94)]
    for bar in range(BARS):
        root, _ = chord_at(bar)
        for pos, up, vel in pattern:
            notes.append(note(root + up, bar * BAR + pos * 240, 200, vel))
        # Walk into the next chord on the last 16th of each chord's second bar.
        if bar % 2 == 1:
            nxt, _ = chord_at(bar + 1)
            notes.append(note(nxt - 1 if nxt > root else nxt + 1, bar * BAR + 15 * 240, 180, 84))
    return notes


def drums():
    notes = []
    for bar in range(BARS):
        b = bar * BAR
        for beat in range(4):
            notes.append(note(36, b + beat * PPQ, 200, 122))
            notes.append(note(42, b + beat * PPQ + 480, 120, 88))
        for beat in (1, 3):
            notes.append(note(39, b + beat * PPQ, 200, 104))
            notes.append(note(38, b + beat * PPQ, 200, 76))
    return notes


def extra():
    notes = []
    for bar in range(BARS):
        b = bar * BAR
        for s in range(16):
            if s % 2 == 1 and s % 4 != 1:
                continue
            if s % 4 == 2:
                continue        # the off-beat 8ths are the main kit's
            swing = 24 if s % 2 == 1 else 0
            notes.append(note(42, b + s * 240 + swing, 90, 52 + (10 if s % 4 == 0 else 0)))
        notes.append(note(46, b + 3 * PPQ + 480, 300, 86))
        if bar in (0, 8):
            notes.append(note(49, b, 1200, 92))
        if bar in (7, 15):
            for k, p in enumerate([50, 48, 47, 45, 43, 41]):
                notes.append(note(p, b + 3 * PPQ - 480 + k * 240, 200, 96 + k * 3))
    return notes


def stabs():
    notes = []
    for bar in range(BARS):
        _, voicing = chord_at(bar)
        b = bar * BAR
        if bar % 2 == 0:
            for p in voicing:
                notes.append(note(p + 12, b, 420, 100))
        for s in (2, 6, 10, 14):
            if bar % 2 == 0 and s == 2:
                continue
            for p in voicing:
                notes.append(note(p + 12, b + s * 240, 170, 92 if s != 10 else 104))
    return notes


# The hook over the second half: (bar, 8th, pitch, length in 8ths).
HOOK = [
    (8, 0, 76, 1), (8, 2, 79, 1), (8, 3, 81, 2), (8, 5, 79, 1), (8, 6, 76, 1), (8, 7, 74, 1),
    (9, 0, 72, 1), (9, 2, 74, 1), (9, 3, 76, 5),
    (10, 0, 77, 1), (10, 2, 76, 1), (10, 3, 74, 2), (10, 5, 72, 1), (10, 6, 74, 2),
    (11, 0, 69, 4), (11, 4, 72, 1), (11, 5, 74, 1), (11, 6, 76, 2),
    (12, 0, 77, 1), (12, 2, 79, 1), (12, 3, 81, 2), (12, 5, 79, 1), (12, 6, 77, 1), (12, 7, 76, 1),
    (13, 0, 72, 1), (13, 2, 74, 1), (13, 3, 76, 3), (13, 6, 74, 2),
    (14, 0, 76, 1), (14, 2, 80, 1), (14, 3, 76, 2), (14, 5, 74, 1), (14, 6, 71, 1), (14, 7, 74, 1),
    (15, 0, 76, 6), (15, 6, 71, 1), (15, 7, 72, 1),
]


def lead():
    notes = []
    for bar in range(8):
        _, voicing = chord_at(bar)
        t = [p + 12 for p in voicing]
        seq = [t[0], t[1], t[2], t[3], t[0] + 12, t[3], t[2], t[1]]
        for s in range(16):
            notes.append(note(seq[s % 8], bar * BAR + s * 240, 200, 96 if s % 4 == 0 else 74))
    for bar, pos, pitch, length in HOOK:
        notes.append(note(pitch, bar * BAR + pos * 480, length * 480 - 40, 100))
    return notes


SYNTH = "subtractive_synth"
DRUMS = "drum_synth"
TRACKS = [
    # name, instrument, instrument params, inserts [(plugin, params)], fader dB, notes
    ("matta", SYNTH, {"osc1_wave": 0, "osc2_wave": 3, "osc2_semitones": 12, "osc2_detune": 12, "osc_mix": 40,
        "cutoff": 1100, "resonance": 10, "filter_env_amount": 20, "amp_attack": 600, "amp_decay": 1500,
        "amp_sustain": 80, "amp_release": 1500, "filter_attack": 900, "filter_decay": 2000, "filter_sustain": 50,
        "level": -12},
        [("chorus", {"mix": 50, "rate": 0.4}), ("plate_reverb", {"mix": 38, "decay": 4.0})], -4.0, pad),
    ("bas", SYNTH, {"osc1_wave": 0, "osc2_wave": 1, "osc2_semitones": -12, "osc2_detune": 0, "osc_mix": 35,
        "cutoff": 700, "resonance": 35, "filter_env_amount": 55, "amp_attack": 1, "amp_decay": 180,
        "amp_sustain": 40, "amp_release": 60, "filter_decay": 160, "filter_sustain": 10, "level": -4},
        [("saturator", {"drive": 6, "mix": 60}), ("compressor", {"threshold": -20, "ratio": 4, "attack": 5, "release": 80})], -2.0, bass),
    ("trummor", DRUMS, {"kick_tune": -2, "kick_decay": 380, "snare_snappy": 75, "snare_decay": 180, "hat_decay": 50, "level": -2},
        [("compressor", {"threshold": -18, "ratio": 3, "attack": 12, "release": 90}), ("saturator", {"drive": 3, "mix": 50})], 0.0, drums),
    ("ackord", SYNTH, {"osc1_wave": 0, "osc2_wave": 0, "osc2_detune": 9, "osc_mix": 50, "cutoff": 1400, "resonance": 30,
        "filter_env_amount": 45, "amp_attack": 2, "amp_decay": 260, "amp_sustain": 25, "amp_release": 180,
        "filter_decay": 220, "level": -10},
        [("phaser", {"rate": 0.25, "depth": 60, "mix": 40}), ("chorus", {"mix": 35}), ("plate_reverb", {"mix": 22, "decay": 1.8})], -3.0, stabs),
    ("extra", DRUMS, {"hat_decay": 35, "open_hat_decay": 320, "cymbal_decay": 1800, "tom_decay": 380, "level": -8},
        [("room_reverb", {"mix": 12, "decay": 0.9})], -2.0, extra),
    ("melodi", SYNTH, {"osc1_wave": 1, "osc2_wave": 1, "osc2_detune": 5, "osc_mix": 40, "cutoff": 2600, "resonance": 25,
        "filter_env_amount": 35, "amp_attack": 3, "amp_decay": 140, "amp_sustain": 45, "amp_release": 120, "glide": 30,
        "level": -12},
        [("mod_delay", {"time": 375, "feedback": 35, "mix": 25, "lpf": 5000}), ("plate_reverb", {"mix": 18, "decay": 2.2})], -4.0, lead),
]


def cmd(cid, params):
    return call("command", {"id": cid, "params": params})


def build():
    cmd("session.new", {"name": "Cykelmusik", "sample_rate": RATE})
    cmd("event.tempo", {"bpm": BPM})
    for name, instrument, params, inserts, fader, make in TRACKS:
        cmd("track.new", {"kind": "instrument", "name": name, "instrument": instrument, "format": "stereo"})
        cmd("mix.instrument", {"track": name, "plugin": instrument, "params": params})
        for slot, (plugin, p) in enumerate(inserts):
            cmd("mix.insert", {"track": name, "slot": slot, "plugin": plugin, "params": p})
        cmd("mix.volume", {"tracks": [name], "db": fader})
        notes = make()
        cmd("event.retrospective_record", {"track": name, "notes": notes})
        print(f"{name}: {len(notes)} noter")


# Level of each stem against the drums (dB of RMS), so the game can mix them at 0 dB.
BALANCE = {"trummor": 0.0, "bas": -3.0, "ackord": -8.0, "matta": -10.0, "melodi": -7.0, "extra": -9.0}
REFERENCE_RMS = 2177.0     # the drum stem as rendered


def fold_loop(src, dst, balance_db=None):
    """Keep the first BARS bars and add the tail after them onto the start; with balance_db, scale the
    stem so its RMS sits that many dB under the reference."""
    w = wave.open(src)
    ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    assert width == 2, "16-bit expected"
    data = array.array("h", w.readframes(n))
    w.close()
    loop = BARS * SAMPLES_PER_BAR * rate // RATE
    out = data[: loop * ch]
    if len(out) < loop * ch:
        out.extend([0] * (loop * ch - len(out)))
    tail = data[loop * ch:]
    for i in range(min(len(tail), len(out))):
        out[i] = out[i] + tail[i] if -32768 <= out[i] + tail[i] <= 32767 else (32767 if out[i] + tail[i] > 0 else -32768)
    if balance_db is not None:
        rms = (sum(x * x for x in out[::7]) / max(len(out) // 7, 1)) ** 0.5
        gain = REFERENCE_RMS * 10 ** (balance_db / 20.0) / max(rms, 1.0)
        out = array.array("h", (max(-32768, min(32767, int(x * gain))) for x in out))
    o = wave.open(dst, "wb")
    o.setnchannels(ch)
    o.setsampwidth(2)
    o.setframerate(rate)
    o.writeframes(out.tobytes())
    o.close()
    return loop / rate


if __name__ == "__main__":
    build()
    os.makedirs(OUT, exist_ok=True)
    raw = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stems")
    os.makedirs(raw, exist_ok=True)
    end = (BARS + TAIL_BARS) * SAMPLES_PER_BAR
    res = cmd("file.bounce_stems", {"dir": raw, "format": "wav", "bit_depth": 16, "start": 0, "end": end})
    print("stems:", res)
    cmd("session.save_as", {"path": os.path.join(os.path.dirname(os.path.abspath(__file__)), "cykelmusik.scraft"), "replace": True})
    for name, *_ in TRACKS:
        cands = [f for f in os.listdir(raw) if f.endswith(f" - {name}.wav") or f == name + ".wav"]
        if not cands:
            print("saknas:", name)
            continue
        seconds = fold_loop(os.path.join(raw, cands[0]), os.path.join(OUT, name + ".wav"), BALANCE[name])
        print(f"{name}.wav: {seconds:.1f} s loop")
