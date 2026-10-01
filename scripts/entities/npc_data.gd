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
const HUNGER_DECAY_PER_TICK: float = 0.05 # 每天自然消耗約 72 點，需用餐 2~3 次
const STAMINA_DECAY_IDLE: float = 0.03 # 平常活動消耗 (每天約 43 點)
const STAMINA_DECAY_WORK: float = 0.12 # 工作時加劇消耗
const STAMINA_RECOVERY_SLEEP: float = 0.25 # 睡眠時快速恢復 (睡 6 小時可回約 90 點)
const SOCIAL_DECAY_PER_TICK: float = 0.035 # 社交渴望消耗
const MOOD_DECAY_PER_TICK: float = 0.02 # 心情緩慢向平衡點靠攏

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

# 生理與心理指標 (0.0 ~ 100.0)
@export var hp: float = 100.0
@export var health: float = 100.0
@export var stamina: float = 100.0
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

	# 4. 健康度與生命值聯動 (飢餓飢荒/生病扣血，飽腹健康回血)
	if hunger <= 0.0:
		health = clampf(health - (0.1 * d), MIN_STAT, MAX_STAT)
		if health < 30.0:
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
		"personality_offset": Array(personality_offset)
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

	if data.has("personality_offset") and data["personality_offset"] is Array:
		var arr: Array = data["personality_offset"]
		personality_offset.resize(15)
		for i in range(mini(arr.size(), 15)):
			personality_offset[i] = float(arr[i])

	stats_changed.emit(npc_id)

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
		hunger = clampf(hunger + 45.0, MIN_STAT, MAX_STAT)
		stamina = clampf(stamina + 15.0, MIN_STAT, MAX_STAT)
		mood = clampf(mood + 10.0, MIN_STAT, MAX_STAT)
		return true
	elif food > 0:
		consume_item("food", 1)
		hunger = clampf(hunger + 35.0, MIN_STAT, MAX_STAT)
		stamina = clampf(stamina + 10.0, MIN_STAT, MAX_STAT)
		mood = clampf(mood + 5.0, MIN_STAT, MAX_STAT)
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
