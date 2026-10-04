#!/usr/bin/env python3
"""Синтез звуков Arc Lightning (без сторонних библиотек: wave + math + random, кодирование в .ogg — через ffmpeg).

Запуск из корня репозитория:  python3 tools/make_audio.py
Результат: assets/audio/arc_lightning_charge.ogg и assets/audio/arc_lightning_zap.ogg
"""
import math
import random
import struct
import subprocess
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def add(dst, src, offset=0):
    for i, v in enumerate(src):
        j = offset + i
        if j < len(dst):
            dst[j] += v


def noise_burst(length, tau, amp, highpass=True):
    """Всплеск белого шума с экспоненциальным затуханием; highpass делает «треск» резче."""
    out, prev = [], 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        n = random.uniform(-1, 1)
        v = (n - prev) * 0.5 if highpass else n
        prev = n
        out.append(v * amp * math.exp(-t / tau))
    return out


def sweep(length, f0, f1, amp, tau, harmonics=(1.0, 0.35, 0.15)):
    """Экспоненциальный частотный свип (электрический «зинг») с гармониками."""
    out, phase = [], 0.0
    k = math.log(f1 / f0) / length
    for i in range(int(RATE * length)):
        t = i / RATE
        f = f0 * math.exp(k * t)
        phase += 2 * math.pi * f / RATE
        v = sum(h * math.sin(phase * (n + 1)) for n, h in enumerate(harmonics))
        out.append(v * amp * math.exp(-t / tau))
    return out


def crackle(length, rate0, rate1, amp):
    """Редкие микро-щелчки (потрескивание разряда); частота щелчков меняется от rate0 к rate1."""
    out = silence(length)
    t = 0.0
    while t < length:
        rate = rate0 + (rate1 - rate0) * (t / length)
        t += random.expovariate(rate)
        if t >= length:
            break
        click = noise_burst(0.012, 0.003, amp * random.uniform(0.3, 1.0))
        add(out, click, int(t * RATE))
    return out


def fade_out(samples, seconds):
    n = int(RATE * seconds)
    for i in range(n):
        idx = len(samples) - n + i
        if idx >= 0:
            samples[idx] *= 1 - i / n
    return samples


def fade_in(samples, seconds):
    n = int(RATE * seconds)
    for i in range(min(n, len(samples))):
        samples[i] *= i / n
    return samples


def normalize(samples, peak):
    m = max(abs(v) for v in samples) or 1.0
    return [v * peak / m for v in samples]


def zap():
    random.seed(7)
    length = 0.7
    out = silence(length)
    add(out, noise_burst(0.25, 0.04, 1.0))  # резкий треск удара
    add(out, sweep(0.45, 3400, 160, 0.55, 0.14))  # падающий «зинг»
    add(out, sweep(0.30, 70, 38, 0.8, 0.10, harmonics=(1.0, 0.2)))  # низкий удар
    add(out, crackle(length, 140, 12, 0.6))  # потрескивание хвоста
    return fade_out(normalize(out, 0.9), 0.04)


def charge():
    random.seed(11)
    length = 0.45
    out = silence(length)
    n = int(RATE * length)
    # нарастающий свип с вибрато и AM-гулом
    phase = 0.0
    k = math.log(1500 / 180) / length
    hum = []
    for i in range(n):
        t = i / RATE
        f = 180 * math.exp(k * t) * (1 + 0.02 * math.sin(2 * math.pi * 28 * t))
        phase += 2 * math.pi * f / RATE
        env = (t / length) ** 1.6
        am = 0.65 + 0.35 * math.sin(2 * math.pi * 55 * t)
        hum.append((math.sin(phase) + 0.4 * math.sin(2 * phase)) * env * am)
    add(out, hum)
    add(out, [v * (i / n) ** 2 * 0.25 for i, v in enumerate(noise_burst(length, 10, 1.0))])  # шипение нарастает
    add(out, crackle(length, 10, 170, 0.45))
    return fade_in(fade_out(normalize(out, 0.8), 0.03), 0.01)


def write_wav(path, samples):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, samples in (("arc_lightning_zap", zap()), ("arc_lightning_charge", charge())):
        wav = OUT / (name + ".wav")
        ogg = OUT / (name + ".ogg")
        write_wav(wav, samples)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)],
            check=True,
        )
        wav.unlink()
        print(f"{ogg.name}: {len(samples) / RATE:.2f} s, {ogg.stat().st_size} bytes")


if __name__ == "__main__":
    main()
