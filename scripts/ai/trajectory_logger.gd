# ==============================================================================
# 26號宇宙 (Universe 26) - Transformer 決策軌跡收集器 (Trajectory Logger)
# 檔案路徑: res://scripts/ai/trajectory_logger.gd
# 職責描述:
#   1. 收集日常行為與雙向社交決策數據，輸出為高因果性的 JSON Lines (.jsonl) 格式
#   2. 採用記憶體緩衝區 (Buffer) 批次寫入，確保在 60 倍速下流暢無阻不掉幀
#   3. 整合 SocialSemantics，自動標記社交意圖、關係標籤、八卦情報與 LLM 介面
# ==============================================================================
class_name TrajectoryLogger
extends RefCounted

## 是否正在錄製軌跡
var is_logging: bool = true

## 目前錄製的檔案路徑
var current_filepath: String = ""

## 內部記憶體緩衝隊列
var _buffer: Array[String] = []
const BUFFER_FLUSH_THRESHOLD: int = 15

## 檔案寫入句柄
var _file: FileAccess = null

## 關聯的社交語意與 LLM 接口
var social_semantics: SocialSemantics = null

## 當前局次 ID
var episode_id: String = ""

## 累計記錄步數
var total_steps_logged: int = 0

func _init() -> void:
	social_semantics = SocialSemantics.new()
	_start_new_episode()

## 啟動新錄製局次 (Episode)
func _start_new_episode(custom_id: String = "") -> void:
	flush()
	if _file:
		_file.close()
		_file = null

	var dir_path: String = "user://trajectories" if not OS.has_feature("editor") else "res://data/trajectories"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var time_str: String = "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]
	]
	episode_id = custom_id if not custom_id.is_empty() else "ep_%s" % time_str
	current_filepath = "%s/%s.jsonl" % [dir_path, episode_id]

	_file = FileAccess.open(current_filepath, FileAccess.WRITE_READ)
	if _file:
		print("[TrajectoryLogger] 成功建立 Transformer 軌跡資料集檔案: %s" % current_filepath)
	else:
		printerr("[TrajectoryLogger] 無法建立軌跡檔案: %s" % current_filepath)

## 切換錄製開關
func toggle_logging() -> bool:
	is_logging = not is_logging
	if not is_logging:
		flush()
	print("[TrajectoryLogger] 軌跡錄製狀態切換為: %s" % ("開啟 [ON]" if is_logging else "暫停 [OFF]"))
	return is_logging

# ------------------------------------------------------------------------------
# 1. 日常行為決策步記錄 (Normal Action Step)
# ------------------------------------------------------------------------------

func log_normal_action_step(
	npc_data: NPCData,
	current_tick: int,
	current_day: int,
	decision: Dictionary,
	exec_result: Dictionary = {}
) -> void:
	if not is_logging or npc_data == null:
		return

	var time_str: String = "%02d:%02d" % [current_tick / 60, current_tick % 60]
	var period_str: String = _get_period_name(current_tick / 60)
	var action_id: int = int(decision.get("best_action", 0))
	var action_name: String = String(decision.get("best_action_name", "閒逛"))
	var target_poi: int = int(decision.get("target_location", 0))

	# 判斷決策機制
	var mechanism: String = String(decision.get("decision_mechanism", "ai_mlp"))
	if bool(decision.get("is_rule_override", false)):
		mechanism = "rule_override"
	elif bool(decision.get("is_work_schedule", false)):
		mechanism = "work_schedule"

	var record: Dictionary = {
		"step_type": "normal_decision",
		"episode_id": episode_id,
		"day": current_day,
		"tick": current_tick,
		"time_str": time_str,
		"period": period_str,
		"npc_id": npc_data.npc_id,
		"npc_name": npc_data.npc_name,
		"job_id": npc_data.job_id,
		"ltm_traits": npc_data.get_active_ltm_trait_labels(),
		"action_weights": npc_data.action_weights.duplicate(),
		"state": {
			"vitals": {
				"hp": npc_data.hp,
				"health": npc_data.health,
				"stamina": npc_data.stamina,
				"hunger": npc_data.hunger,
				"social_desire": npc_data.social_desire,
				"mood": npc_data.mood,
				"money": npc_data.money
			},
			"inventory": {
				"food": npc_data.food,
				"lunchbox": npc_data.lunchbox,
				"crops": npc_data.crops,
				"wood": npc_data.wood,
				"stone": npc_data.stone,
				"mineral": npc_data.mineral,
				"fish": npc_data.fish
			},
			"location": {
				"home_poi": npc_data.home_poi_id,
				"target_poi": target_poi
			},
			"recent_memories": npc_data.stm_events.slice(0, 3)
		},
		"action": {
			"decision_category": "normal",
			"action_id": action_id,
			"action_name": action_name,
			"target_poi": target_poi,
			"decision_mechanism": mechanism,
			"override_reason": String(decision.get("override_reason", "")),
			"policy_scores": decision.get("scores", PackedFloat32Array())
		},
		"transition": {
			"is_success": bool(exec_result.get("success", true)),
			"delta_vitals": {
				"delta_hp": float(exec_result.get("change_hp", 0)),
				"delta_stamina": float(exec_result.get("change_stamina", 0)),
				"delta_hunger": float(exec_result.get("change_hunger", 0)),
				"delta_mood": float(exec_result.get("change_mood", 0)),
				"delta_money": int(exec_result.get("change_money", 0))
			},
			"instant_reward": float(exec_result.get("reward_value", 0.0))
		}
	}

	_push_record(record)

# ------------------------------------------------------------------------------
# 2. 雙向社交互動步記錄 (Social Interaction Step)
# ------------------------------------------------------------------------------

func log_social_interaction_step(
	source_ctrl: NPCController,
	target_ctrl: NPCController,
	current_tick: int,
	current_day: int,
	social_action_id: int,
	action_name: String,
	phase: String,
	s_changes: Dictionary,
	t_changes: Dictionary,
	candidates_radar: Array[Dictionary] = []
) -> void:
	if not is_logging or source_ctrl == null or target_ctrl == null:
		return
	if source_ctrl.npc_data == null or target_ctrl.npc_data == null:
		return

	var s_data: NPCData = source_ctrl.npc_data
	var t_data: NPCData = target_ctrl.npc_data
	var time_str: String = "%02d:%02d" % [current_tick / 60, current_tick % 60]
	var period_str: String = _get_period_name(current_tick / 60)

	var s_fav: float = s_data.get_friendship(t_data.npc_id)
	var s_trust: float = s_data.get_trust(t_data.npc_id)
	var t_fav: float = t_data.get_friendship(s_data.npc_id)
	var t_trust: float = t_data.get_trust(s_data.npc_id)

	# 取得社交語意與話題
	var topic: String = "日常隨筆交流"
	var rel_label: String = "點頭之交"
	if social_semantics:
		rel_label = social_semantics.get_relationship_label(s_fav, s_trust)
		topic = social_semantics.generate_topic(s_data.job_id, t_data.job_id, social_action_id, phase, s_fav, s_data.mood)

	# 構建預留之 LLM Prompt 格式字典
	var llm_context: Dictionary = {}
	if social_semantics:
		llm_context = social_semantics.build_llm_prompt_context(
			s_data.npc_id, s_data.npc_name, s_data.job_id,
			t_data.npc_id, t_data.npc_name, t_data.job_id,
			s_fav, s_trust, action_name, phase, topic, time_str
		)

	# 若有八卦或特殊社交事件，註冊進小鎮傳聞庫供擴散
	if social_semantics and (social_action_id == 4 or social_action_id == 5):
		var evt_name: String = "一起進行共同活動" if social_action_id == 4 else "開了捉弄人的玩笑"
		social_semantics.add_rumor(s_data.npc_name, t_data.npc_name, evt_name, current_day, current_tick)

	var record: Dictionary = {
		"step_type": "social_interaction",
		"episode_id": episode_id,
		"day": current_day,
		"tick": current_tick,
		"time_str": time_str,
		"period": period_str,
		"initiator": {
			"npc_id": s_data.npc_id,
			"npc_name": s_data.npc_name,
			"job_id": s_data.job_id,
			"vitals": {
				"mood": s_data.mood,
				"social_desire": s_data.social_desire,
				"stamina": s_data.stamina
			},
			"ltm_traits": s_data.get_active_ltm_trait_labels()
		},
		"receiver": {
			"npc_id": t_data.npc_id,
			"npc_name": t_data.npc_name,
			"job_id": t_data.job_id,
			"vitals": {
				"mood": t_data.mood,
				"social_desire": t_data.social_desire,
				"stamina": t_data.stamina
			},
			"ltm_traits": t_data.get_active_ltm_trait_labels()
		},
		"social_context": {
			"candidates_radar": candidates_radar.slice(0, 3), # 32 格內雷達前 3 名
			"relationship_tag": rel_label,
			"topic": topic,
			"phase": phase,
			"prior_favorability": s_fav,
			"prior_trust": s_trust
		},
		"action": {
			"decision_category": "social",
			"action_id": 6, # 社交
			"social_action_id": social_action_id,
			"social_action_name": action_name,
			"target_npc_id": t_data.npc_id,
			"target_npc_name": t_data.npc_name,
			"decision_mechanism": "onnx_social_eval_and_heuristic"
		},
		"transition": {
			"initiator_delta": {
				"delta_favorability": float(s_changes.get("change_favorability", 0)),
				"delta_trust": float(s_changes.get("change_trust", 0)),
				"delta_mood": float(s_changes.get("change_mood", 0)),
				"delta_stamina": float(s_changes.get("change_stamina", 0))
			},
			"receiver_delta": {
				"delta_favorability": float(t_changes.get("change_favorability", 0)),
				"delta_trust": float(t_changes.get("change_trust", 0)),
				"delta_mood": float(t_changes.get("change_mood", 0)),
				"delta_stamina": float(t_changes.get("change_stamina", 0))
			},
			"resulting_favorability": s_data.get_friendship(t_data.npc_id),
			"resulting_trust": s_data.get_trust(t_data.npc_id),
			"stsm_type": 1 if (float(s_changes.get("change_favorability", 0)) + float(s_changes.get("change_mood", 0)) > 0) else (-1 if social_action_id in [5, 6] else 0)
		},
		"llm_hook_context": llm_context # 預留掛載 LLM 或導出 SFT 訓練資料
	}

	_push_record(record)

# ------------------------------------------------------------------------------
# 3. 亡故終端事件記錄 (Death Terminal Step)
# ------------------------------------------------------------------------------

func log_death_step(
	ctrl: NPCController,
	current_tick: int,
	current_day: int,
	death_cause_str: String
) -> void:
	if not is_logging or ctrl == null or ctrl.npc_data == null:
		return

	var npc_data: NPCData = ctrl.npc_data
	var time_str: String = "%02d:%02d" % [current_tick / 60, current_tick % 60]
	var period_str: String = _get_period_name(current_tick / 60)
	var nav = ctrl._get_nav_manager()
	var grid_pos: Vector2i = nav.local_to_map(ctrl.global_position) if nav else Vector2i.ZERO

	var record: Dictionary = {
		"step_type": "death_event",
		"episode_id": episode_id,
		"day": current_day,
		"tick": current_tick,
		"time_str": time_str,
		"period": period_str,
		"npc_id": npc_data.npc_id,
		"npc_name": npc_data.npc_name,
		"job_id": npc_data.job_id,
		"ltm_traits": npc_data.get_active_ltm_trait_labels(),
		"state": {
			"vitals": {
				"hp": npc_data.hp,
				"health": npc_data.health,
				"stamina": npc_data.stamina,
				"hunger": npc_data.hunger,
				"social_desire": npc_data.social_desire,
				"mood": npc_data.mood,
				"money": npc_data.money
			},
			"inventory": {
				"food": npc_data.food,
				"lunchbox": npc_data.lunchbox,
				"crops": npc_data.crops,
				"wood": npc_data.wood,
				"stone": npc_data.stone,
				"mineral": npc_data.mineral,
				"fish": npc_data.fish
			},
			"location": {
				"grid_position": [grid_pos.x, grid_pos.y],
				"home_poi": npc_data.home_poi_id,
				"last_target_poi": int(ctrl.last_decision.get("target_location", 0))
			},
			"recent_memories": npc_data.stm_events.slice(0, 3)
		},
		"death_info": {
			"cause": death_cause_str,
			"last_action_id": ctrl.current_action_id,
			"last_decision": ctrl.last_decision
		},
		"transition": {
			"is_success": false,
			"instant_reward": -1.0 # 終端強烈負向懲罰，供 Transformer 學習死亡規避
		}
	}

	_push_record(record)
	flush()

# ------------------------------------------------------------------------------
# 4. 緩衝寫入與檔案管理 (Buffer & Disk I/O)
# ------------------------------------------------------------------------------

func _push_record(dict: Dictionary) -> void:
	var json_line: String = JSON.stringify(dict)
	_buffer.append(json_line)
	total_steps_logged += 1

	if _buffer.size() >= BUFFER_FLUSH_THRESHOLD:
		flush()

## 強制刷新記憶體緩衝區至磁碟檔案
func flush() -> void:
	if _buffer.is_empty():
		return

	if _file == null and not current_filepath.is_empty():
		_file = FileAccess.open(current_filepath, FileAccess.READ_WRITE)
		if _file:
			_file.seek_end()

	if _file:
		for line in _buffer:
			_file.store_line(line)
		_file.flush()
	_buffer.clear()

func close() -> void:
	flush()
	if _file:
		_file.close()
		_file = null

func _get_period_name(hour: int) -> String:
	if hour >= 5 and hour < 8:
		return "清晨"
	elif hour >= 8 and hour < 12:
		return "上午"
	elif hour >= 12 and hour < 14:
		return "中午"
	elif hour >= 14 and hour < 17:
		return "下午"
	elif hour >= 17 and hour < 20:
		return "傍晚"
	elif hour >= 20 and hour < 24:
		return "夜晚"
	else:
		return "深夜"

