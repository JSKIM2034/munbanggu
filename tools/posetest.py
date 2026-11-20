import bpy, sys, math
from mathutils import Vector, Euler
src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
rig=[o for o in bpy.data.objects if o.type=="ARMATURE"][0]
pb=rig.pose.bones
def rot(n,x=0,y=0,z=0):
    b=pb.get(n)
    if b: b.rotation_mode="XYZ"; b.rotation_euler=(math.radians(x),math.radians(y),math.radians(z))
# 팔 내리기 + 앞으로, 다리 하나 앞
rot("armL",0,0,0); 
for n in pb: print(n.name, end=" ")
sc=bpy.context.scene
for b in pb: b.rotation_mode="XYZ"
import mathutils
def bend(n, axis, deg):
    b=pb[n]; b.rotation_mode="QUATERNION"
    # 월드 축 기준 회전 -> 본 로컬
    mw=(rig.matrix_world@b.bone.matrix_local).to_3x3().normalized()
    a=mw.inverted()@Vector(axis)
    b.rotation_quaternion=mathutils.Quaternion(a, math.radians(deg))
bend("armL",(0,1,0),-60); bend("armR",(0,1,0),60)
bend("foreL",(1,0,0),40); bend("foreR",(1,0,0),40)
bend("thighL",(1,0,0),35); bend("thighR",(1,0,0),-35); bend("shinR",(1,0,0),30)
bend("head",(0,0,1),20)
bpy.context.view_layer.update()
mn=Vector((-0.6,-0.6,0)); mx=Vector((0.6,0.6,1.0)); ctr=(mn+mx)/2
sc.render.engine="BLENDER_WORKBENCH"; sc.display.shading.light="STUDIO"; sc.display.shading.color_type="TEXTURE"
sc.render.resolution_x=400; sc.render.resolution_y=400
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type="ORTHO"; cam.data.ortho_scale=1.15
for i,ang in enumerate([0,90,30]):
    a=math.radians(ang); cam.location=ctr+Vector((math.sin(a)*3,-math.cos(a)*3,0)); cam.rotation_euler=(math.pi/2,0,a)
    sc.render.filepath=f"{out}_{i}.png"; bpy.ops.render.render(write_still=True)
