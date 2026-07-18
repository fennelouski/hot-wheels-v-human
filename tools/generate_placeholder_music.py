# Placeholder music synthesizer — stdlib only (wave + math).
#
#   python3 tools/generate_placeholder_music.py
#
# SFX are real (ElevenLabs, see Audio/SFX-SPEC.md); music is NOT — the
# API's 22 s limit rules it out. Until real tracks are picked per
# Audio/README.md, these two synthesized chiptune loops fill the slots so
# music start/stop/ducking is testable. Convert to .m4a per __main__.

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..",
                   "Hot Wheels v Human", "Resources", "Audio")


def write_wav(name, samples):
    path = os.path.join(OUT, name)
    clipped = bytearray()
    for s in samples:
        clipped += struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(clipped))
    print("wrote", path, f"{len(samples)/RATE:.1f}s")


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def tone(freq, seconds, volume=0.5, shape="sine", decay=0.0):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        phase = (t * freq) % 1
        if shape == "sine":
            v = math.sin(2 * math.pi * freq * t)
        elif shape == "square":
            v = 1 if phase < 0.5 else -1
        else:  # saw
            v = 2 * phase - 1
        env = math.exp(-decay * t) if decay else 1
        out.append(v * volume * env * 0.6)
    return out


def sweep(f0, f1, seconds, volume=0.5, decay=0.0):
    n = int(RATE * seconds)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (t / seconds)
        phase += f / RATE
        env = math.exp(-decay * t) if decay else 1
        out.append(math.sin(2 * math.pi * phase) * volume * env * 0.6)
    return out


def noise(seconds, volume=0.5, decay=6.0):
    rnd = random.Random(7)
    n = int(RATE * seconds)
    return [rnd.uniform(-1, 1) * volume * math.exp(-decay * (i / RATE)) * 0.6
            for i in range(n)]


def mix(*layers):
    n = max(len(l) for l in layers)
    return [sum(l[i] if i < len(l) else 0 for l in layers) for i in range(n)]


def engine_loop(seconds=10):
    # Putt-putt: 88.2 Hz saw (integer cycles at 44.1 kHz -> seamless loop)
    # amplitude-modulated at 14.7 Hz, pinch of noise.
    n = int(RATE * seconds)
    rnd = random.Random(3)
    out = []
    for i in range(n):
        t = i / RATE
        saw = 2 * ((t * 88.2) % 1) - 1
        putt = 0.65 + 0.35 * math.sin(2 * math.pi * 14.7 * t)
        out.append((saw * 0.35 + rnd.uniform(-1, 1) * 0.05) * putt)
    return out


def melody(notes, dur, shape="square", volume=0.35, gap=0.0):
    out = []
    for f in notes:
        out += tone(f, dur, volume, shape, decay=3) if f else silence(dur)
        out += silence(gap)
    return out


def music_loop(bass_notes, arp_notes, bars=8, bpm=112):
    beat = 60 / bpm
    bass, arp = [], []
    for bar in range(bars):
        root = bass_notes[bar % len(bass_notes)]
        for _ in range(4):
            bass += tone(root, beat, 0.22, "saw", decay=4)
        for note in arp_notes[bar % len(arp_notes)]:
            arp += tone(note, beat / 2, 0.14, "square", decay=5)
            arp += tone(note * 2, beat / 2, 0.10, "sine", decay=5)
    return mix(bass, arp)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # Music loops (workshop = mellow, race = driving); convert to m4a:
    #   afconvert <in.wav> -d aac -f m4af <out.m4a>
    write_wav("workshop_ambience.wav",
              music_loop([131, 98, 110, 98],
                         [[262, 330, 392, 330], [196, 247, 294, 247],
                          [220, 262, 330, 262], [196, 247, 294, 330]], bpm=92))
    write_wav("race_intensity.wav",
              music_loop([110, 110, 87, 98],
                         [[220, 277, 330, 440], [220, 277, 330, 440],
                          [175, 220, 262, 349], [196, 247, 294, 392]], bpm=138))
