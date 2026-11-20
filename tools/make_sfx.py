# 효과음 만들기: 여러 소리를 겹치고(층), 필터와 잔향을 입혀서 손맛 나는 효과음을 ogg로 저장해요.
# 전부 코드로 만든 소리라 저작권 걱정이 없어요.
# 사용: python3 tools/make_sfx.py  -> source/sfx/fx_*.ogg
import numpy as np, os, subprocess
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "source", "sfx")
rng = np.random.default_rng(7)

def T(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def lp(x, f, o=2): b, a = butter(o, min(f, SR / 2 - 100) / (SR / 2)); return lfilter(b, a, x)
def hp(x, f, o=2): b, a = butter(o, f / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, o=2): b, a = butter(o, [lo / (SR / 2), hi / (SR / 2)], "band"); return lfilter(b, a, x)
def sweep(f0, f1, d, curve=8.0, kind="sin"):
    t = T(d); f = f1 + (f0 - f1) * np.exp(-t * curve)
    ph = np.cumsum(f) / SR
    if kind == "tri": return 4 * np.abs((ph % 1) - 0.5) - 1
    if kind == "sq": return np.sign(np.sin(2 * np.pi * ph))
    return np.sin(2 * np.pi * ph)
def tone(f, d, harm=((1, 1.0),)):
    t = T(d); return sum(a * np.sin(2 * np.pi * f * h * t) for h, a in harm)
def env(d, a=0.002, k=10.0):
    t = T(d); e = np.exp(-t * k); n = max(1, int(a * SR)); e[:n] *= np.linspace(0, 1, n); return e
def pad(x, d): y = np.zeros(int(d * SR)); y[:min(len(x), len(y))] = x[:len(y)]; return y
def at(x, start, total):
    y = np.zeros(int(total * SR)); s = int(start * SR); n = min(len(x), len(y) - s); y[s:s + n] += x[:n]; return y
def reverb(x, wet=0.18, size=1.0):
    y = x.copy()
    for dl, g in [(0.029, 0.5), (0.037, 0.45), (0.041, 0.4), (0.053, 0.35)]:
        d = int(dl * size * SR); buf = np.zeros(len(x) + d * 8)
        buf[:len(x)] += x
        for i in range(1, 8): buf[d * i:d * i + len(x)] += x * (g ** i)
        y = y + wet * 0.25 * buf[:len(x)]
    return y
def master(x, gain=1.0, drive=1.5):
    x = np.tanh(x * drive * gain) / np.tanh(drive)
    fade = min(len(x), int(0.01 * SR)); x[-fade:] *= np.linspace(1, 0, fade)
    return x / max(1e-6, np.abs(x).max()) * 0.7
def save(name, x):
    raw = (x * 32000).astype(np.int16).tobytes()
    path = os.path.join(OUT, "fx_%s.ogg" % name)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", path], input=raw, check=True)
    print("saved", path)

S = {}
# 타격: 퍽(저음 펀치) + 딱(클릭) + 뽀(귀여운 위 소리)
d = 0.16
S["hit"] = master(pad(sweep(260, 70, d, 30) * env(d, 0.001, 22), d) * 1.0
                  + lp(noise(d), 4000) * env(d, 0.0005, 90) * 0.6
                  + sweep(1400, 700, d, 40, "tri") * env(d, 0.001, 45) * 0.25, drive=2.2)
# 처치: 퐁! 하고 터지는 소리 + 반짝
d = 0.32
S["blast"] = master(sweep(420, 55, d, 14) * env(d, 0.001, 11) * 1.0
                    + lp(noise(d), 2200) * env(d, 0.001, 16) * 0.8
                    + hp(noise(d), 5000) * env(d, 0.001, 40) * 0.2, drive=2.5)
# 물총: 쮸웃
d = 0.14
S["shoot"] = master(bp(noise(d), 1200, 5000) * env(d, 0.004, 26) * 0.8
                    + sweep(900, 1800, d, 20) * env(d, 0.002, 30) * 0.35, drive=1.4)
# 콩알탄: 따닥! 폭죽
d = 0.45
crack = np.zeros(int(d * SR))
for st in [0.0, 0.05, 0.09, 0.16]:
    crack += at(hp(noise(0.05), 1500) * env(0.05, 0.0005, 70), st, d) * (1.0 if st == 0 else 0.55)
S["pop"] = master(reverb(crack + sweep(300, 60, d, 20) * env(d, 0.001, 18) * 0.7, 0.35), drive=2.0)
# 경험치 보석: 띵 (벨 음색, 조금 높게)
d = 0.22
S["gem"] = master(reverb(tone(1760, d, ((1, 1), (2.76, 0.35), (5.4, 0.12))) * env(d, 0.001, 22), 0.25), drive=1.2)
# 동전: 짤랑 두 음
d = 0.35
c1 = tone(1975, 0.1, ((1, 1), (2.4, 0.3))) * env(0.1, 0.001, 30)
c2 = tone(2637, 0.3, ((1, 1), (2.4, 0.3))) * env(0.3, 0.001, 12)
S["coin"] = master(reverb(at(c1, 0, d) + at(c2, 0.06, d), 0.3), drive=1.2)
# 레벨업: 도미솔도 + 반짝이
d = 0.9
lv = np.zeros(int(d * SR))
for i, f in enumerate([523, 659, 784, 1047]):
    n = 0.5 if i == 3 else 0.14
    lv += at(tone(f, n, ((1, 1), (2, 0.4), (3, 0.15))) * env(n, 0.003, 4 if i == 3 else 14), i * 0.08, d)
for i in range(10):
    lv += at(tone(2000 + rng.uniform(0, 2500), 0.08) * env(0.08, 0.001, 50) * 0.18, 0.3 + i * 0.04, d)
S["level"] = master(reverb(lv, 0.4, 1.3), drive=1.3)
# 진화: 쑤우웅 올라가는 소리 + 큰 화음 + 반짝반짝
d = 1.8
rise = sweep(200, 1600, 0.6, -0.1) * 0.0
t = T(0.6); f = 200 * (8 ** (t / 0.6)); rise = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.linspace(0.1, 0.6, len(t))
rise += bp(noise(0.6), 800, 6000) * np.linspace(0, 0.4, len(t))
chord = sum(tone(fr, 1.2, ((1, 1), (2, 0.35), (3, 0.12))) for fr in [523, 659, 784, 1047]) * env(1.2, 0.004, 2.5) * 0.4
boom = sweep(180, 40, 0.6, 9) * env(0.6, 0.001, 6) * 1.2 + lp(noise(0.6), 1500) * env(0.6, 0.001, 9) * 0.7
ev = at(rise, 0, d) + at(chord, 0.6, d) + at(boom, 0.6, d)
for i in range(18):
    ev += at(tone(1800 + rng.uniform(0, 3000), 0.1) * env(0.1, 0.001, 40) * 0.15, 0.65 + i * 0.05, d)
S["evo"] = master(reverb(ev, 0.45, 1.5), drive=1.6)
# 아야: 둥- 하고 부드럽게
d = 0.35
S["hurt"] = master(sweep(420, 140, d, 9, "tri") * env(d, 0.002, 9) * 0.8
                   + lp(noise(d), 900) * env(d, 0.001, 25) * 0.6, drive=1.8)
# 첨벙
d = 0.4
S["splash"] = master(reverb(bp(noise(d), 500, 4000) * env(d, 0.003, 9) + sweep(500, 150, d, 15) * env(d, 0.002, 18) * 0.4, 0.3), drive=1.5)
# 회복: 띠링~ 올라가는 두 음
d = 0.55
S["heal"] = master(reverb(at(tone(880, 0.25, ((1, 1), (2, 0.3))) * env(0.25, 0.003, 10), 0, d)
                          + at(tone(1319, 0.4, ((1, 1), (2, 0.3))) * env(0.4, 0.003, 7), 0.1, d), 0.4), drive=1.2)
# 자석: 휘이잉
d = 0.6
t = T(d); f = 300 + 1500 * (t / d) ** 2
S["magnet"] = master(reverb(np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t)) * env(d, 0.01, 3), 0.3), drive=1.3)
# 고무줄: 띠용
d = 0.3
t = T(d); f = 160 + 60 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 6)
S["rubber"] = master(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 0.001, 9) + hp(noise(d), 3000) * env(d, 0.0005, 80) * 0.3, drive=1.8)
# 번개: 지직
d = 0.22
S["zap"] = master(bp(noise(d), 1500, 8000) * (np.sign(np.sin(2 * np.pi * 60 * T(d))) * 0.5 + 0.5) * env(d, 0.001, 14), drive=2.0)
# 쿵 (보스 발소리, 음악실 박자)
d = 0.3
S["kick"] = master(sweep(150, 42, d, 22) * env(d, 0.001, 10) + lp(noise(d), 500) * env(d, 0.0005, 60) * 0.4, drive=2.0)

for k, v in S.items():
    save(k, v)
