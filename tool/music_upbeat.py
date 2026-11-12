"""Upbeat synthwave / arcade loop for Sky Dodger.

124 BPM, A minor (Am - F - C - G), 32 bars (~62 s), rendered circularly so
the loop is seamless. Section A (bars 0-15): drums, bass, arpeggio, pads.
Section B (bars 16-31): adds the lead hook. A riser leads into each section.
"""
import numpy as np

from make_audio import (SR, circ_add, circ_reverb, highpass, lowpass, midi,
                        pan, to_mp3)

rng = np.random.default_rng(42)

BPM = 124
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 32
L = int(round(BARS * BAR * SR))


def at(beat):
    return int(round(beat * BEAT * SR))


# ------------------------------------------------------------------ oscillators

def saw(freq, n, detune_cents=(0,), phase_rand=True):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for c in detune_cents:
        f = freq * 2 ** (c / 1200)
        ph = rng.uniform(0, 1) if phase_rand else 0
        out += 2 * ((f * t + ph) % 1) - 1
    return out / len(detune_cents)


def square(freq, n, duty=0.5):
    t = np.arange(n) / SR
    return np.where((freq * t) % 1 < duty, 1.0, -1.0)


def env(n, a=0.005, d=0.1, s=0.6, r=0.05):
    a_n, d_n, r_n = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([np.linspace(0, 1, a_n), np.linspace(1, s, d_n),
                        np.full(s_n, s), np.linspace(s, 0, r_n)])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


# ------------------------------------------------------------------ drums

def kick():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 35)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    click = rng.standard_normal(n) * np.exp(-t * 300) * 0.3
    return np.tanh((body + click) * 1.6)


def clap():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    e = np.zeros(n)
    for o in (0, 0.011, 0.022):
        oi = int(o * SR)
        e[oi:] += np.exp(-(t[: n - oi]) * (60 if o < 0.02 else 18))
    s = highpass(lowpass(nz, 6000), 900) * e
    return s * 0.8


def hat(open_=False):
    n = int((0.22 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    s = highpass(rng.standard_normal(n), 7000, 4)
    return s * np.exp(-t * (14 if open_ else 90))


# ------------------------------------------------------------------ harmony

# (pad chord, bass root) for each 2-bar block; A minor progression.
CHORDS = [
    ([57, 60, 64, 69], 33),  # Am
    ([53, 57, 60, 65], 29),  # F
    ([55, 60, 64, 67], 36),  # C
    ([55, 59, 62, 67], 31),  # G
]

# Lead hook: (beat offset in 8-beat phrase, midi note, length in beats)
HOOK = [
    [(0, 76, 1), (1, 81, .5), (1.5, 79, .5), (2, 76, 1), (3, 74, .5),
     (3.5, 76, 2.5), (6.5, 72, .5), (7, 74, 1)],
    [(0, 72, 1), (1, 77, .5), (1.5, 76, .5), (2, 72, 1), (3, 69, .5),
     (3.5, 72, 2.5), (6.5, 74, .5), (7, 76, 1)],
    [(0, 79, 1), (1, 76, .5), (1.5, 79, .5), (2, 84, 1.5), (3.5, 83, .5),
     (4, 79, 2), (6, 76, 1), (7, 79, 1)],
    [(0, 74, 1), (1, 79, .5), (1.5, 83, .5), (2, 81, 1.5), (3.5, 79, .5),
     (4, 76, 3), (7, 74, .5), (7.5, 71, .5)],
]


def chord_at(bar):
    return CHORDS[(bar // 2) % 4]


def main():
    drums = np.zeros((2, L))
    bass = np.zeros((2, L))
    pads = np.zeros((2, L))
    arp = np.zeros((2, L))
    lead = np.zeros((2, L))
    fx = np.zeros((2, L))

    k, c, ch, oh = kick(), clap(), hat(), hat(True)
    kick_times = []

    for bar in range(BARS):
        b0 = bar * 4
        section_b = bar >= 16
        for beat in range(4):
            # four-on-the-floor kick
            circ_add(drums, pan(k * 0.62, 0), at(b0 + beat))
            kick_times.append(at(b0 + beat))
            # off-beat hats, open hat on the "and" of each beat in section B
            circ_add(drums, pan((oh if section_b else ch) * 0.32, 0.25),
                     at(b0 + beat + 0.5))
            # 16th ghost hats for drive
            circ_add(drums, pan(ch * 0.13, -0.3), at(b0 + beat + 0.25))
            circ_add(drums, pan(ch * 0.13, -0.3), at(b0 + beat + 0.75))
        # clap on 2 and 4
        for beat in (1, 3):
            circ_add(drums, pan(c * 0.6, 0.05), at(b0 + beat))
        # little drum fill at the end of every 4th bar
        if bar % 4 == 3:
            for s16 in (3.25, 3.5, 3.75):
                circ_add(drums, pan(c * 0.35, -0.1), at(b0 + s16))

        pad_notes, root = chord_at(bar)

        # Bass: driving 8ths, root with an octave jump on the last off-beat.
        for e8 in range(8):
            note = root + 12 if e8 in (3, 7) else root
            n = at(0.45)
            f = midi(note)
            s = saw(f, n, (0, 7)) * 0.9 + np.sin(2 * np.pi * f * np.arange(n) / SR) * 0.35
            s = lowpass(s, 900 + 500 * (e8 % 2)) * env(n, 0.003, 0.12, 0.5, 0.03)
            circ_add(bass, pan(s * 0.42, 0), at(b0 + e8 * 0.5))

        # Pads: one chord per 2 bars, wide detuned saws, filtered.
        if bar % 2 == 0:
            n = at(8)
            pad = sum(saw(midi(p), n, (-9, 0, 9)) for p in pad_notes)
            pad = lowpass(pad, 2600 if section_b else 1800) * env(n, 0.08, 0.5, 0.75, 0.4)
            circ_add(pads, np.vstack([pad, np.roll(pad, 400)]) * 0.095, at(b0))

        # Arpeggio: 16ths over chord tones (up-down), plucky square.
        tones = [p + 12 for p in pad_notes]
        pattern = tones + tones[-2:0:-1]
        for s16 in range(16):
            note = pattern[(bar * 16 + s16) % len(pattern)]
            n = at(0.3)
            s = square(midi(note), n, 0.3)
            s = lowpass(s, 3200) * env(n, 0.002, 0.08, 0.15, 0.04)
            p = -0.45 if s16 % 2 == 0 else 0.45
            start = at(b0 + s16 * 0.25)
            circ_add(arp, pan(s * 0.15, p), start)
            circ_add(arp, pan(s * 0.06, -p), start + at(0.75))  # echo

    # Lead hook (section B), bright detuned saw with vibrato + echo.
    for phrase in range(8):  # 8 phrases of 2 bars in bars 16-31
        bar0 = 16 + phrase * 2
        for off, note, length in HOOK[phrase % 4]:
            n = at(length)
            t = np.arange(n) / SR
            f = midi(note) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25))
            ph = np.cumsum(f) / SR
            s = sum(2 * ((ph * 2 ** (c / 1200) + rng.uniform()) % 1) - 1 for c in (-8, 0, 8)) / 3
            s += 0.4 * np.sin(2 * np.pi * ph * 2)  # octave sparkle
            s = lowpass(s, 4200) * env(n, 0.01, 0.15, 0.7, 0.08)
            start = at(bar0 * 4 + off)
            circ_add(lead, pan(s * 0.32, -0.1), start)
            circ_add(lead, pan(s * 0.12, 0.6), start + at(0.75))
            circ_add(lead, pan(s * 0.06, -0.6), start + at(1.5))

    # Risers into each section (bars 14-15 and 30-31) + crash on the downbeat.
    for bar0 in (14, 30):
        n = at(8)
        t = np.arange(n) / SR
        nz = rng.standard_normal(n)
        hop = 1024
        r = np.zeros(n)
        for i in range(0, n, hop):
            fc = 500 + 7000 * (i / n) ** 2
            seg = nz[max(0, i - hop): i + hop]
            r[i: i + hop] = lowpass(seg, fc)[-min(hop, n - i):]
        r *= (t / t[-1]) ** 2 * 0.22
        circ_add(fx, np.vstack([r, np.roll(r, 300)]), at(bar0 * 4))
        cn = int(1.8 * SR)
        crash = highpass(rng.standard_normal(cn), 4000) * np.exp(-np.arange(cn) / SR * 2.2)
        circ_add(fx, np.vstack([crash, np.roll(crash, 200)]) * 0.18, at((bar0 + 2) * 4 % (BARS * 4)))

    # Sidechain "pump": duck everything except drums after each kick.
    duck = np.ones(L)
    dn = int(0.25 * SR)
    shape = 1 - 0.55 * np.exp(-np.arange(dn) / SR / 0.07)
    for kt in kick_times:
        idx = (np.arange(dn) + kt) % L
        duck[idx] = np.minimum(duck[idx], shape)

    music = (bass + pads * 1.0 + arp + lead) * duck + fx * duck
    music = circ_reverb(music, seconds=1.8, wet=0.22, seed=3)
    mix = drums * 0.9 + music
    # Gentle glue: soft saturation.
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    print(to_mp3(mix, "music", bitrate="128k", peak=0.9))


if __name__ == "__main__":
    main()
