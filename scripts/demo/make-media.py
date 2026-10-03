#!/usr/bin/env python3
"""Turns a recorded tour (demo.mov + cues.json) into the README media.

Scores the video with a synthesized soundtrack whose effects land on the tour's cues, then writes
docs/media/demo.mp4, docs/media/demo.gif and one screenshot per `shot:` cue. Pure standard library
plus ffmpeg, so it runs on a stock Mac with Homebrew's ffmpeg.
"""

import array
import json
import math
import random
import subprocess
import sys
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "build" / "demo-raw"
OUT = ROOT / "docs" / "media"
WORK = ROOT / "build" / "media-work"

# The panel's area in the 2560x1440 recording, without the captions underneath.
PANEL_CROP = "1260:770:650:0"
# Alerts only take the top of the notch.
PEEK_CROP = "940:240:810:0"
PEEK_SHOTS = {"01-alerts", "06-ci-passed"}
# The stretch of the tour the README's GIF loops: alert, open, both tabs.
GIF_START, GIF_END = 12.6, 26.2


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


class Track:
    def __init__(self, seconds):
        self.samples = array.array("d", bytes(8 * int(seconds * RATE)))

    def add(self, start, sound, gain=1.0):
        offset = int(start * RATE)
        end = min(len(self.samples), offset + len(sound))
        for i in range(max(0, offset), end):
            self.samples[i] += sound[i - offset] * gain

    def write(self, path):
        peak = max(1e-9, max(abs(s) for s in self.samples))
        scale = 0.89 / peak
        pcm = array.array("h", (int(s * scale * 32767) for s in self.samples))
        with wave.open(str(path), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(pcm.tobytes())


def envelope(i, length, attack, release):
    t = i / RATE
    total = length / RATE
    level = min(1.0, t / attack) if attack else 1.0
    if t > total - release:
        level *= max(0.0, (total - t) / release)
    return level


def pad_chord(midis, seconds):
    """Soft detuned sines that swell in and fade out: the bed under the whole video."""
    length = int(seconds * RATE)
    voices = [(note(m) * d, random.random() * math.tau) for m in midis for d in (0.997, 1.003)]
    out = array.array("d", bytes(8 * length))
    for i in range(length):
        t = i / RATE
        value = sum(math.sin(math.tau * f * t + phase) for f, phase in voices)
        out[i] = value / len(voices) * envelope(i, length, 1.2, 1.6)
    return out


def pluck(midi, seconds=1.4, brightness=0.25):
    length = int(seconds * RATE)
    f = note(midi)
    out = array.array("d", bytes(8 * length))
    for i in range(length):
        t = i / RATE
        decay = math.exp(-t * 3.2)
        tone = math.sin(math.tau * f * t) + brightness * math.sin(math.tau * 2 * f * t) * math.exp(-t * 6)
        out[i] = tone * decay * min(1.0, t / 0.004)
    return out


def chime(midis, gap=0.09):
    """The peek sound: a quick rising pair of bell tones."""
    parts = [pluck(m, 1.6, 0.5) for m in midis]
    length = len(parts[0]) + int(gap * RATE) * (len(parts) - 1)
    out = array.array("d", bytes(8 * length))
    for n, part in enumerate(parts):
        offset = int(n * gap * RATE)
        for i, s in enumerate(part):
            out[offset + i] += s
    return out


def whoosh(seconds, rising):
    """Noise through a three-pole low-pass whose cutoff sweeps, shaped like the notch's spring."""
    length = int(seconds * RATE)
    out = array.array("d", bytes(8 * length))
    stages = [0.0, 0.0, 0.0]
    for i in range(length):
        progress = i / length
        sweep = progress if rising else 1 - progress
        cutoff = 180 + 1400 * sweep ** 2
        alpha = 1 - math.exp(-math.tau * cutoff / RATE)
        value = random.uniform(-1, 1)
        for n in range(3):
            stages[n] += alpha * (value - stages[n])
            value = stages[n]
        shape = math.sin(math.pi * min(1.0, progress * (1.6 if rising else 1.2))) ** 2
        out[i] = value * shape * 6
    return out


def click(seconds=0.025, pitch=1800):
    length = int(seconds * RATE)
    out = array.array("d", bytes(8 * length))
    noise = 0.0
    for i in range(length):
        t = i / RATE
        decay = math.exp(-t * 260)
        noise += 0.35 * (random.uniform(-1, 1) - noise)
        out[i] = (0.8 * noise + math.sin(math.tau * pitch * t)) * decay
    return out


def soundtrack(cues, seconds):
    random.seed(7)
    music = Track(seconds)
    # Fmaj9 → Am7 → Dm9 → Bbmaj7, four bars of four seconds, looped under the tour.
    progression = [[53, 60, 64, 67, 69], [57, 60, 64, 67], [50, 57, 60, 64, 65], [46, 57, 62, 65, 69]]
    bar = 4.0
    chord_sounds = [pad_chord(c, bar + 1.6) for c in progression]
    arpeggio_notes = [[72, 76, 79, 81], [72, 76, 79, 84], [74, 77, 81, 76], [74, 77, 81, 79]]
    start, index = 0.0, 0
    while start < seconds:
        music.add(start, chord_sounds[index % 4], 0.5)
        for step, midi in enumerate(arpeggio_notes[index % 4]):
            music.add(start + step * bar / 4 + 0.15, pluck(midi), 0.10)
        start += bar
        index += 1

    effects = Track(seconds)
    open_sound, close_sound = whoosh(0.55, True), whoosh(0.45, False)
    peek_sound, done_sound = chime([79, 86]), chime([72, 79, 84], 0.12)
    for cue in cues:
        t, kind = cue["time"], cue["kind"]
        if kind == "open":
            effects.add(t - 0.05, open_sound, 0.35)
        elif kind == "close":
            effects.add(t - 0.05, close_sound, 0.25)
        elif kind == "peek":
            effects.add(t, peek_sound, 0.35)
        elif kind == "key":
            effects.add(t, click(), 0.30)
        elif kind == "type":
            effects.add(t, click(0.018, 2400), 0.22)
        elif kind == "end-card":
            effects.add(t + 0.2, done_sound, 0.30)

    music.write(WORK / "music.wav")
    effects.write(WORK / "effects.wav")
    fade_start = seconds - 2.5
    ffmpeg(
        "-i", str(WORK / "music.wav"), "-i", str(WORK / "effects.wav"),
        "-filter_complex",
        "[0]volume=0.55,afade=t=in:d=1.5,"
        f"afade=t=out:st={fade_start}:d=2.5[m];"
        "[1]aecho=0.8:0.6:60|130:0.25|0.15,volume=1.0[e];"
        "[m][e]amix=inputs=2:normalize=0,aecho=0.8:0.5:240:0.12,"
        "aformat=channel_layouts=stereo,loudnorm=I=-18:TP=-1.5",
        "-ar", str(RATE), str(WORK / "soundtrack.wav"),
    )


def main():
    cues = json.loads((RAW / "cues.json").read_text())
    end = next(c["time"] for c in cues if c["kind"] == "end")
    WORK.mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)

    print("soundtrack…")
    soundtrack(cues, end + 0.3)

    print("video…")
    # The recorder only gets frames when something moves, so a still end card needs its last frame held.
    ffmpeg(
        "-i", str(RAW / "demo.mov"), "-i", str(WORK / "soundtrack.wav"),
        "-filter_complex",
        f"[0:v]tpad=stop_mode=clone:stop_duration=5,trim=0:{end},fps=30,scale=1920:1080:flags=lanczos,"
        f"fade=t=in:d=0.6,fade=t=out:st={end - 0.8}:d=0.8,format=yuv420p[v]",
        "-map", "[v]", "-map", "1:a",
        "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-tune", "animation",
        "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart",
        str(OUT / "demo.mp4"),
    )

    print("gif…")
    gif_filter = f"trim={GIF_START}:{GIF_END},setpts=PTS-STARTPTS,fps=15,crop={PANEL_CROP},scale=840:-1:flags=lanczos"
    ffmpeg("-i", str(RAW / "demo.mov"), "-vf", f"{gif_filter},palettegen=stats_mode=diff:max_colors=160",
           str(WORK / "palette.png"))
    ffmpeg("-i", str(RAW / "demo.mov"), "-i", str(WORK / "palette.png"), "-filter_complex",
           f"[0:v]{gif_filter}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
           "-loop", "0", str(OUT / "demo.gif"))

    print("screenshots…")
    for cue in cues:
        if cue["kind"].startswith("shot:"):
            name = cue["kind"][len("shot:"):]
            ffmpeg("-ss", f"{cue['time']:.3f}", "-i", str(RAW / "demo.mov"), "-frames:v", "1",
                   "-vf", f"crop={PEEK_CROP if name in PEEK_SHOTS else PANEL_CROP}",
                   str(OUT / "screenshots" / f"{name}.png"))

    for path in sorted(OUT.rglob("*.*")):
        print(f"  {path.relative_to(ROOT)}  {path.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    sys.exit(main())
