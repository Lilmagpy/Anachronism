"""Synthesise the game's sounds and music into client/sounds/ (standard library only).

    uv run python scripts/make_sounds.py

Everything is made from scratch here: plucked strings (Karplus-Strong), a gong, drums, a
chime and wooden clicks, and a gentle pentatonic theme over a drone. Being generated, the
files are our own and free of licences. Re-run to regenerate; the output is deterministic.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

from anachronism.engine.rng import GameRng

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "client" / "sounds"


def noise(rng: GameRng) -> float:
    """White noise in -1..1 from the game's seeded generator (deterministic output)."""
    return rng.below(20001) / 10000.0 - 1.0


def write(name: str, samples: list[float], volume: float = 0.9) -> None:
    """Save samples as a 16-bit mono WAV, normalised to ``volume``."""
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = volume / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples
    )
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def pluck(freq: float, seconds: float, rng: GameRng, brightness: float = 0.5) -> list[float]:
    """A plucked string (Karplus-Strong): a burst of noise through a decaying delay line."""
    period = max(2, int(RATE / freq))
    line = [noise(rng) for _ in range(period)]
    out = []
    decay = 0.996
    for i in range(int(seconds * RATE)):
        j = i % period
        nxt = line[(j + 1) % period]
        line[j] = (
            decay * ((1 - brightness) * line[j] + brightness * nxt) if i >= period else line[j]
        )
        line[j] = decay * 0.5 * (line[j] + nxt)
        out.append(line[j])
    return out


def mix(into: list[float], sound: list[float], at: int, gain: float = 1.0) -> None:
    """Add ``sound`` into ``into`` starting at sample ``at``."""
    for i, s in enumerate(sound):
        if at + i < len(into):
            into[at + i] += s * gain


def gong(seconds: float = 3.5) -> list[float]:
    """A bronze gong: inharmonic partials with slow decay."""
    partials = [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2), (1.5, 0.3)]
    base = 110.0
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        swell = min(1.0, t * 40)
        value = sum(
            a
            * math.sin(2 * math.pi * base * f * t + 0.3 * math.sin(2 * math.pi * 2 * t))
            * math.exp(-t * (0.8 + f * 0.25))
            for f, a in partials
        )
        out.append(value * swell)
    return out


def drum(seconds: float = 0.6, pitch: float = 70.0) -> list[float]:
    """A war drum: a falling-pitch thump with a noisy attack."""
    rng = GameRng.from_seed(3)
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        f = pitch * (1 + 1.5 * math.exp(-t * 30))
        out.append(
            math.sin(2 * math.pi * f * t) * math.exp(-t * 7) + noise(rng) * 0.3 * math.exp(-t * 40)
        )
    return out


def chime(notes: list[float], gap: float = 0.09, seconds: float = 1.2) -> list[float]:
    """Bell-like notes struck one after another."""
    out = [0.0] * int((seconds + gap * len(notes)) * RATE)
    for k, f in enumerate(notes):
        tone = [
            math.sin(2 * math.pi * f * i / RATE) * math.exp(-i / RATE * 4)
            + 0.3 * math.sin(4 * math.pi * f * i / RATE) * math.exp(-i / RATE * 7)
            for i in range(int(seconds * RATE))
        ]
        mix(out, tone, int(k * gap * RATE))
    return out


def click() -> list[float]:
    """A short wooden click for buttons."""
    rng = GameRng.from_seed(5)
    return [
        (math.sin(2 * math.pi * 900 * i / RATE) * 0.6 + noise(rng) * 0.4) * math.exp(-i / RATE * 90)
        for i in range(int(0.06 * RATE))
    ]


def clang(freq: float, seconds: float = 0.5) -> list[float]:
    """Iron on iron: a few inharmonic partials that ring briefly."""
    partials = [(1.0, 1.0), (2.41, 0.7), (3.93, 0.5), (5.67, 0.3)]
    return [
        sum(a * math.sin(2 * math.pi * freq * f * i / RATE) for f, a in partials)
        * math.exp(-i / RATE * 14)
        for i in range(int(seconds * RATE))
    ]


def roar(seconds: float, rng: GameRng) -> list[float]:
    """Many voices shouting at once: low-passed noise swelling and dying away."""
    out = []
    low = 0.0
    for i in range(int(seconds * RATE)):
        t = i / seconds / RATE
        low += 0.08 * (noise(rng) - low)
        out.append(low * math.sin(math.pi * t) ** 0.7)
    return out


def horn(notes: list[tuple[float, float]], vibrato: float = 5.0) -> list[float]:
    """A war horn: brassy harmonics with a soft attack, each (frequency, seconds) in turn."""
    out: list[float] = []
    for freq, seconds in notes:
        n = int(seconds * RATE)
        for i in range(n):
            t = i / RATE
            wobble = 1 + 0.006 * math.sin(2 * math.pi * vibrato * t)
            env = min(1.0, t * 18) * min(1.0, (n - i) / (0.08 * RATE))
            out.append(
                env
                * sum(math.sin(2 * math.pi * freq * k * wobble * t) / k**1.3 for k in range(1, 7))
            )
    return out


def theme(seconds: float = 64.0) -> list[float]:
    """A calm loop: a pentatonic melody on plucked strings over a soft drone."""
    rng = GameRng.from_seed(11)
    out = [0.0] * int(seconds * RATE)
    root = 146.83  # D3
    scale = [0, 2, 4, 7, 9, 12, 14, 16, 19]
    beat = 0.75
    phrase = [4, 3, 2, 3, 5, 4, 2, 1, 0, 2, 3, 1, 2, -1, 0, -1]
    t = 0.0
    step = 0
    while t < seconds - 3:
        degree = phrase[step % len(phrase)]
        if step % 32 >= 16:
            degree = min(8, degree + 2) if degree >= 0 else degree
        if degree >= 0:
            freq = root * 2 ** (scale[degree] / 12) * 2
            mix(out, pluck(freq, 2.4, rng, 0.4), int(t * RATE), 0.55)
            if step % 4 == 0:
                mix(
                    out,
                    pluck(root * 2 ** (scale[degree % 5] / 12), 3.0, rng, 0.3),
                    int(t * RATE),
                    0.35,
                )
        t += beat * (2 if step % 8 == 7 else 1)
        step += 1
    for i in range(len(out)):  # drone on D and A, breathing slowly
        tt = i / RATE
        breath = 0.5 + 0.5 * math.sin(2 * math.pi * tt / 16)
        out[i] += (
            0.06
            * breath
            * (
                math.sin(2 * math.pi * root / 2 * tt)
                + 0.6 * math.sin(2 * math.pi * root * 0.75 * tt)
            )
        )
    fade = int(2.5 * RATE)  # loop seam: fade the ends
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def main() -> None:
    """Write every sound file."""
    OUT.mkdir(parents=True, exist_ok=True)
    write("click", click(), 0.5)
    write("end_turn", gong(), 0.8)
    write("speak", chime([880.0, 1318.5]), 0.45)
    write("idea", chime([659.3, 880.0, 1174.7]), 0.5)
    war = [0.0] * int(2.2 * RATE)
    for k, at in enumerate([0.0, 0.35, 0.7, 1.2, 1.4]):
        mix(war, drum(0.8, 60.0 if k % 2 == 0 else 75.0), int(at * RATE))
    write("war", war, 0.85)
    march = [0.0] * int(2.6 * RATE)
    for k in range(6):  # left, right, left, right... the drums of an army on the road
        mix(march, drum(0.5, 82.0 if k % 2 == 0 else 96.0), int(k * 0.42 * RATE), 0.7)
    write("march", march, 0.6)
    rng = GameRng.from_seed(17)
    clash = roar(1.8, rng)
    for k, (at, f) in enumerate(
        [(0.15, 820.0), (0.32, 1040.0), (0.5, 760.0), (0.66, 930.0), (0.9, 1110.0), (1.1, 870.0)]
    ):
        mix(clash, clang(f), int(at * RATE), 0.35 if k % 2 else 0.45)
    mix(clash, drum(0.8, 55.0), 0, 0.9)
    write("clash", clash, 0.85)
    write("horn", horn([(196.0, 0.35), (261.6, 0.35), (329.6, 0.9)]), 0.7)
    write("defeat", horn([(220.0, 0.5), (196.0, 0.5), (164.8, 1.2)], 3.0), 0.6)
    write("victory", chime([587.3, 740.0, 880.0, 1174.7, 1480.0], 0.16, 2.0), 0.7)
    write("theme", theme(), 0.5)
    print("sounds written to", OUT)


if __name__ == "__main__":
    main()
