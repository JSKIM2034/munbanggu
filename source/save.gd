extends Node
# 판과 판 사이에 남는 모든 것: 동전, 문방구 상점, 친구, 클리어 기록, 도장(업적), 오늘의 숙제, 귀신 도감

const PATH := "user://save.json"

var data := {}
var mode := "menu"                     # "menu" 또는 "run"
var run_cfg := {"stage": "ground", "grade": 1}
var last_result := {}                   # 방금 끝난 판 (메뉴에서 보여줘요)

const STAGES := {
	"ground": {"name": "운동장", "desc": "넓은 흙 운동장. 사방에서 귀신이 몰려와요.", "boss": "분실물함 대왕귀신", "need": "", "col": "#e8b77a"},
	"hall": {"name": "학교 복도", "desc": "길고 좁은 복도! 양쪽 끝에서 귀신이 밀려와요.", "boss": "청소함 대왕귀신", "need": "ground", "col": "#8fd1a8"},
	"lab": {"name": "밤의 과학실", "desc": "불 꺼진 과학실. 손전등 불빛만 믿어야 해요.", "boss": "인체모형 대왕귀신", "need": "hall", "col": "#6f7fd8"},
	"toilet": {"name": "화장실", "desc": "칸막이 사이 좁은 길! 휴지 귀신의 본거지예요.", "boss": "변기 대왕귀신", "need": "lab", "col": "#7fc8e8"},
	"roof": {"name": "옥상", "desc": "바람이 세게 불어요. 난간 밖으로 밀려난 귀신은 떨어져요.", "boss": "물탱크 대왕귀신", "need": "toilet", "col": "#f2a65a"},
	"music": {"name": "음악실", "desc": "쿵짝쿵짝! 박자마다 철수 주변에 충격파가 퍼져요.", "boss": "피아노 대왕귀신", "need": "roof", "col": "#c98ef0"},
}
const STAGE_ORDER := ["ground", "hall", "lab", "toilet", "roof", "music"]

# 특별한 날: 날짜마다 바뀌어요
const DAY_MODS := {
	"normal": {"name": "평범한 날", "desc": "오늘은 별일 없어요.", "col": "#b9b0bf"},
	"rain": {"name": "비 오는 날", "desc": "물웅덩이에서 미끄러져요. 귀신도 느려져요. 동전 +20%", "col": "#58a6e8"},
	"sports": {"name": "운동회 날", "desc": "모두 빨라져요! 계주 귀신이 달려와요. 동전 +20%", "col": "#ff9a2f"},
	"exam": {"name": "시험 기간", "desc": "보스가 1분 일찍 와요. 대신 경험치 +30%", "col": "#e8524a"},
	"vacation": {"name": "방학", "desc": "밤의 학교! 손전등으로 버텨요. 동전 +30%", "col": "#4a4fa8"},
}
const MAX_GRADE := 99

const CHARS := {
	"chulsoo": {"name": "철수", "weapon": "gun", "perk": "물총 피해 +10%", "unlock": "", "col": "#4fa8e8", "icon": "철", "power": 1.0, "price": 0},
	"younghee": {"name": "영희", "weapon": "ddakji", "perk": "치명타 확률 +8%", "unlock": "kills500", "col": "#ff7aa8", "icon": "영", "power": 1.2, "price": 900},
	"minsu": {"name": "민수", "weapon": "yoyo", "perk": "경험치 +15%", "unlock": "evo1", "col": "#2fc79a", "icon": "민", "power": 1.4, "price": 1800},
	"sunja": {"name": "순자", "weapon": "rubber", "perk": "최대 하트 +2", "unlock": "clear_ground", "col": "#ff9a2f", "icon": "순", "power": 1.6, "price": 3000},
}
const CHAR_ORDER := ["chulsoo", "younghee", "minsu", "sunja"]

const SHOP := [
	{"id": "w_gun", "name": "물총 강화", "icon": "물", "desc": "물총 피해 +12%, 연사 +4%", "base": 50, "col": "#4fa8e8"},
	{"id": "w_ddakji", "name": "딱지 강화", "icon": "딱", "desc": "딱지 피해 +12%, 회전 +4%", "base": 50, "col": "#ff7aa8"},
	{"id": "w_yoyo", "name": "요요 강화", "icon": "요", "desc": "요요 피해 +12%, 대기 -4%", "base": 50, "col": "#2fc79a"},
	{"id": "w_plane", "name": "종이비행기 강화", "icon": "비", "desc": "비행기 피해 +12%, 대기 -4%", "base": 60, "col": "#7fa8ff"},
	{"id": "w_pop", "name": "콩알탄 강화", "icon": "콩", "desc": "콩알탄 피해 +12%, 대기 -4%", "base": 60, "col": "#ff5c5c"},
	{"id": "w_rubber", "name": "고무줄 강화", "icon": "줄", "desc": "고무줄 피해 +12%, 대기 -4%", "base": 50, "col": "#ff9a2f"},
	{"id": "dmg", "name": "힘센 손", "icon": "힘", "desc": "모든 피해 +8%", "base": 30, "col": "#ff7a6b"},
	{"id": "hp", "name": "튼튼 우유", "icon": "우", "desc": "최대 하트 +1", "base": 60, "max": 10, "col": "#ff5c7a"},
	{"id": "speed", "name": "빠른 발", "icon": "발", "desc": "이동 속도 +5%", "base": 40, "col": "#f2c230"},
	{"id": "magnet", "name": "큰 자석", "icon": "석", "desc": "딱지 줍는 거리 +15%", "base": 30, "col": "#9b8cff"},
	{"id": "xp", "name": "예습 공책", "icon": "예", "desc": "경험치 +6%", "base": 60, "col": "#6ee0b0"},
	{"id": "luck", "name": "행운 부적", "icon": "운", "desc": "치명타 +3%, 상자에서 더 많이", "base": 80, "max": 15, "col": "#ffd23f"},
	{"id": "coin", "name": "용돈", "icon": "돈", "desc": "동전 +10%", "base": 50, "col": "#e8a93a"},
	{"id": "reroll", "name": "다시 뽑기권", "icon": "뽑", "desc": "판마다 카드 다시 뽑기 +1번", "base": 100, "max": 5, "col": "#58c6f2"},
	{"id": "revive", "name": "오뚝이", "icon": "뚝", "desc": "판마다 1번 되살아나요", "base": 600, "max": 3, "col": "#c9a8f0"},
]

const ACH := [
	{"id": "kills100", "name": "첫 퇴마", "desc": "귀신 100마리 물리치기", "stat": "total_kills", "goal": 100, "reward": 50},
	{"id": "kills500", "name": "동네 퇴마사", "desc": "귀신 500마리 (영희가 친구가 돼요)", "stat": "total_kills", "goal": 500, "reward": 120},
	{"id": "kills3000", "name": "학교 퇴마왕", "desc": "귀신 3,000마리", "stat": "total_kills", "goal": 3000, "reward": 400},
	{"id": "kills20000", "name": "전설의 퇴마단", "desc": "귀신 20,000마리", "stat": "total_kills", "goal": 20000, "reward": 1500},
	{"id": "evo1", "name": "첫 진화", "desc": "진화 1번 (민수가 친구가 돼요)", "stat": "evos_total", "goal": 1, "reward": 100},
	{"id": "evo2run", "name": "쌍둥이 진화", "desc": "한 판에 진화 2개", "stat": "max_evos_run", "goal": 2, "reward": 250},
	{"id": "evo4run", "name": "완전 진화", "desc": "한 판에 진화 4개 모두", "stat": "max_evos_run", "goal": 4, "reward": 800},
	{"id": "elite20", "name": "반짝이 사냥꾼", "desc": "정예 귀신 20마리", "stat": "elite_kills", "goal": 20, "reward": 150},
	{"id": "combo100", "name": "백 콤보", "desc": "100 콤보 달성", "stat": "best_combo", "goal": 100, "reward": 150},
	{"id": "nohit120", "name": "털끝 하나 안 다침", "desc": "2분 동안 한 대도 안 맞기", "stat": "best_nohit", "goal": 120, "reward": 200},
	{"id": "clear_ground", "name": "운동장 수호자", "desc": "운동장 보스 물리치기 (순자가 친구가 돼요)", "stat": "clear_ground", "goal": 1, "reward": 200},
	{"id": "clear_hall", "name": "복도 수호자", "desc": "복도 보스 물리치기", "stat": "clear_hall", "goal": 1, "reward": 300},
	{"id": "clear_lab", "name": "과학실 수호자", "desc": "과학실 보스 물리치기", "stat": "clear_lab", "goal": 1, "reward": 500},
	{"id": "grade3", "name": "3단계 돌파", "desc": "아무 곳이나 3단계 클리어", "stat": "best_grade", "goal": 3, "reward": 300},
	{"id": "grade6", "name": "졸업!", "desc": "아무 곳이나 6단계 클리어", "stat": "best_grade", "goal": 6, "reward": 1500},
	{"id": "clear_toilet", "name": "화장실 수호자", "desc": "화장실 보스 물리치기", "stat": "clear_toilet", "goal": 1, "reward": 700},
	{"id": "clear_roof", "name": "옥상 수호자", "desc": "옥상 보스 물리치기", "stat": "clear_roof", "goal": 1, "reward": 900},
	{"id": "clear_music", "name": "음악실 수호자", "desc": "음악실 보스 물리치기", "stat": "clear_music", "goal": 1, "reward": 1200},
	{"id": "weekly1", "name": "도전자", "desc": "주간 도전 참가하기", "stat": "weekly_runs", "goal": 1, "reward": 100},
	{"id": "gacha5", "name": "뽑기 중독", "desc": "문방구 뽑기통 5번 돌리기", "stat": "gacha_total", "goal": 5, "reward": 150},
	{"id": "grade10", "name": "중학생 퇴마사", "desc": "아무 곳이나 10단계 클리어", "stat": "best_grade", "goal": 10, "reward": 3000},
	{"id": "grade20", "name": "고등학생 퇴마사", "desc": "아무 곳이나 20단계 클리어", "stat": "best_grade", "goal": 20, "reward": 8000},
	{"id": "grade50", "name": "전설의 선생님", "desc": "아무 곳이나 50단계 클리어", "stat": "best_grade", "goal": 50, "reward": 30000},
	{"id": "friends4", "name": "퇴마단 결성", "desc": "친구 4명 모두 모으기", "stat": "friends", "goal": 4, "reward": 500},
]

const DAILY_POOL := [
	{"id": "kills", "desc": "귀신 400마리 물리치기", "goal": 400},
	{"id": "elites", "desc": "정예 귀신 3마리 물리치기", "goal": 3},
	{"id": "evos", "desc": "진화 1번 하기", "goal": 1},
	{"id": "gems", "desc": "딱지 600개 줍기", "goal": 600},
	{"id": "boss", "desc": "보스 1번 물리치기", "goal": 1},
	{"id": "runs", "desc": "3판 하기", "goal": 3},
	{"id": "coins", "desc": "동전 150개 모으기", "goal": 150},
	{"id": "chests", "desc": "보물 상자 2개 열기", "goal": 2},
]
const DAILY_REWARD := 80
const DAILY_BONUS := 100

const BESTIARY := {
	"paper": {"name": "휴지 귀신", "desc": "화장실 마지막 칸에 살아요. 휴지를 다 쓰면 나타난대요."},
	"egg": {"name": "달걀 귀신", "desc": "얼굴이 없다더니 사실 있어요. 엄청 빨라요."},
	"kettle": {"name": "주전자 귀신", "desc": "운동회 날 잃어버린 노란 주전자. 뜨겁고 단단해요."},
	"eraser": {"name": "지우개 귀신", "desc": "칠판지우개. 부르르 떨다가 쌩 돌진하니 조심!"},
	"dust": {"name": "먼지 뭉치", "desc": "마룻바닥 틈에서 떼로 몰려나와요."},
	"report": {"name": "성적표 귀신", "desc": "빨간 줄 가득한 성적표. 엉엉 울면서 지그재그로 다가와요."},
	"relay": {"name": "계주 귀신", "desc": "운동회 날에만 나타나는 빨간 머리띠 귀신. 엄청 빨라요."},
	"boss": {"name": "대왕귀신", "desc": "아무도 찾아가지 않은 물건들이 모여 생긴 왕 귀신."},
}

func _ready() -> void:
	load_data()

func _default() -> Dictionary:
	return {"coins": 0, "shop": {}, "char": "chulsoo", "clears": {}, "stats": {}, "ach_claimed": [],
		"bestiary": {}, "daily": {}, "best": {}, "runs": 0, "seen_unlock": [], "tut": {},
		"opt": {"bgm": true, "sfx": true, "vib": true, "shake": true, "nums": true, "fx": true}}

func opt(key: String) -> bool:
	return bool(data["opt"].get(key, true))

func set_opt(key: String, v: bool) -> void:
	data["opt"][key] = v
	save_data()

func tut_seen(key: String) -> bool:
	return data["tut"].get(key, false)

func tut_mark(key: String) -> void:
	data["tut"][key] = true
	save_data()

func affordable() -> Array:
	var out: Array = []
	for it in SHOP:
		var c := shop_cost(it["id"])
		if c >= 0 and int(data["coins"]) >= c:
			out.append(it)
	return out

func load_data() -> void:
	data = _default()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				data[k] = d[k]
	_refresh_daily()

func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

# ---------- 상점 ----------
func shop_lv(id: String) -> int:
	return int(data["shop"].get(id, 0))

func shop_item(id: String) -> Dictionary:
	for s in SHOP:
		if s["id"] == id:
			return s
	return {}

func shop_max(id: String) -> int:
	return int(shop_item(id).get("max", -1))

func shop_cost(id: String) -> int:
	var s := shop_item(id)
	var l := shop_lv(id)
	var mx := shop_max(id)
	if mx >= 0 and l >= mx:
		return -1
	# 강화할수록 조금씩 비싸져요 (끝은 없어요)
	return int(round(float(s["base"]) * pow(1.28, l) + l * 10))

func buy(id: String) -> bool:
	var c := shop_cost(id)
	if c < 0 or data["coins"] < c:
		return false
	data["coins"] -= c
	data["shop"][id] = shop_lv(id) + 1
	save_data()
	return true

# ---------- 기록 값 ----------
func stat(key: String) -> int:
	match key:
		"clear_ground", "clear_hall", "clear_lab", "clear_toilet", "clear_roof", "clear_music":
			return 1 if int(data["clears"].get(key.substr(6), 0)) > 0 else 0
		"best_grade":
			var m := 0
			for k in data["clears"]:
				m = maxi(m, int(data["clears"][k]))
			return m
		"friends":
			var n := 0
			for c in CHAR_ORDER:
				if char_unlocked(c):
					n += 1
			return n
	return int(data["stats"].get(key, 0))

func ach_by_id(id: String) -> Dictionary:
	for a in ACH:
		if a["id"] == id:
			return a
	return {}

func ach_done(a: Dictionary) -> bool:
	return stat(a["stat"]) >= int(a["goal"])

func ach_claimable() -> int:
	var n := 0
	for a in ACH:
		if ach_done(a) and not data["ach_claimed"].has(a["id"]):
			n += 1
	return n

func claim_ach(id: String) -> int:
	var a := ach_by_id(id)
	if a.is_empty() or not ach_done(a) or data["ach_claimed"].has(id):
		return 0
	data["ach_claimed"].append(id)
	data["coins"] += int(a["reward"])
	save_data()
	return int(a["reward"])

func char_unlocked(id: String) -> bool:
	var u: String = CHARS[id]["unlock"]
	if u == "" or data.get("bought_chars", []).has(id):
		return true
	return ach_done(ach_by_id(u))

func buy_char(id: String) -> bool:
	var price: int = CHARS[id]["price"]
	if char_unlocked(id) or int(data["coins"]) < price:
		return false
	data["coins"] -= price
	if not data.has("bought_chars"):
		data["bought_chars"] = []
	data["bought_chars"].append(id)
	save_data()
	return true

func stage_unlocked(id: String) -> bool:
	var need: String = STAGES[id]["need"]
	return need == "" or int(data["clears"].get(need, 0)) > 0

func max_grade(id: String) -> int:
	return mini(MAX_GRADE, int(data["clears"].get(id, 0)) + 1)

# ---------- 특별한 날 ----------
func today_mod() -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(_today() + "mod")
	var roll := r.randf()
	if roll < 0.3:
		return "normal"
	return ["rain", "sports", "exam", "vacation"][int((roll - 0.3) / 0.7 * 4.0) % 4]

# ---------- 주간 도전 ----------
func week_id() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0 + 3.0) / 7    # 월요일마다 바뀌어요

func weekly_cfg() -> Dictionary:
	var w := week_id()
	var r := RandomNumberGenerator.new()
	r.seed = w * 7919
	var mods := ["rain", "sports", "exam", "vacation"]
	return {"stage": ["ground", "hall", "lab"][r.randi() % 3], "char": CHAR_ORDER[r.randi() % 4],
		"mod": mods[r.randi() % 4], "grade": 2, "seed": w * 7919 + 13, "week": w}

func weekly_best() -> int:
	var wk: Dictionary = data.get("weekly", {})
	return int(wk.get("best", 0)) if int(wk.get("week", -1)) == week_id() else 0

# ---------- 오늘의 숙제 ----------
func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func _refresh_daily() -> void:
	var today := _today()
	if data["daily"].get("date", "") == today:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash(today)
	var ids: Array = []
	while ids.size() < 3:
		var q: String = DAILY_POOL[r.randi() % DAILY_POOL.size()]["id"]
		if not ids.has(q):
			ids.append(q)
	data["daily"] = {"date": today, "ids": ids, "prog": {}, "claimed": [], "bonus": false}
	save_data()

func daily_quest(id: String) -> Dictionary:
	for q in DAILY_POOL:
		if q["id"] == id:
			return q
	return {}

func daily_done(id: String) -> bool:
	return int(data["daily"]["prog"].get(id, 0)) >= int(daily_quest(id)["goal"])

func daily_claimable() -> int:
	_refresh_daily()
	var n := 0
	for id in data["daily"]["ids"]:
		if daily_done(id) and not data["daily"]["claimed"].has(id):
			n += 1
	if data["daily"]["claimed"].size() >= 3 and not data["daily"]["bonus"]:
		n += 1
	return n

func claim_daily(id: String) -> int:
	if id == "bonus":
		if data["daily"]["claimed"].size() >= 3 and not data["daily"]["bonus"]:
			data["daily"]["bonus"] = true
			data["coins"] += DAILY_BONUS
			save_data()
			return DAILY_BONUS
		return 0
	if daily_done(id) and not data["daily"]["claimed"].has(id):
		data["daily"]["claimed"].append(id)
		data["coins"] += DAILY_REWARD
		save_data()
		return DAILY_REWARD
	return 0

# ---------- 한 판 기록 ----------
func record_run(r: Dictionary) -> Dictionary:
	# r: stage, grade, win, kills, elites, evos, gems, coins, combo, nohit, time, chests, kinds{kind:n}
	_refresh_daily()
	var before_ach: Array = []
	for a in ACH:
		if ach_done(a):
			before_ach.append(a["id"])
	var before_chars: Array = []
	for c in CHAR_ORDER:
		if char_unlocked(c):
			before_chars.append(c)
	var before_stages: Array = []
	for s in STAGE_ORDER:
		if stage_unlocked(s):
			before_stages.append(s)
	var st: Dictionary = data["stats"]
	st["total_kills"] = int(st.get("total_kills", 0)) + int(r["kills"])
	st["evos_total"] = int(st.get("evos_total", 0)) + int(r["evos"])
	st["max_evos_run"] = maxi(int(st.get("max_evos_run", 0)), int(r["evos"]))
	st["elite_kills"] = int(st.get("elite_kills", 0)) + int(r["elites"])
	st["best_combo"] = maxi(int(st.get("best_combo", 0)), int(r["combo"]))
	st["best_nohit"] = maxi(int(st.get("best_nohit", 0)), int(r["nohit"]))
	st["gacha_total"] = int(st.get("gacha_total", 0)) + int(r.get("gacha", 0))
	var weekly_new := false
	if r.get("weekly", false):
		st["weekly_runs"] = int(st.get("weekly_runs", 0)) + 1
		var wk: Dictionary = data.get("weekly", {})
		if int(wk.get("week", -1)) != week_id():
			wk = {"week": week_id(), "best": 0}
		if int(r["score"]) > int(wk["best"]):
			wk["best"] = int(r["score"])
			weekly_new = true
		data["weekly"] = wk
	data["coins"] += int(r["coins"])
	data["runs"] = int(data["runs"]) + 1
	for k in r["kinds"]:
		data["bestiary"][k] = int(data["bestiary"].get(k, 0)) + int(r["kinds"][k])
	var new_grade := false
	if r["win"] and not r.get("weekly", false):
		var prev := int(data["clears"].get(r["stage"], 0))
		if int(r["grade"]) > prev:
			data["clears"][r["stage"]] = int(r["grade"])
			new_grade = true
	var bk: String = "%s_%d" % [r["stage"], r["grade"]]
	var best: Dictionary = data["best"].get(bk, {})
	if r.get("weekly", false):
		pass
	elif r["win"] and (best.is_empty() or not best.get("win", false) or float(r["time"]) < float(best.get("time", 9999))):
		data["best"][bk] = {"win": true, "time": r["time"], "kills": r["kills"]}
	elif best.is_empty() or (not best.get("win", false) and float(r["time"]) > float(best.get("time", 0))):
		data["best"][bk] = {"win": r["win"], "time": r["time"], "kills": r["kills"]}
	var dp: Dictionary = data["daily"]["prog"]
	for pair in [["kills", r["kills"]], ["elites", r["elites"]], ["evos", r["evos"]], ["gems", r["gems"]],
			["boss", 1 if r["win"] else 0], ["runs", 1], ["coins", r["coins"]], ["chests", r["chests"]]]:
		dp[pair[0]] = int(dp.get(pair[0], 0)) + int(pair[1])
	save_data()
	var news: Array = []
	for a in ACH:
		if ach_done(a) and not before_ach.has(a["id"]):
			news.append("도장: " + a["name"])
	for c in CHAR_ORDER:
		if char_unlocked(c) and not before_chars.has(c):
			news.append("새 친구: " + CHARS[c]["name"] + "!")
	for s in STAGE_ORDER:
		if stage_unlocked(s) and not before_stages.has(s):
			news.append("새 장소: " + STAGES[s]["name"] + "!")
	if new_grade and int(r["grade"]) < MAX_GRADE:
		news.append("%s %d단계가 열렸어요!" % [STAGES[r["stage"]]["name"], int(r["grade"]) + 1])
	if weekly_new:
		news.append("주간 도전 최고 기록!")
	return {"news": news}
