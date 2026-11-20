# 고해상도 모델을 줄인 뒤, 줄인 모델에 새 UV를 펴고 원본의 색을 그대로 구워 입혀요.
# (그냥 줄이기만 하면 눈, 입 같은 얼굴 텍스처가 늘어나거나 금이 가요)
import bpy, bmesh

def decimate_and_bake(hi, target, tex_size=1024, margin=8):
    scene = bpy.context.scene
    # 원본 복제 -> 줄이기
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    bpy.context.view_layer.objects.active = hi
    bpy.ops.object.duplicate()
    lo = bpy.context.object
    lo.name = "Low"
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.00001); bpy.ops.object.mode_set(mode="OBJECT")
    n = len(lo.data.polygons)
    if n > target:
        md = lo.modifiers.new("dec", "DECIMATE"); md.ratio = target / n
        bpy.ops.object.modifier_apply(modifier="dec")
    for p in lo.data.polygons:
        p.use_smooth = True
    # 새 UV
    while len(lo.data.uv_layers) > 0:
        lo.data.uv_layers.remove(lo.data.uv_layers[0])
    lo.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    # 굽기 대상 이미지와 재질
    img = bpy.data.images.new("Baked", tex_size, tex_size)
    mat = bpy.data.materials.new("BakedMat"); mat.use_nodes = True
    nt = mat.node_tree
    bsdf = [nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED"][0]
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.0; bsdf.inputs["Roughness"].default_value = 0.8
    lo.data.materials.clear(); lo.data.materials.append(mat)
    nt.nodes.active = tn
    # 원본 재질은 색만 남겨요 (금속, 노멀은 굽기에 방해돼요)
    for m in hi.data.materials:
        if not m or not m.use_nodes: continue
        for nd in m.node_tree.nodes:
            if nd.type == "BSDF_PRINCIPLED":
                nd.inputs["Metallic"].default_value = 0.0
                for l in list(m.node_tree.links):
                    if l.to_node == nd and l.to_socket.name in ("Metallic", "Normal", "Roughness"):
                        m.node_tree.links.remove(l)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.use_selected_to_active = True
    size = max(hi.dimensions)
    scene.render.bake.cage_extrusion = size * 0.01
    scene.render.bake.max_ray_distance = size * 0.03
    scene.render.bake.margin = margin
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True); lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="DIFFUSE")
    img.pack()
    # 원본은 지워요
    bpy.data.objects.remove(hi)
    bpy.ops.object.select_all(action="DESELECT")
    lo.select_set(True); bpy.context.view_layer.objects.active = lo
    print("BAKED", len(lo.data.polygons), tex_size)
    return lo, img
