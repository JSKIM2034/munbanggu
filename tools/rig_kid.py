# Meshy T자 꼬마 캐릭터(GLB 한 덩어리) -> 줄이고, 뼈대 넣고, 웹용으로 내보내요.
# 사용: python rig_kid.py 입력.glb 출력.glb 목표면수
import bpy, sys, numpy as np
from mathutils import Vector
src, dst, target = sys.argv[-3], sys.argv[-2], int(sys.argv[-1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != mesh: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = mesh; mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# 면 수 줄이기 (모바일용)
md = mesh.modifiers.new("dec", "DECIMATE"); md.ratio = target / len(mesh.data.polygons)
bpy.ops.object.modifier_apply(modifier="dec")
for p in mesh.data.polygons: p.use_smooth = True
print("FACES", len(mesh.data.polygons))

co = np.array([v.co[:] for v in mesh.data.vertices])
zmin, zmax = co[:, 2].min(), co[:, 2].max()
H = 1.0   # 게임 속 키 1m, 발바닥 z=0
S = H / (zmax - zmin)
def M(x, y, z): return Vector((x * S, y * S, (z - zmin) * S))
for v in mesh.data.vertices: v.co = M(*v.co)

# 원래 좌표로 잰 관절 (앞쪽이 -y)
AY, LY = -0.08, -0.08
J = {"hips": ((0, LY, -0.66), (0, LY, -0.40), None),
     "spine": ((0, LY, -0.40), (0, LY, -0.02), "hips"),
     "head": ((0, LY, -0.02), (0, LY, 0.60), "spine")}
for side, sx in (("L", -1), ("R", 1)):
    J["arm" + side] = ((0.22 * sx, AY, -0.15), (0.38 * sx, AY, -0.15), "spine")
    J["fore" + side] = ((0.38 * sx, AY, -0.15), (0.51 * sx, AY, -0.14), "arm" + side)
    J["hand" + side] = ((0.51 * sx, AY, -0.14), (0.66 * sx, AY, -0.13), "fore" + side)
    J["thigh" + side] = ((0.15 * sx, LY, -0.62), (0.17 * sx, LY, -0.76), "hips")
    J["shin" + side] = ((0.17 * sx, LY, -0.76), (0.17 * sx, LY, -0.90), "thigh" + side)
    J["foot" + side] = ((0.17 * sx, LY, -0.90), (0.17 * sx, -0.30, -0.93), "shin" + side)
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
    if abs(ox) > 0.24 and -0.30 < oz < 0.0 and oy < 0.12:
        w = chain(p, side, ("arm", "fore", "hand"))
        k = 1.0 - sm(0.24, 0.31, abs(ox))         # 어깨는 몸통과 섞기
        if k > 0:
            w = {a: b * (1 - k) for a, b in w.items()}; w["spine"] = k
    elif oz < -0.56:
        legw = sm(-0.56, -0.68, oz) if True else 1
        legw = 1.0 - sm(-0.68, -0.56, oz)
        w = {a: b * legw for a, b in chain(p, side, ("thigh", "shin", "foot")).items()}
        w["hips"] = 1.0 - legw
    else:
        hb = sm(-0.06, 0.06, oz); sb = sm(-0.5, -0.3, oz)
        w = {"head": hb, "spine": (1 - hb) * sb, "hips": (1 - hb) * (1 - sb)}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:3]; tot = sum(x for _, x in top) or 1
    for k, x in top:
        if x / tot > 0.01: vg[k].add([v.index], x / tot, "REPLACE")
mesh.parent = rig; mod = mesh.modifiers.new("Armature", "ARMATURE"); mod.object = rig
mesh.name = "Body"
# 텍스처: 색만 1024
mat = mesh.data.materials[0]; nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]; base = None
for l in list(nt.links):
    if l.to_node == bsdf and l.to_socket.name == "Base Color": base = l.from_node.image
    elif l.to_node == bsdf or l.to_node.type in ("NORMAL_MAP", "SEPARATE_COLOR"): nt.links.remove(l)
for n in list(nt.nodes):
    if (n.type == "TEX_IMAGE" and n.image != base) or n.type in ("NORMAL_MAP", "SEPARATE_COLOR"): nt.nodes.remove(n)
bsdf.inputs["Metallic"].default_value = 0.0; bsdf.inputs["Roughness"].default_value = 0.8
base.scale(1024, 1024)
bpy.ops.object.select_all(action="DESELECT"); rig.select_set(True); mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=False, export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORTED", dst)
