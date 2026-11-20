# 소품이 여러 개 놓인 시트(GLB 한 덩어리)를 한 번에 줄이고 색을 구운 뒤, 떨어진 덩어리끼리 나눠 각각 GLB로 내보내요.
# 사용: python sheet_split.py -- 입력.glb 출력접두어 목표면수 텍스처크기 배율
#  출력: 접두어_0.glb, 접두어_1.glb ... (왼쪽 위부터), 각 조각은 바닥 가운데가 원점
import sys as _s, os as _o
_s.path.insert(0, _o.path.dirname(_o.path.abspath(__file__)))
import bpy, bmesh, sys
from mathutils import Vector
import bake_util
args = sys.argv[sys.argv.index("--") + 1:]
src, prefix, target, tex, scale = args[0], args[1], int(args[2]), int(args[3]), float(args[4])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in list(bpy.data.objects):
    if o.type != "MESH": bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
mesh = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
lo, img = bake_util.decimate_and_bake(mesh, target, tex)
for v in lo.data.vertices: v.co *= scale
# 떨어진 덩어리 나누기
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in bpy.data.objects if o.type == "MESH"]
def bb(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return [min(v.x for v in vs), max(v.x for v in vs), min(v.y for v in vs), max(v.y for v in vs), len(vs)]
boxes = [bb(o) for o in parts]
# 위에서 봤을 때(x, y) 상자가 겹치거나 아주 가까운 덩어리끼리 묶어요
gap = 0.005 * scale
groups = [[i] for i in range(len(parts))]
gb = [list(b[:4]) for b in boxes]
changed = True
while changed:
    changed = False
    for i in range(len(groups)):
        for j in range(i + 1, len(groups)):
            a, b = gb[i], gb[j]
            if a[0] - gap <= b[1] and b[0] - gap <= a[1] and a[2] - gap <= b[3] and b[2] - gap <= a[3]:
                groups[i] += groups[j]; gb[i] = [min(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), max(a[3], b[3])]
                del groups[j]; del gb[j]; changed = True; break
        if changed: break
order = sorted(range(len(groups)), key=lambda k: (-round(gb[k][3] / (0.5 * scale)), gb[k][0]))
n = 0
keep = []
for k in order:
    if sum(boxes[i][4] for i in groups[k]) < 60:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    objs = [parts[i] for i in groups[k]]
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.object
    vs = [v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in o.data.vertices: v.co -= c
    o.name = "p%d" % n
    o.location = (n * 3.0, 0, 0)
    print("PIECE", n, "at x=%.2f y=%.2f" % (c.x / scale, c.y / scale), "size", tuple(round(mx[i] - mn[i], 2) for i in range(3)))
    keep.append(o)
    n += 1
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=prefix + ".glb", export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=86)
print("EXPORTED", prefix + ".glb", n)
