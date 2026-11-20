# 뼈대 없는 모델(귀신, 보스, 할머니)을 줄이고 크기를 맞춰 내보내요.
# 사용: python prop_export.py 입력.glb 출력.glb 목표면수 키(m) [x0 x1 z0 z1]  <- 마지막 4개는 시트에서 한 칸만 자를 때
import sys as _s, os as _o
_s.path.insert(0, _o.path.dirname(_o.path.abspath(__file__)))
import bpy, bmesh, sys
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
src, dst, target, height = args[0], args[1], int(args[2]), float(args[3])
cell = [float(a) for a in args[4:8]] if len(args) >= 8 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != mesh: bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = mesh; mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# UV 경계마다 끊어진 꼭짓점을 붙여요 (안 붙이면 줄일 때 틈이 벌어져 금처럼 보여요)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00001); bpy.ops.object.mode_set(mode="OBJECT")
if cell:
    x0, x1, z0, z1 = cell
    bm = bmesh.new(); bm.from_mesh(mesh.data)
    kill = [f for f in bm.faces if not (x0 <= f.calc_center_median().x < x1 and z0 <= f.calc_center_median().z < z1)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(mesh.data); bm.free()
n = len(mesh.data.polygons)
if n > target:
    md = mesh.modifiers.new("dec", "DECIMATE"); md.ratio = target / n
    bpy.ops.object.modifier_apply(modifier="dec")
for p in mesh.data.polygons: p.use_smooth = True
vs = [v.co.copy() for v in mesh.data.vertices]
mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
S = height / (mx.z - mn.z)
c = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
for v in mesh.data.vertices:
    v.co = (v.co - c) * S
print("FACES", len(mesh.data.polygons), "SIZE", tuple(round((mx[i] - mn[i]) * S, 2) for i in range(3)))
mat = mesh.data.materials[0]; nt = mat.node_tree
bsdf = [nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED"][0]; base = None
for l in list(nt.links):
    if l.to_node == bsdf and l.to_socket.name == "Base Color": base = l.from_node.image
    elif l.to_node == bsdf or l.to_node.type in ("NORMAL_MAP", "SEPARATE_COLOR"): nt.links.remove(l)
for nd in list(nt.nodes):
    if (nd.type == "TEX_IMAGE" and nd.image != base) or nd.type in ("NORMAL_MAP", "SEPARATE_COLOR"): nt.nodes.remove(nd)
bsdf.inputs["Metallic"].default_value = 0.0; bsdf.inputs["Roughness"].default_value = 0.8
tex = int(args[8]) if len(args) >= 9 else 1024
base.scale(tex, tex)
import tex_bleed; tex_bleed.bleed(base, mesh)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=86)
print("EXPORTED", dst)
