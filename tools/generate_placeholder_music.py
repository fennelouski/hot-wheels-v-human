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




# ── Radio stations ─────────────────────────────────────────────────────
# The FPV dashboard's six presets. Same stdlib synth as the two loops
# above; what separates the genres is tempo, the drum pattern and the
# waveform, which is about as far as a square wave can carry a genre.
# Placeholder quality on purpose — see Audio/README.md. The 8-BIT preset
# has no file of its own: it plays `race_intensity`, which is already a
# chiptune loop.


def bed(seconds):
    return [0.0] * int(RATE * seconds)


def place(buf, at, samples, gain=1.0):
    """Mix `samples` into `buf` starting at `at` seconds (wraps nothing —
    anything past the end is dropped, which keeps the loop point clean)."""
    start = int(at * RATE)
    for j, s in enumerate(samples):
        k = start + j
        if k >= len(buf):
            break
        buf[k] += s * gain
    return buf


def kick(volume=0.9):
    return sweep(150, 45, 0.16, volume=volume, decay=26)


def snare(volume=0.5):
    return mix(noise(0.14, volume, decay=26),
               tone(190, 0.14, volume * 0.5, "sine", decay=30))


def hat(volume=0.14, seconds=0.045):
    return noise(seconds, volume, decay=90)


def crunch(samples, drive=2.6):
    """Soft-clip: the one trick that makes a saw read as a guitar."""
    return [max(-0.8, min(0.8, s * drive)) for s in samples]


def lead(freq, seconds, volume=0.4, depth=4.0, rate=5.0, decay=0.7):
    """Sine with vibrato and a slow attack — the smooth-jazz 'sax'."""
    n = int(RATE * seconds)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += (freq + depth * math.sin(2 * math.pi * rate * t)) / RATE
        env = min(1.0, t * 8) * math.exp(-decay * t)
        out.append(math.sin(2 * math.pi * phase) * volume * env * 0.6)
    return out


def chord(freqs, seconds, volume=0.12, shape="sine", decay=2.0):
    return mix(*[tone(f, seconds, volume, shape, decay) for f in freqs])


def station_rock(bars=8, bpm=142):
    """Power chords on straight eighths, backbeat snare."""
    beat = 60 / bpm
    buf = bed(bars * 4 * beat)
    roots = [110.0, 110.0, 87.3, 98.0]          # A A F G
    for bar in range(bars):
        root, bar_at = roots[bar % 4], bar * 4 * beat
        for eighth in range(8):
            stab = crunch(mix(tone(root, beat * 0.45, 0.3, "saw", decay=7),
                              tone(root * 1.5, beat * 0.45, 0.24, "saw", decay=7)))
            place(buf, bar_at + eighth * beat / 2, stab, 0.5)
        for b in (0, 2):
            place(buf, bar_at + b * beat, kick())
        for b in (1, 3):
            place(buf, bar_at + b * beat, snare())
        if bar % 4 == 3:                         # fill
            for i in range(4):
                place(buf, bar_at + 3 * beat + i * beat / 4, snare(0.4))
    return buf


def station_jazz(bars=8, bpm=132):
    """Walking bass in quarters, swung ride, seventh-chord stabs."""
    beat = 60 / bpm
    swing = beat / 3                             # triplet feel
    buf = bed(bars * 4 * beat)
    walks = [[98.0, 110.0, 123.5, 131.0], [110.0, 123.5, 131.0, 147.0],
             [87.3, 98.0, 110.0, 116.5], [98.0, 87.3, 82.4, 98.0]]
    stabs = [[262, 311, 392], [294, 349, 440], [233, 277, 349], [262, 330, 392]]
    for bar in range(bars):
        bar_at = bar * 4 * beat
        for b, note in enumerate(walks[bar % 4]):
            place(buf, bar_at + b * beat, tone(note, beat * 0.9, 0.3, "sine", decay=3))
            place(buf, bar_at + b * beat, hat(0.10, 0.07))          # ride
            place(buf, bar_at + b * beat + 2 * swing, hat(0.07, 0.05))
        place(buf, bar_at + beat, snare(0.22))                       # brush 2
        place(buf, bar_at + 3 * beat, snare(0.22))                   # and 4
        place(buf, bar_at + beat / 2, chord(stabs[bar % 4], beat, 0.10, "sine", 3.5))
    return buf


def station_pop(bars=8, bpm=124):
    """Four-on-the-floor, bright square arp, claps on the backbeat."""
    beat = 60 / bpm
    buf = bed(bars * 4 * beat)
    roots = [131.0, 98.0, 110.0, 147.0]          # C G A F
    arps = [[523, 659, 784, 659], [392, 494, 587, 494],
            [440, 523, 659, 523], [349, 440, 523, 440]]
    for bar in range(bars):
        root, bar_at = roots[bar % 4], bar * 4 * beat
        for b in range(4):
            place(buf, bar_at + b * beat, kick(0.8))
            place(buf, bar_at + b * beat, tone(root, beat * 0.8, 0.26, "sine", decay=5))
            place(buf, bar_at + b * beat + beat / 2, hat(0.12))
        for b in (1, 3):
            place(buf, bar_at + b * beat, snare(0.42))
        for i, note in enumerate(arps[bar % 4] * 2):
            place(buf, bar_at + i * beat / 2,
                  tone(note, beat * 0.45, 0.13, "square", decay=6))
    return buf


def station_funk(bars=8, bpm=106):
    """Syncopated sixteenth bass, muted stabs, hats all the way down."""
    beat = 60 / bpm
    six = beat / 4
    buf = bed(bars * 4 * beat)
    # Sixteenth grid: 1 = bass note, . = rest. One bar of Clyde Stubblefield.
    pattern = "*..*.*..*..*.*.."
    roots = [73.4, 73.4, 98.0, 87.3]             # D D G F
    for bar in range(bars):
        root, bar_at = roots[bar % 4], bar * 4 * beat
        for i, hit in enumerate(pattern):
            if hit == "*":
                place(buf, bar_at + i * six,
                      tone(root, six * 1.6, 0.34, "saw", decay=14))
            place(buf, bar_at + i * six, hat(0.09 if i % 2 else 0.15))
        place(buf, bar_at, kick())
        place(buf, bar_at + 2.5 * beat, kick(0.7))
        for b in (1, 3):
            place(buf, bar_at + b * beat, snare(0.45))
        if bar % 2 == 1:                          # clav stab off the beat
            place(buf, bar_at + 1.75 * beat,
                  chord([root * 4, root * 5, root * 6], six * 2, 0.11, "square", 12))
    return buf


def station_smooth(bars=8, bpm=84):
    """Slow pads, brushed backbeat, a vibrato lead that takes its time."""
    beat = 60 / bpm
    buf = bed(bars * 4 * beat)
    pads = [[196, 247, 294], [175, 220, 262], [165, 208, 247], [147, 185, 220]]
    tune = [[392, 440, 494], [349, 392, 440], [330, 392, 349], [294, 330, 392]]
    for bar in range(bars):
        bar_at = bar * 4 * beat
        place(buf, bar_at, chord(pads[bar % 4], beat * 4, 0.12, "sine", 0.5))
        place(buf, bar_at, tone(pads[bar % 4][0] / 2, beat * 3.6, 0.24, "sine", decay=1))
        for b in (1, 3):
            place(buf, bar_at + b * beat, snare(0.16))
        for i, note in enumerate(tune[bar % 4]):
            place(buf, bar_at + (i + 1) * beat, lead(note, beat * 1.4))
    return buf


def level(samples, target_rms=0.055, fade=0.015):
    """Match the two original loops' level — a radio whose presets jump in
    volume is a radio a kid stops touching — then fade the last few
    milliseconds so the loop point doesn't click (the smooth station's pad
    is still ringing when the bar ends).
    """
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) or 1
    gain = target_rms / rms
    peak = max(abs(s) for s in samples) * gain
    if peak > 0.9:                       # leave the drum transients headroom
        gain *= 0.9 / peak
    out = [s * gain for s in samples]
    n = int(fade * RATE)
    for i in range(n):
        out[i] *= i / n
        out[-1 - i] *= i / n
    return out


def leveled(builder):
    return lambda: level(builder())


STATIONS = {
    "radio_rock": leveled(station_rock),
    "radio_jazz": leveled(station_jazz),
    "radio_pop": leveled(station_pop),
    "radio_funk": leveled(station_funk),
    "radio_smooth": leveled(station_smooth),
}


def write_music(name, samples):
    """WAV → AAC .m4a (music ships as m4a, SFX as wav — Audio/README)."""
    import subprocess
    write_wav(name + ".wav", samples)
    wav = os.path.join(OUT, name + ".wav")
    subprocess.run(["afconvert", wav, "-d", "aac", "-f", "m4af",
                    os.path.join(OUT, name + ".m4a")], check=True)
    os.remove(wav)


TRACKS = dict(STATIONS)
# Workshop = mellow, race = driving. race_intensity doubles as the radio's
# 8-BIT preset, which is why the stations don't ship one of their own.
TRACKS["workshop_ambience"] = lambda: music_loop(
    [131, 98, 110, 98],
    [[262, 330, 392, 330], [196, 247, 294, 247],
     [220, 262, 330, 262], [196, 247, 294, 330]], bpm=92)
TRACKS["race_intensity"] = lambda: music_loop(
    [110, 110, 87, 98],
    [[220, 277, 330, 440], [220, 277, 330, 440],
     [175, 220, 262, 349], [196, 247, 294, 392]], bpm=138)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    # No args = every track. Name tracks to rewrite just those, which is how
    # you add a station without churning the committed m4a of the others.
    wanted = sys.argv[1:] or sorted(TRACKS)
    for name in wanted:
        write_music(name, TRACKS[name]())
