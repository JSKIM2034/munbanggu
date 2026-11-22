extends CanvasLayer
# 메인 메뉴: 홈, 놀러 가기(장소,학년), 문방구(영구 강화), 친구들, 도장 숙제, 귀신 도감

var main: Node3D
var root: Control
var screen := "home"
var sel := {}        # 장소 -> 고른 학년
var scroll_y := {}   # 화면별 스크롤 위치 기억

const CREAM := Color("#fff8e8")
const INK := Color("#3a2148")
const SUB := Color("#6b5a75")

func _ready() -> void:
	layer = 5
	var first := "home"
	for a in OS.get_cmdline_user_args():
		if a == "--rich":
			# 스크린샷용 가짜 진행도 (저장하지 않아요)
			Save.data["coins"] = 480
			Save.data["clears"] = {"ground": 6}
			Save.data["stats"] = {"total_kills": 650, "best_combo": 120, "elite_kills": 6}
			Save.data["shop"] = {"dmg": 2, "hp": 1}
			Save.data["bestiary"] = {"paper": 420, "egg": 180, "kettle": 30, "eraser": 20}
			Save.data["daily"]["prog"] = {Save.data["daily"]["ids"][0]: 9999}
		if a.begins_with("--mscreen="):
			first = a.substr(10)
	for s in Save.STAGE_ORDER:
		sel[s] = Save.max_grade(s)
	show_screen(first)

func show_screen(name: String) -> void:
	if root:
		var sc := root.find_child("Scroll", true, false)
		if sc:
			scroll_y[screen] = (sc as ScrollContainer).scroll_vertical
		root.queue_free()
	screen = name
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	match name:
		"home": _home()
		"stage": _stage()
		"shop": _shop()
		"friends": _friends()
		"ach": _ach()
		"book": _book()

# ---------- 작은 도구 ----------
func L(text: String, size: int, col: Color, parent: Node, outline := 0) -> Label:
	return main._label(text, size, col, parent, outline)

func B(text: String, col: Color, fs := 36) -> Button:
	var b: Button = main._small_btn(text, col, fs)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b

func _coins(parent: Control) -> void:
	var c := L(tr("동전 %d") % int(Save.data["coins"]), 40, Color("#ffd23f"), parent, 10)
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.offset_left = -360
	c.offset_right = -28
	c.offset_top = 30

func _dot(parent: Control, n: int) -> void:
	if n <= 0:
		return
	var d := Panel.new()
	d.add_theme_stylebox_override("panel", main._round_panel(Color("#ff4f4f"), 22, Color.WHITE, 4))
	d.size = Vector2(44, 44)
	d.position = Vector2(parent.custom_minimum_size.x - 34, -10)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	var l := L(str(n), 26, Color.WHITE, d, 0)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _page(title: String) -> VBoxContainer:
	# 공통 화면 틀: 크림색 판, 제목, 뒤로, 동전, 스크롤 목록
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.18, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var back := B(tr("< 뒤로"), Color("#8a7a95"), 32)
	back.position = Vector2(24, 24)
	back.size = Vector2(170, 76)
	root.add_child(back)
	back.pressed.connect(func():
		main._play("pick", 0.8, -4.0)
		show_screen("home"))
	_coins(root)
	var t := L(title, 60, Color.WHITE, root, 12)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 112
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 30
	sc.offset_right = -30
	sc.offset_top = 200
	sc.offset_bottom = -30
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	sc.add_child(vb)
	if scroll_y.has(screen):
		var y: int = scroll_y[screen]
		get_tree().create_timer(0.02).timeout.connect(func(): if is_instance_valid(sc): sc.scroll_vertical = y)
	return vb

func _row(parent: Control, h: float, border: Color, bg := CREAM) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", main._round_panel(bg, 26, border, 7))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	return p

func _right_btn(row: Panel, text: String, col: Color, enabled: bool, cb: Callable, w := 190.0) -> Button:
	var b := B(text, col, 30)
	main._fit(b, w - 30)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	b.offset_left = -w - 22
	b.offset_right = -22
	b.offset_top = -40
	b.offset_bottom = 40
	b.disabled = not enabled
	row.add_child(b)
	b.pressed.connect(cb)
	return b

# ---------- 홈 ----------
func _home() -> void:
	_coins(root)
	var sb := B(tr("설정"), Color("#8a7a95"), 30)
	sb.position = Vector2(24, 24)
	sb.size = Vector2(130, 72)
	root.add_child(sb)
	sb.pressed.connect(main._open_settings)
	if OS.has_feature("web") and not _standalone():
		var ib := B(tr("앱처럼 설치하기"), Color("#2fc79a"), 26)
		ib.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		ib.offset_left = -150
		ib.offset_right = 150
		ib.offset_top = 290
		ib.offset_bottom = 352
		root.add_child(ib)
		ib.pressed.connect(_install_help)
	var t := L(tr("문방구 퇴마단"), 96 if Save.lang() == "ko" else 66, Color("#ffdf3d"), root, 18)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 110
	t.pivot_offset = Vector2(360, 60)
	var tw := t.create_tween().set_loops()
	tw.tween_property(t, "rotation", 0.03, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "rotation", -0.03, 1.2).set_trans(Tween.TRANS_SINE)
	var st := L(tr("학교 귀신, 장난감으로 물리쳐라!"), 34, Color.WHITE, root, 10)
	st.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.offset_top = 230
	var ch: Dictionary = Save.CHARS[Save.data["char"]]
	var who := L(tr("%s - 시작 무기 %s") % [ch["name"], main.mains_def()[ch["weapon"]]["name"]], 32, Color.WHITE, root, 10)
	who.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.offset_left = -300
	who.offset_right = 300
	who.offset_top = -420
	who.offset_bottom = -370
	var go := B(tr("놀러 가기!"), Color("#ff9a2f"), 56)
	go.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	go.offset_left = -280
	go.offset_right = 280
	go.offset_top = -355
	go.offset_bottom = -225
	go.pivot_offset = Vector2(280, 65)
	root.add_child(go)
	var gt := go.create_tween().set_loops()
	gt.tween_property(go, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	gt.tween_property(go, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	go.pressed.connect(func():
		main._play("pick", 1.0, -3.0)
		show_screen("stage"))
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hb.offset_left = -340
	hb.offset_right = 340
	hb.offset_top = -195
	hb.offset_bottom = -60
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hb)
	var items := [[tr("문방구"), "shop", Color("#4fa8e8"), Save.affordable().size()], [tr("친구들"), "friends", Color("#ff7aa8"), 0],
		[tr("도장 숙제"), "ach", Color("#2fc79a"), Save.ach_claimable() + Save.daily_claimable()], [tr("도감"), "book", Color("#9b8cff"), 0]]
	for it in items:
		var b := B(it[0], it[2], 30)
		b.custom_minimum_size = Vector2(160, 120)
		hb.add_child(b)
		_dot(b, it[3])
		var dest: String = it[1]
		b.pressed.connect(func():
			main._play("pick", 1.0, -4.0)
			show_screen(dest))

func _standalone() -> bool:
	if not OS.has_feature("web"):
		return true
	var r = JavaScriptBridge.eval("(window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || window.navigator.standalone === true", true)
	return r == true

func _install_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.15, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var box_p := Panel.new()
	box_p.add_theme_stylebox_override("panel", main._round_panel(CREAM, 36, Color("#2fc79a"), 10))
	box_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box_p.offset_left = -310
	box_p.offset_right = 310
	box_p.offset_top = -380
	box_p.offset_bottom = 380
	layer.add_child(box_p)
	var t := L(tr("홈 화면에 설치하기"), 50, INK, box_p)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.offset_top = 34
	var body := L(tr("주소창 없이 꽉 찬 화면으로,\n다음부터 아이콘 한 번에 바로 시작해요.\n\n[아이폰 사파리]\n아래쪽 공유 버튼을 누르고\n'홈 화면에 추가'\n\n[안드로이드 크롬]\n오른쪽 위 점 세 개 메뉴에서\n'홈 화면에 추가' 또는 '앱 설치'"), 30, SUB, box_p)
	body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.offset_top = 120
	var ok := B(tr("알겠어요"), Color("#2fc79a"), 40)
	ok.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ok.offset_left = -150
	ok.offset_right = 150
	ok.offset_top = -130
	ok.offset_bottom = -40
	box_p.add_child(ok)
	ok.pressed.connect(layer.queue_free)

# ---------- 놀러 가기 ----------
func _stage() -> void:
	var vb := _page(tr("어디로 갈까?"))
	# 오늘의 특별한 날
	var mid := Save.today_mod()
	var md: Dictionary = Save.DAY_MODS[mid]
	var mrow := _row(vb, 130, Color(md["col"]))
	var ml := L(tr("오늘은 ") + md["name"], 40, INK, mrow)
	ml.position = Vector2(28, 14)
	main._fit(ml, 600)
	var mdl := L(md["desc"], 26, SUB, mrow)
	mdl.position = Vector2(28, 74)
	main._fit(mdl, 600)
	for sid in Save.STAGE_ORDER:
		var s: Dictionary = Save.STAGES[sid]
		var open := Save.stage_unlocked(sid)
		var row := _row(vb, 400, Color(s["col"]) if open else Color("#9b8aa5"), CREAM if open else Color("#e9e2ee"))
		var nm := L(s["name"] if open else s["name"] + tr("  (잠김)"), 50, INK, row)
		nm.position = Vector2(30, 22)
		main._fit(nm, 600)
		var ds := L(s["desc"], 28, SUB, row)
		ds.position = Vector2(30, 90)
		main._fit(ds, 600)
		var bl := L(tr("보스: ") + s["boss"], 26, Color("#c0506a"), row)
		bl.position = Vector2(30, 134)
		main._fit(bl, 425)
		if not open:
			var need: String = s["need"]
			var lk := L(tr("%s %d단계까지 깨면 열려요 (지금 %d단계)") % [Save.STAGES[need]["name"], Save.UNLOCK_GRADE, int(Save.data["clears"].get(need, 0))], 30, Color("#8a7a95"), row)
			lk.position = Vector2(30, 200)
			main._fit_box(lk, 600, 90)
			continue
		var mg := Save.max_grade(sid)
		var gl := L(tr("단계"), 30, INK, row)
		gl.position = Vector2(30, 196)
		main._fit(gl, 66)
		var ss: String = sid
		for pair in [[-10, "-10"], [-1, "-"], [1, "+"], [10, "+10"]]:
			var dv: int = pair[0]
			var gb := B(pair[1], Color("#8a7a95") if dv < 0 else Color("#ffb03f"), 32)
			var px: int = {-10: 100, -1: 196, 1: 400, 10: 480}[dv]
			gb.position = Vector2(px, 182)
			gb.size = Vector2(88 if absi(dv) == 10 else 72, 72)
			var nv: int = clampi(sel[sid] + dv, 1, mg)
			gb.disabled = nv == sel[sid]
			row.add_child(gb)
			gb.pressed.connect(func():
				sel[ss] = nv
				main._play("pick", 1.0 + minf(nv, 30) * 0.02, -5.0)
				show_screen("stage"))
		var gnum := L(tr("%d단계") % sel[sid], 44, Color("#e8524a"), row, 0)
		gnum.position = Vector2(282, 186)
		main._fit(gnum, 114)
		gnum.position.y = 186 + (44 - gnum.get_theme_font_size("font_size")) * 0.6
		var gmax := L(tr("(최고 %d)") % mg, 22, SUB, row)
		gmax.position = Vector2(574, 206)
		main._fit(gmax, 80)
		var wid := Save.weather_for(sid, sel[sid])
		var wl := L(Save.WEATHERS[wid]["name"], 26, Color(Save.WEATHERS[wid]["col"]).darkened(0.25), row)
		wl.position = Vector2(470, 134)
		main._fit(wl, 160)
		var bk: String = "%s_%d" % [sid, sel[sid]]
		var best: Dictionary = Save.data["best"].get(bk, {})
		var rec := tr("아직 기록이 없어요")
		if not best.is_empty():
			rec = (tr("클리어 %d:%02d") if best.get("win", false) else tr("최고 %d:%02d 버팀")) % [int(best["time"]) / 60, int(best["time"]) % 60]
		var g0: int = sel[sid] - 1
		var hint := tr("  |  귀신 체력 x%.1f  동전 x%.1f") % [(1.0 + 0.45 * g0 + 0.02 * g0 * g0), 1.0 + 0.35 * g0]
		var rl := L(rec + hint, 24, SUB, row)
		rl.position = Vector2(30, 268)
		main._fit(rl, 600)
		var go := B(tr("출발!"), Color("#ff9a2f"), 40)
		go.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		go.offset_left = -230
		go.offset_right = -24
		go.offset_top = -100
		go.offset_bottom = -20
		row.add_child(go)
		var sid2: String = sid
		go.pressed.connect(func():
			Save.run_cfg = {"stage": sid2, "grade": sel[sid2]}
			Save.mode = "run"
			get_tree().reload_current_scene())

	# 주간 도전 (운동장을 한 번 깨야 열려요)
	if not Save.stage_unlocked("hall"):
		var lrow := _row(vb, 120, Color("#c9bfd3"), Color("#e9e2ee"))
		var ll := L(tr("이번 주 도전 (운동장 보스를 물리치면 열려요)"), 30, Color("#8a7a95"), lrow)
		ll.position = Vector2(28, 40)
		main._fit(ll, 600)
		return
	var wc := Save.weekly_cfg()
	var wrow := _row(vb, 250, Color("#ffc928"), Color("#fff1b8"))
	var wl := L(tr("이번 주 도전 (특별 규칙)"), 40, INK, wrow)
	wl.position = Vector2(28, 16)
	main._fit(wl, 600)
	var wd := L(tr("%s 2단계, %s를 빌려서, %s\n모두 같은 조건! 점수를 단톡방에 자랑해요") % [Save.STAGES[wc["stage"]]["name"], Save.CHARS[wc["char"]]["name"], Save.DAY_MODS[wc["mod"]]["name"]], 26, SUB, wrow)
	wd.position = Vector2(28, 76)
	main._fit(wd, 600)
	var wb := L(tr("이번 주 최고 점수 %d") % Save.weekly_best(), 28, Color("#d08a00"), wrow)
	wb.position = Vector2(28, 160)
	main._fit(wb, 380)
	var wgo := B(tr("도전!"), Color("#e8524a"), 40)
	wgo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	wgo.offset_left = -210
	wgo.offset_right = -24
	wgo.offset_top = -100
	wgo.offset_bottom = -20
	wrow.add_child(wgo)
	wgo.pressed.connect(func():
		Save.run_cfg = {"stage": wc["stage"], "grade": wc["grade"], "weekly": true}
		Save.mode = "run"
		get_tree().reload_current_scene())

# ---------- 문방구 ----------
func _shop() -> void:
	var vb := _page(tr("문방구 진열대"))
	var tip := L(tr("판에서 모은 동전으로 영원히 강해져요"), 28, Color.WHITE, vb, 8)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for it in Save.SHOP:
		var id: String = it["id"]
		var lvl := Save.shop_lv(id)
		var mx := Save.shop_max(id)
		var row := _row(vb, 170, Color(it["col"]))
		main._badge(row, it["icon"], Color(it["col"]), 110, Vector2(22, 30))
		var nm := L(it["name"], 40, INK, row)
		nm.position = Vector2(150, 22)
		main._fit(nm, 290)
		var pips := (tr("강화 +%d") % lvl) + (" / %d" % mx if mx >= 0 else "")
		var lv := L(pips, 28, Color("#ff8a2f") if lvl > 0 else Color("#b9b0bf"), row)
		lv.position = Vector2(150, 72)
		main._fit(lv, 290)
		var ds := L(it["desc"], 24, SUB, row)
		ds.position = Vector2(150, 108)
		main._fit_box(ds, 290, 56)
		var cost := Save.shop_cost(id)
		if cost < 0:
			_right_btn(row, tr("다 샀어요"), Color("#b9b0bf"), false, func(): pass)
		else:
			var buy_cb := func():
				if Save.buy(id):
					main._play("coin", 1.0, -2.0)
					main._play("level", 1.2, -6.0)
					show_screen("shop")
			_right_btn(row, tr("동전 %d") % cost, Color("#ffb03f"), int(Save.data["coins"]) >= cost, buy_cb)

# ---------- 친구들 ----------
func _friends() -> void:
	var vb := _page(tr("퇴마단 친구들"))
	var tip := L(tr("단계를 깰수록 힘센 친구가 와요!"), 28, Color.WHITE, vb, 8)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for cid in Save.CHAR_ORDER:
		var c: Dictionary = Save.CHARS[cid]
		var open := Save.char_unlocked(cid)
		var row := _row(vb, 220, Color(c["col"]) if open else Color("#9b8aa5"), CREAM if open else Color("#e9e2ee"))
		main._badge(row, c["icon"] if open else "?", Color(c["col"]) if open else Color("#9b8aa5"), 130, Vector2(22, 34))
		var nm := L(c["name"], 46, INK, row)
		nm.position = Vector2(175, 22)
		main._fit(nm, 280 if open else 170)
		var wp := L(tr("시작 무기: ") + main.mains_def()[c["weapon"]]["name"], 28, SUB, row)
		wp.position = Vector2(175, 86)
		main._fit(wp, 280 if open else 450)
		var pk := L(tr("특기: ") + c["perk"], 28, Color("#d08a00"), row)
		pk.position = Vector2(175, 128)
		main._fit(pk, 280 if open else 450)
		var pw := L(tr("기본 피해 x%.1f") % float(c["power"]), 26, Color("#e8524a"), row)
		pw.position = Vector2(175, 166)
		if not open:
			var nd: Array = c["need"]
			var lk := L(tr("%s\n(지금 %d단계)") % [Save.char_need_text(cid), int(Save.data["clears"].get(nd[0], 0))], 24, Color("#8a7a95"), row)
			lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lk.offset_left = -330
			lk.offset_right = -24
			lk.offset_top = 14
			lk.offset_bottom = 110
			main._fit_box(lk, 306, 96)
		elif Save.data["char"] == cid:
			_right_btn(row, tr("함께해요"), Color("#2fc79a"), false, func(): pass, 170)
		else:
			var ccid: String = cid
			var pick_cb := func():
				Save.data["char"] = ccid
				Save.save_data()
				main.set_character(ccid)
				main._play("pick", 1.2, -3.0)
				show_screen("friends")
			_right_btn(row, tr("고르기"), Color("#4fa8e8"), true, pick_cb, 170)

# ---------- 도장 숙제 ----------
func _ach() -> void:
	var vb := _page(tr("도장 숙제"))
	var h1 := L(tr("오늘의 숙제 (매일 바뀌어요)"), 36, Color.WHITE, vb, 9)
	for qid in Save.data["daily"]["ids"]:
		var q := Save.daily_quest(qid)
		var prog := mini(int(Save.data["daily"]["prog"].get(qid, 0)), int(q["goal"]))
		var row := _row(vb, 130, Color("#2fc79a"))
		var nm := L(q["desc"], 34, INK, row)
		nm.position = Vector2(28, 18)
		main._fit(nm, 440)
		var pl := L(tr("%d / %d   |  동전 %d") % [prog, int(q["goal"]), Save.DAILY_REWARD], 26, SUB, row)
		pl.position = Vector2(28, 74)
		main._fit(pl, 440)
		var claimed: bool = Save.data["daily"]["claimed"].has(qid)
		var q2: String = qid
		var qcb := func():
			Save.claim_daily(q2)
			main._play("coin", 1.0, -2.0)
			show_screen("ach")
		_right_btn(row, tr("받았어요") if claimed else tr("받기"), Color("#2fc79a"), Save.daily_done(qid) and not claimed, qcb, 160)
	var brow := _row(vb, 110, Color("#ffb03f"))
	var bn := L(tr("숙제 3개 다 하면 보너스 동전 %d") % Save.DAILY_BONUS, 30, INK, brow)
	bn.position = Vector2(28, 34)
	main._fit(bn, 440)
	var bdone: bool = Save.data["daily"]["bonus"]
	var bcb := func():
		Save.claim_daily("bonus")
		main._play("coin", 1.0, -2.0)
		show_screen("ach")
	_right_btn(brow, tr("받았어요") if bdone else tr("받기"), Color("#ffb03f"), Save.data["daily"]["claimed"].size() >= 3 and not bdone, bcb, 160)
	var h2 := L(tr("도장 모으기"), 36, Color.WHITE, vb, 9)
	for a in Save.ACH:
		var done := Save.ach_done(a)
		var claimed: bool = Save.data["ach_claimed"].has(a["id"])
		var row := _row(vb, 140, Color("#ff7aa8") if done else Color("#c9bfd3"), CREAM if done or claimed else Color("#f3eef6"))
		var nm := L((tr("[도장] ") if claimed else "") + a["name"], 36, INK, row)
		nm.position = Vector2(28, 16)
		main._fit(nm, 440)
		var cur := mini(Save.stat(a["stat"]), int(a["goal"]))
		var ds := L(tr("%s  (%d/%d)  동전 %d") % [a["desc"], cur, int(a["goal"]), int(a["reward"])], 24, SUB, row)
		ds.position = Vector2(28, 76)
		main._fit(ds, 440)
		ds.size = Vector2(450, 40)
		ds.clip_text = true
		var aid: String = a["id"]
		var acb := func():
			Save.claim_ach(aid)
			main._play("coin", 1.0, -2.0)
			main._play("level", 1.0, -6.0)
			show_screen("ach")
		_right_btn(row, tr("받았어요") if claimed else tr("받기"), Color("#ff7aa8"), done and not claimed, acb, 160)

# ---------- 귀신 도감 ----------
func _book() -> void:
	var vb := _page(tr("도감"))
	var total := 0
	for k in Save.BESTIARY:
		if int(Save.data["bestiary"].get(k, 0)) > 0:
			total += 1
	var sh := L(tr("세트 진화표"), 36, Color.WHITE, vb, 9)
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var md: Dictionary = main.mains_def()
	var sd: Dictionary = main.supports_def()
	for id in md:
		var d: Dictionary = md[id]
		var row := _row(vb, 150, Color(d["col"]))
		main._badge(row, d["icon"], Color(d["col"]), 100, Vector2(22, 25))
		var nm := L("%s Lv.5 + %s" % [d["name"], sd[d["partner"]]["name"]], 34, INK, row)
		nm.position = Vector2(140, 16)
		main._fit(nm, 490)
		var ev := L("= " + d["evo"], 32, Color("#d08a00"), row)
		ev.position = Vector2(140, 62)
		main._fit(ev, 490)
		var ds := L(d["evo_desc"], 22, SUB, row)
		ds.position = Vector2(140, 104)
		main._fit_box(ds, 490, 40)
	var tip := L(tr("만난 귀신 %d / %d") % [total, Save.BESTIARY.size()], 30, Color.WHITE, vb, 8)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for k in Save.BESTIARY:
		var b: Dictionary = Save.BESTIARY[k]
		var n := int(Save.data["bestiary"].get(k, 0))
		var seen := n > 0
		var col := Color(main.kinds_def()[k]["col"])
		var row := _row(vb, 170, col if seen else Color("#c9bfd3"), CREAM if seen else Color("#e9e2ee"))
		main._badge(row, b["name"].substr(0, 1) if seen else "?", col if seen else Color("#9b8aa5"), 110, Vector2(22, 30))
		var nm := L(b["name"] if seen else "???", 40, INK, row)
		nm.position = Vector2(150, 18)
		var cnt := L(tr("%d마리 물리침") % n if seen else tr("아직 못 만났어요"), 26, Color("#d08a00"), row)
		cnt.position = Vector2(150, 72)
		var ds := L(b["desc"] if seen else "", 24, SUB, row)
		ds.position = Vector2(150, 108)
		main._fit_box(ds, 480, 56)
