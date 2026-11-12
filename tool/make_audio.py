"""Synthesizes Sky Dodger's music and sound effects (no external samples).

Everything is rendered "circularly" for the music: notes, echoes and reverb
tails that run past the end wrap around to the start, so the loop is seamless.
"""
import os
import subprocess
import sys

import numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a, d, s, r, sr=SR):
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False) ** 2,
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n) ** 1.5,
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def lowpass(x, fc, order=2, zero_phase=False):
    sos = butter(order, fc / (SR / 2), btype="low", output="sos")
    return sosfiltfilt(sos, x) if zero_phase else sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = butter(order, fc / (SR / 2), btype="high", output="sos")
    return sosfilt(sos, x)


def circ_add(buf, sig, start):
    """Add sig into buf starting at start, wrapping around the end."""
    L = buf.shape[-1]
    idx = (np.arange(sig.shape[-1]) + start) % L
    np.add.at(buf, (slice(None), idx) if buf.ndim == 2 else idx, sig)


def circ_reverb(x, seconds=4.5, wet=0.45, seed=1):
    """Stereo circular convolution reverb with a decaying-noise impulse."""
    r = np.random.default_rng(seed)
    L = x.shape[-1]
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = r.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = lowpass(ir, 5000)
        ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
        ir /= np.sqrt(np.sum(ir**2))
        irp = np.zeros(L)
        irp[:n] = ir
        out[ch] = np.real(np.fft.ifft(np.fft.fft(x[ch]) * np.fft.fft(irp)))
    return x * (1 - wet) + out * wet * 1.6


def to_mp3(stereo, name, bitrate="112k", peak=0.89):
    stereo = stereo / (np.max(np.abs(stereo)) + 1e-9) * peak
    wav = os.path.join(OUT, name + ".wav")
    pcm = (stereo.T * 32767).astype("<i2")
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    mp3 = os.path.join(OUT, name + ".mp3")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame",
         "-b:a", bitrate, mp3],
        check=True,
    )
    return mp3


# --------------------------------------------------------------------- voices

def pad_voice(freq, dur, bright=1800.0):
    """Soft, slowly breathing pad: detuned triangles + sine, low-passed."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for det in (-0.07, 0.0, 0.065):
        f = freq * 2 ** (det / 12)
        ph = rng.uniform(0, 1)
        tri = 2 * np.abs(2 * ((f * t + ph) % 1) - 1) - 1
        sig += tri * 0.33
    sig += 0.5 * np.sin(2 * np.pi * freq * t)
    sig = lowpass(sig, bright)
    breath = 0.82 + 0.18 * np.sin(2 * np.pi * t / dur * 2 + rng.uniform(0, 6))
    return sig * breath * env_adsr(n, dur * 0.35, 0.5, 0.85, dur * 0.4)


def bell(freq, dur=3.5, amp=1.0):
    """Gentle FM bell / glass tone."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod_env = np.exp(-t * 3.0)
    mod = 1.6 * mod_env * np.sin(2 * np.pi * freq * 3.5 * t)
    car = np.sin(2 * np.pi * freq * t + mod)
    car += 0.25 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t * 2.5)
    e = np.exp(-t * 1.6) * np.minimum(1, t / 0.004)
    fade = min(n, int(0.08 * SR))
    e[-fade:] *= np.linspace(1, 0, fade)  # no clicks when a bell is cut short
    return car * e * amp


def sub(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(2 * np.pi * freq * 2 * t)
    return s * env_adsr(n, 0.8, 0.4, 0.9, 1.2)


def pan(sig, p):
    """p in [-1, 1] -> stereo array."""
    a = (p + 1) * np.pi / 4
    return np.vstack([sig * np.cos(a), sig * np.sin(a)])


# --------------------------------------------------------------------- music

def make_music():
    bpm_bar = 8.0  # seconds per chord
    # D major / Lydian colour.  (pad notes, bass root)
    progression = [
        ([62, 66, 69, 73, 76], 38),  # Dmaj9
        ([59, 62, 66, 69, 76], 35),  # Bm11-ish
        ([55, 59, 62, 66, 73], 31),  # Gmaj7#11 colour (C# on top)
        ([57, 61, 64, 69, 71], 33),  # Aadd9
        ([62, 66, 69, 74, 78], 38),  # Dmaj (higher voicing)
        ([54, 59, 62, 66, 71], 30),  # F#m/B blend
        ([55, 59, 62, 67, 74], 31),  # Gmaj
        ([57, 62, 64, 69, 73], 33),  # Asus2 -> back to D
    ]
    total = bpm_bar * len(progression)  # 64 s
    L = int(total * SR)
    pads = np.zeros((2, L))
    low = np.zeros((2, L))
    bells = np.zeros((2, L))

    for i, (notes, root) in enumerate(progression):
        start = int(i * bpm_bar * SR)
        dur = bpm_bar + 4.0  # overlap into next chord (wraps at the end)
        for k, nte in enumerate(notes):
            v = pad_voice(midi(nte), dur, bright=1500 + 250 * k) * 0.22
            circ_add(pads, pan(v, -0.6 + 1.2 * k / (len(notes) - 1)), start)
        circ_add(low, pan(sub(midi(root + 12), bpm_bar + 1.2) * 0.16, 0.0), start)

        # Sparse bell melody from the D major pentatonic over the chord.
        scale = [74, 76, 78, 81, 83, 86, 88]
        n_bells = rng.integers(2, 5)
        times = np.sort(rng.choice(np.arange(0, 8, 0.5), n_bells, replace=False))
        for tt in times:
            nte = rng.choice(scale)
            b = bell(midi(nte), 4.0, amp=rng.uniform(0.10, 0.17))
            p = rng.uniform(-0.7, 0.7)
            s0 = start + int(tt * SR)
            circ_add(bells, pan(b, p), s0)
            # dotted-eighth style soft echoes, ping-ponged
            for e_i, gain in enumerate((0.45, 0.25, 0.12)):
                circ_add(bells, pan(b * gain, -p if e_i % 2 == 0 else p),
                         s0 + int((e_i + 1) * 0.75 * SR))

    # Airy wind layer (filtered noise, slowly swelling), circular.
    t = np.arange(L) / SR
    wind = np.zeros((2, L))
    for ch in range(2):
        nz = rng.standard_normal(L + SR)
        nz = highpass(lowpass(nz, 2400, 2), 500, 2)[SR:]
        swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / total * 4 + ch * 1.3)
        wind[ch] = nz * swell * 0.035

    mix = pads + low + bells * 0.9 + wind
    mix = circ_reverb(mix, seconds=5.0, wet=0.5)
    # Gentle high cut so it never fights the sound effects.
    mix = np.vstack([lowpass(np.concatenate([mix[c][-SR:], mix[c]]), 7000)[SR:]
                     for c in range(2)])
    return to_mp3(mix, "music", bitrate="112k", peak=0.80)


# --------------------------------------------------------------------- sfx

def sfx_coin():
    a = bell(midi(88), 0.85, 0.9)
    b = bell(midi(95), 0.85, 0.8)
    n = int(1.0 * SR)
    s = np.zeros(n)
    s[: len(a)] += a
    off = int(0.07 * SR)
    s[off: off + len(b)] += b[: n - off]
    st = np.vstack([s, np.roll(s, 90)])
    return to_mp3(highpass(st, 300), "coin", peak=0.75)


def sfx_crash():
    dur = 1.6
    n = int(dur * SR)
    t = np.arange(n) / SR
    boom_f = 110 * np.exp(-t * 3) + 38
    boom = np.sin(2 * np.pi * np.cumsum(boom_f) / SR) * np.exp(-t * 3.2)
    nz = rng.standard_normal(n)
    sweep = np.zeros(n)
    # noise burst whose brightness falls over time (soft, not harsh)
    for i, fc in enumerate((1400, 650, 300)):
        seg = lowpass(nz, fc) * np.exp(-t * (4 + 3 * i))
        sweep += seg * (0.5 / (i + 1))
    s = boom * 1.0 + sweep * 0.45
    s *= np.minimum(1, t / 0.003)
    st = np.vstack([s, lowpass(np.roll(s, 200), 2500)])
    st = np.vstack([st[c] + 0.25 * np.roll(st[c], int(0.11 * SR)) for c in range(2)])
    return to_mp3(st, "crash", peak=0.85)


def sfx_click():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = 1200 * np.exp(-t * 18) + 600
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 40) * np.minimum(1, t / 0.002)
    return to_mp3(np.vstack([s, s]), "click", peak=0.6)


def sfx_start():
    dur = 1.4
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    # rising airy whoosh: band of noise moving upward
    whoosh = np.zeros(n)
    hop = 2048
    for i in range(0, n, hop):
        seg = nz[max(0, i - hop): i + hop]
        fc = 400 + 3500 * (i / n)
        whoosh[i: i + hop] = lowpass(seg, fc)[-min(hop, n - i):] if len(seg) else 0
    whoosh *= np.sin(np.pi * np.clip(t / 0.9, 0, 1)) * 0.35
    chord = sum(bell(midi(nn), dur, 0.25) for nn in (74, 78, 81, 86))
    chord = np.concatenate([np.zeros(int(0.35 * SR)), chord])[:n]
    s = whoosh + chord
    st = np.vstack([s, np.roll(s, 300)])
    st = circ_reverb(np.pad(st, ((0, 0), (0, SR))), seconds=1.2, wet=0.35)
    return to_mp3(st, "start", peak=0.7)


def sfx_newbest():
    notes = [74, 78, 81, 86, 90]
    dur = 2.4
    n = int(dur * SR)
    s = np.zeros(n)
    for i, nn in enumerate(notes):
        b = bell(midi(nn), dur - i * 0.11, 0.5)
        o = int(i * 0.11 * SR)
        s[o: o + len(b)] += b[: n - o]
    st = np.vstack([s, np.roll(s, 250)])
    st = circ_reverb(np.pad(st, ((0, 0), (0, SR))), seconds=1.8, wet=0.4)
    return to_mp3(st, "new_best", peak=0.75)


if __name__ == "__main__":
    for f in (make_music, sfx_coin, sfx_crash, sfx_click, sfx_start, sfx_newbest):
        print(f())
