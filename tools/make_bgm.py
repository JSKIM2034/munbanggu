# 배경음악 만들기: 장소마다 다른 칩튠 반복곡을 코드로 작곡해서 ogg로 저장해요.
# 사용: python3 tools/make_bgm.py  -> source/music/*.ogg
import numpy as np, os, subprocess, random

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "source", "music")
os.makedirs(OUT, exist_ok=True)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
def freq(midi): return 440.0 * 2 ** ((midi - 69) / 12)

def osc(kind, f, n, duty=0.5):
    t = np.arange(n) / SR
    ph = (t * f) % 1.0
    if kind == "square": return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri": return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw": return 2 * ph - 1
    return np.sin(2 * np.pi * ph)

def env(n, a=0.005, d=0.08, s=0.6, r=0.05):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n); e[:na] = np.linspace(0, 1, na)
    nd = min(nd, n - na); e[na:na + nd] = np.linspace(1, s, nd)
    nr = min(nr, n); e[n - nr:] *= np.linspace(1, 0, nr)
    return e

def drum(kind, n):
    t = np.arange(n) / SR
    if kind == "kick":
        f = 110 * np.exp(-t * 25) + 45
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)
    if kind == "snare":
        return (np.random.uniform(-1, 1, n) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 18)
    return np.random.uniform(-1, 1, n) * np.exp(-t * 60) * 0.5

# 화음 진행 (근음 midi, 단조 여부)
def chord_tones(root, minor):
    return [root, root + (3 if minor else 4), root + 7]

def song(name, key, scale_minor, bpm, prog, lead="square", seed=1, drums=True, swing=0.0, spooky=False, bars_rep=2):
    random.seed(seed); np.random.seed(seed)
    beat = 60.0 / bpm
    step = beat / 2           # 8분음표
    bars = len(prog) * bars_rep
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR)
    scale = [0, 2, 3, 5, 7, 8, 10] if scale_minor else [0, 2, 4, 5, 7, 9, 11]
    base = 60 + NOTE[key]
    def put(sig, start_s, vol):
        i = int(start_s * SR)
        mix[i:i + len(sig)] += sig * vol
    # 멜로디 동기(2마디)를 만들고 화음에 맞춰 변주해요
    motif = []
    pos = 0.0
    while pos < 8:
        dur = random.choice([0.5, 0.5, 1.0, 0.5, 1.5]) if not spooky else random.choice([1.0, 1.5, 2.0, 0.5])
        dur = min(dur, 8 - pos)
        deg = random.choice([0, 2, 4, 4, 2, 5, 7, 1, 3])
        rest = random.random() < (0.12 if not spooky else 0.25)
        motif.append((pos, dur, deg, rest))
        pos += dur
    for b in range(bars):
        root_deg, minor = prog[b // bars_rep % len(prog)] if bars_rep == 1 else prog[(b // 1) % len(prog)]
        root = base + scale[root_deg % 7] - 12
        ch = chord_tones(root, minor)
        t0 = b * 4 * beat
        # 베이스: 8분음표 근음-5도
        for k in range(8):
            nn = ch[0] - 12 if k % 2 == 0 else ch[2] - 12
            n = int(step * 0.9 * SR)
            sig = osc("tri", freq(nn), n) * env(n, d=0.05, s=0.7)
            put(sig, t0 + k * step + (swing * step if k % 2 else 0), 0.32)
        # 아르페지오 (16분음표)
        for k in range(16):
            nn = ch[k % 3] + (12 if (k // 3) % 2 else 0)
            n = int(step / 2 * 0.8 * SR)
            sig = osc("square", freq(nn), n, 0.25) * env(n, d=0.03, s=0.3)
            put(sig, t0 + k * step / 2, 0.06 if not spooky else 0.04)
        # 멜로디
        half = b % 2
        for (p, dur, deg, rest) in motif:
            if rest or not (half * 4 <= p < half * 4 + 4):
                continue
            var = random.choice([0, 0, 0, 1, -1]) if b >= len(prog) else 0
            d = (deg + root_deg + var) % 7
            octv = (deg + root_deg + var) // 7
            nn = base + scale[d] + 12 * octv + 12
            n = int(dur * beat * 0.92 * SR)
            sig = osc(lead, freq(nn), n, 0.5 if lead == "square" else 0.5) * env(n, d=0.1, s=0.55, r=0.04)
            if spooky:
                tt = np.arange(n) / SR
                sig *= 0.7 + 0.3 * np.sin(2 * np.pi * 6 * tt)
            put(sig, t0 + (p - half * 4) * beat, 0.13)
        # 드럼
        if drums:
            for k in range(8):
                if k in (0, 4):
                    put(drum("kick", int(0.25 * SR)), t0 + k * step, 0.45)
                if k in (2, 6):
                    put(drum("snare", int(0.2 * SR)), t0 + k * step, 0.22)
                put(drum("hat", int(0.05 * SR)), t0 + k * step + (swing * step if k % 2 else 0), 0.12)
    out = mix[:total]
    # 끝과 처음이 자연스럽게 이어지도록 꼬리를 앞쪽에 더해요
    tail = mix[total:total + SR]
    out[:len(tail)] += tail
    out = out / max(1e-6, np.abs(out).max()) * 0.85
    wav = os.path.join(OUT, name + ".wav")
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((out * 32000).astype(np.int16).tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)
    print(name, round(total / SR, 1), "s", os.path.getsize(ogg) // 1024, "KB")

I, ii, iii, IV, V, vi = (0, False), (1, True), (2, True), (3, False), (4, False), (5, True)
i_, iv_, v_, VI, VII, III = (0, True), (3, True), (4, True), (5, False), (6, False), (2, False)
song("menu", "C", False, 116, [I, vi, IV, V], seed=3)
song("ground", "D", False, 138, [I, V, vi, IV], seed=11)
song("hall", "F", False, 128, [I, IV, ii, V], seed=5, swing=0.25)
song("lab", "A", True, 96, [i_, VI, iv_, v_], lead="tri", seed=7, spooky=True)
song("toilet", "D", True, 122, [i_, iv_, VII, III], seed=21, swing=0.2)
song("roof", "G", False, 126, [I, iii, IV, V], lead="saw", seed=9)
song("music", "C", False, 120, [I, vi, ii, V], seed=13, drums=False)
song("boss", "E", True, 152, [i_, VI, VII, v_], lead="saw", seed=31)
