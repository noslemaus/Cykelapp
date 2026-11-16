"""Nine songs for the worlds, three per world, each in tune with its place and with an 80s feel, made in
SoundCraft through its control channel (start it with `--control 7879`). Like the first song
(musik.py) each has six layers the game fades in with your power zone: matta (pad), bas, trummor,
ackord, extra (percussion, fills) and melodi (the lead), 16 bars that loop seamlessly.

    Skärgården  Midsommarnatt  118 BPM  E minor   synth-pop, arpeggios, gated snare
                Kustvägen      124 BPM  A major   driving 8th bass, plucks, bright lead
                Fyrljus         96 BPM  D minor   slow, wide pads, a lead with long echoes
    Egypten     Nilen          108 BPM  E Hijaz   maqsum rhythm, oud-like plucks, gliding lead
                Basaren        126 BPM  D Hijaz   Italo disco with darbuka on top
                Pyramiderna     92 BPM  A Hijaz   epic: big pads, floor toms, a slow majestic lead
    Japan       Neongatan      116 BPM  F         city pop: maj7 chords, popping bass, brass lead
                Sakura         100 BPM  D In      koto plucks, shakuhachi-like lead, taiko on the ends
                Shinkansen     128 BPM  A minor   synthwave: 16th bass, arpeggios, soaring lead

python3 -I latar.py <game dir>    writes game/audio/musik/<song>/<layer>.wav and latar.json
"""
import array
import json
import os
import random
import sys
import wave

GAME = sys.argv[1] if len(sys.argv) > 1 else "../../game"
sys.argv = sys.argv[:1]
HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, "sc.py")).read().split("if __name__")[0])

RATE = 22050
PPQ = 960
BAR = 4 * PPQ
BARS = 16
TAIL = 2
S16 = PPQ // 4                  # a 16th note in ticks
MONO = {"bas", "trummor", "extra"}
BALANCE = {"trummor": 0.0, "bas": -3.0, "ackord": -8.0, "matta": -10.0, "melodi": -7.0, "extra": -10.0}
REFERENCE_RMS = 2177.0


def note(p, start, length, vel):
    return {"pitch": int(p), "start_ticks": int(start), "length_ticks": int(max(length, 30)), "velocity": int(max(1, min(127, vel)))}


# --- Sounds ----------------------------------------------------------------------------------------

def synth(**kw):
    base = {"osc1_wave": 0, "osc2_wave": 0, "osc2_semitones": 0, "osc2_detune": 7, "osc_mix": 50, "cutoff": 2000,
            "resonance": 20, "filter_env_amount": 30, "amp_attack": 5, "amp_decay": 200, "amp_sustain": 70,
            "amp_release": 300, "filter_attack": 5, "filter_decay": 300, "filter_sustain": 30, "filter_release": 300,
            "glide": 0, "level": -8}
    base.update(kw)
    return base


PAD = synth(osc2_wave=3, osc2_semitones=12, osc2_detune=12, osc_mix=40, cutoff=1300, resonance=10, filter_env_amount=15,
            amp_attack=500, amp_decay=1500, amp_sustain=85, amp_release=1400, filter_attack=800, filter_decay=2000,
            filter_sustain=55, level=-12)
BASS = synth(osc1_wave=0, osc2_wave=1, osc2_semitones=-12, osc2_detune=0, osc_mix=35, cutoff=650, resonance=35,
             filter_env_amount=55, amp_attack=1, amp_decay=180, amp_sustain=45, amp_release=60, filter_decay=150,
             filter_sustain=12, level=-4)
POP_BASS = synth(osc1_wave=1, osc2_wave=0, osc2_semitones=12, osc2_detune=3, osc_mix=30, cutoff=900, resonance=45,
                 filter_env_amount=70, amp_attack=1, amp_decay=140, amp_sustain=20, amp_release=50, filter_decay=110,
                 filter_sustain=5, level=-4)
PLUCK = synth(osc1_wave=0, osc2_wave=1, osc2_detune=9, cutoff=1800, resonance=30, filter_env_amount=55, amp_attack=1,
              amp_decay=220, amp_sustain=0, amp_release=180, filter_decay=180, filter_sustain=0, level=-10)
OUD = synth(osc1_wave=0, osc2_wave=3, osc2_semitones=12, osc2_detune=4, osc_mix=35, cutoff=2400, resonance=40,
            filter_env_amount=60, amp_attack=1, amp_decay=260, amp_sustain=0, amp_release=150, filter_decay=140,
            filter_sustain=0, level=-10)
KOTO = synth(osc1_wave=0, osc2_wave=2, osc2_semitones=12, osc2_detune=2, osc_mix=30, cutoff=3200, resonance=25,
             filter_env_amount=60, amp_attack=1, amp_decay=420, amp_sustain=0, amp_release=300, filter_decay=200,
             filter_sustain=0, level=-10)
EP = synth(osc1_wave=2, osc2_wave=1, osc2_semitones=12, osc2_detune=2, osc_mix=25, cutoff=2600, resonance=10,
           filter_env_amount=25, amp_attack=2, amp_decay=600, amp_sustain=25, amp_release=350, filter_decay=500,
           filter_sustain=20, level=-10)
STAB = synth(osc1_wave=0, osc2_wave=0, osc2_detune=11, cutoff=1500, resonance=30, filter_env_amount=45, amp_attack=2,
             amp_decay=260, amp_sustain=25, amp_release=180, filter_decay=220, level=-10)
ARP = synth(osc1_wave=1, osc2_wave=0, osc2_semitones=12, osc2_detune=6, osc_mix=45, cutoff=2200, resonance=30,
            filter_env_amount=45, amp_attack=1, amp_decay=160, amp_sustain=20, amp_release=120, filter_decay=140,
            filter_sustain=10, level=-11)
LEAD = synth(osc1_wave=0, osc2_wave=1, osc2_detune=6, osc_mix=45, cutoff=2600, resonance=25, filter_env_amount=35,
             amp_attack=4, amp_decay=200, amp_sustain=60, amp_release=180, glide=25, level=-12)
BRASS = synth(osc1_wave=0, osc2_wave=0, osc2_detune=14, osc_mix=50, cutoff=1500, resonance=15, filter_env_amount=60,
              amp_attack=20, amp_decay=300, amp_sustain=70, amp_release=200, filter_attack=60, filter_decay=400,
              filter_sustain=40, level=-12)
NEY = synth(osc1_wave=3, osc2_wave=2, osc2_semitones=12, osc2_detune=5, osc_mix=30, cutoff=2400, resonance=15,
            filter_env_amount=20, amp_attack=60, amp_decay=400, amp_sustain=75, amp_release=300, glide=90, level=-11)
FLUTE = synth(osc1_wave=2, osc2_wave=3, osc2_detune=8, osc_mix=40, cutoff=2200, resonance=10, filter_env_amount=15,
              amp_attack=120, amp_decay=500, amp_sustain=80, amp_release=400, glide=120, level=-11)

GATED = [("compressor", {"threshold": -18, "ratio": 3, "attack": 10, "release": 90}),
         ("room_reverb", {"mix": 22, "decay": 0.7, "size": 70})]
DRUMS_80S = {"kick_tune": -2, "kick_decay": 360, "snare_snappy": 80, "snare_decay": 260, "hat_decay": 45, "level": -2}


# --- Patterns ------------------------------------------------------------------------------------

def per_bar(chords, bar):
    """chords: list of (root, voicing, bars); the chord sounding in this bar."""
    total = sum(c[2] for c in chords)
    b = bar % total
    for root, voicing, n in chords:
        if b < n:
            return root, voicing
        b -= n
    return chords[0][:2]


def pad_part(chords, octave=0, vel=78):
    out = []
    bar = 0
    k = 0
    while bar < BARS:
        root, voicing, n = chords[k % len(chords)]
        n = min(n, BARS - bar)
        for p in voicing:
            out.append(note(p + octave, bar * BAR, n * BAR - 100, vel))
        bar += n
        k += 1
    return out


def bass_part(chords, style):
    out = []
    for bar in range(BARS):
        root, _ = per_bar(chords, bar)
        b = bar * BAR
        if style == "octave8":            # disco/Italo: root–octave in 8ths
            for k in range(8):
                out.append(note(root + (12 if k % 2 else 0), b + k * 480, 380, 108 if k % 2 == 0 else 92))
        elif style == "drive8":           # 80s pop: straight 8ths on the root
            for k in range(8):
                out.append(note(root, b + k * 480, 400, 112 if k in (0, 4) else 96))
        elif style == "synthwave16":      # 16th octave arpeggio
            for k in range(16):
                out.append(note(root + (12 if k % 2 else 0), b + k * S16, 200, 104 if k % 4 == 0 else 86))
        elif style == "pop":              # city-pop: syncopated with octave pops
            for pos, up, ln, v in [(0, 0, 300, 112), (3, 12, 120, 96), (6, 0, 200, 100), (8, 0, 300, 108),
                                   (10, 12, 120, 94), (11, 7, 200, 92), (14, 12, 120, 98)]:
                out.append(note(root + up, b + pos * S16, ln, v))
        elif style == "maqsum":           # Egyptian ostinato under the maqsum rhythm
            for pos, up, v in [(0, 0, 112), (3, 0, 92), (4, 12, 100), (8, 0, 108), (11, 7, 92), (12, 12, 100)]:
                out.append(note(root + up, b + pos * S16, 260, v))
        elif style == "slow":             # half notes with a passing note
            out.append(note(root, b, 1800, 108))
            out.append(note(root + (7 if bar % 2 else 12), b + 2 * PPQ, 1700, 98))
        elif style == "drone":
            out.append(note(root, b, BAR - 60, 104))
    return out


def drum_part(style):
    out = []
    for bar in range(BARS):
        b = bar * BAR
        if style in ("pop", "synthwave"):
            for q in (0, 2):
                out.append(note(36, b + q * PPQ, 200, 122))
            if style == "pop":
                out.append(note(36, b + 2 * PPQ - 480, 200, 100))
            for q in (1, 3):
                out.append(note(38, b + q * PPQ, 200, 112))
                out.append(note(39, b + q * PPQ, 200, 90))
            for k in range(8 if style == "pop" else 16):
                step = 480 if style == "pop" else S16
                out.append(note(42, b + k * step, 90, 84 if k % 2 == 0 else 62))
        elif style == "disco":
            for q in range(4):
                out.append(note(36, b + q * PPQ, 200, 122))
                out.append(note(46, b + q * PPQ + 480, 220, 84))
            for q in (1, 3):
                out.append(note(39, b + q * PPQ, 200, 104))
        elif style == "maqsum":           # D T . T D . T . in 8ths
            for pos8, kind in [(0, "D"), (1, "T"), (3, "T"), (4, "D"), (6, "T")]:
                t = b + pos8 * 480
                if kind == "D":
                    out.append(note(36, t, 200, 118))
                    out.append(note(45, t, 200, 96))
                else:
                    out.append(note(38, t, 160, 92))
            for k in range(8):
                out.append(note(42, b + k * 480 + 240, 80, 58))
        elif style == "halftime":
            out.append(note(36, b, 200, 120))
            out.append(note(36, b + 3 * PPQ + 480, 200, 96))
            out.append(note(38, b + 2 * PPQ, 240, 112))
            for k in range(8):
                out.append(note(42, b + k * 480, 90, 70 if k % 2 == 0 else 52))
        elif style == "epic":
            out.append(note(36, b, 200, 122))
            out.append(note(41, b + 2 * PPQ, 400, 112))
            out.append(note(43, b + 2 * PPQ + 480, 400, 100))
            out.append(note(38, b + 3 * PPQ, 260, 108))
        elif style == "soft":
            for q in (0, 2):
                out.append(note(36, b + q * PPQ, 200, 108))
            for q in (1, 3):
                out.append(note(37, b + q * PPQ, 160, 96))
            for k in range(8):
                out.append(note(42, b + k * 480, 70, 56))
    return out


def extra_part(style):
    out = []
    for bar in range(BARS):
        b = bar * BAR
        if style == "shaker":
            for k in range(16):
                if k % 4 != 0:
                    out.append(note(42, b + k * S16 + (18 if k % 2 else 0), 60, 44 + (12 if k % 4 == 2 else 0)))
        elif style == "darbuka":
            for k, v in [(2, 74), (5, 80), (7, 70), (10, 78), (13, 84), (14, 70), (15, 88)]:
                out.append(note(48 if k % 2 else 50, b + k * S16, 120, v))
        elif style == "taiko":
            if bar % 4 == 3:
                for k, p in enumerate([41, 41, 43, 45, 41, 43]):
                    out.append(note(p, b + 2 * PPQ + k * 320, 300, 100 + k * 3))
            out.append(note(41, b, 400, 84))
        elif style == "openhat":
            out.append(note(46, b + 3 * PPQ + 480, 300, 84))
            for k in range(16):
                if k % 2:
                    out.append(note(42, b + k * S16, 70, 50))
        if bar in (0, 8):
            out.append(note(49, b, 1400, 92))
        if bar in (7, 15):
            for k, p in enumerate([50, 48, 47, 45, 43, 41]):
                out.append(note(p, b + 3 * PPQ - 480 + k * 240, 200, 94 + k * 4))
    return out


def chord_part(chords, style, octave=12):
    out = []
    for bar in range(BARS):
        root, voicing = per_bar(chords, bar)
        b = bar * BAR
        tones = [p + octave for p in voicing]
        if style == "arp16":
            seq = tones + [tones[0] + 12] + tones[::-1][1:-1]
            for k in range(16):
                out.append(note(seq[k % len(seq)], b + k * S16, 200, 92 if k % 4 == 0 else 72))
        elif style == "arp8":
            seq = tones + [tones[0] + 12]
            for k in range(8):
                out.append(note(seq[k % len(seq)], b + k * 480, 420, 86 if k % 2 == 0 else 70))
        elif style == "offbeat":
            for k in (1, 3, 5, 7):
                for p in tones:
                    out.append(note(p, b + k * 480, 200, 90))
        elif style == "citypop":
            for pos, ln in [(2, 200), (6, 380), (10, 200), (13, 200)]:
                for p in tones:
                    out.append(note(p, b + pos * S16, ln, 84))
        elif style == "pluckscale":          # oud/koto: runs through the scale over the chord
            seq = tones + [tones[1] + 12, tones[0] + 12, tones[2]]
            for k, pos in enumerate([0, 2, 3, 6, 8, 10, 11, 14]):
                out.append(note(seq[k % len(seq)], b + pos * S16, 240, 96 if pos in (0, 8) else 74))
        elif style == "stab":
            if bar % 2 == 0:
                for p in tones:
                    out.append(note(p, b, 600, 96))
            for k in (3, 6):
                for p in tones:
                    out.append(note(p, b + k * 480, 180, 88))
    return out


def melody_part(chords, scale, rng, center=76, style="hook"):
    """A 4-bar phrase built from chord tones on the strong beats and scale steps between, played as
    A A' B A'' over 16 bars (the second half of each 8 answered a little higher)."""
    rhythms = {
        "hook": [[(0, 2), (2, 1), (3, 3), (6, 2), (8, 2), (10, 2), (12, 4)],
                 [(0, 3), (3, 1), (4, 2), (6, 2), (8, 6), (14, 2)],
                 [(0, 2), (2, 2), (4, 2), (6, 2), (8, 2), (10, 2), (12, 2), (14, 2)],
                 [(0, 8), (8, 4), (12, 4)]],
        "long": [[(0, 8), (8, 8)], [(0, 6), (6, 2), (8, 8)], [(0, 4), (4, 4), (8, 8)], [(0, 16)]],
        "busy": [[(0, 1), (1, 1), (2, 2), (4, 1), (5, 1), (6, 2), (8, 2), (10, 1), (11, 1), (12, 4)],
                 [(0, 2), (2, 2), (4, 4), (8, 1), (9, 1), (10, 2), (12, 4)],
                 [(0, 1), (2, 1), (3, 1), (4, 4), (8, 2), (10, 2), (12, 2), (14, 2)],
                 [(0, 4), (4, 2), (6, 2), (8, 8)]],
    }[style]
    # The scale is given as pitch classes from C; the lead stays around `center`.
    pool = sorted({base + (s % 12) for base in (48, 60, 72, 84) for s in scale})
    octave = center

    def phrase(start_bar, lift):
        notes = []
        last = None
        for bar in range(4):
            root, voicing = per_bar(chords, start_bar + bar)
            chord_pcs = {p % 12 for p in voicing}
            for pos, ln in rhythms[(bar + lift) % 4]:
                strong = pos in (0, 8)
                cands = [p for p in pool if (p % 12 in chord_pcs) == strong or not strong]
                ranged = [p for p in cands if octave - 5 + lift * 2 <= p <= octave + 12 + lift * 2]
                cands = ranged or cands
                if last is not None:
                    cands.sort(key=lambda p: abs(p - last) + rng.random() * 3)
                    p = cands[min(len(cands) - 1, rng.choice([0, 0, 1, 1, 2]))]
                else:
                    p = rng.choice([q for q in cands if q % 12 in chord_pcs] or cands)
                last = p
                notes.append((bar, pos, ln, p, 104 if strong else 90))
        return notes

    out = []
    a = phrase(0, 0)
    b_part = phrase(8, 1)
    for start, ph, shift in [(0, a, 0), (4, a, 0), (8, b_part, 0), (12, a, 0)]:
        for bar, pos, ln, p, v in ph:
            if start == 4 and bar == 3:
                continue                # leave a breath before the answer
            out.append(note(p + shift, (start + bar) * BAR + pos * S16, ln * S16 - 30, v))
    return out


# --- The songs -----------------------------------------------------------------------------------

def tri(r, minor=True, seventh=False):
    t = [r, r + (3 if minor else 4), r + 7]
    if seventh:
        t.append(r + (10 if minor else 11))
    return t


SONGS = [
    {"id": "midsommarnatt", "name": "Midsommarnatt", "en": "Midsummer Night", "world": "skargarden", "bpm": 118,
     "chords": [(40, [55, 59, 64], 2), (36, [55, 60, 64], 2), (43, [55, 59, 62], 2), (38, [54, 57, 62], 2)],
     "scale": [4, 6, 7, 9, 11, 12, 14], "bass": "drive8", "drums": "pop", "extra": "shaker", "chord": "arp16",
     "lead": ("hook", 76, LEAD), "chord_sound": ARP, "pad": PAD, "bass_sound": BASS},
    {"id": "kustvagen", "name": "Kustvägen", "en": "Coast Road", "world": "skargarden", "bpm": 124,
     "chords": [(45, [57, 61, 64], 2), (40, [56, 59, 64], 2), (42, [57, 61, 66], 2), (38, [57, 62, 66], 2)],
     "scale": [9, 11, 13, 14, 16, 18, 20], "bass": "drive8", "drums": "pop", "extra": "openhat", "chord": "offbeat",
     "lead": ("hook", 76, BRASS), "chord_sound": PLUCK, "pad": PAD, "bass_sound": BASS},
    {"id": "fyrljus", "name": "Fyrljus", "en": "Beacon", "world": "skargarden", "bpm": 96,
     "chords": [(38, [57, 62, 65], 2), (34, [58, 62, 65], 2), (41, [57, 60, 65], 2), (36, [55, 60, 64], 2)],
     "scale": [2, 4, 5, 7, 9, 10, 12], "bass": "slow", "drums": "halftime", "extra": "shaker", "chord": "arp8",
     "lead": ("long", 74, LEAD), "chord_sound": ARP, "pad": PAD, "bass_sound": BASS, "echo": 470},
    {"id": "nilen", "name": "Nilen", "en": "The Nile", "world": "egypten", "bpm": 108,
     "chords": [(40, [56, 59, 64], 2), (41, [57, 60, 65], 1), (40, [56, 59, 64], 1), (38, [57, 62, 65], 2), (40, [56, 59, 64], 2)],
     "scale": [4, 5, 8, 9, 11, 12, 14], "bass": "maqsum", "drums": "maqsum", "extra": "darbuka", "chord": "pluckscale",
     "lead": ("hook", 76, NEY), "chord_sound": OUD, "pad": PAD, "bass_sound": BASS},
    {"id": "basaren", "name": "Basaren", "en": "The Bazaar", "world": "egypten", "bpm": 126,
     "chords": [(38, [54, 57, 62], 2), (39, [55, 58, 63], 2), (38, [54, 57, 62], 2), (36, [55, 60, 63], 2)],
     "scale": [2, 3, 6, 7, 9, 10, 12], "bass": "octave8", "drums": "disco", "extra": "darbuka", "chord": "stab",
     "lead": ("busy", 74, LEAD), "chord_sound": STAB, "pad": PAD, "bass_sound": BASS},
    {"id": "pyramiderna", "name": "Pyramiderna", "en": "The Pyramids", "world": "egypten", "bpm": 92,
     "chords": [(45, [57, 61, 64], 2), (46, [58, 62, 65], 2), (45, [57, 61, 64], 2), (43, [55, 58, 62], 2)],
     "scale": [9, 10, 13, 14, 16, 17, 19], "bass": "drone", "drums": "epic", "extra": "taiko", "chord": "arp8",
     "lead": ("long", 76, NEY), "chord_sound": OUD, "pad": PAD, "bass_sound": BASS, "echo": 490},
    {"id": "neongatan", "name": "Neongatan", "en": "Neon Street", "world": "japan", "bpm": 116,
     "chords": [(41, [57, 60, 64, 65], 2), (40, [55, 59, 62, 64], 2), (38, [57, 60, 62, 65], 2), (36, [55, 59, 60, 64], 2)],
     "scale": [5, 7, 9, 12, 14, 17, 19], "bass": "pop", "drums": "pop", "extra": "openhat", "chord": "citypop",
     "lead": ("hook", 77, BRASS), "chord_sound": EP, "pad": PAD, "bass_sound": POP_BASS},
    {"id": "sakura", "name": "Sakura", "en": "Sakura", "world": "japan", "bpm": 100,
     "chords": [(38, [57, 62, 65], 2), (34, [58, 62, 65], 2), (43, [55, 58, 62], 2), (38, [57, 62, 63], 2)],
     "scale": [2, 3, 7, 9, 10, 14, 15], "bass": "slow", "drums": "soft", "extra": "taiko", "chord": "pluckscale",
     "lead": ("long", 74, FLUTE), "chord_sound": KOTO, "pad": PAD, "bass_sound": BASS, "echo": 450},
    {"id": "shinkansen", "name": "Shinkansen", "en": "Shinkansen", "world": "japan", "bpm": 128,
     "chords": [(45, [57, 60, 64], 2), (41, [57, 60, 65], 2), (36, [55, 60, 64], 2), (43, [55, 59, 62], 2)],
     "scale": [9, 12, 14, 16, 19, 21, 24], "bass": "synthwave16", "drums": "synthwave", "extra": "openhat", "chord": "arp16",
     "lead": ("hook", 76, LEAD), "chord_sound": ARP, "pad": PAD, "bass_sound": BASS},
]


def cmd(cid, params):
    return call("command", {"id": cid, "params": params})


def build(song):
    rng = random.Random(song["id"])
    cmd("session.new", {"name": song["id"], "sample_rate": RATE})
    cmd("event.tempo", {"bpm": song["bpm"]})
    style, octave, lead_sound = song["lead"]
    eighth_ms = round(60000 / song["bpm"] * 0.75)          # a dotted 8th, the classic 80s echo
    echo = song.get("echo", eighth_ms)
    layers = [
        ("matta", "subtractive_synth", song["pad"], pad_part(song["chords"]),
         [("chorus", {"mix": 50, "rate": 0.35}), ("plate_reverb", {"mix": 40, "decay": 4.0})]),
        ("bas", "subtractive_synth", song["bass_sound"], bass_part(song["chords"], song["bass"]),
         [("saturator", {"drive": 5, "mix": 50}), ("compressor", {"threshold": -20, "ratio": 4, "attack": 5, "release": 80})]),
        ("trummor", "drum_synth", DRUMS_80S, drum_part(song["drums"]), GATED),
        ("ackord", "subtractive_synth", song["chord_sound"], chord_part(song["chords"], song["chord"]),
         [("chorus", {"mix": 35}), ("mod_delay", {"time": echo, "feedback": 30, "mix": 20, "lpf": 4000}),
          ("plate_reverb", {"mix": 20, "decay": 1.8})]),
        ("extra", "drum_synth", {"hat_decay": 35, "open_hat_decay": 320, "tom_decay": 380, "cymbal_decay": 1800, "level": -8},
         extra_part(song["extra"]), [("room_reverb", {"mix": 14, "decay": 0.9})]),
        ("melodi", "subtractive_synth", lead_sound, melody_part(song["chords"], song["scale"], rng, octave, style),
         [("mod_delay", {"time": echo, "feedback": 38, "mix": 26, "lpf": 5000}), ("plate_reverb", {"mix": 22, "decay": 2.4})]),
    ]
    for name, instrument, params, notes, inserts in layers:
        cmd("track.new", {"kind": "instrument", "name": name, "instrument": instrument, "format": "stereo"})
        cmd("mix.instrument", {"track": name, "plugin": instrument, "params": params})
        for slot, (plugin, p) in enumerate(inserts):
            cmd("mix.insert", {"track": name, "slot": slot, "plugin": plugin, "params": p})
        cmd("event.retrospective_record", {"track": name, "notes": notes})
    samples_per_bar = round(RATE * 60 * 4 / song["bpm"])
    raw = os.path.join(HERE, "stems", song["id"])
    os.makedirs(raw, exist_ok=True)
    cmd("file.bounce_stems", {"dir": raw, "format": "wav", "bit_depth": 16, "start": 0,
                              "end": (BARS + TAIL) * samples_per_bar})
    return raw, samples_per_bar


def fold(src, dst, loop_frames, balance_db, mono):
    w = wave.open(src)
    ch, n = w.getnchannels(), w.getnframes()
    data = array.array("h", w.readframes(n))
    w.close()
    frames = [data[i::ch] for i in range(ch)]
    if mono and ch == 2:
        frames = [array.array("h", ((a + b) // 2 for a, b in zip(frames[0], frames[1])))]
    out_ch = []
    for f in frames:
        body = f[:loop_frames]
        if len(body) < loop_frames:
            body.extend([0] * (loop_frames - len(body)))
        tail = f[loop_frames:]
        body = array.array("h", (max(-32768, min(32767, body[i] + (tail[i] if i < len(tail) else 0))) for i in range(loop_frames)))
        out_ch.append(body)
    rms = (sum(x * x for x in out_ch[0][::7]) / max(len(out_ch[0]) // 7, 1)) ** 0.5
    gain = REFERENCE_RMS * 10 ** (balance_db / 20.0) / max(rms, 1.0)
    peak = max(max(abs(min(c)), max(c)) for c in out_ch)
    gain = min(gain, 30000.0 / max(peak, 1))          # sparse drums: never clip
    if len(out_ch) == 1:
        inter = out_ch[0]
    else:
        inter = array.array("h", [0]) * (loop_frames * 2)
        inter[0::2] = out_ch[0]
        inter[1::2] = out_ch[1]
    inter = array.array("h", (max(-32768, min(32767, int(x * gain))) for x in inter))
    o = wave.open(dst, "wb")
    o.setnchannels(len(out_ch))
    o.setsampwidth(2)
    o.setframerate(RATE)
    o.writeframes(inter.tobytes())
    o.close()


def main():
    only = os.environ.get("BARA")          # BARA=nilen renders just that song
    out_root = os.path.join(GAME, "audio", "musik")
    manifest_path = os.path.join(out_root, "latar.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    manifest["original"] = {"name": "Klassikern", "en": "The Classic", "world": "", "bpm": 120, "folder": ""}
    for song in SONGS:
        if only and song["id"] != only:
            continue
        if os.environ.get("OMFORMA"):        # OMFORMA=1: fold the saved stems again, no new render
            raw = os.path.join(HERE, "stems", song["id"])
            spb = round(RATE * 60 * 4 / song["bpm"])
        else:
            raw, spb = build(song)
        dst = os.path.join(out_root, song["id"])
        os.makedirs(dst, exist_ok=True)
        for layer in ["matta", "bas", "trummor", "ackord", "extra", "melodi"]:
            src = [f for f in os.listdir(raw) if f.endswith(f" - {layer}.wav")][0]
            fold(os.path.join(raw, src), os.path.join(dst, layer + ".wav"), BARS * spb, BALANCE[layer], layer in MONO)
        manifest[song["id"]] = {"name": song["name"], "en": song["en"], "world": song["world"], "bpm": song["bpm"],
                                "folder": song["id"]}
        print(f"{song['name']}: klar ({BARS * spb / RATE:.1f} s loop)")
    json.dump(manifest, open(manifest_path, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
