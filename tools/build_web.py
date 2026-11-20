# 웹으로 내보내고, 큰 엔진 파일을 25MB 이하 조각으로 나눠 저장소 맨 위에 둬요.
# 사용: python3 tools/build_web.py
import os, re, json, shutil, subprocess, math
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source")
G = os.environ.get("GODOT", "/tmp/godot/Godot_v4.4.1-stable_linux.x86_64")
out = os.path.join(SRC, "export")
shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
subprocess.run([G, "--headless", "--path", SRC, "--export-release", "Web", "export/index.html"], check=True, timeout=600)
for f in os.listdir(ROOT):
    if f.startswith("index."):
        os.remove(os.path.join(ROOT, f))
for f in os.listdir(out):
    if f in ("index.html", "index.wasm"):
        continue
    shutil.copy(os.path.join(out, f), os.path.join(ROOT, f))
wasm = open(os.path.join(out, "index.wasm"), "rb").read()
n = math.ceil(len(wasm) / (24 * 1024 * 1024))
step = math.ceil(len(wasm) / n)
parts = []
for i in range(n):
    name = "index.wasm.part%d" % (i + 1)
    open(os.path.join(ROOT, name), "wb").write(wasm[i * step:(i + 1) * step])
    parts.append(name)
html = open(os.path.join(ROOT, "tools", "shell_template.html"), encoding="utf-8").read()
html = re.sub(r"<title>.*?</title>", "<title>문방구 퇴마단</title>", html)
html = re.sub(r"var parts = \[.*?\];", "var parts = " + json.dumps(parts).replace('"', "'").replace(",", ", ") + ";", html)
new_cfg = re.search(r"const GODOT_CONFIG = (\{.*?\});", open(os.path.join(out, "index.html"), encoding="utf-8").read()).group(1)
html = re.sub(r"const GODOT_CONFIG = \{.*?\};", "const GODOT_CONFIG = " + new_cfg + ";", html)
# 홈 화면에 추가 (앱처럼 꽉 찬 화면)
from PIL import Image
icon = Image.open(os.path.join(SRC, "icon.png"))
for n in (192, 512):
    icon.resize((n, n)).save(os.path.join(ROOT, "index.icon%d.png" % n))
manifest = {"name": "문방구 퇴마단", "short_name": "퇴마단", "start_url": "./index.html", "display": "fullscreen",
    "orientation": "portrait", "background_color": "#3a2148", "theme_color": "#4fa8e8",
    "icons": [{"src": "index.icon192.png", "sizes": "192x192", "type": "image/png"},
              {"src": "index.icon512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"}]}
open(os.path.join(ROOT, "index.manifest.json"), "w", encoding="utf-8").write(json.dumps(manifest, ensure_ascii=False, indent=1))
head = """<link rel="manifest" href="index.manifest.json">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="퇴마단">
<meta name="apple-mobile-web-app-status-bar-style" content="black">
<meta name="theme-color" content="#4fa8e8">
"""
html = html.replace("</head>", head + "</head>", 1)
open(os.path.join(ROOT, "index.html"), "w", encoding="utf-8").write(html)
shutil.rmtree(out)
print("OK", parts, len(wasm), os.path.getsize(os.path.join(ROOT, "index.pck")))
