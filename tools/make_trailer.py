# 홍보 영상 만들기 (세로 1080x1920, 약 25초). 먼저 게임을 녹화해 둬야 해요 (auto/LOG.md 2026-11-25 참고). 사용: python3 tools/make_trailer.py ko|en
import subprocess, sys, os
lang=sys.argv[1]
V='/tmp/claude-0/vid'; F='/home/claude/munbanggu/source/fonts/Jua-Regular.ttf'
OUT=f'{V}/out/{lang}'; os.makedirs(OUT,exist_ok=True)
if lang=='ko':
    segs=[('t_swarm_ko.avi',0.0,3.0,'학교 귀신이 몰려온다!'),
          ('ko.avi',211.0,4.0,'장난감 무기를 모으고'),
          ('t_evo_ko.avi',0.2,4.2,''),
          ('t_swarm_ko.avi',3.0,2.2,'한 번에 싹!'),
          ('ko.avi',238.0,3.5,'콤보가 쌓일수록 더 세게'),
          ('t_boss_ko.avi',0.0,3.0,'대왕귀신까지 물리쳐라!'),
          ('t_boss_ko.avi',5.0,2.0,'대왕귀신까지 물리쳐라!')]
    end=('home_ko.png','웹에서 바로 무료 플레이','jskim2034.github.io/munbanggu')
else:
    segs=[('t_swarm_en.avi',0.0,3.0,'School ghosts are coming!'),
          ('en.avi',88.0,4.0,'Grab toy weapons'),
          ('t_evo_en.avi',0.2,4.2,''),
          ('t_swarm_en.avi',3.0,2.2,'Wipe them all out!'),
          ('t_mid_en.avi',0.5,3.5,'Bigger combos, bigger hits'),
          ('t_boss_en.avi',0.0,3.0,'Beat the King Ghost!'),
          ('t_boss_en.avi',5.0,2.0,'Beat the King Ghost!')]
    end=('home_en.png','Free to play in your browser','jskim2034.github.io/munbanggu')
def esc(t): return t.replace(':','\\:').replace("'","\u2019")
files=[]
for i,(src,ss,d,cap) in enumerate(segs):
    vf='scale=1080:1920:flags=lanczos,fps=30'
    if cap:
        vf+=f",drawtext=fontfile={F}:text='{esc(cap)}':fontsize={92 if lang=='ko' else 74}:fontcolor=white:borderw=8:bordercolor=0x3a2148:x=(w-text_w)/2:y=h*0.70"
    vf+=f',fade=t=in:st=0:d=0.12,fade=t=out:st={d-0.12}:d=0.12'
    af=f'aresample=48000,afade=t=in:st=0:d=0.08,afade=t=out:st={d-0.1}:d=0.1,volume=1.4'
    o=f'{OUT}/s{i}.mp4'
    cmd=['ffmpeg','-v','error','-y','-ss',str(ss),'-i',f'{V}/{src}','-t',str(d),'-vf',vf,'-af',af,'-c:v','libx264','-preset','medium','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-ar','48000','-ac','2',o]
    subprocess.run(cmd,check=True); files.append(o)
img,l1,l2=end
o=f'{OUT}/s_end.mp4'
vf=(f"scale=1080:1920,drawbox=x=0:y=1380:w=1080:h=420:color=0x3a2148@0.82:t=fill,"
    f"drawtext=fontfile={F}:text='{esc(l1)}':fontsize={84 if lang=='ko' else 70}:fontcolor=0xffdf3d:x=(w-text_w)/2:y=1450,"
    f"drawtext=fontfile={F}:text='{esc(l2)}':fontsize=62:fontcolor=white:x=(w-text_w)/2:y=1600,fade=t=in:st=0:d=0.25")
cmd=['ffmpeg','-v','error','-y','-loop','1','-t','3.5','-i',f'{V}/{img}','-ss','0','-t','3.5','-i','/home/claude/munbanggu/source/music/menu.ogg',
     '-vf',vf,'-af','afade=t=in:st=0:d=0.2,afade=t=out:st=3.0:d=0.5','-r','30','-c:v','libx264','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-ar','48000','-ac','2','-shortest',o]
subprocess.run(cmd,check=True); files.append(o)
with open(f'{OUT}/list.txt','w') as f:
    for x in files: f.write(f"file '{x}'\n")
final=f'{V}/out/munbanggu_trailer_{lang}.mp4'
subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',f'{OUT}/list.txt','-c:v','libx264','-crf','23','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',final],check=True)
print(final)
