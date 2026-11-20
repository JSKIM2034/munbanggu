extends Node3D
# 문방구 퇴마단
# 철수가 운동장에서 몰려오는 학교 귀신을 문방구 장난감으로 물리쳐요.
# - 메인 스킬(장난감 무기) 4종 + 보조 스킬 6종
# - 메인 스킬 Lv.5 + 세트 짝꿍 보조 스킬이 있으면 "진화"해서 훨씬 강해져요.
# 성능: 귀신, 딱지, 물방울, 효과는 전부 MultiMesh로 한 번에 그려요.

var AX := 13.0
var AZ := 13.0
var stage := "ground"
var grade := 1
var char_id := "chulsoo"
var in_menu := false
var obstacles: Array = []          # [중심 Vector3, 반너비 Vector2]
var run_coins := 0
var rerolls := 0
var revives := 0
var xp_f := 0.0
var kinds_killed := {}
var elites_killed := 0
var gems_got := 0
var best_combo := 0
var nohit_t := 0.0
var best_nohit := 0.0
var chests_opened := 0
var coin_label: Label
var menu_node: Node
var flashlight: OmniLight3D
const STAGE_FROM := {
	"hall": {"egg": 20.0, "dust": 40.0, "eraser": 60.0, "kettle": 100.0},
	"lab": {"egg": 10.0, "kettle": 45.0, "eraser": 70.0, "dust": 100.0},
}
const BOSS_TINT := {"ground": Color(1, 1, 1), "hall": Color(0.75, 0.9, 1.35), "lab": Color(1.3, 0.85, 1.1)}
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
# 귀신 종류: 체력, 속도, 반지름, 크기, 딱지 수, 색, 나오기 시작하는 시간(초)
const KINDS := {
	"paper": {"hp": 24.0, "speed": 1.6, "r": 0.45, "scale": 1.25, "xp": 1, "col": "#c9a8f0", "from": 0.0},
	"egg": {"hp": 13.0, "speed": 2.8, "r": 0.4, "scale": 1.25, "xp": 1, "col": "#a9d4f5", "from": 15.0},
	"kettle": {"hp": 110.0, "speed": 1.2, "r": 0.62, "scale": 1.7, "xp": 3, "col": "#ffd23f", "from": 70.0},
	"eraser": {"hp": 55.0, "speed": 1.7, "r": 0.5, "scale": 1.35, "xp": 2, "col": "#7fd18b", "from": 85.0},
	"dust": {"hp": 9.0, "speed": 3.5, "r": 0.3, "scale": 0.95, "xp": 1, "col": "#b8b2c0", "from": 115.0},
	"boss": {"hp": 36000.0, "speed": 1.35, "r": 1.5, "scale": 3.0, "xp": 0, "col": "#6fbf4a", "from": 9999.0},
}
const BOSS_TIME := 240.0

const MAINS := {
	"gun": {"name": "물총", "icon": "물", "col": "#4fa8e8", "partner": "bottle", "evo": "소방차 물대포",
		"evo_desc": "굵은 물대포! 60% 확률로 관통, 40% 확률로 물풍선처럼 펑!",
		"desc": ["가장 가까운 귀신에게 물을 쏴요", "피해 +30%", "물줄기 +1갈래", "쏘는 속도 +30%", "물줄기 +1, 30% 확률로 관통"]},
	"ddakji": {"name": "딱지", "icon": "딱", "col": "#ff7aa8", "partner": "notebook", "evo": "황금 딱지 폭풍",
		"evo_desc": "황금 딱지 8장이 크게 넘실대며 귀신을 날려요",
		"desc": ["딱지 2장이 빙글빙글 철수를 지켜요", "딱지 +1장", "피해 +40%", "딱지 +1장", "딱지 +1장, 더 크고 빠르게"]},
	"yoyo": {"name": "요요", "icon": "요", "col": "#2fc79a", "partner": "watch", "evo": "번개 요요",
		"evo_desc": "요요 4개! 맞히면 35% 확률로 찌릿, 번개가 옆으로 튀어요",
		"desc": ["쭉 날아갔다 돌아오며 다 맞혀요", "요요 +1개", "피해 +40%", "더 멀리 날아가요", "요요 +1개"]},
	"rubber": {"name": "고무줄", "icon": "줄", "col": "#ff9a2f", "partner": "sneakers", "evo": "무지개 고무줄",
		"evo_desc": "무지개 고무줄이 두 겹으로 쫙쫙! 맞은 귀신은 느려져요",
		"desc": ["고무줄이 쫙! 퍼지며 주변을 튕겨내요", "범위 +20%", "피해 +40%", "더 자주 퍼져요", "범위 +20%, 더 세게 튕겨요"]},
}
const SUPPORTS := {
	"bottle": {"name": "생수병", "icon": "병", "col": "#58c6f2", "desc": "모든 공격 피해 +15%", "set": "gun"},
	"notebook": {"name": "공책", "icon": "책", "col": "#b48ef0", "desc": "공격 범위,크기 +15%", "set": "ddakji"},
	"watch": {"name": "계산기 시계", "icon": "시", "col": "#7cc95a", "desc": "공격 대기 시간 -8%", "set": "yoyo"},
	"sneakers": {"name": "운동화", "icon": "신", "col": "#f2c230", "desc": "이동 속도 +10%", "set": "rubber"},
	"pencil": {"name": "필통", "icon": "필", "col": "#9b8cff", "desc": "딱지 줍는 거리 +40%", "set": ""},
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
		if a.begins_with("--stage="):
			Save.run_cfg["stage"] = a.substr(8)
		if a.begins_with("--grade="):
			Save.run_cfg["grade"] = int(a.substr(8))
		if a.begins_with("--char="):
			Save.data["char"] = a.substr(7)
	if args.has("--seed"):
		rng.seed = 7
	if args.has("--meta"):
		Save.data["shop"] = {"dmg": 4, "hp": 2, "speed": 2, "magnet": 2, "xp": 2, "luck": 1, "reroll": 1, "revive": 1}
	if args.has("--menu"):
		Save.mode = "menu"
	elif auto_play or shot_mode != "":
		Save.mode = "run"
	in_menu = Save.mode == "menu"
	stage = "ground" if in_menu else Save.run_cfg["stage"]
	grade = int(Save.run_cfg["grade"])
	char_id = Save.data["char"]
	match stage:
		"hall":
			AX = 3.4
			AZ = 30.0
		"lab":
			AX = 11.0
			AZ = 11.0
	var w: String = Save.CHARS[char_id]["weapon"]
	mains = {w: 1}
	main_order = [w]
	rerolls = Save.shop_lv("reroll")
	revives = Save.shop_lv("revive")
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
	hp = max_hp()
	_refresh_ui()
	if in_menu:
		hud.visible = false
		cam_off = Vector3(0.0, 2.3, 5.2)
		cam.position = cam_off
		cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
		menu_node = load("res://menu.gd").new()
		menu_node.set("main", self)
		add_child(menu_node)
		return
	if shot_mode != "":
		_setup_shot()
	_prewarm()
	_banner("%s %d학년" % [Save.STAGES[stage]["name"], grade], Color.WHITE)

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
	if stage == "hall":
		_world_hall(e, sun)
		return
	if stage == "lab":
		_world_lab(e, sun)
		return

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

func _tile_floor(size: Vector2, c1: Color, c2: Color, tile: float, center := Vector3.ZERO) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_disabled;
uniform vec3 c1; uniform vec3 c2; uniform float tile;
varying vec2 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment(){
  vec2 q = wp / tile;
  vec2 f = fract(q);
  float chk = mod(floor(q.x) + floor(q.y), 2.0);
  vec3 c = mix(c1, c2, chk);
  float gap = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
  c *= mix(0.82, 1.0, smoothstep(0.0, 0.03, gap));
  ALBEDO = c;
  ROUGHNESS = 0.6;
}
"""
	sm.shader = sh
	sm.set_shader_parameter("c1", c1)
	sm.set_shader_parameter("c2", c2)
	sm.set_shader_parameter("tile", tile)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.position = center
	add_child(mi)

func _world_hall(e: Environment, sun: DirectionalLight3D) -> void:
	# 길고 좁은 학교 복도: 왼쪽 창문, 오른쪽 사물함
	e.background_color = Color("#2d2a3a")
	e.ambient_light_energy = 0.5
	_tile_floor(Vector2(12, 70), Color(0.78, 0.86, 0.72), Color(0.92, 0.9, 0.82), 1.0)
	var L: Array = []
	var W := AX + 0.75
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(0.3, 3.2, AZ * 2 + 4)), T(Vector3(side * W, 1.6, 0)), Color("#f0e6cc")])
		L.append([_box(Vector3(0.34, 0.9, AZ * 2 + 4)), T(Vector3(side * (W - 0.02), 0.45, 0)), Color("#7aa86a")])
	var z := -AZ
	while z < AZ:
		# 왼쪽 창문
		L.append([_box(Vector3(0.1, 1.2, 1.8)), T(Vector3(-W + 0.18, 1.8, z + 1.0)), Color("#9fd8ff")])
		L.append([_box(Vector3(0.12, 0.1, 1.9)), T(Vector3(-W + 0.2, 1.2, z + 1.0)), Color("#6b4a32")])
		# 오른쪽 사물함
		L.append([_box(Vector3(0.5, 1.6, 0.9)), T(Vector3(W - 0.4, 0.8, z + 0.5)), Color("#5fa8d8") if int(z) % 2 == 0 else Color("#ff9a8a")])
		L.append([_box(Vector3(0.52, 0.06, 0.06)), T(Vector3(W - 0.4, 1.2, z + 0.5)), Color("#f5f0e0")])
		z += 2.4
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(W * 2, 3.2, 0.3)), T(Vector3(0, 1.6, side * (AZ + 1.5))), Color("#e8dcc0")])
		L.append([_box(Vector3(1.6, 2.4, 0.1)), T(Vector3(0, 1.2, side * (AZ + 1.33))), Color("#6b4a32")])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)

func _world_lab(e: Environment, sun: DirectionalLight3D) -> void:
	# 불 꺼진 과학실: 어둡고, 철수 손전등만 환해요. 실험대는 장애물이에요.
	e.background_color = Color("#0d0b1a")
	e.ambient_light_color = Color("#6f7fd8")
	e.ambient_light_energy = 0.14
	sun.light_energy = 0.1
	sun.light_color = Color("#8fa0ff")
	_tile_floor(Vector2(40, 40), Color(0.42, 0.45, 0.6), Color(0.52, 0.55, 0.7), 1.2)
	flashlight = OmniLight3D.new()
	flashlight.omni_range = 8.5
	flashlight.light_energy = 2.4
	flashlight.light_color = Color("#fff1c9")
	flashlight.omni_attenuation = 0.9
	add_child(flashlight)
	var L: Array = []
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(0.4, 3.0, 26)), T(Vector3(side * 12.6, 1.5, 0)), Color("#d8d2e8")])
		L.append([_box(Vector3(26, 3.0, 0.4)), T(Vector3(0, 1.5, side * 12.6)), Color("#d8d2e8")])
	# 선반과 칠판
	L.append([_box(Vector3(8, 2.2, 0.1)), T(Vector3(0, 1.6, -12.35)), Color("#2f5a3c")])
	for i in 6:
		L.append([_box(Vector3(0.6, 1.8, 2.0)), T(Vector3(12.1, 0.9, -9.0 + i * 3.6)), Color("#8a6a4a")])
	var tables := [Vector3(-6, 0, -6), Vector3(0, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 0), Vector3(6, 0, 0),
		Vector3(-6, 0, 6), Vector3(0, 0, 6), Vector3(6, 0, 6)]
	var beaker_cols := [Color("#6ee0b0"), Color("#ff7aa8"), Color("#9b8cff"), Color("#ffd23f")]
	for i in tables.size():
		var tp: Vector3 = tables[i]
		L.append([_box(Vector3(2.6, 0.12, 1.3)), T(tp + Vector3(0, 0.9, 0)), Color("#3a3a46")])
		L.append([_box(Vector3(2.4, 0.84, 1.1)), T(tp + Vector3(0, 0.42, 0)), Color("#c8b48a")])
		for j in 2:
			L.append([_cyl(0.1, 0.28, 0.12, 10), T(tp + Vector3(-0.6 + j * 1.0, 1.1, 0.1 * j)), beaker_cols[(i + j) % 4]])
		obstacles.append([tp, Vector2(1.3, 0.65)])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)
	# 비커가 은은하게 빛나요
	for i in 3:
		var gl := OmniLight3D.new()
		gl.omni_range = 3.0
		gl.light_energy = 0.8
		gl.light_color = beaker_cols[i]
		gl.position = tables[i * 3 % tables.size()] + Vector3(0, 1.4, 0)
		add_child(gl)

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
	elif kind == "kettle":
		var col := Color("#ffd23f")
		L.append([_sph(0.34, 0.5, 18, 8), T(Vector3(0, 0.36, 0)), col])
		L.append([_cyl(0.2, 0.08, 0.26), T(Vector3(0, 0.63, 0)), col.darkened(0.08)])
		L.append([_sph(0.05, -1, 8, 4), T(Vector3(0, 0.7, 0)), Color("#6b4a32")])
		L.append([_cyl(0.045, 0.32, 0.07), T(Vector3(-0.38, 0.42, 0.0), Vector3(0, 0, 50)), col.darkened(0.05)])
		L.append([_box(Vector3(0.5, 0.05, 0.05)), T(Vector3(0, 0.86, 0)), Color("#6b4a32")])
		for sx in [-1.0, 1.0]:
			L.append([_box(Vector3(0.05, 0.22, 0.05)), T(Vector3(sx * 0.23, 0.76, 0)), Color("#6b4a32")])
			L.append([_sph(0.08, -1, 8, 4), T(Vector3(sx * 0.38, 0.3, 0.1)), col.darkened(0.1)])
			L.append([_sph(0.08, -1, 8, 4), T(Vector3(sx * 0.14, 0.06, 0.0)), col.darkened(0.15)])
		L.append([_sph(0.05, -1, 8, 4), T(Vector3(0.12, 0.5, 0.26)), Color("#c9a24a")])
		_face_parts(L, 0.31, 0.38, 1.0)
	elif kind == "eraser":
		var col := Color("#7fd18b")
		L.append([_box(Vector3(0.62, 0.3, 0.4)), T(Vector3(0, 0.42, 0)), col])
		L.append([_box(Vector3(0.6, 0.12, 0.38)), T(Vector3(0, 0.22, 0)), Color("#d6d0dc")])
		L.append([_box(Vector3(0.4, 0.06, 0.06)), T(Vector3(0, 0.62, 0)), col.darkened(0.2)])
		_face_parts(L, 0.205, 0.43, 0.95)
		for sx in [-1.0, 1.0]:
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.36, 0.38, 0.06)), col.darkened(0.1)])
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.16, 0.07, 0.0)), col.darkened(0.15)])
	elif kind == "dust":
		var col := Color("#b8b2c0")
		L.append([_sph(0.26, -1, 10, 5), T(Vector3(0, 0.3, 0)), col])
		for i in 7:
			var a := TAU * i / 7.0
			L.append([_sph(0.12, -1, 6, 3), T(Vector3(cos(a) * 0.22, 0.3 + sin(a * 2.0) * 0.1, sin(a) * 0.22)), col.darkened(0.12)])
		_face_parts(L, 0.24, 0.32, 0.85)
		L.append([_box(Vector3(0.03, 0.05, 0.02)), T(Vector3(-0.04, 0.2, 0.25)), Color.WHITE])
		L.append([_box(Vector3(0.03, 0.05, 0.02)), T(Vector3(0.04, 0.2, 0.25)), Color.WHITE])
	elif kind == "boss":
		var g := Color("#6fbf4a")
		L.append([_box(Vector3(0.9, 0.95, 0.6)), T(Vector3(0, 0.62, 0)), g])
		L.append([_box(Vector3(0.82, 0.22, 0.05)), T(Vector3(0, 0.95, 0.3)), g.darkened(0.15)])
		for i in 3:
			L.append([_box(Vector3(0.3, 0.03, 0.02)), T(Vector3(0, 1.02 - i * 0.05, 0.33)), g.darkened(0.35)])
		L.append([_box(Vector3(0.7, 0.32, 0.04)), T(Vector3(0, 0.62, 0.3)), Color("#2a1630")])
		for sx in [-1.0, 1.0]:
			L.append([_sph(0.08, -1, 10, 5), T(Vector3(sx * 0.15, 0.66, 0.33), Vector3.ZERO, Vector3(1, 0.8, 0.4)), Color("#ffe14a")])
			L.append([_box(Vector3(0.14, 0.03, 0.02)), T(Vector3(sx * 0.15, 0.78, 0.33), Vector3(0, 0, -sx * 20.0)), Color("#2a1630")])
			L.append([_sph(0.1, -1, 8, 4), T(Vector3(sx * 0.3, 0.55, 0.32), Vector3.ZERO, Vector3(1, 0.7, 0.3)), Color("#ff9db0")])
			L.append([_cyl(0.14, 0.5, 0.17), T(Vector3(sx * 0.6, 0.55, 0.05), Vector3(0, 0, sx * 25.0)), Color("#2e3a8c")])
			L.append([_sph(0.13, -1, 10, 5), T(Vector3(sx * 0.72, 0.3, 0.1)), Color("#f5d6b8")])
			L.append([_box(Vector3(0.22, 0.12, 0.3)), T(Vector3(sx * 0.25, 0.06, 0.05)), Color.WHITE])
		L.append([_box(Vector3(0.82, 0.18, 0.05)), T(Vector3(0, 0.33, 0.3)), g.darkened(0.15)])
		L.append([_sph(0.25, 0.3, 14, 6), T(Vector3(0.1, 1.24, 0)), Color("#ffd23f")])
		L.append([_cyl(0.04, 0.22, 0.06), T(Vector3(-0.17, 1.24, 0), Vector3(0, 0, 50)), Color("#ffd23f")])
		var bc := [Color("#ff7aa8"), Color("#58c6f2"), Color("#ffd23f"), Color("#b48ef0")]
		for i in 4:
			L.append([_sph(0.11, -1, 8, 4), T(Vector3(-0.52 + (i % 2) * 1.04, 0.95 - (i / 2) * 0.35, 0.15)), bc[i]])
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
	for kind in KINDS:
		_mm(kind, _enemy_mesh(kind), 4 if kind == "boss" else MAX_ENEMY, true)
	var H: Array = []
	H.append([_sph(0.15, -1, 10, 5), T(Vector3(-0.1, 0.05, 0)), Color("#ff4f6d")])
	H.append([_sph(0.15, -1, 10, 5), T(Vector3(0.1, 0.05, 0)), Color("#ff4f6d")])
	H.append([_box(Vector3(0.22, 0.22, 0.2)), T(Vector3(0, -0.08, 0), Vector3(0, 0, 45)), Color("#ff4f6d")])
	H.append([_sph(0.04, -1, 6, 3), T(Vector3(-0.12, 0.12, 0.11)), Color.WHITE])
	heart_mesh = merge(H)
	var G: Array = []
	G.append([_box(Vector3(0.12, 0.34, 0.12)), T(Vector3(-0.14, 0.02, 0)), Color("#ff3b3b")])
	G.append([_box(Vector3(0.12, 0.34, 0.12)), T(Vector3(0.14, 0.02, 0)), Color("#3b6bff")])
	G.append([_box(Vector3(0.4, 0.12, 0.12)), T(Vector3(0, -0.15, 0)), Color("#ff3b3b")])
	G.append([_box(Vector3(0.13, 0.08, 0.13)), T(Vector3(-0.14, 0.22, 0)), Color("#e8e8f0")])
	G.append([_box(Vector3(0.13, 0.08, 0.13)), T(Vector3(0.14, 0.22, 0)), Color("#e8e8f0")])
	magnet_mesh = merge(G)
	var C: Array = []
	C.append([_box(Vector3(0.62, 0.36, 0.42)), T(Vector3(0, 0.0, 0)), Color("#b5713a")])
	C.append([_box(Vector3(0.64, 0.16, 0.44)), T(Vector3(0, 0.25, 0)), Color("#9a5c2c")])
	C.append([_box(Vector3(0.66, 0.06, 0.46)), T(Vector3(0, 0.16, 0)), Color("#ffd23f")])
	C.append([_box(Vector3(0.08, 0.5, 0.46)), T(Vector3(-0.2, 0.08, 0)), Color("#ffd23f")])
	C.append([_box(Vector3(0.08, 0.5, 0.46)), T(Vector3(0.2, 0.08, 0)), Color("#ffd23f")])
	C.append([_box(Vector3(0.12, 0.14, 0.05)), T(Vector3(0, 0.12, 0.23)), Color("#fff3b0")])
	chest_mesh = merge(C)
	_mm("coin", _cyl(0.13, 0.04, -1, 14), 200, true)
	var SH: Array = []
	SH.append([_box(Vector3(0.16, 0.08, 0.3)), T(Vector3(0, 0.04, 0)), Color("#f5f2ea")])
	SH.append([_box(Vector3(0.17, 0.03, 0.31)), T(Vector3(0, -0.01, 0)), Color("#4f7fe0")])
	SH.append([_box(Vector3(0.12, 0.06, 0.1)), T(Vector3(0, 0.1, -0.08)), Color("#f5f2ea")])
	_mm("eshot", merge(SH), 120, true)
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
func mains_def() -> Dictionary:
	return MAINS
func kinds_def() -> Dictionary:
	return KINDS

func lv(id: String) -> int:
	return int(mains.get(id, 0)) + int(supports.get(id, 0))

func dmg_mult() -> float:
	return (1.0 + 0.15 * lv("bottle")) * (1.0 + 0.08 * Save.shop_lv("dmg"))
func crit_chance() -> float:
	return 0.12 + 0.03 * Save.shop_lv("luck") + (0.08 if char_id == "younghee" else 0.0)
func xp_mult() -> float:
	return 1.0 + 0.06 * Save.shop_lv("xp") + (0.15 if char_id == "minsu" else 0.0)
func coin_mult() -> float:
	return (1.0 + 0.1 * Save.shop_lv("coin")) * (1.0 + 0.35 * (grade - 1)) * (1.0 + (STAGE_MULT[stage] - 1.0) * 0.8)
const STAGE_MULT := {"ground": 1.0, "hall": 1.45, "lab": 2.0}
func grade_hp() -> float:
	return (1.0 + 0.45 * (grade - 1)) * STAGE_MULT[stage]
func area_mult() -> float:
	return 1.0 + 0.15 * lv("notebook")
func cd_mult() -> float:
	return 1.0 - 0.08 * lv("watch")
func move_speed() -> float:
	return 4.2 * (1.0 + 0.1 * lv("sneakers")) * (1.0 + 0.05 * Save.shop_lv("speed"))
func magnet() -> float:
	return 2.2 * (1.0 + 0.4 * lv("pencil")) * (1.0 + 0.15 * Save.shop_lv("magnet"))
func max_hp() -> int:
	return 5 + lv("nametag") + Save.shop_lv("hp") + (2 if char_id == "sunja" else 0)

func gun_stats() -> Dictionary:
	var d := _gun_base()
	var w := Save.shop_lv("w_gun")
	d["dmg"] *= 1.0 + 0.12 * w
	d["rate"] *= 1.0 + 0.04 * w
	return d

func _gun_base() -> Dictionary:
	var l := lv("gun")
	if evolved.has("gun"):
		return {"rate": 2.8, "dmg": 22.0 * (1.1 if char_id == "chulsoo" else 1.0), "shots": 3, "pierce": 0.6, "size": 1.8, "splash": 1.5, "splash_p": 0.4}
	return {"rate": 2.2 * (1.3 if l >= 4 else 1.0), "dmg": 10.0 * (1.3 if l >= 2 else 1.0) * (1.1 if char_id == "chulsoo" else 1.0),
		"shots": 1 + (1 if l >= 3 else 0) + (1 if l >= 5 else 0), "pierce": 0.3 if l >= 5 else 0.0, "size": 1.0, "splash": 0.0, "splash_p": 0.0}

func ddakji_stats() -> Dictionary:
	var d := _ddakji_base()
	var w := Save.shop_lv("w_ddakji")
	d["dmg"] *= 1.0 + 0.12 * w
	d["speed"] *= 1.0 + 0.04 * w
	return d

func _ddakji_base() -> Dictionary:
	var l := lv("ddakji")
	if evolved.has("ddakji"):
		return {"count": 8, "dmg": 18.0, "radius": 2.6, "speed": 4.2, "knock": 6.0}
	return {"count": [0, 2, 3, 3, 4, 5][l], "dmg": 8.0 * (1.4 if l >= 3 else 1.0), "radius": 1.7 * (1.2 if l >= 5 else 1.0),
		"speed": 3.2 * (1.3 if l >= 5 else 1.0), "knock": 3.0}

func yoyo_stats() -> Dictionary:
	var d := _yoyo_base()
	var w := Save.shop_lv("w_yoyo")
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	return d

func _yoyo_base() -> Dictionary:
	var l := lv("yoyo")
	if evolved.has("yoyo"):
		return {"count": 4, "dmg": 24.0, "dist": 6.5, "cool": 1.4, "chain": 3}
	return {"count": 1 + (1 if l >= 2 else 0) + (1 if l >= 5 else 0), "dmg": 14.0 * (1.4 if l >= 3 else 1.0),
		"dist": 4.5 * (1.3 if l >= 4 else 1.0), "cool": 1.7, "chain": 0}

func rubber_stats() -> Dictionary:
	var d := _rubber_base()
	var w := Save.shop_lv("w_rubber")
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	return d

func _rubber_base() -> Dictionary:
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
func _make_enemy(kind: String, pos: Vector3, elite := false) -> Dictionary:
	if kind != "boss" and enemies.size() >= MAX_ENEMY - 2:
		return {}
	var k: Dictionary = KINDS[kind]
	var t := elapsed / RUN_TIME
	var hpv: float = k["hp"] * (1.0 + t * 3.0 + t * t * 6.0) * grade_hp()
	if kind == "boss":
		hpv = k["hp"] * grade_hp()
	var e := {"pos": pos, "vel": Vector3.ZERO, "rot": 0.0, "kind": kind, "hp": hpv, "flash": 0.0,
		"squash": 0.0, "phase": rng.randf() * TAU, "spawn": 0.0, "dead": -1.0, "slow": 0.0, "elite": elite,
		"speed": k["speed"] * (1.0 + t * 0.3), "radius": k["r"], "scale": k["scale"], "xp": k["xp"], "hits": {},
		"dash": rng.randf_range(1.5, 3.5), "dash_t": 0.0, "summon": 3.0}
	if elite:
		e["hp"] *= 9.0
		e["scale"] *= 1.55
		e["radius"] *= 1.5
		e["speed"] *= 0.9
		e["xp"] *= 6
	e["max_hp"] = e["hp"]
	enemies.append(e)
	return e

func _spawn_logic(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer > 0.0:
		return
	var t := elapsed / RUN_TIME
	spawn_timer = lerpf(1.1, 0.3, clampf(t * 1.3, 0, 1))
	var count := int((1 + int(t * 9.0)) * (1.0 + 0.12 * (grade - 1)) * (1.0 + (STAGE_MULT[stage] - 1.0) * 0.4))
	if boss_spawned:
		count = maxi(1, count / 3)
	# 시간이 지날수록 센 귀신이 섞여요
	var pool := {}
	for kind in KINDS:
		if kind != "boss" and elapsed >= kind_from(kind):
			pool[kind] = {"paper": 5.0, "egg": 3.0, "kettle": 1.2, "eraser": 1.6, "dust": 1.0}[kind]
	for i in count:
		if enemies.size() >= MAX_ENEMY - 8:
			return
		var p := _spawn_point()
		var kind := _weighted(pool)
		if kind == "dust":
			for j in 5:
				_make_enemy("dust", p + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))
		else:
			_make_enemy(kind, p)

func kind_from(kind: String) -> float:
	return float(STAGE_FROM.get(stage, {}).get(kind, KINDS[kind]["from"]))

func _spawn_point() -> Vector3:
	if stage == "hall":
		# 복도: 앞뒤 끝에서 몰려와요
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var z := player.position.z + side * rng.randf_range(11.0, 14.0)
		if absf(z) > AZ:
			z = player.position.z - side * rng.randf_range(11.0, 14.0)
		return Vector3(rng.randf_range(-AX, AX), 0, clampf(z, -AZ, AZ))
	var a := rng.randf() * TAU
	var p := player.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(11.0, 13.0)
	p.x = clampf(p.x, -AX, AX)
	p.z = clampf(p.z, -AZ, AZ)
	if p.distance_to(player.position) < 6.0:
		p = player.position - (p - player.position).normalized() * 9.0
	return p

func _weighted(pool: Dictionary) -> String:
	var tot := 0.0
	for k in pool:
		tot += pool[k]
	var r := rng.randf() * tot
	for k in pool:
		r -= pool[k]
		if r <= 0.0:
			return k
	return pool.keys()[0]

# 정예 귀신과 보스
var next_elite := 40.0
var boss_spawned := false
var boss: Dictionary = {}
var boss_warned := false
func _event_logic() -> void:
	if elapsed >= next_elite and not boss_spawned:
		next_elite += 40.0
		var kinds: Array = []
		for kind in KINDS:
			if kind != "boss" and kind != "dust" and elapsed >= kind_from(kind):
				kinds.append(kind)
		_make_enemy(kinds[rng.randi() % kinds.size()], _spawn_point(), true)
		_banner("반짝반짝 정예 귀신 등장!", Color("#ffdf3d"))
		_play("warn", 1.4, -10.0)
	if elapsed >= BOSS_TIME - 5.0 and not boss_warned:
		boss_warned = true
		_banner(Save.STAGES[stage]["boss"] + "이 와요!", Color("#ff7aa8"))
		_play("warn", 1.0, 0.0)
	if elapsed >= BOSS_TIME and not boss_spawned:
		boss_spawned = true
		var p := player.position + Vector3(0, 0, -8)
		if p.z < -AZ:
			p.z = player.position.z + 8.0
		p.x = clampf(p.x, -AX, AX)
		boss = _make_enemy("boss", p)
		shake = 0.5

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
		var steer := 4.0
		if e["kind"] == "eraser":
			# 부르르 떨다가 쌩 돌진해요
			e["dash"] -= dt
			if e["dash"] <= 0.0 and e["dash_t"] <= 0.0 and dist < 8.0:
				e["dash_t"] = 0.95
				e["dash_dir"] = to_p / maxf(dist, 0.01)
			if e["dash_t"] > 0.0:
				e["dash_t"] -= dt
				if e["dash_t"] > 0.45:
					want = Vector3.ZERO
					e["squash"] = 0.3 + 0.2 * sin(elapsed * 60.0)
				else:
					want = e["dash_dir"] * 10.0
					steer = 12.0
					if rng.randf() < 0.5:
						_part("drop", e["pos"] + Vector3(0, 0.3, 0), Vector3(0, 1, 0), Color(1, 1, 1, 0.8), 0.09, 0.4)
				if e["dash_t"] <= 0.0:
					e["dash"] = rng.randf_range(2.5, 4.0)
		if e["kind"] == "boss":
			var r := _boss_ai(e, dt, to_p, dist)
			if r.size() > 0:
				want = r[0]
				steer = r[1]
		e["vel"] = (e["vel"] as Vector3).lerp(want, dt * steer)
		e["pos"] += e["vel"] * dt
		e["pos"].x = clampf(e["pos"].x, -AX - 1, AX + 1)
		e["pos"].z = clampf(e["pos"].z, -AZ - 1, AZ + 1)
		if dist > 0.01:
			e["rot"] = lerp_angle(e["rot"], atan2(to_p.x, to_p.z), dt * 8.0)
		e["phase"] += dt * (10.0 if e["kind"] in ["egg", "dust"] else 7.0)
		e["squash"] = move_toward(e["squash"], 0.0, dt * 5.0)
		e["flash"] = maxf(0.0, e["flash"] - dt)
		if obstacles.size() > 0:
			e["pos"] = _push_out(e["pos"], e["radius"] * 0.8)
		if dist < e["radius"] + 0.3 and hurt_timer <= 0.0 and not game_over:
			_player_hurt(e["pos"], 2 if e["kind"] == "boss" or e["elite"] else 1)
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
			var md: float = (a["radius"] + b["radius"]) * 0.85
			if l < md and l > 0.001:
				var push := d / l * (md - l) * 0.5
				if a["kind"] == "boss":
					b["pos"] -= push * 2.0
				elif b["kind"] == "boss":
					a["pos"] += push * 2.0
				else:
					a["pos"] += push
					b["pos"] -= push

func _hit_enemy(e: Dictionary, dmg: float, dir: Vector3, knock := 5.0, quiet := false) -> void:
	if e["dead"] >= 0.0:
		return
	dmg *= dmg_mult()
	var crit := rng.randf() < crit_chance()
	if crit:
		dmg *= 2.0
	e["hp"] -= dmg
	e["flash"] = 0.08
	e["squash"] = 1.0
	dir.y = 0
	if dir.length() > 0.01:
		var resist := 0.08 if e["kind"] == "boss" else (0.35 if e["elite"] or e["kind"] == "kettle" else 1.0)
		e["vel"] = dir.normalized() * knock * resist
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
	kinds_killed[e["kind"]] = int(kinds_killed.get(e["kind"], 0)) + 1
	if e["elite"]:
		elites_killed += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = 1.6
	var pos: Vector3 = e["pos"]
	var col := Color(KINDS[e["kind"]]["col"])
	var big: bool = e["elite"] or e["kind"] == "boss"
	_burst(pos + Vector3(0, 0.6, 0), col, 16 if big else 7, 6.0 if big else 4.5)
	_burst(pos + Vector3(0, 0.6, 0), Color("#fff27a"), 14 if big else 4, 6.0 if big else 5.0, true)
	for i in int(e["xp"]):
		gems.append({"pos": pos + Vector3(0, 0.25, 0), "vel": Vector3(rng.randf_range(-1.5, 1.5), 3.5, rng.randf_range(-1.5, 1.5)) * (1.6 if i > 0 else 1.0),
			"pull": false, "t": 0.0, "col": [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#9b8cff")][rng.randi() % 4]})
	# 동전
	var cc := 0
	if e["kind"] == "boss":
		cc = 40
	elif e["kind"] == "kettle":
		cc = 1 if rng.randf() < 0.3 else 0
	elif rng.randf() < 0.08:
		cc = 1
	for i in cc:
		gems.append({"pos": pos + Vector3(0, 0.3, 0), "vel": Vector3(rng.randf_range(-3, 3), rng.randf_range(3, 6), rng.randf_range(-3, 3)) * (1.0 if cc == 1 else 1.4),
			"pull": false, "t": 0.0, "col": Color("#ffc928"), "coin": true})
	# 하트,자석,보물 상자 떨어뜨리기
	if e["elite"]:
		_drop("chest", pos + Vector3(0.5, 0, 0))
		_drop("heart", pos + Vector3(-0.5, 0, 0))
	elif e["kind"] != "boss":
		var r := rng.randf()
		if r < 0.012:
			_drop("heart", pos)
		elif r < 0.019:
			_drop("magnet", pos)
	if e["kind"] == "boss":
		hitstop(0.25)
		shake = 0.8
		get_tree().create_timer(1.2).timeout.connect(func(): _end_game(true))
	_play("pop", 1.0 + minf(combo, 12) * 0.04, -3.0)
	if hitstop_cool <= 0.0:
		hitstop(0.035)
		hitstop_cool = 0.15
	shake = maxf(shake, 0.12)

# ---------- 보스 공격 ----------
var eshots: Array = []      # 보스가 던진 실내화
var warns: Array = []       # 바닥 경고 동그라미
func _boss_ai(e: Dictionary, dt: float, to_p: Vector3, dist: float) -> Array:
	var angry: bool = e["hp"] < e["max_hp"] * 0.5
	if not e.has("pat"):
		e["pat"] = "walk"
		e["pat_t"] = 2.0
	e["pat_t"] -= dt
	match e["pat"]:
		"walk":
			if e["pat_t"] <= 0.0:
				var pats := ["shoes", "charge", "rain", "summon", "shoes", "charge", "rain"]
				e["pat"] = pats[rng.randi() % pats.size()]
				if e["pat"] == "summon" and enemies.size() >= MAX_ENEMY - 12:
					e["pat"] = "shoes"
				e["pat_t"] = 0.7
				e["stage"] = 0
				e["flash"] = 0.25
				_play("warn", 1.3, -9.0)
			return []
		"shoes":
			# 부르르 떨다가 실내화를 사방으로 던져요
			e["squash"] = 0.4 + 0.2 * sin(elapsed * 50.0)
			if e["pat_t"] <= 0.0:
				var n := 12 + grade + (4 if angry else 0)
				var off := rng.randf() * TAU
				for i in n:
					var a := off + TAU * i / n
					var dv := Vector3(cos(a), 0, sin(a))
					eshots.append({"pos": e["pos"] + dv * 1.2 + Vector3(0, 0.6, 0), "vel": dv * (4.2 + 0.2 * grade), "life": 5.0, "rot": a})
				_play("blast", 0.7, -4.0)
				shake = maxf(shake, 0.25)
				e["stage"] += 1
				e["pat_t"] = 0.45
				if e["stage"] >= (3 if angry else 2):
					_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"charge":
			if e["stage"] == 0:
				e["charge_dir"] = to_p / maxf(dist, 0.01)
				e["stage"] = 1
				e["pat_t"] = 0.9
				_warn_line(e["pos"], e["charge_dir"], 0.9)
			if e["stage"] == 1:
				e["squash"] = 0.3
				if e["pat_t"] <= 0.0:
					e["stage"] = 2
					e["pat_t"] = 0.75
					_play("rubber", 0.6, -2.0)
				return [Vector3.ZERO, 8.0]
			if e["pat_t"] <= 0.0:
				_boss_rest(e, angry)
			if rng.randf() < 0.6:
				_part("drop", e["pos"] + Vector3(0, 0.4, 0), Vector3(rng.randf_range(-1, 1), 2, rng.randf_range(-1, 1)), Color(1, 1, 1, 0.8), 0.14, 0.5)
			return [e["charge_dir"] * 13.0, 14.0]
		"rain":
			# 우산 비: 철수 발밑에 빨간 동그라미, 잠시 뒤 쾅!
			if e["stage"] == 0:
				var n := 3 + (2 if angry else 0)
				for i in n:
					var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
					var wp := player.position + move_dir * move_speed() * 0.6 + off
					_warn_circle(wp, 1.5, 1.1 + i * 0.12)
				e["stage"] = 1
				e["pat_t"] = 1.6
			if e["pat_t"] <= 0.0:
				_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"summon":
			if e["pat_t"] <= 0.0:
				for j in 6 + grade:
					var a := TAU * j / (6 + grade)
					_make_enemy("dust", e["pos"] + Vector3(cos(a), 0, sin(a)) * 2.2)
				_play("warn", 1.6, -8.0)
				_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"rest":
			if e["pat_t"] <= 0.0:
				e["pat"] = "walk"
				e["pat_t"] = 0.1
			return []
	return []

func _boss_rest(e: Dictionary, angry: bool) -> void:
	e["pat"] = "walk"
	e["pat_t"] = rng.randf_range(1.2, 1.8) if angry else rng.randf_range(2.0, 2.8)

func _warn_mat(a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.2, 0.25, a)
	return m

func _warn_circle(pos: Vector3, r: float, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(1.0, 0.02, -1, 32)
	mi.material_override = _warn_mat(0.35)
	mi.position = Vector3(pos.x, 0.04, pos.z)
	mi.scale = Vector3(r, 1, r)
	add_child(mi)
	var inner := MeshInstance3D.new()
	inner.mesh = _cyl(1.0, 0.03, -1, 32)
	inner.material_override = _warn_mat(0.5)
	inner.scale = Vector3(0.01, 1, 0.01)
	mi.add_child(inner)
	warns.append({"node": mi, "inner": inner, "t": 0.0, "life": delay, "pos": pos, "r": r, "kind": "circle"})

func _warn_line(pos: Vector3, dir: Vector3, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(Vector3(2.2, 0.02, 1.0))
	mi.material_override = _warn_mat(0.35)
	add_child(mi)
	var len := 12.0
	mi.position = pos + dir * len / 2.0 + Vector3(0, 0.04, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.scale = Vector3(1, 1, len)
	warns.append({"node": mi, "t": 0.0, "life": life, "kind": "line"})

func _update_boss_attacks(dt: float) -> void:
	var keep: Array = []
	for b in eshots:
		b["pos"] += b["vel"] * dt
		b["life"] -= dt
		b["rot"] += dt * 9.0
		var d: Vector3 = b["pos"] - player.position
		d.y = 0
		if d.length() < 0.5 and hurt_timer <= 0.0 and not game_over:
			_player_hurt(b["pos"])
			continue
		if b["life"] > 0.0 and absf(b["pos"].x) < AX + 3 and absf(b["pos"].z) < AZ + 3:
			keep.append(b)
	eshots = keep
	for w in warns.duplicate():
		w["t"] += dt
		var k: float = w["t"] / w["life"]
		var mi: MeshInstance3D = w["node"]
		if w["kind"] == "circle":
			(w["inner"] as MeshInstance3D).scale = Vector3(k, 1, k)
			if k >= 1.0:
				var d: Vector3 = player.position - w["pos"]
				d.y = 0
				_burst(w["pos"] + Vector3(0, 0.3, 0), Color("#ff7aa8"), 12, 5.0, true)
				_burst(w["pos"] + Vector3(0, 0.3, 0), Color(0.8, 0.9, 1.0, 0.9), 10, 4.0)
				_play("splash", 0.7, -5.0)
				shake = maxf(shake, 0.2)
				if d.length() < w["r"] and hurt_timer <= 0.0 and not game_over:
					_player_hurt(w["pos"])
		else:
			(mi.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.25 * sin(w["t"] * 30.0)
		if k >= 1.0:
			mi.queue_free()
			warns.erase(w)
	var m: MultiMesh = mm["eshot"].multimesh
	var n := mini(eshots.size(), 120)
	for i in n:
		var b: Dictionary = eshots[i]
		m.set_instance_transform(i, Transform3D(Basis(Vector3.UP, b["rot"]).scaled(Vector3.ONE * 1.6), b["pos"]))
		m.set_instance_color(i, Color.WHITE)
		m.set_instance_custom_data(i, Color(1, 1, 1, 0))
	m.visible_instance_count = n

# ---------- 떨어지는 아이템 ----------
var drops: Array = []
var heart_mesh: ArrayMesh
var magnet_mesh: ArrayMesh
var chest_mesh: ArrayMesh
func _drop(kind: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = {"heart": heart_mesh, "magnet": magnet_mesh, "chest": chest_mesh}[kind]
	mi.material_override = mat_vc
	add_child(mi)
	drops.append({"node": mi, "kind": kind, "pos": pos + Vector3(0, 0.5, 0), "t": 0.0})

func _update_drops(dt: float) -> void:
	for d in drops.duplicate():
		d["t"] += dt
		var mi: MeshInstance3D = d["node"]
		mi.position = d["pos"] + Vector3(0, 0.15 * sin(d["t"] * 4.0) + 0.2, 0)
		mi.rotation.y = d["t"] * 2.5
		mi.scale = Vector3.ONE * (1.0 + 0.08 * sin(d["t"] * 8.0)) * minf(1.0, d["t"] * 4.0)
		var dist := Vector2(player.position.x - d["pos"].x, player.position.z - d["pos"].z).length()
		if dist < 0.9:
			if d["kind"] == "chest":
				mi.queue_free()
				drops.erase(d)
				_open_chest()
				return
			if d["kind"] == "heart":
				hp = mini(max_hp(), hp + 1)
				_play("heal", 1.0, -3.0)
				_burst(player.position + Vector3(0, 1, 0), Color("#ff5c7a"), 10, 3.0, true)
				_refresh_ui()
			else:
				for g in gems:
					g["pull"] = true
				_play("magnet", 1.0, -3.0)
				_banner("자석! 딱지가 다 모여요", Color("#ff7a7a"))
			mi.queue_free()
			drops.erase(d)
		elif d["t"] > 25.0 and d["kind"] != "chest":
			mi.queue_free()
			drops.erase(d)

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
	gun.visible = mains.has("gun")
	var target := _nearest_enemy(8.5)
	if not target.is_empty():
		var tdir: Vector3 = target["pos"] - player.position
		tdir.y = 0
		face_dir = tdir.normalized()
	if not target.is_empty() and mains.has("gun"):
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
					"dmg": gs["dmg"], "size": gs["size"] * area_mult(), "splash": gs["splash"], "splash_p": gs["splash_p"]})
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
						if y["chain"] > 0 and rng.randf() < 0.35:
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
				if b["splash"] > 0.0 and rng.randf() < b["splash_p"]:
					_splash(e["pos"], b["splash"] * area_mult(), e, b["dmg"] * 0.6)
				if rng.randf() >= b["pierce"]:
					done = true
					break
		if done:
			_burst(b["pos"], Color(0.65, 0.88, 1.0, 0.85), 4, 2.5)
			bullets.erase(b)

func _splash(pos: Vector3, r: float, skip: Dictionary, dmg: float) -> void:
	_burst(pos + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1, 0.8), 12, 5.0)
	_play("splash", rng.randf_range(0.9, 1.1), -6.0)
	shake = maxf(shake, 0.1)
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
			g["vel"] = (g["vel"] as Vector3).lerp(d.normalized() * maxf(14.0, d.length() * 3.0), dt * 9.0)
		else:
			g["vel"].y -= 12.0 * dt
		g["pos"] += g["vel"] * dt
		if g["pos"].y < 0.08 and not g["pull"]:
			g["pos"].y = 0.08
			g["vel"] = Vector3(g["vel"].x * 0.5, absf(g["vel"].y) * 0.3, g["vel"].z * 0.5)
		if g["pull"] and d.length() < 0.4:
			if g.get("coin", false):
				var v := maxi(1, int(round(coin_mult())))
				run_coins += v
				_play("coin", rng.randf_range(1.0, 1.2), -10.0)
			else:
				got += 1
		else:
			keep.append(g)
	while keep.size() > 290:
		keep.pop_front()
		got += 1
	gems = keep
	if got > 0:
		gems_got += got
		_gain_xp(got)

func _gain_xp(v: int) -> void:
	xp_f += v * xp_mult()
	xp += int(xp_f)
	xp_f -= int(xp_f)
	if gem_sound_t <= 0.0:
		gem_sound_t = 0.05
		_play("gem", 1.2 + minf(xp, 20) * 0.02, -12.0)
	if xp >= xp_need and not paused:
		xp -= xp_need
		level += 1
		xp_need = 3 + level * 2 + int(level * level * 0.25)
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
	var counts := {}
	for kind in KINDS:
		counts[kind] = 0
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
		var es: float = e["scale"]
		var scl := Vector3(1.0 + sq * 0.45 + (1.0 - hop) * 0.05, 1.0 - sq * 0.4 - (1.0 - hop) * 0.06, 1.0 + sq * 0.45) * pop * es
		var fl: float = minf(1.0, e["flash"] / 0.05)
		if e["dead"] >= 0.0:
			var k: float = e["dead"] / 0.16
			scl = Vector3(1.0 + k * 0.7, 1.0 - k * 0.85, 1.0 + k * 0.7) * es
			fl = 1.0
		var tint := Color(1, 1, 1)
		if e["elite"]:
			tint = Color(1.25, 1.05, 0.55).lerp(Color(1.4, 1.3, 0.9), 0.5 + 0.5 * sin(elapsed * 6.0))
		if e["kind"] == "boss":
			tint = BOSS_TINT[stage]
		if e["kind"] == "eraser" and e["dash_t"] > 0.45:
			tint = Color(1.4, 0.8, 0.8)
		var tr := Transform3D(Basis(Vector3.UP, e["rot"]).scaled(scl), e["pos"] + Vector3(0, hop * 0.12, 0))
		m.set_instance_transform(i, tr)
		m.set_instance_color(i, Color.WHITE)
		m.set_instance_custom_data(i, Color(tint.r, tint.g, tint.b, fl))
		var ss := es * 0.76
		sh.set_instance_transform(shn, Transform3D(Basis().scaled(Vector3(ss, 1, ss)), e["pos"] + Vector3(0, 0.015, 0)))
		shn += 1
	for kind in KINDS:
		mm[kind].multimesh.visible_instance_count = counts[kind]
	sh.visible_instance_count = shn
	# 딱지
	var gm: MultiMesh = mm["gem"].multimesh
	var cm: MultiMesh = mm["coin"].multimesh
	var gi := 0
	var ci := 0
	for i in gems.size():
		var g: Dictionary = gems[i]
		if g.get("coin", false):
			if ci >= 200:
				continue
			cm.set_instance_transform(ci, Transform3D(Basis(Vector3.UP, elapsed * 5.0 + i) * Basis(Vector3.RIGHT, PI / 2), g["pos"] + Vector3(0, 0.1, 0)))
			cm.set_instance_color(ci, Color.WHITE)
			cm.set_instance_custom_data(ci, Color(1.0, 0.8, 0.2, 0.0))
			ci += 1
			continue
		gm.set_instance_transform(gi, Transform3D(Basis(Vector3.UP, elapsed * 3.0 + i).scaled(Vector3.ONE * 0.85), g["pos"]))
		var c: Color = g["col"]
		gm.set_instance_color(gi, Color.WHITE)
		gm.set_instance_custom_data(gi, Color(c.r, c.g, c.b, 0.0))
		gi += 1
	gm.visible_instance_count = gi
	cm.visible_instance_count = ci
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

var god := false
func _player_hurt(from: Vector3, amount := 1) -> void:
	if god:
		return
	nohit_t = 0.0
	hp -= amount
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
	if hp <= 0 and revives > 0:
		revives -= 1
		hp = maxi(2, max_hp() / 2)
		hurt_timer = 2.5
		_banner("오뚝이 부활!", Color("#c9a8f0"))
		_play("evo", 1.2, -2.0)
		for e in enemies:
			var d: Vector3 = e["pos"] - player.position
			if d.length() < 6.0:
				_hit_enemy(e, 80.0, d, 10.0, true)
		_refresh_ui()
	elif hp <= 0:
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
		if shot_mode == "bossview":
			player.position = Vector3(0, 0, 4)
			cam.position = Vector3(0, 4.5, 7.5)
			cam.look_at(Vector3(0, 0.8, -1.0), Vector3.UP)
			cam_off = cam.position - player.position
			for e in enemies:
				e["hp"] = 99999.0
		if shot_frames == (34 if shot_mode == "boss" else 110) and perf_frames == 0:
			get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % shot_mode)
			get_tree().quit()
	if perf_frames > 0 and Engine.get_process_frames() % 60 == 0:
		print("P f=%d t=%.1f fps=%d draws=%d enemies=%d parts=%d" % [Engine.get_process_frames(), elapsed, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), enemies.size(), parts.size()])
		if Engine.get_process_frames() >= perf_frames:
			get_tree().quit()
	if in_menu:
		_menu_idle(dt)
		return
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
	if boss_spawned and not boss.is_empty() and elapsed > BOSS_TIME + 60.0:
		boss["speed"] = KINDS["boss"]["speed"] * 2.0   # 1분 안에 못 잡으면 화나요
	_read_input()
	if auto_play:
		_auto_input(dt)
	player.position += move_dir * move_speed() * dt
	player.position.x = clampf(player.position.x, -AX, AX)
	player.position.z = clampf(player.position.z, -AZ, AZ)
	if obstacles.size() > 0:
		player.position = _push_out(player.position, 0.35)
	nohit_t += dt
	best_nohit = maxf(best_nohit, nohit_t)
	if flashlight:
		flashlight.position = player.position + Vector3(0, 2.2, 0.6)
	if _nearest_enemy(8.5).is_empty() and move_dir.length() > 0.1:
		face_dir = move_dir.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(face_dir.x, face_dir.z), dt * 14.0)
	hurt_timer -= dt
	model.visible = hurt_timer <= 0.0 or fmod(hurt_timer, 0.16) > 0.08
	var t0 := Time.get_ticks_usec()
	_spawn_logic(dt)
	_event_logic()
	_update_enemies(dt)
	_update_drops(dt)
	_update_boss_attacks(dt)
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
		print(("BOSS%d " % int(boss["hp"]) if not boss.is_empty() else "") + "T%d kills=%d lv=%d hp=%d enemies=%d gems=%d parts=%d mains=%s sup=%s evo=%s" % [int(elapsed), kills, level, hp, enemies.size(), gems.size(), parts.size(), mains, supports, evolved.keys()])

var menu_t := 0.0
func _menu_idle(dt: float) -> void:
	menu_t += dt
	move_dir = Vector3.ZERO
	face_dir = Vector3(0, 0, 1)
	model.rotation.y = lerp_angle(model.rotation.y, sin(menu_t * 0.6) * 0.35, dt * 3.0)
	_animate_player(dt)
	if fmod(menu_t, 2.5) < dt:
		recoil = 1.0
	cam.position = Vector3(sin(menu_t * 0.2) * 0.4, 2.3, 5.2)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	gun.visible = mains.has("gun")

func _push_out(pos: Vector3, r: float) -> Vector3:
	for o in obstacles:
		var c: Vector3 = o[0]
		var h: Vector2 = o[1]
		var dx := pos.x - c.x
		var dz := pos.z - c.z
		var px := h.x + r - absf(dx)
		var pz := h.y + r - absf(dz)
		if px > 0.0 and pz > 0.0:
			if px < pz:
				pos.x += px * signf(dx if dx != 0.0 else 1.0)
			else:
				pos.z += pz * signf(dz if dz != 0.0 else 1.0)
	return pos

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
	else:
		# 안전하면 딱지,아이템 주우러 가요
		var best := Vector3.ZERO
		var bd := 7.0
		for g in gems:
			var d: float = (g["pos"] as Vector3).distance_to(player.position)
			if d < bd:
				bd = d
				best = g["pos"]
		for d in drops:
			best = d["pos"]
			bd = 0.0
			break
		if best != Vector3.ZERO:
			var v := (best - player.position)
			auto_dir = Vector2(v.x, v.z).normalized()
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
	coin_label = _label("동전 0", 30, Color("#ffd23f"), hud)
	coin_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_label.offset_left = -260
	coin_label.offset_right = -24
	coin_label.offset_top = 70
	var pb := _small_btn("II", Color("#8a7a95"), 30)
	pb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pb.offset_left = -96
	pb.offset_right = -24
	pb.offset_top = 116
	pb.offset_bottom = 186
	hud.add_child(pb)
	pb.pressed.connect(_pause_menu)
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

func _pause_menu() -> void:
	if paused or game_over:
		return
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	stick_base.visible = false
	card_panel = Control.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(card_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	var t := _label("잠깐 쉬어요", 60, Color.WHITE, card_panel)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_left = -300
	t.offset_right = 300
	t.offset_top = -260
	t.offset_bottom = -180
	var go := _small_btn("계속하기", Color("#4fa8e8"), 44)
	go.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	go.offset_left = -170
	go.offset_right = 170
	go.offset_top = -120
	go.offset_bottom = -20
	card_panel.add_child(go)
	go.pressed.connect(func():
		card_panel.queue_free()
		card_panel = null
		paused = false)
	var q := _small_btn("그만하고 나가기", Color("#e8524a"), 36)
	q.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	q.offset_left = -170
	q.offset_right = 170
	q.offset_top = 20
	q.offset_bottom = 110
	card_panel.add_child(q)
	q.pressed.connect(func():
		card_panel.queue_free()
		card_panel = null
		paused = false
		_end_game(false))

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

var banner_label: Label
var banner_t := 0.0
var boss_bar_bg: Panel
var boss_bar: ColorRect
func _banner(text: String, col: Color) -> void:
	if banner_label == null:
		banner_label = _label("", 46, col, hud)
		banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner_label.offset_left = -360
		banner_label.offset_right = 360
		banner_label.offset_top = -330
		banner_label.offset_bottom = -260
		banner_label.pivot_offset = Vector2(360, 35)
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", col)
	banner_t = 2.2

func _update_hud() -> void:
	var left := maxf(0.0, BOSS_TIME - elapsed)
	if boss_spawned:
		timer_label.text = "보스전!"
	else:
		timer_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	if banner_label:
		banner_t -= get_process_delta_time()
		banner_label.visible = banner_t > 0.0
		banner_label.scale = Vector2.ONE * (1.0 + maxf(0.0, banner_t - 1.9) * 2.0)
		banner_label.modulate.a = clampf(banner_t * 2.0, 0, 1)
	if boss_spawned and not boss.is_empty():
		if boss_bar_bg == null:
			boss_bar_bg = Panel.new()
			boss_bar_bg.add_theme_stylebox_override("panel", _round_panel(Color(0.2, 0.1, 0.25, 0.8), 14, Color("#3a2148"), 4))
			boss_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			boss_bar_bg.offset_left = -260
			boss_bar_bg.offset_right = 260
			boss_bar_bg.offset_top = 128
			boss_bar_bg.offset_bottom = 162
			boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud.add_child(boss_bar_bg)
			boss_bar = ColorRect.new()
			boss_bar.color = Color("#ff5c7a")
			boss_bar.position = Vector2(6, 6)
			boss_bar.size = Vector2(508, 22)
			boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boss_bar_bg.add_child(boss_bar)
			var bl := _label("분실물함 대왕귀신", 26, Color.WHITE, boss_bar_bg, 7)
			bl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_bar.size.x = 508.0 * clampf(boss["hp"] / boss["max_hp"], 0, 1)
	xp_bar.size.x = xp_bar_bg.size.x * float(xp) / float(xp_need)
	kill_label.text = "귀신 %d" % kills
	coin_label.text = "동전 %d" % run_coins
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
	_show_cards(pick)

func _show_cards(pick: Array) -> void:
	var is_evo: bool = pick[0]["type"] == "evo"
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
	if rerolls > 0 and not is_evo:
		var rb := _small_btn("다시 뽑기 (%d)" % rerolls, Color("#58c6f2"))
		rb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		rb.offset_left = -170
		rb.offset_right = 170
		rb.offset_top = -190
		rb.offset_bottom = -100
		card_panel.add_child(rb)
		rb.pressed.connect(func():
			rerolls -= 1
			card_panel.queue_free()
			card_panel = null
			_play("pick", 0.8, -3.0)
			_show_cards(_card_pool()))

func _small_btn(text: String, col: Color, fs := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color("#3a2148"))
	b.add_theme_constant_override("outline_size", 8)
	var st := _round_panel(col, 26, Color("#3a2148"), 5)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", _round_panel(col.darkened(0.15), 26, Color("#3a2148"), 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _round_panel(Color("#b9b0bf"), 26, Color("#3a2148"), 5))
	return b

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
			tag = "새로!" if cur == 0 else "Lv.%d > %d" % [cur, cur + 1]
			icon = d["icon"]
			col = Color(d["col"])
			var pn: String = SUPPORTS[d["partner"]]["name"]
			setline = "세트 짝꿍: %s%s" % [pn, "  (있어요!)" if supports.has(d["partner"]) else ""]
		"sup":
			var d: Dictionary = SUPPORTS[c["id"]]
			var cur: int = supports.get(c["id"], 0)
			nm_t = d["name"]
			desc = d["desc"]
			tag = "새로!" if cur == 0 else "Lv.%d > %d" % [cur, cur + 1]
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

func _apply_card(c: Dictionary, from_chest := false) -> void:
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
	if from_chest:
		_refresh_ui()
		_refresh_slots()
		return
	if card_panel:
		card_panel.queue_free()
		card_panel = null
	paused = false
	_play("pick", 1.0, -3.0)
	_refresh_ui()
	_refresh_slots()

func _open_chest() -> void:
	chests_opened += 1
	var n := 3 if rng.randf() < 0.2 + 0.06 * Save.shop_lv("luck") else 1
	var got: Array = []
	for i in n:
		var pool := _card_pool()
		var c: Dictionary = pool[0] if pool[0]["type"] == "evo" else pool[rng.randi() % pool.size()]
		got.append(c)
		_apply_card(c, true)
	var cc := int(round((5 + 3 * n) * coin_mult()))
	run_coins += cc
	_play("evo", 1.1, -3.0)
	shake = 0.25
	if auto_play:
		return
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	stick_base.visible = false
	card_panel = Control.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(card_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	var title := _label("보물 상자!" if n == 1 else "대박! 보물 3개!", 64, Color("#ffdf3d"), card_panel)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_left = -340
	title.offset_right = 340
	title.offset_top = 230
	title.pivot_offset = Vector2(340, 40)
	title.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -300
	vb.offset_right = 300
	vb.offset_top = -300
	vb.offset_bottom = 380
	vb.add_theme_constant_override("separation", 20)
	card_panel.add_child(vb)
	for i in got.size():
		var c: Dictionary = got[i]
		var info := _card_info(c)
		var row := Panel.new()
		row.custom_minimum_size = Vector2(600, 130)
		row.add_theme_stylebox_override("panel", _round_panel(Color("#fff1b8") if info["gold"] else Color("#fff8e8"), 26, info["col"], 8))
		vb.add_child(row)
		_badge(row, info["icon"], info["col"], 90, Vector2(20, 20), info["gold"])
		var nm := _label(info["name"] + "  " + info["tag"], 40, Color("#3a2148"), row, 0)
		nm.position = Vector2(130, 18)
		var ds := _label(info["desc"], 28, Color("#5b4a66"), row, 0)
		ds.position = Vector2(130, 74)
		row.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.35 + i * 0.35)
		tw.tween_property(row, "modulate:a", 1.0, 0.15)
		tw.tween_callback(func(): _play("pick", 1.0 + i * 0.15, -3.0))
	var cl := _label("동전 +%d" % cc, 40, Color("#ffd23f"), vb)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := _small_btn("좋아!", Color("#ff9a2f"), 44)
	ok.custom_minimum_size = Vector2(300, 100)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	ok.pressed.connect(func():
		card_panel.queue_free()
		card_panel = null
		paused = false)

func _card_info(c: Dictionary) -> Dictionary:
	var info := {"name": "뽀빠이 과자", "desc": "하트 2칸 회복", "tag": "", "icon": "♥", "col": Color("#ff5c7a"), "gold": false}
	match c["type"]:
		"evo":
			var d: Dictionary = MAINS[c["id"]]
			info = {"name": d["evo"], "desc": d["evo_desc"], "tag": "진화!", "icon": d["icon"], "col": Color("#ffc928"), "gold": true}
		"main":
			var d: Dictionary = MAINS[c["id"]]
			var cur: int = mains.get(c["id"], 0)
			info = {"name": d["name"], "desc": d["desc"][maxi(0, cur - 1)], "tag": "Lv.%d" % cur, "icon": d["icon"], "col": Color(d["col"]), "gold": false}
		"sup":
			var d: Dictionary = SUPPORTS[c["id"]]
			info = {"name": d["name"], "desc": d["desc"], "tag": "Lv.%d" % supports.get(c["id"], 0), "icon": d["icon"], "col": Color(d["col"]), "gold": false}
	return info

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
	var bonus := int(round((60 + 40 * grade) * (1.0 + 0.1 * Save.shop_lv("coin")))) if win else 0
	bonus += int(kills / 14.0 * (1.0 + 0.1 * Save.shop_lv("coin")))
	run_coins += bonus
	var result := {"stage": stage, "grade": grade, "win": win, "kills": kills, "elites": elites_killed, "evos": evolved.size(),
		"gems": gems_got, "coins": run_coins, "combo": best_combo, "nohit": int(best_nohit), "time": int(elapsed),
		"chests": chests_opened, "kinds": kinds_killed}
	var rec := {"news": []}
	if not auto_play and shot_mode == "":
		rec = Save.record_run(result)
	if auto_play:
		print("END coins=%d chests=%d elites=%d " % [run_coins, chests_opened, elites_killed] + "win=%s t=%d kills=%d lv=%d mains=%s sup=%s evo=%s" % [win, int(elapsed), kills, level, mains, supports, evolved.keys()])
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
	box_p.offset_top = -420
	box_p.offset_bottom = 420
	end_panel.add_child(box_p)
	var t := _label("대왕귀신을 물리쳤다!" if win else "철수가 기절했어요", 52, Color("#ffdf3d") if win else Color("#ff7aa8"), box_p)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 46
	var evo_names: Array = []
	for id in evolved:
		evo_names.append(MAINS[id]["evo"])
	var lines := "버틴 시간  %d:%02d\n물리친 귀신  %d마리\n레벨  %d\n진화  %s\n\n동전 +%d%s" % [int(elapsed) / 60, int(elapsed) % 60, kills, level,
		", ".join(evo_names) if evo_names.size() > 0 else "아직 없어요", run_coins, ("  (보너스 %d 포함)" % bonus) if bonus > 0 else ""]
	for n in rec["news"]:
		lines += "\n★ " + n
	var s := _label(lines, 32, Color("#3a2148"), box_p, 0)
	s.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.offset_top = 140
	s.offset_left = 20
	s.offset_right = -20
	var b := Button.new()
	b.text = "한 판 더!"
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", Color.WHITE)
	var st := _round_panel(Color("#4fa8e8"), 30, Color("#3a2148"), 6)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", _round_panel(Color("#3d8ccc"), 30, Color("#3a2148"), 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -250
	b.offset_right = -10
	b.offset_top = -140
	b.offset_bottom = -44
	box_p.add_child(b)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	var hb := _small_btn("메인으로", Color("#ff9a2f"), 40)
	hb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hb.offset_left = 10
	hb.offset_right = 250
	hb.offset_top = -140
	hb.offset_bottom = -44
	box_p.add_child(hb)
	hb.pressed.connect(func():
		Save.mode = "menu"
		get_tree().reload_current_scene())

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
	sounds["coin"] = _synth(0.18, func(t: float, st: Dictionary) -> float:
		var f := 1568.0 if t < 0.05 else 2093.0
		return (1.0 if sin(t * f * TAU) > 0 else -1.0) * exp(-t * 18.0) * 0.18)
	sounds["splash"] = _synth(0.3, func(t: float, st: Dictionary) -> float:
		st["lp"] = lerpf(st["lp"], r.randf_range(-1, 1), 0.25)
		st["ph"] += (240.0 - t * 400.0) / 22050.0
		return (st["lp"] * 0.9 + sin(st["ph"] * TAU) * 0.6 * exp(-t * 20.0)) * exp(-t * 10.0) * 0.6)
	sounds["heal"] = _synth(0.4, func(t: float, st: Dictionary) -> float:
		var f := 880.0 if t < 0.12 else 1320.0
		return sin(t * f * TAU) * exp(-fmod(t, 0.12) * 12.0) * 0.45)
	sounds["magnet"] = _synth(0.5, func(t: float, st: Dictionary) -> float:
		st["ph"] += (300.0 + t * 1800.0) / 22050.0
		return sin(st["ph"] * TAU) * (0.6 + 0.4 * sin(t * 40.0 * TAU)) * exp(-t * 4.0) * 0.4)
	sounds["warn"] = _synth(0.9, func(t: float, st: Dictionary) -> float:
		var on := 1.0 if fmod(t, 0.3) < 0.2 else 0.0
		st["ph"] += (330.0 if fmod(t, 0.6) < 0.3 else 262.0) / 22050.0
		return (1.0 if fmod(st["ph"], 1.0) < 0.5 else -1.0) * on * 0.22)
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
	god = true
	if shot_mode == "bossview":
		cam_off = Vector3(0, 6.0, 9.0)
		boss_spawned = true
		boss = _make_enemy("boss", Vector3(0, 0, -3))
		boss["speed"] = 0.0
		boss["summon"] = 999.0
		for k in ["kettle", "eraser", "dust", "paper", "egg"]:
			var e := _make_enemy(k, Vector3(-3.0 + ["kettle", "eraser", "dust", "paper", "egg"].find(k) * 1.5, 0, 0.5))
			e["speed"] = 0.0
		spawn_timer = 999.0
		next_elite = 9999.0
		return
	if shot_mode == "hero":
		cam_off = Vector3(1.2, 1.6, 3.2)
		cam.position = cam_off
		spawn_timer = 999.0
		return
	elapsed = 60.0
	for i in (150 if shot_mode == "evo_perf" else 40):
		var a := rng.randf() * TAU
		var kinds := ["paper", "paper", "egg", "kettle", "eraser", "dust"]
		_make_enemy(kinds[i % kinds.size()] if shot_mode != "cards" else "paper", Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 8.0), i == 5)
	if shot_mode == "boss":
		boss_spawned = true
		boss = _make_enemy("boss", Vector3(0, 0, -4))
		boss["pat"] = "shoes"
		boss["pat_t"] = 0.9
		boss["stage"] = 0
		_warn_circle(Vector3(1.5, 0, 1.0), 1.5, 3.0)
		_warn_line(Vector3(-3, 0, -3), Vector3(0.5, 0, 1).normalized(), 3.0)
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
	if shot_mode == "chest":
		mains["ddakji"] = 2
		main_order.append("ddakji")
		supports["bottle"] = 1
		support_order.append("bottle")
		Save.data["shop"]["luck"] = 3
		rng.seed = 3
		_open_chest()
