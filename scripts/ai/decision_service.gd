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
const BREAKFAST_START_TICK: int = 420 # 07:00 早餐開始
const BREAKFAST_END_TICK: int = 480 # 08:00 早餐結束
const LUNCH_START_TICK: int = 720 # 12:00 午餐開始
const LUNCH_END_TICK: int = 780 # 13:00 午餐結束
const DINNER_START_TICK: int = 1080 # 18:00 晚餐開始
const DINNER_END_TICK: int = 1170 # 19:30 晚餐結束
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
	5: {"name": "醫護人員", "shifts_desc": "早班07:00~15:00 / 晚班14:00~22:00", "poi": 18}, # 07:00 ~ 22:00 醫院 (輪班制)
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

## AI 決策模型模式枚舉
enum AIModelType {
	DUAL_TRANSFORMER = 0, # 雙頭 Transformer 大腦 (Policy Transformer + Social Transformer，推薦/最新)
	CLASSIC_MLP = 1,      # 經典 MLP 神經網路 (C# ONNX / GDScript 原生推論)
	RULE_BASED = 2        # 純啟發式作息規則 (無神經網絡，遵循作息與生理求生啟發式)
}

## 當前啟用的 AI 決策模型模式
var current_ai_model_type: AIModelType = AIModelType.DUAL_TRANSFORMER

## C# ONNX 橋接器與模式標記
var _csharp_bridge: RefCounted = null
var _use_csharp_onnx: bool = false
var _use_transformer: bool = false
var _use_social_transformer: bool = false
var enable_pure_transformer: bool = false

## 切換 AI 決策大腦模式
func set_ai_model_type(model_type: int) -> void:
	current_ai_model_type = model_type as AIModelType
	match current_ai_model_type:
		AIModelType.DUAL_TRANSFORMER:
			_use_csharp_onnx = true
			_use_transformer = (_csharp_bridge != null and _csharp_bridge.has_method("EvaluateTransformer"))
			_use_social_transformer = (_csharp_bridge != null and _csharp_bridge.has_method("EvaluateSocialCandidates"))
			enable_pure_transformer = false
			print("[NPCDecisionService] 🧠 AI 決策模型切換為：【雙頭 Transformer 大腦 (Dual Transformer)】")
		AIModelType.CLASSIC_MLP:
			_use_csharp_onnx = true
			_use_transformer = false
			_use_social_transformer = false
			enable_pure_transformer = false
			print("[NPCDecisionService] 🧠 AI 決策模型切換為：【經典 MLP 神經網路 (Classic MLP)】")
		AIModelType.RULE_BASED:
			_use_csharp_onnx = false
			_use_transformer = false
			_use_social_transformer = false
			enable_pure_transformer = false
			print("[NPCDecisionService] 🧠 AI 決策模型切換為：【純啟發式作息規則 (Rule-Based Only)】")

## 取得當前 AI 決策模型模式
func get_ai_model_type() -> int:
	return int(current_ai_model_type)

## 取得當前 AI 決策模型顯示名稱
func get_ai_model_name() -> String:
	match current_ai_model_type:
		AIModelType.DUAL_TRANSFORMER:
			return "雙頭 Transformer 大腦"
		AIModelType.CLASSIC_MLP:
			return "經典 MLP 神經網路"
		AIModelType.RULE_BASED:
			return "純啟發式作息規則"
		_:
			return "未指定模型"

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
			if inst != null:
				var init_mlp_ok: bool = false
				if inst.has_method("Initialize"):
					init_mlp_ok = inst.Initialize("res://ai_models/npc_decision_mlp.onnx", "res://ai_models/npc_normalization.json")

				# 優先檢查 Policy Transformer 決策大腦是否就緒
				var tf_active: bool = false
				if inst.has_method("IsTransformerActive"):
					tf_active = inst.IsTransformerActive()
				elif "IsTransformerInitialized" in inst:
					tf_active = bool(inst.IsTransformerInitialized)

				if not tf_active and inst.has_method("InitializeTransformer"):
					var tf_path: String = "res://ai_models/universe_policy_transformer.onnx"
					if FileAccess.file_exists(tf_path):
						tf_active = inst.InitializeTransformer(tf_path)

				# 優先檢查 Social Transformer 決策大腦是否就緒
				var st_active: bool = false
				if inst.has_method("IsSocialTransformerActive"):
					st_active = inst.IsSocialTransformerActive()
				elif "IsSocialTransformerInitialized" in inst:
					st_active = bool(inst.IsSocialTransformerInitialized)

				if not st_active and inst.has_method("InitializeSocialTransformer"):
					var st_path: String = "res://ai_models/universe_social_transformer.onnx"
					if FileAccess.file_exists(st_path):
						st_active = inst.InitializeSocialTransformer(st_path)

				if init_mlp_ok or tf_active or st_active:
					_csharp_bridge = inst
					_use_csharp_onnx = true
					_use_transformer = tf_active
					_use_social_transformer = st_active
					if _use_transformer:
						print("[NPCDecisionService] 🚀 成功啟用 Causal Policy Transformer 決策大腦 (universe_policy_transformer.onnx)！")
					if _use_social_transformer:
						print("[NPCDecisionService] 👥 成功啟用 Causal Social Transformer 社交大腦 (universe_social_transformer.onnx)！")
					if not _use_transformer and not _use_social_transformer:
						print("[NPCDecisionService] 成功啟用原生 C# ONNX Runtime (Microsoft.ML.OnnxRuntime) 推論引擎！")
					return
				else:
					printerr("[NPCDecisionService] C# NPCDecisionBridge 初始化失敗，退回 GDScript 原生神經網路引擎。")
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

## 檢查 Transformer 決策大腦是否啟用中
func is_transformer_active() -> bool:
	return _use_transformer

## 設定是否切換為純 Transformer 決策模式 (跳過作息規則覆蓋，由模型直接決策)
func set_pure_transformer(enable: bool) -> void:
	enable_pure_transformer = enable
	print("[NPCDecisionService] 純 Transformer 決策模式切換為: ", enable)

## 直接調用 Transformer 決策推論 (雙頭輸出行為與地點)
func evaluate_transformer(
	stats: PackedFloat32Array,
	current_tick: int,
	job_id: int,
	home_poi: int,
	prev_action: int = 0
) -> Dictionary:
	if not _use_transformer or _csharp_bridge == null or not _csharp_bridge.has_method("EvaluateTransformer"):
		return {"success": false, "best_action": 0, "best_poi": 0}
	return _csharp_bridge.EvaluateTransformer(stats, current_tick, job_id, home_poi, prev_action)

# ------------------------------------------------------------------------------
# 5. 綜合決策與排程整合 (Comprehensive Decision with Schedule)
# ------------------------------------------------------------------------------

## 執行完整決策：考慮生理求生 (飢餓/體力休養/就醫)、時間排程 (就寢/三餐/工作) 與神經網路意圖
func evaluate_decision(
	current_tick: int,
	stats: PackedFloat32Array,
	home_id: int,
	job_id: int,
	food_count: int,
	lunchbox_count: int,
	personality_offset: PackedFloat32Array = PackedFloat32Array(),
	npc_id: String = "",
	action_weights: Array = [],
	is_resting: bool = false,
	prev_action: int = 0
) -> Dictionary:
	var hp_val: float = stats[0] if stats.size() > 0 else 100.0
	var health: float = stats[1] if stats.size() > 1 else 50.0
	var stamina: float = stats[2] if stats.size() > 2 else 50.0
	var hunger: float = stats[3] if stats.size() > 3 else 50.0
	var money: int = int(stats[7]) if stats.size() > 7 else 0

	# 規則 0：飢餓緊急生存法則 (最高優先級，防暴斃)
	# 若極度飢餓 (hunger < 30.0)，不管任何工作或排程立即進食
	if hunger < 30.0:
		# 身上有便當或料理：優先原地進食 (耗時短、防暴斃)
		if food_count > 0 or lunchbox_count > 0:
			return {
				"best_action": 3, # 吃東西
				"best_action_name": ACTION_NAMES[3],
				"target_location": 0, # 原地進食
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "飢餓度過低 (%.1f < 30.0)，緊急原地享用便當/料理充飢" % hunger
			}
		# 身上無糧食且非深夜就寢時段 (或瀕臨餓死)，前往餐廳進食/求援
		elif (current_tick >= WAKE_UP_TICK and current_tick < BEDTIME_TICK) or hunger < 15.0:
			return {
				"best_action": 3, # 吃東西
				"best_action_name": ACTION_NAMES[3],
				"target_location": 13, # 餐廳
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "極度飢餓 (%.1f) 且無存糧，緊急前往餐廳進食" % hunger
			}

	# 規則 2：緊急就醫 (健康過低或身受重傷)
	if health < 25.0 or (hp_val < 30.0 and health < 50.0):
		return {
			"best_action": 4, # 就醫
			"best_action_name": ACTION_NAMES[4],
			"target_location": 18, # 醫院
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"override_reason": "身體抱恙或負傷 (健康:%.1f, HP:%.1f)，緊急前往醫院就醫" % [health, hp_val]
		}

	# 若啟用純 Transformer 模式：在底線生存法則 (飢餓/就醫) 之外，其餘作息與工作全由 Transformer 大腦自主演繹
	if enable_pure_transformer and _use_transformer and _csharp_bridge != null:
		var pure_tf_res = _evaluate_pure_transformer(stats, current_tick, job_id, home_id, prev_action, food_count, lunchbox_count, money, personality_offset, action_weights)
		if not pure_tf_res.is_empty():
			return pure_tf_res

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

	# 規則 3：常規三餐用餐時間 (早餐 07:00~08:00, 午餐 12:00~13:00, 晚餐 18:00~19:30)
	var is_breakfast_time: bool = (current_tick >= BREAKFAST_START_TICK and current_tick < BREAKFAST_END_TICK)
	var is_lunch_time: bool = (current_tick >= LUNCH_START_TICK and current_tick < LUNCH_END_TICK)
	var is_dinner_time: bool = (current_tick >= DINNER_START_TICK and current_tick < DINNER_END_TICK)

	if (is_breakfast_time or is_lunch_time or is_dinner_time) and hunger < 85.0:
		var meal_name: String = "早餐" if is_breakfast_time else ("午餐" if is_lunch_time else "晚餐")
		var loc: int = 0 if (food_count > 0 or lunchbox_count > 0) else 13
		return {
			"best_action": 3, # 吃東西
			"best_action_name": ACTION_NAMES[3],
			"target_location": loc,
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"override_reason": "%s時間，出外用餐或就地食用便當" % meal_name
		}

	# 規則 4：體力耗盡休養與遲滯保護 (Hysteresis)
	# 時鐘檢測：白天時段 (06:30 ~ 21:30, tick 390 ~ 1290) 嚴禁觸發返家睡眠 (Action 5)
	var is_daytime: bool = (current_tick >= 390 and current_tick < 1290)
	if is_daytime:
		# 白天若體力偏低 (stamina < 30.0)：優先引導進食，無法進食則原地小憩摸魚，絕不允許跑回家睡覺
		if stamina < 30.0:
			if food_count > 0 or lunchbox_count > 0:
				return {
					"best_action": 3, # 吃東西
					"best_action_name": ACTION_NAMES[3],
					"target_location": 0, # 原地吃
					"scores": PackedFloat32Array(),
					"is_rule_override": true,
					"override_reason": "白天體力偏低 (%.1f < 30.0)，就地食用存糧回補體力" % stamina
				}
			elif money >= 3:
				return {
					"best_action": 3, # 吃東西
					"best_action_name": ACTION_NAMES[3],
					"target_location": 13, # 餐廳用餐
					"scores": PackedFloat32Array(),
					"is_rule_override": true,
					"override_reason": "白天體力偏低 (%.1f < 30.0) 且身懷金錢，前往餐廳用餐回補體力" % stamina
				}
			else:
				return {
					"best_action": 0, # 閒逛/原地小憩
					"best_action_name": "原地小憩",
					"target_location": 0, # 原地放鬆
					"scores": PackedFloat32Array(),
					"is_rule_override": true,
					"override_reason": "白天體力偏低 (%.1f < 30.0) 且無存糧金錢，原地小憩摸魚放鬆" % stamina
				}
	else:
		# 夜間時段 (21:30 ~ 06:30, tick >= 1290 或 tick < 390)：體力透支或睡眠時間才允許返家就寢大睡
		if is_resting and stamina < 75.0:
			return {
				"best_action": 5, # 回家休息
				"best_action_name": ACTION_NAMES[5],
				"target_location": home_id if home_id > 0 else 21,
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "夜間休養中，體力恢復至充足水準 (%.1f/75.0) 前持續就寢" % stamina
			}

		if stamina < 30.0:
			return {
				"best_action": 5, # 回家休息
				"best_action_name": ACTION_NAMES[5],
				"target_location": home_id if home_id > 0 else 21,
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "夜間體力透支 (%.1f < 30.0)，提早返家就寢" % stamina
			}

	# 規則 5：工作排程檢查
	var work_check: Dictionary = _check_job_work_time(current_tick, job_id, stats, home_id, npc_id, is_resting)
	if work_check.get("is_working", false):
		var act_id: int = int(work_check.get("action", 7))
		var job_name: String = String(work_check.get("job_name", "工作"))
		return {
			"best_action": act_id,
			"best_action_name": "執勤工作 (%s)" % job_name,
			"target_location": work_check.get("poi", 0),
			"scores": PackedFloat32Array(),
			"is_rule_override": true,
			"is_work_schedule": true,
			"override_reason": "工作時間，前往 %s 崗位執勤" % job_name
		}

	# 規則 5.5：自由活動期購物與儲糧活化 (Action 2 傾向)
	# 當居民持有金錢充足 (money >= 6) 且身上毫無存糧 (lunchbox == 0 and food == 0) 時，給予採購儲糧傾向
	if money >= 6 and lunchbox_count == 0 and food_count == 0:
		if randf() < 0.5:
			var shop_poi: int = 12 if (randf() < 0.5) else 13 # 商店 POI 12 (食材料理) 或 餐廳 POI 13 (便當)
			return {
				"best_action": 2, # 購物
				"best_action_name": ACTION_NAMES[2],
				"target_location": shop_poi,
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "身上無存糧且金錢充足 ($%d >= 6)，前往採購儲備餐點" % money
			}

	# 規則 5.6：自由活動期社交慾望活化 (Action 6 社交傾向)
	# 當居民社交慾望偏低 (social_desire < 45.0) 且作息充裕時，給予社交互動傾向，激勵前往廣場交流並啟動 Social Transformer
	var soc_val_rule: float = stats[4] if stats.size() > 4 else 50.0
	if soc_val_rule < 45.0:
		var social_prob: float = 0.6 if soc_val_rule < 30.0 else 0.4
		if randf() < social_prob:
			return {
				"best_action": 6, # 社交
				"best_action_name": ACTION_NAMES[6],
				"target_location": 20, # 社交廣場
				"scores": PackedFloat32Array(),
				"is_rule_override": true,
				"override_reason": "社交慾望偏低 (%.1f < 45.0)，前往社交廣場尋求同伴交流" % soc_val_rule
			}

	# 模式分支：若設定為純啟發式作息規則，跳過神經網路推論
	if current_ai_model_type == AIModelType.RULE_BASED:
		var mood_val: float = stats[5] if stats.size() > 5 else 50.0
		var soc_val: float = stats[4] if stats.size() > 4 else 50.0
		if soc_val < 45.0:
			return {
				"best_action": 6, # 社交
				"best_action_name": ACTION_NAMES[6],
				"target_location": 20, # 社交廣場
				"scores": PackedFloat32Array(),
				"is_rule_override": false,
				"override_reason": "純啟發式規則：社交慾望偏低 (%.1f < 45)，前往社交廣場尋求互動" % soc_val
			}
		elif mood_val < 55.0:
			return {
				"best_action": 1, # 閱讀
				"best_action_name": ACTION_NAMES[1],
				"target_location": 19, # 圖書館
				"scores": PackedFloat32Array(),
				"is_rule_override": false,
				"override_reason": "純啟發式規則：心情偏低 (%.1f < 55)，前往圖書館閱讀放鬆" % mood_val
			}
		else:
			return {
				"best_action": 0, # 閒逛
				"best_action_name": ACTION_NAMES[0],
				"target_location": 20 if randf() < 0.5 else 0,
				"scores": PackedFloat32Array(),
				"is_rule_override": false,
				"override_reason": "純啟發式規則：作息充裕，街區悠閒散步閒逛"
			}

	# 規則 6：無排程干預時，由神經網路 (AI) 自由決策
	# 優先使用 Causal Transformer 決策大腦 (雙頭輸出行為與地點)
	if _use_transformer and _csharp_bridge != null and _csharp_bridge.has_method("EvaluateTransformer"):
		var input_stats: PackedFloat32Array = stats.duplicate()
		if not personality_offset.is_empty():
			var count: int = mini(input_stats.size(), personality_offset.size())
			for i in range(count):
				input_stats[i] += personality_offset[i]

		var tf_res: Dictionary = _csharp_bridge.EvaluateTransformer(
			input_stats,
			current_tick,
			job_id,
			home_id,
			prev_action
		)
		if tf_res.get("success", false):
			var tf_action: int = int(tf_res.get("best_action", 0))
			var tf_poi: int = int(tf_res.get("best_poi", 0))
			var raw_scores = tf_res.get("action_scores", [])
			var scores: PackedFloat32Array = PackedFloat32Array()
			scores.resize(raw_scores.size())
			for i in range(raw_scores.size()):
				scores[i] = float(raw_scores[i])

			# 若金錢充足且無存糧，適度微調購物 (Action 2) 傾向
			if money >= 6 and lunchbox_count == 0 and food_count == 0 and scores.size() > 2:
				scores[2] += 0.35

			# 根據社交慾望動態加權：社交慾望偏低時顯著提升社交 (Action 6) 傾向，活化 Transformer 社交活動
			var soc_val_tf: float = stats[4] if stats.size() > 4 else 50.0
			if soc_val_tf < 65.0 and scores.size() > 6:
				var soc_boost: float = maxf(0.0, (65.0 - soc_val_tf) / 65.0) * 0.45
				scores[6] += soc_boost

			var chosen_action: int = tf_action
			if not action_weights.is_empty() and action_weights.size() >= 9:
				var weights_array: PackedFloat32Array = PackedFloat32Array()
				weights_array.resize(9)
				for i in range(9):
					weights_array[i] = float(action_weights[i])
				if _csharp_bridge.has_method("SampleActionWithWeights"):
					chosen_action = int(_csharp_bridge.SampleActionWithWeights(scores, weights_array))
				else:
					chosen_action = _sample_action_with_weights(scores, weights_array)
			else:
				chosen_action = get_best_action_index(scores)

			# 目標 POI：若為社交行為且 Transformer POI 非社交場所，自動引導至社交廣場 POI 20
			var target_location: int = tf_poi
			if chosen_action == 6 and target_location not in [20, 12, 13, 22]:
				target_location = 20
			elif target_location <= 0 or target_location > 25:
				target_location = get_location_by_action(chosen_action, food_count, lunchbox_count, home_id, job_id)

			return {
				"best_action": chosen_action,
				"best_action_name": get_action_name(chosen_action),
				"target_location": target_location,
				"scores": scores,
				"poi_scores": tf_res.get("poi_scores", []),
				"is_rule_override": false,
				"override_reason": "",
				"decision_mechanism": "transformer_policy"
			}

	# 備用：若無 Transformer 或推論失敗，回退至經典 MLP 決策 (依據圖 3: 依 LTM 權重改變分數並輪盤抽樣)
	var scores: PackedFloat32Array = forward(stats, personality_offset)
	# 若金錢充足且無存糧，在神經分數上額外提高購物 (Action 2) 傾向
	if money >= 6 and lunchbox_count == 0 and food_count == 0 and scores.size() > 2:
		scores[2] += 0.35

	# 若社交慾望偏低，在神經分數上額外提高社交 (Action 6) 傾向
	var soc_val_mlp: float = stats[4] if stats.size() > 4 else 50.0
	if soc_val_mlp < 65.0 and scores.size() > 6:
		var soc_boost: float = maxf(0.0, (65.0 - soc_val_mlp) / 65.0) * 0.45
		scores[6] += soc_boost

	var chosen_action: int = 0
	if not action_weights.is_empty() and action_weights.size() >= 9:
		var weights_array: PackedFloat32Array = PackedFloat32Array()
		weights_array.resize(9)
		for i in range(9):
			weights_array[i] = float(action_weights[i])
		if _use_csharp_onnx and _csharp_bridge != null and _csharp_bridge.has_method("SampleActionWithWeights"):
			chosen_action = int(_csharp_bridge.SampleActionWithWeights(scores, weights_array))
		else:
			chosen_action = _sample_action_with_weights(scores, weights_array)
	else:
		chosen_action = get_best_action_index(scores)

	var target_location: int = get_location_by_action(chosen_action, food_count, lunchbox_count, home_id, job_id)

	return {
		"best_action": chosen_action,
		"best_action_name": get_action_name(chosen_action),
		"target_location": target_location,
		"scores": scores,
		"is_rule_override": false,
		"override_reason": "",
		"decision_mechanism": "ai_mlp"
	}

## 內部純 Transformer 決策評估
func _evaluate_pure_transformer(
	stats: PackedFloat32Array,
	current_tick: int,
	job_id: int,
	home_id: int,
	prev_action: int,
	food_count: int,
	lunchbox_count: int,
	money: int,
	personality_offset: PackedFloat32Array,
	action_weights: Array
) -> Dictionary:
	var input_stats: PackedFloat32Array = stats.duplicate()
	if not personality_offset.is_empty():
		var count: int = mini(input_stats.size(), personality_offset.size())
		for i in range(count):
			input_stats[i] += personality_offset[i]

	var tf_res: Dictionary = _csharp_bridge.EvaluateTransformer(
		input_stats,
		current_tick,
		job_id,
		home_id,
		prev_action
	)
	if tf_res.get("success", false):
		var tf_action: int = int(tf_res.get("best_action", 0))
		var tf_poi: int = int(tf_res.get("best_poi", 0))
		var raw_scores = tf_res.get("action_scores", [])
		var scores: PackedFloat32Array = PackedFloat32Array()
		scores.resize(raw_scores.size())
		for i in range(raw_scores.size()):
			scores[i] = float(raw_scores[i])

		# 根據社交慾望動態加權，提升社交 (Action 6) 傾向
		var soc_val_ptf: float = stats[4] if stats.size() > 4 else 50.0
		if soc_val_ptf < 65.0 and scores.size() > 6:
			var soc_boost: float = maxf(0.0, (65.0 - soc_val_ptf) / 65.0) * 0.45
			scores[6] += soc_boost

		var chosen_action: int = tf_action
		if not action_weights.is_empty() and action_weights.size() >= 9:
			var weights_array: PackedFloat32Array = PackedFloat32Array()
			weights_array.resize(9)
			for i in range(9):
				weights_array[i] = float(action_weights[i])
			if _csharp_bridge.has_method("SampleActionWithWeights"):
				chosen_action = int(_csharp_bridge.SampleActionWithWeights(scores, weights_array))
			else:
				chosen_action = _sample_action_with_weights(scores, weights_array)
		else:
			chosen_action = get_best_action_index(scores)

		var target_location: int = tf_poi
		if chosen_action == 6 and target_location not in [20, 12, 13, 22]:
			target_location = 20
		elif target_location <= 0 or target_location > 25:
			target_location = get_location_by_action(chosen_action, food_count, lunchbox_count, home_id, job_id)

		return {
			"best_action": chosen_action,
			"best_action_name": get_action_name(chosen_action),
			"target_location": target_location,
			"scores": scores,
			"poi_scores": tf_res.get("poi_scores", []),
			"is_rule_override": false,
			"override_reason": "",
			"decision_mechanism": "pure_transformer"
		}
	return {}

# ------------------------------------------------------------------------------
# 6. 行動與地點映射 (Action to Location Mapping)
# ------------------------------------------------------------------------------

## 依據行為代碼與物資決定目標地點 (對照表設計規則)
func get_location_by_action(
	action_index: int,
	food_count: int,
	lunchbox_count: int,
	home_id: int,
	_job_id: int
) -> int:
	match action_index:
		0: # 閒逛
			# 較高機率前往社交廣場 (20)，其餘隨機地圖 1~25
			var r: int = randi_range(1, 25)
			return 20 if r >= 20 else r
		1: # 閱讀 -> 19 (圖書館)
			return 19
		2: # 購物 -> 13 (餐廳) 或 12 (商店)
			return 12 if (randi() % 2 == 0) else 13
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

func _check_job_work_time(
	tick: int,
	job_id: int,
	stats: PackedFloat32Array,
	home_id: int = 0,
	npc_id: String = "",
	is_resting: bool = false
) -> Dictionary:
	# 若體力過低 (< 25) 或健康度過低 (< 25)，或正在休養且體力未達 75，不強制上班
	var stamina: float = stats[2] if stats.size() > 2 else 50.0
	var health: float = stats[1] if stats.size() > 1 else 50.0
	if is_resting and stamina < 75.0:
		return {"is_working": false}
	if stamina < 25.0 or health < 25.0:
		return {"is_working": false}

	if not JOB_SCHEDULES.has(job_id):
		return {"is_working": false}

	var job_info: Dictionary = JOB_SCHEDULES[job_id]
	var poi: int = job_info.get("poi", 0)

	# 醫護人員專用輪班制 (早班 07:00~15:00 Ticks 420~900 / 晚班 14:00~22:00 Ticks 840~1320)
	if job_id == 5:
		var is_late_shift: bool = (npc_id == "npc_10" or home_id == 9)
		var s_start: int = 840 if is_late_shift else 420
		var s_end: int = 1320 if is_late_shift else 900
		var shift_name: String = "晚班" if is_late_shift else "早班"
		if tick >= s_start and tick < s_end:
			return {
				"is_working": true,
				"poi": poi,
				"action": 7,
				"job_name": "醫護人員 (%s)" % shift_name
			}
		return {"is_working": false}

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

# ------------------------------------------------------------------------------
# 9. 社交互動決策服務 (Social Decision Evaluation)
# ------------------------------------------------------------------------------

const SOCIAL_ACTION_NAMES: Array[String] = [
	"無",
	"普通聊天",
	"討論主題",
	"詢問問題",
	"共同活動",
	"捉弄",
	"欺騙",
	"訊息傳播"
]

## 檢查社交 ONNX 推論引擎 (Social Transformer 或 社交 MLP) 是否成功就緒
func is_social_engine_available() -> bool:
	return _use_csharp_onnx and _csharp_bridge != null and (bool(_csharp_bridge.get("IsSocialInitialized")) or _use_social_transformer)

## 檢查是否啟用 Social Transformer 決策大腦
func is_social_transformer_active() -> bool:
	return _use_social_transformer

## 評估單一對象的社交互動意願 (0.0 ~ 1.0)
func evaluate_social(
	time: float,
	social_desire: float,
	mood: float,
	favorability: float,
	distance: float,
	days_since_interaction: float,
	history_score: float = 0.5
) -> float:
	if is_social_engine_available():
		return float(_csharp_bridge.EvaluateSocial(
			time, social_desire, mood, favorability, distance, days_since_interaction, history_score
		))
	return 0.0

## 批次評估多位候選 NPC 並透過加權輪盤選出最佳互動目標
## 支援優先調用 Causal Social Transformer (端到端指針選人 + 行為預測) 或經典 MLP 引擎
func evaluate_social_candidates(
	time: float,
	social_desire: float,
	mood: float,
	candidates: Array,
	stamina: float = 50.0,
	initiator_job_id: int = 9
) -> Dictionary:
	if is_social_engine_available():
		return _csharp_bridge.EvaluateSocialCandidates(time, social_desire, mood, candidates, stamina, initiator_job_id)
	return {
		"target_id": -1,
		"highest_target_id": -1,
		"highest_score": 0.0,
		"score": 0.0,
		"candidate_scores": {},
		"candidate_probs": {}
	}

## 決定具體社交行為代碼 (1~7)
## 1=普通聊天, 2=討論主題, 3=詢問問題, 4=共同活動, 5=捉弄, 6=欺騙, 7=訊息傳播
## 依據目標好感度 (favorability) 與當前心情 (mood) 進行啟發式決策，產出高因果性資料供 Transformer 訓練
func decide_social_action(
	target_id: int,
	has_spread_message: bool = false,
	favorability: float = 50.0,
	mood: float = 50.0
) -> int:
	if is_social_engine_available():
		if _csharp_bridge.has_method("DecideSocialActionHeuristic"):
			return int(_csharp_bridge.DecideSocialActionHeuristic(target_id, has_spread_message, favorability, mood))
		elif _csharp_bridge.has_method("DecideSocialAction"):
			return int(_csharp_bridge.DecideSocialAction(target_id, has_spread_message, favorability, mood))

	if target_id <= 0:
		return 0
	if has_spread_message:
		return 7

	# GDScript 原生雙引擎同步啟發式階層機率分佈
	if favorability < 35.0:
		var roll: int = randi_range(1, 100)
		if mood < 40.0:
			if roll <= 40: return 5
			if roll <= 70: return 6
			if roll <= 90: return 3
			return 1
		else:
			if roll <= 50: return 3
			if roll <= 80: return 1
			if roll <= 90: return 5
			return 6
	elif favorability >= 65.0:
		var roll: int = randi_range(1, 100)
		if mood >= 50.0:
			if roll <= 50: return 4
			if roll <= 80: return 2
			if roll <= 95: return 1
			return 3
		else:
			if roll <= 45: return 2
			if roll <= 80: return 1
			if roll <= 95: return 3
			return 4
	else:
		var roll: int = randi_range(1, 100)
		if roll <= 70: return 1
		if roll <= 90: return 3
		if roll <= 97: return 2
		return 4

## 取得社交行為中文名稱
func get_social_action_name(action_id: int) -> String:
	if action_id >= 0 and action_id < SOCIAL_ACTION_NAMES.size():
		return SOCIAL_ACTION_NAMES[action_id]
	return "未知"

# ------------------------------------------------------------------------------
# 10. 記憶資料庫與啟動載入服務 (Memory Database & Startup Service)
# ------------------------------------------------------------------------------
# 10. 記憶資料庫與圖 1 啟動載入 API (Memory Database & Startup APIs)
# ------------------------------------------------------------------------------

## 當前活動的 SQLite 記憶資料庫路徑 (預設寫入 user://saves/active_memory.db，避免打包後唯讀崩潰與多存檔記憶污染)
var active_db_path: String = "user://saves/active_memory.db"

## 設定當前活動資料庫路徑
func set_active_database_path(path: String) -> void:
	if not path.is_empty():
		active_db_path = path

## 取得當前活動資料庫路徑
func get_active_database_path() -> String:
	return active_db_path

## 釋放 SQLite 連線池佔用的檔案控制代碼
func clear_database_connections() -> void:
	if is_database_available() and _csharp_bridge.has_method("ClearDatabaseConnections"):
		_csharp_bridge.ClearDatabaseConnections()

## 複製/備份 SQLite 資料庫檔案
func copy_database(src_path: String, dst_path: String) -> bool:
	if is_database_available() and _csharp_bridge.has_method("CopyDatabase"):
		return bool(_csharp_bridge.CopyDatabase(src_path, dst_path))
	return false

## 檢查 C# 橋接是否具備資料庫功能
func is_database_available() -> bool:
	return _csharp_bridge != null and _csharp_bridge.has_method("InitializeMemoryDatabase")

## 初始化所有記憶資料庫 (對應圖 1: 初始化所有資料庫 STSM, MTSM, LTSM, STM, MTM, LTM)
func initialize_memory_database(db_path: String = "", force_reset: bool = false) -> bool:
	if is_database_available():
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return bool(_csharp_bridge.InitializeMemoryDatabase(target, force_reset))
	return false

## 檢查資料庫檔案是否存在
func has_memory_database(db_path: String = "") -> bool:
	var target: String = db_path if not db_path.is_empty() else active_db_path
	if is_database_available():
		return bool(_csharp_bridge.HasMemoryDatabase(target))
	return FileAccess.file_exists(target)

## 依據圖 1 (讀取存檔)，從 MTM, LTM, LTSM 載入資料並計算歷史分數
func load_npc_startup_data(npc_id: int, db_path: String = "") -> Dictionary:
	if is_database_available():
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return _csharp_bridge.LoadNPCStartupData(npc_id, target)
	return {}

## 依據圖 1 (新開局)，將使用者設定的詞條存入 LTM
func store_npc_entry(npc_id: int, traits_dict: Dictionary, db_path: String = "") -> bool:
	if is_database_available():
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return bool(_csharp_bridge.StoreNPCEntry(npc_id, traits_dict, target))
	return false

# ------------------------------------------------------------------------------
# 11. 圖 2、圖 4 與圖 5 執行期記憶寫入與換日結算服務
# ------------------------------------------------------------------------------

## 依據圖 2：計算一般行動數值增減並儲存至 STM
func save_normal_action_memory(
	npc_id: int,
	time: int,
	stats: Dictionary,
	action: int,
	location: int,
	is_success: bool,
	db_path: String = ""
) -> Dictionary:
	if is_database_available() and _csharp_bridge.has_method("SaveNormalActionMemory"):
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return _csharp_bridge.SaveNormalActionMemory(npc_id, time, stats, action, location, is_success, target)
	return {}

## 依據圖 4：計算社交互動數值增減並儲存雙向記憶至 STSM
func save_social_action_memory(
	source_id: int,
	target_id: int,
	time: int,
	social_action: int,
	source_social: Dictionary,
	target_social: Dictionary,
	db_path: String = ""
) -> Dictionary:
	if is_database_available() and _csharp_bridge.has_method("SaveSocialActionMemory"):
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return _csharp_bridge.SaveSocialActionMemory(source_id, target_id, time, social_action, source_social, target_social, target)
	return {}

## 依據圖 5：執行午夜換日結算前半 (步驟 1~5: SettleSTM -> SettleMTSM -> SettleSTSM)
func execute_midnight_settlement_1(db_path: String = "") -> bool:
	if is_database_available() and _csharp_bridge.has_method("ExecuteMidnightSettlement1"):
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return bool(_csharp_bridge.ExecuteMidnightSettlement1(target))
	return false

## 依據圖 5：執行午夜換日結算後半 (步驟 6~10: SaveState -> LoadHistoryEvent -> LoadActionWeights)
func execute_midnight_settlement_2(
	npc_id: int,
	current_stats: Dictionary,
	current_trust: Dictionary,
	current_friendships: Dictionary,
	db_path: String = ""
) -> Dictionary:
	if is_database_available() and _csharp_bridge.has_method("ExecuteMidnightSettlement2"):
		var target: String = db_path if not db_path.is_empty() else active_db_path
		return _csharp_bridge.ExecuteMidnightSettlement2(npc_id, current_stats, current_trust, current_friendships, target)
	return {}

## 內部輔助：基於權重的輪盤抽樣 (純 GDScript 備用)
func _sample_action_with_weights(scores: PackedFloat32Array, weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	var weighted: PackedFloat32Array = PackedFloat32Array()
	weighted.resize(scores.size())
	for i in range(scores.size()):
		var w: float = weights[i] if i < weights.size() else 1.0
		var s: float = maxf(0.0, scores[i] * w)
		weighted[i] = s
		total += s
	if total <= 0.0:
		return get_best_action_index(scores)
	var r: float = randf() * total
	var cum: float = 0.0
	for i in range(weighted.size()):
		cum += weighted[i]
		if r <= cum:
			return i
	return 0


