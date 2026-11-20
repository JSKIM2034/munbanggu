extends Node3D
# 문방구 퇴마단
# 철수가 운동장에서 몰려오는 학교 귀신을 문방구 장난감으로 물리쳐요.
# - 메인 스킬(장난감 무기) 4종 + 보조 스킬 6종
# - 메인 스킬 Lv.5 + 세트 짝꿍 보조 스킬이 있으면 "진화"해서 훨씬 강해져요.
# 성능: 귀신, 딱지, 물방울, 효과는 전부 MultiMesh로 한 번에 그려요.

const ARENA := 13.0
const CAM_OFFSET := Vector3(0, 14.0, 11.5)
const RUN_TIME := 300.0
const MAX_ENEMY := 160
const MAX_LV := 5

var cam_off := CAM_OFFSET
var rng := RandomNumberGenerator.new()
var cam: Camera3D
var player: Node3D
var model: Node3D
var skel: Skeleton3D
var gun: Node3D
var bones := {}

# ---------- 스킬 정의 ----------
const MAINS := {
	"gun": {"name": "물총", "icon": "물", "col": "#4fa8e8", "partner": "bottle", "evo": "소방차 물대포",
		"evo_desc": "굵은 물대포가 모두 뚫고 지나가며 펑! 터져요",
		"desc": ["가장 가까운 귀신에게 물을 쏴요", "피해 +30%", "물줄기 +1갈래", "쏘는 속도 +30%", "물줄기 +1, 귀신 1마리 관통"]},
	"ddakji": {"name": "딱지", "icon": "딱", "col": "#ff7aa8", "partner": "notebook", "evo": "황금 딱지 폭풍",
		"evo_desc": "황금 딱지 8장이 크게 넘실대며 귀신을 날려요",
		"desc": ["딱지 2장이 빙글빙글 철수를 지켜요", "딱지 +1장", "피해 +40%", "딱지 +1장", "딱지 +1장, 더 크고 빠르게"]},
	"yoyo": {"name": "요요", "icon": "요", "col": "#2fc79a", "partner": "watch", "evo": "번개 요요",
		"evo_desc": "요요 4개가 맞힐 때마다 찌릿! 번개가 옆으로 튀어요",
		"desc": ["쭉 날아갔다 돌아오며 다 맞혀요", "요요 +1개", "피해 +40%", "더 멀리 날아가요", "요요 +1개"]},
	"rubber": {"name": "고무줄", "icon": "줄", "col": "#ff9a2f", "partner": "sneakers", "evo": "무지개 고무줄",
		"evo_desc": "무지개 고무줄이 두 겹으로 쫙쫙! 맞은 귀신은 느려져요",
		"desc": ["고무줄이 쫙! 퍼지며 주변을 튕겨내요", "범위 +20%", "피해 +40%", "더 자주 퍼져요", "범위 +20%, 더 세게 튕겨요"]},
}
const SUPPORTS := {
	"bottle": {"name": "생수병", "icon": "병", "col": "#58c6f2", "desc": "모든 공격 피해 +15%", "set": "gun"},
	"notebook": {"name": "공책", "icon": "책", "col": "#b48ef0", "desc": "공격 범위·크기 +15%", "set": "ddakji"},
	"watch": {"name": "계산기 시계", "icon": "시", "col": "#7cc95a", "desc": "공격 대기 시간 -8%", "set": "yoyo"},
	"sneakers": {"name": "운동화", "icon": "신", "col": "#f2c230", "desc": "이동 속도 +10%", "set": "rubber"},
	"pencil": {"name": "자석 필통", "icon": "필", "col": "#9b8cff", "desc": "딱지 줍는 거리 +40%", "set": ""},
	"nametag": {"name": "명찰", "icon": "명", "col": "#ff5c7a", "desc": "최대 하트 +1, 1칸 회복", "set": ""},
}
var mains := {"gun": 1}          # 이름 -> 레벨
var supports := {}               # 이름 -> 레벨
var evolved := {}                # 이름 -> true
var main_order: Array = ["gun"]
var support_order: Array = []

# ---------- 상태 ----------
var enemies: Array = []
var bullets: Array = []
var gems: Array = []
var parts: Array = []      # 물방울/별 조각
var rings: Array = []
var bolts: Array = []
var yoyos: Array = []
var ddakji_nodes: Array = []
var numbers: Array = []
var num_i := 0

var move_dir := Vector3.ZERO
var face_dir := Vector3(0, 0, 1)
var walk_phase := 0.0
var run_amt := 0.0
var recoil := 0.0
var cd := {"gun": 0.0, "yoyo": 0.5, "rubber": 1.0}
var orbit_angle := 0.0
var spawn_timer := 1.0
var elapsed := 0.0
var shake := 0.0
var hurt_timer := 0.0
var hitstop_left := 0.0
var hitstop_cool := 0.0
var combo := 0
var combo_timer := 0.0
var paused := false
var game_over := false
var kills := 0
var hp := 5
var level := 1
var xp := 0
var xp_need := 4

var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO

# 그리기
var mm := {}           # 이름 -> MultiMeshInstance3D
var mat_vc: StandardMaterial3D
var sh_lit: Shader
var sh_unlit: Shader
var mesh_cache := {}
var ddakji_mesh: ArrayMesh
var ddakji_gold_mesh: ArrayMesh
var yoyo_mesh: ArrayMesh
var yoyo_evo_mesh: ArrayMesh

# UI
var ui: CanvasLayer
var hud: Control
var hearts_label: Label
var timer_label: Label
var kill_label: Label
var xp_bar: ColorRect
var xp_bar_bg: ColorRect
var level_label: Label
var combo_label: Label
var slot_box: Control
var stick_base: Control
var stick_knob: Control
var card_panel: Control
var end_panel: Control
var font: Font
var sounds := {}
var players_audio: Array = []
var audio_i := 0

var auto_play := false
var shot_mode := ""
var perf_frames := 0

# =========================================================
func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	auto_play = args.has("--auto")
	for a in args:
		if a.begins_with("--shot="):
			shot_mode = a.substr(7)
		if a.begins_with("--frames="):
			perf_frames = int(a.substr(9))
	if args.has("--seed"):
		rng.seed = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/Jua-Regular.ttf")
	if OS.has_feature("web"):
		get_viewport().scaling_3d_scale = 0.8
	_make_materials()
	_make_world()
	_make_player()
	_make_multimeshes()
	_make_ui()
	_make_sounds()
	if shot_mode != "":
		_setup_shot()
	_prewarm()

func _prewarm() -> void:
	# 처음 쓰는 효과의 셰이더가 게임 도중 준비되느라 멈칫하지 않게, 땅 밑에서 한 번씩 그려 둬요
	_rubber_wave({"radius": 1.0, "dmg": 0.0, "knock": 0.0, "double": false}, 0.0)
	rings[0]["node"].visible = true
	rings[0]["node"].position = Vector3(0, -0.5, 0)
	rings[0]["done"] = true
	_bolt(Vector3(0, -0.5, 0), Vector3(1, -0.5, 0))
	_number(Vector3(0, -1, 0), 0, false)
	var y := MeshInstance3D.new()
	y.mesh = yoyo_mesh
	y.material_override = mat_vc
	y.position = Vector3(0, -0.5, 0)
	add_child(y)
	get_tree().create_timer(0.3).timeout.connect(y.queue_free)

# =========================================================
# 메시 만들기 도구: 조각들을 하나의 메시(정점 색)로 합쳐요
# =========================================================
func _sph(r: float, h := -1.0, seg := 14, rings_n := 7) -> Mesh:
	var key := "s%s_%s_%s" % [r, h, seg]
	if not mesh_cache.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0 if h < 0 else h
		s.radial_segments = seg
		s.rings = rings_n
		mesh_cache[key] = s
	return mesh_cache[key]

func _box(size: Vector3) -> Mesh:
	var key := "b%s" % size
	if not mesh_cache.has(key):
		var b := BoxMesh.new()
		b.size = size
		mesh_cache[key] = b
	return mesh_cache[key]

func _cyl(r: float, h: float, r2 := -1.0, seg := 16) -> Mesh:
	var key := "c%s_%s_%s_%s" % [r, h, r2, seg]
	if not mesh_cache.has(key):
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r if r2 < 0 else r2
		c.height = h
		c.radial_segments = seg
		c.rings = 1
		mesh_cache[key] = c
	return mesh_cache[key]

func T(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)

func merge(list: Array) -> ArrayMesh:
	# list: [[mesh, Transform3D, Color], ...]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in list:
		var m: Mesh = p[0]
		var t: Transform3D = p[1]
		var c: Color = p[2]
		var a := m.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var nb := t.basis.inverse().transposed()
		for i in v.size():
			verts.append(t * v[i])
			norms.append((nb * n[i]).normalized())
			cols.append(c)
		for i in ix:
			idx.append(base + i)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _make_materials() -> void:
	mat_vc = StandardMaterial3D.new()
	mat_vc.vertex_color_use_as_albedo = true
	mat_vc.vertex_color_is_srgb = true
	mat_vc.roughness = 0.85
	sh_lit = Shader.new()
	sh_lit.code = """
shader_type spatial;
render_mode specular_disabled;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){
  vec3 c = COLOR.rgb * cu.rgb;
  ALBEDO = mix(c, vec3(1.0), cu.a);
  EMISSION = vec3(cu.a * 0.6);
  ROUGHNESS = 0.85;
}
"""
	sh_unlit = Shader.new()
	sh_unlit.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ ALBEDO = cu.rgb; ALPHA = cu.a; }
"""

func _mm(name: String, mesh: Mesh, count: int, lit: bool) -> void:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_custom_data = true
	m.use_colors = true
	m.mesh = mesh
	m.instance_count = count
	m.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = m
	var sm := ShaderMaterial.new()
	sm.shader = sh_lit if lit else sh_unlit
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))
	add_child(mi)
	mm[name] = mi

# =========================================================
# 세계
# =========================================================
func _make_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#9fd8ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#fff1e0")
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.78
	sun.light_color = Color("#fff4dc")
	sun.shadow_enabled = false
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.position = cam_off
	cam.far = 80.0
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	# 흙 운동장: 작은 무늬 텍스처 한 장을 반복해요
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.08
	for y in 128:
		for x in 128:
			var v := nz.get_noise_2d(x, y) * 0.5 + 0.5
			var g := rng.randf()
			var c := Color(0.88, 0.75, 0.57).lerp(Color(0.78, 0.63, 0.45), v * 0.7) * (0.95 + g * 0.08)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var ground := PlaneMesh.new()
	ground.size = Vector2(70, 70)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tex : repeat_enable, filter_linear_mipmap;
varying vec2 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment(){
  vec3 c = texture(tex, wp * 0.09).rgb;
  float ex = wp.x/11.0; float ez = wp.y/8.0;
  float d = sqrt(ex*ex + ez*ez);
  float w = fwidth(d) * 1.2 + 0.006;
  float lines = max(1.0 - smoothstep(0.0, w, abs(d - 1.0)), 1.0 - smoothstep(0.0, w, abs(d - 0.86)));
  float out_g = smoothstep(14.0, 14.4, max(abs(wp.x), abs(wp.y)));
  c = mix(c, vec3(0.98,0.97,0.92), lines * 0.85);
  c = mix(c, vec3(0.45,0.70,0.36) * (c.r + 0.15), out_g);
  ALBEDO = c;
  ROUGHNESS = 1.0;
}
"""
	sm.shader = sh
	sm.set_shader_parameter("tex", tex)
	var gi := MeshInstance3D.new()
	gi.mesh = ground
	gi.material_override = sm
	add_child(gi)

	# 학교, 구령대, 골대, 철봉, 나무, 울타리를 메시 하나로
	var L: Array = []
	var S := Vector3(0, 0, -19)
	L.append([_box(Vector3(30, 7.5, 4)), T(S + Vector3(0, 3.75, 0)), Color("#f3e6c8")])
	L.append([_box(Vector3(30.6, 0.5, 4.6)), T(S + Vector3(0, 7.7, 0)), Color("#c0563f")])
	for fl in range(3):
		for i in range(12):
			var x := -13.2 + i * 2.4
			if absf(x) < 1.5:
				continue
			L.append([_box(Vector3(1.7, 1.3, 0.12)), T(S + Vector3(x, 1.5 + fl * 2.2, 2.02)), Color("#7fb7d9")])
			L.append([_box(Vector3(1.8, 0.12, 0.2)), T(S + Vector3(x, 0.82 + fl * 2.2, 2.05)), Color("#5f8f4e")])
	L.append([_box(Vector3(2.4, 2.6, 0.2)), T(S + Vector3(0, 1.3, 2.05)), Color("#6b4a32")])
	L.append([_cyl(0.9, 0.15), T(S + Vector3(0, 6.2, 2.1), Vector3(90, 0, 0)), Color("#ffffff")])
	L.append([_box(Vector3(6, 1.0, 3)), T(S + Vector3(0, 0.5, 3.3)), Color("#d9d2c3")])
	L.append([_box(Vector3(6.4, 0.18, 3.4)), T(S + Vector3(0, 1.05, 3.3)), Color("#a9a294")])
	for side in [-1.0, 1.0]:
		var gp := Vector3(side * 15.5, 0, 0)
		for dz in [-2.5, 2.5]:
			L.append([_cyl(0.07, 2.2, -1, 8), T(gp + Vector3(0, 1.1, dz)), Color.WHITE])
		L.append([_cyl(0.07, 5.0, -1, 8), T(gp + Vector3(0, 2.2, 0), Vector3(90, 0, 0)), Color.WHITE])
	for i in range(3):
		var x := 9.0 + i * 1.4
		var h := 1.2 + i * 0.25
		L.append([_cyl(0.05, h, -1, 8), T(Vector3(x, h / 2.0, -15.2)), Color("#d94f3d")])
		L.append([_cyl(0.05, h, -1, 8), T(Vector3(x + 1.2, h / 2.0, -15.2)), Color("#d94f3d")])
		L.append([_cyl(0.035, 1.2, -1, 8), T(Vector3(x + 0.6, h, -15.2), Vector3(0, 0, 90)), Color("#cccccc")])
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		var tp := Vector3(side * rng.randf_range(17.0, 19.5), 0, -14.0 + (i / 2) * 4.2 + rng.randf_range(-0.8, 0.8))
		var s := rng.randf_range(0.9, 1.3)
		L.append([_cyl(0.22, 1.6, 0.3, 8), T(tp + Vector3(0, 0.8, 0)), Color("#8a5a3b")])
		L.append([_sph(1.3, -1, 12, 6), T(tp + Vector3(0, 2.4 * s, 0), Vector3.ZERO, Vector3.ONE * s), Color("#5fae4e")])
		L.append([_sph(0.9, -1, 12, 6), T(tp + Vector3(0.6, 2.9 * s, 0.4), Vector3.ZERO, Vector3.ONE * s), Color("#74c25b")])
	for i in range(-14, 15):
		L.append([_cyl(0.06, 0.9, -1, 6), T(Vector3(i, 0.45, 15.0)), Color("#e8e2d0")])
		L.append([_cyl(0.06, 0.9, -1, 6), T(Vector3(-15.0, 0.45, i)), Color("#e8e2d0")])
		L.append([_cyl(0.06, 0.9, -1, 6), T(Vector3(15.0, 0.45, i)), Color("#e8e2d0")])
	L.append([_box(Vector3(30, 0.08, 0.08)), T(Vector3(0, 0.8, 15.0)), Color("#e8e2d0")])
	L.append([_box(Vector3(0.08, 0.08, 30)), T(Vector3(-15.0, 0.8, 0)), Color("#e8e2d0")])
	L.append([_box(Vector3(0.08, 0.08, 30)), T(Vector3(15.0, 0.8, 0)), Color("#e8e2d0")])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)

# =========================================================
# 귀신, 딱지, 요요 모양
# =========================================================
func _face_parts(L: Array, z: float, y: float, s := 1.0) -> void:
	for sx in [-1.0, 1.0]:
		L.append([_sph(0.07 * s, -1, 10, 5), T(Vector3(sx * 0.1 * s, y, z), Vector3.ZERO, Vector3(1, 1.2, 0.5)), Color("#3a2148")])
		L.append([_sph(0.025 * s, -1, 6, 3), T(Vector3(sx * 0.1 * s + 0.02, y + 0.03 * s, z + 0.035 * s)), Color.WHITE])
		L.append([_sph(0.05 * s, -1, 8, 4), T(Vector3(sx * 0.17 * s, y - 0.08 * s, z - 0.01), Vector3.ZERO, Vector3(1, 0.6, 0.3)), Color("#ff9db0")])
		L.append([_box(Vector3(0.09, 0.022, 0.02) * s), T(Vector3(sx * 0.1 * s, y + 0.11 * s, z + 0.01), Vector3(0, 0, -sx * 22.0)), Color("#3a2148")])
	L.append([_sph(0.035 * s, -1, 8, 4), T(Vector3(0, y - 0.1 * s, z), Vector3.ZERO, Vector3(1.3, 0.6, 0.4)), Color("#7a2f4a")])

func _enemy_mesh(kind: String) -> ArrayMesh:
	var L: Array = []
	if kind == "paper":
		var col := Color("#c9a8f0")
		L.append([_cyl(0.3, 0.46, -1, 18), T(Vector3(0, 0.45, 0)), col])
		L.append([_cyl(0.11, 0.02, -1, 12), T(Vector3(0, 0.685, 0)), Color("#8a6a4a")])
		L.append([_box(Vector3(0.36, 0.5, 0.02)), T(Vector3(0.28, 0.32, -0.12), Vector3(0, -40, -18)), Color("#e6d6fb")])
		_face_parts(L, 0.29, 0.47)
		for sx in [-1.0, 1.0]:
			L.append([_sph(0.08, -1, 8, 4), T(Vector3(sx * 0.33, 0.36, 0.08)), col.darkened(0.08)])
			L.append([_sph(0.08, -1, 8, 4), T(Vector3(sx * 0.13, 0.08, 0.0)), col.darkened(0.12)])
	else:
		var col := Color("#a9d4f5")
		L.append([_sph(0.3, 0.74, 16, 8), T(Vector3(0, 0.46, 0)), col])
		_face_parts(L, 0.27, 0.48, 0.95)
		L.append([_box(Vector3(0.18, 0.02, 0.02)), T(Vector3(-0.05, 0.78, 0.17), Vector3(0, 0, 30)), Color("#6e95b8")])
		for sx in [-1.0, 1.0]:
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.3, 0.38, 0.06)), col.darkened(0.1)])
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.12, 0.07, 0.0)), col.darkened(0.15)])
	return merge(L)

func _ddakji_mesh(c1: Color, c2: Color) -> ArrayMesh:
	var L: Array = []
	L.append([_box(Vector3(0.3, 0.05, 0.3)), T(Vector3.ZERO), c1])
	L.append([_box(Vector3(0.31, 0.055, 0.045)), T(Vector3.ZERO, Vector3(0, 45, 0)), c2])
	L.append([_box(Vector3(0.31, 0.055, 0.045)), T(Vector3.ZERO, Vector3(0, -45, 0)), c2])
	return merge(L)

func _yoyo_mesh(c: Color) -> ArrayMesh:
	var L: Array = []
	L.append([_cyl(0.17, 0.08, 0.13), T(Vector3(0, 0.06, 0)), c])
	L.append([_cyl(0.13, 0.08, 0.17), T(Vector3(0, -0.06, 0)), c])
	L.append([_cyl(0.05, 0.06), T(Vector3.ZERO), Color.WHITE])
	L.append([_cyl(0.08, 0.01), T(Vector3(0, 0.105, 0)), c.lightened(0.5)])
	return merge(L)

func _make_multimeshes() -> void:
	_mm("paper", _enemy_mesh("paper"), MAX_ENEMY, true)
	_mm("egg", _enemy_mesh("egg"), MAX_ENEMY, true)
	_mm("gem", _ddakji_mesh(Color.WHITE, Color(1, 1, 1).darkened(0.25)), 300, true)
	_mm("bullet", _sph(0.13, -1, 8, 4), 80, false)
	_mm("drop", _sph(1.0, -1, 6, 3), 260, false)
	_mm("star", _box(Vector3(0.12, 0.12, 0.02)), 120, false)
	# 동그란 그림자
	var q := PlaneMesh.new()
	q.size = Vector2(1, 1)
	_mm("shadow", q, MAX_ENEMY * 2 + 4, false)
	var sm: ShaderMaterial = mm["shadow"].material_override
	var shs := Shader.new()
	shs.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
void fragment(){ float d = length(UV - 0.5) * 2.0; ALBEDO = vec3(0.25,0.15,0.1); ALPHA = (1.0 - smoothstep(0.55, 1.0, d)) * 0.28; }
"""
	sm.shader = shs
	ddakji_mesh = _ddakji_mesh(Color("#ff7aa8"), Color("#ffd1e1"))
	ddakji_gold_mesh = _ddakji_mesh(Color("#ffc928"), Color("#fff3b0"))
	yoyo_mesh = _yoyo_mesh(Color("#2fc79a"))
	yoyo_evo_mesh = _yoyo_mesh(Color("#ffd23f"))

# =========================================================
# 철수
# =========================================================
func _make_player() -> void:
	player = Node3D.new()
	add_child(player)
	model = (load("res://models/chulsoo.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * 1.5
	player.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), skel.get_bone_global_rest(i).basis.get_rotation_quaternion()]
	var L: Array = []
	L.append([_box(Vector3(0.16, 0.13, 0.34)), T(Vector3(0, 0, 0.02)), Color("#4fa8e8")])
	L.append([_cyl(0.085, 0.24), T(Vector3(0, 0.13, -0.02), Vector3(90, 0, 0)), Color("#ffd23f")])
	L.append([_sph(0.085, -1, 10, 5), T(Vector3(0, 0.13, 0.1)), Color("#ffd23f")])
	L.append([_sph(0.085, -1, 10, 5), T(Vector3(0, 0.13, -0.14)), Color("#ffd23f")])
	L.append([_cyl(0.04, 0.12), T(Vector3(0, 0, 0.24), Vector3(90, 0, 0)), Color("#ff8a3d")])
	L.append([_box(Vector3(0.07, 0.14, 0.08)), T(Vector3(0, -0.11, -0.06)), Color("#ffd23f")])
	gun = MeshInstance3D.new()
	(gun as MeshInstance3D).mesh = merge(L)
	(gun as MeshInstance3D).material_override = mat_vc
	gun.scale = Vector3.ONE * 0.95
	player.add_child(gun)

func pose_bone(name: String, q_model: Quaternion) -> void:
	if not bones.has(name):
		return
	var b: Array = bones[name]
	var g: Quaternion = b[2]
	skel.set_bone_pose_rotation(b[0], b[1] * (g.inverse() * q_model * g))

func Q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))

func _animate_player(dt: float) -> void:
	run_amt = move_toward(run_amt, 1.0 if move_dir.length() > 0.1 else 0.0, dt * 6.0)
	walk_phase += dt * (13.0 * run_amt + 2.2 * (1.0 - run_amt))
	recoil = move_toward(recoil, 0.0, dt * 8.0)
	var s := sin(walk_phase)
	var c := cos(walk_phase)
	var sw := 38.0 * run_amt
	pose_bone("thighL", Q(Vector3.RIGHT, -sw * s))
	pose_bone("thighR", Q(Vector3.RIGHT, sw * s))
	pose_bone("shinL", Q(Vector3.RIGHT, 30.0 * run_amt * maxf(0.0, -c)))
	pose_bone("shinR", Q(Vector3.RIGHT, 30.0 * run_amt * maxf(0.0, c)))
	model.position.y = absf(s) * 0.07 * run_amt + sin(walk_phase * 0.5) * 0.008 * (1.0 - run_amt)
	model.rotation_degrees.x = 8.0 * run_amt
	pose_bone("spine", Q(Vector3.UP, 7.0 * s * run_amt))
	pose_bone("head", Q(Vector3.RIGHT, -4.0 * run_amt + recoil * 6.0) * Q(Vector3.FORWARD, 3.0 * s * run_amt))
	pose_bone("armL", Q(Vector3.RIGHT, -62.0 + recoil * 14.0) * Q(Vector3.BACK, 66.0) * Q(Vector3.UP, -18.0))
	pose_bone("foreL", Q(Vector3.UP, -30.0))
	pose_bone("armR", Q(Vector3.RIGHT, -55.0 + recoil * 10.0) * Q(Vector3.BACK, -70.0) * Q(Vector3.UP, 32.0))
	pose_bone("foreR", Q(Vector3.UP, 38.0))
	var hand_t := skel.get_bone_global_pose(bones["handL"][0])
	gun.global_position = skel.global_transform * hand_t.origin + model.global_transform.basis.orthonormalized() * Vector3(0.06, 0.02, 0.05)
	gun.rotation = Vector3(deg_to_rad(-recoil * 18.0), model.rotation.y, 0)
	gun.scale = Vector3.ONE * (1.25 if evolved.has("gun") else 0.95)

# =========================================================
# 스킬 수치
# =========================================================
func lv(id: String) -> int:
	return int(mains.get(id, 0)) + int(supports.get(id, 0))

func dmg_mult() -> float:
	return 1.0 + 0.15 * lv("bottle")
func area_mult() -> float:
	return 1.0 + 0.15 * lv("notebook")
func cd_mult() -> float:
	return 1.0 - 0.08 * lv("watch")
func move_speed() -> float:
	return 4.2 * (1.0 + 0.1 * lv("sneakers"))
func magnet() -> float:
	return 2.2 * (1.0 + 0.4 * lv("pencil"))
func max_hp() -> int:
	return 5 + lv("nametag")

func gun_stats() -> Dictionary:
	var l := lv("gun")
	if evolved.has("gun"):
		return {"rate": 3.0, "dmg": 24.0, "shots": 3, "pierce": 999, "size": 2.0, "splash": 1.5}
	return {"rate": 2.4 * (1.3 if l >= 4 else 1.0), "dmg": 10.0 * (1.3 if l >= 2 else 1.0),
		"shots": 1 + (1 if l >= 3 else 0) + (1 if l >= 5 else 0), "pierce": 1 if l >= 5 else 0, "size": 1.0, "splash": 0.0}

func ddakji_stats() -> Dictionary:
	var l := lv("ddakji")
	if evolved.has("ddakji"):
		return {"count": 8, "dmg": 18.0, "radius": 2.6, "speed": 4.2, "knock": 6.0}
	return {"count": [0, 2, 3, 3, 4, 5][l], "dmg": 8.0 * (1.4 if l >= 3 else 1.0), "radius": 1.7 * (1.2 if l >= 5 else 1.0),
		"speed": 3.2 * (1.3 if l >= 5 else 1.0), "knock": 3.0}

func yoyo_stats() -> Dictionary:
	var l := lv("yoyo")
	if evolved.has("yoyo"):
		return {"count": 4, "dmg": 26.0, "dist": 6.5, "cool": 1.3, "chain": 3}
	return {"count": 1 + (1 if l >= 2 else 0) + (1 if l >= 5 else 0), "dmg": 14.0 * (1.4 if l >= 3 else 1.0),
		"dist": 4.5 * (1.3 if l >= 4 else 1.0), "cool": 1.7, "chain": 0}

func rubber_stats() -> Dictionary:
	var l := lv("rubber")
	if evolved.has("rubber"):
		return {"cool": 1.4, "radius": 4.2, "dmg": 24.0, "knock": 8.0, "double": true}
	return {"cool": 3.0 * (0.72 if l >= 4 else 1.0), "radius": 2.6 * (1.2 if l >= 2 else 1.0) * (1.2 if l >= 5 else 1.0),
		"dmg": 12.0 * (1.4 if l >= 3 else 1.0), "knock": 7.0 if l >= 5 else 4.5, "double": false}

func evo_ready(id: String) -> bool:
	return mains.get(id, 0) >= MAX_LV and supports.has(MAINS[id]["partner"]) and not evolved.has(id)

# =========================================================
# 귀신
# =========================================================
func _make_enemy(kind: String, pos: Vector3) -> void:
	var t := elapsed / RUN_TIME
	var hpv := (22.0 if kind == "paper" else 12.0) * (1.0 + t * 2.2)
	enemies.append({"pos": pos, "vel": Vector3.ZERO, "rot": 0.0, "kind": kind, "hp": hpv, "flash": 0.0,
		"squash": 0.0, "phase": rng.randf() * TAU, "spawn": 0.0, "dead": -1.0, "slow": 0.0,
		"speed": (1.55 if kind == "paper" else 2.7) * (1.0 + t * 0.25), "radius": 0.45 if kind == "paper" else 0.4, "hits": {}})

func _spawn_logic(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer > 0.0:
		return
	var t := elapsed / RUN_TIME
	spawn_timer = lerpf(1.3, 0.35, clampf(t * 1.3, 0, 1))
	var count := 1 + int(t * 7.0)
	for i in count:
		if enemies.size() >= MAX_ENEMY - 4:
			return
		var a := rng.randf() * TAU
		var p := player.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(11.0, 13.0)
		p.x = clampf(p.x, -ARENA, ARENA)
		p.z = clampf(p.z, -ARENA, ARENA)
		if p.distance_to(player.position) < 6.0:
			p = player.position - (p - player.position).normalized() * 9.0
		_make_enemy("egg" if rng.randf() < clampf(0.15 + t * 0.6, 0, 0.5) else "paper", p)

func _update_enemies(dt: float) -> void:
	var alive: Array = []
	for e in enemies:
		if e["dead"] >= 0.0:
			e["dead"] += dt
			if e["dead"] <= 0.16:
				alive.append(e)
			continue
		alive.append(e)
		e["spawn"] = minf(1.0, e["spawn"] + dt * 3.0)
		var to_p: Vector3 = player.position - e["pos"]
		to_p.y = 0
		var dist := to_p.length()
		var sp: float = e["speed"] * (0.45 if e["slow"] > 0.0 else 1.0)
		e["slow"] -= dt
		var want := to_p / maxf(dist, 0.01) * sp
		e["vel"] = (e["vel"] as Vector3).lerp(want, dt * 4.0)
		e["pos"] += e["vel"] * dt
		e["pos"].x = clampf(e["pos"].x, -ARENA - 1, ARENA + 1)
		e["pos"].z = clampf(e["pos"].z, -ARENA - 1, ARENA + 1)
		if dist > 0.01:
			e["rot"] = lerp_angle(e["rot"], atan2(to_p.x, to_p.z), dt * 8.0)
		e["phase"] += dt * (7.0 if e["kind"] == "paper" else 10.0)
		e["squash"] = move_toward(e["squash"], 0.0, dt * 5.0)
		e["flash"] = maxf(0.0, e["flash"] - dt)
		if dist < e["radius"] + 0.3 and hurt_timer <= 0.0 and not game_over:
			_player_hurt(e["pos"])
	enemies = alive
	# 서로 밀어내기
	var n := enemies.size()
	for i in n:
		var a: Dictionary = enemies[i]
		for j in range(i + 1, mini(n, i + 10)):
			var b: Dictionary = enemies[j]
			var d: Vector3 = a["pos"] - b["pos"]
			d.y = 0
			var l := d.length()
			if l < 0.75 and l > 0.001:
				var push := d / l * (0.75 - l) * 0.5
				a["pos"] += push
				b["pos"] -= push

func _hit_enemy(e: Dictionary, dmg: float, dir: Vector3, knock := 5.0, quiet := false) -> void:
	if e["dead"] >= 0.0:
		return
	dmg *= dmg_mult()
	var crit := rng.randf() < 0.12
	if crit:
		dmg *= 2.0
	e["hp"] -= dmg
	e["flash"] = 0.08
	e["squash"] = 1.0
	dir.y = 0
	if dir.length() > 0.01:
		e["vel"] = dir.normalized() * knock
	var pos: Vector3 = e["pos"]
	_number(pos + Vector3(0, 1.3, 0), int(round(dmg)), crit)
	_burst(pos + Vector3(0, 0.55, 0), Color(0.7, 0.9, 1.0, 0.9), 3, 3.0)
	if not quiet:
		_play("hit", rng.randf_range(0.9, 1.15) + (0.25 if crit else 0.0), -5.0)
	if crit:
		shake = maxf(shake, 0.12)
	if e["hp"] <= 0.0:
		_kill_enemy(e)

func _kill_enemy(e: Dictionary) -> void:
	e["dead"] = 0.0
	kills += 1
	combo += 1
	combo_timer = 1.6
	var pos: Vector3 = e["pos"]
	var col := Color("#c9a8f0") if e["kind"] == "paper" else Color("#a9d4f5")
	_burst(pos + Vector3(0, 0.6, 0), col, 7, 4.5)
	_burst(pos + Vector3(0, 0.6, 0), Color("#fff27a"), 4, 5.0, true)
	gems.append({"pos": pos + Vector3(0, 0.25, 0), "vel": Vector3(rng.randf_range(-1.5, 1.5), 3.5, rng.randf_range(-1.5, 1.5)),
		"pull": false, "t": 0.0, "col": [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#9b8cff")][rng.randi() % 4]})
	_play("pop", 1.0 + minf(combo, 12) * 0.04, -3.0)
	if hitstop_cool <= 0.0:
		hitstop(0.035)
		hitstop_cool = 0.15
	shake = maxf(shake, 0.12)

func _nearest_enemy(range_v: float) -> Dictionary:
	var best := {}
	var bd := range_v
	for e in enemies:
		if e["dead"] >= 0.0:
			continue
		var d: float = (e["pos"] as Vector3).distance_to(player.position)
		if d < bd:
			bd = d
			best = e
	return best

# =========================================================
# 무기들
# =========================================================
func _weapons(dt: float) -> void:
	# 물총
	var gs := gun_stats()
	cd["gun"] -= dt
	var target := _nearest_enemy(8.5)
	if not target.is_empty():
		var to: Vector3 = target["pos"] - player.position
		to.y = 0
		face_dir = to.normalized()
		if cd["gun"] <= 0.0:
			cd["gun"] = 1.0 / gs["rate"] * cd_mult()
			for i in int(gs["shots"]):
				var ang: float = (i - (gs["shots"] - 1) / 2.0) * (10.0 if evolved.has("gun") else 12.0)
				var dir := face_dir.rotated(Vector3.UP, deg_to_rad(ang))
				var start := gun.global_position + dir * 0.35
				start.y = 0.6
				bullets.append({"pos": start, "dir": dir, "life": 0.85, "pierce": gs["pierce"], "hit": [], "trail": 0.0,
					"dmg": gs["dmg"], "size": gs["size"] * area_mult(), "splash": gs["splash"]})
			recoil = 1.0
			_play("shoot" if not evolved.has("gun") else "blast", rng.randf_range(0.95, 1.1), -9.0)
	_update_bullets(dt)
	# 딱지 (빙글빙글)
	if mains.has("ddakji"):
		var ds := ddakji_stats()
		var cnt := int(ds["count"])
		orbit_angle += dt * ds["speed"]
		while ddakji_nodes.size() < cnt:
			var mi := MeshInstance3D.new()
			mi.material_override = mat_vc
			add_child(mi)
			ddakji_nodes.append(mi)
		var r: float = ds["radius"] * area_mult()
		if evolved.has("ddakji"):
			r += sin(elapsed * 2.5) * 0.7
		for i in ddakji_nodes.size():
			var mi: MeshInstance3D = ddakji_nodes[i]
			mi.visible = i < cnt
			if i >= cnt:
				continue
			mi.mesh = ddakji_gold_mesh if evolved.has("ddakji") else ddakji_mesh
			var a := orbit_angle + TAU * i / cnt
			var p := player.position + Vector3(cos(a) * r, 0.55, sin(a) * r)
			mi.position = p
			mi.rotation = Vector3(0.5, -a * 2.0, 0.3)
			mi.scale = Vector3.ONE * (1.6 if evolved.has("ddakji") else 1.15) * area_mult()
			for e in enemies:
				if e["dead"] >= 0.0:
					continue
				if Vector2(e["pos"].x - p.x, e["pos"].z - p.z).length() < e["radius"] + 0.25 * area_mult():
					var last: float = e["hits"].get("dd", -9.0)
					if elapsed - last > 0.45:
						e["hits"]["dd"] = elapsed
						_hit_enemy(e, ds["dmg"], e["pos"] - player.position, ds["knock"])
	# 요요
	if mains.has("yoyo"):
		var ys := yoyo_stats()
		cd["yoyo"] -= dt
		if cd["yoyo"] <= 0.0:
			cd["yoyo"] = ys["cool"] * cd_mult()
			var base_dir := face_dir
			var tg := _nearest_enemy(9.0)
			if not tg.is_empty():
				base_dir = ((tg["pos"] as Vector3) - player.position).normalized()
			for i in int(ys["count"]):
				var dir := base_dir.rotated(Vector3.UP, TAU * i / ys["count"])
				var mi := MeshInstance3D.new()
				mi.mesh = yoyo_evo_mesh if evolved.has("yoyo") else yoyo_mesh
				mi.material_override = mat_vc
				add_child(mi)
				yoyos.append({"node": mi, "dir": dir, "t": 0.0, "dist": ys["dist"] * area_mult(), "dmg": ys["dmg"], "chain": ys["chain"], "hit": {}})
			_play("yoyo", 1.0, -8.0)
		for y in yoyos.duplicate():
			y["t"] += dt / 0.9
			var k: float = sin(minf(y["t"], 1.0) * PI)
			var p: Vector3 = player.position + y["dir"] * y["dist"] * k + Vector3(0, 0.6, 0)
			var mi: MeshInstance3D = y["node"]
			mi.position = p
			mi.rotation = Vector3(PI / 2, atan2(y["dir"].x, y["dir"].z), y["t"] * 30.0)
			mi.scale = Vector3.ONE * 1.4 * area_mult()
			for e in enemies:
				if e["dead"] >= 0.0:
					continue
				if Vector2(e["pos"].x - p.x, e["pos"].z - p.z).length() < e["radius"] + 0.22 * area_mult():
					var last: float = y["hit"].get(e, -9.0)
					if y["t"] - last > 0.5:
						y["hit"][e] = y["t"]
						_hit_enemy(e, y["dmg"], y["dir"], 4.0)
						if y["chain"] > 0:
							_chain(e, int(y["chain"]), y["dmg"] * 0.6)
			if y["t"] >= 1.0:
				mi.queue_free()
				yoyos.erase(y)
	# 고무줄
	if mains.has("rubber"):
		var rs := rubber_stats()
		cd["rubber"] -= dt
		if cd["rubber"] <= 0.0:
			cd["rubber"] = rs["cool"] * cd_mult()
			_rubber_wave(rs, 0.0)
			if rs["double"]:
				_rubber_wave(rs, 0.25)
	for r in rings.duplicate():
		r["t"] += dt
		if r["t"] < 0.0:
			continue
		var k: float = r["t"] / 0.35
		var rad: float = r["radius"] * minf(k, 1.0)
		var mi: MeshInstance3D = r["node"]
		var m: StandardMaterial3D = mi.material_override
		mi.visible = true
		mi.position = player.position + Vector3(0, 0.35, 0)
		mi.scale = Vector3(rad, 1.0, rad)
		var a := 0.9 * (1.0 - maxf(0.0, k - 0.6) / 0.6)
		if r["rainbow"]:
			m.albedo_color = Color.from_hsv(fmod(elapsed * 1.5, 1.0), 0.6, 1.0, a)
		else:
			m.albedo_color.a = a
		if not r["done"]:
			for e in enemies:
				if e["dead"] >= 0.0 or r["hit"].has(e):
					continue
				var d: Vector3 = e["pos"] - player.position
				d.y = 0
				if d.length() < rad + e["radius"]:
					r["hit"][e] = true
					_hit_enemy(e, r["dmg"], d, r["knock"], true)
					if r["rainbow"]:
						e["slow"] = 1.5
			if k >= 1.0:
				r["done"] = true
		if k >= 1.6:
			mi.queue_free()
			rings.erase(r)

func _rubber_wave(rs: Dictionary, delay: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color("#ff9a2f")
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	rings.append({"node": mi, "t": -delay, "radius": rs["radius"] * area_mult(), "dmg": rs["dmg"], "knock": rs["knock"],
		"hit": {}, "done": false, "rainbow": rs["double"]})
	_play("rubber", 1.0 + (0.2 if delay > 0 else 0.0), -6.0)
	shake = maxf(shake, 0.1)

func _chain(from: Dictionary, n: int, dmg: float) -> void:
	var cur := from
	var used := {from: true}
	for i in n:
		var best := {}
		var bd := 3.2
		for e in enemies:
			if e["dead"] >= 0.0 or used.has(e):
				continue
			var d: float = (e["pos"] as Vector3).distance_to(cur["pos"])
			if d < bd:
				bd = d
				best = e
		if best.is_empty():
			return
		used[best] = true
		_bolt(cur["pos"] + Vector3(0, 0.6, 0), best["pos"] + Vector3(0, 0.6, 0))
		_hit_enemy(best, dmg, best["pos"] - cur["pos"], 2.0, true)
		cur = best
	_play("zap", rng.randf_range(0.9, 1.2), -9.0)

func _bolt(a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.05:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _box(Vector3(0.07, 0.07, 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#fff36b")
	mi.material_override = m
	add_child(mi)
	mi.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, a.distance_to(b))
	bolts.append({"node": mi, "t": 0.0})

func _update_bullets(dt: float) -> void:
	for b in bullets.duplicate():
		b["pos"] += b["dir"] * 15.0 * dt
		b["life"] -= dt
		b["trail"] -= dt
		if b["trail"] <= 0.0:
			b["trail"] = 0.06
			_part("drop", b["pos"], -b["dir"] + Vector3(0, 1, 0), Color(0.7, 0.9, 1.0, 0.7), 0.05 * b["size"], 0.25)
		var done: bool = b["life"] <= 0.0
		for e in enemies:
			if e["dead"] >= 0.0 or b["hit"].has(e):
				continue
			if Vector2(e["pos"].x - b["pos"].x, e["pos"].z - b["pos"].z).length() < e["radius"] + 0.12 * b["size"]:
				b["hit"].append(e)
				_hit_enemy(e, b["dmg"], b["dir"], 5.5)
				if b["splash"] > 0.0:
					_splash(e["pos"], b["splash"] * area_mult(), e, b["dmg"] * 0.5)
				if b["pierce"] <= 0:
					done = true
					break
				b["pierce"] -= 1
		if done:
			_burst(b["pos"], Color(0.65, 0.88, 1.0, 0.85), 4, 2.5)
			bullets.erase(b)

func _splash(pos: Vector3, r: float, skip: Dictionary, dmg: float) -> void:
	_burst(pos + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1, 0.8), 8, 4.0)
	for e in enemies:
		if e == skip or e["dead"] >= 0.0:
			continue
		var d: Vector3 = e["pos"] - pos
		if d.length() < r:
			_hit_enemy(e, dmg, d, 3.0, true)

# =========================================================
# 딱지(경험치)
# =========================================================
var gem_sound_t := 0.0
func _update_gems(dt: float) -> void:
	gem_sound_t -= dt
	var keep: Array = []
	var got := 0
	for g in gems:
		g["t"] += dt
		var d: Vector3 = player.position + Vector3(0, 0.5, 0) - g["pos"]
		if not g["pull"] and g["t"] > 0.35 and d.length() < magnet():
			g["pull"] = true
		if g["pull"]:
			g["vel"] = (g["vel"] as Vector3).lerp(d.normalized() * 14.0, dt * 9.0)
		else:
			g["vel"].y -= 12.0 * dt
		g["pos"] += g["vel"] * dt
		if g["pos"].y < 0.08 and not g["pull"]:
			g["pos"].y = 0.08
			g["vel"] = Vector3(g["vel"].x * 0.5, absf(g["vel"].y) * 0.3, g["vel"].z * 0.5)
		if g["pull"] and d.length() < 0.4:
			got += 1
		else:
			keep.append(g)
	while keep.size() > 290:
		keep.pop_front()
		got += 1
	gems = keep
	if got > 0:
		_gain_xp(got)

func _gain_xp(v: int) -> void:
	xp += v
	if gem_sound_t <= 0.0:
		gem_sound_t = 0.05
		_play("gem", 1.2 + minf(xp, 20) * 0.02, -12.0)
	if xp >= xp_need and not paused:
		xp -= xp_need
		level += 1
		xp_need = 3 + level * 2 + int(level * level * 0.12)
		_level_up()
	_refresh_ui()

# =========================================================
# 효과 (MultiMesh 조각들)
# =========================================================
func hitstop(d: float) -> void:
	hitstop_left = maxf(hitstop_left, d)

func _part(kind: String, pos: Vector3, vel: Vector3, col: Color, size: float, life: float, spin := 0.0) -> void:
	if parts.size() > 360:
		parts.pop_front()
	parts.append({"kind": kind, "pos": pos, "vel": vel, "col": col, "size": size, "life": life, "t": 0.0, "spin": spin, "rot": 0.0})

func _burst(pos: Vector3, col: Color, count: int, spd: float, stars := false) -> void:
	for i in count:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.4), rng.randf_range(-1, 1)).normalized() * spd * rng.randf_range(0.5, 1.0)
		if stars:
			_part("star", pos, v, col, 1.0, 0.45, rng.randf_range(-12, 12))
		else:
			_part("drop", pos, v, col, rng.randf_range(0.05, 0.09), 0.35)

func _number(pos: Vector3, v: int, crit: bool) -> void:
	if numbers.size() < 12:
		var l := Label3D.new()
		l.font = font
		l.outline_size = 14
		l.outline_modulate = Color("#3a2148")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.009
		add_child(l)
		numbers.append({"node": l, "t": 9.0})
	var n: Dictionary = numbers[num_i]
	num_i = (num_i + 1) % 12
	var l: Label3D = n["node"]
	l.text = str(v) + ("!" if crit else "")
	l.font_size = 64 if crit else 44
	l.modulate = Color("#ffdf3d") if crit else Color.WHITE
	l.position = pos + Vector3(rng.randf_range(-0.25, 0.25), 0, 0)
	l.visible = true
	n["t"] = 0.0

func _update_fx(dt: float) -> void:
	var keep: Array = []
	for p in parts:
		p["t"] += dt
		if p["t"] >= p["life"]:
			continue
		p["vel"].y -= 9.0 * dt
		p["pos"] += p["vel"] * dt
		p["rot"] += p["spin"] * dt
		keep.append(p)
	parts = keep
	for n in numbers:
		if n["t"] > 0.6:
			continue
		n["t"] += dt
		var l: Label3D = n["node"]
		var k: float = n["t"] / 0.6
		l.position.y += dt * 2.0 * (1.0 - k)
		l.scale = Vector3.ONE * (1.0 + sin(minf(k * 4.0, 1.0) * PI) * 0.4)
		l.modulate.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
		if k >= 1.0:
			l.visible = false
	for b in bolts.duplicate():
		b["t"] += dt
		(b["node"] as Node3D).scale.x = maxf(0.01, 1.0 - b["t"] / 0.15)
		if b["t"] > 0.15:
			b["node"].queue_free()
			bolts.erase(b)

func _sync_draw() -> void:
	# 귀신
	var counts := {"paper": 0, "egg": 0}
	var sh: MultiMesh = mm["shadow"].multimesh
	var shn := 0
	sh.set_instance_transform(shn, Transform3D(Basis(), player.position + Vector3(0, 0.02, 0)))
	sh.set_instance_custom_data(shn, Color(1, 1, 1, 1))
	shn += 1
	for e in enemies:
		var kind: String = e["kind"]
		var m: MultiMesh = mm[kind].multimesh
		var i: int = counts[kind]
		counts[kind] = i + 1
		var hop := absf(sin(e["phase"]))
		var sq: float = e["squash"]
		var spn: float = e["spawn"]
		var pop := spn * (1.0 + sin(spn * PI) * 0.35)
		var scl := Vector3(1.0 + sq * 0.45 + (1.0 - hop) * 0.05, 1.0 - sq * 0.4 - (1.0 - hop) * 0.06, 1.0 + sq * 0.45) * pop * 1.25
		var fl: float = minf(1.0, e["flash"] / 0.05)
		if e["dead"] >= 0.0:
			var k: float = e["dead"] / 0.16
			scl = Vector3(1.0 + k * 0.7, 1.0 - k * 0.85, 1.0 + k * 0.7) * 1.25
			fl = 1.0
		var tr := Transform3D(Basis(Vector3.UP, e["rot"]).scaled(scl), e["pos"] + Vector3(0, hop * 0.12, 0))
		m.set_instance_transform(i, tr)
		m.set_instance_color(i, Color.WHITE)
		m.set_instance_custom_data(i, Color(1, 1, 1, fl))
		sh.set_instance_transform(shn, Transform3D(Basis().scaled(Vector3(0.95, 1, 0.95)), e["pos"] + Vector3(0, 0.015, 0)))
		shn += 1
	mm["paper"].multimesh.visible_instance_count = counts["paper"]
	mm["egg"].multimesh.visible_instance_count = counts["egg"]
	sh.visible_instance_count = shn
	# 딱지
	var gm: MultiMesh = mm["gem"].multimesh
	for i in gems.size():
		var g: Dictionary = gems[i]
		gm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, elapsed * 3.0 + i).scaled(Vector3.ONE * 0.85), g["pos"]))
		var c: Color = g["col"]
		gm.set_instance_color(i, Color.WHITE)
		gm.set_instance_custom_data(i, Color(c.r, c.g, c.b, 0.0))
	gm.visible_instance_count = gems.size()
	# 물방울 총알
	var bm: MultiMesh = mm["bullet"].multimesh
	var bn := mini(bullets.size(), 80)
	for i in bn:
		var b: Dictionary = bullets[i]
		var basis := Basis.looking_at(b["dir"], Vector3.UP).scaled(Vector3(0.85, 0.85, 1.7) * b["size"])
		bm.set_instance_transform(i, Transform3D(basis, b["pos"]))
		bm.set_instance_custom_data(i, Color(0.55, 0.86, 1.0, 0.92) if b["splash"] == 0.0 else Color(0.35, 0.7, 1.0, 0.95))
	bm.visible_instance_count = bn
	# 조각
	var dm: MultiMesh = mm["drop"].multimesh
	var stm: MultiMesh = mm["star"].multimesh
	var dn := 0
	var sn := 0
	for p in parts:
		var k: float = 1.0 - p["t"] / p["life"]
		if p["kind"] == "star":
			if sn >= 120:
				continue
			stm.set_instance_transform(sn, Transform3D(Basis(Vector3.BACK, p["rot"] + 0.785).scaled(Vector3.ONE * k * 1.3), p["pos"]))
			stm.set_instance_custom_data(sn, p["col"])
			sn += 1
		else:
			if dn >= 260:
				continue
			dm.set_instance_transform(dn, Transform3D(Basis().scaled(Vector3.ONE * p["size"] * k), p["pos"]))
			dm.set_instance_custom_data(dn, p["col"])
			dn += 1
	dm.visible_instance_count = dn
	stm.visible_instance_count = sn

func _player_hurt(from: Vector3) -> void:
	hp -= 1
	hurt_timer = 1.1
	shake = 0.35
	hitstop(0.08)
	_play("hurt", 1.0, -3.0)
	Input.vibrate_handheld(120)
	var away := player.position - from
	away.y = 0
	player.position += away.normalized() * 0.6
	for e in enemies:
		var d: Vector3 = e["pos"] - player.position
		if d.length() < 2.5:
			e["vel"] = d.normalized() * 7.0
	_refresh_ui()
	if hp <= 0:
		_end_game(false)

# =========================================================
# 메인 루프
# =========================================================
var shot_frames := 0
var prof := [0,0,0,0,0,0]
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if shot_mode != "":
		shot_frames += 1
		if shot_mode == "hero":
			cam.look_at(player.position + Vector3(0, 0.6, 0.6), Vector3.UP)
		if shot_frames == 110 and perf_frames == 0:
			get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % shot_mode)
			get_tree().quit()
	if perf_frames > 0 and Engine.get_process_frames() % 60 == 0:
		print("P f=%d t=%.1f fps=%d draws=%d enemies=%d parts=%d" % [Engine.get_process_frames(), elapsed, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), enemies.size(), parts.size()])
		if Engine.get_process_frames() >= perf_frames:
			get_tree().quit()
	hitstop_cool -= dt
	if hitstop_left > 0.0:
		hitstop_left -= dt
		_update_camera(dt)
		return
	if paused or game_over:
		_update_camera(dt)
		_update_fx(dt)
		_sync_draw()
		_update_hud()
		return
	elapsed += dt
	if elapsed >= RUN_TIME:
		_end_game(true)
	_read_input()
	if auto_play:
		_auto_input(dt)
	player.position += move_dir * move_speed() * dt
	player.position.x = clampf(player.position.x, -ARENA, ARENA)
	player.position.z = clampf(player.position.z, -ARENA, ARENA)
	if _nearest_enemy(8.5).is_empty() and move_dir.length() > 0.1:
		face_dir = move_dir.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(face_dir.x, face_dir.z), dt * 14.0)
	hurt_timer -= dt
	model.visible = hurt_timer <= 0.0 or fmod(hurt_timer, 0.16) > 0.08
	var t0 := Time.get_ticks_usec()
	_spawn_logic(dt)
	_update_enemies(dt)
	var t1 := Time.get_ticks_usec()
	_weapons(dt)
	var t2 := Time.get_ticks_usec()
	_update_gems(dt)
	_update_fx(dt)
	var t3 := Time.get_ticks_usec()
	_animate_player(dt)
	var t4 := Time.get_ticks_usec()
	_sync_draw()
	var t5 := Time.get_ticks_usec()
	prof[0] += t1 - t0; prof[1] += t2 - t1; prof[2] += t3 - t2; prof[3] += t4 - t3; prof[4] += t5 - t4; prof[5] += 1
	if prof[5] >= 300:
		if perf_frames > 0: print("PROF enemies=%d en=%d weap=%d gems_fx=%d anim=%d draw=%d (us/frame)" % [enemies.size(), prof[0]/300, prof[1]/300, prof[2]/300, prof[3]/300, prof[4]/300])
		prof = [0,0,0,0,0,0]
	combo_timer -= dt
	if combo_timer <= 0.0:
		combo = 0
	_update_camera(dt)
	_update_hud()
	if auto_play and int(elapsed / 10.0) != int((elapsed - dt) / 10.0):
		print("T%d kills=%d lv=%d hp=%d enemies=%d gems=%d parts=%d mains=%s sup=%s evo=%s" % [int(elapsed), kills, level, hp, enemies.size(), gems.size(), parts.size(), mains, supports, evolved.keys()])

func _update_camera(dt: float) -> void:
	cam.position = cam.position.lerp(player.position + cam_off, minf(1.0, dt * 6.0))
	shake = move_toward(shake, 0.0, dt * 1.2)
	var s := shake * shake * 2.2
	cam.h_offset = rng.randf_range(-s, s)
	cam.v_offset = rng.randf_range(-s, s)

func _read_input() -> void:
	var k := Vector2(
		Input.get_axis("ui_left", "ui_right") + (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0),
		Input.get_axis("ui_up", "ui_down") + (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0))
	var v := stick_vec if stick_vec.length() > 0.05 else k
	if v.length() > 1.0:
		v = v.normalized()
	move_dir = Vector3(v.x, 0, v.y)

var auto_t := 0.0
var auto_dir := Vector2.ZERO
func _auto_input(dt: float) -> void:
	auto_t -= dt
	if auto_t <= 0.0:
		auto_t = rng.randf_range(0.5, 1.5)
		auto_dir = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0)
		if player.position.length() > 9.0:
			auto_dir = Vector2(-player.position.x, -player.position.z).normalized()
	# 가까운 귀신은 피해요
	var push := Vector3.ZERO
	for e in enemies:
		var d: Vector3 = player.position - e["pos"]
		d.y = 0
		var l := d.length()
		if l < 3.0 and l > 0.01:
			push += d / l * (3.0 - l)
	if push.length() > 0.5:
		var v := (push.normalized() + Vector3(-player.position.x, 0, -player.position.z) * 0.04).normalized()
		auto_dir = Vector2(v.x, v.z)
	move_dir = Vector3(auto_dir.x, 0, auto_dir.y)

func _input(event: InputEvent) -> void:
	if paused or game_over:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and stick_index == -1:
			stick_index = t.index
			stick_origin = t.position
			stick_vec = Vector2.ZERO
			stick_base.visible = true
			stick_base.position = t.position - stick_base.size / 2.0
			stick_knob.position = stick_base.size / 2.0 - stick_knob.size / 2.0
		elif not t.pressed and t.index == stick_index:
			stick_index = -1
			stick_vec = Vector2.ZERO
			stick_base.visible = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == stick_index:
			var off := d.position - stick_origin
			var r := 90.0
			if off.length() > r:
				stick_origin += off - off.normalized() * r
				stick_base.position = stick_origin - stick_base.size / 2.0
				off = off.normalized() * r
			stick_vec = off / r
			stick_knob.position = stick_base.size / 2.0 - stick_knob.size / 2.0 + off

# =========================================================
# UI
# =========================================================
func _label(text: String, size: int, col := Color.WHITE, parent: Node = null, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#3a2148"))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui).add_child(l)
	return l

func _round_panel(col: Color, radius := 28, border := Color("#3a2148"), bw := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 6)
	return s

func _badge(parent: Control, icon: String, col: Color, size: float, pos: Vector2, gold := false) -> Panel:
	var b := Panel.new()
	b.add_theme_stylebox_override("panel", _round_panel(col, int(size * 0.25), Color("#ffd23f") if gold else Color("#3a2148"), 7 if gold else 4))
	b.position = pos
	b.size = Vector2(size, size)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	var l := _label(icon, int(size * 0.55), Color.WHITE, b, 8)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return b

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.color = Color(0.23, 0.13, 0.28, 0.6)
	xp_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	xp_bar_bg.offset_bottom = 20
	xp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(xp_bar_bg)
	xp_bar = ColorRect.new()
	xp_bar.color = Color("#6ee0b0")
	xp_bar.size = Vector2(0, 20)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar_bg.add_child(xp_bar)
	level_label = _label("Lv.1", 30, Color.WHITE, hud)
	level_label.position = Vector2(24, 26)
	timer_label = _label("5:00", 48, Color.WHITE, hud)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.offset_left = -120
	timer_label.offset_right = 120
	timer_label.offset_top = 24
	hearts_label = _label("", 40, Color("#ff5c7a"), hud)
	hearts_label.position = Vector2(24, 64)
	kill_label = _label("귀신 0", 34, Color.WHITE, hud)
	kill_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.offset_left = -260
	kill_label.offset_right = -24
	kill_label.offset_top = 28
	combo_label = _label("", 54, Color("#ffdf3d"), hud)
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.offset_left = -200
	combo_label.offset_right = 200
	combo_label.offset_top = 200
	combo_label.pivot_offset = Vector2(200, 30)
	slot_box = Control.new()
	slot_box.position = Vector2(20, 118)
	slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(slot_box)
	stick_base = Panel.new()
	stick_base.size = Vector2(200, 200)
	stick_base.add_theme_stylebox_override("panel", _round_panel(Color(1, 1, 1, 0.22), 100, Color(1, 1, 1, 0.55), 5))
	stick_base.visible = false
	stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stick_base)
	stick_knob = Panel.new()
	stick_knob.size = Vector2(90, 90)
	stick_knob.add_theme_stylebox_override("panel", _round_panel(Color(1, 1, 1, 0.85), 45, Color("#4fa8e8"), 6))
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.add_child(stick_knob)
	_refresh_ui()
	_refresh_slots()

func _refresh_ui() -> void:
	var h := ""
	for i in max_hp():
		h += "♥" if i < hp else "♡"
	hearts_label.text = h
	level_label.text = "Lv.%d" % level

func _refresh_slots() -> void:
	for c in slot_box.get_children():
		c.queue_free()
	var x := 0.0
	for id in main_order:
		var d: Dictionary = MAINS[id]
		var b := _badge(slot_box, d["icon"], Color(d["col"]), 62, Vector2(x, 0), evolved.has(id))
		var lvl := _label("★" if evolved.has(id) else str(mains[id]), 24, Color("#ffdf3d") if evolved.has(id) else Color.WHITE, b, 7)
		lvl.position = Vector2(42, 38)
		if evo_ready(id):
			b.set_meta("ready", true)
		x += 70
	x = 0.0
	for id in support_order:
		var d: Dictionary = SUPPORTS[id]
		var b := _badge(slot_box, d["icon"], Color(d["col"]), 46, Vector2(x, 72))
		var lvl := _label(str(supports[id]), 20, Color.WHITE, b, 6)
		lvl.position = Vector2(31, 24)
		x += 52

func _update_hud() -> void:
	var left := maxf(0.0, RUN_TIME - elapsed)
	timer_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	xp_bar.size.x = xp_bar_bg.size.x * float(xp) / float(xp_need)
	kill_label.text = "귀신 %d" % kills
	for c in slot_box.get_children():
		if c.has_meta("ready"):
			(c as Control).modulate = Color(1, 1, 1).lerp(Color(1.6, 1.4, 0.6), 0.5 + 0.5 * sin(elapsed * 8.0))
	if combo >= 5:
		combo_label.text = "%d 콤보!" % combo
		combo_label.modulate.a = minf(1.0, clampf(combo_timer / 1.6, 0, 1) * 3.0)
		combo_label.scale = Vector2.ONE * (1.0 + maxf(0.0, combo_timer - 1.45) * 3.0)
	else:
		combo_label.text = ""

# ---------- 레벨업 카드 ----------
func _card_pool() -> Array:
	var pool: Array = []
	for id in MAINS:
		if evo_ready(id):
			pool.append({"type": "evo", "id": id})
	if pool.size() > 0:
		return pool.slice(0, 3)    # 진화가 준비되면 진화 카드가 꼭 나와요
	var opts: Array = []
	for id in MAINS:
		if evolved.has(id):
			continue
		if mains.has(id):
			if mains[id] < MAX_LV:
				opts.append({"type": "main", "id": id, "w": 3.0})
		elif main_order.size() < 4:
			opts.append({"type": "main", "id": id, "w": 2.0})
	for id in SUPPORTS:
		if supports.has(id):
			if supports[id] < MAX_LV:
				opts.append({"type": "sup", "id": id, "w": 1.5})
		elif support_order.size() < 4:
			# 짝꿍 메인이 있으면 더 잘 나와요
			var w := 3.0 if SUPPORTS[id]["set"] != "" and mains.has(SUPPORTS[id]["set"]) else 1.2
			opts.append({"type": "sup", "id": id, "w": w})
	var out: Array = []
	while out.size() < 3 and opts.size() > 0:
		var tot := 0.0
		for o in opts:
			tot += o["w"]
		var r := rng.randf() * tot
		var chosen: Dictionary = opts[opts.size() - 1]
		for o in opts:
			r -= o["w"]
			if r <= 0.0:
				chosen = o
				break
		out.append(chosen)
		opts.erase(chosen)
	if out.size() < 3:
		out.append({"type": "heal", "id": "heal"})
	return out

func _level_up() -> void:
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	stick_base.visible = false
	var pick := _card_pool()
	var is_evo: bool = pick[0]["type"] == "evo"
	_play("evo" if is_evo else "level", 1.0, -2.0)
	if auto_play:
		_apply_card(pick[0] if is_evo else pick[rng.randi() % pick.size()])
		return
	card_panel = Control.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(card_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	var title := _label("세트 완성! 진화!" if is_evo else "레벨 업!  하나 골라요", 58, Color("#ffdf3d"), card_panel)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_left = -340
	title.offset_right = 340
	title.offset_top = 200
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -300
	vb.offset_right = 300
	vb.offset_top = -330
	vb.offset_bottom = 450
	vb.add_theme_constant_override("separation", 24)
	card_panel.add_child(vb)
	for i in pick.size():
		var b := _make_card(pick[i])
		vb.add_child(b)
		b.scale = Vector2(0.6, 0.6)
		b.pivot_offset = Vector2(300, 105)
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_card(c: Dictionary) -> Button:
	var nm_t := ""
	var desc := ""
	var tag := ""
	var icon := "♥"
	var col := Color("#ff5c7a")
	var setline := ""
	var gold := false
	match c["type"]:
		"evo":
			var d: Dictionary = MAINS[c["id"]]
			nm_t = d["evo"]
			desc = d["evo_desc"]
			tag = "진화!"
			icon = d["icon"]
			col = Color("#ffc928")
			setline = "%s Lv.5 + %s" % [d["name"], SUPPORTS[d["partner"]]["name"]]
			gold = true
		"main":
			var d: Dictionary = MAINS[c["id"]]
			var cur: int = mains.get(c["id"], 0)
			nm_t = d["name"]
			desc = d["desc"][cur]
			tag = "새로!" if cur == 0 else "Lv.%d → %d" % [cur, cur + 1]
			icon = d["icon"]
			col = Color(d["col"])
			var pn: String = SUPPORTS[d["partner"]]["name"]
			setline = "세트 짝꿍: %s%s" % [pn, "  (있어요!)" if supports.has(d["partner"]) else ""]
		"sup":
			var d: Dictionary = SUPPORTS[c["id"]]
			var cur: int = supports.get(c["id"], 0)
			nm_t = d["name"]
			desc = d["desc"]
			tag = "새로!" if cur == 0 else "Lv.%d → %d" % [cur, cur + 1]
			icon = d["icon"]
			col = Color(d["col"])
			if d["set"] != "":
				setline = "세트 짝꿍: %s%s" % [MAINS[d["set"]]["name"], "  (있어요!)" if mains.has(d["set"]) else ""]
			else:
				setline = "보조 아이템"
		"heal":
			nm_t = "뽀빠이 과자"
			desc = "하트 2칸 회복"
	var b := Button.new()
	b.custom_minimum_size = Vector2(600, 210)
	var bg := Color("#fff1b8") if gold else Color("#fff8e8")
	var st := _round_panel(bg, 30, col, 12 if gold else 10)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", _round_panel(col.lightened(0.6), 30, col, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_badge(b, icon, col, 120, Vector2(24, 45), gold)
	var nm := _label(nm_t, 44, Color("#3a2148"), b, 0)
	nm.position = Vector2(168, 26)
	var tg := _label(tag, 30, Color("#e8524a") if tag == "새로!" or gold else Color("#8a7a95"), b, 0)
	tg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tg.offset_left = -220
	tg.offset_right = -26
	tg.offset_top = 30
	var ds := _label(desc, 30, Color("#5b4a66"), b, 0)
	ds.position = Vector2(168, 88)
	ds.size = Vector2(410, 70)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if setline != "":
		var sl := _label(setline, 24, Color("#d08a00") if setline.contains("있어요") or gold else Color("#9b8aa5"), b, 0)
		sl.position = Vector2(168, 162)
	b.pressed.connect(func(): _apply_card(c))
	return b

func _apply_card(c: Dictionary) -> void:
	var id: String = c["id"]
	match c["type"]:
		"evo":
			evolved[id] = true
			_evo_fx()
		"main":
			if not mains.has(id):
				main_order.append(id)
				mains[id] = 0
			mains[id] += 1
		"sup":
			if not supports.has(id):
				support_order.append(id)
				supports[id] = 0
			supports[id] += 1
			if id == "nametag":
				hp = mini(max_hp(), hp + 1)
		"heal":
			hp = mini(max_hp(), hp + 2)
	if card_panel:
		card_panel.queue_free()
		card_panel = null
	paused = false
	_play("pick", 1.0, -3.0)
	_refresh_ui()
	_refresh_slots()

func _evo_fx() -> void:
	shake = 0.4
	for i in 30:
		var a := TAU * i / 30.0
		_part("star", player.position + Vector3(0, 0.8, 0), Vector3(cos(a) * 6.0, rng.randf_range(2, 6), sin(a) * 6.0),
			Color.from_hsv(float(i) / 30.0, 0.55, 1.0), 1.0, 0.8, rng.randf_range(-10, 10))
	for e in enemies:
		var d: Vector3 = e["pos"] - player.position
		if d.length() < 5.0:
			_hit_enemy(e, 30.0, d, 9.0, true)

func _end_game(win: bool) -> void:
	if game_over:
		return
	game_over = true
	_play("evo" if win else "hurt", 0.8, 0.0)
	if auto_play:
		print("END win=%s t=%d kills=%d lv=%d mains=%s sup=%s evo=%s" % [win, int(elapsed), kills, level, mains, supports, evolved.keys()])
		get_tree().quit()
		return
	end_panel = Control.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(end_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(dim)
	var box_p := Panel.new()
	box_p.add_theme_stylebox_override("panel", _round_panel(Color("#fff8e8"), 36, Color("#4fa8e8"), 10))
	box_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box_p.offset_left = -280
	box_p.offset_right = 280
	box_p.offset_top = -270
	box_p.offset_bottom = 270
	end_panel.add_child(box_p)
	var t := _label("운동장을 지켰다!" if win else "철수가 기절했어요", 52, Color("#ffdf3d") if win else Color("#ff7aa8"), box_p)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 46
	var evo_names: Array = []
	for id in evolved:
		evo_names.append(MAINS[id]["evo"])
	var s := _label("버틴 시간  %d:%02d\n물리친 귀신  %d마리\n레벨  %d\n진화  %s" % [int(elapsed) / 60, int(elapsed) % 60, kills, level,
		", ".join(evo_names) if evo_names.size() > 0 else "아직 없어요"], 34, Color("#3a2148"), box_p, 0)
	s.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.offset_top = 140
	s.offset_left = 20
	s.offset_right = -20
	var b := Button.new()
	b.text = "다시 하기"
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", Color.WHITE)
	var st := _round_panel(Color("#4fa8e8"), 30, Color("#3a2148"), 6)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", _round_panel(Color("#3d8ccc"), 30, Color("#3a2148"), 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -180
	b.offset_right = 180
	b.offset_top = -140
	b.offset_bottom = -44
	box_p.add_child(b)
	b.pressed.connect(func(): get_tree().reload_current_scene())

# =========================================================
# 소리
# =========================================================
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1, 1) * 32000.0))
	w.data = data
	return w

func _synth(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * 22050)
	var s := PackedFloat32Array()
	s.resize(n)
	var st := {"ph": 0.0, "lp": 0.0}
	for i in n:
		s[i] = f.call(float(i) / 22050.0, st)
	return _wav(s)

func _make_sounds() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	sounds["shoot"] = _synth(0.12, func(t: float, st: Dictionary) -> float:
		st["ph"] += (1400.0 - t * 6000.0) / 22050.0
		st["lp"] = lerpf(st["lp"], r.randf_range(-1, 1), 0.35)
		return (sin(st["ph"] * TAU) * 0.35 + st["lp"] * 0.55) * exp(-t * 32.0) * 0.6)
	sounds["blast"] = _synth(0.22, func(t: float, st: Dictionary) -> float:
		st["ph"] += (500.0 - t * 1500.0) / 22050.0
		st["lp"] = lerpf(st["lp"], r.randf_range(-1, 1), 0.2)
		return (sin(st["ph"] * TAU) * 0.4 + st["lp"] * 0.8) * exp(-t * 14.0) * 0.6)
	sounds["hit"] = _synth(0.13, func(t: float, st: Dictionary) -> float:
		st["ph"] += (620.0 * exp(-t * 30.0) + 140.0) / 22050.0
		return (sin(st["ph"] * TAU) * 0.9 + r.randf_range(-1, 1) * exp(-t * 300.0) * 0.5) * exp(-t * 26.0) * 0.8)
	sounds["pop"] = _synth(0.3, func(t: float, st: Dictionary) -> float:
		st["ph"] += (300.0 + t * 2600.0 if t < 0.08 else 900.0) / 22050.0
		var sp := sin(t * 2400.0 * TAU) * exp(-maxf(0.0, t - 0.06) * 22.0) * (0.3 if t > 0.06 else 0.0)
		return (sin(st["ph"] * TAU) * 0.8 * exp(-t * 14.0) + sp) * 0.7)
	sounds["gem"] = _synth(0.1, func(t: float, st: Dictionary) -> float:
		return (sin(t * 1320.0 * TAU) + sin(t * 1980.0 * TAU) * 0.4) * exp(-t * 40.0) * 0.5)
	sounds["level"] = _synth(0.7, func(t: float, st: Dictionary) -> float:
		var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]
		var i := mini(3, int(t / 0.11))
		var lt := t - i * 0.11
		var sq := 1.0 if sin(t * notes[i] * TAU) > 0 else -1.0
		return ((sin(t * notes[i] * TAU) + 0.3 * sin(t * notes[i] * 2.0 * TAU)) * 0.6 + sq * 0.12) * exp(-lt * (8.0 if i < 3 else 3.5)) * 0.5)
	sounds["evo"] = _synth(1.2, func(t: float, st: Dictionary) -> float:
		var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0]
		var i := mini(5, int(t / 0.08))
		var lt := t - i * 0.08
		var f: float = notes[i]
		var v := sin(t * f * TAU) + 0.5 * sin(t * f * 1.5 * TAU) + 0.3 * sin(t * f * 2.0 * TAU)
		return v * exp(-lt * (10.0 if i < 5 else 2.2)) * 0.32)
	sounds["pick"] = _synth(0.15, func(t: float, st: Dictionary) -> float:
		return sin(t * (700.0 + t * 3000.0) * TAU) * exp(-t * 20.0) * 0.5)
	sounds["hurt"] = _synth(0.3, func(t: float, st: Dictionary) -> float:
		st["ph"] += (220.0 - t * 300.0) / 22050.0
		return (1.0 if fmod(st["ph"], 1.0) < 0.5 else -1.0) * exp(-t * 9.0) * 0.35)
	sounds["yoyo"] = _synth(0.2, func(t: float, st: Dictionary) -> float:
		st["ph"] += (300.0 + sin(t * 60.0) * 120.0) / 22050.0
		return sin(st["ph"] * TAU) * exp(-t * 12.0) * 0.4)
	sounds["rubber"] = _synth(0.25, func(t: float, st: Dictionary) -> float:
		st["ph"] += (180.0 + t * 900.0) / 22050.0
		return sin(st["ph"] * TAU) * (1.0 + 0.5 * sin(t * 90.0 * TAU)) * exp(-t * 11.0) * 0.45)
	sounds["zap"] = _synth(0.15, func(t: float, st: Dictionary) -> float:
		return r.randf_range(-1, 1) * (1.0 if sin(t * 3000.0) > 0 else 0.3) * exp(-t * 20.0) * 0.4)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players_audio.append(p)

func _play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sounds.has(name):
		return
	var p: AudioStreamPlayer = players_audio[audio_i]
	audio_i = (audio_i + 1) % players_audio.size()
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()

# =========================================================
# 스크린샷용 장면
# =========================================================
func _setup_shot() -> void:
	rng.seed = 11
	if shot_mode == "hero":
		cam_off = Vector3(1.2, 1.6, 3.2)
		cam.position = cam_off
		spawn_timer = 999.0
		return
	elapsed = 60.0
	for i in (150 if shot_mode == "evo_perf" else 40):
		var a := rng.randf() * TAU
		_make_enemy("paper" if i % 3 else "egg", Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 8.0))
	for e in enemies:
		e["spawn"] = 1.0
	if shot_mode in ["evo", "evocard", "evo_perf"]:
		for id in ["ddakji", "yoyo", "rubber"]:
			main_order.append(id)
			mains[id] = 5
		mains["gun"] = 5
		for id in ["bottle", "notebook", "watch", "sneakers"]:
			support_order.append(id)
			supports[id] = 2
		if shot_mode != "evocard":
			for id in ["gun", "ddakji", "yoyo", "rubber"]:
				evolved[id] = true
		_refresh_ui()
		_refresh_slots()
	if shot_mode == "cards" or shot_mode == "evocard":
		_level_up()
