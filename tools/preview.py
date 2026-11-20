# GLB 미리보기: 앞/옆 렌더
import bpy, sys, math
from mathutils import Vector
src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs=[o for o in bpy.data.objects if o.type=="MESH"]
mn=Vector((1e9,)*3); mx=Vector((-1e9,)*3)
for o in objs:
    for c in o.bound_box:
        w=o.matrix_world@Vector(c); mn=Vector(map(min,mn,w)); mx=Vector(map(max,mx,w))
ctr=(mn+mx)/2; size=max(mx-mn)
print("BOUNDS",tuple(mn),tuple(mx))
sc=bpy.context.scene
sc.render.engine="BLENDER_WORKBENCH"
sc.display.shading.light="STUDIO"; sc.display.shading.color_type="TEXTURE"
sc.render.resolution_x=512; sc.render.resolution_y=512
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type="ORTHO"; cam.data.ortho_scale=size*1.1
for i,(ang) in enumerate([0,90]):
    a=math.radians(ang)
    cam.location=ctr+Vector((math.sin(a)*size*3,-math.cos(a)*size*3,0))
    cam.rotation_euler=(math.pi/2,0,a)
    sc.render.filepath=out+f"_{i}.png"
    bpy.ops.render.render(write_still=True)
