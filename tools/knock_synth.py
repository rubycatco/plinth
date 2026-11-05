"""A numpy port of Sources/PlinthCore/KnockSynth.swift: the same voices, seeds and
hall, so showoff_video.py's soundtrack is the knocks the app plays."""
import math
import numpy as np
from scipy.signal import lfilter

SR = 44100
M64 = (1 << 64) - 1


class Rng:
    def __init__(self, seed):
        self.s = seed if seed else 0x9E3779B97F4A7C15

    def next(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & M64
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & M64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & M64
        return z ^ (z >> 31)

    def unit(self):
        return (self.next() >> 40) / 16777216

    def gaussian(self):
        u1 = max(self.unit(), 1e-7)
        u2 = self.unit()
        return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)


def M(ratio, amp, tau, cents=0):
    return (ratio, amp, tau, cents)


TONES = {
    "wood": dict(bases=[612, 598, 625], length=0.9, seed=1,
                 modes=[M(1, 1, .110), M(1.52, .45, .070), M(2.31, .30, .045), M(3.07, .18, .030), M(4.63, .10, .018)],
                 body=M(.5, .35, .16), noise=(.6, .004, 1500, 7000), attack=.001),
    "lacquer": dict(bases=[820, 802, 840], length=.62, seed=11,
                    modes=[M(1, 1, .070), M(1.47, .48, .040), M(2.30, .28, .024), M(3.15, .14, .014), M(5.60, .08, .008)],
                    body=M(.55, .14, .07), noise=(.42, .0032, 3200, 10000), attack=.0005),
    "ink": dict(bases=[392, 380, 404], length=1.05, seed=23,
                modes=[M(1, 1, .18), M(1.5, .32, .10), M(2.28, .12, .05)],
                body=M(.48, .55, .24), noise=(.22, .010, 350, 1400), attack=.008, lowpass=1500),
    "cartoon": dict(bases=[520, 508, 534], length=.48, seed=37,
                    modes=[M(1, 1, .065), M(1.5, .30, .038), M(2.4, .07, .018)],
                    body=M(.5, .16, .07), noise=(.28, .0025, 1600, 4800), attack=.002),
    "pixel": dict(bases=[604, 590, 618], length=.42, seed=41,
                  modes=[M(1, .9, .050), M(2, .42, .028), M(3, .16, .014), M(4, .06, .008)],
                  noise=(.7, .003, 2000, 7000), attack=.0004, crush=True),
    "jade": dict(bases=[740, 724, 758], length=.85, seed=53,
                 modes=[M(1, 1, .16), M(2.27, .40, .07), M(3.70, .18, .030), M(6.40, .10, .010)],
                 body=M(.72, .06, .04), noise=(.28, .0011, 4500, 12000), attack=.0004),
    "bowl": dict(bases=[196, 191, 202], length=3.0, seed=67,
                 modes=[M(1, .62, .70, 5), M(2.05, 1, .42, 8), M(2.98, .36, .18, 10), M(5.10, .14, .07, 14),
                        M(9.40, .16, .014), M(14.5, .08, .007)],
                 noise=(.22, .0018, 3200, 9000), attack=.0016),
    "key": dict(bases=[360, 348, 372], length=.22, seed=79,
                modes=[M(1, .35, .018), M(4.2, .70, .010), M(7.5, .22, .005)],
                noise=(.85, .0014, 2800, 9000), attack=.0003),
    "bamboo": dict(bases=[262, 254, 270], length=.95, seed=83,
                   modes=[M(1, 1, .12), M(2.76, .38, .05), M(4.4, .12, .025)],
                   body=M(.5, .65, .22), noise=(.25, .004, 800, 3200), attack=.0012),
    "stone": dict(bases=[340, 330, 350], length=.5, seed=89,
                  modes=[M(1, 1, .06), M(1.7, .30, .03), M(2.6, .12, .015)],
                  noise=(.55, .006, 400, 2200), attack=.001, lowpass=2000),
    "piston": dict(bases=[510, 496, 524], length=.38, seed=97,
                   modes=[M(1, .45, .028), M(2.8, .85, .04), M(5.1, .28, .016), M(8.4, .10, .007)],
                   noise=(.35, .0012, 3500, 10000), attack=.0003),
    "crt": dict(bases=[210, 204, 216], length=.4, seed=101,
                modes=[M(1, 1, .05), M(2.1, .18, .02)],
                noise=(.28, .008, 200, 900), attack=.002, lowpass=1100, crush=True),
    "bead": dict(bases=[1050, 1030, 1072], length=.3, seed=103,
                 modes=[M(1, 1, .030), M(2.71, .42, .016), M(5.2, .16, .007)],
                 body=M(.42, .10, .03), noise=(.55, .0016, 2500, 8000), attack=.0004),
    "plate": dict(bases=[330, 322, 338], length=2.2, seed=107,
                  modes=[M(1, .8, .55, 6), M(1.59, 1, .38, 9), M(2.14, .55, .22, 12), M(2.65, .30, .12), M(3.61, .14, .06)],
                  noise=(.18, .003, 600, 2800), attack=.002, lowpass=5000),
    "porcelain": dict(bases=[1180, 1160, 1204], length=.7, seed=109,
                      modes=[M(1, 1, .14), M(2.32, .36, .06), M(4.1, .16, .024), M(6.9, .08, .009)],
                      noise=(.30, .0008, 5000, 13000), attack=.0003),
    "bell": dict(bases=[392, 384, 400], length=2.0, seed=113,
                 modes=[M(.5, .30, .50), M(1, 1, .40, 4), M(1.19, .65, .32), M(2.4, .35, .12), M(3.1, .20, .06), M(4.9, .10, .03)],
                 noise=(.25, .002, 800, 4000), attack=.001),
    "stamp": dict(bases=[180, 172, 188], length=.3, seed=127,
                  modes=[M(1, 1, .030), M(2.3, .35, .015), M(3.9, .12, .008)],
                  body=M(.6, .40, .04), noise=(.60, .006, 300, 2500), attack=.001, lowpass=2500),
    "chime": dict(bases=[560, 548, 574], length=1.7, seed=131,
                  modes=[M(1, 1, .35), M(2.76, .45, .14), M(5.4, .20, .05), M(8.9, .08, .015)],
                  noise=(.15, .003, 1000, 5000), attack=.0015),
    "board": dict(bases=[430, 420, 442], length=.95, seed=137,
                  modes=[M(1, 1, .13), M(1.58, .50, .08), M(2.42, .28, .05), M(3.3, .14, .03)],
                  body=M(.5, .45, .18), noise=(.55, .004, 1200, 6000), attack=.001),
    "ceramic": dict(bases=[1450, 1420, 1480], length=.5, seed=139,
                    modes=[M(1, 1, .09), M(2.1, .45, .05), M(3.5, .25, .02), M(5.6, .10, .01)],
                    body=M(.35, .15, .05), noise=(.45, .0007, 5000, 14000), attack=.0002),
    "temple": dict(bases=[370, 361, 380], length=1.2, seed=149,
                   modes=[M(1, 1, .17), M(1.52, .45, .10), M(2.31, .22, .055), M(3.07, .10, .032)],
                   body=M(.5, .65, .30), noise=(1.0, .005, 800, 3500), attack=.002, lowpass=4500),
}


def biquad(f0, q, band):
    w0 = 2 * math.pi * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    cosw = math.cos(w0)
    a0 = 1 + alpha
    if band:
        b = [alpha / a0, 0, -alpha / a0]
    else:
        bb = (1 - cosw) / 2 / a0
        b = [bb, (1 - cosw) / a0, bb]
    return b, [1, -2 * cosw / a0, (1 - alpha) / a0]


REF_FORCE = 0.6


def strike(tone, base, seed, force=REF_FORCE, place=0.0, warmth=0.0):
    """One strike, as KnockSynth.strike: force 0 to 1, place -1 to 1 off the sweet spot,
    warmth -1 (a winter's morning board) to 1 (a summer's late night), 0 as tuned."""
    hard = max(force, .05) / REF_FORCE
    edge = min(abs(place), 1)
    w = min(max(warmth, -1), 1)
    # Past the evening board, softer still into the deep night, with no step at 0.7.
    late = max((w - .7) / .3, 0)
    night = late * late * (3 - 2 * late)
    base = base * (1 + .004 * (force - REF_FORCE)) * (1 + .012 * edge)
    rng = Rng(seed)
    n = int(np.float32(tone["length"]) * np.float32(SR))  # in Float, as Swift counts it
    out = np.zeros(n)
    idx = np.arange(n)

    def osc(freq, amp, tau, phase):
        dp = 2 * math.pi * freq / SR
        decay = math.exp(-1 / (tau * SR))
        return amp * decay ** idx * np.sin(phase + dp * idx)

    def add(ratio, amp, tau, cents, jitter, body=False):
        nonlocal out
        amp = amp * hard ** (.6 * math.log2(max(ratio, .25)))
        if body:
            amp *= 1 - .4 * edge
        elif ratio == 1:
            amp *= 1 - .3 * edge
        elif ratio > 1:
            amp *= 1 + .5 * edge
        if body:
            amp *= 1 + .20 * w + .10 * night
            tau *= 1 + .10 * w + .04 * night
        elif ratio > 1:
            amp *= ratio ** (-.18 * w - .12 * night)
            tau *= ratio ** (-.07 * w - .04 * night)
        f = base * ratio
        if jitter:
            f *= 1 + rng.gaussian() * 0.004
        p0 = rng.unit() * 2 * math.pi
        out += osc(f, amp, tau, p0)
        if cents:
            out += osc(f * 2 ** (cents / 1200), amp * .35, tau, p0 + math.pi / 2)

    for m in tone["modes"]:
        add(*m, jitter=True)
    if "body" in tone:
        r, a, t, _ = tone["body"]
        add(r, a, t, 0, False, body=True)
    if "noise" in tone:
        amp, tau, lo, hi = tone["noise"]
        amp, lo, hi = amp * hard ** 1.2, lo * hard ** .2, min(hi * hard ** .4, .45 * SR)
        amp = amp * 2 ** (-.32 * w - .32 * night)
        lo = lo * 2 ** (-.16 * w - .14 * night)
        hi = min(hi * 2 ** (-.28 * w - .20 * night), .45 * SR)
        decay = math.exp(-1 / (tau * SR))
        burst = np.array([rng.gaussian() for _ in range(n)]) * decay ** idx
        f0 = math.sqrt(lo * hi)
        b, a = biquad(f0, max(f0 / (hi - lo), .15), True)
        out += amp * lfilter(b, a, burst)
    # A warm night's contact is longer and softer; the morning board's shorter.
    contact = 2 ** (.45 * w + .50 * night)
    att = max(tone["attack"] * (1 / hard) ** .7 * contact * SR, 1)
    k = min(n, int(att))
    out[:k] *= np.arange(k) / att
    fade = min(n, int(.05 * SR))
    out[n - fade:] *= 1 - np.arange(fade) / (fade - 1)
    if "lowpass" in tone:
        b, a = biquad(tone["lowpass"], .707, False)
        out = lfilter(b, a, out)
    if tone.get("crush"):
        tick = Rng((seed + 9) & M64)
        m = int(.012 * SR)
        step = max(int(SR / 6000), 1)
        held = 0
        for i in range(min(m, n)):
            if i % step == 0:
                held = (tick.unit() * 2 - 1) * math.exp(-i / (.003 * SR))
            # Added after the attack's envelope, so it softens with it when warm.
            soften = 1 - max(w, 0) * (1 - min(i / att, 1))
            out[i] += held * .22 * (1 - .22 * w - .22 * night) * soften
    return level(out)


def level(x, attack_rms=.23, peak=.85):
    n = min(len(x), int(.15 * SR))
    unit = x / np.abs(x).max()
    for drive in [1, 1.6, 2.4]:
        z = unit if drive == 1 else np.tanh(unit * drive) / math.tanh(drive)
        g = attack_rms / max(math.sqrt(np.mean(z[:n] ** 2)), 1e-8)
        last = z * g
        p = np.abs(last).max()
        if p <= peak:
            return last
        if drive == 2.4:
            return last * peak / p
    return last


def comb(x, ms, rt60=2.3, damp=.42):
    d = max(int(ms / 1000 * SR), 1)
    fb = math.exp(-6.91 * (d / SR) / rt60)
    n = len(x)
    y = np.zeros(n)
    buf = np.zeros(d)
    filt = 0.0
    # Block-wise: the output of block k is the buffer written during block k-1.
    for s in range(0, n, d):
        e = min(s + d, n)
        out = buf[: e - s].copy()
        y[s:e] = out
        # filter is a one-pole lowpass across samples in the block
        f = lfilter([1 - damp], [1, -damp], out, zi=[filt * damp])[0]
        filt = f[-1] if len(f) else filt
        nb = x[s:e] + f * fb
        buf = np.concatenate([nb, buf[e - s:]]) if e - s < d else nb
    return y


def allpass(x, ms, fb=.5):
    d = max(int(ms / 1000 * SR), 1)
    # buf[n] = x[n] + fb*buf[n-d]; y = buf[n-d] - fb*x
    b = np.zeros(d + 1); b[0] = 1
    a = np.zeros(d + 1); a[0] = 1; a[d] = -fb
    w = lfilter(b, a, x)
    delayed = np.concatenate([np.zeros(d), w[:-d]])
    return delayed - fb * x


def hall(dry, warmth=0.0):
    damp = .42 + .06 * min(max(warmth, -1), 1)
    n = int(3 * SR)
    L = np.zeros(n); R = np.zeros(n)
    for ms, g, pan in [(13, .28, -.55), (19, .24, .40), (27, .20, -.25), (34, .16, .50), (46, .13, -.15), (58, .10, .30), (71, .08, -.40)]:
        d = int(ms / 1000 * SR)
        c = min(len(dry), n - d)
        L[d:d + c] += dry[:c] * g * math.sqrt((1 - pan) / 2)
        R[d:d + c] += dry[:c] * g * math.sqrt((1 + pan) / 2)
    pre = int(.02 * SR)
    x = np.zeros(n); x[pre:pre + len(dry)] = dry[: n - pre]
    l = sum(comb(x, ms, damp=damp) for ms in [47, 53, 59, 67, 73, 83, 89, 97]) * .15
    r = sum(comb(x, ms + 1.7, damp=damp) for ms in [47, 53, 59, 67, 73, 83, 89, 97]) * .15
    for ms in [5.1, 1.7]:
        l = allpass(l, ms)
    for ms in [6.3, 2.3]:
        r = allpass(r, ms)
    L += l; R += r
    fade = int(.4 * SR)
    g = (1 - np.arange(fade) / fade) ** 2
    L[n - fade:] *= g; R[n - fade:] *= g
    dryE = np.sum(dry ** 2) / SR
    hallE = np.sum(L ** 2 + R ** 2) / (2 * SR)
    gg = math.sqrt(dryE / 2 / hallE)
    pk = max(np.abs(L).max(), np.abs(R).max()) * gg
    if pk > .4:
        gg *= .4 / pk
    return L * gg, R * gg


def prepare(name):
    t = TONES[name]
    out = []
    for i, base in enumerate(t["bases"]):
        d = strike(t, base, t["seed"] + i)
        l, r = hall(d)
        out.append((d, l, r))
    return out
