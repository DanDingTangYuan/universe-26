# ==============================================================================
# 26號宇宙 (Universe 26) - NPC 數據模型 (NPC Data Model)
# 檔案路徑: res://scripts/entities/npc_data.gd
# 職責描述: 
#   1. 封裝 NPC 個體 15 維度特徵向量 (對齊神經網路輸入與 Google 設計規格表)
#   2. 管理生理/心理屬性隨時間之自然衰減與恢復 (代謝模擬)
#   3. 管理物品庫存、修飾器 (Modifiers)、好感度/信任度關係網
#   4. 支援數據序列化 (Dictionary / JSON) 與特徵向量導出 (PackedFloat32Array)
# ==============================================================================
class_name NPCData
extends Resource

# ------------------------------------------------------------------------------
# 1. 訊號 (Signals)
# ------------------------------------------------------------------------------

## 數值大幅變動或定期刷新時發射
signal stats_changed(npc_id: String)

## 生命值歸零時發射 (死亡或瀕死)
signal hp_depleted(npc_id: String)

## 飽食度過低警戒時發射 (< 20.0)
signal hunger_critical(npc_id: String)

## 體力耗盡時發射 (< 10.0)
signal stamina_depleted(npc_id: String)

## 物品數量增加時發射
signal item_acquired(npc_id: String, item_type: String, amount: int)

## 物品消耗時發射
signal item_consumed(npc_id: String, item_type: String, amount: int)

## 與其他 NPC 的好感度/信任度變更時發射
signal relationship_changed(source_id: String, target_id: String, new_friendship: float, new_trust: float)

# ------------------------------------------------------------------------------
# 2. 常數與代謝係數 (Constants & Tuning Parameters)
# ------------------------------------------------------------------------------

# 屬性上下限
const MIN_STAT: float = 0.0
const MAX_STAT: float = 100.0
const MAX_ITEM_COUNT: int = 9999

# 每 Tick (1 遊戲分鐘) 自然代謝係數 (1 遊戲日 = 1440 Ticks)
const HUNGER_DECAY_PER_TICK: float = 0.03 # 平緩飽食消耗 (每天約 43 點，吃 1~2 餐即可維持整天充沛)
const STAMINA_DECAY_IDLE: float = 0.015 # 平常活動輕微消耗 (每天約 21 點)
const STAMINA_DECAY_WORK: float = 0.04 # 工作時穩定消耗 (工作一整天約 30 點)
const STAMINA_RECOVERY_SLEEP: float = 0.35 # 睡眠時高效率恢復 (睡 4~5 小時即可回滿體力)
const SOCIAL_DECAY_PER_TICK: float = 0.025 # 社交渴望平緩消耗
const MOOD_DECAY_PER_TICK: float = 0.015 # 心情緩慢向平衡點靠攏

# 15 維度特徵欄位名稱 (嚴格對照 npc_normalization.json)
const FEATURE_NAMES: Array[String] = [
	"生命值", # 0: hp
	"健康度", # 1: health
	"體力", # 2: stamina
	"飽食度", # 3: hunger
	"社交慾望", # 4: social_desire
	"心情", # 5: mood
	"職業編號", # 6: job_id
	"持有金錢", # 7: money
	"持有木頭", # 8: wood
	"持有石頭", # 9: stone
	"持有礦物", # 10: mineral
	"持有農作物", # 11: crops
	"持有魚", # 12: fish
	"持有料理", # 13: food
	"持有便當" # 14: lunchbox
]

# ------------------------------------------------------------------------------
# 3. 核心身份與基本資訊 (Identity)
# ------------------------------------------------------------------------------

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var avatar_texture_path: String = ""
@export var home_poi_id: int = 1
@export var work_poi_id: int = 0

# ------------------------------------------------------------------------------
# 4. 15 維度基礎生理與經濟數值 (The 15 Neural Features)
# ------------------------------------------------------------------------------

## 是否處於體力耗盡休養狀態 (遲滯保護：低於 25 進入，回滿至 75 方才解除)
@export var is_exhausted: bool = false

# 生理與心理指標 (0.0 ~ 100.0)
@export var hp: float = 100.0
@export var health: float = 100.0
@export var stamina: float = 100.0:
	set(val):
		stamina = clampf(val, MIN_STAT, MAX_STAT)
		if stamina < 25.0:
			is_exhausted = true
		elif stamina >= 75.0:
			is_exhausted = false
@export var hunger: float = 100.0
@export var social_desire: float = 50.0
@export var mood: float = 80.0

# 身份 (1 ~ 9)
@export var job_id: int = 1

# 持有金錢與資產物資 (0 ~ 9999)
@export var money: int = 100
@export var wood: int = 0
@export var stone: int = 0
@export var mineral: int = 0
@export var crops: int = 0
@export var fish: int = 0
@export var food: int = 0
@export var lunchbox: int = 0

# ------------------------------------------------------------------------------
# 5. 擴充模組：好感度、修飾器與個性詞條 (Modifiers & Memories)
# ------------------------------------------------------------------------------

## 與其他 NPC 之好感度字典 { "npc_2": 65.0, "npc_3": 40.0 }，預設 50.0
@export var friendships: Dictionary = {}

## 與其他 NPC 之信任度字典 { "npc_2": 50.0 }，預設 50.0
@export var trust: Dictionary = {}

## 短期記憶 (STM - Short-Term Memory)：單日重大生活事件清單 (最多保留 5 筆)
@export var stm_events: Array[String] = []

## 記憶與互動天數追蹤 { "npc_01": 0 } (記錄上次與各 NPC 互動之遊戲天數)
@export var last_interaction_days: Dictionary = {}

## 長期性格特質 (LTM - Long-Term Memory)：靈魂性格標籤
@export var ltm_traits: Array[String] = []

## 12 大性格特質中文名稱對照表 (對齊 SQLite LTM 資料表)
const LTM_TRAIT_NAMES: Dictionary = {
	"medicine_jar": "藥罐子",
	"healthy": "健康強健",
	"greedy": "貪吃",
	"eat_like_a_bird": "小鳥胃",
	"social_person": "社交達人",
	"asocial": "社恐孤僻",
	"optimistic": "樂觀開朗",
	"pessimistic": "悲觀憂慮",
	"debility": "體質虛弱",
	"strong": "筋骨強壯",
	"big_e": "大E外向",
	"big_i": "大I內斂"
}

## 9 大行為動態加權中文名稱 (對齊 NormalDecision.cs)
const ACTION_WEIGHT_NAMES: Array[String] = [
	"進食", "如廁", "工作", "就醫", "午睡", "洗澡", "社交", "娛樂", "散步"
]

## LTM 12 大性格詞條布林開關 (對齊 SQLite LTM 資料表與 NormalDecision)
@export var ltm_entries: Dictionary = {
	"medicine_jar": false,    # 藥罐子 (健康 -10)
	"healthy": false,         # 健康 (健康 +10)
	"greedy": false,          # 貪吃 (飽食 -10)
	"eat_like_a_bird": false, # 小鳥胃 (飽食 +10)
	"social_person": false,   # 社交達人 (社交需求 +10)
	"asocial": false,         # 社恐 (社交需求 -10)
	"optimistic": false,      # 樂觀 (心情 +10)
	"pessimistic": false,     # 悲觀 (心情 -10)
	"debility": false,        # 虛弱
	"strong": false,          # 強壯
	"big_e": false,           # 大E (外向)
	"big_i": false            # 大I (內向)
}

## LTM 9 大一般行為動態加權權重 (由換日結算 STM 演化更新)
@export var action_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

## 與其他 20 位 NPC 之 10 天歷史事件好壞分數 (0.0 ~ 1.0, 預設 0.5)
@export var history_scores: Array[float] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]

## 最近一次社交模型 (ONNX) 評估快取 (含候選人分數與選定行為)
@export var last_social_evaluation: Dictionary = {}

## NPC 已知城鎮情報字典 { rumor_id: String -> Dictionary }
## 每筆包含: { "learned_from": String, "learned_from_name": String, "learned_day": int, "learned_tick": int, "generation": int, "shared_to": Array[String] }
@export var known_rumors: Dictionary = {}

## 取得當前已啟用的 LTM 靈魂特質中文清單 (若 LTM entries 無啟用項目則退回 ltm_traits)
func get_active_ltm_trait_labels() -> Array[String]:
	var result: Array[String] = []
	for key in ltm_entries.keys():
		if bool(ltm_entries[key]):
			result.append(LTM_TRAIT_NAMES.get(key, key))
	if result.is_empty():
		return ltm_traits
	return result

## 取得對指定 NPC 編號 (1~20) 之 10 天歷史事件好壞分數 (0.0 ~ 1.0)
func get_history_score_to_npc(target_num: int) -> float:
	var idx: int = target_num - 1
	if idx >= 0 and idx < history_scores.size():
		return history_scores[idx]
	return 0.5

## 動態修飾器陣列 (符合 AGENTS.md 規範: 實體需帶有 Modifiers 陣列)
## 每項為 Dictionary: { "id": String, "stat": String, "value_per_tick": float, "duration": int }
var modifiers: Array[Dictionary] = []

## 個性詞條偏置向量 (長度 15，預設為 0.0，供神經推論時微調輸出傾向)
@export var personality_offset: PackedFloat32Array = PackedFloat32Array()

# ------------------------------------------------------------------------------
# 6. 建構與生命週期 (Constructor & Setup)
# ------------------------------------------------------------------------------

func _init() -> void:
	if personality_offset.is_empty():
		personality_offset.resize(15)
		personality_offset.fill(0.0)
	if ltm_traits.is_empty():
		_init_default_traits()
	calculate_personality_offset_from_entries()

## 依職業或預設建立靈魂性格特質標籤
func _init_default_traits() -> void:
	match job_id:
		1: ltm_traits = ["勤奮採掘", "耐力堅韌"]
		2: ltm_traits = ["沉靜好學", "重視知識"]
		3: ltm_traits = ["沉穩耐心", "喜愛水域"]
		4: ltm_traits = ["熱情好客", "擅長烹調"]
		5: ltm_traits = ["仁心仁術", "注重健康"]
		6: ltm_traits = ["質樸剛健", "熱愛森林"]
		7: ltm_traits = ["辛勤耕耘", "順應天時"]
		8: ltm_traits = ["精打細算", "善於社交"]
		9: ltm_traits = ["顧家溫暖", "隨和親切"]
		_: ltm_traits = ["自由自在", "樂於探索"]

## 依據 12 大性格詞條布林計算神經網路的輸入偏移量 (對齊 NormalDecision.cs)
func calculate_personality_offset_from_entries() -> void:
	if personality_offset.size() < 15:
		personality_offset.resize(15)
	personality_offset.fill(0.0)

	# 1: Health (健康度)
	if ltm_entries.get("medicine_jar", false):
		personality_offset[1] -= 10.0
	if ltm_entries.get("healthy", false):
		personality_offset[1] += 10.0

	# 3: Hunger (飽食度)
	if ltm_entries.get("greedy", false):
		personality_offset[3] -= 10.0
	if ltm_entries.get("eat_like_a_bird", false):
		personality_offset[3] += 10.0

	# 4: Social Desire (社交慾望)
	if ltm_entries.get("social_person", false):
		personality_offset[4] -= 10.0
	if ltm_entries.get("asocial", false):
		personality_offset[4] += 10.0
	if job_id == 9: # 家庭主婦提升社交需求
		personality_offset[4] -= 10.0

	# 5: Mood (心情)
	if ltm_entries.get("optimistic", false):
		personality_offset[5] += 10.0
	if ltm_entries.get("pessimistic", false):
		personality_offset[5] -= 10.0

## 從 SQLite 記憶資料庫 (MTM / LTM / LTSM) 載入啟動數值 (對應圖 1)
func apply_startup_data(data: Dictionary) -> void:
	if data.is_empty() or not data.get("success", false):
		return

	# 1. 還原生理數值 (MTM)
	if data.has("stats") and data["stats"] is Dictionary:
		var st: Dictionary = data["stats"]
		hp = float(st.get("hp", hp))
		health = float(st.get("health", health))
		stamina = float(st.get("stamina", stamina))
		hunger = float(st.get("hunger", hunger))
		social_desire = float(st.get("social_desire", social_desire))
		mood = float(st.get("mood", mood))
		money = int(st.get("money", money))
		wood = int(st.get("wood", wood))
		stone = int(st.get("stone", stone))
		mineral = int(st.get("mineral", mineral))
		crops = int(st.get("crops", crops))
		fish = int(st.get("fish", fish))
		food = int(st.get("food", food))
		lunchbox = int(st.get("lunchbox", lunchbox))

	# 2. 還原 12 大性格詞條 (LTM)
	if data.has("entries") and data["entries"] is Dictionary:
		var ent: Dictionary = data["entries"]
		for k in ent.keys():
			ltm_entries[k] = bool(ent[k])
		calculate_personality_offset_from_entries()

	# 3. 還原行動權重 (LTM)
	if data.has("action_weights") and data["action_weights"] is Array:
		var aw: Array = data["action_weights"]
		action_weights.resize(aw.size())
		for i in range(aw.size()):
			action_weights[i] = float(aw[i])

	# 4. 還原信任度與好感度 (LTSM)
	if data.has("trust") and data["trust"] is Dictionary:
		trust = data["trust"].duplicate()
	if data.has("friendships") and data["friendships"] is Dictionary:
		friendships = data["friendships"].duplicate()

	# 5. 還原互動歷史分數 (0.0 ~ 1.0)
	if data.has("history_scores") and data["history_scores"] is Array:
		var hs: Array = data["history_scores"]
		history_scores.resize(hs.size())
		for i in range(hs.size()):
			history_scores[i] = float(hs[i])

	if data.has("job_id") and int(data["job_id"]) > 0:
		job_id = int(data["job_id"])
	if data.has("home_id") and int(data["home_id"]) > 0:
		home_poi_id = int(data["home_id"])

	stats_changed.emit(npc_id)


# ------------------------------------------------------------------------------
# 7. 代謝模擬 (Tick-Based Simulation)
# ------------------------------------------------------------------------------

## 隨時間每 Tick 演化 NPC 狀態
func tick_update(delta_ticks: int = 1, is_sleeping: bool = false, is_working: bool = false) -> void:
	if delta_ticks <= 0:
		return

	var d: float = float(delta_ticks)

	# 1. 飽食度自然衰減
	hunger = clampf(hunger - (HUNGER_DECAY_PER_TICK * d), MIN_STAT, MAX_STAT)

	# 2. 體力增減
	if is_sleeping:
		stamina = clampf(stamina + (STAMINA_RECOVERY_SLEEP * d), MIN_STAT, MAX_STAT)
	elif is_working:
		stamina = clampf(stamina - (STAMINA_DECAY_WORK * d), MIN_STAT, MAX_STAT)
	else:
		stamina = clampf(stamina - (STAMINA_DECAY_IDLE * d), MIN_STAT, MAX_STAT)

	# 3. 社交慾望衰減
	if not is_sleeping:
		social_desire = clampf(social_desire - (SOCIAL_DECAY_PER_TICK * d), MIN_STAT, MAX_STAT)

	# 4. 健康度與生命值聯動 (飢荒扣血，健康過低扣血，飽腹健康回血)
	if hunger <= 0.0:
		health = clampf(health - (0.2 * d), MIN_STAT, MAX_STAT)
		hp = clampf(hp - (0.3 * d), MIN_STAT, MAX_STAT)
	if health < 20.0:
		hp = clampf(hp - (0.15 * d), MIN_STAT, MAX_STAT)
	elif health > 70.0 and hunger > 50.0 and hp < MAX_STAT and is_sleeping:
		# 睡眠且健康良好時自癒
		hp = clampf(hp + (0.05 * d), MIN_STAT, MAX_STAT)

	# 5. 心情演化 (飢餓或體力枯竭時心情降低，良好作息自然回穩)
	if hunger < 20.0 or stamina < 15.0 or health < 30.0:
		mood = clampf(mood - (0.08 * d), MIN_STAT, MAX_STAT)
	else:
		# 自然向平衡點 70.0 靠攏
		mood = move_toward(mood, 70.0, MOOD_DECAY_PER_TICK * d)

	# 6. 套用動態修飾器 (Modifiers)
	_process_modifiers(delta_ticks)

	# 7. 門檻警戒廣播
	if hp <= 0.0:
		hp_depleted.emit(npc_id)
	elif hunger < 20.0:
		hunger_critical.emit(npc_id)
	elif stamina < 10.0:
		stamina_depleted.emit(npc_id)

	stats_changed.emit(npc_id)

# ------------------------------------------------------------------------------
# 8. 特徵向量與資料交換 (AI Vector & Data Serialization)
# ------------------------------------------------------------------------------

## 匯出長度為 15 的特徵向量，供神經網路推論
func to_feature_vector() -> PackedFloat32Array:
	var vec: PackedFloat32Array = PackedFloat32Array()
	vec.resize(15)
	vec[0] = hp
	vec[1] = health
	vec[2] = stamina
	vec[3] = hunger
	vec[4] = social_desire
	vec[5] = mood
	vec[6] = float(job_id)
	vec[7] = float(money)
	vec[8] = float(wood)
	vec[9] = float(stone)
	vec[10] = float(mineral)
	vec[11] = float(crops)
	vec[12] = float(fish)
	vec[13] = float(food)
	vec[14] = float(lunchbox)
	return vec

## 從特徵向量反向設定 (可用於模型除錯或重設)
func from_feature_vector(vec: PackedFloat32Array) -> void:
	if vec.size() < 15:
		push_error("[NPCData] 特徵向量長度不足 15，無法賦值！")
		return
	hp = vec[0]
	health = vec[1]
	stamina = vec[2]
	hunger = vec[3]
	social_desire = vec[4]
	mood = vec[5]
	job_id = int(vec[6])
	money = int(vec[7])
	wood = int(vec[8])
	stone = int(vec[9])
	mineral = int(vec[10])
	crops = int(vec[11])
	fish = int(vec[12])
	food = int(vec[13])
	lunchbox = int(vec[14])
	stats_changed.emit(npc_id)

## 序列化為字典 (供存檔、MTM 日結算記錄或網路傳輸)
func to_dict() -> Dictionary:
	return {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"avatar_texture_path": avatar_texture_path,
		"home_poi_id": home_poi_id,
		"work_poi_id": work_poi_id,
		"hp": hp,
		"health": health,
		"stamina": stamina,
		"hunger": hunger,
		"social_desire": social_desire,
		"mood": mood,
		"job_id": job_id,
		"money": money,
		"wood": wood,
		"stone": stone,
		"mineral": mineral,
		"crops": crops,
		"fish": fish,
		"food": food,
		"lunchbox": lunchbox,
		"friendships": friendships.duplicate(),
		"trust": trust.duplicate(),
		"stm_events": stm_events.duplicate(),
		"last_interaction_days": last_interaction_days.duplicate(),
		"ltm_traits": ltm_traits.duplicate(),
		"ltm_entries": ltm_entries.duplicate(),
		"action_weights": action_weights.duplicate(),
		"history_scores": history_scores.duplicate(),
		"last_social_evaluation": last_social_evaluation.duplicate(),
		"personality_offset": Array(personality_offset),
		"known_rumors": known_rumors.duplicate(true)
	}

## 從字典反序列化 (由模板 JSON 初始化或讀檔)
func from_dict(data: Dictionary) -> void:
	npc_id = data.get("npc_id", npc_id)
	npc_name = data.get("npc_name", npc_name)
	avatar_texture_path = data.get("avatar_texture_path", avatar_texture_path)
	home_poi_id = int(data.get("home_poi_id", home_poi_id))
	work_poi_id = int(data.get("work_poi_id", work_poi_id))

	hp = float(data.get("hp", hp))
	health = float(data.get("health", health))
	stamina = float(data.get("stamina", stamina))
	hunger = float(data.get("hunger", hunger))
	social_desire = float(data.get("social_desire", social_desire))
	mood = float(data.get("mood", mood))
	job_id = int(data.get("job_id", job_id))

	money = int(data.get("money", money))
	wood = int(data.get("wood", wood))
	stone = int(data.get("stone", stone))
	mineral = int(data.get("mineral", mineral))
	crops = int(data.get("crops", crops))
	fish = int(data.get("fish", fish))
	food = int(data.get("food", food))
	lunchbox = int(data.get("lunchbox", lunchbox))

	if data.has("friendships") and data["friendships"] is Dictionary:
		friendships = data["friendships"].duplicate()
	if data.has("trust") and data["trust"] is Dictionary:
		trust = data["trust"].duplicate()
	if data.has("stm_events") and data["stm_events"] is Array:
		stm_events.clear()
		for ev in data["stm_events"]:
			stm_events.append(str(ev))
	if data.has("last_interaction_days") and data["last_interaction_days"] is Dictionary:
		last_interaction_days = data["last_interaction_days"].duplicate()
	if data.has("ltm_traits") and data["ltm_traits"] is Array:
		ltm_traits.clear()
		for tr in data["ltm_traits"]:
			ltm_traits.append(str(tr))
	if data.has("ltm_entries") and data["ltm_entries"] is Dictionary:
		ltm_entries = data["ltm_entries"].duplicate()
		calculate_personality_offset_from_entries()
	if data.has("action_weights") and data["action_weights"] is Array:
		var aw: Array = data["action_weights"]
		action_weights.resize(aw.size())
		for i in range(aw.size()):
			action_weights[i] = float(aw[i])
	if data.has("history_scores") and data["history_scores"] is Array:
		var hs: Array = data["history_scores"]
		history_scores.resize(hs.size())
		for i in range(hs.size()):
			history_scores[i] = float(hs[i])
	if data.has("last_social_evaluation") and data["last_social_evaluation"] is Dictionary:
		last_social_evaluation = data["last_social_evaluation"].duplicate()

	if data.has("personality_offset") and data["personality_offset"] is Array:
		var arr: Array = data["personality_offset"]
		personality_offset.resize(15)
		for i in range(mini(arr.size(), 15)):
			personality_offset[i] = float(arr[i])

	if data.has("known_rumors") and data["known_rumors"] is Dictionary:
		known_rumors = data["known_rumors"].duplicate(true)

	stats_changed.emit(npc_id)

# ------------------------------------------------------------------------------
# 8.5. 情報傳播與認知系統 (Information & Rumor System)
# ------------------------------------------------------------------------------

## 檢查是否已獲知特定情報
func has_rumor(rumor_id: String) -> bool:
	return known_rumors.has(rumor_id)

## 獲取尚未向特定 NPC (target_id) 轉述過的已知情報 ID 清單
func get_unshared_rumors_for(target_id: String) -> Array[String]:
	var unshared: Array[String] = []
	for r_id in known_rumors.keys():
		var entry: Dictionary = known_rumors[r_id]
		var shared_list: Array = entry.get("shared_to", [])
		if not (target_id in shared_list):
			unshared.append(str(r_id))
	return unshared

## 標記情報已向特定 NPC 轉述
func mark_rumor_shared(rumor_id: String, target_id: String) -> void:
	if known_rumors.has(rumor_id):
		var shared_list: Array = known_rumors[rumor_id].get("shared_to", [])
		if not (target_id in shared_list):
			shared_list.append(target_id)
			known_rumors[rumor_id]["shared_to"] = shared_list

## 學習新情報並套用神經行為引力 / 屬性影響
func learn_rumor(
	rumor_dict: Dictionary,
	from_id: String,
	from_name: String,
	day: int,
	tick: int,
	gen: int
) -> bool:
	var r_id: String = str(rumor_dict.get("id", ""))
	if r_id.is_empty() or has_rumor(r_id):
		return false

	known_rumors[r_id] = {
		"learned_from": from_id,
		"learned_from_name": from_name,
		"learned_day": day,
		"learned_tick": tick,
		"generation": gen,
		"shared_to": []
	}

	# 套用神經行為引力與身心影響
	var effects: Dictionary = rumor_dict.get("effects", {})
	apply_rumor_effects(effects)

	var r_title: String = str(rumor_dict.get("title", "未命名情報"))
	add_stm_event("聽聞情報: [%s] (來自 %s, 第 %d 代)" % [r_title, from_name, gen])
	stats_changed.emit(npc_id)
	return true

## 套用情報的神經行為引力與屬性調整
func apply_rumor_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return
	if effects.has("social_desire_bonus"):
		social_desire = clampf(social_desire + float(effects["social_desire_bonus"]), MIN_STAT, MAX_STAT)
	if effects.has("mood_bonus"):
		mood = clampf(mood + float(effects["mood_bonus"]), MIN_STAT, MAX_STAT)
	if effects.has("health_vigilance"):
		# 提升就醫戒備心 (心情稍降促使其提高就醫優先序)
		mood = clampf(mood - 5.0, MIN_STAT, MAX_STAT)
	if effects.has("fun_desire_bonus"):
		mood = clampf(mood + float(effects["fun_desire_bonus"]) * 0.5, MIN_STAT, MAX_STAT)
	if effects.has("type") and effects["type"] == "gossip":
		var a_id: String = str(effects.get("npc_a_id", ""))
		var b_id: String = str(effects.get("npc_b_id", ""))
		var delta_fav: float = float(effects.get("delta_fav", 0.0))
		var delta_trust: float = float(effects.get("delta_trust", 0.0))
		if not a_id.is_empty() and a_id != npc_id:
			modify_relationship(a_id, delta_fav, delta_trust)
		if not b_id.is_empty() and b_id != npc_id:
			modify_relationship(b_id, delta_fav, delta_trust)

# ------------------------------------------------------------------------------
# 9. 物品與資源管理 (Inventory & Eating)
# ------------------------------------------------------------------------------

## 取得特定物品數量
func get_item_count(item_type: String) -> int:
	match item_type:
		"wood": return wood
		"stone": return stone
		"mineral": return mineral
		"crops": return crops
		"fish": return fish
		"food": return food
		"lunchbox": return lunchbox
		"money": return money
		_: return 0

## 增加物品數量
func add_item(item_type: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	match item_type:
		"wood": wood = mini(wood + amount, MAX_ITEM_COUNT)
		"stone": stone = mini(stone + amount, MAX_ITEM_COUNT)
		"mineral": mineral = mini(mineral + amount, MAX_ITEM_COUNT)
		"crops": crops = mini(crops + amount, MAX_ITEM_COUNT)
		"fish": fish = mini(fish + amount, MAX_ITEM_COUNT)
		"food": food = mini(food + amount, MAX_ITEM_COUNT)
		"lunchbox": lunchbox = mini(lunchbox + amount, MAX_ITEM_COUNT)
		"money": money = mini(money + amount, MAX_ITEM_COUNT)
		_: return

	item_acquired.emit(npc_id, item_type, amount)
	stats_changed.emit(npc_id)

## 消耗物品數量 (不足時回傳 false)
func consume_item(item_type: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if get_item_count(item_type) < amount:
		return false

	match item_type:
		"wood": wood -= amount
		"stone": stone -= amount
		"mineral": mineral -= amount
		"crops": crops -= amount
		"fish": fish -= amount
		"food": food -= amount
		"lunchbox": lunchbox -= amount
		"money": money -= amount
		_: return false

	item_consumed.emit(npc_id, item_type, amount)
	stats_changed.emit(npc_id)
	return true

## 執行進食 (優先食用便當，若無便當則食用料理)
func eat_food(prefer_lunchbox: bool = true) -> bool:
	if prefer_lunchbox and lunchbox > 0:
		consume_item("lunchbox", 1)
		hunger = clampf(hunger + 55.0, MIN_STAT, MAX_STAT)
		stamina = clampf(stamina + 35.0, MIN_STAT, MAX_STAT)
		mood = clampf(mood + 15.0, MIN_STAT, MAX_STAT)
		return true
	elif food > 0:
		consume_item("food", 1)
		hunger = clampf(hunger + 45.0, MIN_STAT, MAX_STAT)
		stamina = clampf(stamina + 25.0, MIN_STAT, MAX_STAT)
		mood = clampf(mood + 10.0, MIN_STAT, MAX_STAT)
		return true
	return false

# ------------------------------------------------------------------------------
# 10. 社交關係與好感度管理 (Social Relationships)
# ------------------------------------------------------------------------------

## 取得對特定 NPC 的好感度 (預設 50.0)
func get_friendship(target_id: String) -> float:
	return float(friendships.get(target_id, 50.0))

## 取得對特定 NPC 的信任度 (預設 50.0)
func get_trust(target_id: String) -> float:
	return float(trust.get(target_id, 50.0))

## 調整對特定 NPC 的關係數值
func modify_relationship(target_id: String, delta_friendship: float, delta_trust: float) -> void:
	var cur_f: float = get_friendship(target_id)
	var cur_t: float = get_trust(target_id)
	var new_f: float = clampf(cur_f + delta_friendship, MIN_STAT, MAX_STAT)
	var new_t: float = clampf(cur_t + delta_trust, MIN_STAT, MAX_STAT)

	friendships[target_id] = new_f
	trust[target_id] = new_t

	relationship_changed.emit(npc_id, target_id, new_f, new_t)

## 新增短期生活事件記憶 (STM)
func add_stm_event(event_text: String) -> void:
	stm_events.push_front(event_text)
	if stm_events.size() > 5:
		stm_events.resize(5)

## 取得距離上次與特定 NPC 互動的天數 (預設 3.0，範圍 0.0 ~ 10.0)
func get_days_since_interaction(target_id: String, current_day: int) -> float:
	if not last_interaction_days.has(target_id):
		return 3.0
	var last_day: int = int(last_interaction_days[target_id])
	return clampf(float(current_day - last_day), 0.0, 10.0)

## 記錄與特定 NPC 發生互動
func record_interaction(target_id: String, current_day: int) -> void:
	last_interaction_days[target_id] = current_day

## 取得生理數值字典 (供 C# 資料庫儲存與結算使用)
func get_physiological_dict() -> Dictionary:
	return {
		"hp": hp,
		"health": health,
		"stamina": stamina,
		"hunger": hunger,
		"social_desire": social_desire,
		"mood": mood,
		"money": money,
		"wood": wood,
		"stone": stone,
		"mineral": mineral,
		"crops": crops,
		"fish": fish,
		"food": food,
		"lunchbox": lunchbox
	}

## 套用行動造成的數值改變量 (由 attributeCalculator 計算產出)
func apply_stat_changes(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	if changes.has("change_hp"):
		hp = clampf(hp + float(changes["change_hp"]), MIN_STAT, MAX_STAT)
	if changes.has("change_health"):
		health = clampf(health + float(changes["change_health"]), MIN_STAT, MAX_STAT)
	if changes.has("change_stamina"):
		stamina = clampf(stamina + float(changes["change_stamina"]), MIN_STAT, MAX_STAT)
	if changes.has("change_hunger"):
		hunger = clampf(hunger + float(changes["change_hunger"]), MIN_STAT, MAX_STAT)
	if changes.has("change_social_desire"):
		social_desire = clampf(social_desire + float(changes["change_social_desire"]), MIN_STAT, MAX_STAT)
	if changes.has("change_mood"):
		mood = clampf(mood + float(changes["change_mood"]), MIN_STAT, MAX_STAT)
	if changes.has("change_money"):
		money = clampi(money + int(changes["change_money"]), 0, 99999)
	if changes.has("change_wood"):
		wood = clampi(wood + int(changes["change_wood"]), 0, 9999)
	if changes.has("change_stone"):
		stone = clampi(stone + int(changes["change_stone"]), 0, 9999)
	if changes.has("change_mineral"):
		mineral = clampi(mineral + int(changes["change_mineral"]), 0, 9999)
	if changes.has("change_crops"):
		crops = clampi(crops + int(changes["change_crops"]), 0, 9999)
	if changes.has("change_fish"):
		fish = clampi(fish + int(changes["change_fish"]), 0, 9999)
	if changes.has("change_food"):
		food = clampi(food + int(changes["change_food"]), 0, 9999)
	if changes.has("change_lunchbox"):
		lunchbox = clampi(lunchbox + int(changes["change_lunchbox"]), 0, 9999)
	stats_changed.emit(npc_id)

## 套用換日結算更新的權重與歷史好壞分數 (對應圖 5: 步驟 9)
func apply_settlement_data(new_weights: Array, new_history_scores: Array) -> void:
	if not new_weights.is_empty():
		action_weights.clear()
		for w in new_weights:
			action_weights.append(float(w))
	if not new_history_scores.is_empty():
		history_scores.clear()
		for s in new_history_scores:
			history_scores.append(float(s))
	add_stm_event("換日記憶結算完成，行為權重與歷史分數已更新")

## 每日午夜記憶演化 (LTM / MTM / STM 結算)
func evolve_midnight_memory(day: int) -> void:
	# 1. 關係自然平緩 (MTM)：好感度向 50.0 溫和收斂
	for t_id in friendships.keys():
		var f: float = float(friendships[t_id])
		friendships[t_id] = move_toward(f, 50.0, 0.5)

	# 2. 結算當日經歷並沉澱思緒
	add_stm_event("第 %d 天午夜：進行思緒重整與記憶歸檔" % day)

# ------------------------------------------------------------------------------
# 11. 動態修飾器系統 (Modifiers)
# ------------------------------------------------------------------------------

## 新增修飾器 (如生病、吃飽、興奮等)
func add_modifier(mod: Dictionary) -> void:
	if not mod.has("id"):
		return
	# 若已有同名修飾器，覆蓋它
	remove_modifier(mod["id"])
	modifiers.append(mod)

## 移除修飾器
func remove_modifier(mod_id: String) -> void:
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].get("id", "") == mod_id:
			modifiers.remove_at(i)
			return

## 檢查是否帶有特定修飾器
func has_modifier(mod_id: String) -> bool:
	for m in modifiers:
		if m.get("id", "") == mod_id:
			return true
	return false

## 內部處理修飾器效果與過期倒數
func _process_modifiers(delta_ticks: int) -> void:
	if modifiers.is_empty():
		return

	for i in range(modifiers.size() - 1, -1, -1):
		var mod: Dictionary = modifiers[i]
		var stat: String = mod.get("stat", "")
		var val_per_tick: float = float(mod.get("value_per_tick", 0.0))
		var duration: int = int(mod.get("duration", -1))

		# 應用數值修飾
		if val_per_tick != 0.0:
			match stat:
				"hp": hp = clampf(hp + (val_per_tick * delta_ticks), MIN_STAT, MAX_STAT)
				"health": health = clampf(health + (val_per_tick * delta_ticks), MIN_STAT, MAX_STAT)
				"stamina": stamina = clampf(stamina + (val_per_tick * delta_ticks), MIN_STAT, MAX_STAT)
				"hunger": hunger = clampf(hunger + (val_per_tick * delta_ticks), MIN_STAT, MAX_STAT)
				"mood": mood = clampf(mood + (val_per_tick * delta_ticks), MIN_STAT, MAX_STAT)

		# 倒數計時
		if duration > 0:
			duration -= delta_ticks
			if duration <= 0:
				modifiers.remove_at(i)
			else:
				modifiers[i]["duration"] = duration
