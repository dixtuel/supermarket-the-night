#!/usr/bin/env python3
"""Generate original, dependency-free WAV music and UI/game feedback for Bakkal."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RATE = 22050


def write_wav(name: str, samples: list[tuple[float, float]], loop: bool = False) -> None:
    path = ROOT / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        pcm = bytearray()
        for left, right in samples:
            pcm.extend(struct.pack("<hh", int(max(-1, min(1, left)) * 32767), int(max(-1, min(1, right)) * 32767)))
        wav.writeframes(pcm)
    if loop:
        print(f"{path} ({len(samples) / RATE:.2f}s; set AudioStreamWAV loop range in Godot)")


def midi(number: int) -> float:
    return 440.0 * (2.0 ** ((number - 69) / 12.0))


def envelope(phase: float, attack: float, release: float, duration: float) -> float:
    return min(1.0, phase / max(0.001, attack)) * min(1.0, (duration - phase) / max(0.001, release))


def make_music() -> None:
    bpm = 82.0
    beat = 60.0 / bpm
    duration = beat * 4 * 8
    count = int(RATE * duration)
    chords = [
        (45, (57, 60, 64)),  # A minor
        (41, (53, 57, 60)),  # F major
        (36, (48, 52, 55)),  # C major
        (43, (55, 59, 62)),  # G major
    ]
    samples: list[tuple[float, float]] = []
    for index in range(count):
        t = index / RATE
        bar = int(t / (beat * 4)) % 8
        chord_index = bar // 2
        root, notes = chords[chord_index]
        local = t % (beat * 4)
        pad = sum(math.sin(2 * math.pi * midi(note) * t) for note in notes) / 3.0
        pad += 0.28 * math.sin(2 * math.pi * midi(root) * t)
        bass_phase = t % beat
        bass_env = math.exp(-bass_phase * 3.2) * min(1.0, bass_phase / 0.018)
        bass = math.sin(2 * math.pi * midi(root - 12) * t) * bass_env
        melody = 0.0
        # A sparse, soft two-note shop bell motif. Leave plenty of breathing room.
        beat_in_bar = int(local / beat)
        if beat_in_bar in (1, 3):
            note_index = (chord_index + (beat_in_bar // 2)) % 3
            phase = local - beat_in_bar * beat
            bell_env = envelope(phase, 0.008, 0.32, 0.36)
            frequency = midi(notes[note_index] + 12)
            melody = bell_env * (math.sin(2 * math.pi * frequency * phase) + 0.23 * math.sin(4 * math.pi * frequency * phase))
        fade = min(1.0, t / 0.025, (duration - t) / 0.025)
        value = fade * (0.075 * pad + 0.09 * bass + 0.035 * melody)
        pan = 0.035 * math.sin(2 * math.pi * t / 7.0)
        samples.append((value * (1.0 - pan), value * (1.0 + pan)))
    write_wav("night_shift_theme.wav", samples, loop=True)


def tone(frequencies: list[float], duration: float, *, waveform: str = "sine", volume: float = 0.25, decay: float = 8.0) -> list[tuple[float, float]]:
    count = int(RATE * duration)
    result: list[tuple[float, float]] = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for frequency in frequencies:
            phase = 2 * math.pi * frequency * t
            if waveform == "triangle":
                voice = (2.0 / math.pi) * math.asin(math.sin(phase))
            else:
                voice = math.sin(phase)
            value += voice / max(1, len(frequencies))
        amp = volume * math.exp(-decay * t) * min(1.0, t / 0.006)
        result.append((value * amp, value * amp))
    return result


def sequence(notes: list[tuple[list[float], float]], gap: float = 0.035, volume: float = 0.22) -> list[tuple[float, float]]:
    output: list[tuple[float, float]] = []
    for frequencies, length in notes:
        output.extend(tone(frequencies, length, volume=volume, decay=4.2))
        output.extend([(0.0, 0.0)] * int(RATE * gap))
    return output


def make_sfx() -> None:
    write_wav("ui_confirm.wav", tone([midi(79), midi(86)], 0.11, volume=0.16, decay=24.0))
    write_wav("xp_collect.wav", sequence([([midi(76)], 0.09), ([midi(83)], 0.12)], volume=0.17))
    write_wav("level_up.wav", sequence([([midi(69)], 0.12), ([midi(76)], 0.14), ([midi(81)], 0.22)], gap=0.025, volume=0.18))
    write_wav("player_hurt.wav", tone([midi(52), midi(59)], 0.10, waveform="triangle", volume=0.12, decay=20.0))
    write_wav("boss_arrival.wav", sequence([([midi(45)], 0.25), ([midi(45), midi(52)], 0.32), ([midi(57), midi(64)], 0.5)], gap=0.08, volume=0.2))
    write_wav("shift_survived.wav", sequence([([midi(60), midi(64)], 0.22), ([midi(64), midi(67)], 0.22), ([midi(67), midi(72)], 0.5)], volume=0.19))
    write_wav("shift_lost.wav", sequence([([midi(57)], 0.3), ([midi(53)], 0.34), ([midi(48)], 0.55)], volume=0.17))


if __name__ == "__main__":
    make_music()
    make_sfx()
