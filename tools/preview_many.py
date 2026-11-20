import bpy, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]; files = args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    for o in set(bpy.data.objects) - before:
        if o.parent is None:
            o.location.x += i * 1.6
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 220 * len(files); sc.render.resolution_y = 260
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.6 * len(files)
cam.location = Vector(((len(files) - 1) * 0.8, -6, 0.75)); cam.rotation_euler = (math.radians(88), 0, 0)
sc.render.filepath = out; bpy.ops.render.render(write_still=True)
