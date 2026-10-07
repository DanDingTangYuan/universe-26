# ==============================================================================
# 26號宇宙 (Universe 26) - AI 決策大腦服務 (NPC Decision Service)
# 檔案路徑: res://scripts/ai/decision_service.gd
# 職責描述: 
#   1. 加載並快取神經網路權重 (MLP: 15 -> 64 -> 128 -> 64 -> 32 -> 9)
#   2. 執行原生 GDScript 15 維度前向推論，計算 9 種行為機率分數
#   3. 結合 Google 表格排程規則 (上班、午餐 12:00、就寢 23:00) 產出最終決策與目標 POI
#   4. 提供社交互動可行性檢查 (Rule-based Filter)
# ==============================================================================
class_name NPCDecisionService
extends RefCounted

# ------------------------------------------------------------------------------
# 1. 常數與設定 (Constants & Definitions)
# ------------------------------------------------------------------------------

const WEIGHTS_PATH: String = "res://ai_models/npc_weights.json"

## 行為名稱對照 (對應 0 ~ 8)
const ACTION_NAMES: Array[String] = [
	"閒逛", # 0
	"閱讀", # 1
	"購物", # 2
	"吃東西", # 3
	"就醫", # 4
	"回家休息", # 5
	"社交", # 6
	"巡田水", # 7
	"販售物品" # 8
]

## 作息關鍵時間點 (Ticks, 0 ~ 1440)
const WAKE_UP_TICK: int = 360 # 06:00 起床活動
const LUNCH_START_TICK: int = 720 # 12:00 午餐開始
const LUNCH_END_TICK: int = 780 # 13:00 午餐結束
const BEDTIME_TICK: int = 1380 # 23:00 最晚就寢回家

## 職業作息表 (資料來源：設計規格表)
const JOB_SCHEDULES: Dictionary = {
	1: {"name": "礦工", "work_start": 480, "work_end": 1020, "poi": 15}, # 08:00 ~ 17:00 礦場
	2: {"name": "圖書管理員", "work_start": 540, "work_end": 1200, "poi": 19}, # 09:00 ~ 20:00 圖書館
	3: {"name": "漁夫", "work_start": 420, "work_end": 540, "poi": 17}, # 07:00 ~ 09:00 釣魚場
	4: { # 餐廳員工 (雙班制)
		"name": "餐廳員工",
		"shifts": [ {"start": 660, "end": 780}, {"start": 1080, "end": 1260}],
		"poi": 13
	},
	5: {"name": "醫護人員", "work_start": 420, "work_end": 1320, "poi": 18}, # 07:00 ~ 22:00 醫院
	6: {"name": "伐木工", "work_start": 540, "work_end": 1020, "poi": 14}, # 09:00 ~ 17:00 伐木場
	7: {"name": "農民", "work_start": 420, "work_end": 720, "poi": 16}, # 07:00 ~ 12:00 農田
	8: {"name": "商店店長", "work_start": 480, "work_end": 1200, "poi": 12}, # 08:00 ~ 20:00 商店
	9: {"name": "家庭主夫/婦", "work_start": - 1, "work_end": - 1, "poi": 0} # 無固定上班時間
}

# ------------------------------------------------------------------------------
# 2. 內部神經網路模型結構 (Model Weights Storage)
# ------------------------------------------------------------------------------

var _is_loaded: bool = false
var _mean: PackedFloat32Array = PackedFloat32Array()
var _std: PackedFloat32Array = PackedFloat32Array()

var _layers_in_dim: Array[int] = []
var _layers_out_dim: Array[int] = []
var _layers_weights: Array[Array] = [] # Array[Array[PackedFloat32Array]]
var _layers_biases: Array[PackedFloat32Array] = []
var _layers_activations: Array[String] = []

## C# ONNX 橋接器與模式標記
var _csharp_bridge: RefCounted = null
var _use_csharp_onnx: bool = false

# ------------------------------------------------------------------------------
# 3. 初始化與權重載入 (Initialization & Weight Loading)
# ------------------------------------------------------------------------------

func _init() -> void:
	_try_init_csharp_bridge()
	if not _use_csharp_onnx:
		load_model()

## 嘗試初始化 C# ONNX 橋接引擎
func _try_init_csharp_bridge() -> void:
	if ResourceLoader.exists("res://ai_models/NPCDecisionBridge.cs"):
		var bridge_class = load("res://ai_models/NPCDecisionBridge.cs")
		if bridge_class != null:
			var inst = bridge_class.new()
			if inst != null and inst.has_method("Initialize"):
				if inst.Initialize("res://ai_models/npc_decision_mlp.onnx", "res://ai_models/npc_normalization.json"):
					_csharp_bridge = inst
					_use_csharp_onnx = true
					print("[NPCDecisionService] 成功啟用原生 C# ONNX Runtime (Microsoft.ML.OnnxRuntime) 推論引擎！")
					return
	print("[NPCDecisionService] 使用原生 GDScript 神經網路權重引擎。")

## 載入神經網路權重配置
func load_model(path: String = WEIGHTS_PATH) -> bool:
	if _is_loaded:
		return true

	if not FileAccess.file_exists(path):
		printerr("[NPCDecisionService] 找不到神經網路權重檔案: ", path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("[NPCDecisionService] 無法讀取權重檔案: ", path)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(json_text)
	if not data is Dictionary:
		printerr("[NPCDecisionService] 權重 JSON 解析失敗！")
		return false

	var dict: Dictionary = data
	# 載入標準化參數
	var norm: Dictionary = dict.get("normalization", {})
	var raw_mean: Array = norm.get("mean", [])
	var raw_std: Array = norm.get("std", [])
	
	_mean.resize(raw_mean.size())
	for i in range(raw_mean.size()):
		_mean[i] = float(raw_mean[i])

	_std.resize(raw_std.size())
	for i in range(raw_std.size()):
		_std[i] = float(raw_std[i])

	# 載入各層網路參數
	var layers: Array = dict.get("layers", [])
	_layers_in_dim.clear()
	_layers_out_dim.clear()
	_layers_weights.clear()
	_layers_biases.clear()
	_layers_activations.clear()

	for l_dict in layers:
		var in_dim: int = int(l_dict.get("in_dim", 0))
		var out_dim: int = int(l_dict.get("out_dim", 0))
		var act: String = String(l_dict.get("activation", "relu"))
		var raw_w: Array = l_dict.get("weight", []) # out_dim x in_dim
		var raw_b: Array = l_dict.get("bias", []) # out_dim

		var layer_w: Array[PackedFloat32Array] = []
		layer_w.resize(out_dim)
		for j in range(out_dim):
			var row: PackedFloat32Array = PackedFloat32Array()
			row.resize(in_dim)
			var raw_row: Array = raw_w[j]
			for k in range(in_dim):
				row[k] = float(raw_row[k])
			layer_w[j] = row

		var layer_b: PackedFloat32Array = PackedFloat32Array()
		layer_b.resize(out_dim)
		for j in range(out_dim):
			layer_b[j] = float(raw_b[j])

		_layers_in_dim.append(in_dim)
		_layers_out_dim.append(out_dim)
		_layers_weights.append(layer_w)
		_layers_biases.append(layer_b)
		_layers_activations.append(act)

	_is_loaded = true
	print("[NPCDecisionService] 神經網路模型載入成功！層數: %d, 特徵數: %d" % [_layers_weights.size(), _mean.size()])
	return true

# ------------------------------------------------------------------------------
# 4. 前向推論計算 (Neural Network Forward Pass)
# ------------------------------------------------------------------------------

## 輸入 15 個原始特徵，回傳 9 種行為的機率分佈 (0.0 ~ 1.0)
func forward(stats: PackedFloat32Array, personality_offset: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	if stats.size() < 15:
		printerr("[NPCDecisionService] 輸入特徵維度不足 15！目前大小: ", stats.size())
		return PackedFloat32Array()

	# 1. 優先使用 C# ONNX Runtime 引擎 (若已成功加載)
	if _use_csharp_onnx and _csharp_bridge != null:
		var input_stats: PackedFloat32Array = stats.duplicate()
		if not personality_offset.is_empty():
			var count: int = mini(input_stats.size(), personality_offset.size())
			for i in range(count):
				input_stats[i] += personality_offset[i]
		var raw_scores = _csharp_bridge.Evaluate(input_stats)
		var result: PackedFloat32Array = PackedFloat32Array()
		result.resize(raw_scores.size())
		for i in range(raw_scores.size()):
			result[i] = float(raw_scores[i])
		return result

	# 2. 備用：原生 GDScript 前向推論
	if not _is_loaded:
		if not load_model():
			return PackedFloat32Array()

	# 1. 特徵標準化：(x - mean) / std + 詞條偏移量
	var current: PackedFloat32Array = PackedFloat32Array()
	current.resize(15)
	for i in range(15):
		var offset: float = personality_offset[i] if i < personality_offset.size() else 0.0
		current[i] = ((stats[i] - _mean[i]) / _std[i]) + offset

	# 2. 逐層前向傳播
	var num_layers: int = _layers_weights.size()
	for l in range(num_layers):
		var weights: Array = _layers_weights[l]
		var biases: PackedFloat32Array = _layers_biases[l]
		var activation: String = _layers_activations[l]
		var out_dim: int = _layers_out_dim[l]

		var next_layer: PackedFloat32Array = PackedFloat32Array()
		next_layer.resize(out_dim)

		for j in range(out_dim):
			var sum_val: float = biases[j]
			var row: PackedFloat32Array = weights[j]
			for k in range(current.size()):
				sum_val += current[k] * row[k]

			# 激活函數
			if activation == "relu":
				next_layer[j] = maxf(0.0, sum_val)
			elif activation == "sigmoid":
				next_layer[j] = 1.0 / (1.0 + exp(-sum_val))
			else:
				next_layer[j] = sum_val

		current = next_layer

	# 3. 數值後處理 (四捨五入至小數點後三位，小於 0.0005 歸零，完全對齊 C# 實現)
	for i in range(current.size()):
		current[i] = snappedf(current[i], 0.001)
		if absf(current[i]) < 0.0005:
			current[i] = 0.0

	return current

# ------------------------------------------------------------------------------
# 5. 綜合決策與排程整合 (Comprehensive Decision with Schedule)
# ------------------------------------------------------------------------------

## 執行完整決策：考慮時間排程 (Curfew / Lunch / Work) 與神經網路意圖
func evaluate_decision(
	current_tick: int,
	stats: PackedFloat32Array,
	home_id: int,
	job_id: int,
	food_count: int,
	lunchbox_count: int,
	personality_offset: PackedFloat32Array = PackedFloat32Array()
) -> Dictionary:
	# 規則 1：就寢時間 (23:00 ~ 06:00 / tick >= 1380 或 tick < 360) 強制回家睡覺
	if current_tick >= BEDTIME_TICK or current_tick < WAKE_UP_TICK:
		return {
			"best_action": 5, # 回家休息
			"best_action_name": ACTION_NAMES[5],
			"target_location": home_id if home_id > 0 else 21,
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"override_reason": "就寢時間，強制返家休息"
		}

	# 規則 2：午餐時間 (12:00 ~ 13:00 / 720 ~ 780 ticks) 尋找食物
	var hunger: float = stats[3] if stats.size() > 3 else 50.0
	if current_tick >= LUNCH_START_TICK and current_tick < LUNCH_END_TICK and hunger < 85.0:
		var loc: int = 0 if (food_count > 0 or lunchbox_count > 0) else 13
		return {
			"best_action": 3, # 吃東西
			"best_action_name": ACTION_NAMES[3],
			"target_location": loc,
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"override_reason": "午餐時間，出外用餐或就地食用便當"
		}

	# 規則 3：上班時間檢查
	var work_check: Dictionary = _check_job_work_time(current_tick, job_id, stats)
	if work_check.get("is_working", false):
		var act_id: int = int(work_check.get("action", 7))
		var job_name: String = String(work_check.get("job_name", "工作"))
		return {
			"best_action": act_id,
			"best_action_name": "執勤工作 (%s)" % job_name,
			"target_location": work_check.get("poi", 0),
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"override_reason": "工作時間，前往 %s 崗位執勤" % job_name
		}

	# 規則 4：無排程干預時，由神經網路 (AI) 自由決策
	var scores: PackedFloat32Array = forward(stats, personality_offset)
	var best_action: int = get_best_action_index(scores)
	var target_location: int = get_location_by_action(best_action, food_count, lunchbox_count, home_id, job_id)

	return {
		"best_action": best_action,
		"best_action_name": get_action_name(best_action),
		"target_location": target_location,
		"scores": scores,
		"is_rule_override": false,
		"override_reason": ""
	}

# ------------------------------------------------------------------------------
# 6. 行動與地點映射 (Action to Location Mapping)
# ------------------------------------------------------------------------------

## 依據行為代碼與物資決定目標地點 (對照表設計規則)
func get_location_by_action(
	action_index: int,
	food_count: int,
	lunchbox_count: int,
	home_id: int,
	job_id: int
) -> int:
	match action_index:
		0: # 閒逛
			# 較高機率前往社交廣場 (20)，其餘隨機地圖 1~25
			var r: int = randi_range(1, 25)
			return 20 if r >= 20 else r
		1: # 閱讀 -> 19 (圖書館)
			return 19
		2: # 購物 -> 13 (餐廳) 或 12 (商店)
			return 13
		3: # 吃東西
			if food_count > 0 or lunchbox_count > 0:
				return 0 # 原地吃
			return 13 # 餐廳
		4: # 就醫 -> 18 (醫院)
			return 18
		5: # 回家休息 -> 該 NPC 的家
			return home_id if home_id > 0 else 21
		6: # 社交 -> 20 (社交廣場)
			return 20
		7: # 巡田水 -> 16 (農田)
			return 16
		8: # 販售物品 -> 12 (商店)
			return 12
		_:
			return 0

## 取得分數最高的行為索引
func get_best_action_index(scores: PackedFloat32Array) -> int:
	if scores.is_empty():
		return 0
	var best_idx: int = 0
	var max_val: float = scores[0]
	for i in range(1, scores.size()):
		if scores[i] > max_val:
			max_val = scores[i]
			best_idx = i
	return best_idx

## 取得行為中文名稱
func get_action_name(action_index: int) -> String:
	if action_index >= 0 and action_index < ACTION_NAMES.size():
		return ACTION_NAMES[action_index]
	return "未知"

# ------------------------------------------------------------------------------
# 7. 社交可用性篩選 (Social Filter - Sheet 0 規則)
# ------------------------------------------------------------------------------

## 檢查目標 NPC 是否允許進行社交互動
## 規格書明載：「若該 NPC 正在工作、就醫、閱讀、在家休息，則不適合互動，直接由程式碼檢查」
func is_available_for_social(current_action: int, is_at_home: bool = false) -> bool:
	if is_at_home:
		return false
	match current_action:
		1: # 閱讀
			return false
		4: # 就醫
			return false
		5: # 回家休息
			return false
		7: # 巡田水 (工作)
			return false
		_:
			return true

# ------------------------------------------------------------------------------
# 8. 內部輔助：工作時間判定
# ------------------------------------------------------------------------------

func _check_job_work_time(tick: int, job_id: int, stats: PackedFloat32Array) -> Dictionary:
	# 若體力過低 (< 15) 或健康度過低 (< 15)，身體不適不強制上班
	var stamina: float = stats[2] if stats.size() > 2 else 50.0
	var health: float = stats[1] if stats.size() > 1 else 50.0
	if stamina < 15.0 or health < 15.0:
		return {"is_working": false}

	if not JOB_SCHEDULES.has(job_id):
		return {"is_working": false}

	var job_info: Dictionary = JOB_SCHEDULES[job_id]
	var poi: int = job_info.get("poi", 0)

	# 雙班制 (如餐廳員工)
	if job_info.has("shifts"):
		var shifts: Array = job_info["shifts"]
		for shift in shifts:
			if tick >= shift["start"] and tick < shift["end"]:
				return {"is_working": true, "poi": poi, "action": 7, "job_name": job_info.get("name", "工作")}
		return {"is_working": false}

	# 單班制
	var start_t: int = job_info.get("work_start", -1)
	var end_t: int = job_info.get("work_end", -1)
	if start_t >= 0 and end_t >= 0 and tick >= start_t and tick < end_t:
		var act: int = 7 if job_id == 7 else (8 if job_id == 8 else (1 if job_id == 2 else 7))
		return {"is_working": true, "poi": poi, "action": act, "job_name": job_info.get("name", "工作")}

	return {"is_working": false}
