# Meshy T자 꼬마 캐릭터(GLB 한 덩어리) -> 줄이고, 뼈대 넣고, 웹용으로 내보내요.
# 사용: python rig_kid.py 입력.glb 출력.glb 목표면수
import sys as _s, os as _o
_s.path.insert(0, _o.path.dirname(_o.path.abspath(__file__)))
import bpy, sys, numpy as np
from mathutils import Vector
import json
src, dst, target, cfgs = sys.argv[-4], sys.argv[-3], int(sys.argv[-2]), sys.argv[-1]
C = json.loads(cfgs)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != mesh: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = mesh; mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# 줄이고 새 UV에 원본 색을 구워요 (얼굴이 깨지지 않게)
import bake_util
TEX = int(C.get("tex", 2048))
mesh, baked = bake_util.decimate_and_bake(mesh, target, TEX)
print("FACES", len(mesh.data.polygons))

co = np.array([v.co[:] for v in mesh.data.vertices])
zmin, zmax = co[:, 2].min(), co[:, 2].max()
H = 1.0   # 게임 속 키 1m, 발바닥 z=0
S = H / (zmax - zmin)
def M(x, y, z): return Vector((x * S, y * S, (z - zmin) * S))
for v in mesh.data.vertices: v.co = M(*v.co)

# 원래 좌표로 잰 관절 (앞쪽이 -y). C에 캐릭터별 값이 들어 있어요
co0 = (co - np.array([0, 0, 0]))  # 이미 바뀌기 전 좌표
cx = C.get("cx", 0.0)
az = C["arm_z"]; ax0 = C["arm_x"]
band = (co[:, 2] > az - 0.12) & (co[:, 2] < az + 0.1) & (np.abs(co[:, 0] - cx) > ax0 + 0.08)
AY = float(co[band, 1].mean()) if band.sum() > 10 else -0.05
legs = co[:, 2] < C["crotch"] - 0.1
LY = float(co[legs, 1].mean()) if legs.sum() > 10 else -0.05
print("AY", AY, "LY", LY)
cr, ht = C["crotch"], C["hip_top"]
J = {"hips": ((cx, LY, cr), (cx, LY, (cr + C["neck"]) / 2), None),
     "spine": ((cx, LY, (cr + C["neck"]) / 2), (cx, LY, C["neck"]), "hips"),
     "head": ((cx, LY, C["neck"]), (cx, LY, C["neck"] + 0.6), "spine")}
for side, sx in (("L", -1), ("R", 1)):
    xt = C["tip"] if sx > 0 else C.get("tip_l", C["tip"])
    J["arm" + side] = ((cx + C["shoulder"] * sx, AY, az), (cx + C["elbow"] * sx, AY, az), "spine")
    J["fore" + side] = ((cx + C["elbow"] * sx, AY, az), (cx + C["wrist"] * sx, AY, az), "arm" + side)
    J["hand" + side] = ((cx + C["wrist"] * sx, AY, az), (cx + xt * sx, AY, az), "fore" + side)
    lx = C["leg_x"]
    J["thigh" + side] = ((cx + (lx - 0.02) * sx, LY, cr + 0.04), (cx + lx * sx, LY, C["knee"]), "hips")
    J["shin" + side] = ((cx + lx * sx, LY, C["knee"]), (cx + lx * sx, LY, C["ankle"]), "thigh" + side)
    J["foot" + side] = ((cx + lx * sx, LY, C["ankle"]), (cx + lx * sx, LY - 0.22, zmin + 0.02), "shin" + side)
W = {k: (M(*a), M(*b), p) for k, (a, b, p) in J.items()}
ad = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", ad)
bpy.context.scene.collection.objects.link(rig); bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT"); eb = {}
for name in ["hips","spine","head","armL","foreL","handL","armR","foreR","handR","thighL","shinL","footL","thighR","shinR","footR"]:
    h, t, p = W[name]; b = ad.edit_bones.new(name); b.head, b.tail = h, t
    if p: b.parent = eb[p]; b.use_connect = (eb[p].tail - h).length < 1e-4
    eb[name] = b
bpy.ops.object.mode_set(mode="OBJECT")

def seg(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); return (a + ab * t - p).length
def sm(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t)
for n in W: mesh.vertex_groups.new(name=n)
vg = {g.name: g for g in mesh.vertex_groups}
def chain(p, side, names):
    c = {n + side: 1.0 / (seg(p, W[n + side][0], W[n + side][1]) ** 4 + 1e-9) for n in names}
    t = sum(c.values()); return {k: v / t for k, v in c.items()}
for v in mesh.data.vertices:
    p = v.co; ox, oy, oz = p.x / S, p.y / S, p.z / S + zmin
    side = "L" if ox < 0 else "R"
    side = "L" if ox < cx else "R"
    dx = abs(ox - cx)
    if dx > C["arm_x"] and az - C["arm_h"] < oz < az + C["arm_h"] and oy < C.get("arm_back", 0.12):
        w = chain(p, side, ("arm", "fore", "hand"))
        k = 1.0 - sm(C["arm_x"], C["arm_x"] + 0.07, dx)         # 어깨는 몸통과 섞기
        if k > 0:
            w = {a: b * (1 - k) for a, b in w.items()}; w["spine"] = k
    elif oz < ht:
        legw = 1.0 - sm(cr - 0.02, ht, oz)
        w = {a: b * legw for a, b in chain(p, side, ("thigh", "shin", "foot")).items()}
        w["hips"] = 1.0 - legw
    else:
        hb = sm(C["neck"] - 0.06, C["neck"] + 0.06, oz); sb = sm(cr + 0.1, (cr + C["neck"]) / 2, oz)
        w = {"head": hb, "spine": (1 - hb) * sb, "hips": (1 - hb) * (1 - sb)}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:3]; tot = sum(x for _, x in top) or 1
    for k, x in top:
        if x / tot > 0.01: vg[k].add([v.index], x / tot, "REPLACE")
mesh.parent = rig; mod = mesh.modifiers.new("Armature", "ARMATURE"); mod.object = rig
mesh.name = "Body"
bpy.ops.object.select_all(action="DESELECT"); rig.select_set(True); mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=False, export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORTED", dst)
