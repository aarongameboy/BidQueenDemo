#!/usr/bin/env python3
"""Generate listenable medieval-fantasy BGM loops for meta-game screens.

Replaces the old pure-sine placeholder synthesis with arpeggiated plucked strings,
bell chimes, soft pads, and rhythmic pulses aligned to docs/audio/game_music_design.md.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 44100
DURATION_SEC = 32.0
SAMPLE_COUNT = int(SAMPLE_RATE * DURATION_SEC)
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "music"

# Equal-tempered note table (octave 3–5)
NOTE: dict[str, float] = {}
for octave in range(2, 7):
    for name, semitone in [
        ("C", 0),
        ("Cs", 1),
        ("D", 2),
        ("Ds", 3),
        ("E", 4),
        ("F", 5),
        ("Fs", 6),
        ("G", 7),
        ("Gs", 8),
        ("A", 9),
        ("As", 10),
        ("B", 11),
    ]:
        NOTE[f"{name}{octave}"] = 440.0 * (2.0 ** ((octave - 4) + (semitone - 9) / 12.0))


@dataclass(frozen=True)
class NoteEvent:
    start: float
    duration: float
    freq: float
    velocity: float = 0.7
    timbre: str = "harp"


def _silence() -> list[float]:
    return [0.0] * SAMPLE_COUNT


def _mix(*channels: list[float], gains: list[float] | None = None) -> list[float]:
    if gains is None:
        gains = [1.0] * len(channels)
    out = [0.0] * SAMPLE_COUNT
    for ch, gain in zip(channels, gains):
        for i, v in enumerate(ch):
            out[i] += v * gain
    peak = max(abs(v) for v in out) or 1.0
    scale = 0.92 / peak
    return [v * scale for v in out]


def _lowpass(samples: list[float], alpha: float = 0.12) -> list[float]:
    if not samples:
        return samples
    out = [samples[0]]
    for i in range(1, len(samples)):
        out.append(out[-1] + alpha * (samples[i] - out[-1]))
    return out


def _fade_edges(samples: list[float], attack: float = 0.35, release: float = 0.35) -> list[float]:
    attack_n = int(attack * SAMPLE_RATE)
    release_n = int(release * SAMPLE_RATE)
    out = samples[:]
    for i in range(min(attack_n, len(out))):
        out[i] *= min(1.0, 0.82 + 0.18 * (i / max(1, attack_n)))
    for i in range(min(release_n, len(out))):
        idx = len(out) - 1 - i
        out[idx] *= min(1.0, 0.82 + 0.18 * (i / max(1, release_n)))
    return out


def _loop_smooth(samples: list[float], window: float = 0.08) -> list[float]:
    """Match the end to the beginning enough to avoid a click at loop wrap."""
    n = min(int(window * SAMPLE_RATE), len(samples) // 2)
    out = samples[:]
    for i in range(n):
        blend = i / max(1, n - 1)
        head = samples[i]
        tail = samples[-n + i]
        out[i] = head * blend + tail * (1.0 - blend)
        out[-n + i] = tail * (1.0 - blend) + head * blend
    return out


def _pluck(freq: float, duration: float, start: float, velocity: float, brightness: float = 0.55) -> list[float]:
    """Karplus-Strong plucked string."""
    out = _silence()
    delay = max(2, int(SAMPLE_RATE / freq))
    buf = [random.uniform(-1.0, 1.0) for _ in range(delay)]
    start_i = int(start * SAMPLE_RATE)
    end_i = min(SAMPLE_COUNT, start_i + int(duration * SAMPLE_RATE))
    decay = 0.9965 - min(0.003, freq / 50000.0)
    idx = 0
    for i in range(start_i, end_i):
        sample = buf[idx]
        nxt = idx + 1 if idx + 1 < delay else 0
        buf[idx] = decay * (brightness * sample + (1.0 - brightness) * 0.5 * (buf[idx] + buf[nxt]))
        out[i] += sample * velocity
        idx = nxt
    return out


def _bell(freq: float, start: float, velocity: float, decay: float = 2.8) -> list[float]:
    out = _silence()
    start_i = int(start * SAMPLE_RATE)
    partials = [(1.0, 1.0), (2.02, 0.45), (3.01, 0.22), (4.05, 0.1)]
    for i in range(start_i, SAMPLE_COUNT):
        t = (i - start_i) / SAMPLE_RATE
        env = math.exp(-t * decay) * (1.0 - math.exp(-t * 40.0))
        sample = 0.0
        for ratio, amp in partials:
            sample += amp * math.sin(2.0 * math.pi * freq * ratio * t)
        out[i] += sample * velocity * env
    return out


def _pad(freqs: list[float], amps: list[float], lfo_hz: float = 0.07) -> list[float]:
    out = _silence()
    for i in range(SAMPLE_COUNT):
        t = i / SAMPLE_RATE
        mod = 0.72 + 0.28 * math.sin(2.0 * math.pi * lfo_hz * t)
        sample = 0.0
        for freq, amp in zip(freqs, amps):
            sample += amp * math.sin(2.0 * math.pi * freq * t)
            sample += amp * 0.18 * math.sin(2.0 * math.pi * freq * 2.0 * t + 0.3)
        out[i] = sample * mod
    return _lowpass(out, 0.08)


def _pulse_bass(root: float, bpm: float, depth: float, velocity: float = 0.35) -> list[float]:
    out = _silence()
    beat = 60.0 / bpm
    for i in range(SAMPLE_COUNT):
        t = i / SAMPLE_RATE
        phase = (t % beat) / beat
        env = 1.0 if phase < 0.12 else 0.55 + 0.45 * math.sin(2.0 * math.pi * t / beat)
        body = math.sin(2.0 * math.pi * root * t) + 0.35 * math.sin(2.0 * math.pi * root * 0.5 * t)
        out[i] = body * (1.0 - depth + depth * env) * velocity
    return _lowpass(out, 0.15)


def _render_events(events: list[NoteEvent]) -> list[float]:
    out = _silence()
    for ev in events:
        layer = _pluck(ev.freq, ev.duration, ev.start, ev.velocity)
        for i, v in enumerate(layer):
            out[i] += v
    return out


def _chord_notes(names: list[str]) -> list[float]:
    return [NOTE[n] for n in names]


def _arpeggio(
    chords: list[list[str]],
    bars_per_chord: int,
    bpm: float,
    pattern: list[int],
    velocity: float = 0.55,
    note_len: float = 0.42,
) -> list[NoteEvent]:
    beat = 60.0 / bpm
    bar_len = 4 * beat
    events: list[NoteEvent] = []
    cursor = 0.0
    for chord in chords:
        freqs = _chord_notes(chord)
        for bar in range(bars_per_chord):
            for step, idx in enumerate(pattern):
                start = cursor + step * beat
                if start >= DURATION_SEC:
                    break
                events.append(
                    NoteEvent(start=start, duration=note_len, freq=freqs[idx % len(freqs)], velocity=velocity)
                )
            cursor += bar_len
            if cursor >= DURATION_SEC:
                break
        if cursor >= DURATION_SEC:
            break
    return events


def _schedule_bells(schedule: list[tuple[float, str, float]]) -> list[float]:
    out = _silence()
    for start, note, vel in schedule:
        layer = _bell(NOTE[note], start, vel)
        for i, v in enumerate(layer):
            out[i] += v
    return out


def build_meta_shop() -> list[float]:
    chords = [["C4", "E4", "G4", "C5"], ["F4", "A4", "C5"], ["G4", "B4", "D5"], ["C4", "G4", "E4"]]
    arp = _render_events(_arpeggio(chords, 2, 90, [0, 1, 2, 1, 2, 3, 2, 1], velocity=0.5))
    bells = _schedule_bells([(0.0, "G5", 0.18), (8.0, "E5", 0.14), (16.0, "C5", 0.16), (24.0, "G5", 0.15)])
    pad = _pad(_chord_notes(["C3", "G3", "E4"]), [0.08, 0.06, 0.05], 0.05)
    return _fade_edges(_mix(arp, bells, pad, gains=[1.0, 0.85, 0.55]))


def build_meta_warehouse() -> list[float]:
    chords = [["A2", "E3", "A3"], ["F3", "C4", "F4"], ["D3", "A3", "D4"], ["E3", "B3", "E4"]]
    arp = _render_events(_arpeggio(chords, 2, 72, [0, 1, 0, 2], velocity=0.42, note_len=0.55))
    pad = _pad(_chord_notes(["A2", "E3", "A3"]), [0.14, 0.1, 0.08], 0.04)
    ticks = _render_events(
        [
            NoteEvent(start=t, duration=0.08, freq=NOTE["E2"], velocity=0.22, timbre="harp")
            for t in [i * 2.0 for i in range(16)]
        ]
    )
    return _fade_edges(_mix(arp, pad, ticks, gains=[1.0, 0.7, 0.35]))


def build_meta_collection() -> list[float]:
    chords = [["D4", "Fs4", "A4", "D5"], ["G4", "B4", "D5"], ["A4", "Cs5", "E5"], ["D4", "A4", "Fs4"]]
    arp = _render_events(_arpeggio(chords, 2, 84, [0, 2, 1, 2, 3, 2, 1, 0], velocity=0.48))
    bells = _schedule_bells([(0.0, "A5", 0.2), (4.0, "D5", 0.12), (12.0, "Fs5", 0.14), (20.0, "A5", 0.16)])
    pad = _pad(_chord_notes(["D3", "A3", "D4"]), [0.07, 0.08, 0.06], 0.06)
    return _fade_edges(_mix(arp, bells, pad, gains=[1.0, 0.9, 0.5]))


def build_meta_characters() -> list[float]:
    chords = [["G3", "B3", "D4", "G4"], ["C4", "E4", "G4"], ["D4", "Fs4", "A4"], ["G3", "D4", "B3"]]
    arp = _render_events(_arpeggio(chords, 2, 78, [0, 1, 2, 1, 3, 2, 1, 0], velocity=0.46))
    melody = _render_events(
        [
            NoteEvent(0.0, 0.9, NOTE["D5"], 0.38),
            NoteEvent(2.0, 0.9, NOTE["E5"], 0.36),
            NoteEvent(4.0, 1.2, NOTE["G5"], 0.4),
            NoteEvent(8.0, 0.9, NOTE["B4"], 0.34),
            NoteEvent(10.0, 0.9, NOTE["D5"], 0.36),
            NoteEvent(12.0, 1.4, NOTE["G5"], 0.38),
            NoteEvent(16.0, 0.9, NOTE["A5"], 0.36),
            NoteEvent(18.0, 0.9, NOTE["G5"], 0.34),
            NoteEvent(20.0, 1.6, NOTE["D5"], 0.4),
            NoteEvent(24.0, 0.9, NOTE["E5"], 0.34),
            NoteEvent(26.0, 0.9, NOTE["G5"], 0.36),
            NoteEvent(28.0, 2.0, NOTE["B4"], 0.38),
        ]
    )
    pad = _pad(_chord_notes(["G2", "D3", "G3"]), [0.09, 0.07, 0.06], 0.05)
    return _fade_edges(_mix(arp, melody, pad, gains=[0.85, 1.0, 0.45]))


def build_meta_leaderboard() -> list[float]:
    pulse = _pulse_bass(NOTE["E3"], 92.0, 0.5, velocity=0.42)
    chords = [["E3", "G3", "B3"], ["A3", "C4", "E4"], ["B3", "D4", "Fs4"], ["E3", "B3", "G3"]]
    plucks = _render_events(_arpeggio(chords, 2, 92, [0, 2, 1, 2], velocity=0.44, note_len=0.28))
    accents = _render_events(
        [NoteEvent(t, 0.15, NOTE["B4"], 0.32) for t in [i * (60.0 / 92.0) * 2 for i in range(24)]]
    )
    return _fade_edges(_mix(pulse, plucks, accents, gains=[0.9, 1.0, 0.55]))


def build_meta_encyclopedia() -> list[float]:
    bells = _schedule_bells(
        [
            (0.0, "E6", 0.12),
            (2.5, "G5", 0.1),
            (5.0, "B5", 0.11),
            (8.0, "E6", 0.1),
            (11.0, "D6", 0.09),
            (14.0, "G5", 0.1),
            (17.0, "A5", 0.11),
            (20.0, "E6", 0.1),
            (23.0, "B5", 0.09),
            (26.0, "G5", 0.1),
            (29.0, "E6", 0.11),
        ]
    )
    pad = _pad(_chord_notes(["E4", "B4", "G4"]), [0.05, 0.04, 0.035], 0.03)
    scratch = _render_events(
        [NoteEvent(t, 0.06, NOTE["A6"], 0.04) for t in [i * 1.6 + 0.4 for i in range(18)]]
    )
    return _fade_edges(_mix(bells, pad, scratch, gains=[1.0, 0.65, 0.4]))


def build_meta_map_select() -> list[float]:
    chords = [["A3", "E4", "A4"], ["D4", "Fs4", "A4"], ["E4", "G4", "B4"], ["A3", "E4", "C5"]]
    arp = _render_events(_arpeggio(chords, 2, 66, [0, 1, 2, 1], velocity=0.46, note_len=0.62))
    bells = _schedule_bells([(0.0, "E5", 0.14), (16.0, "A5", 0.12)])
    pad = _pad(_chord_notes(["A2", "E3", "A3"]), [0.1, 0.08, 0.07], 0.04)
    return _fade_edges(_mix(arp, bells, pad, gains=[1.0, 0.75, 0.55]))


def build_meta_matchmaking() -> list[float]:
    pulse = _pulse_bass(NOTE["A3"], 108.0, 0.62, velocity=0.48)
    chords = [["A3", "C4", "E4"], ["D4", "F4", "A4"], ["E4", "G4", "B4"], ["A3", "E4", "C5"]]
    plucks = _render_events(_arpeggio(chords, 1, 108, [0, 1, 2], velocity=0.4, note_len=0.22))
    bells = _schedule_bells([(i * 2.0, "E5", 0.1 + 0.02 * (i % 4)) for i in range(16)])
    return _fade_edges(_mix(pulse, plucks, bells, gains=[1.0, 0.85, 0.6]))


def build_meta_room() -> list[float]:
    chords = [["F3", "A3", "C4"], ["G3", "B3", "D4"], ["A3", "C4", "E4"], ["F3", "C4", "A3"]]
    arp = _render_events(_arpeggio(chords, 2, 60, [0, 2, 1, 2], velocity=0.38, note_len=0.7))
    counter = _render_events(
        [
            NoteEvent(1.0, 1.0, NOTE["C5"], 0.28),
            NoteEvent(5.0, 1.0, NOTE["A4"], 0.26),
            NoteEvent(9.0, 1.0, NOTE["G4"], 0.27),
            NoteEvent(13.0, 1.0, NOTE["E4"], 0.26),
            NoteEvent(17.0, 1.0, NOTE["F4"], 0.28),
            NoteEvent(21.0, 1.0, NOTE["G4"], 0.26),
            NoteEvent(25.0, 1.0, NOTE["A4"], 0.27),
            NoteEvent(29.0, 1.0, NOTE["C5"], 0.26),
        ]
    )
    pad = _pad(_chord_notes(["F2", "C3", "F3"]), [0.08, 0.06, 0.05], 0.035)
    return _fade_edges(_mix(arp, counter, pad, gains=[0.9, 0.75, 0.5]))


def build_meta_settlement() -> list[float]:
    chords = [["F3", "A3", "C4", "F4"], ["As3", "D4", "F4"], ["C4", "E4", "G4"], ["F3", "C4", "A3"]]
    arp = _render_events(_arpeggio(chords, 2, 72, [3, 2, 1, 0, 1, 2], velocity=0.5, note_len=0.5))
    bells = _schedule_bells(
        [(0.0, "C6", 0.22), (4.0, "A5", 0.16), (8.0, "F5", 0.18), (16.0, "C6", 0.2), (24.0, "A5", 0.17)]
    )
    coins = _render_events(
        [NoteEvent(t, 0.07, NOTE["C5"], 0.25) for t in [i * 0.5 for i in range(64) if i % 4 == 0]]
    )
    pad = _pad(_chord_notes(["F2", "A2", "C3"]), [0.09, 0.08, 0.07], 0.05)
    return _fade_edges(_mix(arp, bells, coins, pad, gains=[1.0, 0.95, 0.45, 0.5]))


BUILDERS: dict[str, callable] = {
    "meta_shop": build_meta_shop,
    "meta_warehouse": build_meta_warehouse,
    "meta_collection": build_meta_collection,
    "meta_characters": build_meta_characters,
    "meta_leaderboard": build_meta_leaderboard,
    "meta_encyclopedia": build_meta_encyclopedia,
    "meta_map_select": build_meta_map_select,
    "meta_matchmaking": build_meta_matchmaking,
    "meta_room": build_meta_room,
    "meta_settlement": build_meta_settlement,
}


def write_wav(name: str, mono: list[float]) -> Path:
    path = OUTPUT_DIR / f"{name}.wav"
    mono = _loop_smooth(mono)
    peak = max(abs(v) for v in mono) or 1.0
    mono = [v * (0.86 / peak) for v in mono]
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for i, sample in enumerate(mono):
            pan_lfo = 0.08 * math.sin(2.0 * math.pi * i / SAMPLE_RATE / 11.0)
            left = sample * (0.96 - pan_lfo)
            right = sample * (0.96 + pan_lfo)
            frames.extend(struct.pack("<h", int(max(-1.0, min(1.0, left)) * 32767)))
            frames.extend(struct.pack("<h", int(max(-1.0, min(1.0, right)) * 32767)))
        wf.writeframes(frames)
    return path


def main() -> None:
    random.seed(42)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, builder in BUILDERS.items():
        out = write_wav(name, builder())
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
