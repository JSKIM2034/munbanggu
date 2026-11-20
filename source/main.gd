extends Node3D
# 문방구 퇴마단 - 첫 버전
# 철수가 운동장에서 물총으로 몰려오는 귀신을 물리쳐요. 공격은 자동, 이동은 조이스틱.

const ARENA := 13.0                 # 운동장 반지름(네모)
const CAM_OFFSET := Vector3(0, 8.2, 8.4)
var cam_off := CAM_OFFSET
const RUN_TIME := 300.0             # 5분 버티면 승리

# ---------- 상태 ----------
var rng := RandomNumberGenerator.new()
var cam: Camera3D
var player: Node3D
var model: Node3D
var skel: Skeleton3D
var gun: Node3D
var bones := {}                     # 이름 -> [id, rest_q, global_rest_q]
var enemies: Array = []
var bullets: Array = []
var gems: Array = []
var fx: Array = []                  # 수명이 있는 효과들 {node, t, life, kind, vel}

var move_dir := Vector3.ZERO
var face_dir := Vector3(0, 0, 1)
var walk_phase := 0.0
var run_amt := 0.0
var recoil := 0.0
var fire_timer := 0.0
var spawn_timer := 1.0
var elapsed := 0.0
var shake := 0.0
var hurt_timer := 0.0
var hitstop_left := 0.0
var combo := 0
var combo_timer := 0.0
var paused := false
var game_over := false
var kills := 0

# 성장
var hp := 5
var max_hp := 5
var level := 1
var xp := 0
var xp_need := 5
var stat := {
	"fire_rate": 2.6,      # 초당 발사
	"damage": 10.0,
	"shots": 1,
	"pierce": 0,
	"speed": 4.2,
	"magnet": 2.2,
	"splash": 0.0,         # 물풍선 반경
	"range": 7.5,
}

# 입력(조이스틱)
var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO

# UI
var ui: CanvasLayer
var hearts_label: Label
var timer_label: Label
var kill_label: Label
var xp_bar: ColorRect
var xp_bar_bg: ColorRect
var level_label: Label
var stick_base: Control
var stick_knob: Control
var card_panel: Control
var end_panel: Control
var combo_label: Label
var font: Font

# 재료
var mat_cache := {}
var flash_mat: StandardMaterial3D
var sounds := {}
var players_audio: Array = []

# 테스트용
var auto_play := false
var shot_mode := ""

func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	auto_play = args.has("--auto")
	for a in args:
		if a.begins_with("--shot="):
			shot_mode = a.substr(7)
	if args.has("--seed"):
		rng.seed = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_font()
	_make_world()
	_make_player()
	_make_ui()
	_make_sounds()
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1, 1, 1, 0.85)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if shot_mode != "":
		_setup_shot()

# =========================================================
# 세계: 운동장, 학교, 나무, 구령대
# =========================================================
func M(col: Color, rough := 0.85, unshaded := false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [col.to_html(), rough, unshaded]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cache[key] = m
	return m

func mesh_node(mesh: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi

func box(size: Vector3, col: Color, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh_node(b, M(col), pos, parent)

func sphere(r: float, col: Color, pos: Vector3, parent: Node = null, h := -1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0 else h
	s.radial_segments = 16
	s.rings = 8
	return mesh_node(s, M(col), pos, parent)

func cyl(r: float, h: float, col: Color, pos: Vector3, parent: Node = null, r2 := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0 else r2
	c.height = h
	c.radial_segments = 18
	return mesh_node(c, M(col), pos, parent)

func _make_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#9fd8ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#fff1e0")
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = false
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_energy = 0.75
	sun.light_color = Color("#fff4dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 42.0
	cam.position = CAM_OFFSET
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	# 흙 운동장 (셰이더로 모래알과 하얀 트랙 선)
	var ground := PlaneMesh.new()
	ground.size = Vector2(60, 60)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 wp;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
  vec2 p = wp.xz;
  vec3 sand = vec3(0.88,0.75,0.57);
  vec3 dark = vec3(0.80,0.65,0.47);
  float big = n(p*0.35);
  float grain = n(p*14.0);
  vec3 c = mix(sand, dark, big*0.55) * (0.93 + grain*0.1);
  // 타원 트랙 선 두 줄
  float ex = p.x/11.0; float ez = p.y/8.0;
  float d = sqrt(ex*ex + ez*ez);
  float line1 = 1.0 - smoothstep(0.0, 0.012, abs(d - 1.0));
  float line2 = 1.0 - smoothstep(0.0, 0.012, abs(d - 0.86));
  // 운동장 밖은 잔디 테두리
  float out_g = smoothstep(14.0, 14.4, max(abs(p.x), abs(p.y)));
  c = mix(c, vec3(0.98,0.97,0.92), max(line1, line2) * 0.85);
  c = mix(c, vec3(0.45,0.70,0.36) * (0.9 + grain*0.15), out_g);
  ALBEDO = c;
  ROUGHNESS = 1.0;
}
"""
	sm.shader = sh
	mesh_node(ground, sm, Vector3.ZERO)

	# 학교 건물 (뒤쪽)
	var school := Node3D.new()
	school.position = Vector3(0, 0, -19)
	add_child(school)
	box(Vector3(30, 7.5, 4), Color("#f3e6c8"), Vector3(0, 3.75, 0), school)
	box(Vector3(30.6, 0.5, 4.6), Color("#c0563f"), Vector3(0, 7.7, 0), school)
	for fl in range(3):
		for i in range(12):
			var x := -13.2 + i * 2.4
			if abs(x) < 1.5:
				continue
			box(Vector3(1.7, 1.3, 0.12), Color("#7fb7d9"), Vector3(x, 1.5 + fl * 2.2, 2.02), school)
			box(Vector3(1.8, 0.12, 0.2), Color("#5f8f4e"), Vector3(x, 0.82 + fl * 2.2, 2.05), school)
	box(Vector3(2.4, 2.6, 0.2), Color("#6b4a32"), Vector3(0, 1.3, 2.05), school)   # 현관
	cyl(0.9, 0.15, Color("#ffffff"), Vector3(0, 6.2, 2.1), school).rotation_degrees.x = 90  # 시계
	box(Vector3(0.06, 0.6, 0.05), Color("#333333"), Vector3(0, 6.35, 2.2), school)
	# 구령대
	box(Vector3(6, 1.0, 3), Color("#d9d2c3"), Vector3(0, 0.5, 3.3), school)
	box(Vector3(6.4, 0.18, 3.4), Color("#a9a294"), Vector3(0, 1.05, 3.3), school)
	# 철봉, 축구 골대
	_goal(Vector3(-15.5, 0, 0), 90)
	_goal(Vector3(15.5, 0, 0), -90)
	for i in range(3):
		var x := 9.0 + i * 1.4
		cyl(0.05, 1.2 + i * 0.25, Color("#d94f3d"), Vector3(x, (1.2 + i * 0.25) / 2.0, -15.2))
		cyl(0.05, 1.2 + i * 0.25, Color("#d94f3d"), Vector3(x + 1.2, (1.2 + i * 0.25) / 2.0, -15.2))
		var bar := cyl(0.035, 1.2, Color("#cccccc"), Vector3(x + 0.6, 1.2 + i * 0.25, -15.2))
		bar.rotation_degrees.z = 90
	# 나무와 울타리
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		_tree(Vector3(side * rng.randf_range(17.0, 19.5), 0, -14.0 + (i / 2) * 4.2 + rng.randf_range(-0.8, 0.8)))
	for i in range(-14, 15):
		cyl(0.06, 0.9, Color("#e8e2d0"), Vector3(i * 1.0, 0.45, 15.0))
		cyl(0.06, 0.9, Color("#e8e2d0"), Vector3(-15.0, 0.45, i * 1.0))
		cyl(0.06, 0.9, Color("#e8e2d0"), Vector3(15.0, 0.45, i * 1.0))
	box(Vector3(30, 0.08, 0.08), Color("#e8e2d0"), Vector3(0, 0.8, 15.0))
	box(Vector3(0.08, 0.08, 30), Color("#e8e2d0"), Vector3(-15.0, 0.8, 0))
	box(Vector3(0.08, 0.08, 30), Color("#e8e2d0"), Vector3(15.0, 0.8, 0))

func _goal(pos: Vector3, rot: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = rot
	add_child(g)
	cyl(0.07, 2.2, Color("#ffffff"), Vector3(-2.5, 1.1, 0), g)
	cyl(0.07, 2.2, Color("#ffffff"), Vector3(2.5, 1.1, 0), g)
	var top := cyl(0.07, 5.0, Color("#ffffff"), Vector3(0, 2.2, 0), g)
	top.rotation_degrees.z = 90
	box(Vector3(5, 2.2, 0.02), Color(1, 1, 1, 0.25), Vector3(0, 1.1, -1.0), g)

func _tree(pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	add_child(t)
	cyl(0.22, 1.6, Color("#8a5a3b"), Vector3(0, 0.8, 0), t, 0.3)
	var s := rng.randf_range(0.9, 1.3)
	sphere(1.3 * s, Color("#5fae4e"), Vector3(0, 2.4 * s, 0), t)
	sphere(0.9 * s, Color("#74c25b"), Vector3(0.6, 2.9 * s, 0.4), t)
	sphere(0.8 * s, Color("#4f9a43"), Vector3(-0.7, 2.2 * s, 0.3), t)

# =========================================================
# 철수
# =========================================================
func _make_player() -> void:
	player = Node3D.new()
	add_child(player)
	model = (load("res://models/chulsoo.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * 1.5
	player.add_child(model)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	skel = sk[0] as Skeleton3D
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		var g := skel.get_bone_global_rest(i).basis.get_rotation_quaternion()
		bones[n] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), g]
	# 그림자 동그라미
	var sh := sphere(0.42, Color(0, 0, 0, 0.22), Vector3(0, 0.02, 0), player, 0.02)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 물총 (노랑+하늘색 장난감)
	gun = Node3D.new()
	player.add_child(gun)
	var body := box(Vector3(0.16, 0.13, 0.34), Color("#4fa8e8"), Vector3(0, 0, 0.02), gun)
	body.mesh.size = Vector3(0.16, 0.13, 0.34)
	var tank := cyl(0.085, 0.24, Color("#ffd23f"), Vector3(0, 0.13, -0.02), gun)
	tank.rotation_degrees.x = 90
	sphere(0.085, Color("#ffd23f"), Vector3(0, 0.13, 0.1), gun)
	sphere(0.085, Color("#ffd23f"), Vector3(0, 0.13, -0.14), gun)
	var nozzle := cyl(0.04, 0.12, Color("#ff8a3d"), Vector3(0, 0.0, 0.24), gun)
	nozzle.rotation_degrees.x = 90
	box(Vector3(0.07, 0.14, 0.08), Color("#ffd23f"), Vector3(0, -0.11, -0.06), gun)
	gun.scale = Vector3.ONE * 0.95

func pose_bone(name: String, q_model: Quaternion) -> void:
	if not bones.has(name):
		return
	var b: Array = bones[name]
	var g: Quaternion = b[2]
	var local := g.inverse() * q_model * g
	skel.set_bone_pose_rotation(b[0], b[1] * local)

func Q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))

func _animate_player(dt: float) -> void:
	var speed := move_dir.length()
	run_amt = move_toward(run_amt, 1.0 if speed > 0.1 else 0.0, dt * 6.0)
	walk_phase += dt * (13.0 * run_amt + 2.2 * (1.0 - run_amt))
	recoil = move_toward(recoil, 0.0, dt * 8.0)
	var s := sin(walk_phase)
	var c := cos(walk_phase)
	var sw := 38.0 * run_amt
	# 다리 (모델은 +Z가 앞, 다리 앞으로 = X축 음의 회전)
	pose_bone("thighL", Q(Vector3.RIGHT, -sw * s))
	pose_bone("thighR", Q(Vector3.RIGHT, sw * s))
	pose_bone("shinL", Q(Vector3.RIGHT, 30.0 * run_amt * max(0.0, -c)))
	pose_bone("shinR", Q(Vector3.RIGHT, 30.0 * run_amt * max(0.0, c)))
	# 몸통 통통 + 앞으로 기울기
	var bob := absf(s) * 0.07 * run_amt + sin(walk_phase * 0.5) * 0.008 * (1.0 - run_amt)
	model.position.y = bob
	model.rotation_degrees.x = 8.0 * run_amt
	pose_bone("spine", Q(Vector3.UP, 7.0 * s * run_amt))
	pose_bone("head", Q(Vector3.RIGHT, -4.0 * run_amt + recoil * 6.0) * Q(Vector3.FORWARD, 3.0 * s * run_amt))
	# 오른팔(-X 쪽, armL): 물총 들고 앞으로
	pose_bone("armL", Q(Vector3.RIGHT, -62.0 + recoil * 14.0) * Q(Vector3.BACK, 66.0) * Q(Vector3.UP, -18.0))
	pose_bone("foreL", Q(Vector3.UP, -30.0))
	# 왼팔(+X): 물총 받치기
	pose_bone("armR", Q(Vector3.RIGHT, -55.0 + recoil * 10.0) * Q(Vector3.BACK, -70.0) * Q(Vector3.UP, 32.0))
	pose_bone("foreR", Q(Vector3.UP, 38.0))
	skel.force_update_all_bone_transforms()
	# 물총은 오른손 위치에
	var hand_t := skel.get_bone_global_pose(bones["handL"][0])
	var hp_world := skel.global_transform * hand_t.origin
	gun.global_position = hp_world + player.global_transform.basis * Vector3(0.06, 0.02, 0.05)
	gun.rotation = Vector3(deg_to_rad(-recoil * 18.0), model.rotation.y, 0)

# =========================================================
# 귀신
# =========================================================
func _face(parent: Node3D, z: float, y: float, scale := 1.0, angry := true) -> void:
	for sx in [-1.0, 1.0]:
		var e := sphere(0.07 * scale, Color("#3a2148"), Vector3(sx * 0.1 * scale, y, z), parent)
		e.scale = Vector3(1, 1.2, 0.5)
		sphere(0.025 * scale, Color("#ffffff"), Vector3(sx * 0.1 * scale + 0.02, y + 0.03 * scale, z + 0.035 * scale), parent)
		var bl := sphere(0.05 * scale, Color("#ff9db0"), Vector3(sx * 0.17 * scale, y - 0.08 * scale, z - 0.01), parent)
		bl.scale = Vector3(1, 0.6, 0.3)
		if angry:
			var br := box(Vector3(0.09, 0.02, 0.02) * scale, Color("#3a2148"), Vector3(sx * 0.1 * scale, y + 0.11 * scale, z + 0.01), parent)
			br.rotation_degrees.z = -sx * 22.0
	var mo := sphere(0.035 * scale, Color("#7a2f4a"), Vector3(0, y - 0.1 * scale, z), parent)
	mo.scale = Vector3(1.3, 0.6, 0.4)

func _make_enemy(kind: String, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	root.scale = Vector3.ONE * 1.25
	var e := {"node": root, "body": body, "kind": kind, "vel": Vector3.ZERO, "flash": 0.0,
		"squash": 0.0, "phase": rng.randf() * TAU, "dead": false, "spawn": 0.0}
	if kind == "paper":
		var col := Color("#c9a8f0")
		var roll := cyl(0.3, 0.46, col, Vector3(0, 0.45, 0), body)
		cyl(0.11, 0.47, Color("#9b7a5a"), Vector3(0, 0.455, 0), body)
		var tail := box(Vector3(0.36, 0.5, 0.02), Color("#e6d6fb"), Vector3(0.28, 0.32, -0.12), body)
		tail.rotation_degrees = Vector3(0, -40, -18)
		e["tail"] = tail
		_face(body, 0.29, 0.47, 1.0, true)
		for sx in [-1.0, 1.0]:
			sphere(0.08, col.darkened(0.08), Vector3(sx * 0.33, 0.36, 0.08), body)
			sphere(0.08, col.darkened(0.12), Vector3(sx * 0.13, 0.1, 0.0), body)
		roll.name = "main"
		e["hp"] = 22.0
		e["speed"] = 1.55
		e["xp"] = 1
		e["radius"] = 0.38
	else: # egg
		var col := Color("#a9d4f5")
		var egg := sphere(0.3, col, Vector3(0, 0.46, 0), body, 0.74)
		_face(body, 0.27, 0.48, 0.95, true)
		var crack := box(Vector3(0.18, 0.02, 0.02), Color("#6e95b8"), Vector3(-0.05, 0.78, 0.17), body)
		crack.rotation_degrees.z = 30
		for sx in [-1.0, 1.0]:
			sphere(0.07, col.darkened(0.1), Vector3(sx * 0.3, 0.38, 0.06), body)
			sphere(0.07, col.darkened(0.15), Vector3(sx * 0.12, 0.08, 0.0), body)
		egg.name = "main"
		e["hp"] = 12.0
		e["speed"] = 2.7
		e["xp"] = 1
		e["radius"] = 0.34
	e["max_hp"] = e["hp"]
	body.scale = Vector3(0.01, 0.01, 0.01)
	enemies.append(e)

func _spawn_logic(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer > 0.0:
		return
	var t := elapsed / RUN_TIME
	spawn_timer = lerpf(0.9, 0.25, clampf(t * 1.4, 0, 1))
	var count := 2 + int(t * 5.0)
	if enemies.size() > 70:
		return
	for i in count:
		var a := rng.randf() * TAU
		var p := player.position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.5, 10.5)
		p.x = clampf(p.x, -ARENA, ARENA)
		p.z = clampf(p.z, -ARENA, ARENA)
		if p.distance_to(player.position) < 5.0:
			p = player.position - (p - player.position).normalized() * 8.0
		var kind := "egg" if rng.randf() < clampf(0.15 + t * 0.6, 0, 0.5) else "paper"
		_make_enemy(kind, p)

func _update_enemies(dt: float) -> void:
	for e in enemies:
		var n: Node3D = e["node"]
		var body: Node3D = e["body"]
		e["spawn"] = minf(1.0, e["spawn"] + dt * 3.0)
		var to_p: Vector3 = player.position - n.position
		to_p.y = 0
		var dist := to_p.length()
		var want := to_p.normalized() * float(e["speed"]) if dist > 0.01 else Vector3.ZERO
		var v: Vector3 = e["vel"]
		v = v.lerp(want, dt * 4.0)
		e["vel"] = v
		n.position += v * dt
		n.position.x = clampf(n.position.x, -ARENA - 1, ARENA + 1)
		n.position.z = clampf(n.position.z, -ARENA - 1, ARENA + 1)
		if dist > 0.01:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to_p.x, to_p.z), dt * 8.0)
		# 통통 튀며 다가오기 + 맞으면 찌그러짐
		e["phase"] += dt * (7.0 if e["kind"] == "paper" else 10.0)
		var hop := absf(sin(e["phase"]))
		e["squash"] = move_toward(e["squash"], 0.0, dt * 5.0)
		var sq: float = e["squash"]
		var sp := float(e["spawn"])
		var pop := sp * (1.0 + sin(sp * PI) * 0.35)
		body.position.y = hop * 0.12
		body.scale = Vector3(1.0 + sq * 0.45 + (1.0 - hop) * 0.05, 1.0 - sq * 0.4 - (1.0 - hop) * 0.06, 1.0 + sq * 0.45) * pop
		if e.has("tail"):
			(e["tail"] as Node3D).rotation_degrees.x = sin(e["phase"] * 1.3) * 25.0
		# 반짝
		if e["flash"] > 0.0:
			e["flash"] -= dt
			if e["flash"] <= 0.0:
				_set_overlay(body, null)
		# 플레이어와 부딪힘
		if dist < float(e["radius"]) + 0.3 and hurt_timer <= 0.0 and not game_over:
			_player_hurt(n.position)
	# 귀신끼리 겹치지 않게 살짝 밀기
	for i in enemies.size():
		var a: Node3D = enemies[i]["node"]
		for j in range(i + 1, mini(enemies.size(), i + 12)):
			var b: Node3D = enemies[j]["node"]
			var d := a.position - b.position
			d.y = 0
			var l := d.length()
			if l < 0.6 and l > 0.001:
				var push := d / l * (0.6 - l) * 0.5
				a.position += push
				b.position -= push

func _set_overlay(n: Node, m: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_overlay = m
		_set_overlay(c, m)

# =========================================================
# 물총
# =========================================================
func _nearest_enemy() -> Dictionary:
	var best := {}
	var bd := float(stat["range"])
	for e in enemies:
		var d: float = (e["node"] as Node3D).position.distance_to(player.position)
		if d < bd:
			bd = d
			best = e
	return best

func _fire_logic(dt: float) -> void:
	fire_timer -= dt
	var target := _nearest_enemy()
	if target.is_empty():
		return
	var to: Vector3 = (target["node"] as Node3D).position - player.position
	to.y = 0
	face_dir = to.normalized()
	if fire_timer > 0.0:
		return
	fire_timer = 1.0 / float(stat["fire_rate"])
	var shots := int(stat["shots"])
	var spread := 12.0
	for i in shots:
		var ang := (i - (shots - 1) / 2.0) * spread
		var dir := face_dir.rotated(Vector3.UP, deg_to_rad(ang))
		_make_bullet(dir)
	recoil = 1.0
	_play("shoot", rng.randf_range(0.95, 1.1), -6.0)

func _make_bullet(dir: Vector3) -> void:
	var start := gun.global_position + dir * 0.35
	start.y = 0.55
	var n := Node3D.new()
	n.position = start
	add_child(n)
	var core := sphere(0.13, Color(0.55, 0.85, 1.0, 0.92), Vector3.ZERO, n)
	core.material_override = M(Color(0.6, 0.88, 1.0, 0.9), 0.1, true)
	core.scale = Vector3(0.8, 0.8, 1.6)
	sphere(0.05, Color(1, 1, 1, 0.95), Vector3(0.04, 0.05, 0.05), n).material_override = M(Color(1, 1, 1, 0.95), 0.1, true)
	n.look_at(start + dir, Vector3.UP)
	bullets.append({"node": n, "dir": dir, "life": 0.9, "pierce": int(stat["pierce"]), "hit": [], "trail": 0.0})

func _update_bullets(dt: float) -> void:
	for b in bullets.duplicate():
		var n: Node3D = b["node"]
		n.position += b["dir"] * 15.0 * dt
		b["life"] -= dt
		b["trail"] -= dt
		if b["trail"] <= 0.0:
			b["trail"] = 0.03
			_droplet(n.position, Color(0.7, 0.9, 1.0, 0.7), 0.05, b["dir"] * -1.0 + Vector3(0, 1, 0), 0.25)
		var done: bool = b["life"] <= 0.0
		for e in enemies:
			if e["dead"] or b["hit"].has(e):
				continue
			var en: Node3D = e["node"]
			var d := Vector2(en.position.x - n.position.x, en.position.z - n.position.z).length()
			if d < float(e["radius"]) + 0.12:
				b["hit"].append(e)
				_hit_enemy(e, float(stat["damage"]), b["dir"])
				if float(stat["splash"]) > 0.0:
					_splash(en.position, float(stat["splash"]), e)
				if b["pierce"] <= 0:
					done = true
					break
				b["pierce"] -= 1
		if done:
			_burst(n.position, Color(0.65, 0.88, 1.0, 0.85), 6, 2.5)
			n.queue_free()
			bullets.erase(b)

func _splash(pos: Vector3, r: float, skip: Dictionary) -> void:
	var ring := cyl(r, 0.05, Color(0.6, 0.85, 1, 0.5), pos + Vector3(0, 0.1, 0))
	ring.material_override = M(Color(0.6, 0.85, 1, 0.45), 0.1, true)
	fx.append({"node": ring, "t": 0.0, "life": 0.25, "kind": "ring"})
	for e in enemies:
		if e == skip or e["dead"]:
			continue
		if (e["node"] as Node3D).position.distance_to(pos) < r:
			var d: Vector3 = (e["node"] as Node3D).position - pos
			_hit_enemy(e, float(stat["damage"]) * 0.5, d.normalized(), false)

func _hit_enemy(e: Dictionary, dmg: float, dir: Vector3, main := true) -> void:
	var crit := rng.randf() < 0.12
	if crit:
		dmg *= 2.0
	e["hp"] -= dmg
	e["flash"] = 0.07
	e["squash"] = 1.0
	_set_overlay(e["body"], flash_mat)
	e["vel"] = dir.normalized() * (5.5 if main else 3.0)
	var pos: Vector3 = (e["node"] as Node3D).position
	_damage_number(pos + Vector3(0, 1.0, 0), int(round(dmg)), crit)
	_burst(pos + Vector3(0, 0.45, 0), Color(0.7, 0.9, 1.0, 0.9), 5, 3.0)
	if main:
		_play("hit", rng.randf_range(0.9, 1.15) + (0.25 if crit else 0.0), -3.0)
		hitstop(0.035 if not crit else 0.06)
		shake = maxf(shake, 0.08 if not crit else 0.18)
	if e["hp"] <= 0.0 and not e["dead"]:
		_kill_enemy(e)

func _kill_enemy(e: Dictionary) -> void:
	e["dead"] = true
	enemies.erase(e)
	kills += 1
	combo += 1
	combo_timer = 1.6
	var n: Node3D = e["node"]
	var pos := n.position
	_set_overlay(e["body"], null)
	# 퐁! 커졌다가 사라지기
	fx.append({"node": n, "t": 0.0, "life": 0.18, "kind": "pop"})
	var col := Color("#c9a8f0") if e["kind"] == "paper" else Color("#a9d4f5")
	_burst(pos + Vector3(0, 0.5, 0), col, 10, 4.5)
	_burst(pos + Vector3(0, 0.5, 0), Color("#fff27a"), 6, 5.0, true)
	for i in int(e["xp"]):
		_make_gem(pos + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
	_play("pop", 1.0 + minf(combo, 12) * 0.04, -1.0)
	hitstop(0.05)
	shake = maxf(shake, 0.16)
	Input.vibrate_handheld(25)

# 딱지(경험치)
func _make_gem(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos + Vector3(0, 0.25, 0)
	add_child(n)
	var cols := [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#9b8cff")]
	var c: Color = cols[rng.randi() % cols.size()]
	var a := box(Vector3(0.26, 0.05, 0.26), c, Vector3.ZERO, n)
	box(Vector3(0.27, 0.052, 0.04), c.lightened(0.45), Vector3.ZERO, n).rotation_degrees.y = 45
	box(Vector3(0.27, 0.052, 0.04), c.lightened(0.45), Vector3.ZERO, n).rotation_degrees.y = -45
	a.rotation_degrees.y = 0
	gems.append({"node": n, "vel": Vector3(rng.randf_range(-1.5, 1.5), 3.5, rng.randf_range(-1.5, 1.5)), "pull": false, "t": 0.0})

func _update_gems(dt: float) -> void:
	for g in gems.duplicate():
		var n: Node3D = g["node"]
		g["t"] += dt
		var d := player.position + Vector3(0, 0.4, 0) - n.position
		if not g["pull"] and g["t"] > 0.35 and d.length() < float(stat["magnet"]):
			g["pull"] = true
		if g["pull"]:
			g["vel"] = g["vel"].lerp(d.normalized() * 13.0, dt * 9.0)
		else:
			g["vel"].y -= 12.0 * dt
		n.position += g["vel"] * dt
		if n.position.y < 0.08 and not g["pull"]:
			n.position.y = 0.08
			g["vel"] = Vector3(g["vel"].x * 0.5, absf(g["vel"].y) * 0.3, g["vel"].z * 0.5)
		n.rotation.y += dt * 3.0
		if g["pull"] and d.length() < 0.35:
			n.queue_free()
			gems.erase(g)
			_gain_xp(1)

func _gain_xp(v: int) -> void:
	xp += v
	_play("gem", 1.2 + minf(xp, 20) * 0.02, -9.0)
	if xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = int(xp_need * 1.35) + 2
		_level_up()
	_refresh_ui()

# =========================================================
# 효과
# =========================================================
func hitstop(d: float) -> void:
	hitstop_left = maxf(hitstop_left, d)

func _droplet(pos: Vector3, col: Color, r: float, vel: Vector3, life: float) -> void:
	var s := sphere(r, col, pos)
	s.material_override = M(col, 0.2, true)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.append({"node": s, "t": 0.0, "life": life, "kind": "drop", "vel": vel})

func _burst(pos: Vector3, col: Color, count: int, spd: float, stars := false) -> void:
	for i in count:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.4), rng.randf_range(-1, 1)).normalized() * spd * rng.randf_range(0.5, 1.0)
		if stars:
			var b := box(Vector3(0.12, 0.12, 0.02), col, pos)
			b.material_override = M(col, 0.2, true)
			b.rotation_degrees.z = 45
			fx.append({"node": b, "t": 0.0, "life": 0.45, "kind": "drop", "vel": v, "spin": rng.randf_range(-12, 12)})
		else:
			_droplet(pos, col, rng.randf_range(0.04, 0.08), v, 0.35)

func _damage_number(pos: Vector3, v: int, crit: bool) -> void:
	var l := Label3D.new()
	l.text = str(v) + ("!" if crit else "")
	l.font = font
	l.font_size = 64 if crit else 46
	l.outline_size = 14
	l.modulate = Color("#ffdf3d") if crit else Color.WHITE
	l.outline_modulate = Color("#3a2148")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.position = pos + Vector3(rng.randf_range(-0.2, 0.2), 0, 0)
	add_child(l)
	fx.append({"node": l, "t": 0.0, "life": 0.6, "kind": "num", "vel": Vector3(0, 2.2, 0)})

func _update_fx(dt: float) -> void:
	for f in fx.duplicate():
		var n: Node3D = f["node"]
		f["t"] += dt
		var k: float = f["t"] / f["life"]
		match f["kind"]:
			"drop":
				f["vel"].y -= 9.0 * dt
				n.position += f["vel"] * dt
				n.scale = Vector3.ONE * maxf(0.01, 1.0 - k)
				if f.has("spin"):
					n.rotation.z += f["spin"] * dt
			"num":
				n.position += f["vel"] * dt
				f["vel"].y *= 0.9
				var pop := 1.0 + sin(minf(k * 4.0, 1.0) * PI) * 0.4
				n.scale = Vector3.ONE * pop
				n.modulate.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
			"pop":
				var s := 1.0 + k * 0.6
				n.scale = Vector3(s, 1.0 - k * 0.8, s)
			"ring":
				n.scale = Vector3(0.3 + k, 1, 0.3 + k)
		if k >= 1.0:
			n.queue_free()
			fx.erase(f)

func _player_hurt(from: Vector3) -> void:
	hp -= 1
	hurt_timer = 1.1
	shake = 0.35
	hitstop(0.09)
	_play("hurt", 1.0, -2.0)
	Input.vibrate_handheld(120)
	var away := player.position - from
	away.y = 0
	player.position += away.normalized() * 0.6
	for e in enemies:
		var en: Node3D = e["node"]
		var d := en.position - player.position
		if d.length() < 2.5:
			e["vel"] = d.normalized() * 7.0
	_refresh_ui()
	if hp <= 0:
		_end_game(false)

# =========================================================
# 메인 루프
# =========================================================
var shot_frames := 0
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if shot_mode != "":
		shot_frames += 1
		if shot_mode == "play" and shot_frames < 100:
			stick_vec = Vector2(0.25, -0.15)
		if shot_mode == "hero":
			cam.look_at(player.position + Vector3(0, 0.6, 0.6), Vector3.UP)
		if shot_frames == 110:
			get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % shot_mode)
			get_tree().quit()
	if hitstop_left > 0.0:
		hitstop_left -= dt
		_update_camera(dt)
		return
	if paused or game_over:
		_update_camera(dt)
		_update_fx(dt)
		return
	elapsed += dt
	if elapsed >= RUN_TIME:
		_end_game(true)
	_read_input()
	if auto_play:
		_auto_input()
	var vel := move_dir * float(stat["speed"])
	player.position += vel * dt
	player.position.x = clampf(player.position.x, -ARENA, ARENA)
	player.position.z = clampf(player.position.z, -ARENA, ARENA)
	var look := face_dir
	if _nearest_enemy().is_empty() and move_dir.length() > 0.1:
		face_dir = move_dir.normalized()
		look = face_dir
	model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), dt * 14.0)
	hurt_timer -= dt
	model.visible = hurt_timer <= 0.0 or fmod(hurt_timer, 0.16) > 0.08
	_spawn_logic(dt)
	_fire_logic(dt)
	_update_bullets(dt)
	_update_enemies(dt)
	_update_gems(dt)
	_update_fx(dt)
	_animate_player(dt)
	combo_timer -= dt
	if combo_timer <= 0.0:
		combo = 0
	_update_camera(dt)
	_update_hud()
	if auto_play and int(elapsed / 10.0) != int((elapsed - dt) / 10.0):
		print("T%d kills=%d lv=%d hp=%d enemies=%d bullets=%d gems=%d fx=%d fps=%d" % [int(elapsed), kills, level, hp, enemies.size(), bullets.size(), gems.size(), fx.size(), Engine.get_frames_per_second()])

func _update_camera(dt: float) -> void:
	var target := player.position + cam_off
	cam.position = cam.position.lerp(target, minf(1.0, dt * 6.0))
	shake = move_toward(shake, 0.0, dt * 1.2)
	var s := shake * shake * 2.0
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
func _auto_input() -> void:
	auto_t -= 0.016
	if auto_t <= 0.0:
		auto_t = rng.randf_range(0.5, 1.5)
		auto_dir = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 1.0)
		if player.position.length() > 9.0:
			auto_dir = Vector2(-player.position.x, -player.position.z).normalized()
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
				# 손가락을 따라 조이스틱이 끌려와요
				stick_origin += off - off.normalized() * r
				stick_base.position = stick_origin - stick_base.size / 2.0
				off = off.normalized() * r
			stick_vec = off / r
			stick_knob.position = stick_base.size / 2.0 - stick_knob.size / 2.0 + off

# =========================================================
# UI
# =========================================================
func _make_font() -> void:
	font = load("res://fonts/Jua-Regular.ttf")

func _label(text: String, size: int, col := Color.WHITE, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#3a2148"))
	l.add_theme_constant_override("outline_size", 10)
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

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	# 경험치 막대
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.color = Color(0.23, 0.13, 0.28, 0.6)
	xp_bar_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar_bg.offset_top = 0
	xp_bar_bg.offset_bottom = 22
	top.add_child(xp_bar_bg)
	xp_bar = ColorRect.new()
	xp_bar.color = Color("#6ee0b0")
	xp_bar.position = Vector2(0, 0)
	xp_bar.size = Vector2(0, 22)
	xp_bar_bg.add_child(xp_bar)
	level_label = _label("Lv.1", 30, Color("#ffffff"), top)
	level_label.position = Vector2(24, 26)
	timer_label = _label("0:00", 48, Color.WHITE, top)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.offset_left = -120
	timer_label.offset_right = 120
	timer_label.offset_top = 24
	hearts_label = _label("", 40, Color("#ff5c7a"), top)
	hearts_label.position = Vector2(24, 64)
	kill_label = _label("👻 0", 34, Color.WHITE, top)
	kill_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.offset_left = -240
	kill_label.offset_right = -24
	kill_label.offset_top = 28
	combo_label = _label("", 54, Color("#ffdf3d"), top)
	combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.offset_left = -200
	combo_label.offset_right = 200
	combo_label.offset_top = 150
	combo_label.pivot_offset = Vector2(200, 30)
	# 조이스틱
	stick_base = Panel.new()
	stick_base.size = Vector2(200, 200)
	stick_base.add_theme_stylebox_override("panel", _round_panel(Color(1, 1, 1, 0.22), 100, Color(1, 1, 1, 0.55), 5))
	stick_base.visible = false
	stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(stick_base)
	stick_knob = Panel.new()
	stick_knob.size = Vector2(90, 90)
	stick_knob.add_theme_stylebox_override("panel", _round_panel(Color(1, 1, 1, 0.85), 45, Color("#4fa8e8"), 6))
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.add_child(stick_knob)
	_refresh_ui()

func _refresh_ui() -> void:
	var h := ""
	for i in max_hp:
		h += "♥" if i < hp else "♡"
	hearts_label.text = h
	level_label.text = "Lv.%d" % level
	kill_label.text = "귀신 %d" % kills

func _update_hud() -> void:
	var left := maxf(0.0, RUN_TIME - elapsed)
	timer_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	xp_bar.size.x = xp_bar_bg.size.x * float(xp) / float(xp_need)
	kill_label.text = "귀신 %d" % kills
	if combo >= 3:
		combo_label.text = "%d 콤보!" % combo
		var k := clampf(combo_timer / 1.6, 0, 1)
		combo_label.modulate.a = minf(1.0, k * 3.0)
		combo_label.scale = Vector2.ONE * (1.0 + maxf(0.0, combo_timer - 1.45) * 3.0)
	else:
		combo_label.text = ""

# ---------- 레벨업 카드 ----------
const CARDS := [
	{"id": "fire_rate", "name": "연사 물총", "desc": "쏘는 속도 +25%", "col": "#4fa8e8"},
	{"id": "shots", "name": "갈래 물줄기", "desc": "물줄기 +1갈래", "col": "#6ee0b0"},
	{"id": "pierce", "name": "뚫어뻥 물줄기", "desc": "귀신 1마리 더 관통", "col": "#9b8cff"},
	{"id": "damage", "name": "왕 물방울", "desc": "물방울 피해 +30%", "col": "#ff7aa8"},
	{"id": "speed", "name": "운동화 끈 꽉!", "desc": "이동 속도 +12%", "col": "#ffb03f"},
	{"id": "splash", "name": "물풍선", "desc": "맞으면 펑! 주변도 젖어요", "col": "#58c6f2"},
	{"id": "heal", "name": "뽀빠이 과자", "desc": "하트 2칸 회복", "col": "#ff5c7a"},
	{"id": "magnet", "name": "자석 필통", "desc": "딱지 줍는 거리 +50%", "col": "#c9a8f0"},
	{"id": "range", "name": "멀리멀리 노즐", "desc": "사거리 +20%", "col": "#8fd16a"},
]

func _level_up() -> void:
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	stick_base.visible = false
	_play("level", 1.0, -2.0)
	var pool := CARDS.duplicate()
	if hp >= max_hp:
		pool = pool.filter(func(c): return c["id"] != "heal")
	pool.shuffle()
	var pick := pool.slice(0, 3)
	if auto_play:
		_apply_card(pick[rng.randi() % 3]["id"])
		return
	card_panel = Control.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(card_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	var title := _label("레벨 업!  하나 골라요", 58, Color("#ffdf3d"), card_panel)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_left = -330
	title.offset_right = 330
	title.offset_top = 210
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -290
	vb.offset_right = 290
	vb.offset_top = -330
	vb.offset_bottom = 420
	vb.add_theme_constant_override("separation", 26)
	card_panel.add_child(vb)
	for i in pick.size():
		var c: Dictionary = pick[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(580, 200)
		var st := _round_panel(Color("#fff8e8"), 30, Color(c["col"]), 10)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", _round_panel(Color(c["col"]).lightened(0.6), 30, Color(c["col"]), 10))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		vb.add_child(b)
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", _round_panel(Color(c["col"]), 22, Color("#3a2148"), 5))
		badge.position = Vector2(26, 40)
		badge.size = Vector2(120, 120)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		var icon := _label(_card_icon(c["id"]), 64, Color.WHITE, badge)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var nm := _label(c["name"], 46, Color("#3a2148"), b)
		nm.remove_theme_constant_override("outline_size")
		nm.position = Vector2(172, 40)
		var ds := _label(c["desc"], 32, Color("#6b5a75"), b)
		ds.remove_theme_constant_override("outline_size")
		ds.position = Vector2(172, 110)
		var id: String = c["id"]
		b.pressed.connect(func(): _apply_card(id))
		# 카드가 톡톡 튀어나와요
		b.scale = Vector2(0.6, 0.6)
		b.pivot_offset = Vector2(290, 100)
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _card_icon(id: String) -> String:
	return {"fire_rate": "연", "shots": "갈", "pierce": "뚫", "damage": "왕", "speed": "꽉",
		"splash": "펑", "heal": "♥", "magnet": "자", "range": "멀"}.get(id, "★")

func _apply_card(id: String) -> void:
	match id:
		"fire_rate": stat["fire_rate"] *= 1.25
		"shots": stat["shots"] += 1
		"pierce": stat["pierce"] += 1
		"damage": stat["damage"] *= 1.3
		"speed": stat["speed"] *= 1.12
		"splash": stat["splash"] = 1.3 if stat["splash"] == 0.0 else stat["splash"] + 0.4
		"heal": hp = mini(max_hp, hp + 2)
		"magnet": stat["magnet"] *= 1.5
		"range": stat["range"] *= 1.2
	if card_panel:
		card_panel.queue_free()
		card_panel = null
	paused = false
	_play("pick", 1.0, -3.0)
	_refresh_ui()

func _end_game(win: bool) -> void:
	if game_over:
		return
	game_over = true
	_play("level" if win else "hurt", 0.8, 0.0)
	if auto_play:
		print("END win=%s t=%d kills=%d lv=%d" % [win, int(elapsed), kills, level])
		get_tree().quit()
		return
	end_panel = Control.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(end_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(dim)
	var box_p := Panel.new()
	box_p.add_theme_stylebox_override("panel", _round_panel(Color("#fff8e8"), 36, Color("#4fa8e8"), 10))
	box_p.set_anchors_preset(Control.PRESET_CENTER)
	box_p.offset_left = -280
	box_p.offset_right = 280
	box_p.offset_top = -260
	box_p.offset_bottom = 260
	end_panel.add_child(box_p)
	var t := _label("운동장을 지켰다!" if win else "철수가 기절했어요", 52, Color("#ffdf3d") if win else Color("#ff7aa8"), box_p)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 50
	var s := _label("버틴 시간  %d:%02d\n물리친 귀신  %d마리\n레벨  %d" % [int(elapsed) / 60, int(elapsed) % 60, kills, level], 38, Color("#3a2148"), box_p)
	s.remove_theme_constant_override("outline_size")
	s.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.offset_top = 150
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
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -180
	b.offset_right = 180
	b.offset_top = -150
	b.offset_bottom = -50
	box_p.add_child(b)
	b.pressed.connect(func(): get_tree().reload_current_scene())

# =========================================================
# 소리 (코드로 만든 장난감 소리)
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
	var ph := 0.0
	var st := {"ph": 0.0, "lp": 0.0}
	for i in n:
		var t := float(i) / 22050.0
		s[i] = f.call(t, st)
	return _wav(s)

func _make_sounds() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	# 퓻: 짧은 물 쏘는 소리 (걸러낸 잡음 + 내려가는 휘파람)
	sounds["shoot"] = _synth(0.12, func(t: float, st: Dictionary) -> float:
		var env := exp(-t * 32.0)
		var fq := 1400.0 - t * 6000.0
		st["ph"] += fq / 22050.0
		var nz := r.randf_range(-1, 1)
		st["lp"] = lerpf(st["lp"], nz, 0.35)
		return (sin(st["ph"] * TAU) * 0.35 + st["lp"] * 0.55) * env * 0.6)
	# 뽁: 말랑한 타격음
	sounds["hit"] = _synth(0.13, func(t: float, st: Dictionary) -> float:
		var fq := 620.0 * exp(-t * 30.0) + 140.0
		st["ph"] += fq / 22050.0
		var env := exp(-t * 26.0)
		var click := r.randf_range(-1, 1) * exp(-t * 300.0) * 0.5
		return (sin(st["ph"] * TAU) * 0.9 + click) * env * 0.8)
	# 퐁! 귀신 터지는 소리 (위로 올라가는 팝 + 반짝)
	sounds["pop"] = _synth(0.32, func(t: float, st: Dictionary) -> float:
		var fq := 300.0 + t * 2600.0 if t < 0.08 else 900.0
		st["ph"] += fq / 22050.0
		var env := exp(-t * 14.0)
		var sp := sin(t * 2400.0 * TAU) * exp(-maxf(0.0, t - 0.06) * 22.0) * (0.3 if t > 0.06 else 0.0)
		return (sin(st["ph"] * TAU) * 0.8 * env + sp) * 0.7)
	# 딱지 줍기: 짧은 띵
	sounds["gem"] = _synth(0.1, func(t: float, st: Dictionary) -> float:
		return (sin(t * 1320.0 * TAU) + sin(t * 1980.0 * TAU) * 0.4) * exp(-t * 40.0) * 0.5)
	# 레벨업: 도미솔도
	sounds["level"] = _synth(0.7, func(t: float, st: Dictionary) -> float:
		var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]
		var i := mini(3, int(t / 0.11))
		var lt := t - i * 0.11
		var v := sin(t * notes[i] * TAU) + 0.3 * sin(t * notes[i] * 2.0 * TAU)
		var sq := 1.0 if sin(t * notes[i] * TAU) > 0 else -1.0
		return (v * 0.6 + sq * 0.12) * exp(-lt * (8.0 if i < 3 else 3.5)) * 0.5)
	sounds["pick"] = _synth(0.15, func(t: float, st: Dictionary) -> float:
		return sin(t * (700.0 + t * 3000.0) * TAU) * exp(-t * 20.0) * 0.5)
	# 아야: 낮은 부웅
	sounds["hurt"] = _synth(0.3, func(t: float, st: Dictionary) -> float:
		var fq := 220.0 - t * 300.0
		st["ph"] += fq / 22050.0
		var sq := 1.0 if fmod(st["ph"], 1.0) < 0.5 else -1.0
		return sq * exp(-t * 9.0) * 0.35)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players_audio.append(p)

var audio_i := 0
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
# 테스트 장면 (스크린샷용)
# =========================================================
func _setup_shot() -> void:
	rng.seed = 11
	if shot_mode == "hero":
		cam_off = Vector3(1.2, 1.6, 3.2)
		cam.position = cam_off
		_make_enemy("paper", Vector3(0.5, 0, 3.0))
		_make_enemy("egg", Vector3(-1.2, 0, 3.4))
		for e in enemies:
			e["spawn"] = 1.0
			e["speed"] = 0.0
			e["hp"] = 9999.0
		spawn_timer = 999.0
		return
	elapsed = 40.0
	for i in 9:
		var a := float(i) / 9.0 * TAU
		_make_enemy("paper" if i % 3 else "egg", Vector3(cos(a) * rng.randf_range(2.5, 4.5), 0, sin(a) * rng.randf_range(2.5, 4.5)))
	for e in enemies:
		e["spawn"] = 1.0
	if shot_mode == "cards":
		_level_up()
