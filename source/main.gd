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
var dg := 1  # 실제 난이도: 장소가 바뀔 때마다 8단계씩 더해져요
const STAGE_STEP := 8
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
var day_mod := "normal"
var weekly := false
var boss_time := 240.0
var player_vel := Vector3.ZERO
var puddles: Array = []          # [위치, 반지름]
var flee_t := 0.0
var wind := Vector3.ZERO
var wind_t := 10.0
var wind_on := 0.0
var beat_t := 0.0
var beat_n := 0
var gacha_used := 0
var ev_done := {}
var next_props := 55.0
var bgm: AudioStreamPlayer
var tut_move_t := 0.0
var tut_node: Control
var indicators: Array = []
var lv5_told := {}
var env_ref: Environment
var sun_ref: DirectionalLight3D
const STAGE_FROM := {
	"hall": {"egg": 20.0, "dust": 40.0, "eraser": 60.0, "kettle": 100.0},
	"lab": {"egg": 10.0, "kettle": 45.0, "eraser": 70.0, "dust": 100.0},
	"toilet": {"egg": 30.0, "dust": 50.0, "eraser": 80.0, "kettle": 110.0},
	"roof": {"egg": 10.0, "eraser": 35.0, "kettle": 60.0, "dust": 90.0},
	"music": {"egg": 5.0, "dust": 30.0, "eraser": 50.0, "kettle": 70.0},
}
const BOSS_TINT := {"ground": Color(1, 1, 1), "hall": Color(0.75, 0.9, 1.35), "lab": Color(1.3, 0.85, 1.1),
	"toilet": Color(0.9, 1.25, 1.35), "roof": Color(1.35, 1.0, 0.7), "music": Color(1.1, 0.8, 1.4)}
const CAM_OFFSET := Vector3(0, 14.0, 11.5)
const RUN_TIME := 300.0
const MAX_ENEMY := 110
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
	"paper": {"dmg": 1, "hp": 24.0, "speed": 1.6, "r": 0.45, "scale": 1.25, "xp": 1, "col": "#c9a8f0", "from": 0.0},
	"egg": {"dmg": 1, "hp": 13.0, "speed": 2.8, "r": 0.4, "scale": 1.25, "xp": 1, "col": "#a9d4f5", "from": 15.0},
	"kettle": {"dmg": 2, "hp": 110.0, "speed": 1.2, "r": 0.62, "scale": 1.7, "xp": 3, "col": "#ffd23f", "from": 70.0},
	"eraser": {"dmg": 1, "hp": 55.0, "speed": 1.7, "r": 0.5, "scale": 1.35, "xp": 2, "col": "#7fd18b", "from": 85.0},
	"dust": {"dmg": 1, "hp": 9.0, "speed": 3.5, "r": 0.3, "scale": 0.95, "xp": 1, "col": "#b8b2c0", "from": 115.0},
	"report": {"dmg": 1, "hp": 45.0, "speed": 2.0, "r": 0.42, "scale": 1.3, "xp": 2, "col": "#ff9db8", "from": 140.0},
	"relay": {"dmg": 1, "hp": 30.0, "speed": 5.2, "r": 0.4, "scale": 1.35, "xp": 2, "col": "#ff6b6b", "from": 9999.0},
	"pot": {"hp": 40.0, "speed": 0.0, "r": 0.4, "scale": 1.3, "xp": 0, "col": "#d9774a", "from": 9999.0, "prop": true},
	"ext": {"hp": 40.0, "speed": 0.0, "r": 0.35, "scale": 1.3, "xp": 0, "col": "#e8433a", "from": 9999.0, "prop": true},
	"boss": {"dmg": 3, "hp": 36000.0, "speed": 1.35, "r": 1.5, "scale": 3.0, "xp": 0, "col": "#6fbf4a", "from": 9999.0},
}

const MAINS_KO := {
	"gun": {"name": "물총", "icon": "물", "col": "#4fa8e8", "partner": "bottle", "evo": "소방차 물대포",
		"evo_desc": "굵은 물대포! 60% 확률로 관통, 40% 확률로 물풍선처럼 펑!",
		"desc": ["가장 가까운 귀신에게 물을 쏴요", "피해 +30%", "물줄기 +1갈래", "쏘는 속도 +30%", "물줄기 +1, 30% 확률로 관통"]},
	"ddakji": {"name": "딱지", "icon": "딱", "col": "#ff7aa8", "partner": "notebook", "evo": "황금 딱지 폭풍",
		"evo_desc": "황금 딱지 8장이 크게 넘실대며 귀신을 날려요",
		"desc": ["딱지 2장이 빙글빙글 철수를 지켜요", "딱지 +1장", "피해 +40%", "딱지 +1장", "딱지 +1장, 더 크고 빠르게"]},
	"yoyo": {"name": "요요", "icon": "요", "col": "#2fc79a", "partner": "watch", "evo": "번개 요요",
		"evo_desc": "요요 4개! 맞히면 35% 확률로 찌릿, 번개가 옆으로 튀어요",
		"desc": ["쭉 날아갔다 돌아오며 다 맞혀요", "요요 +1개", "피해 +40%", "더 멀리 날아가요", "요요 +1개"]},
	"plane": {"name": "종이비행기", "icon": "비", "col": "#7fa8ff", "partner": "colorpaper", "evo": "종이학 편대",
		"evo_desc": "종이학 6마리가 무지개 꼬리를 그리며 귀신을 줄줄이 꿰뚫어요",
		"desc": ["귀신을 쫓아가는 종이비행기를 날려요", "비행기 +1", "피해 +40%", "비행기 +1, 더 빠르게", "귀신 2마리를 더 뚫고 날아가요"]},
	"pop": {"name": "콩알탄", "icon": "콩", "col": "#ff5c5c", "partner": "magnifier", "evo": "왕 불꽃놀이",
		"evo_desc": "하늘로 쏘아 올린 불꽃이 펑펑! 귀신 떼 위에서 크게 터져요",
		"desc": ["귀신 무리에 콩알탄을 던져 펑! 터뜨려요", "콩알탄 +1", "폭발 범위 +25%", "피해 +40%", "콩알탄 +2"]},
	"rubber": {"name": "고무줄", "icon": "줄", "col": "#ff9a2f", "partner": "sneakers", "evo": "무지개 고무줄",
		"evo_desc": "무지개 고무줄이 두 겹으로 쫙쫙! 맞은 귀신은 느려져요",
		"desc": ["고무줄이 쫙! 퍼지며 주변을 튕겨내요", "범위 +20%", "피해 +40%", "더 자주 퍼져요", "범위 +20%, 더 세게 튕겨요"]},
	"top": {"name": "팽이", "icon": "팽", "col": "#e8524a", "partner": "pencil", "evo": "회오리 팽이",
		"evo_desc": "큰 팽이 4개가 회오리를 일으켜 귀신을 빨아들이고 튕겨내요",
		"desc": ["팽이를 던지면 바닥에서 돌며 귀신을 튕겨내요", "팽이 +1개", "피해 +40%", "더 오래 돌아요", "팽이 +1개, 더 크게"]},
}
var MAINS: Dictionary = Save.trd(MAINS_KO)
const SUPPORTS_KO := {
	"bottle": {"name": "생수병", "icon": "병", "col": "#58c6f2", "desc": "피해 +15%, 가끔 물을 촤악 뿌려요", "set": "gun"},
	"notebook": {"name": "공책", "icon": "책", "col": "#b48ef0", "desc": "범위 +15%, 공책 종이가 빙글빙글 돌아요", "set": "ddakji"},
	"watch": {"name": "계산기 시계", "icon": "시", "col": "#7cc95a", "desc": "대기 시간 -8%, 띠띠! 주변 귀신이 느려져요", "set": "yoyo"},
	"sneakers": {"name": "운동화", "icon": "신", "col": "#f2c230", "desc": "이동 속도 +10%, 반짝 발자국", "set": "rubber"},
	"colorpaper": {"name": "색종이", "icon": "색", "col": "#6fd3ff", "desc": "색종이 별을 휙휙 던져요. 물줄기, 비행기, 콩알탄도 15% 빨라져요", "set": "plane"},
	"magnifier": {"name": "돋보기", "icon": "돋", "col": "#ffb03f", "desc": "치명타 피해 +30%, 햇빛으로 귀신을 지져요", "set": "pop"},
	"pencil": {"name": "필통", "icon": "필", "col": "#9b8cff", "desc": "줍는 거리 +40% (바닥에 원이 보여요)", "set": "top"},
	"nametag": {"name": "명찰", "icon": "명", "col": "#ff5c7a", "desc": "하트 +1, 하트 방패가 한 번 막아 줘요", "set": ""},
}
var SUPPORTS: Dictionary = Save.trd(SUPPORTS_KO)
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
var cd := {"gun": 0.0, "yoyo": 0.5, "rubber": 1.0, "plane": 0.3, "pop": 0.8, "top": 0.6}
var tops: Array = []
var planes: Array = []
var pops: Array = []
var plane_mesh: ArrayMesh
var crane_mesh: ArrayMesh
var pop_mesh: Mesh
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
var mat_vc_2s: StandardMaterial3D
var sh_lit: Shader
var sh_unlit: Shader
var mesh_cache := {}
var ddakji_mesh: ArrayMesh
var ddakji_gold_mesh: ArrayMesh
var yoyo_mesh: ArrayMesh
var yoyo_evo_mesh: ArrayMesh
var top_mesh: ArrayMesh
var coin_fall_mesh: ArrayMesh
var fall_mats := {}
var top_evo_mesh: ArrayMesh

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
	MAINS = Save.trd(MAINS_KO)
	SUPPORTS = Save.trd(SUPPORTS_KO)
	BOSS_RANKS = Save.trd(BOSS_RANKS_KO)
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
		if a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		if a.begins_with("--clears="):
			Save.data["clears"] = {"ground": int(a.substr(9))}   # 봇 시험용: 앞 단계를 깬 척
		if a.begins_with("--shop="):
			var sl := int(a.substr(7))   # 봇 시험용: 문방구 강화 단계
			Save.data["shop"] = {"dmg": sl, "hp": sl / 2, "speed": sl / 2, "magnet": sl / 2, "xp": sl / 2, "w_gun": sl / 2, "w_ddakji": sl / 2}
	if args.has("--seed"):
		rng.seed = 7
	if args.has("--weekly"):
		Save.run_cfg["weekly"] = true
	if args.has("--meta") or (shot_mode != "" and not args.has("--menu")) or args.has("--evoall"):
		Save.evo_all = true
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
	day_mod = Save.today_mod()
	weekly = Save.run_cfg.get("weekly", false) and not in_menu
	if weekly:
		var wc := Save.weekly_cfg()
		stage = wc["stage"]
		grade = wc["grade"]
		char_id = wc["char"]
		day_mod = wc["mod"]
		rng.seed = wc["seed"]
	dg = grade + maxi(0, BOSS_ORDER.find(stage)) * (3 if weekly else STAGE_STEP)
	for a in args:
		if a.begins_with("--mod="):
			day_mod = a.substr(6)
	if in_menu:
		day_mod = "normal"
	if day_mod == "exam":
		boss_time = 180.0
	match stage:
		"hall":
			AX = 3.4
			AZ = 30.0
		"lab":
			AX = 11.0
			AZ = 11.0
		"toilet":
			AX = 9.0
			AZ = 9.0
		"roof":
			AX = 9.5
			AZ = 9.5
		"music":
			AX = 10.0
			AZ = 10.0
	var w: String = Save.CHARS[char_id]["weapon"]
	mains = {w: 1}
	main_order = [w]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--give="):   # 봇 시험용: 무기 하나를 처음부터 더 줘요
			var gw := a.substr(7)
			if MAINS.has(gw) and not mains.has(gw):
				mains[gw] = 1
				main_order.append(gw)
	rerolls = Save.shop_lv("reroll")
	revives = Save.shop_lv("revive")
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/Jua-Regular.ttf")
	if OS.has_feature("web"):
		get_viewport().scaling_3d_scale = 0.8
		if OS.has_feature("web_android") or OS.has_feature("web_ios"):
			# 폰에서는 열과 배터리를 아끼려고 40프레임으로, 화면도 조금 가볍게
			Engine.max_fps = 40
			get_viewport().scaling_3d_scale = 0.7
			mobile_web = true
	_make_materials()
	_make_world()
	_make_player()
	_make_multimeshes()
	_make_ui()
	_make_sounds()
	hp = max_hp()
	_refresh_ui()
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	_play_bgm("menu" if in_menu else stage)
	if in_menu:
		hud.visible = false
		cam_off = Vector3(0.0, 2.3, 5.2)
		cam.position = cam_off
		cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
		if ResourceLoader.exists("res://models/granny.glb"):
			var gr: Node3D = (load("res://models/granny.glb") as PackedScene).instantiate()
			gr.position = Vector3(1.0, 0, -1.4)
			gr.rotation.y = -0.3
			gr.scale = Vector3.ONE * 1.25
			gr.name = "Granny"
			add_child(gr)
		_decor("bg_shop", "", Vector3(0.4, 0, -3.6), 0.0, 1.0)
		menu_node = load("res://menu.gd").new()
		menu_node.set("main", self)
		add_child(menu_node)
		return
	if shot_mode != "":
		_setup_shot()
	_prewarm()
	var bt := tr("%s %d단계") % [Save.STAGES[stage]["name"], grade]
	var wd: Dictionary = Save.WEATHERS[weather]
	if wd["desc"] != "":
		bt += "\n" + wd["name"] + "! " + wd["desc"]
	if day_mod != "normal":
		bt += tr("\n오늘은 ") + Save.DAY_MODS[day_mod]["name"] + "!"
	if weekly:
		bt = tr("주간 도전!\n") + bt
	_banner(bt, Color.WHITE)
	_spawn_props(6)
	if not Save.tut_seen("move") and shot_mode == "" and not auto_play:
		_make_move_tut()
	for i in 6:
		var pnl := Panel.new()
		pnl.size = Vector2(84, 84)
		pnl.pivot_offset = Vector2(42, 42)
		pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.visible = false
		hud.add_child(pnl)
		var il := _label("", 30, Color.WHITE, pnl, 8)
		il.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		indicators.append([pnl, il])

func _make_move_tut() -> void:
	tut_node = Control.new()
	tut_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tut_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tut_node)
	var l := _label(tr("화면을 누른 채로 끌면 움직여요\n공격은 저절로! 귀신을 피해 다녀요"), 38, Color.WHITE, tut_node, 12)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -340
	l.offset_right = 340
	l.offset_top = -420
	l.offset_bottom = -320
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", _round_panel(Color(1, 1, 1, 0.25), 70, Color(1, 1, 1, 0.9), 6))
	ring.size = Vector2(140, 140)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_node.add_child(ring)
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", _round_panel(Color("#ffdf3d"), 30, Color("#3a2148"), 5))
	dot.size = Vector2(60, 60)
	dot.position = Vector2(40, 40)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(dot)
	ring.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ring.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 70, get_viewport().get_visible_rect().size.y - 300)
	var tw := dot.create_tween().set_loops()
	tw.tween_property(dot, "position", Vector2(85, 40), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "position", Vector2(-5, 40), 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "position", Vector2(40, 40), 0.5).set_trans(Tween.TRANS_SINE)

func _update_tut_and_hints(dt: float) -> void:
	if tut_node:
		if move_dir.length() > 0.2:
			tut_move_t += dt
		if tut_move_t > 1.5 or elapsed > 12.0:
			tut_node.queue_free()
			tut_node = null
			Save.tut_mark("move")
	for id in mains:
		if mains[id] >= MAX_LV and not evolved.has(id) and not lv5_told.has(id):
			lv5_told[id] = true
			var pn: String = SUPPORTS[MAINS[id]["partner"]]["name"]
			if supports.has(MAINS[id]["partner"]):
				_banner(tr("%s Lv.5! 다음 레벨업에 진화해요") % MAINS[id]["name"], Color("#ffd23f"))
			else:
				_banner(tr("%s Lv.5! 짝꿍 %s 챙기면 진화!") % [MAINS[id]["name"], pn], Color("#ffd23f"))

func _update_indicators() -> void:
	# 화면 밖에 있는 보스, 정예 귀신, 뽑기통, 보물 상자를 가장자리에 알려 줘요
	var targets: Array = []
	if not boss.is_empty() and boss["dead"] < 0.0:
		targets.append([boss["pos"], tr("보스"), Color("#e8524a")])
	for e in enemies:
		if e["elite"] and e["dead"] < 0.0:
			targets.append([e["pos"], "!", Color("#ffb03f")])
	for d in drops:
		if d["kind"] == "gacha":
			targets.append([d["pos"], tr("뽑"), Color("#ff9a2f")])
		elif d["kind"] == "chest":
			targets.append([d["pos"], tr("상"), Color("#b5713a")])
	var rect := get_viewport().get_visible_rect().size
	var scale_v := rect / Vector2(get_viewport().size)
	var n := 0
	for tg in targets:
		if n >= indicators.size():
			break
		var wp: Vector3 = tg[0] + Vector3(0, 0.8, 0)
		var sp := cam.unproject_position(wp) * scale_v
		var behind := cam.is_position_behind(wp)
		var m := 60.0
		if not behind and sp.x > m and sp.x < rect.x - m and sp.y > 200 and sp.y < rect.y - m:
			continue
		var c := rect / 2.0
		var dir := (sp - c) if not behind else (c - sp)
		var k := minf((rect.x / 2.0 - m) / maxf(absf(dir.x), 0.001), (rect.y / 2.0 - m) / maxf(absf(dir.y), 0.001))
		var pos := c + dir * minf(k, 1.0)
		pos.y = maxf(pos.y, 230.0)
		var pnl: Panel = indicators[n][0]
		var il: Label = indicators[n][1]
		pnl.visible = true
		pnl.position = pos - pnl.size / 2.0
		pnl.add_theme_stylebox_override("panel", _round_panel(tg[2], 42, Color.WHITE, 5))
		pnl.scale = Vector2.ONE * (1.0 + 0.1 * sin(elapsed * 8.0))
		il.text = tg[1]
		il.add_theme_font_size_override("font_size", 26 if tg[1].length() > 1 else 40)
		n += 1
	for i in range(n, indicators.size()):
		indicators[i][0].visible = false

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
	for cm in [true, false]:
		var fz := MeshInstance3D.new()
		fz.mesh = coin_fall_mesh if cm else mm["eshot"].multimesh.mesh
		fz.material_override = _fall_mat(cm)
		fz.position = Vector3(-0.5 if cm else -1.0, -0.5, 0)
		add_child(fz)
		get_tree().create_timer(0.3).timeout.connect(fz.queue_free)
	var tpm := MeshInstance3D.new()
	tpm.mesh = top_mesh
	tpm.material_override = mat_vc
	tpm.position = Vector3(0.5, -0.5, 0)
	add_child(tpm)
	get_tree().create_timer(0.3).timeout.connect(tpm.queue_free)
	var z := _make_zone(Vector3(0, -3.0, 0))
	get_tree().create_timer(0.3).timeout.connect(z.queue_free)

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

const GHOST_MODELS := {"paper": "ghost_paper", "egg": "ghost_egg", "kettle": "ghost_kettle", "eraser": "ghost_eraser",
	"dust": "ghost_dust", "report": "ghost_report", "boss": "boss_locker", "relay": "ghost_relay", "pot": "prop_pot", "ext": "prop_ext"}
const BOSS_MODELS := {"ground": "boss_locker", "hall": "boss_hall", "lab": "boss_lab", "toilet": "boss_toilet", "roof": "boss_roof", "music": "boss_music"}
var sh_tex: Shader
func _mm_textured(name: String, glb: String, count: int) -> void:
	# 3D 모델(텍스처 있음)을 MultiMesh로: 맞으면 하얗게 번쩍, 정예는 금빛
	var inst: Node = (load(glb) as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var mat := mesh.surface_get_material(0)
	if mi.get_surface_override_material(0):
		mat = mi.get_surface_override_material(0)
	var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture if mat is BaseMaterial3D else null
	inst.free()
	if sh_tex == null:
		sh_tex = Shader.new()
		sh_tex.code = """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){
  vec3 c = texture(tex, UV).rgb * cu.rgb;
  ALBEDO = mix(c, vec3(1.0), cu.a);
  EMISSION = vec3(cu.a * 0.6);
  ROUGHNESS = 0.85;
}
"""
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_custom_data = true
	m.use_colors = true
	m.mesh = mesh
	m.instance_count = count
	m.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = m
	var sm := ShaderMaterial.new()
	sm.shader = sh_tex
	sm.set_shader_parameter("tex", tex)
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))
	add_child(mmi)
	mm[name] = mmi

func _fx_shader(code: String) -> Shader:
	var sh := Shader.new()
	sh.code = code
	return sh

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
	e.glow_enabled = true
	e.glow_intensity = 1.2
	e.glow_strength = 1.2
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 0.92
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
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
	env_ref = e
	sun_ref = sun
	match stage:
		"hall": _world_hall(e, sun)
		"lab": _world_lab(e, sun)
		"toilet": _world_toilet(e, sun)
		"roof": _world_roof(e, sun)
		"music": _world_music(e, sun)
		_: _world_ground()
	_place_decor()
	_apply_day_mod()
	_apply_weather()
	if mobile_web:
		e_glow_off()

# ---------- 배경 소품(3D 모델) ----------
var decor_cache := {}
func _decor(file: String, piece: String, pos: Vector3, rot_deg := 0.0, scl := 1.0, block := Vector2.ZERO) -> Node3D:
	var path := "res://models/%s.glb" % file
	if not ResourceLoader.exists(path):
		return null
	if not decor_cache.has(file):
		decor_cache[file] = (load(path) as PackedScene).instantiate()
	var src: Node = decor_cache[file]
	var n: Node3D = src if piece == "" else src.find_child(piece, true, false)
	if n == null:
		return null
	var d: Node3D = n.duplicate()
	d.position = pos
	d.rotation = Vector3(0, deg_to_rad(rot_deg), 0)
	d.scale = Vector3.ONE * scl
	add_child(d)
	for mi in d.find_children("*", "MeshInstance3D", true, false) + ([d] if d is MeshInstance3D else []):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if block != Vector2.ZERO:
		obstacles.append([Vector3(pos.x, 0, pos.z), block])
	return d

func _exit_tree() -> void:
	for k in decor_cache:
		(decor_cache[k] as Node).free()
	decor_cache.clear()

func _place_decor() -> void:
	match stage:
		"ground":
			_decor("bg_school", "", Vector3(0, 0, -20.5), 0.0, 1.0)
			_decor("set_ground", "p2", Vector3(0, 0, -15.6), 0.0, 2.6)
			_decor("set_ground", "p3", Vector3(-11.5, 0, -15.0), 0.0, 1.8)
			_decor("set_ground", "p3", Vector3(11.5, 0, -15.0), 0.0, 1.8)
		"hall":
			var left := ["p0", "p1", "p2", "p6"]
			var right := ["p3", "p4", "p5"]
			var z := -AZ + 3.0
			var i := 0
			while z < AZ - 2.0:
				_decor("set_hall", left[i % left.size()], Vector3(-AX - 0.3, 0, z), 90.0, 1.0)
				_decor("set_hall", right[i % right.size()], Vector3(AX + 0.35, 0, z + 2.5), -90.0, 1.0)
				z += 5.0
				i += 1
		"lab":
			_decor("set_lab", "p0", Vector3(-3.0, 0, -11.6), 0.0, 1.5)
			_decor("set_lab", "p2", Vector3(3.0, 0, -11.5), 0.0, 1.3)
			_decor("set_lab", "p6", Vector3(9.5, 0, -11.8), 0.0, 1.4)
			_decor("set_lab", "p3", Vector3(-11.8, 0, -4.0), 90.0, 1.5)
			_decor("set_lab", "p4", Vector3(-11.9, 0.8, 4.0), 90.0, 1.5)
			_decor("set_lab", "p1", Vector3(-9.0, 0, 10.0), 180.0, 1.2, Vector2(0.5, 0.4))
			_decor("set_lab", "p1", Vector3(9.0, 0, -3.0), 0.0, 1.2, Vector2(0.5, 0.4))
			_decor("set_lab", "p5", Vector3(9.5, 0, 9.5), 0.0, 1.5, Vector2(0.4, 0.4))
		"toilet":
			_decor("set_toilet", "p1", Vector3(AX + 0.6, 0, 0.0), -90.0, 1.4)
			_decor("set_toilet", "p2", Vector3(-AX - 0.5, 0, 0.0), 90.0, 1.4)
			_decor("set_toilet", "p4", Vector3(-7.5, 0, 2.5), 30.0, 1.1, Vector2(0.4, 0.4))
			_decor("set_toilet", "p5", Vector3(7.8, 0, -2.6), 0.0, 1.2)
			_decor("set_toilet", "p3", Vector3(-AX - 0.3, 0.6, -3.5), 90.0, 1.2)
			_decor("set_toilet", "p0", Vector3(-3.0, 0, -AZ - 0.5), 0.0, 1.3)
			_decor("set_toilet", "p0", Vector3(3.0, 0, -AZ - 0.5), 0.0, 1.3)
		"roof":
			_decor("set_roof", "p0", Vector3(-4.5, 0, -AZ - 2.6), 0.0, 1.6)
			_decor("set_roof", "p1", Vector3(6.5, 0, 6.5), 0.0, 1.25)
			_decor("set_roof", "p1", Vector3(-6.5, 0, -6.5), 0.0, 1.25)
		"music":
			_decor("set_music", "p1", Vector3(0.0, 0, -AZ - 0.2), 0.0, 1.5)
			_decor("set_music", "p1", Vector3(AX + 0.3, 0, 2.0), -90.0, 1.5)
			_decor("set_music", "p2", Vector3(-3.5, 0, 6.5), 0.0, 1.5, Vector2(0.35, 0.35))
			_decor("set_music", "p3", Vector3(-AX - 0.2, 0, -2.0), 90.0, 1.2)

func e_glow_off() -> void:
	# 빛 번짐은 화면 전체를 한 번 더 그려서 폰을 뜨겁게 해요
	if env_ref:
		env_ref.glow_enabled = false

func _apply_day_mod() -> void:
	if day_mod == "vacation" and stage != "lab":
		env_ref.background_color = Color("#0d0b1a")
		env_ref.ambient_light_color = Color("#6f7fd8")
		env_ref.ambient_light_energy = 0.16
		sun_ref.light_energy = 0.12
		sun_ref.light_color = Color("#8fa0ff")
		if flashlight == null:
			flashlight = OmniLight3D.new()
			flashlight.omni_range = 8.5
			flashlight.light_energy = 2.4
			flashlight.light_color = Color("#fff1c9")
			add_child(flashlight)
	if day_mod == "rain":
		env_ref.background_color = env_ref.background_color.darkened(0.35)
		env_ref.ambient_light_color = Color("#c8d4e8")
		sun_ref.light_energy *= 0.6
		_make_puddles(9)

# =========================================================
# 단계별 날씨 / 학교 안 사건
# =========================================================
var weather := "sunny"
var light_t := 6.0
var flash_t := 0.0
var strikes: Array = []
var base_ambient := 1.0
func _apply_weather() -> void:
	weather = Save.weather_for(stage, grade)
	if in_menu:
		weather = "sunny"
		return
	base_ambient = env_ref.ambient_light_energy
	match weather:
		"sunset":
			env_ref.background_color = Color("#f2905a")
			env_ref.ambient_light_color = Color("#ffe0cc")
			sun_ref.light_color = Color("#ffd6b8")
			sun_ref.light_energy *= 0.9
		"rain", "storm":
			env_ref.background_color = env_ref.background_color.darkened(0.55)
			env_ref.ambient_light_color = Color("#a8b8d8")
			sun_ref.light_energy *= 0.45
			env_ref.tonemap_exposure *= 0.8
			if puddles.is_empty():
				_make_puddles(9)
			_sky_particles(Color(0.8, 0.9, 1.0, 0.75), Vector3(0.05, 1.1, 0.05), 22.0, 200 if not mobile_web else 110)
		"snow":
			env_ref.background_color = Color("#c8d8ec")
			env_ref.ambient_light_color = Color("#e0ecff")
			sun_ref.light_color = Color("#dfe9ff")
			_sky_particles(Color(1, 1, 1, 0.95), Vector3(0.14, 0.14, 0.14), 2.5, 220 if not mobile_web else 120)
			env_ref.tonemap_exposure *= 1.08
		"cleaning":
			if puddles.is_empty():
				_make_puddles(10)
		"night", "blackout", "midnight":
			env_ref.background_color = Color("#0d0b1a")
			env_ref.ambient_light_color = Color("#6f7fd8")
			env_ref.ambient_light_energy = minf(env_ref.ambient_light_energy, 0.15)
			sun_ref.light_energy = minf(sun_ref.light_energy, 0.12)
			sun_ref.light_color = Color("#8fa0ff")
			if stage != "lab":
				env_ref.tonemap_exposure *= 0.6
			if flashlight == null:
				flashlight = OmniLight3D.new()
				flashlight.omni_range = 8.5
				flashlight.light_energy = 3.6
				flashlight.light_color = Color("#fff1c9")
				add_child(flashlight)
			elif stage == "lab":
				flashlight.omni_range = 6.8
		"alarm":
			env_ref.ambient_light_color = Color("#ffb0a8")
	base_ambient = env_ref.ambient_light_energy

func _sky_particles(col: Color, size: Vector3, speed: float, amount: int) -> void:
	# 비나 눈: 카메라 주변에만 떨어지게 해서 가벼워요
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.2 if speed > 10.0 else 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(10, 0.5, 12)
	p.direction = Vector3(0.15, -1, 0)
	p.spread = 4.0 if speed > 10.0 else 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed
	if size.y > size.x * 2.0:
		var bm := BoxMesh.new()
		bm.size = size
		p.mesh = bm
	else:
		var sm := SphereMesh.new()
		sm.radius = size.x * 0.6
		sm.height = size.x * 1.2
		sm.radial_segments = 6
		sm.rings = 3
		p.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	p.material_override = m
	p.local_coords = false
	add_child(p)
	set_meta("sky_p", p)

func weather_speed() -> float:
	return {"snow": 0.85, "alarm": 1.12, "midnight": 1.05}.get(weather, 1.0)

func weather_spawn() -> float:
	return {"sunset": 1.1, "snow": 1.2, "alarm": 1.05}.get(weather, 1.0)

func _weather_logic(dt: float) -> void:
	if has_meta("sky_p"):
		var sp: CPUParticles3D = get_meta("sky_p")
		sp.position = player.position + Vector3(0, 9.0, -2.0)
	if weather == "alarm":
		var k := 0.5 + 0.5 * sin(elapsed * 6.0)
		env_ref.ambient_light_color = Color(1.0, 0.75, 0.7).lerp(Color(1.0, 0.25, 0.2), k)
		if fmod(elapsed, 12.0) < dt:
			_play("warn", 0.9, -12.0)
	# 번개: 빨간 동그라미 경고 뒤에 콰광! 철수도 귀신도 맞아요
	if weather in ["storm", "thunder", "midnight"] and elapsed > 8.0:
		light_t -= dt
		if light_t <= 0.0:
			light_t = rng.randf_range(6.0, 9.0) if weather != "midnight" else rng.randf_range(5.0, 7.5)
			var n := 2 + (1 if dg > 15 else 0)
			for i in n:
				var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
				var sp2 := player.position + move_dir * move_speed() * 0.5 + off
				sp2.x = clampf(sp2.x, -AX + 1, AX - 1)
				sp2.z = clampf(sp2.z, -AZ + 1, AZ - 1)
				_warn_circle(sp2, 1.4, 1.2 + i * 0.15)
				strikes.append({"pos": sp2, "t": 1.2 + i * 0.15})
	for st in strikes.duplicate():
		st["t"] -= dt
		if st["t"] <= 0.0:
			strikes.erase(st)
			var sp3: Vector3 = st["pos"]
			var top := sp3 + Vector3(rng.randf_range(-1, 1), 12.0, -3.0)
			var mid := sp3.lerp(top, 0.5) + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			_bolt(top, mid)
			_bolt(mid, sp3)
			_ring(sp3, Color(1.0, 0.95, 0.5, 1.0), 0.3, 2.2, 0.35)
			_sparkle(sp3 + Vector3(0, 0.3, 0), Color(1.0, 0.95, 0.5, 1.0), 10, 6.0, 0.12, 0.4)
			flash_t = 0.18
			shake = maxf(shake, 0.25)
			_play("zap", 0.6, -2.0)
			for e in enemies:
				if e["dead"] < 0.0 and Vector2(e["pos"].x - sp3.x, e["pos"].z - sp3.z).length() < 1.4 + e["radius"]:
					_hit_enemy(e, 60.0, e["pos"] - sp3, 6.0, true)
	if flash_t > 0.0:
		flash_t -= dt
		env_ref.ambient_light_energy = base_ambient + 2.5 * maxf(flash_t, 0.0) / 0.18
	elif weather in ["storm", "thunder", "midnight"]:
		env_ref.ambient_light_energy = base_ambient

func _make_puddles(count: int) -> void:
		var pm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, specular_schlick_ggx;
void fragment(){ float d = length(UV - 0.5) * 2.0; ALBEDO = vec3(0.62,0.78,1.0); ROUGHNESS = 0.05; METALLIC = 0.1; float rim = smoothstep(0.75, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d)); ALBEDO += rim * 0.3; ALPHA = (1.0 - smoothstep(0.85, 1.0, d)) * 0.5; }
"""
		pm.shader = sh
		for i in count:
			var c := Vector3(rng.randf_range(-AX + 1, AX - 1), 0.02, rng.randf_range(-AZ + 1, AZ - 1))
			var r := rng.randf_range(1.2, 2.2)
			var q := PlaneMesh.new()
			q.size = Vector2(r * 2, r * 2)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = pm
			mi.position = c
			add_child(mi)
			puddles.append([c, r * 0.9])

func _world_ground() -> void:
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
	var tex: Texture2D = ImageTexture.create_from_image(img)
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
  vec3 c = texture(tex, wp / 7.0).rgb;
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
	if ResourceLoader.exists("res://textures/floor_ground.jpg"):
		tex = load("res://textures/floor_ground.jpg")
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
	if not ResourceLoader.exists("res://models/set_ground.glb"):
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

func _world_toilet(e: Environment, sun: DirectionalLight3D) -> void:
	# 화장실: 위아래로 칸막이 줄, 가운데는 넓은 통로
	e.background_color = Color("#2a3440")
	e.ambient_light_energy = 0.48
	if not _tex_floor(Vector2(30, 30), "res://textures/floor_toilet.jpg", 6.0):
		_tile_floor(Vector2(30, 30), Color(0.86, 0.93, 0.97), Color(0.7, 0.84, 0.92), 0.6)
	var L: Array = []
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(0.4, 3.0, 20)), T(Vector3(side * (AX + 0.9), 1.5, 0)), Color("#dfe9ef")])
		L.append([_box(Vector3(20, 3.0, 0.4)), T(Vector3(0, 1.5, side * (AZ + 0.9))), Color("#dfe9ef")])
		for x in [-7.0, -4.5, -2.0, 2.0, 4.5, 7.0]:
			var c := Vector3(x, 0, side * 6.0)
			L.append([_box(Vector3(0.18, 1.7, 3.6)), T(c + Vector3(0, 0.85, 0)), Color("#7fc8e8")])
			obstacles.append([c, Vector2(0.12, 1.8)])
		for x in [-5.75, -3.25, 3.25, 5.75]:
			# 변기
			L.append([_cyl(0.28, 0.4, 0.22, 12), T(Vector3(x, 0.2, side * 7.6)), Color.WHITE])
			L.append([_box(Vector3(0.5, 0.6, 0.25)), T(Vector3(x, 0.55, side * 8.0)), Color("#f5f5f5")])
	for z in [-2.0, 0.0, 2.0]:
		# 세면대
		L.append([_box(Vector3(0.6, 0.85, 0.9)), T(Vector3(-AX - 0.3, 0.42, z)), Color("#c8d4dc")])
		L.append([_box(Vector3(0.1, 0.8, 0.7)), T(Vector3(-AX - 0.62, 1.6, z)), Color("#bfe4ff")])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)

func _world_roof(e: Environment, sun: DirectionalLight3D) -> void:
	# 옥상: 초록 방수 페인트 바닥, 낮은 난간, 물탱크
	e.background_color = Color("#8cc8f0")
	e.ambient_light_energy = 0.42
	if not _tex_floor(Vector2(AX * 2 + 2.4, AZ * 2 + 2.4), "res://textures/floor_roof.jpg", 8.0):
		_tile_floor(Vector2(AX * 2 + 2.4, AZ * 2 + 2.4), Color(0.45, 0.62, 0.48), Color(0.48, 0.66, 0.5), 2.0)
	var L: Array = []
	var ring := 0.0
	while ring <= 1.0:
		for side in [-1.0, 1.0]:
			var x := -AX - 1.1 + ring * (AX * 2 + 2.2)
			L.append([_cyl(0.05, 0.7, -1, 6), T(Vector3(x, 0.35, side * (AZ + 1.1))), Color("#d0d0d8")])
			L.append([_cyl(0.05, 0.7, -1, 6), T(Vector3(side * (AX + 1.1), 0.35, x)), Color("#d0d0d8")])
		ring += 0.05
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(AX * 2 + 2.3, 0.06, 0.06)), T(Vector3(0, 0.7, side * (AZ + 1.1))), Color("#d0d0d8")])
		L.append([_box(Vector3(0.06, 0.06, AZ * 2 + 2.3)), T(Vector3(side * (AX + 1.1), 0.7, 0)), Color("#d0d0d8")])
	# 저 아래 운동장과 하늘
	L.append([_box(Vector3(80, 0.1, 80)), T(Vector3(0, -12, 0)), Color("#d9b98a")])
	for c in [Vector3(-6.5, 0, -6.5), Vector3(6.5, 0, 6.5)]:
		if not ResourceLoader.exists("res://models/set_roof.glb"):
			L.append([_cyl(1.1, 1.8, -1, 16), T(c + Vector3(0, 0.9, 0)), Color("#5fa8d8")])
			L.append([_cyl(1.15, 0.12, -1, 16), T(c + Vector3(0, 1.85, 0)), Color("#3f88b8")])
		obstacles.append([c, Vector2(1.0, 1.0)])
	L.append([_box(Vector3(2.4, 2.4, 1.8)), T(Vector3(6.0, 1.2, -7.6)), Color("#e8dcc0")])
	L.append([_box(Vector3(1.0, 1.9, 0.08)), T(Vector3(6.0, 0.95, -6.66)), Color("#6b4a32")])
	obstacles.append([Vector3(6.0, 0, -7.6), Vector2(1.2, 0.9)])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)

func _world_music(e: Environment, sun: DirectionalLight3D) -> void:
	# 음악실: 나무 바닥, 피아노, 북, 실로폰
	e.background_color = Color("#3a2440")
	e.ambient_light_color = Color("#ffe1f0")
	e.ambient_light_energy = 0.46
	if not _tex_floor(Vector2(30, 30), "res://textures/floor_music.jpg", 7.0):
		_tile_floor(Vector2(30, 30), Color(0.72, 0.52, 0.34), Color(0.66, 0.47, 0.3), 0.8)
	var L: Array = []
	for side in [-1.0, 1.0]:
		L.append([_box(Vector3(0.4, 3.0, 23)), T(Vector3(side * (AX + 1.0), 1.5, 0)), Color("#f3e0f0")])
		L.append([_box(Vector3(23, 3.0, 0.4)), T(Vector3(0, 1.5, side * (AZ + 1.0))), Color("#f3e0f0")])
	# 칠판의 오선지
	L.append([_box(Vector3(8, 2.0, 0.08)), T(Vector3(0, 1.7, -AZ - 0.75)), Color("#2f5a3c")])
	for i in 5:
		L.append([_box(Vector3(7.4, 0.03, 0.02)), T(Vector3(0, 1.2 + i * 0.22, -AZ - 0.7)), Color.WHITE])
	# 피아노
	var pc := Vector3(-6.0, 0, -6.5)
	L.append([_box(Vector3(2.6, 1.3, 1.0)), T(pc + Vector3(0, 0.65, 0)), Color("#1e1a22")])
	L.append([_box(Vector3(2.4, 0.08, 0.35)), T(pc + Vector3(0, 0.95, 0.65)), Color.WHITE])
	for i in 10:
		L.append([_box(Vector3(0.1, 0.06, 0.2)), T(pc + Vector3(-1.0 + i * 0.22, 1.0, 0.6)), Color("#1e1a22")])
	obstacles.append([pc + Vector3(0, 0, 0.2), Vector2(1.3, 0.7)])
	# 북
	for c in [Vector3(6.5, 0, 6.0), Vector3(-6.5, 0, 6.0)]:
		L.append([_cyl(0.7, 0.7, -1, 18), T(c + Vector3(0, 0.35, 0)), Color("#e8433a")])
		L.append([_cyl(0.72, 0.06, -1, 18), T(c + Vector3(0, 0.72, 0)), Color("#f5f0e0")])
		obstacles.append([c, Vector2(0.6, 0.6)])
	# 실로폰
	var xc := Vector3(6.0, 0, -6.0)
	var xcols := [Color("#ff5c7a"), Color("#ff9a2f"), Color("#ffd23f"), Color("#6ee0b0"), Color("#58c6f2"), Color("#9b8cff")]
	for i in 6:
		L.append([_box(Vector3(0.28, 0.08, 1.0 - i * 0.08)), T(xc + Vector3(-0.8 + i * 0.32, 0.7, 0)), xcols[i]])
	L.append([_box(Vector3(2.0, 0.6, 0.2)), T(xc + Vector3(0, 0.35, 0)), Color("#8a5a3b")])
	obstacles.append([xc, Vector2(1.0, 0.5)])
	var wi := MeshInstance3D.new()
	wi.mesh = merge(L)
	wi.material_override = mat_vc
	add_child(wi)

func _tex_floor(size: Vector2, path: String, span: float) -> bool:
	# 그림 바닥: span 미터마다 한 장씩 반복해요
	if not ResourceLoader.exists(path):
		return false
	var pm := PlaneMesh.new()
	pm.size = size
	var sm := ShaderMaterial.new()
	sm.shader = _fx_shader("""
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float span;
varying vec2 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment(){ ALBEDO = texture(tex, wp / span).rgb; ROUGHNESS = 0.85; }
""")
	sm.set_shader_parameter("tex", load(path))
	sm.set_shader_parameter("span", span)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	add_child(mi)
	return true

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
	if not _tex_floor(Vector2(12, 70), "res://textures/floor_hall.jpg", 7.0):
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
	elif kind == "relay":
		var col := Color("#ff6b6b")
		L.append([_sph(0.3, 0.74, 16, 8), T(Vector3(0, 0.46, 0)), col])
		L.append([_cyl(0.31, 0.08, -1, 18), T(Vector3(0, 0.66, 0)), Color.WHITE])
		L.append([_box(Vector3(0.08, 0.2, 0.04)), T(Vector3(-0.1, 0.66, -0.3), Vector3(30, 0, 0)), Color.WHITE])
		_face_parts(L, 0.27, 0.48, 0.95)
		for sx in [-1.0, 1.0]:
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.3, 0.38, 0.06)), col.darkened(0.1)])
			L.append([_sph(0.07, -1, 8, 4), T(Vector3(sx * 0.12, 0.07, 0.0)), col.darkened(0.15)])
	elif kind == "pot":
		L.append([_cyl(0.26, 0.42, 0.18, 14), T(Vector3(0, 0.21, 0)), Color("#d9774a")])
		L.append([_cyl(0.28, 0.07, -1, 14), T(Vector3(0, 0.42, 0)), Color("#c0623a")])
		L.append([_sph(0.24, -1, 10, 5), T(Vector3(0, 0.62, 0)), Color("#5fae4e")])
		L.append([_sph(0.16, -1, 8, 4), T(Vector3(0.15, 0.75, 0.05)), Color("#74c25b")])
		L.append([_sph(0.07, -1, 8, 4), T(Vector3(-0.1, 0.82, 0.12)), Color("#ff7aa8")])
	elif kind == "ext":
		L.append([_cyl(0.15, 0.62, -1, 14), T(Vector3(0, 0.31, 0)), Color("#e8433a")])
		L.append([_sph(0.15, -1, 12, 6), T(Vector3(0, 0.62, 0)), Color("#e8433a")])
		L.append([_box(Vector3(0.1, 0.1, 0.24)), T(Vector3(0, 0.76, 0.06)), Color("#333344")])
		L.append([_cyl(0.03, 0.3, 0.05), T(Vector3(0.12, 0.55, 0.12), Vector3(30, 0, -20)), Color("#333344")])
		L.append([_box(Vector3(0.16, 0.12, 0.02)), T(Vector3(0, 0.35, 0.15)), Color.WHITE])
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

func _star3d() -> ArrayMesh:
	# 통통한 5각 별 (앞뒤로 볼록), 크기 약 0.14
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var pts: Array = []
	for i in 10:
		var a := PI / 2 + TAU * i / 10.0
		var r := 0.075 if i % 2 == 0 else 0.032
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for side in [1.0, -1.0]:
		var top := Vector3(0, 0, 0.035 * side)
		for i in 10:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 10]
			var tri := [top, a, b] if side > 0 else [top, b, a]
			var n: Vector3 = ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				verts.append(v)
				norms.append(n)
				cols.append(Color.WHITE)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _paper_plane(c1: Color, c2: Color, crane := false) -> ArrayMesh:
	# 앞이 -Z(look_at 기준)인 종이비행기: 날개 두 장 + 아래 용골
	var nose := Vector3(0, 0, -0.32)
	var tail := Vector3(0, 0.0, 0.22)
	var lw := Vector3(-0.28, 0.05, 0.24)
	var rw := Vector3(0.28, 0.05, 0.24)
	var keel := Vector3(0, -0.09, 0.22)
	var tris := [[nose, lw, tail, c1], [nose, tail, rw, c1], [nose, keel, tail, c2], [nose, tail, keel, c2]]
	if crane:
		tris.append([tail, Vector3(0, 0.22, 0.35), Vector3(0, 0.02, 0.1), c2])
		tris.append([lw, Vector3(-0.45, 0.25, 0.1), Vector3(-0.1, 0.05, 0.0), c1])
		tris.append([rw, Vector3(0.1, 0.05, 0.0), Vector3(0.45, 0.25, 0.1), c1])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for t in tris:
		var n: Vector3 = ((t[1] - t[0]) as Vector3).cross(t[2] - t[0]).normalized()
		for j in 3:
			verts.append(t[j])
			norms.append(n)
			cols.append(t[3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

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

func _shoe_mesh() -> ArrayMesh:
	# 실내화: 둥근 앞코와 뒤꿈치, 파란 고무 밑창 + 하얀 고무 테두리, 볼록한 발등, 파란 띠, 반짝 하이라이트
	var white := Color("#f7f4ec")
	var blue := Color("#4f7fe0")
	var trim := Color("#dfe4ee")
	var L: Array = []
	for z in [[-0.07, 0.085, 0.09], [0.08, 0.075, 0.08]]:
		L.append([_cyl(1.0, 0.04, -1, 14), T(Vector3(0, -0.01, z[0]), Vector3.ZERO, Vector3(z[1], 1, z[2])), blue])
		L.append([_cyl(1.0, 0.022, -1, 14), T(Vector3(0, 0.02, z[0]), Vector3.ZERO, Vector3(z[1] - 0.006, 1, z[2] - 0.006)), trim])
	L.append([_box(Vector3(0.15, 0.04, 0.15)), T(Vector3(0, -0.01, 0.005)), blue])
	L.append([_box(Vector3(0.138, 0.022, 0.15)), T(Vector3(0, 0.02, 0.005)), trim])
	L.append([_sph(1.0, -1, 12, 6), T(Vector3(0, 0.035, -0.045), Vector3.ZERO, Vector3(0.074, 0.07, 0.115)), white])
	L.append([_cyl(1.0, 0.075, -1, 12), T(Vector3(0, 0.065, 0.075), Vector3.ZERO, Vector3(0.068, 1, 0.07)), white])
	L.append([_cyl(1.0, 0.01, -1, 12), T(Vector3(0, 0.1, 0.075), Vector3.ZERO, Vector3(0.05, 1, 0.052)), Color("#4a3a44")])
	L.append([_cyl(1.0, 1.0, -1, 10), T(Vector3(0, 0.07, 0.01), Vector3(0, 0, 90), Vector3(0.158, 0.052, 0.03)), blue])
	L.append([_sph(1.0, -1, 8, 4), T(Vector3(-0.028, 0.095, -0.07), Vector3.ZERO, Vector3(0.018, 0.008, 0.035)), Color(1.0, 1.0, 1.0)])
	return merge(L)

func _coin_mesh() -> ArrayMesh:
	# 두툼한 동전: 진한 테두리, 밝은 앞면, 가운데 볼록한 무늬, 옆면 톱니, 반짝 줄
	var gold := Color("#f5c03a")
	var dark := Color("#c98a1a")
	var L: Array = []
	L.append([_cyl(0.55, 0.14, -1, 24), T(Vector3.ZERO), dark])
	L.append([_cyl(0.46, 0.15, -1, 24), T(Vector3.ZERO), gold])
	L.append([_cyl(0.24, 0.17, -1, 16), T(Vector3.ZERO), Color("#e5a52a")])
	L.append([_cyl(0.16, 0.18, -1, 12), T(Vector3.ZERO), Color("#ffe07a")])
	for i in 20:
		var a := TAU * i / 20.0
		L.append([_box(Vector3(0.03, 0.11, 0.05)), T(Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), Vector3(0, -rad_to_deg(a), 0)), Color("#a86f12")])
	for i in 6:
		var a := TAU * i / 6.0
		L.append([_sph(0.035, -1, 6, 3), T(Vector3(cos(a) * 0.35, 0.075, sin(a) * 0.35)), Color("#fff0a8")])
	L.append([_box(Vector3(0.06, 0.01, 0.34)), T(Vector3(-0.18, 0.08, -0.05), Vector3(0, 35, 0)), Color(1.0, 0.98, 0.85)])
	return merge(L)

func _top_mesh(c1: Color, c2: Color) -> ArrayMesh:
	# 위에서 봐도 팽이로 보이게: 넓은 윗판(줄무늬) + 아래로 뾰족한 몸통 + 쇠심 + 손잡이
	var L: Array = []
	L.append([_cyl(0.24, 0.07, 0.24, 20), T(Vector3(0, 0.1, 0)), c1])
	L.append([_cyl(0.245, 0.03, 0.245, 20), T(Vector3(0, 0.075, 0)), c2])
	L.append([_cyl(0.18, 0.012, 0.18, 20), T(Vector3(0, 0.14, 0)), c2])
	L.append([_cyl(0.11, 0.014, 0.11, 16), T(Vector3(0, 0.146, 0)), c1.lightened(0.25)])
	L.append([_cyl(0.23, 0.2, 0.03, 16), T(Vector3(0, -0.04, 0)), c1.darkened(0.15)])
	L.append([_cyl(0.025, 0.08, 0.008, 8), T(Vector3(0, -0.17, 0)), Color("#c9ccd6")])
	L.append([_cyl(0.04, 0.12, 0.05, 10), T(Vector3(0, 0.2, 0)), Color("#8a5a2b")])
	L.append([_sph(0.05, -1, 8, 4), T(Vector3(0, 0.27, 0)), Color("#a8743f")])
	for i in 4:
		var a := TAU * i / 4.0
		L.append([_box(Vector3(0.05, 0.018, 0.05)), T(Vector3(cos(a) * 0.15, 0.142, sin(a) * 0.15), Vector3(0, 45, 0)), Color.WHITE])
	return merge(L)

func _make_multimeshes() -> void:
	for kind in KINDS:
		var glb := "res://models/%s.glb" % (BOSS_MODELS.get(boss_stage(), "boss_locker") if kind == "boss" else GHOST_MODELS.get(kind, ""))
		if GHOST_MODELS.has(kind) and ResourceLoader.exists(glb):
			_mm_textured(kind, glb, 4 if kind == "boss" else MAX_ENEMY)
		else:
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
	var GC: Array = []
	GC.append([_box(Vector3(0.9, 0.7, 0.7)), T(Vector3(0, 0.35, 0)), Color("#e8433a")])
	GC.append([_box(Vector3(0.6, 0.18, 0.05)), T(Vector3(0, 0.45, 0.36)), Color("#fff3b0")])
	GC.append([_box(Vector3(0.18, 0.18, 0.06)), T(Vector3(0.22, 0.2, 0.36)), Color("#ffd23f")])
	GC.append([_sph(0.42, 0.75, 16, 8), T(Vector3(0, 1.0, 0)), Color("#cfeeff")])
	var cap_cols := [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#9b8cff"), Color("#58c6f2")]
	for i in 7:
		var a := TAU * i / 7.0
		GC.append([_sph(0.11, -1, 8, 4), T(Vector3(cos(a) * 0.2, 0.85 + (i % 3) * 0.1, sin(a) * 0.2)), cap_cols[i % 5]])
	GC.append([_cyl(0.43, 0.08), T(Vector3(0, 1.38, 0)), Color("#e8433a")])
	gacha_mesh = merge(GC)
	_mm("coin", _cyl(0.13, 0.04, -1, 14), 200, true)
	_mm("eshot", _shoe_mesh(), 120, true)
	coin_fall_mesh = _coin_mesh()
	_mm("gem", _ddakji_mesh(Color.WHITE, Color(1, 1, 1).darkened(0.25)), 300, true)
	_mm("bullet", _sph(0.17, -1, 10, 5), 80, false)
	(mm["bullet"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){
  float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
  vec3 c = mix(vec3(1.0), cu.rgb, smoothstep(0.15, 0.7, f));
  c += vec3(0.8) * pow(f, 10.0);
  ALBEDO = c; ALPHA = cu.a * (0.55 + 0.45 * f);
}
""")
	_mm("drop", _sph(1.0, -1, 10, 5), 260, false)
	(mm["drop"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ ALBEDO = cu.rgb; ROUGHNESS = 0.08; METALLIC = 0.0; EMISSION = cu.rgb * 0.15; ALPHA = cu.a; }
""")
	_mm("star", _star3d(), 200, false)
	(mm["star"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ ALBEDO = cu.rgb; ROUGHNESS = 0.35; METALLIC = 0.0; EMISSION = cu.rgb * 0.25; ALPHA = cu.a; }
""")
	# 빛나는 알갱이(더하기 섞기), 퍼지는 고리, 뭉게구름
	_mm("glow", _sph(1.0, -1, 10, 5), 320, false)
	(mm["glow"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6); ALBEDO = cu.rgb; ALPHA = f * cu.a; }
""")
	_mm("bglow", _sph(1.0, -1, 10, 5), 80, false)
	(mm["bglow"].material_override as ShaderMaterial).shader = (mm["glow"].material_override as ShaderMaterial).shader
	_mm("eglow", _sph(1.0, -1, 10, 5), 120, false)
	(mm["eglow"].material_override as ShaderMaterial).shader = (mm["glow"].material_override as ShaderMaterial).shader
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 40
	tor.ring_segments = 8
	_mm("ring", tor, 90, false)
	(mm["ring"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ ALBEDO = cu.rgb; ROUGHNESS = 0.2; EMISSION = cu.rgb * 0.7; ALPHA = cu.a; }
""")
	_mm("puff", _sph(1.0, -1, 10, 5), 140, false)
	(mm["puff"].material_override as ShaderMaterial).shader = _fx_shader("""
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
varying vec4 cu;
void vertex(){ cu = INSTANCE_CUSTOM; }
void fragment(){ float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 0.5); ALBEDO = cu.rgb; ROUGHNESS = 1.0; ALPHA = f * cu.a; }
""")
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
	plane_mesh = _paper_plane(Color("#f5f8ff"), Color("#9cc2ff"))
	crane_mesh = _paper_plane(Color("#fff3b0"), Color("#ff9ab8"), true)
	var PP: Array = []
	PP.append([_sph(0.1, -1, 8, 4), T(Vector3.ZERO), Color("#ff4f4f")])
	PP.append([_sph(0.06, -1, 6, 3), T(Vector3(0.05, 0.06, 0.03)), Color("#fff3e0")])
	pop_mesh = merge(PP)
	mat_vc_2s = mat_vc.duplicate()
	mat_vc_2s.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_vc_2s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ddakji_mesh = _ddakji_mesh(Color("#ff7aa8"), Color("#ffd1e1"))
	ddakji_gold_mesh = _ddakji_mesh(Color("#ffc928"), Color("#fff3b0"))
	yoyo_mesh = _yoyo_mesh(Color("#2fc79a"))
	yoyo_evo_mesh = _yoyo_mesh(Color("#ffd23f"))
	top_mesh = _top_mesh(Color("#e8524a"), Color("#ffd23f"))
	top_evo_mesh = _top_mesh(Color("#8a5cff"), Color("#6ee0ff"))

# =========================================================
# 철수
# =========================================================
func _make_player() -> void:
	player = Node3D.new()
	add_child(player)
	_load_model(char_id)
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

func _load_model(cid: String) -> void:
	if model:
		model.queue_free()
	var path := "res://models/%s.glb" % cid
	if not ResourceLoader.exists(path):
		path = "res://models/chulsoo.glb"
	model = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * 1.5
	player.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	bones = {}
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), skel.get_bone_global_rest(i).basis.get_rotation_quaternion()]

func set_character(cid: String) -> void:
	# 메뉴에서 친구를 바꾸면 바로 모습이 바뀌어요
	char_id = cid
	var w: String = Save.CHARS[cid]["weapon"]
	mains = {w: 1}
	main_order = [w]
	_load_model(cid)

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
	if mains.has("gun"):
		pose_bone("armL", Q(Vector3.RIGHT, -62.0 + recoil * 14.0) * Q(Vector3.BACK, 66.0) * Q(Vector3.UP, -18.0))
		pose_bone("foreL", Q(Vector3.UP, -30.0))
		pose_bone("armR", Q(Vector3.RIGHT, -55.0 + recoil * 10.0) * Q(Vector3.BACK, -70.0) * Q(Vector3.UP, 32.0))
		pose_bone("foreR", Q(Vector3.UP, 38.0))
	else:
		# 무기를 안 든 친구는 팔을 흔들며 달려요
		var asw := 40.0 * run_amt
		var cheer := recoil * 25.0
		pose_bone("armL", Q(Vector3.RIGHT, asw * s - cheer) * Q(Vector3.BACK, 68.0 - cheer))
		pose_bone("foreL", Q(Vector3.RIGHT, -20.0 * run_amt))
		pose_bone("armR", Q(Vector3.RIGHT, -asw * s - cheer) * Q(Vector3.BACK, -68.0 + cheer))
		pose_bone("foreR", Q(Vector3.RIGHT, -20.0 * run_amt))
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
func supports_def() -> Dictionary:
	return SUPPORTS

func lv(id: String) -> int:
	return int(mains.get(id, 0)) + int(supports.get(id, 0))

func combo_mult() -> float:
	# 콤보가 쌓일수록 세져요: 25콤보마다 +5%, 최대 +60%
	return 1.0 + minf(0.6, float(combo / 25) * 0.05)

func dmg_mult() -> float:
	return (1.0 + 0.15 * lv("bottle")) * (1.0 + 0.08 * Save.shop_lv("dmg")) * float(Save.CHARS[char_id].get("power", 1.0))
func crit_chance() -> float:
	return 0.12 + 0.03 * Save.shop_lv("luck") + (0.08 if char_id == "younghee" else 0.0)
func xp_mult() -> float:
	return (1.0 + 0.06 * Save.shop_lv("xp") + (0.15 if char_id == "minsu" else 0.0)) * (1.3 if day_mod == "exam" else 1.0)
func coin_mult() -> float:
	return (1.0 + 0.1 * Save.shop_lv("coin")) * (1.0 + 0.35 * (dg - 1)) * (1.0 + (STAGE_MULT[stage] - 1.0) * 0.8) * {"rain": 1.2, "sports": 1.2, "vacation": 1.3}.get(day_mod, 1.0)
const STAGE_MULT := {"ground": 1.0, "hall": 1.05, "lab": 1.1, "toilet": 1.15, "roof": 1.2, "music": 1.25}
const BOSS_ORDER := ["ground", "hall", "lab", "toilet", "roof", "music"]
const BOSS_RANKS_KO := [
	{"pre": "", "tint": Color(1, 1, 1), "scale": 1.0},
	{"pre": "화난 ", "tint": Color(1.7, 0.5, 0.45), "scale": 1.1},
	{"pre": "얼음 ", "tint": Color(0.55, 1.1, 1.8), "scale": 1.15},
	{"pre": "그림자 ", "tint": Color(0.55, 0.45, 0.8), "scale": 1.2},
	{"pre": "황금 ", "tint": Color(1.45, 1.2, 0.5), "scale": 1.28},
	{"pre": "전설의 ", "tint": Color(1.4, 0.6, 1.4), "scale": 1.38},
]
var BOSS_RANKS: Array = Save.trd(BOSS_RANKS_KO)
func boss_stage() -> String:
	# 단계가 오를 때마다 다른 장소의 보스가 나와요 (1단계는 그 장소의 보스)
	var i := BOSS_ORDER.find(stage)
	return BOSS_ORDER[(i + grade - 1) % BOSS_ORDER.size()]
func boss_rank() -> Dictionary:
	# 여섯 보스를 한 바퀴 돌 때마다 색과 크기가 바뀌어요
	return BOSS_RANKS[mini((dg - 1) / BOSS_ORDER.size(), BOSS_RANKS.size() - 1)]
func boss_name() -> String:
	return boss_rank()["pre"] + Save.STAGES[boss_stage()]["boss"]

# 처음 단계는 순하게: 실제 난이도 1에서 10까지 차츰 원래 세기로 올라가요
func ease_x() -> float:
	return clampf((dg - 1) / 9.0, 0.0, 1.0)
func ease_hp() -> float:
	return lerpf(EASE_HP0, 1.0, ease_x())
func ease_spawn() -> float:
	return lerpf(EASE_SPAWN0, 1.0, ease_x())
func ease_boss() -> float:
	return lerpf(EASE_BOSS0, 1.0, ease_x())
func ease_hp_for(d: int) -> float:
	return lerpf(EASE_HP0, 1.0, clampf((d - 1) / 9.0, 0.0, 1.0))
const EASE_HP0 := 0.45
const EASE_SPAWN0 := 1.0   # 귀신 수는 줄이지 않아요 (초반이 너무 비어 보여서)
const EASE_BOSS0 := 0.3

func grade_hp() -> float:
	var g := float(dg - 1)
	return (1.0 + 0.45 * g + 0.02 * g * g) * STAGE_MULT[stage]
func area_mult() -> float:
	return 1.0 + 0.15 * lv("notebook")
func cd_mult() -> float:
	return 1.0 - 0.08 * lv("watch")
func move_speed() -> float:
	return 4.2 * (1.0 + 0.1 * lv("sneakers")) * (1.0 + 0.05 * Save.shop_lv("speed")) * (1.2 if day_mod == "sports" else 1.0)
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
		return {"count": 4, "dmg": 24.0, "dist": 4.3, "cool": 1.4, "chain": 3}
	return {"count": 1 + (1 if l >= 2 else 0) + (1 if l >= 5 else 0), "dmg": 14.0 * (1.4 if l >= 3 else 1.0),
		"dist": 3.0 * (1.25 if l >= 4 else 1.0), "cool": 1.7, "chain": 0}

func rubber_stats() -> Dictionary:
	var d := _rubber_base()
	var w := Save.shop_lv("w_rubber")
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	return d

func _rubber_base() -> Dictionary:
	var l := lv("rubber")
	if evolved.has("rubber"):
		return {"cool": 1.4, "radius": 4.2, "dmg": 24.0, "knock": 15.0, "double": true}
	return {"cool": 3.0 * (0.72 if l >= 4 else 1.0), "radius": 2.6 * (1.2 if l >= 2 else 1.0) * (1.2 if l >= 5 else 1.0),
		"dmg": 12.0 * (1.4 if l >= 3 else 1.0), "knock": 13.0 if l >= 5 else 10.0, "double": false}

func top_stats() -> Dictionary:
	var l := lv("top")
	var w := Save.shop_lv("w_top")
	var d: Dictionary
	if evolved.has("top"):
		d = {"count": 4, "dmg": 22.0, "life": 4.2, "cool": 3.6, "size": 1.3, "knock": 9.0, "speed": 3.6, "pull": 2.6}
	else:
		d = {"count": 1 + (1 if l >= 2 else 0) + (1 if l >= 5 else 0), "dmg": 11.0 * (1.4 if l >= 3 else 1.0),
			"life": 3.4 * (1.5 if l >= 4 else 1.0), "cool": 3.4, "size": 1.25 if l >= 5 else 1.0, "knock": 8.0, "speed": 3.0, "pull": 0.0}
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	return d

func proj_speed() -> float:
	return 1.0 + 0.15 * lv("colorpaper")

func plane_stats() -> Dictionary:
	var l := lv("plane")
	var w := Save.shop_lv("w_plane")
	var d: Dictionary
	if evolved.has("plane"):
		d = {"count": 6, "dmg": 24.0, "pierce": 5, "speed": 10.0, "cool": 1.6, "life": 3.0}
	else:
		d = {"count": 1 + (1 if l >= 2 else 0) + (1 if l >= 4 else 0), "dmg": 12.0 * (1.4 if l >= 3 else 1.0),
			"pierce": 2 if l >= 5 else 0, "speed": 8.0 * (1.2 if l >= 4 else 1.0), "cool": 1.5, "life": 2.2}
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	d["speed"] *= proj_speed()
	return d

func pop_stats() -> Dictionary:
	var l := lv("pop")
	var w := Save.shop_lv("w_pop")
	var d: Dictionary
	if evolved.has("pop"):
		d = {"count": 3, "dmg": 32.0, "radius": 2.4, "cool": 1.3}
	else:
		d = {"count": 1 + (1 if l >= 2 else 0) + (2 if l >= 5 else 0), "dmg": 14.0 * (1.4 if l >= 4 else 1.0),
			"radius": 1.4 * (1.25 if l >= 3 else 1.0), "cool": 1.8}
	d["dmg"] *= 1.0 + 0.12 * w
	d["cool"] *= 1.0 - 0.04 * w
	return d

func evo_ready(id: String) -> bool:
	return mains.get(id, 0) >= MAX_LV and supports.has(MAINS[id]["partner"]) and not evolved.has(id) and evo_open(id)

# 진화 비법: 내 친구의 시작 무기 비법은 처음부터 알고, 나머지는 단계를 깨면 열려요
func evo_open(id: String) -> bool:
	return Save.evo_open(id, Save.CHARS[char_id]["weapon"])

var evo_hint := {}
func _evo_lock_hint() -> void:
	# 세트는 모았는데 진화 비법이 잠겨 있으면 한 번 알려 줘요
	for id in MAINS:
		if mains.get(id, 0) >= MAX_LV and supports.has(MAINS[id]["partner"]) and not evolved.has(id) and not evo_open(id) and not evo_hint.has(id):
			evo_hint[id] = true
			_banner(tr("%s 비법은 아직 잠겨 있어요!") % MAINS[id]["evo"] + "\n" + Save.evo_need_text(id, Save.CHARS[char_id]["weapon"]), Color("#ffd23f"))
			return

# =========================================================
# 귀신
# =========================================================
func _make_enemy(kind: String, pos: Vector3, elite := false) -> Dictionary:
	if kind != "boss" and enemies.size() >= MAX_ENEMY - 2:
		return {}
	var k: Dictionary = KINDS[kind]
	var t := elapsed / RUN_TIME
	var hpv: float = k["hp"] * (1.0 + t * 3.0 + t * t * 6.0) * grade_hp() * (1.0 + 0.35 * clampf(t * 2.0, 0.0, 1.0)) * ease_hp()
	if kind == "boss":
		hpv = k["hp"] * grade_hp() * ease_boss()
	var e := {"pos": pos, "vel": Vector3.ZERO, "rot": 0.0, "kind": kind, "hp": hpv, "flash": 0.0,
		"squash": 0.0, "phase": rng.randf() * TAU, "spawn": 0.0, "dead": -1.0, "slow": 0.0, "elite": elite,
		"speed": k["speed"] * (1.0 + t * 0.3) * (1.0 + minf(0.4, 0.02 * (dg - 1))) * (1.2 if day_mod == "sports" else 1.0) * (1.1 if day_mod == "vacation" else 1.0) * weather_speed(), "radius": k["r"], "scale": k["scale"], "xp": k["xp"], "hits": {},
		"dash": rng.randf_range(1.5, 3.5), "dash_t": 0.0, "summon": 3.0}
	if k.has("prop"):
		e["prop"] = true
		e["hp"] = k["hp"] * (1.0 + 0.3 * (dg - 1))
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
	var count := maxi(1, int((1 + int(t * 9.0)) * (1.0 + 0.12 * (dg - 1)) * (1.0 + (STAGE_MULT[stage] - 1.0) * 0.4) * weather_spawn() * ease_spawn()))
	if boss_spawned:
		count = maxi(1, count / 3)
	# 시간이 지날수록 센 귀신이 섞여요
	var pool := {}
	for kind in KINDS:
		if not ["boss", "relay", "pot", "ext"].has(kind) and elapsed >= kind_from(kind):
			pool[kind] = {"paper": 5.0, "egg": 3.0, "kettle": 1.2, "eraser": 1.6, "dust": 1.0, "report": 1.3}[kind]
	for i in count:
		if enemies.size() >= (MAX_ENEMY - 8 if not mobile_web else 80):
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
var elite_drops := 0
var boss_spawned := false
var boss: Dictionary = {}
var boss_warned := false
var mission := {}
var mission_label: Label
var mission_zone: Node3D
const ZONE_R := 2.2
const ZONE_WALL_SH := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float t = 0.0;
void fragment(){
  float h = UV.y;            // 0 = 위, 1 = 바닥
  float fade = pow(h, 2.2);
  float stripe = 0.65 + 0.35 * sin((h * 9.0 + t * 2.5) * 3.14159);
  ALBEDO = col.rgb;
  ALPHA = clamp(fade * stripe * col.a, 0.0, 1.0);
}
"""

# 숙제 검사 동그라미: 살짝 솟은 무대 + 무늬 있는 윗면(채워지는 초록 부채꼴) + 테두리 + 빛 기둥
const ZONE_TOP_SH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float t = 0.0;
uniform float prog = 0.0;
uniform float glow = 0.0;
varying vec2 lp;
void vertex(){ lp = VERTEX.xz / 2.1; }
void fragment(){
  float r = length(lp);
  float ang = atan(lp.y, lp.x) / 6.28318 + 0.5;
  vec3 c = col.rgb * mix(1.12, 0.8, r);
  float rip = smoothstep(0.82, 1.0, sin((r * 4.0 - t * (1.2 + glow)) * 6.28318) * 0.5 + 0.5);
  c = mix(c, vec3(1.0), rip * (0.25 + 0.2 * glow) * (1.0 - r));
  float pie = step(ang, prog) * step(r, 0.76);
  c = mix(c, vec3(0.25, 0.85, 0.4), pie * 0.85);
  float ring = smoothstep(0.035, 0.0, abs(r - 0.8)) * step(0.45, fract(ang * 28.0 - t * 0.4));
  c = mix(c, vec3(1.0), ring * 0.85);
  c = mix(c, col.rgb * 0.62, smoothstep(0.92, 1.0, r));
  ALBEDO = c;
}
"""
func _make_zone(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var base := MeshInstance3D.new()
	base.mesh = _cyl(ZONE_R, 0.16, ZONE_R * 1.07, 48)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.88, 0.56, 0.18)
	bm.roughness = 0.7
	base.material_override = bm
	base.position = Vector3(0, 0.08, 0)
	root.add_child(base)
	var top := MeshInstance3D.new()
	top.mesh = _cyl(ZONE_R - 0.02, 0.01, -1, 48)
	var tsm := ShaderMaterial.new()
	tsm.shader = _fx_shader(ZONE_TOP_SH)
	top.material_override = tsm
	top.position = Vector3(0, 0.165, 0)
	root.add_child(top)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ZONE_R - 0.07
	tm.outer_radius = ZONE_R + 0.07
	tm.rings = 48
	tm.ring_segments = 8
	rim.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.97, 0.7)
	rim.material_override = rm
	rim.position = Vector3(0, 0.17, 0)
	rim.scale = Vector3(1, 0.7, 1)
	root.add_child(rim)
	var wall := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = ZONE_R
	wc.bottom_radius = ZONE_R
	wc.height = 1.6
	wc.cap_top = false
	wc.cap_bottom = false
	wc.radial_segments = 48
	wc.rings = 1
	wall.mesh = wc
	var wm := ShaderMaterial.new()
	wm.shader = _fx_shader(ZONE_WALL_SH)
	wall.material_override = wm
	wall.position = Vector3(0, 0.8 + 0.16, 0)
	root.add_child(wall)
	root.set_meta("parts", {"base": bm, "top": tsm, "rim_m": rm, "wall": wm})
	return root

func _zone_update(inside: bool, prog: float) -> void:
	var zone_parts: Dictionary = mission_zone.get_meta("parts")
	var c := Color(0.55, 0.95, 0.45) if inside else Color(1.0, 0.82, 0.25)
	var pulse := 0.5 + 0.5 * sin(elapsed * 6.0)
	var tp: ShaderMaterial = zone_parts["top"]
	tp.set_shader_parameter("col", Color(1.0, 0.9, 0.35) if inside else c)
	tp.set_shader_parameter("t", elapsed)
	tp.set_shader_parameter("prog", clampf(prog, 0.0, 1.0))
	tp.set_shader_parameter("glow", 1.0 if inside else 0.0)
	(zone_parts["base"] as StandardMaterial3D).albedo_color = Color(0.4, 0.72, 0.3) if inside else Color(0.88, 0.56, 0.18)
	(zone_parts["rim_m"] as StandardMaterial3D).albedo_color = c.lerp(Color.WHITE, 0.55 + 0.35 * pulse)
	var w: ShaderMaterial = zone_parts["wall"]
	w.set_shader_parameter("col", Color(c.r, c.g, c.b, 0.8 if inside else 0.45 + 0.25 * pulse))
	w.set_shader_parameter("t", elapsed)
var missions_done := 0
func _start_mission() -> void:
	var kinds := ["kills", "nohit", "zone", "combo"]
	var k: String = kinds[rng.randi() % kinds.size()]
	mission = {"kind": k, "t": 0.0, "prog": 0, "start_kills": kills}
	match k:
		"kills":
			mission["goal"] = 25 + mini(dg, 10) * 2
			mission["time"] = 25.0
			mission["text"] = tr("숙제 검사! %d초 안에 귀신 %d마리")
		"nohit":
			mission["goal"] = 15
			mission["time"] = 15.0
			mission["text"] = tr("숙제 검사! %d초 동안 한 대도 안 맞기")
		"zone":
			mission["goal"] = 8
			mission["time"] = 25.0
			var a := rng.randf() * TAU
			var zp := player.position + Vector3(cos(a), 0, sin(a)) * 5.0
			zp.x = clampf(zp.x, -AX + 2.0, AX - 2.0)
			zp.z = clampf(zp.z, -AZ + 2.0, AZ - 2.0)
			mission["pos"] = _push_out(zp, 2.0)
			mission["text"] = tr("숙제 검사! 노란 동그라미 안에서 %d초 버티기")
			mission_zone = _make_zone(mission["pos"])
		"combo":
			mission["goal"] = 40 + mini(dg, 10) * 3
			mission["time"] = 30.0
			mission["text"] = tr("숙제 검사! %d초 안에 %d콤보 만들기")
	_banner(tr("선생님이 숙제를 냈어요!"), Color("#6ee0b0"))
	_play("bell", 1.3, -4.0)
	if mission_label == null:
		mission_label = _label("", 30, Color("#fff8e8"), hud, 9)
		mission_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_label.offset_left = -340
		mission_label.offset_right = 340
		mission_label.offset_top = 170
		mission_label.offset_bottom = 260
	mission_label.visible = true

func _update_mission(dt: float) -> void:
	if mission.is_empty():
		return
	mission["t"] += dt
	var left: float = mission["time"] - mission["t"]
	var done := false
	var line := ""
	match mission["kind"]:
		"kills":
			mission["prog"] = kills - int(mission["start_kills"])
			done = mission["prog"] >= mission["goal"]
			line = tr("귀신 %d / %d   남은 시간 %d초") % [mini(mission["prog"], mission["goal"]), mission["goal"], ceili(left)]
		"nohit":
			if nohit_t < mission["t"] - 0.05:
				_end_mission(false)
				return
			mission["prog"] = int(mission["t"])
			done = mission["t"] >= mission["goal"]
			line = tr("안 맞고 %d / %d초") % [mini(mission["prog"], mission["goal"]), mission["goal"]]
		"zone":
			var zp: Vector3 = mission["pos"]
			var inside := Vector2(player.position.x - zp.x, player.position.z - zp.z).length() < ZONE_R
			if inside:
				mission["prog"] = float(mission["prog"]) + dt
			if mission_zone:
				_zone_update(inside, float(mission["prog"]) / float(mission["goal"]))
			done = float(mission["prog"]) >= mission["goal"]
			line = tr("동그라미 안 %.1f / %d초   남은 시간 %d초") % [minf(mission["prog"], mission["goal"]), mission["goal"], ceili(left)]
		"combo":
			mission["prog"] = maxi(int(mission["prog"]), combo)
			done = mission["prog"] >= mission["goal"]
			line = tr("최고 %d / %d콤보   남은 시간 %d초") % [mini(mission["prog"], mission["goal"]), mission["goal"], ceili(left)]
	var head: String = mission["text"]
	var n := head.count("%d")
	if n == 2:
		head = head % [int(mission["time"]), mission["goal"]]
	else:
		head = head % [mission["goal"]]
	mission_label.text = head + "\n" + line
	mission_label.add_theme_font_size_override("font_size", 30)
	_fit(mission_label, 680, 0.7)
	if done:
		_end_mission(true)
	elif left <= 0.0 and mission["kind"] != "nohit":
		_end_mission(false)

func _end_mission(ok: bool) -> void:
	if mission_zone:
		mission_zone.queue_free()
		mission_zone = null
	mission = {}
	mission_label.visible = false
	if ok:
		missions_done += 1
		_banner(tr("참 잘했어요! 보물 상자!"), Color("#ffdf3d"))
		_play("evo", 1.2, -3.0)
		_drop("chest", player.position + Vector3(1.2, 0, 0))
		_ring(player.position, Color(1.0, 0.85, 0.3, 1.0), 0.3, 3.0, 0.6)
		_sparkle(player.position + Vector3(0, 1, 0), Color(1.0, 0.9, 0.4, 1.0), 20, 6.0, 0.15, 0.7)
	else:
		_banner(tr("숙제를 못 했어요..."), Color("#b9b0bf"))
		_play("ui_error", 1.0, -4.0)

func _spawn_props(n: int) -> void:
	var alive := 0
	for e in enemies:
		if e.has("prop") and e["dead"] < 0.0:
			alive += 1
	for i in mini(n, 8 - alive):
		for tries in 12:
			var p := Vector3(rng.randf_range(-AX + 1, AX - 1), 0, rng.randf_range(-AZ + 1, AZ - 1))
			if stage == "hall":
				p.z = clampf(player.position.z + rng.randf_range(-14, 14), -AZ + 1, AZ - 1)
			if p.distance_to(player.position) < 3.0 or _push_out(p, 0.6) != p:
				continue
			var e := _make_enemy("pot" if rng.randf() < 0.6 else "ext", p)
			if not e.is_empty():
				e["rot"] = rng.randf() * TAU
				e["spawn"] = 0.0
			break

func _once(key: String) -> bool:
	if ev_done.has(key):
		return false
	ev_done[key] = true
	return true

func _event_logic() -> void:
	var dt := get_process_delta_time()
	flee_t = maxf(0.0, flee_t - dt)
	# 부서지는 물건 보충
	if elapsed >= next_props:
		next_props += 55.0
		_spawn_props(3)
	# 선생님의 숙제 검사: 짧은 미션을 깨면 보물 상자
	for at in [60.0, 140.0, boss_time - 45.0]:
		if elapsed >= at and _once("mission%d" % int(at)) and mission.is_empty():
			_start_mission()
	_update_mission(dt)
	# 급식 시간: 하트 잔치
	if elapsed >= 120.0 and _once("lunch"):
		_banner(tr("급식 시간! 하트를 먹어요"), Color("#ff5c7a"))
		_play("level", 1.0, -3.0)
		for i in 2:
			var a := TAU * i / 2.0 + rng.randf()
			var hp_pos := player.position + Vector3(cos(a), 0, sin(a)) * 3.0
			hp_pos.x = clampf(hp_pos.x, -AX + 0.5, AX - 0.5)
			hp_pos.z = clampf(hp_pos.z, -AZ + 0.5, AZ - 0.5)
			_drop("heart", _push_out(hp_pos, 0.5))
	# 쉬는 시간 종: 귀신이 우르르 도망가요
	var bell_t := boss_time - 70.0
	if elapsed >= bell_t and _once("bell"):
		_banner(tr("땡땡땡! 쉬는 시간!\n귀신들이 도망가요"), Color("#6ee0b0"))
		_play("bell", 1.0, -1.0)
		flee_t = 4.5
	# 운동회 날: 계주 귀신
	if day_mod == "sports":
		for at in [100.0, 200.0]:
			if elapsed >= at and _once("relay%d" % int(at)):
				_banner(tr("계주 귀신 출발!"), Color("#ff6b6b"))
				_play("warn", 1.6, -4.0)
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				for i in 6:
					_make_enemy("relay", Vector3(side * AX, 0, clampf(player.position.z - 3.0 + i * 1.2, -AZ, AZ)))
	# 옥상: 바람
	if stage == "roof":
		wind_t -= dt
		if wind_t <= 0.0 and wind_on <= 0.0:
			var dirs := [[Vector3(1, 0, 0), tr("오른쪽으로")], [Vector3(-1, 0, 0), tr("왼쪽으로")], [Vector3(0, 0, 1), tr("아래로")], [Vector3(0, 0, -1), tr("위로")]]
			var d: Array = dirs[rng.randi() % 4]
			set_meta("wind_dir", d[0])
			_banner(tr("휘이잉! 바람이 ") + d[1] + tr(" 불어요"), Color("#9fd8ff"))
			_play("rubber", 0.4, -6.0)
			wind_on = 4.5
			wind_t = 13.0
		if wind_on > 0.0:
			wind_on -= dt
			wind = (get_meta("wind_dir") as Vector3) * 2.2 if wind_on < 3.3 and wind_on > 0.0 else Vector3.ZERO
			if rng.randf() < 0.6:
				var sp := player.position + Vector3(rng.randf_range(-6, 6), rng.randf_range(0.3, 2.5), rng.randf_range(-8, 6))
				_part("drop", sp, wind * 6.0 + Vector3(0, 9.0, 0) * 0.1, Color(1, 1, 1, 0.6), 0.05, 0.6)
		else:
			wind = Vector3.ZERO
	# 음악실: 박자마다 쿵짝, 네 박자마다 충격파
	if stage == "music":
		beat_t -= dt
		if beat_t <= 0.0:
			beat_t += 0.5
			beat_n += 1
			_play("kick" if beat_n % 2 == 1 else "hat", 1.0, -12.0 if beat_n % 4 != 0 else -6.0)
			for e in enemies:
				if not e.has("prop"):
					e["squash"] = maxf(e["squash"], 0.25)
			if beat_n % 8 == 0:
				_rubber_wave({"radius": 2.2, "dmg": 6.0 + level * 0.5, "knock": 4.5, "double": false}, 0.0, Color("#c98ef0"))
	# 비 오는 날: 빗방울
	if day_mod == "rain":
		for i in 3:
			var rp := player.position + Vector3(rng.randf_range(-7, 7), 7.0, rng.randf_range(-10, 7))
			_part("drop", rp, Vector3(0.6, -16.0, 0), Color(0.75, 0.85, 1.0, 0.55), 0.035, 0.45)
	if elapsed >= next_elite and not boss_spawned:
		next_elite += 40.0
		var kinds: Array = []
		for kind in KINDS:
			if not ["boss", "dust", "relay", "pot", "ext"].has(kind) and elapsed >= kind_from(kind):
				kinds.append(kind)
		_make_enemy(kinds[rng.randi() % kinds.size()], _spawn_point(), true)
		_banner(tr("반짝반짝 정예 귀신 등장!"), Color("#ffdf3d"))
		_play("warn", 1.4, -10.0)
	if elapsed >= boss_time - 5.0 and not boss_warned:
		boss_warned = true
		_banner(boss_name() + tr("이 와요!"), Color("#ff7aa8"))
		_play("warn", 1.0, 0.0)
	if elapsed >= boss_time and not boss_spawned:
		boss_spawned = true
		var p := player.position + Vector3(0, 0, -8)
		if p.z < -AZ:
			p.z = player.position.z + 8.0
		p.x = clampf(p.x, -AX, AX)
		boss = _make_enemy("boss", p)
		boss["scale"] *= boss_rank()["scale"]
		boss["radius"] *= boss_rank()["scale"]
		shake = 0.5
		_play_bgm("boss")

func _update_enemies(dt: float) -> void:
	var alive: Array = []
	for e in enemies:
		if e["dead"] >= 0.0:
			e["dead"] += dt
			if e["dead"] <= 0.16:
				alive.append(e)
			continue
		alive.append(e)
		if e.has("prop"):
			e["spawn"] = minf(1.0, e["spawn"] + dt * 3.0)
			e["squash"] = move_toward(e["squash"], 0.0, dt * 5.0)
			e["flash"] = maxf(0.0, e["flash"] - dt)
			continue
		e["spawn"] = minf(1.0, e["spawn"] + dt * 3.0)
		var to_p: Vector3 = player.position - e["pos"]
		to_p.y = 0
		var dist := to_p.length()
		var sp: float = e["speed"] * (0.45 if e["slow"] > 0.0 else 1.0)
		e["slow"] -= dt
		if day_mod == "rain" and _in_puddle(e["pos"]):
			sp *= 0.6
		var want := to_p / maxf(dist, 0.01) * sp
		if e["kind"] == "report":
			# 성적표 귀신은 울면서 지그재그로 와요
			var side := Vector3(-to_p.z, 0, to_p.x) / maxf(dist, 0.01)
			want += side * sin(e["phase"] * 0.6) * sp * 1.3
		if flee_t > 0.0 and e["kind"] != "boss":
			want = -to_p / maxf(dist, 0.01) * sp * 1.7
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
		if float(e.get("push", 0.0)) > 0.0:
			e["push"] -= dt
			steer *= 0.12
			if Engine.get_process_frames() % 4 == 0 and parts.size() < part_cap / 2:
				_puff(e["pos"] + Vector3(0, 0.15, 0), 0.3, 0.3, Color(1, 0.95, 0.85, 0.5))
		e["vel"] = (e["vel"] as Vector3).lerp(want, dt * steer)
		e["pos"] += (e["vel"] + (wind * 1.6 if e["kind"] != "boss" else Vector3.ZERO)) * dt
		if stage == "roof" and e["kind"] != "boss" and (absf(e["pos"].x) > AX + 0.7 or absf(e["pos"].z) > AZ + 0.7):
			# 난간 밖으로 떨어졌어요!
			_number(e["pos"] + Vector3(0, 1.2, 0), 0, false, tr("으악!"))
			e["hp"] = 0.0
			_kill_enemy(e)
			continue
		e["pos"].x = clampf(e["pos"].x, -AX - 1, AX + 1)
		e["pos"].z = clampf(e["pos"].z, -AZ - 1, AZ + 1)
		if dist > 0.01:
			e["rot"] = lerp_angle(e["rot"], atan2(to_p.x, to_p.z), dt * 8.0)
		e["phase"] += dt * (10.0 if e["kind"] in ["egg", "dust"] else 7.0)
		e["squash"] = move_toward(e["squash"], 0.0, dt * 5.0)
		e["flash"] = maxf(0.0, e["flash"] - dt)
		if obstacles.size() > 0:
			e["pos"] = _push_out(e["pos"], e["radius"] * 0.8)
		if dist < e["radius"] + 0.3 and hurt_timer <= 0.0 and not game_over and flee_t <= 0.0 and float(e.get("hop", 0.0)) < 0.5:
			# 귀신마다 아픈 정도가 달라요: 보통 1, 주전자 2, 대왕귀신 3, 반짝이(정예)는 +1
			_player_hurt(e["pos"], int(KINDS[e["kind"]].get("dmg", 1)) + (1 if e["elite"] and e["kind"] != "boss" else 0))
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
				if a.has("prop") or b.has("prop"):
					if a.has("prop") and not b.has("prop"):
						b["pos"] -= push * 2.0
					elif b.has("prop") and not a.has("prop"):
						a["pos"] += push * 2.0
				elif a["kind"] == "boss":
					b["pos"] -= push * 2.0
				elif b["kind"] == "boss":
					a["pos"] += push * 2.0
				else:
					a["pos"] += push
					b["pos"] -= push

func _hit_enemy(e: Dictionary, dmg: float, dir: Vector3, knock := 5.0, quiet := false) -> void:
	if e["dead"] >= 0.0:
		return
	dmg *= dmg_mult() * combo_mult()
	var crit := rng.randf() < crit_chance()
	if crit:
		dmg *= 2.0 + 0.3 * lv("magnifier")
	e["hp"] -= dmg
	e["flash"] = 0.08
	e["squash"] = 1.0
	dir.y = 0
	if dir.length() > 0.01:
		var resist := 0.08 if e["kind"] == "boss" else (0.35 if e["elite"] or e["kind"] == "kettle" else 1.0)
		if e.has("prop"):
			resist = 0.0
		e["vel"] = dir.normalized() * knock * resist
		# 센 넉백(고무줄 등)은 잠깐 버티지 못하고 튕겨 나가요
		if knock >= 8.0 and resist > 0.0:
			e["push"] = 0.28 if e["kind"] != "boss" else 0.1
	var pos: Vector3 = e["pos"]
	_number(pos + Vector3(0, 1.3, 0), int(round(dmg)), crit)
	_burst(pos + Vector3(0, 0.55, 0), Color(0.7, 0.9, 1.0, 0.9), 3, 3.0)
	if not quiet:
		_sparkle(pos + Vector3(0, 0.6, 0), Color(1.0, 0.95, 0.7, 0.9), 1, 3.5, 0.12, 0.25)
	if crit:
		_ring(pos, Color(1.0, 0.85, 0.2, 1.0), 0.2, 1.4 + 0.2 * lv("magnifier"), 0.35)
		if lv("magnifier") > 0 and not quiet:
			_sparkle(pos + Vector3(0, 0.8, 0), Color(1.0, 0.8, 0.2, 1.0), 4, 5.0, 0.14, 0.35)
		_burst(pos + Vector3(0, 0.7, 0), Color("#ffdf3d"), 6, 5.0, true)
	if not quiet:
		_play("hit", rng.randf_range(0.9, 1.15) + (0.25 if crit else 0.0), -5.0)
	if crit:
		shake = maxf(shake, 0.12)
	if e["hp"] <= 0.0:
		_kill_enemy(e)

func _kill_enemy(e: Dictionary) -> void:
	if e.has("prop"):
		e["dead"] = 0.0
		var pp: Vector3 = e["pos"]
		_burst(pp + Vector3(0, 0.5, 0), Color(KINDS[e["kind"]]["col"]), 12, 5.0)
		for i in 4:
			_puff(pp + Vector3(0, 0.4, 0), 0.3, 0.5, Color(0.85, 0.8, 0.75, 0.7))
		_ring(pp, Color(1, 0.8, 0.4, 0.9), 0.2, 1.5, 0.4)
		_burst(pp + Vector3(0, 0.5, 0), Color("#fff27a"), 6, 5.0, true)
		_play("pop", 0.7, -3.0)
		var r := rng.randf()
		if r < 0.1:
			_drop("heart", pp)
		elif r < 0.3:
			_drop("magnet", pp)
		elif r < 0.75:
			for i in 4:
				gems.append({"pos": pp + Vector3(0, 0.3, 0), "vel": Vector3(rng.randf_range(-3, 3), rng.randf_range(3, 6), rng.randf_range(-3, 3)), "pull": false, "t": 0.0, "col": Color("#ffc928"), "coin": true})
		else:
			for i in 8:
				gems.append({"pos": pp + Vector3(0, 0.3, 0), "vel": Vector3(rng.randf_range(-3, 3), rng.randf_range(3, 6), rng.randf_range(-3, 3)), "pull": false, "t": 0.0,
					"col": [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#9b8cff")][rng.randi() % 4]})
		return
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
	var confetti := [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#58c6f2"), Color("#c9a8f0")]
	for i in (22 if big else 6):
		var cv := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.6), rng.randf_range(-1, 1)).normalized() * rng.randf_range(3.0, 6.5)
		_part("star", pos + Vector3(0, 0.6, 0), cv, confetti[rng.randi() % confetti.size()], 1.0, 1.0, rng.randf_range(-14, 14), 14.0)
	for i in (6 if big else 2):
		_puff(pos + Vector3(rng.randf_range(-0.3, 0.3), 0.5, rng.randf_range(-0.3, 0.3)), 0.28 * (1.8 if big else 1.0), 0.45)
	_ring(pos, Color(col.r, col.g, col.b, 0.9), 0.2, 1.6 if not big else 4.0, 0.4 if not big else 0.7)
	_glow(pos + Vector3(0, 0.8, 0), Vector3(rng.randf_range(-0.4, 0.4), 2.4, 0), Color(0.9, 0.95, 1.0, 0.8), 0.22, 0.9, -1.0)
	_glow(pos + Vector3(0, 0.6, 0), Vector3.ZERO, Color(1, 1, 0.85, 1.0), 0.9 if big else 0.55, 0.14)
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
		# 첫 반짝이는 상자를 꼭 주고, 그다음부터는 반반 (상자가 너무 자주 나와서)
		elite_drops += 1
		if elite_drops == 1 or rng.randf() < 0.5:
			_drop("chest", pos + Vector3(0.5, 0, 0))
			if rng.randf() < 0.35:
				_drop("heart", pos + Vector3(-0.5, 0, 0))
		else:
			_drop("heart", pos + Vector3(-0.5, 0, 0))
			for i in 6:
				gems.append({"pos": pos + Vector3(0, 0.3, 0), "vel": Vector3(rng.randf_range(-3, 3), rng.randf_range(3, 6), rng.randf_range(-3, 3)) * 1.4,
					"pull": false, "t": 0.0, "col": Color("#ffc928"), "coin": true})
	elif e["kind"] != "boss":
		var r := rng.randf()
		if r < 0.004:
			_drop("heart", pos)
		elif r < 0.011:
			_drop("magnet", pos)
	if e["kind"] == "boss":
		hitstop(0.25)
		shake = 0.8
		get_tree().create_timer(1.2).timeout.connect(func(): _end_game(true))
	_play("pop", 1.0 + minf(combo, 12) * 0.04, -3.0)
	if e["elite"]:
		_vib(40)
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
				# 등급 보스는 자기만의 새 공격을 섞어 써요
				var ri := BOSS_RANKS.find(boss_rank())
				if ri >= 1:
					pats += ["spiral", "spiral"]
				if ri >= 2:
					pats += ["cross", "cross"]
				if ri >= 3:
					pats += ["jump", "jump"]
				if ri >= 4:
					pats += ["goldrain", "goldrain"]
				if ri >= 5:
					pats += ["nova", "nova", "nova"]
				e["pat"] = pats[rng.randi() % pats.size()]
				if ri >= 1 and e.get("last_pat", "") == e["pat"]:
					e["pat"] = pats[rng.randi() % pats.size()]
				e["last_pat"] = e["pat"]
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
				var n := 12 + mini(dg, 16) + (4 if angry else 0)
				var off := rng.randf() * TAU
				for i in n:
					var a := off + TAU * i / n
					var dv := Vector3(cos(a), 0, sin(a))
					eshots.append({"pos": e["pos"] + dv * 1.2 + Vector3(0, 0.6, 0), "vel": dv * (4.2 + 0.2 * mini(dg, 15)), "life": 5.0, "rot": a})
				_play("blast", 0.7, -4.0)
				shake = maxf(shake, 0.25)
				e["stage"] += 1
				e["pat_t"] = 0.45
				if e["stage"] >= (3 if angry else 2):
					_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"charge":
			# 돌진: 경고는 짧게, 준비하는 동안 철수 쪽으로 계속 고쳐 겨누다가(마지막 0.15초는 고정) 빠르고 길게 달려요
			var wind := 0.45 if angry else 0.55
			if e["stage"] == 0:
				e["charge_dir"] = to_p / maxf(dist, 0.01)
				e["stage"] = 1
				e["pat_t"] = wind
				if not e.has("charges") or int(e["charges"]) <= 0:
					e["charges"] = 2 if angry else 1
				e["cwarn"] = _warn_line(e["pos"], e["charge_dir"], wind, 16.0)
			if e["stage"] == 1:
				e["squash"] = 0.3 + 0.15 * sin(elapsed * 60.0)
				if e["pat_t"] > 0.15:
					var aim := to_p / maxf(dist, 0.01)
					e["charge_dir"] = (e["charge_dir"] as Vector3).slerp(aim, minf(1.0, dt * 6.0)).normalized()
					var wl: MeshInstance3D = e.get("cwarn")
					if is_instance_valid(wl):
						wl.position = e["pos"] + e["charge_dir"] * 8.0 + Vector3(0, 0.04, 0)
						wl.rotation.y = atan2(e["charge_dir"].x, e["charge_dir"].z)
				if e["pat_t"] <= 0.0:
					e["stage"] = 2
					e["pat_t"] = 0.62
					_play("rubber", 0.6, -2.0)
					shake = maxf(shake, 0.15)
				return [Vector3.ZERO, 8.0]
			if e["pat_t"] <= 0.0:
				e["charges"] = int(e["charges"]) - 1
				if int(e["charges"]) > 0:
					# 화나면 한 번 더! 잠깐 멈췄다 다시 겨눠요
					e["stage"] = 0
					e["vel"] = Vector3.ZERO
					return [Vector3.ZERO, 20.0]
				_boss_rest(e, angry)
			if rng.randf() < 0.8:
				_part("drop", e["pos"] + Vector3(0, 0.4, 0), Vector3(rng.randf_range(-1, 1), 2, rng.randf_range(-1, 1)), Color(1, 1, 1, 0.8), 0.14, 0.5)
			return [e["charge_dir"] * (17.0 + 0.5 * mini(dg, 10)), 45.0]   # 1단계 17.5 → 10단계 22
		"rain":
			# 우산 비: 철수 발밑에 빨간 동그라미, 잠시 뒤 쾅!
			if e["stage"] == 0:
				var n := 3 + (2 if angry else 0)
				for i in n:
					var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
					var wp := player.position + move_dir * move_speed() * 0.6 + off
					_warn_circle(wp, 1.5, 1.1 + i * 0.12, "shoe")
				e["stage"] = 1
				e["pat_t"] = 1.6
			if e["pat_t"] <= 0.0:
				_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"summon":
			if e["pat_t"] <= 0.0:
				for j in 6 + mini(dg, 10):
					var a := TAU * j / (6 + mini(dg, 10))
					_make_enemy("dust", e["pos"] + Vector3(cos(a), 0, sin(a)) * 2.2)
				_play("warn", 1.6, -8.0)
				_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"spiral":
			# 화난 보스: 실내화를 회오리처럼 빙글빙글 뿜어요
			if e["stage"] == 0 and e["pat_t"] <= 0.0:
				e["stage"] = 1
				e["pat_t"] = 2.4
				e["spin"] = rng.randf() * TAU
				e["emit"] = 0.0
			if e["stage"] == 1:
				e["emit"] -= dt
				e["spin"] += dt * (2.4 if angry else 1.9)
				if e["emit"] <= 0.0:
					e["emit"] = 0.07
					for k in 2:
						var a: float = e["spin"] + PI * k
						var dv := Vector3(cos(a), 0, sin(a))
						eshots.append({"pos": e["pos"] + dv * 1.2 + Vector3(0, 0.6, 0), "vel": dv * 5.0, "life": 4.0, "rot": a})
					if Engine.get_process_frames() % 6 == 0:
						_play("shoot", 0.6, -14.0)
				if e["pat_t"] <= 0.0:
					_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"cross":
			# 얼음 보스: 십자 모양 경고선 뒤에 실내화 줄기가 쏟아져요
			if e["stage"] == 0:
				e["spin"] = rng.randf() * TAU
				for k in 4:
					var a: float = e["spin"] + PI * 0.5 * k
					_warn_line(e["pos"], Vector3(cos(a), 0, sin(a)), 1.0)
				e["stage"] = 1
				e["pat_t"] = 1.0
			if e["stage"] == 1 and e["pat_t"] <= 0.0:
				e["stage"] = 2
				e["pat_t"] = 1.6
				e["emit"] = 0.0
				_play("zap", 0.8, -4.0)
				shake = maxf(shake, 0.2)
			if e["stage"] == 2:
				e["emit"] -= dt
				e["spin"] += dt * 0.35
				if e["emit"] <= 0.0:
					e["emit"] = 0.06
					for k in 4:
						var a: float = e["spin"] + PI * 0.5 * k
						var dv := Vector3(cos(a), 0, sin(a))
						eshots.append({"pos": e["pos"] + dv * 1.2 + Vector3(0, 0.6, 0), "vel": dv * 9.0, "life": 2.5, "rot": a})
					_glow(e["pos"] + Vector3(0, 1.0, 0), Vector3.ZERO, Color(0.4, 0.8, 1.0, 0.8), 0.9, 0.2)
				if e["pat_t"] <= 0.0:
					_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"jump":
			# 그림자 보스: 사라졌다가 철수 쪽에 쾅 하고 떨어져요
			if e["stage"] == 0:
				var tp := player.position + move_dir * move_speed() * 0.5
				tp.x = clampf(tp.x, -AX + 1.5, AX - 1.5)
				tp.z = clampf(tp.z, -AZ + 1.5, AZ - 1.5)
				e["jump_to"] = tp
				e["jump_from"] = e["pos"]
				_warn_circle(tp, 2.2, 1.0)
				e["stage"] = 1
				e["pat_t"] = 1.0
				_puff(e["pos"], 1.6, 0.5, Color(0.3, 0.2, 0.45, 0.8))
				_play("magnet", 0.7, -6.0)
			if e["stage"] == 1:
				e["vel"] = Vector3.ZERO
				var k := clampf(1.0 - e["pat_t"], 0.0, 1.0)
				var jf: Vector3 = e["jump_from"]
				var jt: Vector3 = e["jump_to"]
				e["pos"] = jf.lerp(jt, k)
				e["hop"] = sin(k * PI) * 5.0
				if e["pat_t"] <= 0.0:
					e["hop"] = 0.0
					e["stage"] = 2
					e["pat_t"] = 0.6
					_ring(e["pos"], Color(0.6, 0.4, 1.0, 1.0), 0.5, 4.0, 0.5)
					_puff(e["pos"], 2.2, 0.6, Color(0.4, 0.3, 0.55, 0.8))
					_play("kick", 0.7, 0.0)
					shake = maxf(shake, 0.45)
					var n := 10
					for i in n:
						var a := TAU * i / n
						var dv := Vector3(cos(a), 0, sin(a))
						eshots.append({"pos": e["pos"] + dv * 1.4 + Vector3(0, 0.6, 0), "vel": dv * 6.0, "life": 3.0, "rot": a})
			if e["stage"] == 2 and e["pat_t"] <= 0.0:
				e["stage"] = 0 if (angry and not e.get("jumped2", false)) else 3
				e["jumped2"] = e["stage"] == 0
				if e["stage"] == 3:
					e["jumped2"] = false
					_boss_rest(e, angry)
			return [Vector3.ZERO, 0.0]
		"goldrain":
			# 황금 보스: 동전 비! 바닥 동그라미가 줄줄이 생겨요
			if e["stage"] == 0:
				var n := 8 + (4 if angry else 0)
				for i in n:
					var a := TAU * i / n + rng.randf() * 0.4
					var r := 1.5 + (i % 3) * 1.6
					var wp := player.position + Vector3(cos(a), 0, sin(a)) * r
					if i == 0:
						wp = player.position + move_dir * move_speed() * 0.8
					_warn_circle(wp, 1.3, 0.9 + (i % 4) * 0.25, "coin")
				for i in 10:
					_glow(e["pos"] + Vector3(0, 2.0, 0), Vector3(rng.randf_range(-3, 3), 6.0, rng.randf_range(-3, 3)), Color(1.0, 0.85, 0.3, 0.9), 0.3, 0.6, 9.0)
				_play("coin", 0.7, -3.0)
				e["stage"] = 1
				e["pat_t"] = 2.2
			if e["pat_t"] <= 0.0:
				_boss_rest(e, angry)
			return [Vector3.ZERO, 6.0]
		"nova":
			# 전설의 보스: 엇갈린 실내화 고리가 여러 번 퍼져요
			e["squash"] = 0.4 + 0.2 * sin(elapsed * 50.0)
			if e["pat_t"] <= 0.0:
				var n := 18
				var off: float = (PI / n) * float(int(e["stage"]) % 2)
				for i in n:
					var a: float = off + TAU * i / n
					var dv := Vector3(cos(a), 0, sin(a))
					eshots.append({"pos": e["pos"] + dv * 1.3 + Vector3(0, 0.6, 0), "vel": dv * (4.0 + e["stage"] * 0.6), "life": 5.0, "rot": a})
				_ring(e["pos"], Color(1.0, 0.5, 1.0, 1.0), 0.5, 3.0, 0.4)
				_play("blast", 0.6, -3.0)
				shake = maxf(shake, 0.2)
				e["stage"] += 1
				e["pat_t"] = 0.38
				if e["stage"] >= (5 if angry else 4):
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
	m.albedo_color = Color(1, 0.12, 0.18, a)
	m.emission_enabled = true
	m.emission = Color(1, 0.1, 0.15)
	m.emission_energy_multiplier = 0.6
	m.render_priority = 2
	m.no_depth_test = true
	return m

# 떨어지는 실내화/동전 재질은 한 번만 만들어 같이 써요 (처음 나올 때 멈칫하지 않게 _prewarm에서 미리 그려 둬요)
func _fall_mat(coin: bool) -> StandardMaterial3D:
	if not fall_mats.has(coin):
		var fm := StandardMaterial3D.new()
		fm.vertex_color_use_as_albedo = true
		fm.emission_enabled = true
		if coin:
			fm.emission = Color(1.0, 0.7, 0.15)
			fm.emission_energy_multiplier = 0.3
			fm.metallic = 0.45
			fm.roughness = 0.35
		else:
			fm.emission = Color(1.0, 0.25, 0.3)
			fm.emission_energy_multiplier = 0.3
		fall_mats[coin] = fm
	return fall_mats[coin]

func _warn_circle(pos: Vector3, r: float, delay: float, drop := "") -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(1.0, 0.02, -1, 32)
	mi.material_override = _warn_mat(0.5)
	mi.position = Vector3(pos.x, 0.04, pos.z)
	mi.scale = Vector3(r, 1, r)
	add_child(mi)
	var inner := MeshInstance3D.new()
	inner.mesh = _cyl(1.0, 0.03, -1, 32)
	inner.material_override = _warn_mat(0.7)
	inner.scale = Vector3(0.01, 1, 0.01)
	mi.add_child(inner)
	var w := {"node": mi, "inner": inner, "t": 0.0, "life": delay, "pos": pos, "r": r, "kind": "circle"}
	if drop != "":
		# 하늘에서 떨어지는 물건: 동그라미 가운데로 점점 빨라지며 떨어지고, 그림자가 커져요
		var f := MeshInstance3D.new()
		f.mesh = coin_fall_mesh if drop == "coin" else mm["eshot"].multimesh.mesh
		f.material_override = _fall_mat(drop == "coin")
		f.position = Vector3(pos.x, 10.0, pos.z)
		f.scale = Vector3.ONE * (1.0 if drop == "coin" else 4.2)
		add_child(f)
		var sh := MeshInstance3D.new()
		sh.mesh = _cyl(1.0, 0.01, -1, 24)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0.1, 0.0, 0.1, 0.0)
		sm.no_depth_test = true
		sm.render_priority = 3
		sh.material_override = sm
		sh.position = Vector3(pos.x, 0.06, pos.z)
		sh.scale = Vector3(0.1, 1, 0.1)
		add_child(sh)
		w["fall"] = f
		w["shadow"] = sh
		w["spin"] = rng.randf_range(-6.0, 6.0)
	warns.append(w)

func _warn_line(pos: Vector3, dir: Vector3, life: float, len := 12.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(Vector3(2.2, 0.02, 1.0))
	mi.material_override = _warn_mat(0.5)
	add_child(mi)
	mi.position = pos + dir * len / 2.0 + Vector3(0, 0.04, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.scale = Vector3(1, 1, len)
	warns.append({"node": mi, "t": 0.0, "life": life, "kind": "line"})
	return mi

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
			if w.has("fall"):
				var kk := clampf(k, 0.0, 1.0)
				var f: MeshInstance3D = w["fall"]
				f.position.y = 0.3 + 9.7 * (1.0 - kk * kk)
				f.rotation = Vector3(w["t"] * 3.0, w["t"] * float(w["spin"]), 0.0)
				var sh: MeshInstance3D = w["shadow"]
				sh.scale = Vector3.ONE * (0.25 + 0.75 * kk) * float(w["r"]) * 0.6
				sh.scale.y = 1.0
				(sh.material_override as StandardMaterial3D).albedo_color.a = 0.15 + 0.4 * kk
				if k >= 1.0:
					f.queue_free()
					sh.queue_free()
			if k >= 1.0:
				var d: Vector3 = player.position - w["pos"]
				d.y = 0
				_burst(w["pos"] + Vector3(0, 0.3, 0), Color("#ff7aa8"), 12, 5.0, true)
				_burst(w["pos"] + Vector3(0, 0.3, 0), Color(0.8, 0.9, 1.0, 0.9), 10, 4.0)
				_play("splash", 0.7, -5.0)
				shake = maxf(shake, 0.2)
				if d.length() < w["r"] and hurt_timer <= 0.0 and not game_over:
					_player_hurt(w["pos"], 2)
		else:
			(mi.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.25 * sin(w["t"] * 30.0)
		if k >= 1.0:
			mi.queue_free()
			warns.erase(w)
	var m: MultiMesh = mm["eshot"].multimesh
	var n := mini(eshots.size(), 120)
	for i in n:
		var b: Dictionary = eshots[i]
		m.set_instance_transform(i, Transform3D(Basis(Vector3.UP, b["rot"]).scaled(Vector3.ONE * 2.6), b["pos"]))
		var bg2: MultiMesh = mm["eglow"].multimesh
		bg2.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.55), b["pos"] + Vector3(0, 0.1, 0)))
		bg2.set_instance_custom_data(i, Color(1.0, 0.25, 0.3, 0.75 + 0.25 * sin(elapsed * 20.0 + i)))
		m.set_instance_color(i, Color.WHITE)
		m.set_instance_custom_data(i, Color(1, 1, 1, 0))
	m.visible_instance_count = n
	mm["eglow"].multimesh.visible_instance_count = n

# ---------- 떨어지는 아이템 ----------
var drops: Array = []
var heart_mesh: ArrayMesh
var magnet_mesh: ArrayMesh
var chest_mesh: ArrayMesh
var gacha_mesh: ArrayMesh
func _use_gacha(d: Dictionary) -> void:
	var cost: int = d["cost"]
	if run_coins < cost:
		_banner(tr("동전이 모자라요 (%d개 필요)") % cost, Color("#ff9a2f"))
		_play("ui_error", 1.0, -4.0)
		return
	run_coins -= cost
	gacha_used += 1
	d["cost"] = int(round(cost * 1.5))
	(d["label"] as Label3D).text = tr("뽑기 동전 %d") % d["cost"]
	var r := rng.randf()
	var got: Array = []
	var extra: Array = []
	var coins := 0
	if r < 0.55:
		var pool := _owned_pool()
		var c: Dictionary = pool[0]
		got.append(c)
		_apply_card(c, true)
		if rng.randf() < 0.25:
			var pool2 := _owned_pool()
			var c2: Dictionary = pool2[0]
			got.append(c2)
			_apply_card(c2, true)
			extra.append(tr("한 개 더 나왔다!"))
	elif r < 0.75:
		hp = max_hp()
		extra.append(tr("하트 가득 회복!"))
		_refresh_ui()
	elif r < 0.88:
		for g in gems:
			g["pull"] = true
		extra.append(tr("왕자석! 딱지가 다 모여요"))
	else:
		coins = cost * 3
		run_coins += coins
		extra.append(tr("동전 대박!"))
	_reward_panel(tr("뽑기 결과!"), got, coins, extra)

func _drop(kind: String, pos: Vector3) -> void:
	pos.x = clampf(pos.x, -AX + 0.4, AX - 0.4)
	pos.z = clampf(pos.z, -AZ + 0.4, AZ - 0.4)
	if obstacles.size() > 0:
		pos = _push_out(pos, 0.6)
	var mi: Node3D
	var glb := "res://models/prop_%s.glb" % kind
	if (kind == "gacha" or kind == "chest") and ResourceLoader.exists(glb):
		mi = (load(glb) as PackedScene).instantiate()
	else:
		var m3 := MeshInstance3D.new()
		m3.mesh = {"heart": heart_mesh, "magnet": magnet_mesh, "chest": chest_mesh, "gacha": gacha_mesh}[kind]
		m3.material_override = mat_vc
		mi = m3
	add_child(mi)
	var d := {"node": mi, "kind": kind, "pos": pos + Vector3(0, 0.5, 0), "t": 0.0}
	if kind == "gacha":
		d["pos"] = pos
		d["cost"] = int(round(10 * (1.0 + 0.35 * (dg - 1))))
		d["inside"] = false
		var lb := Label3D.new()
		lb.font = font
		lb.font_size = 48
		lb.outline_size = 12
		lb.outline_modulate = Color("#3a2148")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.01
		lb.position = Vector3(0, 2.0, 0)
		lb.text = tr("뽑기 동전 %d") % d["cost"]
		mi.add_child(lb)
		d["label"] = lb
	drops.append(d)

func _update_drops(dt: float) -> void:
	for d in drops.duplicate():
		d["t"] += dt
		var mi: Node3D = d["node"]
		if d["kind"] == "gacha":
			mi.position = d["pos"]
			mi.scale = Vector3.ONE * minf(1.0, d["t"] * 3.0) * (1.0 + 0.04 * sin(d["t"] * 6.0))
			var gd := Vector2(player.position.x - d["pos"].x, player.position.z - d["pos"].z).length()
			if gd < 1.2 and not d["inside"]:
				d["inside"] = true
				_use_gacha(d)
				return
			elif gd > 1.8:
				d["inside"] = false
			continue
		mi.position = d["pos"] + Vector3(0, 0.15 * sin(d["t"] * 4.0) + 0.2, 0)
		mi.rotation.y = d["t"] * 2.5
		mi.scale = Vector3.ONE * (1.0 + 0.08 * sin(d["t"] * 8.0)) * minf(1.0, d["t"] * 4.0)
		var dist := Vector2(player.position.x - d["pos"].x, player.position.z - d["pos"].z).length()
		if dist < 1.2:
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
				_banner(tr("자석! 딱지가 다 모여요"), Color("#ff7a7a"))
			mi.queue_free()
			drops.erase(d)
		elif d["t"] > 25.0 and d["kind"] != "chest":
			mi.queue_free()
			drops.erase(d)

# 팽이: 던지면 바닥에 떨어져 빙글빙글 돌며 귀신 쪽으로 미끄러지고, 부딪힌 귀신을 튕겨내요
func _weapon_top(dt: float) -> void:
	if mains.has("top"):
		var ts := top_stats()
		cd["top"] -= dt
		if cd["top"] <= 0.0:
			cd["top"] = ts["cool"] * cd_mult()
			var base_dir := face_dir
			var tg := _nearest_enemy(8.0)
			if not tg.is_empty():
				base_dir = ((tg["pos"] as Vector3) - player.position).normalized()
			base_dir.y = 0.0
			if base_dir.length() < 0.1:
				base_dir = Vector3(0, 0, 1)
			for i in int(ts["count"]):
				var dir := base_dir.normalized().rotated(Vector3.UP, (i - (ts["count"] - 1) / 2.0) * 0.9 + rng.randf_range(-0.2, 0.2))
				var mi := MeshInstance3D.new()
				mi.mesh = top_evo_mesh if evolved.has("top") else top_mesh
				mi.material_override = mat_vc
				add_child(mi)
				var land := player.position + dir * rng.randf_range(1.8, 2.6)
				tops.append({"node": mi, "from": player.position, "pos": land, "dir": dir, "t": 0.0, "fly": 0.3, "life": ts["life"],
					"dmg": ts["dmg"], "knock": ts["knock"], "size": ts["size"] * area_mult(), "speed": ts["speed"], "pull": ts["pull"], "hit": {}, "spin": 0.0})
			_play("yoyo", 0.75, -9.0)
	var evo := evolved.has("top")
	for t in tops.duplicate():
		t["t"] += dt
		var mi: MeshInstance3D = t["node"]
		var sz: float = t["size"]
		t["spin"] += dt * 28.0
		if t["t"] < t["fly"]:
			# 포물선을 그리며 날아가요
			var k: float = t["t"] / t["fly"]
			var p: Vector3 = (t["from"] as Vector3).lerp(t["pos"], k)
			mi.position = p + Vector3(0, 0.35 + sin(k * PI) * 1.1, 0)
			mi.rotation = Vector3(0.6, t["spin"], 0.0)
			mi.scale = Vector3.ONE * 1.3 * sz
			continue
		if not t.has("landed"):
			t["landed"] = true
			_ring(t["pos"], Color(1.0, 0.9, 0.6, 0.8), 0.15, 0.9 * sz, 0.3)
			_puff(t["pos"] + Vector3(0, 0.15, 0), 0.25, 0.35, Color(0.9, 0.85, 0.75, 0.6))
		var left: float = t["life"] - (t["t"] - t["fly"])
		# 가까운 귀신 쪽으로 천천히 미끄러져요 (부딪히면 방향이 튕겨요)
		var near := {}
		var nd := 4.5
		for e in enemies:
			if e["dead"] >= 0.0 or e.has("prop"):
				continue
			var dd: float = Vector2(e["pos"].x - t["pos"].x, e["pos"].z - t["pos"].z).length()
			if dd < nd:
				nd = dd
				near = e
		if not near.is_empty():
			var want: Vector3 = (near["pos"] as Vector3) - (t["pos"] as Vector3)
			want.y = 0.0
			if want.length() > 0.01:
				t["dir"] = (t["dir"] as Vector3).lerp(want.normalized(), minf(1.0, dt * 2.5)).normalized()
		var tp: Vector3 = t["pos"] + t["dir"] * t["speed"] * dt
		# 철수한테서 너무 멀어지지 않게
		var fromp := tp - player.position
		fromp.y = 0.0
		if fromp.length() > 6.5:
			t["dir"] = (-fromp).normalized()
		t["pos"] = tp
		var wob := 0.12 * (1.0 - clampf(left / 1.0, 0.0, 1.0))   # 멈출 때쯤 비틀비틀
		mi.position = tp + Vector3(0, 0.2 * sz, 0)
		mi.rotation = Vector3(0.35 + sin(t["spin"] * 0.3) * wob * 3.0, t["spin"], cos(t["spin"] * 0.3) * wob * 3.0)
		mi.scale = Vector3.ONE * 1.3 * sz
		if Engine.get_process_frames() % 3 == 0:
			var gc := Color.from_hsv(fmod(elapsed * 1.2, 1.0), 0.55, 1.0, 0.6) if evo else Color(1.0, 0.55, 0.4, 0.5)
			_glow(tp + Vector3(0, 0.08, 0), Vector3.ZERO, gc, 0.28 * sz, 0.3)
		if evo and Engine.get_process_frames() % 10 == 0:
			_ring(tp, Color(0.6, 0.85, 1.0, 0.5), t["pull"] * 0.9, 0.3, 0.35)
		for e in enemies:
			if e["dead"] >= 0.0:
				continue
			var d3: Vector3 = (e["pos"] as Vector3) - tp
			d3.y = 0.0
			var dl := d3.length()
			# 회오리: 주변 귀신을 살살 끌어당겨요 (보스는 못 끌어요)
			if t["pull"] > 0.0 and dl < t["pull"] and dl > 0.3 and e["kind"] != "boss" and not e.has("prop"):
				e["pos"] -= d3.normalized() * minf(dl - 0.3, 2.2 * dt)
			if dl < e["radius"] + 0.28 * sz:
				var last: float = t["hit"].get(e, -9.0)
				if t["t"] - last > 0.35:
					t["hit"][e] = t["t"]
					_hit_enemy(e, t["dmg"], d3, t["knock"])
					# 팽이도 반대쪽으로 튕겨 나가요
					if dl > 0.01:
						t["dir"] = (-d3.normalized()).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
					_sparkle(tp + Vector3(0, 0.3, 0), Color(1.0, 0.95, 0.6, 0.9), 2, 4.0, 0.1, 0.25)
		if left <= 0.0:
			_puff(tp + Vector3(0, 0.2, 0), 0.25, 0.3, Color(1, 1, 1, 0.6))
			mi.queue_free()
			tops.erase(t)

func _nearest_enemy(range_v: float) -> Dictionary:
	var best := {}
	var bd := range_v
	for e in enemies:
		if e["dead"] >= 0.0 or e.has("prop"):
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
			var mz := gun.global_position + face_dir * 0.4
			_glow(mz, face_dir * 2.0, Color(0.6, 0.9, 1.0, 0.9), 0.28 * gs["size"], 0.12)
			_play("shoot" if not evolved.has("gun") else "blast", rng.randf_range(0.95, 1.1), -9.0)
	_update_bullets(dt)
	_weapon_colorpaper(dt)
	_support_fx(dt)
	_weapon_plane(dt)
	_weapon_pop(dt)
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
			if Engine.get_process_frames() % 4 == i % 4:
				var tc := Color(0.9, 0.6, 0.1, 0.45) if evolved.has("ddakji") else Color(1.0, 0.4, 0.65, 0.5)
				_glow(p, Vector3.ZERO, tc, 0.2 * area_mult(), 0.25)
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
				var line := MeshInstance3D.new()
				line.mesh = _box(Vector3(0.035, 0.035, 1.0))
				var lm := StandardMaterial3D.new()
				lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lm.albedo_color = Color(1.0, 0.95, 0.6) if evolved.has("yoyo") else Color(0.85, 1.0, 0.9)
				line.material_override = lm
				line.visible = false
				add_child(line)
				yoyos.append({"line": line, "node": mi, "dir": dir, "t": 0.0, "dist": ys["dist"] * area_mult(), "dmg": ys["dmg"], "chain": ys["chain"], "hit": {}})
			_play("yoyo", 1.0, -8.0)
		for y in yoyos.duplicate():
			y["t"] += dt / 0.9
			var k: float = sin(minf(y["t"], 1.0) * PI)
			var p: Vector3 = player.position + y["dir"] * y["dist"] * k + Vector3(0, 0.6, 0)
			var mi: MeshInstance3D = y["node"]
			mi.position = p
			# 위에서 내려다보는 카메라에 동그란 면이 보이게 눕혀서 팽이처럼 돌려요
			mi.rotation = Vector3(0.35, y["t"] * 30.0, 0.0)
			mi.scale = Vector3.ONE * 1.9 * area_mult()
			var ln: MeshInstance3D = y["line"]
			var hand := player.position + Vector3(0, 0.7, 0)
			var dl := p - hand
			if dl.length() > 0.05:
				ln.visible = true
				ln.look_at_from_position((p + hand) / 2.0, p, Vector3.UP if absf(dl.normalized().y) < 0.99 else Vector3.RIGHT)
				ln.scale = Vector3(1, 1, dl.length())
			var yc := Color(1.0, 0.85, 0.2, 0.8) if evolved.has("yoyo") else Color(0.3, 1.0, 0.75, 0.7)
			_glow(p, Vector3.ZERO, yc, 0.3 * area_mult(), 0.22)
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
				(y["line"] as Node).queue_free()
				yoyos.erase(y)
	_weapon_top(dt)
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
		if not r["done"] and r["dmg"] > 0.0:
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

var cpapers: Array = []
# 보조 아이템도 눈에 보이게: 각자 작은 효과를 내요
var sup_t := {"bottle": 2.0, "watch": 6.0, "magnifier": 2.5, "sneakers": 0.0}
var pages: Array = []
var page_hit := {}
var pickup_ring: MeshInstance3D
var shield_t := 0.0
var shield_on := false
var shield_node: MeshInstance3D
func _sup_mat(c: Color, a := 1.0, glow := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c * glow
	return m

func _support_fx(dt: float) -> void:
	var pp := player.position
	# 생수병: 주기적으로 물을 촤악 뿌려서 주변 귀신을 밀어내요
	var lb := lv("bottle")
	if lb > 0:
		sup_t["bottle"] -= dt
		if sup_t["bottle"] <= 0.0:
			sup_t["bottle"] = maxf(2.5, 5.0 - 0.5 * lb) * cd_mult()
			var r := (2.4 + 0.3 * lb) * area_mult()
			_ring(pp, Color(0.4, 0.8, 1.0, 0.9), 0.3, r, 0.4)
			for i in 14:
				var a := TAU * i / 14.0
				_glow(pp + Vector3(0, 0.5, 0), Vector3(cos(a) * 7.0, 2.5, sin(a) * 7.0), Color(0.45, 0.8, 1.0, 0.85), 0.22, 0.45, 12.0)
			_play("splash", 1.3, -10.0)
			for e in enemies:
				var d: Vector3 = e["pos"] - pp
				d.y = 0
				if e["dead"] < 0.0 and d.length() < r + e["radius"]:
					_hit_enemy(e, 5.0 + 3.0 * lb, d, 7.0, true)
	# 공책: 공책 종이가 철수 주위를 빙글빙글 돌며 귀신을 때려요
	var ln := lv("notebook")
	while pages.size() < ln:
		var mi := MeshInstance3D.new()
		mi.mesh = _box(Vector3(0.5, 0.03, 0.62))
		mi.material_override = _sup_mat(Color("#fff6dc"), 1.0, 0.35)
		var line := MeshInstance3D.new()
		line.mesh = _box(Vector3(0.06, 0.035, 0.62))
		line.material_override = _sup_mat(Color("#b48ef0"), 1.0, 0.6)
		line.position = Vector3(-0.2, 0.005, 0)
		mi.add_child(line)
		add_child(mi)
		pages.append(mi)
	if ln > 0:
		var pr := 1.9 * area_mult()
		for i in pages.size():
			var a := elapsed * 2.6 + TAU * i / pages.size()
			var mi: MeshInstance3D = pages[i]
			var ppos := pp + Vector3(cos(a) * pr, 0.75 + 0.12 * sin(elapsed * 6.0 + i), sin(a) * pr)
			mi.position = ppos
			mi.rotation = Vector3(0.5 * sin(elapsed * 5.0 + i), -a, 0.35)
			if Engine.get_process_frames() % 4 == i % 4:
				_glow(ppos, Vector3.ZERO, Color(0.75, 0.6, 1.0, 0.5), 0.25, 0.25)
			for e in enemies:
				if e["dead"] >= 0.0:
					continue
				var d: Vector3 = e["pos"] - ppos
				d.y = 0
				if d.length() < e["radius"] + 0.35 and elapsed - float(page_hit.get(e, -9.0)) > 0.5:
					page_hit[e] = elapsed
					_hit_enemy(e, 4.0 + 2.0 * ln, d, 3.0, true)
		if Engine.get_process_frames() % 120 == 0:
			page_hit.clear()
	# 계산기 시계: 띠띠! 시간을 멈추듯 주변 귀신을 느리게 해요
	var lw := lv("watch")
	if lw > 0:
		sup_t["watch"] -= dt
		if sup_t["watch"] <= 0.0:
			sup_t["watch"] = maxf(5.0, 10.0 - lw)
			var r := 5.0 * area_mult()
			_ring(pp, Color(0.5, 1.0, 0.45, 0.9), 0.3, r, 0.6)
			_ring(pp, Color(0.8, 1.0, 0.6, 0.7), 0.3, r * 0.6, 0.45)
			for i in 12:
				var a := TAU * i / 12.0
				_glow(pp + Vector3(cos(a) * 1.2, 1.0, sin(a) * 1.2), Vector3(cos(a), 0, sin(a)) * 3.0, Color(0.55, 1.0, 0.5, 0.9), 0.18, 0.5)
			_play("heal", 2.2, -10.0)
			for e in enemies:
				if e["dead"] < 0.0 and (e["pos"] - pp).length() < r:
					e["slow"] = 1.2 + 0.3 * lw
					_glow(e["pos"] + Vector3(0, 1.0, 0), Vector3(0, 1.0, 0), Color(0.55, 1.0, 0.5, 0.8), 0.25, 0.6)
	# 운동화: 달리면 반짝이는 먼지 발자국이 남아요
	var ls := lv("sneakers")
	if ls > 0 and move_dir.length() > 0.1:
		sup_t["sneakers"] -= dt
		if sup_t["sneakers"] <= 0.0:
			sup_t["sneakers"] = 0.09
			_puff(pp + Vector3(0, 0.1, 0) - move_dir.normalized() * 0.3, 0.35 + 0.05 * ls, 0.4, Color(1.0, 0.92, 0.6, 0.6))
			_glow(pp + Vector3(rng.randf_range(-0.2, 0.2), 0.2, rng.randf_range(-0.2, 0.2)), Vector3(0, 1.2, 0), Color(1.0, 0.8, 0.2, 0.7), 0.16, 0.35)
	# 돋보기: 햇빛을 모아 가장 가까운 귀신을 지져요
	var lm := lv("magnifier")
	if lm > 0:
		sup_t["magnifier"] -= dt
		var tg := _nearest_enemy(7.0)
		if sup_t["magnifier"] <= 0.0 and not tg.is_empty():
			sup_t["magnifier"] = maxf(1.2, 3.0 - 0.3 * lm) * cd_mult()
			var tp: Vector3 = tg["pos"]
			for i in 6:
				_glow(tp + Vector3(0, 0.2 + i * 0.5, 0), Vector3(0, -2.0, 0), Color(1.0, 0.85, 0.3, 0.9), 0.4 - i * 0.04, 0.35)
			_ring(tp, Color(1.0, 0.8, 0.2, 1.0), 0.2, 1.0, 0.3)
			_sparkle(tp + Vector3(0, 0.6, 0), Color(1.0, 0.7, 0.2, 1.0), 6, 4.0, 0.12, 0.4)
			_hit_enemy(tg, 10.0 + 5.0 * lm, Vector3.ZERO, 0.0, true)
	# 필통: 줍는 거리를 바닥에 반짝이는 원으로 보여 줘요
	var lpn := lv("pencil")
	if lpn > 0:
		if pickup_ring == null:
			pickup_ring = MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.96
			tm.outer_radius = 1.0
			tm.rings = 48
			tm.ring_segments = 4
			pickup_ring.mesh = tm
			var m := _sup_mat(Color("#9b8cff"), 0.45, 1.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pickup_ring.material_override = m
			add_child(pickup_ring)
		var mr := magnet()
		pickup_ring.position = pp + Vector3(0, 0.06, 0)
		pickup_ring.scale = Vector3(mr, 1.0, mr) * (1.0 + 0.03 * sin(elapsed * 4.0))
		pickup_ring.rotation.y = elapsed * 0.5
	# 명찰: 하트 방패가 차면 한 번 막아 줘요
	var lt := lv("nametag")
	if lt > 0:
		if not shield_on:
			shield_t += dt
			if shield_t >= maxf(12.0, 30.0 - 4.0 * lt):
				shield_on = true
				shield_t = 0.0
				_ring(pp, Color(1.0, 0.45, 0.6, 1.0), 0.3, 1.6, 0.4)
				_play("heal", 1.6, -8.0)
		if shield_node == null:
			shield_node = MeshInstance3D.new()
			shield_node.mesh = _sph(1.0, -1.0, 20, 10)
			var m := _sup_mat(Color("#ff7aa8"), 0.22, 0.9)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			shield_node.material_override = m
			add_child(shield_node)
		shield_node.visible = shield_on
		shield_node.position = pp + Vector3(0, 0.75, 0)
		shield_node.scale = Vector3.ONE * (1.05 + 0.05 * sin(elapsed * 5.0))

var cp_cd := 1.0
func _weapon_colorpaper(dt: float) -> void:
	# 보조 아이템 색종이: 접은 색종이 별을 귀신에게 던져요
	var l := lv("colorpaper")
	if l > 0:
		cp_cd -= dt
		var tg := _nearest_enemy(9.0)
		if cp_cd <= 0.0 and not tg.is_empty():
			cp_cd = maxf(0.7, 2.2 - 0.3 * l) * cd_mult()
			var cols := [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#58c6f2"), Color("#c9a8f0")]
			for i in mini(1 + l / 2, 3):
				var dir: Vector3 = ((tg["pos"] as Vector3) - player.position)
				dir.y = 0
				dir = dir.normalized().rotated(Vector3.UP, deg_to_rad((i - (mini(1 + l / 2, 3) - 1) / 2.0) * 18.0))
				var mi := MeshInstance3D.new()
				mi.mesh = _star3d()
				var m := StandardMaterial3D.new()
				m.albedo_color = cols[rng.randi() % cols.size()]
				m.emission_enabled = true
				m.emission = m.albedo_color * 0.4
				mi.material_override = m
				mi.scale = Vector3.ONE * 6.0
				add_child(mi)
				cpapers.append({"node": mi, "pos": player.position + Vector3(0, 0.8, 0), "dir": dir, "life": 0.9, "dmg": 8.0 + 3.0 * l, "hit": {}, "col": m.albedo_color})
			_play("yoyo", 2.6, -11.0)
	for c in cpapers.duplicate():
		c["life"] -= dt
		c["pos"] += c["dir"] * 13.0 * proj_speed() * dt
		var mi: MeshInstance3D = c["node"]
		mi.position = c["pos"]
		mi.rotation = Vector3(PI / 2, elapsed * 18.0, 0)
		if Engine.get_process_frames() % 2 == 0:
			var cc: Color = c["col"]
			_glow(c["pos"], Vector3.ZERO, Color(cc.r, cc.g, cc.b, 0.7), 0.3, 0.3)
		for e in enemies:
			if e["dead"] >= 0.0 or c["hit"].has(e):
				continue
			if Vector2(e["pos"].x - c["pos"].x, e["pos"].z - c["pos"].z).length() < e["radius"] + 0.25:
				c["hit"][e] = true
				_hit_enemy(e, c["dmg"], c["dir"], 3.5)
				c["life"] = 0.0
				break
		if c["life"] <= 0.0:
			_part("star", c["pos"], Vector3(0, 3, 0), c["col"], 1.0, 0.6, 10.0, 14.0)
			mi.queue_free()
			cpapers.erase(c)

func _weapon_plane(dt: float) -> void:
	if mains.has("plane"):
		var ps := plane_stats()
		cd["plane"] -= dt
		if cd["plane"] <= 0.0 and not _nearest_enemy(11.0).is_empty():
			cd["plane"] = ps["cool"] * cd_mult()
			for i in int(ps["count"]):
				var a: float = TAU * i / ps["count"] + rng.randf() * 0.5
				var mi := MeshInstance3D.new()
				mi.mesh = crane_mesh if evolved.has("plane") else plane_mesh
				mi.material_override = mat_vc_2s
				add_child(mi)
				planes.append({"node": mi, "pos": player.position + Vector3(0, 1.0, 0), "vel": Vector3(cos(a), 0.4, sin(a)) * ps["speed"] * 0.7,
					"life": ps["life"], "dmg": ps["dmg"], "pierce": ps["pierce"], "speed": ps["speed"], "hit": {}, "trail": 0.0, "evo": evolved.has("plane"), "hue": rng.randf()})
			_play("yoyo", 1.6, -9.0)
	for pl in planes.duplicate():
		pl["life"] -= dt
		var mi: MeshInstance3D = pl["node"]
		var pos: Vector3 = pl["pos"]
		# 가장 가까운(아직 안 맞힌) 귀신 쪽으로 방향을 틀어요
		var best := {}
		var bd := 9.0
		for e in enemies:
			if e["dead"] >= 0.0 or e.has("prop") or pl["hit"].has(e):
				continue
			var dd: float = (e["pos"] as Vector3).distance_to(pos)
			if dd < bd:
				bd = dd
				best = e
		var want: Vector3 = pl["vel"]
		if not best.is_empty():
			want = ((best["pos"] as Vector3) + Vector3(0, 0.6, 0) - pos).normalized() * pl["speed"]
		pl["vel"] = (pl["vel"] as Vector3).lerp(want, minf(1.0, dt * 4.5))
		pos += pl["vel"] * dt
		pos.y = maxf(pos.y, 0.45)
		pl["pos"] = pos
		mi.position = pos
		var v: Vector3 = pl["vel"]
		if v.length() > 0.1:
			mi.look_at(pos + v, Vector3.UP)
			mi.rotate_object_local(Vector3.FORWARD, sin(pl["life"] * 6.0) * 0.4)
		mi.scale = Vector3.ONE * (1.3 if pl["evo"] else 1.0)
		pl["trail"] -= dt
		if pl["trail"] <= 0.0:
			pl["trail"] = 0.03
			var tc := Color.from_hsv(fmod(pl["hue"] + elapsed * 0.8, 1.0), 0.55, 1.0, 0.8) if pl["evo"] else Color(0.7, 0.85, 1.0, 0.6)
			_glow(pos, -v * 0.1, tc, 0.16 if pl["evo"] else 0.11, 0.35)
		for e in enemies:
			if e["dead"] >= 0.0 or pl["hit"].has(e):
				continue
			if Vector2(e["pos"].x - pos.x, e["pos"].z - pos.z).length() < e["radius"] + 0.3:
				pl["hit"][e] = true
				_hit_enemy(e, pl["dmg"], v, 4.0)
				_sparkle(pos, Color(0.8, 0.9, 1.0, 1.0), 4, 4.0, 0.12, 0.3)
				pl["pierce"] -= 1
				if pl["pierce"] < 0:
					pl["life"] = 0.0
				break
		if pl["life"] <= 0.0:
			_puff(pos, 0.25, 0.35)
			_burst(pos, Color(0.95, 0.95, 1.0, 0.9), 5, 3.0, true)
			mi.queue_free()
			planes.erase(pl)

func _weapon_pop(dt: float) -> void:
	if mains.has("pop"):
		var ps := pop_stats()
		cd["pop"] -= dt
		if cd["pop"] <= 0.0:
			var cands: Array = []
			for e in enemies:
				if e["dead"] < 0.0 and not e.has("prop") and (e["pos"] as Vector3).distance_to(player.position) < 8.0:
					cands.append(e)
			if cands.size() > 0:
				cd["pop"] = ps["cool"] * cd_mult()
				for i in int(ps["count"]):
					var tg: Dictionary = cands[rng.randi() % cands.size()]
					var to: Vector3 = tg["pos"] + (tg["vel"] as Vector3) * 0.4 + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
					var mi := MeshInstance3D.new()
					mi.mesh = pop_mesh
					mi.material_override = mat_vc
					add_child(mi)
					var evo := evolved.has("pop")
					pops.append({"node": mi, "from": player.position + Vector3(0, 0.9, 0), "to": Vector3(to.x, 0.1, to.z), "t": -i * 0.08,
						"dur": (0.75 if evo else 0.45) / proj_speed(), "dmg": ps["dmg"], "radius": ps["radius"] * area_mult(), "evo": evo})
				_play("yoyo", 2.2, -10.0)
	for pp in pops.duplicate():
		pp["t"] += dt
		var mi: MeshInstance3D = pp["node"]
		if pp["t"] < 0.0:
			mi.visible = false
			continue
		mi.visible = true
		var k: float = minf(1.0, pp["t"] / pp["dur"])
		var h := (5.0 if pp["evo"] else 2.2) * 4.0 * k * (1.0 - k)
		var pos: Vector3 = (pp["from"] as Vector3).lerp(pp["to"], k) + Vector3(0, h, 0)
		mi.position = pos
		mi.rotation = Vector3(k * 20.0, k * 14.0, 0)
		mi.scale = Vector3.ONE * (1.6 if pp["evo"] else 1.0)
		if Engine.get_process_frames() % 2 == 0:
			_glow(pos, Vector3.ZERO, Color(1.0, 0.6, 0.2, 0.8) if not pp["evo"] else Color.from_hsv(fmod(elapsed, 1.0), 0.6, 1.0, 0.9), 0.14 if not pp["evo"] else 0.22, 0.3)
		if k >= 1.0:
			_pop_explode(pp["to"], pp["radius"], pp["dmg"], pp["evo"])
			mi.queue_free()
			pops.erase(pp)

func _pop_explode(at: Vector3, r: float, dmg: float, evo: bool) -> void:
	# 펑! 색색 불꽃
	var cols := [Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.35), Color(1.0, 0.95, 0.8)]
	if evo:
		cols = [Color.from_hsv(rng.randf(), 0.6, 1.0), Color.from_hsv(rng.randf(), 0.6, 1.0), Color(1, 1, 0.9)]
	_glow(at + Vector3(0, 0.5, 0), Vector3.ZERO, Color(1.0, 0.9, 0.6, 1.0), r * 0.9, 0.16)
	_ring(at, Color(cols[0].r, cols[0].g, cols[0].b, 1.0), 0.2, r * 1.15, 0.35)
	for i in (26 if evo else 14):
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.6), rng.randf_range(-1, 1)).normalized() * r * rng.randf_range(3.0, 5.0)
		var c: Color = cols[i % cols.size()]
		_glow(at + Vector3(0, 0.4, 0), v, Color(c.r, c.g, c.b, 1.0), rng.randf_range(0.1, 0.18), rng.randf_range(0.35, 0.6), 7.0)
	for i in (14 if evo else 7):
		var v2 := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.8), rng.randf_range(-1, 1)).normalized() * rng.randf_range(4.0, 7.0)
		var c2: Color = cols[i % cols.size()]
		_part("star", at + Vector3(0, 0.4, 0), v2, c2, 1.0, 0.9, rng.randf_range(-16, 16), 14.0)
	for i in (3 if evo else 2):
		_puff(at + Vector3(0, 0.3, 0), 0.3 * r, 0.5, Color(0.6, 0.55, 0.5, 0.55))
	_play("blast", rng.randf_range(1.2, 1.5), -6.0)
	shake = maxf(shake, 0.12 if not evo else 0.2)
	for e in enemies:
		if e["dead"] >= 0.0:
			continue
		var d: Vector3 = e["pos"] - at
		d.y = 0
		if d.length() < r + e["radius"] * 0.5:
			_hit_enemy(e, dmg, d, 5.0, true)
	if evo:
		# 작은 불꽃이 연달아 터져요
		for i in 3:
			var a := TAU * i / 3.0 + rng.randf()
			var p2 := at + Vector3(cos(a), 0, sin(a)) * r * 0.8
			get_tree().create_timer(0.12 + i * 0.08).timeout.connect(func(): _pop_explode_small(p2, r * 0.5, dmg * 0.5))

func _pop_explode_small(at: Vector3, r: float, dmg: float) -> void:
	var c := Color.from_hsv(rng.randf(), 0.6, 1.0, 1.0)
	_ring(at, c, 0.1, r * 1.2, 0.3)
	for i in 10:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.4), rng.randf_range(-1, 1)).normalized() * rng.randf_range(3.0, 5.0)
		_glow(at + Vector3(0, 0.4, 0), v, c, 0.12, 0.45, 7.0)
	for e in enemies:
		if e["dead"] < 0.0 and (e["pos"] as Vector3).distance_to(at) < r + 0.3:
			_hit_enemy(e, dmg, e["pos"] - at, 3.0, true)
	_play("pop", 1.8, -9.0)

func _rubber_wave(rs: Dictionary, delay: float, col := Color("#ff9a2f")) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	rings.append({"node": mi, "t": -delay, "radius": rs["radius"] * area_mult(), "dmg": rs["dmg"], "knock": rs["knock"],
		"hit": {}, "done": false, "rainbow": rs["double"]})
	_play("rubber", 1.0 + (0.2 if delay > 0 else 0.0), -6.0)
	shake = maxf(shake, 0.1)
	if rs["dmg"] > 0.0:
		var rcol := Color(col.r, col.g, col.b, 0.6)
		_ring(player.position, rcol, 0.3, rs["radius"] * area_mult() * 1.05, 0.45)
		for i in 10:
			var a := TAU * i / 10.0
			var dv := Vector3(cos(a), 0, sin(a))
			_puff(player.position + dv * 0.8 + Vector3(0, 0.2, 0), 0.18, 0.4, Color(0.95, 0.85, 0.7, 0.6))
			_glow(player.position + Vector3(0, 0.3, 0), dv * rs["radius"] * 2.6, rcol, 0.16, 0.38)

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
	mi.mesh = _box(Vector3(0.13, 0.13, 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#fff9b0")
	_glow(b, Vector3.ZERO, Color(1.0, 0.95, 0.3, 1.0), 0.6, 0.2)
	_sparkle(b, Color(1.0, 0.9, 0.3, 1.0), 4, 4.0, 0.09, 0.25)
	mi.material_override = m
	add_child(mi)
	mi.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, a.distance_to(b))
	bolts.append({"node": mi, "t": 0.0})

func _update_bullets(dt: float) -> void:
	for b in bullets.duplicate():
		b["pos"] += b["dir"] * 15.0 * proj_speed() * dt
		b["life"] -= dt
		b["trail"] -= dt
		if b["trail"] <= 0.0:
			b["trail"] = 0.05
			_glow(b["pos"] - b["dir"] * 0.3, -b["dir"] * 1.5, Color(0.35, 0.7, 1.0, 0.7), 0.13 * b["size"], 0.28)
			_part("drop", b["pos"], -b["dir"] * 2.0 + Vector3(rng.randf_range(-1, 1), 1.5, rng.randf_range(-1, 1)), Color(0.75, 0.92, 1.0, 0.85), 0.045 * b["size"], 0.35)
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
			# 철퍽! 물보라
			for j in 8:
				var sv := Vector3(rng.randf_range(-1, 1), rng.randf_range(1.0, 2.2), rng.randf_range(-1, 1)).normalized() * rng.randf_range(2.5, 4.5)
				_part("drop", b["pos"], sv, Color(0.7, 0.9, 1.0, 0.9), rng.randf_range(0.05, 0.09) * b["size"], 0.45)
			_ring(b["pos"], Color(0.45, 0.8, 1.0, 0.9), 0.1, 0.9 * b["size"], 0.3)
			_puff(b["pos"], 0.18 * b["size"], 0.3, Color(0.85, 0.95, 1.0, 0.5))
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
			_glow(player.position + Vector3(0, 0.7, 0), Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3, 0.7) if g.get("coin", false) else Color(0.6, 1.0, 0.8, 0.5), 0.2, 0.25)
			if g.get("coin", false):
				var v := maxi(1, int(round(coin_mult())))
				run_coins += v
				_play("coin", rng.randf_range(1.0, 1.2), -10.0)
			else:
				got += 1
		else:
			keep.append(g)
	while keep.size() > 110:
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

func _part(kind: String, pos: Vector3, vel: Vector3, col: Color, size: float, life: float, spin := 0.0, grav := 9.0, grow := 0.0) -> void:
	if parts.size() > part_cap:
		parts.pop_front()
	var ax := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	parts.append({"kind": kind, "pos": pos, "vel": vel, "col": col, "size": size, "life": life, "t": 0.0, "spin": spin, "rot": rng.randf() * TAU, "grav": grav, "grow": grow, "ax": ax})

func _glow(pos: Vector3, vel: Vector3, col: Color, size: float, life: float, grav := 0.0) -> void:
	# 바쁠 때는 반짝이를 덜 만들어요
	if parts.size() > part_cap * 0.6 and rng.randf() < 0.6:
		return
	_part("glow", pos, vel, col, size, life, 0.0, grav)

func _ring(pos: Vector3, col: Color, r0: float, r1: float, life: float) -> void:
	_part("ring", Vector3(pos.x, 0.08, pos.z), Vector3.ZERO, col, r0, life, 0.0, 0.0, r1)

func _puff(pos: Vector3, size: float, life: float, col := Color(1, 1, 1, 0.75)) -> void:
	var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.5), rng.randf_range(-1, 1)) * 1.2
	_part("puff", pos, v, col, size, life, 0.0, 0.0, size * 1.8)

func _sparkle(pos: Vector3, col: Color, n: int, spd: float, size := 0.12, life := 0.45) -> void:
	for i in n:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.3), rng.randf_range(-1, 1)).normalized() * spd * rng.randf_range(0.4, 1.0)
		_glow(pos, v, col, size * rng.randf_range(0.7, 1.3), life * rng.randf_range(0.7, 1.2), 6.0)

func _burst(pos: Vector3, col: Color, count: int, spd: float, stars := false) -> void:
	for i in count:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.4), rng.randf_range(-1, 1)).normalized() * spd * rng.randf_range(0.5, 1.0)
		if stars:
			_part("star", pos, v, col, 1.0, 0.45, rng.randf_range(-12, 12))
		else:
			_part("drop", pos, v, col, rng.randf_range(0.05, 0.09), 0.35)

func _number(pos: Vector3, v: int, crit: bool, txt := "") -> void:
	if txt == "" and not Save.opt("nums"):
		return
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
	l.text = txt if txt != "" else str(v) + ("!" if crit else "")
	l.font_size = 64 if crit else 44
	l.modulate = Color("#ffdf3d") if crit else Color.WHITE
	l.position = pos + Vector3(rng.randf_range(-0.25, 0.25), 0, 0)
	l.visible = true
	n["t"] = 0.0

var fx_dt := 0.0
func _update_fx(dt: float) -> void:
	# 조각은 그리면서 한 번에 움직여요 (_sync_draw). 여기서는 시간만 넘겨요
	fx_dt += dt
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
			var rk := boss_rank()
			var bt: Color = rk["tint"]
			tint = bt.lerp(bt * 1.25, 0.5 + 0.5 * sin(elapsed * 3.0)) if rk["pre"] != "" else bt
		if e["kind"] == "eraser" and e["dash_t"] > 0.45:
			tint = Color(1.4, 0.8, 0.8)
		var tr := Transform3D(Basis(Vector3.UP, e["rot"]).scaled(scl), e["pos"] + Vector3(0, hop * 0.12 + float(e.get("hop", 0.0)), 0))
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
		# 길쭉한 물줄기: 꿈틀꿈틀 굵기가 바뀌어요
		var wob := 1.0 + 0.12 * sin(elapsed * 40.0 + i)
		var basis := Basis.looking_at(b["dir"], Vector3.UP) * Basis.from_scale(Vector3(0.62 * wob, 0.62 / wob, 3.4) * b["size"])
		bm.set_instance_transform(i, Transform3D(basis, b["pos"]))
		if evolved.has("gun"):
			var hc := Color.from_hsv(fmod(elapsed * 0.7 + i * 0.13, 1.0), 0.45, 1.0, 0.97)
			bm.set_instance_custom_data(i, hc)
		else:
			bm.set_instance_custom_data(i, Color(0.7, 0.92, 1.0, 0.95))
		var bg: MultiMesh = mm["bglow"].multimesh
		bg.set_instance_transform(i, Transform3D(Basis.looking_at(b["dir"], Vector3.UP) * Basis.from_scale(Vector3(0.38, 0.38, 1.1) * b["size"]), b["pos"] - (b["dir"] as Vector3) * 0.25 * b["size"]))
		bg.set_instance_custom_data(i, Color(0.9, 0.7, 0.3, 0.7) if evolved.has("gun") else Color(0.15, 0.45, 0.9, 0.5))
	bm.visible_instance_count = bn
	mm["bglow"].multimesh.visible_instance_count = bn
	# 조각
	var dm: MultiMesh = mm["drop"].multimesh
	var stm: MultiMesh = mm["star"].multimesh
	var gm2: MultiMesh = mm["glow"].multimesh
	var rm: MultiMesh = mm["ring"].multimesh
	var pm2: MultiMesh = mm["puff"].multimesh
	var dn := 0
	var sn := 0
	var gn := 0
	var rn := 0
	var pn := 0
	var dt := fx_dt
	fx_dt = 0.0
	var damp := 1.0 - minf(1.0, dt * 2.5)
	var keep: Array = []
	for p in parts:
		var pt: float = p["t"] + dt
		if pt >= p["life"]:
			continue
		p["t"] = pt
		var kind: String = p["kind"]
		var vel: Vector3 = p["vel"]
		vel.y -= p["grav"] * dt
		if kind == "puff" or kind == "glow":
			vel *= damp
		p["vel"] = vel
		var np: Vector3 = p["pos"] + vel * dt
		if (kind == "star" or kind == "drop") and np.y < 0.05 and vel.y < 0.0:
			# 땅에 톡 튕겨요
			np.y = 0.05
			vel = Vector3(vel.x * 0.6, -vel.y * 0.45, vel.z * 0.6)
			p["vel"] = vel
			p["spin"] *= 0.6
		p["pos"] = np
		if kind == "star":
			p["rot"] += p["spin"] * dt
		keep.append(p)
		var k: float = 1.0 - pt / p["life"]
		var c: Color = p["col"]
		match p["kind"]:
			"glow":
				if gn >= 320:
					continue
				gm2.set_instance_transform(gn, Transform3D(Basis().scaled(Vector3.ONE * p["size"] * (0.4 + 0.6 * k)), p["pos"]))
				gm2.set_instance_custom_data(gn, Color(c.r, c.g, c.b, c.a * k))
				gn += 1
				continue
			"ring":
				if rn >= 90:
					continue
				var e := 1.0 - pow(k, 3.0)
				var r: float = lerpf(p["size"], p["grow"], e)
				var th := 0.15 + 2.2 * k
				rm.set_instance_transform(rn, Transform3D(Basis().scaled(Vector3(r, th * 3.0, r)), p["pos"] + Vector3(0, 0.1 + 0.4 * e, 0)))
				rm.set_instance_custom_data(rn, Color(c.r, c.g, c.b, c.a * minf(1.0, k * 1.6)))
				rn += 1
				continue
			"puff":
				if pn >= 140:
					continue
				var r2: float = lerpf(p["size"], p["grow"], 1.0 - k * k)
				pm2.set_instance_transform(pn, Transform3D(Basis().scaled(Vector3.ONE * r2), p["pos"]))
				pm2.set_instance_custom_data(pn, Color(c.r, c.g, c.b, c.a * k))
				pn += 1
				continue
		if p["kind"] == "star":
			if sn >= 160:
				continue
			var sk := minf(1.0, k * 3.0)
			stm.set_instance_transform(sn, Transform3D(Basis(p["ax"], p["rot"]).scaled(Vector3.ONE * sk * 2.3), p["pos"]))
			stm.set_instance_color(sn, Color.WHITE)
			stm.set_instance_custom_data(sn, Color(c.r, c.g, c.b, 1.0))
			sn += 1
		else:
			if dn >= 260:
				continue
			dm.set_instance_transform(dn, Transform3D(Basis().scaled(Vector3.ONE * p["size"] * minf(1.0, k * 2.5) * 1.2), p["pos"]))
			dm.set_instance_custom_data(dn, Color(c.r, c.g, c.b, 1.0))
			dn += 1
	parts = keep
	dm.visible_instance_count = dn
	stm.visible_instance_count = sn
	gm2.visible_instance_count = gn
	rm.visible_instance_count = rn
	pm2.visible_instance_count = pn

var god := false
func _player_hurt(from: Vector3, amount := 1) -> void:
	if god:
		return
	if shield_on:
		# 명찰 방패가 대신 막아 줘요
		shield_on = false
		hurt_timer = 1.0
		_ring(player.position, Color(1.0, 0.45, 0.6, 1.0), 0.5, 3.0, 0.45)
		_sparkle(player.position + Vector3(0, 1, 0), Color(1.0, 0.6, 0.75, 1.0), 14, 6.0, 0.14, 0.5)
		_number(player.position + Vector3(0, 2.0, 0), 0, true, tr("막았다!"))
		_play("pop", 1.4, -6.0)
		_vib(40)
		return
	nohit_t = 0.0
	hp -= amount
	if amount >= 2:
		_number(player.position + Vector3(0, 2.0, 0), 0, true, tr("하트 -%d") % amount)
	hurt_timer = 2.0
	shake = 0.35
	hitstop(0.08)
	_play("hurt", 1.0, -3.0)
	_vib(120)
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
		_banner(tr("오뚝이 부활!"), Color("#c9a8f0"))
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
var mobile_web := false
var part_cap := 220
var low_fx := false
var slow_t := 0.0
func _auto_quality(delta: float) -> void:
	# 폰이 버거워하면(30프레임 아래가 2초 넘게) 스스로 가볍게 바꿔요
	if low_fx or auto_play or shot_mode != "":
		return
	if delta > 1.0 / 32.0:
		slow_t += delta
	else:
		slow_t = maxf(0.0, slow_t - delta * 0.5)
	if slow_t > 2.0 or not Save.opt("fx"):
		_set_low_fx()

func _set_low_fx() -> void:
	low_fx = true
	part_cap = 90
	if env_ref:
		env_ref.glow_enabled = false
	get_viewport().scaling_3d_scale = 0.62
	for n in ["bglow"]:
		if mm.has(n):
			mm[n].visible = false
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
		if shot_mode == "sup":
			move_dir = Vector3(1, 0, 0)
		if (shot_mode == "sup" or shot_mode.begins_with("top") or shot_mode == "mission_in" or shot_mode.begins_with("pat_") or shot_mode.begins_with("gun_")) and shot_frames in [20, 35, 50, 70, 90]:
			get_viewport().get_texture().get_image().save_png("/tmp/f_%s_%d.png" % [shot_mode, shot_frames])
		if shot_mode.begins_with("pat_") and shot_frames % 4 == 0 and shot_frames <= 72:
			get_viewport().get_texture().get_image().save_png("/tmp/pb_%s_%02d.png" % [shot_mode, shot_frames])
		if shot_mode.begins_with("gun_") and bullets.size() > 0 and shot_frames % 2 == 0 and shot_frames < 90:
			get_viewport().get_texture().get_image().save_png("/tmp/gb_%s_%d.png" % [shot_mode, shot_frames])
		if shot_mode == "boss" and shot_frames % 12 == 0:
			get_viewport().get_texture().get_image().save_png("/tmp/bs_%03d.png" % shot_frames)
		if shot_mode == "cpaper" and cpapers.size() > 0 and shot_frames % 3 == 0:
			get_viewport().get_texture().get_image().save_png("/tmp/cp_%d.png" % shot_frames)
		if shot_mode == "evocine" and shot_frames in [40, 60, 90, 185, 200]:
			get_viewport().get_texture().get_image().save_png("/tmp/evc_%d.png" % shot_frames)
		if shot_mode == "allw" and (shot_frames in [40, 55] or (shot_frames >= 14 and shot_frames <= 40 and bullets.size() > 0 and shot_frames % 2 == 0)):
			get_viewport().get_texture().get_image().save_png("/tmp/shot_allw_%d.png" % shot_frames)
		if shot_frames == (150 if shot_mode == "boss" else (70 if shot_mode == "allw" else (32 if shot_mode == "kills" else (205 if shot_mode == "evocine" else 110)))) and perf_frames == 0:
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
	_auto_quality(delta)
	hitstop_cool -= dt
	if hitstop_left > 0.0:
		hitstop_left -= dt
		_update_camera(dt)
		return
	if evo_cine > 0.0:
		_evo_cine_step(dt)
		return
	if paused or game_over:
		_update_camera(dt)
		_update_fx(dt)
		_sync_draw()
		_update_hud()
		return
	elapsed += dt
	_weather_logic(dt)
	_evo_aura(dt)
	_boss_aura()
	if boss_spawned and not boss.is_empty() and elapsed > boss_time + 60.0:
		boss["speed"] = KINDS["boss"]["speed"] * 2.0   # 1분 안에 못 잡으면 화나요
	_read_input()
	if auto_play:
		_auto_input(dt)
	var target_v := move_dir * move_speed()
	var grip := 2.0 if day_mod == "rain" and _in_puddle(player.position) else 22.0
	player_vel = player_vel.lerp(target_v, minf(1.0, dt * grip))
	player.position += (player_vel + wind) * dt
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
	_update_tut_and_hints(dt)
	_update_indicators()
	var t5 := Time.get_ticks_usec()
	prof[0] += t1 - t0; prof[1] += t2 - t1; prof[2] += t3 - t2; prof[3] += t4 - t3; prof[4] += t5 - t4; prof[5] += 1
	if prof[5] >= 300:
		if perf_frames > 0 or OS.get_cmdline_user_args().has("--prof"): print("PROF t=%d parts=%d gems=%d enemies=%d en=%d weap=%d gems_fx=%d anim=%d draw=%d (us/frame)" % [int(elapsed), parts.size(), gems.size(), enemies.size(), prof[0]/300, prof[1]/300, prof[2]/300, prof[3]/300, prof[4]/300])
		prof = [0,0,0,0,0,0]
	combo_timer -= dt
	if combo_timer <= 0.0:
		combo = 0
	_update_camera(dt)
	_update_hud()
	if auto_play and int(elapsed / 10.0) != int((elapsed - dt) / 10.0):
		print(("BOSS%d " % int(boss["hp"]) if not boss.is_empty() else "") + "T%d kills=%d lv=%d hp=%d enemies=%d gems=%d parts=%d mains=%s sup=%s evo=%s" % [int(elapsed), kills, level, hp, enemies.size(), gems.size(), parts.size(), mains, supports, evolved.keys()] + " snd=%d/%d" % snd_stat)

var menu_t := 0.0
func _menu_idle(dt: float) -> void:
	menu_t += dt
	move_dir = Vector3.ZERO
	face_dir = Vector3(0, 0, 1)
	model.rotation.y = lerp_angle(model.rotation.y, sin(menu_t * 0.6) * 0.35, dt * 3.0)
	_animate_player(dt)
	if fmod(menu_t, 2.5) < dt:
		recoil = 1.0
	cam.position = Vector3(0.35 + sin(menu_t * 0.2) * 0.3, 1.9, 5.9)
	cam.look_at(Vector3(0.35, 0.45, 0), Vector3.UP)
	gun.visible = mains.has("gun")

func _in_puddle(pos: Vector3) -> bool:
	for pd in puddles:
		var c: Vector3 = pd[0]
		if Vector2(pos.x - c.x, pos.z - c.z).length() < pd[1]:
			return true
	return false

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
	var s := shake * shake * 2.2 * (1.0 if Save.opt("shake") else 0.0)
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

# 글자가 자리보다 길면(주로 영어) 글자 크기를 줄여서 한 줄에 맞춰요
func _text_w(l: Control, fs: int) -> float:
	var f: Font = l.get_theme_font("font")
	var w := 0.0
	for line in str(l.get("text")).split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w + l.get_theme_constant("outline_size")

func _fit(l: Control, max_w: float, min_scale := 0.55) -> Control:
	var fs: int = l.get_theme_font_size("font_size")
	var lo := int(fs * min_scale)
	while fs > lo and _text_w(l, fs) > max_w:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	return l

# 여러 줄로 직접 나누고(단어 단위), 상자 높이를 넘으면 글자 크기를 줄여요
func _wrap_lines(f: Font, text: String, w: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var t := word if cur == "" else cur + " " + word
			if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
				out.append(cur)
				cur = word
			else:
				cur = t
		out.append(cur)
	return out

func _fit_box(l: Label, w: float, h: float, min_scale := 0.55) -> Label:
	var f: Font = l.get_theme_font("font")
	var src := l.text
	var fs: int = l.get_theme_font_size("font_size")
	var lo := int(fs * min_scale)
	var lines := _wrap_lines(f, src, w, fs)
	while fs > lo and (lines.size() * (f.get_height(fs) + l.get_theme_constant("line_spacing")) > h or _max_w(f, lines, fs) > w):
		fs -= 1
		lines = _wrap_lines(f, src, w, fs)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text = "\n".join(lines)
	l.add_theme_font_size_override("font_size", fs)
	return l

func _max_w(f: Font, lines: PackedStringArray, fs: int) -> float:
	var m := 0.0
	for line in lines:
		m = maxf(m, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return m

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
	kill_label = _label(tr("귀신 0"), 34, Color.WHITE, hud)
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
	coin_label = _label(tr("동전 0"), 30, Color("#ffd23f"), hud)
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not in_menu and not auto_play and shot_mode == "" and is_inside_tree() and hud != null:
			_pause_menu()

func _set_lines() -> Array:
	# 세트 진화표: [글, 색]
	var out: Array = []
	for id in MAINS:
		var d: Dictionary = MAINS[id]
		var pn: String = SUPPORTS[d["partner"]]["name"]
		if evolved.has(id):
			out.append([tr("%s 진화 완료!") % d["evo"], Color("#ffd23f")])
		elif mains.has(id):
			var have := supports.has(d["partner"])
			out.append(["%s Lv.%d/5 + %s %s" % [d["name"], mains[id], pn, tr("(있어요)") if have else tr("(필요)")] + ("" if evo_open(id) else " " + tr("(잠김)")), Color("#6ee0b0") if have else Color.WHITE])
		elif evo_open(id):
			out.append(["%s + %s = %s" % [d["name"], pn, d["evo"]], Color(1, 1, 1, 0.5)])
		else:
			out.append(["%s + %s = %s %s" % [d["name"], pn, d["evo"], tr("(잠김)")], Color(1, 1, 1, 0.35)])
	return out

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
	var t := _label(tr("잠깐 쉬어요"), 60, Color.WHITE, card_panel)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_left = -300
	t.offset_right = 300
	t.offset_top = -500
	t.offset_bottom = -420
	var sl := _label(tr("세트 진화표"), 36, Color("#ffdf3d"), card_panel, 9)
	sl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.offset_left = -330
	sl.offset_right = 330
	sl.offset_top = -400
	sl.offset_bottom = -350
	var lines := _set_lines()
	for i in lines.size():
		var ll := _label(lines[i][0], 25, lines[i][1], card_panel, 8)
		ll.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.offset_left = -340
		ll.offset_right = 340
		ll.offset_top = -350 + i * 40
		ll.offset_bottom = -312 + i * 40
	var go := _small_btn(tr("계속하기"), Color("#4fa8e8"), 44)
	go.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	go.offset_left = -170
	go.offset_right = 170
	go.offset_top = -100
	go.offset_bottom = 0
	card_panel.add_child(go)
	_arm(go, 0.3)
	var stb := _small_btn(tr("설정"), Color("#8a7a95"), 36)
	stb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stb.offset_left = -170
	stb.offset_right = 170
	stb.offset_top = 30
	stb.offset_bottom = 120
	card_panel.add_child(stb)
	stb.pressed.connect(_open_settings)
	go.pressed.connect(func():
		card_panel.queue_free()
		card_panel = null
		paused = false)
	var q := _small_btn(tr("그만하고 나가기"), Color("#e8524a"), 36)
	q.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	q.offset_left = -170
	q.offset_right = 170
	q.offset_top = 150
	q.offset_bottom = 240
	card_panel.add_child(q)
	q.pressed.connect(func():
		if not q.has_meta("armed"):
			q.set_meta("armed", true)
			q.text = tr("정말 나갈까요? 한 번 더!")
			return
		card_panel.queue_free()
		card_panel = null
		paused = false
		_end_game(false))

func _open_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box_p := Panel.new()
	box_p.add_theme_stylebox_override("panel", _round_panel(Color("#fff8e8"), 36, Color("#8a7a95"), 10))
	box_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box_p.offset_left = -300
	box_p.offset_right = 300
	box_p.offset_top = -480 if in_menu else -430
	box_p.offset_bottom = 480 if in_menu else 430
	root.add_child(box_p)
	var t := _label(tr("설정"), 56, Color("#3a2148"), box_p, 0)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 30
	var items := [["bgm", tr("배경음악")], ["sfx", tr("효과음")], ["vib", tr("진동")], ["shake", tr("화면 흔들림")], ["nums", tr("데미지 숫자")], ["fx", tr("화려한 이펙트")]]
	for i in items.size():
		var key: String = items[i][0]
		var l := _label(items[i][1], 40, Color("#3a2148"), box_p, 0)
		l.position = Vector2(50, 130 + i * 100)
		var b := _small_btn(tr("켜짐") if Save.opt(key) else tr("꺼짐"), Color("#2fc79a") if Save.opt(key) else Color("#b9b0bf"), 34)
		b.position = Vector2(370, 118 + i * 100)
		b.size = Vector2(180, 80)
		box_p.add_child(b)
		b.pressed.connect(func():
			var v := not Save.opt(key)
			Save.set_opt(key, v)
			b.text = tr("켜짐") if v else tr("꺼짐")
			var st := _round_panel(Color("#2fc79a") if v else Color("#b9b0bf"), 26, Color("#3a2148"), 5)
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)
			_play("ui_toggle", 1.0, -4.0)
			if key == "bgm" and bgm:
				bgm.volume_db = -9.0 if v else -80.0
			_play("pick", 1.0, -3.0))
	if in_menu:
		# 언어는 메뉴에서만 바꿔요 (바꾸면 화면을 새로 불러와요). 어느 언어에서도 찾을 수 있게 두 말을 같이 써요.
		var ll := _label("Language / 언어", 34, Color("#3a2148"), box_p, 0)
		ll.position = Vector2(50, 130 + items.size() * 100 + 6)
		var lb := _small_btn("한국어" if Save.lang() == "ko" else "English", Color("#7fa8ff"), 34)
		lb.position = Vector2(370, 118 + items.size() * 100)
		lb.size = Vector2(180, 80)
		box_p.add_child(lb)
		lb.pressed.connect(func():
			_play("ui_toggle", 1.0, -4.0)
			Save.set_lang("en" if Save.lang() == "ko" else "ko")
			get_tree().reload_current_scene())
	var close := _small_btn(tr("닫기"), Color("#4fa8e8"), 40)
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_left = -150
	close.offset_right = 150
	close.offset_top = -130
	close.offset_bottom = -40
	box_p.add_child(close)
	close.pressed.connect(layer.queue_free)

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
	banner_label.add_theme_font_size_override("font_size", 46)
	_fit(banner_label, 690, 0.6)
	banner_label.add_theme_color_override("font_color", col)
	banner_t = 2.2

func _update_hud() -> void:
	var left := maxf(0.0, boss_time - elapsed)
	if boss_spawned:
		timer_label.text = tr("보스전!")
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
			var bl := _label(boss_name(), 26, Color.WHITE, boss_bar_bg, 7)
			bl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_bar.size.x = 508.0 * clampf(boss["hp"] / boss["max_hp"], 0, 1)
	xp_bar.size.x = xp_bar_bg.size.x * float(xp) / float(xp_need)
	kill_label.text = tr("귀신 %d") % kills
	coin_label.text = tr("동전 %d") % run_coins
	for c in slot_box.get_children():
		if c.has_meta("ready"):
			(c as Control).modulate = Color(1, 1, 1).lerp(Color(1.6, 1.4, 0.6), 0.5 + 0.5 * sin(elapsed * 8.0))
	if combo >= 5:
		var cm := combo_mult()
		combo_label.text = tr("%d 콤보!") % combo + (tr("\n피해 x%.2f") % cm if cm > 1.0 else "")
		combo_label.add_theme_color_override("font_color", Color("#ffdf3d").lerp(Color("#ff5c7a"), clampf((cm - 1.0) / 0.6, 0, 1)))
		combo_label.modulate.a = minf(1.0, clampf(combo_timer / 1.6, 0, 1) * 3.0)
		combo_label.scale = Vector2.ONE * (1.0 + maxf(0.0, combo_timer - 1.45) * 3.0)
	else:
		combo_label.text = ""

# ---------- 레벨업 카드 ----------
# 상자/뽑기: 새 무기나 새 아이템은 주지 않고, 이미 가진 것만 올려 줘요 (진화가 준비되면 진화)
func _owned_pool() -> Array:
	for id in MAINS:
		if evo_ready(id):
			return [{"type": "evo", "id": id}]
	var opts: Array = []
	for id in mains:
		if not evolved.has(id) and mains[id] < MAX_LV:
			opts.append({"type": "main", "id": id})
	for id in supports:
		if supports[id] < MAX_LV:
			opts.append({"type": "sup", "id": id})
	opts.shuffle()
	if opts.is_empty():
		opts.append({"type": "heal", "id": "heal"})
	return opts

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

func _level_fx() -> void:
	_ring(player.position, Color(1.0, 0.85, 0.3, 1.0), 0.3, 3.0, 0.6)
	_ring(player.position, Color(0.5, 1.0, 0.8, 0.8), 0.2, 2.0, 0.5)
	for i in 24:
		var a := TAU * i / 24.0
		_glow(player.position + Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3(0, rng.randf_range(4, 8), 0), Color(1.0, 0.9, 0.4, 0.9), 0.14, 0.7, 2.0)

func _level_up() -> void:
	_level_fx()
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	stick_base.visible = false
	var pick := _card_pool()
	var is_evo: bool = pick[0]["type"] == "evo"
	_play("evo" if is_evo else "level", 1.0, -2.0)
	if not is_evo:
		_play("ui_level", 1.0, -4.0)
	if auto_play:
		_apply_card(pick[0] if is_evo else pick[rng.randi() % pick.size()])
		return
	_show_cards(pick)

func _show_cards(pick: Array) -> void:
	var is_evo: bool = pick[0]["type"] == "evo"
	var first_card := not Save.tut_seen("card") and shot_mode == ""
	card_panel = Control.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(card_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	var title := _label(tr("세트 완성! 진화!") if is_evo else tr("레벨 업!  하나 골라요"), 58, Color("#ffdf3d"), card_panel)
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
		_arm(b)
		b.scale = Vector2(0.6, 0.6)
		b.pivot_offset = Vector2(300, 105)
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if first_card:
		Save.tut_mark("card")
		var hint := _label(tr("같은 장난감을 Lv.5까지 키우고\n세트 짝꿍 보조를 모으면 진화해요!"), 34, Color.WHITE, card_panel, 10)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.offset_left = -340
		hint.offset_right = 340
		hint.offset_top = 290
	if rerolls > 0 and not is_evo:
		var rb := _small_btn(tr("다시 뽑기 (%d)") % rerolls, Color("#58c6f2"))
		rb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		rb.offset_left = -170
		rb.offset_right = 170
		rb.offset_top = -190
		rb.offset_bottom = -100
		card_panel.add_child(rb)
		_arm(rb)
		rb.pressed.connect(func():
			rerolls -= 1
			card_panel.queue_free()
			card_panel = null
			_play("pick", 0.8, -3.0)
			_show_cards(_card_pool()))

func _arm(b: Control, delay := 0.5) -> void:
	# 손가락이 화면에 닿아 있던 채로 버튼이 눌리지 않게 잠깐 막아요
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate.a = 0.75
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(b):
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.modulate.a = 1.0)

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
			tag = tr("진화!")
			icon = d["icon"]
			col = Color("#ffc928")
			setline = "%s Lv.5 + %s" % [d["name"], SUPPORTS[d["partner"]]["name"]]
			gold = true
		"main":
			var d: Dictionary = MAINS[c["id"]]
			var cur: int = mains.get(c["id"], 0)
			nm_t = d["name"]
			desc = d["desc"][cur]
			tag = tr("새로!") if cur == 0 else "Lv.%d > %d" % [cur, cur + 1]
			icon = d["icon"]
			col = Color(d["col"])
			var pn: String = SUPPORTS[d["partner"]]["name"]
			setline = tr("세트 짝꿍: %s%s") % [pn, tr("  (있어요!)") if supports.has(d["partner"]) else ""]
			if not evo_open(c["id"]):
				setline += tr("  (진화 잠김)")
		"sup":
			var d: Dictionary = SUPPORTS[c["id"]]
			var cur: int = supports.get(c["id"], 0)
			nm_t = d["name"]
			desc = d["desc"]
			tag = tr("새로!") if cur == 0 else "Lv.%d > %d" % [cur, cur + 1]
			icon = d["icon"]
			col = Color(d["col"])
			if d["set"] != "":
				setline = tr("세트 짝꿍: %s%s") % [MAINS[d["set"]]["name"], tr("  (있어요!)") if mains.has(d["set"]) else ""]
			else:
				setline = tr("보조 아이템")
		"heal":
			nm_t = tr("뽀빠이 과자")
			desc = tr("하트 2칸 회복")
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
	var tg := _label(tag, 30, Color("#e8524a") if tag == tr("새로!") or gold else Color("#8a7a95"), b, 0)
	tg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tg.offset_left = -220
	tg.offset_right = -26
	tg.offset_top = 30
	_fit(nm, 600 - 168 - 40 - _text_w(tg, 30))
	nm.position.y = 26 + (44 - nm.get_theme_font_size("font_size")) * 0.6
	var ds := _label(desc, 30, Color("#5b4a66"), b, 0)
	ds.position = Vector2(168, 88)
	_fit_box(ds, 390, 72)
	if setline != "":
		var sl := _label(setline, 24, Color("#d08a00") if setline.contains(tr("있어요")) or gold else Color("#9b8aa5"), b, 0)
		sl.position = Vector2(168, 162)
		_fit(sl, 390)
	b.pressed.connect(func(): _apply_card(c))
	return b

func _apply_card(c: Dictionary, from_chest := false) -> void:
	var id: String = c["id"]
	match c["type"]:
		"evo":
			evolved[id] = true
			if not from_chest or true:
				call_deferred("_evo_cinematic", id)
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
	_evo_lock_hint()
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
	var n := 3 if rng.randf() < 0.08 + 0.03 * Save.shop_lv("luck") else 1
	var got: Array = []
	for i in n:
		var pool := _owned_pool()
		var c: Dictionary = pool[0]
		got.append(c)
		_apply_card(c, true)
	var cc := int(round((5 + 3 * n) * coin_mult()))
	run_coins += cc
	_reward_panel(tr("보물 상자!") if n == 1 else tr("대박! 보물 3개!"), got, cc, [])

func _reward_panel(title_t: String, got: Array, cc: int, extra: Array) -> void:
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
	var title := _label(title_t, 64, Color("#ffdf3d"), card_panel)
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
	for ex in extra:
		var el := _label(ex, 44, Color.WHITE, vb, 10)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cc > 0:
		var cl := _label(tr("동전 +%d") % cc, 40, Color("#ffd23f"), vb)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := _small_btn(tr("좋아!"), Color("#ff9a2f"), 44)
	ok.custom_minimum_size = Vector2(300, 100)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	_arm(ok, 0.6)
	ok.pressed.connect(func():
		card_panel.queue_free()
		card_panel = null
		paused = false)

func _card_info(c: Dictionary) -> Dictionary:
	var info := {"name": tr("뽀빠이 과자"), "desc": tr("하트 2칸 회복"), "tag": "", "icon": "♥", "col": Color("#ff5c7a"), "gold": false}
	match c["type"]:
		"evo":
			var d: Dictionary = MAINS[c["id"]]
			info = {"name": d["evo"], "desc": d["evo_desc"], "tag": tr("진화!"), "icon": d["icon"], "col": Color("#ffc928"), "gold": true}
		"main":
			var d: Dictionary = MAINS[c["id"]]
			var cur: int = mains.get(c["id"], 0)
			info = {"name": d["name"], "desc": d["desc"][maxi(0, cur - 1)], "tag": "Lv.%d" % cur, "icon": d["icon"], "col": Color(d["col"]), "gold": false}
		"sup":
			var d: Dictionary = SUPPORTS[c["id"]]
			info = {"name": d["name"], "desc": d["desc"], "tag": "Lv.%d" % supports.get(c["id"], 0), "icon": d["icon"], "col": Color(d["col"]), "gold": false}
	return info

# ---------- 진화 연출: 멈춤, 확대, 번쩍, 빛줄기, 폭발 ----------
var evo_cine := 0.0
var evo_id := ""
var evo_ui: CanvasLayer
var evo_rays: Control
var evo_boom_done := false
const EVO_LEN := 2.6

func _evo_cinematic(id: String) -> void:
	evo_id = id
	evo_cine = EVO_LEN
	evo_boom_done = false
	paused = true
	stick_index = -1
	stick_vec = Vector2.ZERO
	if stick_base:
		stick_base.visible = false
	_play("evo", 1.0, 0.0)
	_play("warn", 0.6, -6.0)
	_vib(80)
	if auto_play:
		evo_cine = 0.01
		return
	var d: Dictionary = MAINS[id]
	evo_ui = CanvasLayer.new()
	evo_ui.layer = 15
	add_child(evo_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evo_ui.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.02, 0.15, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.55, 0.3)
	# 회전하는 빛줄기
	var vs := get_viewport().get_visible_rect().size
	evo_rays = Control.new()
	evo_rays.position = vs / 2.0
	evo_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(evo_rays)
	for i in 16:
		var r := ColorRect.new()
		r.color = Color.from_hsv(float(i) / 16.0, 0.45, 1.0, 0.55) if i % 2 == 0 else Color(1, 0.95, 0.6, 0.45)
		r.size = Vector2(1400, 46 if i % 2 == 0 else 22)
		r.position = Vector2(0, -r.size.y / 2.0)
		r.pivot_offset = Vector2(0, r.size.y / 2.0)
		r.rotation = TAU * i / 16.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		evo_rays.add_child(r)
	evo_rays.scale = Vector2(0.01, 0.01)
	evo_rays.create_tween().tween_property(evo_rays, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 큰 배지
	var badge := _badge(root, d["icon"], Color("#ffc928"), 220, vs / 2.0 - Vector2(110, 260), true)
	badge.pivot_offset = Vector2(110, 110)
	badge.scale = Vector2(0.1, 0.1)
	var bt := badge.create_tween()
	bt.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(badge, "scale", Vector2.ONE, 0.2)
	var t1 := _label(tr("진화!"), 120, Color("#ffdf3d"), root, 22)
	t1.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.offset_left = -360
	t1.offset_right = 360
	t1.offset_top = -40
	t1.offset_bottom = 110
	t1.pivot_offset = Vector2(360, 75)
	t1.scale = Vector2(3.0, 3.0)
	t1.modulate.a = 0.0
	var tt := t1.create_tween()
	tt.tween_interval(0.25)
	tt.tween_property(t1, "modulate:a", 1.0, 0.01)
	tt.parallel().tween_property(t1, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t2 := _label(d["evo"], 64, Color.WHITE, root, 16)
	t2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.offset_left = -360
	t2.offset_right = 360
	t2.offset_top = 110
	t2.offset_bottom = 200
	t2.modulate.a = 0.0
	t2.create_tween().tween_interval(0.5)
	t2.create_tween().tween_property(t2, "modulate:a", 1.0, 0.3).set_delay(0.5)
	var t3 := _label(d["evo_desc"], 30, Color("#ffe9a8"), root, 10)
	t3.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t3.offset_left = -320
	t3.offset_right = 320
	t3.offset_top = 205
	t3.offset_bottom = 300
	t3.modulate.a = 0.0
	t3.create_tween().tween_property(t3, "modulate:a", 1.0, 0.3).set_delay(0.75)
	# 하얀 번쩍
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.45)

func _evo_cine_step(dt: float) -> void:
	evo_cine -= dt
	var k := 1.0 - evo_cine / EVO_LEN
	# 카메라가 철수에게 확 다가갔다가 돌아와요
	var zoom := sin(clampf(k / 0.85, 0.0, 1.0) * PI)
	var target := player.position + cam_off.lerp(Vector3(0, 3.2, 3.6), zoom * 0.85)
	cam.position = cam.position.lerp(target, minf(1.0, dt * 8.0))
	cam.look_at(player.position + Vector3(0, 0.7, 0), Vector3.UP)
	if evo_rays:
		evo_rays.rotation += dt * 1.6
	# 철수 주변으로 빛이 빨려 들어가요
	for i in 4:
		var a := rng.randf() * TAU
		var pp := player.position + Vector3(cos(a) * 3.0, rng.randf_range(0.2, 2.0), sin(a) * 3.0)
		_glow(pp, (player.position + Vector3(0, 0.8, 0) - pp) * 3.5, Color.from_hsv(rng.randf(), 0.5, 1.0, 1.0), 0.13, 0.28)
	if k > 0.15 and Engine.get_process_frames() % 6 == 0:
		_ring(player.position, Color.from_hsv(fmod(k * 3.0, 1.0), 0.6, 1.0, 1.0), 0.2, 2.2, 0.4)
	model.rotation.y += dt * (4.0 + k * 20.0)
	recoil = 1.0
	_animate_player(dt)
	_update_fx(dt)
	_sync_draw()
	if evo_cine <= 0.0:
		_evo_finish()

func _evo_finish() -> void:
	evo_cine = 0.0
	if evo_ui:
		evo_ui.queue_free()
		evo_ui = null
		evo_rays = null
	cam.look_at(player.position, Vector3.UP)
	cam.rotation = Vector3.ZERO
	cam.look_at_from_position(cam.position, cam.position - cam_off, Vector3.UP)
	_evo_fx()
	_evo_boom()
	paused = card_panel != null

func _evo_boom() -> void:
	# 진화 폭발: 주변 귀신 싹쓸이
	shake = 0.9
	hitstop(0.12)
	_vib(200)
	_play("blast", 0.6, 0.0)
	_play("pop", 0.6, -2.0)
	for i in 6:
		_ring(player.position, Color.from_hsv(i / 6.0, 0.55, 1.0, 1.0), 0.3, 4.0 + i * 1.5, 0.5 + i * 0.12)
	_glow(player.position + Vector3(0, 1, 0), Vector3.ZERO, Color(1, 1, 0.9, 1), 4.0, 0.3)
	for i in 60:
		var a := rng.randf() * TAU
		var v := Vector3(cos(a), rng.randf_range(0.3, 1.6), sin(a)) * rng.randf_range(6, 13)
		_glow(player.position + Vector3(0, 0.8, 0), v, Color.from_hsv(rng.randf(), 0.55, 1.0, 1.0), rng.randf_range(0.14, 0.26), rng.randf_range(0.6, 1.1), 8.0)
	var confetti := [Color("#ff7aa8"), Color("#ffd23f"), Color("#6ee0b0"), Color("#58c6f2"), Color("#c9a8f0")]
	for i in 50:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(1.0, 2.2), rng.randf_range(-1, 1)).normalized() * rng.randf_range(5, 10)
		_part("star", player.position + Vector3(0, 1.0, 0), v, confetti[i % 5], 1.0, 1.4, rng.randf_range(-14, 14))
	for e in enemies:
		var d: Vector3 = e["pos"] - player.position
		if d.length() < 9.0 and e["kind"] != "boss":
			_hit_enemy(e, 120.0 + level * 6.0, d, 12.0, true)
		elif e["kind"] == "boss":
			_hit_enemy(e, 400.0, d, 3.0, true)

func _boss_aura() -> void:
	if boss.is_empty() or boss["dead"] >= 0.0 or boss_rank()["pre"] == "":
		return
	if Engine.get_process_frames() % 3 == 0:
		var bt: Color = boss_rank()["tint"]
		var a := rng.randf() * TAU
		var bp: Vector3 = boss["pos"]
		_glow(bp + Vector3(cos(a) * 1.6, 0.2, sin(a) * 1.6), Vector3(0, rng.randf_range(2, 4), 0), Color(bt.r * 0.6, bt.g * 0.6, bt.b * 0.6, 0.8), 0.25, 0.7, -1.0)
	if Engine.get_process_frames() % 40 == 0:
		var bt2: Color = boss_rank()["tint"]
		_ring(boss["pos"], Color(bt2.r * 0.6, bt2.g * 0.6, bt2.b * 0.6, 0.8), 1.0, 3.0, 0.7)

func _evo_aura(dt: float) -> void:
	# 진화한 무기가 있으면 발밑에 빛 고리와 반짝이가 늘 따라다녀요
	var n := evolved.size()
	if n == 0:
		return
	if Engine.get_process_frames() % maxi(2, 6 - n) == 0:
		var a := elapsed * 3.0 + rng.randf() * TAU
		var r := 0.9
		_glow(player.position + Vector3(cos(a) * r, 0.15, sin(a) * r), Vector3(0, rng.randf_range(1.0, 2.5), 0),
			Color.from_hsv(fmod(elapsed * 0.3 + rng.randf() * 0.2, 1.0), 0.45, 1.0, 0.8), 0.1, 0.6, -0.5)
	if Engine.get_process_frames() % 50 == 0:
		_ring(player.position, Color(1.0, 0.85, 0.35, 0.6), 0.6, 1.4, 0.8)

func _evo_fx() -> void:
	shake = 0.4
	for i in 4:
		_ring(player.position, Color.from_hsv(i / 4.0, 0.6, 1.0, 1.0), 0.3, 3.0 + i * 1.6, 0.6 + i * 0.15)
	for i in 30:
		var a := TAU * i / 30.0
		_glow(player.position + Vector3(0, 0.8, 0), Vector3(cos(a), 0.4, sin(a)) * 7.0, Color.from_hsv(float(i) / 30.0, 0.5, 1.0, 1.0), 0.2, 0.8)
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
	var bonus := int(round((60 + 40 * dg) * (1.0 + 0.1 * Save.shop_lv("coin")))) if win else 0
	bonus += int(kills / 14.0 * (1.0 + 0.1 * Save.shop_lv("coin")))
	run_coins += bonus
	var result := {"stage": stage, "grade": grade, "win": win, "kills": kills, "elites": elites_killed, "evos": evolved.size(),
		"gems": gems_got, "coins": run_coins, "combo": best_combo, "nohit": int(best_nohit), "time": int(elapsed),
		"chests": chests_opened, "kinds": kinds_killed, "gacha": gacha_used, "missions": missions_done, "weekly": weekly,
		"score": kills + int(elapsed) * 3 + (3000 if win else 0)}
	var rec := {"news": []}
	if not auto_play and shot_mode == "":
		var own: String = Save.CHARS[char_id]["weapon"]
		var evo_before := Save.evo_open_list(own)
		rec = Save.record_run(result)
		for id in Save.evo_open_list(own):
			if not evo_before.has(id):
				rec["news"].append(tr("새 진화 비법: ") + MAINS[id]["evo"] + "!")
	if auto_play:
		print("END missions=%d " % missions_done + "stage=%s mod=%s gacha=%d coins=%d chests=%d elites=%d " % [stage, day_mod, gacha_used, run_coins, chests_opened, elites_killed] + "win=%s t=%d kills=%d lv=%d mains=%s sup=%s evo=%s" % [win, int(elapsed), kills, level, mains, supports, evolved.keys()])
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
	var t := _label(tr("대왕귀신을 물리쳤다!") if win else Save.CHARS[char_id]["name"] + tr("가 기절했어요"), 52, Color("#ffdf3d") if win else Color("#ff7aa8"), box_p)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 46
	var evo_names: Array = []
	for id in evolved:
		evo_names.append(MAINS[id]["evo"])
	var lines := tr("버틴 시간  %d:%02d\n물리친 귀신  %d마리\n레벨  %d\n진화  %s\n\n동전 +%d%s") % [int(elapsed) / 60, int(elapsed) % 60, kills, level,
		", ".join(evo_names) if evo_names.size() > 0 else tr("아직 없어요"), run_coins, (tr("  (보너스 %d 포함)") % bonus) if bonus > 0 else ""]
	if not auto_play and shot_mode == "":
		var af := Save.affordable()
		if af.size() > 0:
			lines += tr("\n\n문방구에서 '%s' 살 수 있어요!") % af[0]["name"]
	if weekly:
		lines += tr("\n\n주간 도전 점수 %d (이번 주 최고 %d)") % [result["score"], Save.weekly_best()]
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
	b.text = tr("한 판 더!")
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
	var hb := _small_btn(tr("메인으로"), Color("#ff9a2f"), 40)
	hb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hb.offset_left = 10
	hb.offset_right = 250
	hb.offset_top = -140
	hb.offset_bottom = -44
	box_p.add_child(hb)
	hb.pressed.connect(func():
		Save.mode = "menu"
		get_tree().reload_current_scene())
	if weekly:
		var sh := _small_btn(tr("결과 복사해서 자랑하기"), Color("#2fc79a"), 30)
		sh.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		sh.offset_left = -250
		sh.offset_right = 250
		sh.offset_top = -250
		sh.offset_bottom = -160
		box_p.add_child(sh)
		var txt := tr("[문방구 퇴마단 주간 도전 %d주차] %s %s로 %d점! 귀신 %d마리, %d:%02d 버팀") % [Save.week_id() % 100, Save.STAGES[stage]["name"], Save.CHARS[char_id]["name"], result["score"], kills, int(elapsed) / 60, int(elapsed) % 60]
		sh.pressed.connect(func():
			DisplayServer.clipboard_set(txt)
			sh.text = tr("복사했어요! 단톡방에 붙여 넣어요"))

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
	sounds["bell"] = _synth(1.4, func(t: float, st: Dictionary) -> float:
		var notes: Array[float] = [784.0, 659.0, 784.0, 659.0]
		var i := mini(3, int(t / 0.32))
		var lt := t - i * 0.32
		return (sin(t * notes[i] * TAU) + 0.4 * sin(t * notes[i] * 2.76 * TAU)) * exp(-lt * 5.0) * 0.35)
	sounds["kick"] = _synth(0.2, func(t: float, st: Dictionary) -> float:
		st["ph"] += (120.0 * exp(-t * 20.0) + 45.0) / 22050.0
		return sin(st["ph"] * TAU) * exp(-t * 14.0) * 0.8)
	sounds["hat"] = _synth(0.06, func(t: float, st: Dictionary) -> float:
		return r.randf_range(-1, 1) * exp(-t * 70.0) * 0.4)
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
	# 화면 소리는 Kenney 인터페이스 효과음(CC0)으로
	for nm in ["ui_pick", "ui_level", "ui_error", "ui_toggle", "ui_drop", "ui_open"]:
		var path := "res://sfx/%s.ogg" % nm
		if ResourceLoader.exists(path):
			sounds[nm] = load(path)
	if sounds.has("ui_pick"):
		sounds["pick"] = sounds["ui_pick"]
	# 새로 만든 손맛 효과음(겹친 소리 + 잔향)으로 바꿔요. 요요 소리는 그대로!
	for nm in ["hit", "blast", "shoot", "pop", "gem", "coin", "level", "evo", "hurt", "splash", "heal", "magnet", "rubber", "zap", "kick"]:
		var path := "res://sfx/fx_%s.ogg" % nm
		if ResourceLoader.exists(path):
			sounds[nm] = load(path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players_audio.append(p)
		player_snd.append("")
	# 소리가 한꺼번에 많이 겹쳐도 찢어지지 않게 마지막에 살짝 눌러 줘요
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)

func _play_bgm(track: String) -> void:
	if auto_play or not ResourceLoader.exists("res://music/%s.ogg" % track):
		return
	var st: AudioStreamOggVorbis = load("res://music/%s.ogg" % track)
	st.loop = true
	bgm.stream = st
	bgm.volume_db = -9.0 if Save.opt("bgm") else -80.0
	bgm.play()

func _vib(ms: int) -> void:
	if Save.opt("vib"):
		Input.vibrate_handheld(ms)

# 자주 나는 소리: 같은 소리는 이 간격(밀리초)보다 촘촘히 내지 않고, 자리가 모자라면 이 소리부터 비켜요
const SND_GAP := {"hit": 55, "gem": 45, "shoot": 70, "coin": 60, "pop": 70, "splash": 90, "zap": 80, "blast": 90,
	"rubber": 90, "kick": 90, "magnet": 150, "yoyo": 80}
var player_snd: Array = []
var snd_last := {}
var snd_stat := [0, 0]   # 낸 소리, 건너뛴 소리 (봇 기록용)
func _play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sounds.has(name) or not Save.opt("sfx"):
		return
	var minor := SND_GAP.has(name)
	var now := Time.get_ticks_msec()
	if minor and now - int(snd_last.get(name, -99999)) < int(SND_GAP[name]):
		snd_stat[1] += 1
		return
	# 쉬고 있는 자리를 먼저 찾고, 없으면 자주 나는 소리 자리를 빌려요 (큰 소리는 끊지 않아요)
	var pick := -1
	for k in players_audio.size():
		var j := (audio_i + k) % players_audio.size()
		if not (players_audio[j] as AudioStreamPlayer).playing:
			pick = j
			break
	if pick < 0:
		for k in players_audio.size():
			var j := (audio_i + k) % players_audio.size()
			if SND_GAP.has(player_snd[j]):
				pick = j
				break
	if pick < 0:
		snd_stat[1] += 1
		return
	snd_last[name] = now
	snd_stat[0] += 1
	audio_i = (pick + 1) % players_audio.size()
	player_snd[pick] = name
	var p: AudioStreamPlayer = players_audio[pick]
	p.stream = sounds[name]
	# 자주 나는 소리는 높낮이를 살짝 흔들어서 덜 질리게
	if name in ["hit", "blast", "gem", "shoot", "coin", "pop"]:
		pitch *= randf_range(0.92, 1.08)
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
		boss["pat"] = "rest"
		boss["pat_t"] = 999.0
		for k in ["kettle", "eraser", "dust", "paper", "egg"]:
			var e := _make_enemy(k, Vector3(-3.0 + ["kettle", "eraser", "dust", "paper", "egg"].find(k) * 1.5, 0, 0.5))
			e["speed"] = 0.0
		spawn_timer = 999.0
		next_elite = 9999.0
		return
	if shot_mode.begins_with("gun_"):
		# 물총 방향 확인용: 귀신 하나를 오른쪽(gun_x) 또는 위쪽(gun_z)에 세워 둬요
		var gp := Vector3(4.5, 0, 0) if shot_mode == "gun_x" else (Vector3(-3.2, 0, -3.2) if shot_mode == "gun_d" else Vector3(0, 0, -4.5))
		var ge := _make_enemy("kettle", gp)
		ge["speed"] = 0.0
		ge["hp"] = 99999.0
		ge["spawn"] = 1.0
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
		boss["scale"] *= boss_rank()["scale"]
		boss["radius"] *= boss_rank()["scale"]
		_banner(boss_name() + tr("이 와요!"), Color("#ff7aa8"))
		boss["pat"] = "shoes"
		boss["pat_t"] = 0.9
		boss["stage"] = 0
		_warn_circle(Vector3(1.5, 0, 1.0), 1.5, 3.0)
		_warn_line(Vector3(-3, 0, -3), Vector3(0.5, 0, 1).normalized(), 3.0)
	for e in enemies:
		e["spawn"] = 1.0
	if shot_mode in ["evo", "evocard", "evo_perf"]:
		for id in ["plane", "pop", "rubber"]:
			main_order.append(id)
			mains[id] = 5
		mains["gun"] = 5
		for id in ["bottle", "colorpaper", "magnifier", "sneakers"]:
			support_order.append(id)
			supports[id] = 2
		if shot_mode != "evocard":
			for id in ["gun", "plane", "pop", "rubber"]:
				evolved[id] = true
		_refresh_ui()
		_refresh_slots()
	if shot_mode == "cards" or shot_mode == "evocard":
		_level_up()
	if shot_mode == "cpaper":
		supports["colorpaper"] = 3
		support_order.append("colorpaper")
		enemies.clear()
		for i in 10:
			var a := TAU * i / 10.0
			var e := _make_enemy("paper", Vector3(cos(a), 0, sin(a)) * 5.0)
			e["hp"] = 99999.0
			e["speed"] = 0.2
			e["spawn"] = 1.0
		spawn_timer = 999.0
		next_elite = 9999.0
	if shot_mode == "evocine":
		mains["gun"] = 5
		supports["bottle"] = 1
		support_order.append("bottle")
		_refresh_slots()
		get_tree().create_timer(0.3).timeout.connect(func(): _apply_card({"type": "evo", "id": "gun"}))
	if shot_mode == "kills":
		enemies.clear()
		for i in 30:
			var a := TAU * i / 30.0
			var e := _make_enemy(["paper", "egg", "kettle"][i % 3], Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.6, 4.0))
			e["hp"] = 8.0
			e["speed"] = 0.8
			e["spawn"] = 1.0
		mains["rubber"] = 3
		main_order.append("rubber")
		cd["rubber"] = 0.6
		xp_need = 99999
		spawn_timer = 999.0
		next_elite = 9999.0
	if shot_mode == "top" or shot_mode == "top_evo":
		# 팽이 확인용
		enemies.clear()
		for i in 16:
			var a := TAU * i / 16.0
			var e := _make_enemy(["paper", "egg"][i % 2], Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 5.5))
			e["hp"] = 99999.0
			e["speed"] = 0.4
			e["spawn"] = 1.0
		mains.erase("gun")
		main_order.erase("gun")
		mains["top"] = 5
		main_order.append("top")
		supports["pencil"] = 1
		support_order.append("pencil")
		if shot_mode == "top_evo":
			evolved["top"] = true
		cd["top"] = 0.1
		xp_need = 99999
		spawn_timer = 999.0
		next_elite = 9999.0
		_refresh_ui()
		_refresh_slots()
	if shot_mode == "allw":
		if OS.get_cmdline_user_args().has("--close"):
			cam_off = Vector3(0, 7.0, 5.5)
		enemies.clear()
		for i in 14:
			var a := TAU * i / 14.0
			var e := _make_enemy("paper", Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 5.0))
			e["hp"] = 99999.0
			e["speed"] = 0.3
			e["spawn"] = 1.0
		for id in ["plane", "pop", "yoyo"]:
			main_order.append(id)
			mains[id] = 4
		mains["gun"] = 4
		spawn_timer = 999.0
		next_elite = 9999.0
	if shot_mode == "pause":
		mains["ddakji"] = 3
		main_order.append("ddakji")
		supports["notebook"] = 1
		support_order.append("notebook")
		_refresh_slots()
		call_deferred("_pause_menu")
	if shot_mode == "settings":
		call_deferred("_open_settings")
	if OS.get_cmdline_user_args().has("--overview"):
		cam_off = Vector3(0, 22, 18) if stage != "hall" else Vector3(0, 14, 12)
		cam.position = player.position + cam_off
		if tut_node:
			tut_node.visible = false
	if shot_mode == "tut":
		elapsed = 0.0
		for e in enemies:
			e["hp"] = 0.0
		enemies.clear()
		call_deferred("_make_move_tut")
	if shot_mode == "ind":
		enemies.clear()
		var el := _make_enemy("kettle", Vector3(11, 0, -11), true)
		el["speed"] = 0.0
		_drop("gacha", Vector3(-10, 0, 9))
		_drop("chest", Vector3(9, 0, 9))
	if shot_mode == "end":
		kills = 1234
		elapsed = 187.0
		run_coins = 96
		evolved["gun"] = true
		_end_game(false)
	if shot_mode == "sup":
		for id in ["bottle", "notebook", "watch", "sneakers", "magnifier", "pencil", "nametag"]:
			support_order.append(id)
			supports[id] = 3
		sup_t = {"bottle": 1.2, "watch": 1.0, "magnifier": 0.2, "sneakers": 0.0}
		shield_t = 99.0
		_refresh_ui()
		_refresh_slots()
	if shot_mode.begins_with("pat_"):
		boss_spawned = true
		boss = _make_enemy("boss", Vector3(0, 0, -4))
		boss["pat"] = shot_mode.substr(4)
		boss["pat_t"] = 0.3
		enemies = [boss]   # 패턴만 잘 보이게 다른 귀신은 치워요
		boss["stage"] = 0
		boss["speed"] = 0.0
	if shot_mode == "mission" or shot_mode == "mission_in":
		while true:
			_start_mission()
			if mission["kind"] == "zone":
				break
			_end_mission(false)
		if shot_mode == "mission_in":
			player.position = mission["pos"] + Vector3(0.6, 0, 0.3)
			mission["prog"] = 1.5
		else:
			player.position = mission["pos"] + Vector3(0, 0, 3.4)
		for e in enemies:
			e["pos"] = mission["pos"] + ((e["pos"] as Vector3) - mission["pos"]).normalized() * 7.0
			e["elite"] = false
	if shot_mode == "chest":
		mains["ddakji"] = 2
		main_order.append("ddakji")
		supports["bottle"] = 1
		support_order.append("bottle")
		Save.data["shop"]["luck"] = 3
		rng.seed = 3
		_open_chest()
