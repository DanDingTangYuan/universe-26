# ==============================================================================
# 26號宇宙 (Universe 26) - NPC 控制器 (NPC Controller)
# 檔案路徑: res://scripts/entities/npc_controller.gd
# 職責描述: 
#   1. 繼承 CharacterBody2D，作為 NPC 實體核心邏輯控制器
#   2. 實作有限狀態機 (FSM: IDLE, MOVING, INTERACTING, WORKING, RESTING)
#   3. 封裝 A* 網格尋路與基於 Tween 的平滑逐格位移與 4 向走動動畫
#   4. 定期推進 NPCData 代謝，並調用 NPCDecisionService 驅動自主行為
# ==============================================================================
class_name NPCController
extends CharacterBody2D

# ------------------------------------------------------------------------------
# 1. 常數與狀態列舉 (Constants & State Enum)
# ------------------------------------------------------------------------------

enum State {
	IDLE, ## 待機
	MOVING, ## 尋路移動中
	INTERACTING, ## 社交或互動中
	WORKING, ## 崗位工作中
	RESTING ## 在家睡覺或醫院休養
}

const NavigationManagerClass = preload("res://scripts/core/navigation_manager.gd")
const NPCDataClass = preload("res://scripts/entities/npc_data.gd")
const DecisionServiceClass = preload("res://scripts/ai/decision_service.gd")

# ------------------------------------------------------------------------------
# 2. 訊號 (Signals)
# ------------------------------------------------------------------------------

## 狀態轉移時發射
signal state_changed(old_state: State, new_state: State)

## 到達尋路目標網格時發射
signal target_reached(destination_cell: Vector2i)

## 開始執行特定 AI 行為時發射
signal action_started(action_type: int, action_name: String, target_poi: int)

## 完成特定行為時發射
signal action_completed(action_type: int)

## 當玩家點擊此 NPC 時發射
signal clicked()

# ------------------------------------------------------------------------------
# 3. 節點與匯出屬性 (Exports & Node References)
# ------------------------------------------------------------------------------

## 綁定的 NPC 數據模型 (若未賦值，將在 _ready 自動實例化)
@export var npc_data: Resource = null

## 移動步進時間 (每走 1 格地塊所耗費秒數，數值越小跑越快)
@export var step_duration: float = 0.22

## 是否啟用 AI 自動決策驅動
@export var auto_ai_enabled: bool = true

## AI 決策週期 (每隔多少個 Tick 檢查一次新目標，預設 30 Ticks = 30 遊戲分鐘)
@export var decision_interval_ticks: int = 30

## 節點引用
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var bubble_node: Node2D = get_node_or_null("bubble") as Node2D

# ------------------------------------------------------------------------------
# 4. 內部運行狀態 (Runtime Variables)
# ------------------------------------------------------------------------------

var current_state: State = State.IDLE
var current_action_id: int = -1
var facing_direction: String = "down"

## 是否處於建築物或密林內部隱藏狀態
var is_concealed: bool = false

## 是否處於死亡/亡故狀態
var is_dead: bool = false

## 死亡原因 (例如 "飢餓衰竭", "體力枯竭")
var death_cause: String = ""

## 是否處於昏倒/昏厥倒地狀態
var is_fainted: bool = false

## 昏厥原因 (例如 "體力竭盡昏厥", "飢餓虛脫")
var fainted_cause: String = ""

## 昏厥持續累積 Ticks (超過門檻未獲救治可能導致傷重不治)
var fainted_elapsed_ticks: int = 0

## 醫護人員專用：是否正處於外勤緊急救援任務中
var is_rescuing: bool = false

## 當前執行中之急救事件資料
var _current_rescue_emergency: Dictionary = {}

## 是否正被其他 NPC 選定為社交對象 (避免多人同時鎖定同一人)
var is_social_target: bool = false

## 最近一次 AI 決策結果字典 (包含 best_action, target_location, scores, is_rule_override, override_reason)
var last_decision: Dictionary = {}

## 社交搜尋半徑 (像素，約 10 格地塊)
const MAX_SOCIAL_SEARCH_DIST: float = 160.0

## 社交面對面判定有效距離 (約 2 格以內)
const SOCIAL_INTERACT_DIST: float = 38.0

## 行動超時看門狗最大持續 Ticks (60 Ticks = 60 遊戲分鐘 = 1 遊戲小時)
const MAX_ACTION_TICKS: int = 60

## 社交鎖定超時保護最大持續 Ticks (15 Ticks = 15 遊戲分鐘，若發起方超時未達則解除鎖定)
const MAX_SOCIAL_TARGET_TICKS: int = 15

var _current_path: Array[Vector2i] = []
var _move_tween: Tween = null
var _last_decision_tick: int = -1
var _is_executing_action: bool = false
var _action_timer: float = 0.0
var _action_elapsed_ticks: int = 0
var _social_target_elapsed_ticks: int = 0
var _current_social_partner: NPCController = null
var _pending_step_index: int = -1
var _pending_on_complete: Callable = Callable()
var _last_evaluated_social_score: float = 0.5
var _last_candidates_eval: Dictionary = {}
var _action_memory_saved: bool = false

# ------------------------------------------------------------------------------
# 5. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	# 1. 確保數據模型就緒
	if npc_data == null:
		npc_data = NPCDataClass.new()
		npc_data.npc_id = name
		npc_data.npc_name = name

	if npc_data:
		if not npc_data.hp_depleted.is_connected(_on_hp_depleted):
			npc_data.hp_depleted.connect(_on_hp_depleted)
		if not npc_data.hunger_critical.is_connected(_on_hunger_critical):
			npc_data.hunger_critical.connect(_on_hunger_critical)

	# 2. 向全域單例註冊自身與監聽時間/暫停/倍速/午夜訊號
	var global_node: Node = _get_global()
	if global_node:
		global_node.register_npc(npc_data.npc_id, self)
		if not global_node.tick_passed.is_connected(_on_global_tick_passed):
			global_node.tick_passed.connect(_on_global_tick_passed)
		if not global_node.time_paused_toggled.is_connected(_on_global_time_paused_toggled):
			global_node.time_paused_toggled.connect(_on_global_time_paused_toggled)
		if not global_node.time_scale_changed.is_connected(_on_global_time_scale_changed):
			global_node.time_scale_changed.connect(_on_global_time_scale_changed)
		if not global_node.on_midnight_reached.is_connected(_on_midnight_reached):
			global_node.on_midnight_reached.connect(_on_midnight_reached)

	# 3. 初始化視圖
	if bubble_node:
		bubble_node.visible = false
	face_direction(facing_direction)

	# 4. 初次定位
	call_deferred("_initialize_position")

	# 5. 啟用點選感應
	_setup_click_detection()


func _exit_tree() -> void:
	if npc_data:
		if npc_data.hp_depleted.is_connected(_on_hp_depleted):
			npc_data.hp_depleted.disconnect(_on_hp_depleted)
		if npc_data.hunger_critical.is_connected(_on_hunger_critical):
			npc_data.hunger_critical.disconnect(_on_hunger_critical)

	# 卸載時從全域註銷
	var global_node: Node = _get_global()
	if global_node:
		global_node.unregister_npc(npc_data.npc_id)
		if global_node.tick_passed.is_connected(_on_global_tick_passed):
			global_node.tick_passed.disconnect(_on_global_tick_passed)
		if global_node.time_paused_toggled.is_connected(_on_global_time_paused_toggled):
			global_node.time_paused_toggled.disconnect(_on_global_time_paused_toggled)
		if global_node.time_scale_changed.is_connected(_on_global_time_scale_changed):
			global_node.time_scale_changed.disconnect(_on_global_time_scale_changed)
		if global_node.on_midnight_reached.is_connected(_on_midnight_reached):
			global_node.on_midnight_reached.disconnect(_on_midnight_reached)


func _process(delta: float) -> void:
	if is_dead:
		return

	var g: Node = _get_global()
	if g and g.is_time_paused:
		return

	# 處理工作或休息時的計時邏輯 (隨全域時間流速倍率縮放)
	var cur_scale: float = g.time_scale if g else 1.0
	if _action_timer > 0.0:
		_action_timer -= delta * cur_scale
		if _action_timer <= 0.0:
			_on_action_timer_finished()

## 響應全域暫停切換
func _on_global_time_paused_toggled(is_paused: bool) -> void:
	if is_dead:
		return
	if is_paused:
		if _move_tween and _move_tween.is_valid():
			_move_tween.pause()
		if animated_sprite and animated_sprite.is_playing():
			animated_sprite.pause()
	else:
		var g: Node = _get_global()
		var cur_scale: float = g.time_scale if g else 1.0
		if _move_tween and _move_tween.is_valid():
			_move_tween.set_speed_scale(cur_scale)
			_move_tween.play()
			if animated_sprite and not animated_sprite.is_playing() and current_state == State.MOVING:
				animated_sprite.play("walk_" + facing_direction)
		elif _pending_step_index >= 0:
			var step_idx: int = _pending_step_index
			var cb: Callable = _pending_on_complete
			_pending_step_index = -1
			_pending_on_complete = Callable()
			_step_move(step_idx, cb)

## 響應全域時間流速倍率變更
func _on_global_time_scale_changed(new_scale: float) -> void:
	if is_dead:
		return
	var g: Node = _get_global()
	if g and g.is_time_paused:
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.set_speed_scale(new_scale)

## 響應午夜記憶演化結算
func _on_midnight_reached(day: int) -> void:
	if npc_data:
		npc_data.evolve_midnight_memory(day)

# ------------------------------------------------------------------------------
# 6. 全域時間與代謝更新 (Tick Handling & Metabolism)
# ------------------------------------------------------------------------------

func _on_global_tick_passed(current_tick: int) -> void:
	if is_dead or npc_data == null:
		return

	# 0. 昏迷倒地狀態處理
	if is_fainted:
		fainted_elapsed_ticks += 1
		# 若昏迷過久且生命耗盡，超過 300 Ticks (5 遊戲小時) 未被及時施救，宣告傷重不治
		if fainted_elapsed_ticks >= 300 and npc_data.hp <= 0.0:
			die(fainted_cause if not fainted_cause.is_empty() else "昏迷重傷不治")
			return
		# 每隔 15 Ticks 冒出虛弱氣泡
		if fainted_elapsed_ticks % 15 == 0:
			show_speech_bubble("💫 昏迷中...", 2.0)
		return

	# 1. 根據目前狀態推進生理代謝
	var is_sleeping: bool = (current_state == State.RESTING)
	var is_working: bool = (current_state == State.WORKING)
	npc_data.tick_update(1, is_sleeping, is_working)

	# 生理極限昏厥檢查 (若體力跌至 0 且飽食度過低，非休養狀態下體力不支倒地)
	if npc_data.stamina <= 0.0 and npc_data.hunger < 15.0 and current_state != State.RESTING and not is_fainted:
		faint("極度過勞虛脫")
		return

	# 看門狗 1: 社交鎖定超時保護 (避免發起方途中受阻或被中斷導致對方永久定格)
	if is_social_target and current_state != State.INTERACTING:
		_social_target_elapsed_ticks += 1
		if _social_target_elapsed_ticks >= MAX_SOCIAL_TARGET_TICKS:
			is_social_target = false
			_social_target_elapsed_ticks = 0
	else:
		_social_target_elapsed_ticks = 0

	# 看門狗 2: 行動超時看門狗 (防止任何尋路、Tween 或協程未釋放導致 AI 決策被外層守衛永久阻斷)
	if _is_executing_action:
		_action_elapsed_ticks += 1
		if _action_elapsed_ticks >= MAX_ACTION_TICKS:
			push_warning("[NPCController] %s 行動超時 (%d Ticks)，強制中止並重置狀態！" % [npc_data.npc_id, _action_elapsed_ticks])
			_abort_and_reset_action()
	else:
		_action_elapsed_ticks = 0

	# 生理飢餓強制自救中斷 (Emergency Survival Interrupt)
	# 若飽食度跌破 20.0 且目前未在進食中，無論任何常規/工作/社交行動立即強制中斷自救
	if npc_data.hunger < 20.0 and current_action_id != 3 and not is_rescuing:
		_handle_emergency_starvation(current_tick)
		return

	# 2. 路人巡視周遭：非隱藏且未出診狀態下，週期性檢查身邊是否有倒地昏迷者並自主通報
	if not is_concealed and not is_rescuing and (current_tick % 3 == 0):
		_check_and_report_nearby_emergencies()

	# 3. 醫護人員專用：當班執勤且醫院當前無病患時，自主出診救援倒地市民
	if npc_data.job_id == 5 and not is_rescuing:
		_check_doctor_rescue_duty(current_tick)

	# 4. 自動決策判斷
	if auto_ai_enabled and not _is_executing_action and not is_social_target and not is_rescuing and not is_fainted:
		# 若目前處於休息狀態 (如夜間就寢或休養中)，且尚未到晨起時間，不進行反覆決策
		if current_state == State.RESTING:
			if _is_bedtime_hour(current_tick) or (npc_data and npc_data.stamina < 75.0 and current_action_id == 5):
				return # 繼續安穩睡眠休養，不發起新決策亦不重複寫入記憶
			else:
				# 晨起 (06:00) 或體力恢復充足，甦醒切換至 IDLE 準備迎接新的一天
				if is_concealed:
					exit_building()
				set_state(State.IDLE)
				current_action_id = 0

		# 每隔一定 Ticks 或目前處於閒置狀態時觸發 AI 決策
		if current_state == State.IDLE or (_last_decision_tick < 0) or (current_tick - _last_decision_tick >= decision_interval_ticks):
			_last_decision_tick = current_tick
			make_decision(current_tick)

# ------------------------------------------------------------------------------
# 7. AI 決策大腦連結與行為執行 (AI Decision & Execution)
# ------------------------------------------------------------------------------

## 觸發一次 AI 決策
func make_decision(current_tick: int) -> void:
	if is_dead or is_fainted or is_social_target or is_rescuing:
		return

	var global_node: Node = _get_global()
	if global_node == null or npc_data == null:
		return

	var decision_service: DecisionServiceClass = global_node.get_decision_service()
	if decision_service == null:
		return

	# 呼叫決策大腦 (融合排程規則 + 15 維度神經模型 + LTM 行動權重抽樣 + 體力休養遲滯保護)
	var is_resting: bool = (current_state == State.RESTING or current_action_id == 5 or (npc_data != null and npc_data.is_exhausted))
	var decision: Dictionary = decision_service.evaluate_decision(
		current_tick,
		npc_data.to_feature_vector(),
		npc_data.home_poi_id,
		npc_data.job_id,
		npc_data.food,
		npc_data.lunchbox,
		npc_data.personality_offset,
		npc_data.npc_id,
		npc_data.action_weights,
		is_resting,
		current_action_id
	)

	last_decision = decision
	_action_memory_saved = false

	var action_id: int = int(decision.get("best_action", 0))
	var action_name: String = String(decision.get("best_action_name", "閒逛"))
	var target_poi: int = int(decision.get("target_location", 0))

	# 廣播全域與本體事件
	action_started.emit(action_id, action_name, target_poi)
	current_action_id = action_id

	# 執行相應行為
	_execute_action(action_id, target_poi)


## 執行特定決策行為
func _execute_action(action_id: int, target_poi: int) -> void:
	if is_dead or is_fainted or is_rescuing:
		return

	_is_executing_action = true
	_action_elapsed_ticks = 0

	# 檢查是否為官方工作排程 (依據決策系統之工作判定，且目標為指定工作 POI)
	var is_work_duty: bool = last_decision.get("is_work_schedule", false) or last_decision.get("best_action_name", "").begins_with("執勤工作")
	if is_work_duty and target_poi in [12, 13, 14, 15, 16, 17, 18, 19]:
		_execute_work(npc_data.job_id if npc_data else 1, target_poi)
		return

	match action_id:
		0: # 閒逛 (若神經模型有指定景點/廣場 POI 則前往該區域漫遊，否則原地鄰近閒逛)
			if target_poi > 0:
				_move_to_poi_and_act(target_poi, State.IDLE, 5.0, func():
					if npc_data:
						npc_data.mood = clampf(npc_data.mood + 6.0, 0.0, 100.0)
						npc_data.stamina = clampf(npc_data.stamina - 2.0, 0.0, 100.0)
						npc_data.stats_changed.emit(npc_data.npc_id)
				)
			else:
				_execute_wander()
		1: # 閱讀 (圖書館 POI 19)
			_move_to_poi_and_act(target_poi, State.WORKING, 8.0, func():
				show_bubble(2.5)
				if npc_data:
					npc_data.mood = clampf(npc_data.mood + 20.0, 0.0, 100.0)
					npc_data.stamina = clampf(npc_data.stamina - 1.0, 0.0, 100.0) # 閱讀屬靜態活動，微量消耗體力
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		2: # 購物 (餐廳 POI 13 或 商店 POI 12 - 依據 Google 道具表：料理與便當各 $3)
			_move_to_poi_and_act(target_poi, State.INTERACTING, 5.0, func():
				show_bubble(2.0)
				if npc_data:
					if target_poi == 13: # 餐廳：購買便當或料理 ($3)
						if npc_data.money >= 3:
							npc_data.consume_item("money", 3)
							npc_data.add_item("lunchbox", 1)
						elif npc_data.money >= 3:
							npc_data.consume_item("money", 3)
							npc_data.add_item("food", 1)
					else: # 商店 POI 12：購買食材料理 ($3)
						if npc_data.money >= 3:
							npc_data.consume_item("money", 3)
							npc_data.add_item("food", 1)
						elif npc_data.money >= 3:
							npc_data.consume_item("money", 3)
							npc_data.add_item("lunchbox", 1)
					npc_data.mood = clampf(npc_data.mood + 10.0, 0.0, 100.0)
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		3: # 吃東西 (依據 Google 道具表：餐廳料理/便當 $3，有存糧優先原地吃)
			if target_poi == 0:
				# 原地吃便當或料理
				_execute_eat_in_place()
			else:
				# 移動至餐廳進食
				_move_to_poi_and_act(target_poi, State.INTERACTING, 6.0, func():
					show_bubble(2.5)
					if npc_data:
						if npc_data.money >= 3:
							# 點餐享用正餐 (花費 $3)
							npc_data.consume_item("money", 3)
							npc_data.hunger = clampf(npc_data.hunger + 60.0, 0.0, 100.0)
							npc_data.stamina = clampf(npc_data.stamina + 35.0, 0.0, 100.0)
							npc_data.mood = clampf(npc_data.mood + 20.0, 0.0, 100.0)
							# 外帶備份糧食：若身上無便當且尚有餘額，順便購買 1 個外帶便當防餓
							if npc_data.money >= 3 and npc_data.lunchbox == 0:
								npc_data.consume_item("money", 3)
								npc_data.add_item("lunchbox", 1)
						elif npc_data.eat_food(true):
							# 身上有便當或料理，在餐廳座位上享用
							pass
						else:
							# 窮困或無餐點：餐廳提供基礎救濟愛心熱湯，避免餓死
							var pay: int = mini(npc_data.money, 1)
							if pay > 0:
								npc_data.consume_item("money", pay)
							npc_data.hunger = clampf(npc_data.hunger + 40.0, 0.0, 100.0)
							npc_data.stamina = clampf(npc_data.stamina + 20.0, 0.0, 100.0)
							npc_data.mood = clampf(npc_data.mood + 10.0, 0.0, 100.0)
						npc_data.stats_changed.emit(npc_data.npc_id)
				)
		4: # 就醫 (醫院 POI 18)
			_move_to_poi_and_act(target_poi, State.RESTING, 10.0, func():
				show_bubble(2.5)
				if npc_data:
					if npc_data.money >= 5:
						npc_data.consume_item("money", 5)
					npc_data.health = clampf(npc_data.health + 45.0, 0.0, 100.0)
					npc_data.hp = clampf(npc_data.hp + 35.0, 0.0, 100.0)
					npc_data.stamina = clampf(npc_data.stamina + 20.0, 0.0, 100.0)
					npc_data.hunger = clampf(npc_data.hunger + 25.0, 0.0, 100.0) # 醫院提供營養點滴與病患餐點
					npc_data.mood = clampf(npc_data.mood + 15.0, 0.0, 100.0)
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		5: # 回家休息 (自宅 POI)
			_move_to_poi_and_act(target_poi, State.RESTING, 12.0, func():
				show_bubble(2.0)
				if npc_data:
					npc_data.stamina = clampf(npc_data.stamina + 35.0, 0.0, 100.0)
					npc_data.mood = clampf(npc_data.mood + 15.0, 0.0, 100.0)
					if npc_data.health > 50.0:
						npc_data.hp = clampf(npc_data.hp + 15.0, 0.0, 100.0)
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		6: # 社交 (社交廣場或周邊 NPC)
			_execute_social_interaction(target_poi)
		7: # 巡田水 (農民專用 POI 16)
			_move_to_poi_and_act(target_poi, State.WORKING, 8.0, func():
				show_bubble(2.5)
				if npc_data:
					npc_data.add_item("crops", 1)
					npc_data.mood = clampf(npc_data.mood + 6.0, 0.0, 100.0)
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		8: # 販售物品 (商店 POI 12 - 依據 Google 道具表收購金額：農作物$5, 木頭$2, 礦物$2, 魚$2, 石頭$1)
			_move_to_poi_and_act(target_poi, State.WORKING, 6.0, func():
				show_bubble(2.5)
				if npc_data:
					var earned: int = 0
					if npc_data.crops > 0:
						var sold_c: int = npc_data.crops
						npc_data.consume_item("crops", sold_c)
						earned += sold_c * 5 # 表格：農作物 $5
					if npc_data.mineral > 0:
						var sold_m: int = npc_data.mineral
						npc_data.consume_item("mineral", sold_m)
						earned += sold_m * 2 # 表格：礦物 $2
					if npc_data.fish > 0:
						var sold_f: int = npc_data.fish
						npc_data.consume_item("fish", sold_f)
						earned += sold_f * 2 # 表格：魚 $2
					if npc_data.wood > 2:
						var sold_w: int = npc_data.wood - 2
						npc_data.consume_item("wood", sold_w)
						earned += sold_w * 2 # 表格：木頭 $2
					if npc_data.stone > 2:
						var sold_s: int = npc_data.stone - 2
						npc_data.consume_item("stone", sold_s)
						earned += sold_s * 1 # 表格：石頭 $1
					
					if earned > 0:
						npc_data.add_item("money", earned)
						npc_data.mood = clampf(npc_data.mood + 15.0, 0.0, 100.0)
					else:
						npc_data.add_item("money", 1)
						npc_data.mood = clampf(npc_data.mood + 5.0, 0.0, 100.0)
					npc_data.stats_changed.emit(npc_data.npc_id)
			)
		_:
			_is_executing_action = false
			set_state(State.IDLE)


## 崗位執勤工作行為
func _execute_work(job_id: int, poi: int) -> void:
	_move_to_poi_and_act(poi, State.WORKING, 8.0, func():
		# 抵達崗位，彈出工作氣泡並產生物資與代謝
		show_bubble(2.5)
		if npc_data:
			match job_id:
				1: # 礦工 -> 產出礦石與石頭
					npc_data.add_item("mineral", 1)
					npc_data.add_item("stone", 1)
				2: # 圖書館員 -> 整理書籍，獲取工資
					npc_data.add_item("money", 2)
				3: # 漁夫 -> 產出鮮魚
					npc_data.add_item("fish", 1)
				4: # 餐廳員工 -> 產出料理與便當
					npc_data.add_item("lunchbox", 1)
					npc_data.add_item("food", 1)
					npc_data.add_item("money", 3)
				5: # 醫護人員 -> 醫院工作
					npc_data.add_item("money", 5)
					# 醫院茶水間/員工餐補給：回復飽食度與健康
					npc_data.hunger = clampf(npc_data.hunger + 15.0, 0.0, 100.0)
					npc_data.health = clampf(npc_data.health + 5.0, 0.0, 100.0)
				6: # 伐木工 -> 產出木材
					npc_data.add_item("wood", 1)
				7: # 農民 -> 產出農作物
					npc_data.add_item("crops", 1)
				8: # 商店店長 -> 販售營業
					npc_data.add_item("money", 4)
			# 執勤工作之生理消耗由 tick_update (STAMINA_DECAY_WORK) 與 STM 結算平滑推進，不再進行單次重度扣除
			npc_data.stats_changed.emit(npc_data.npc_id)
	)


## 原地進食
func _execute_eat_in_place() -> void:
	if is_concealed:
		exit_building()
	set_state(State.INTERACTING)
	show_bubble(1.5)
	if npc_data:
		var ate: bool = npc_data.eat_food(true)
		if not ate:
			# 身上無現成餐點，食用手頭上的農作物或生鮮
			if npc_data.crops > 0:
				npc_data.consume_item("crops", 1)
				npc_data.hunger = clampf(npc_data.hunger + 25.0, 0.0, 100.0)
				npc_data.stamina = clampf(npc_data.stamina + 10.0, 0.0, 100.0)
			elif npc_data.fish > 0:
				npc_data.consume_item("fish", 1)
				npc_data.hunger = clampf(npc_data.hunger + 25.0, 0.0, 100.0)
				npc_data.stamina = clampf(npc_data.stamina + 10.0, 0.0, 100.0)
			else:
				# 摘野果應急充飢
				npc_data.hunger = clampf(npc_data.hunger + 15.0, 0.0, 100.0)
				npc_data.stamina = clampf(npc_data.stamina + 5.0, 0.0, 100.0)
		var g: Node = _get_global()
		var t_str: String = g.get_formatted_time() if g else ""
		npc_data.add_stm_event("%s 就地食用便當/糧食" % t_str)
		npc_data.stats_changed.emit(npc_data.npc_id)
	_action_timer = 1.5


## 閒逛行為：隨機在附近可通行且未被佔用地塊漫遊
func _execute_wander() -> void:
	if is_dead:
		return
	if is_concealed:
		exit_building()
	var nav = _get_nav_manager()
	if nav == null:
		_complete_current_action()
		return

	var cur_cell: Vector2i = nav.local_to_map(global_position)
	var target_cell: Vector2i = cur_cell

	# 嘗試尋找未被佔用的鄰格
	for attempt in range(8):
		var candidate: Vector2i = nav.get_random_walkable_neighbor(cur_cell, 4)
		if candidate != cur_cell and not _is_cell_occupied(candidate):
			target_cell = candidate
			break

	if target_cell == cur_cell:
		# 找不到合適鄰格，原地待機 2 秒
		set_state(State.IDLE)
		_action_timer = 2.0
		return

	move_along_grid(target_cell, func():
		# 到達後待機片刻再結束
		set_state(State.IDLE)
		if npc_data:
			npc_data.mood = clampf(npc_data.mood + 5.0, 0.0, 100.0)
			npc_data.stamina = clampf(npc_data.stamina - 2.0, 0.0, 100.0)
			npc_data.stats_changed.emit(npc_data.npc_id)
		_action_timer = 2.5
	)


## 前往特定 POI 並切換至目標狀態執行一段時間
func _move_to_poi_and_act(poi_id: int, target_state: State, duration: float, on_arrive: Callable = Callable()) -> void:
	if is_dead:
		return

	# 若當前處於隱藏狀態，先現身淡入
	if is_concealed:
		exit_building()

	var g: Node = _get_global()
	var poi_data: Dictionary = {}
	if g and g.has_method("get_poi_data"):
		poi_data = g.get_poi_data(poi_id)

	var target_cell: Vector2i = _get_poi_cell(poi_id)
	if target_cell == Vector2i(-1, -1):
		# 無此 POI 座標，降級為原地執行
		set_state(target_state)
		if on_arrive.is_valid():
			on_arrive.call()
		_action_timer = duration
		return

	var nav = _get_nav_manager()
	if nav:
		var cur_cell: Vector2i = nav.local_to_map(global_position)

		# 1. 多門模式：選取最近門口
		var doors: Array = poi_data.get("doors", [])
		if doors.size() > 0:
			var best_door: Vector2i = target_cell
			var min_dist: float = 999999.0
			for d in doors:
				if d is Array and d.size() >= 2:
					var dc := Vector2i(int(d[0]), int(d[1]))
					var dist := float(abs(dc.x - cur_cell.x) + abs(dc.y - cur_cell.y))
					if dist < min_dist:
						min_dist = dist
						best_door = dc
			target_cell = best_door

		# 2. 廣域/開放式 POI (如 POI 20 社交廣場或農田)：分散目標點，隨機挑選未被佔用之可通行地塊
		var walkable_cells: Array = poi_data.get("walkable_cells", [])
		var is_concealed_poi: bool = bool(poi_data.get("concealed", false))
		if walkable_cells.size() > 0 and not is_concealed_poi:
			var candidates: Array = walkable_cells.duplicate()
			candidates.shuffle()
			for cand in candidates:
				if cand is Array and cand.size() >= 2:
					var c := Vector2i(int(cand[0]), int(cand[1]))
					if nav.is_cell_walkable(c) and not _is_cell_occupied(c):
						target_cell = c
						break

		# 3. 範圍 / 半徑判定：若已在該設施範圍內，避免在內部反覆繞尋
		var radius: float = float(poi_data.get("radius", 0.0))
		var is_inside_area: bool = false
		if radius > 0.0 and Vector2(cur_cell).distance_to(Vector2(target_cell)) <= radius:
			is_inside_area = true

		if not is_inside_area and walkable_cells.size() > 0:
			for wc in walkable_cells:
				if wc is Array and wc.size() >= 2:
					if int(wc[0]) == cur_cell.x and int(wc[1]) == cur_cell.y:
						is_inside_area = true
						break

		if is_inside_area:
			set_state(target_state)
			if is_concealed_poi:
				enter_building(str(poi_data.get("entrance_dir", "south")))
			if poi_id == 22 or poi_id == 20 or poi_id == 12:
				_check_billboard_rumors(poi_id)
			if on_arrive.is_valid():
				on_arrive.call()
			_action_timer = duration
			return

	move_along_grid(target_cell, func():
		set_state(target_state)
		if poi_data.get("concealed", false):
			enter_building(str(poi_data.get("entrance_dir", "south")))
		if poi_id == 22 or poi_id == 20 or poi_id == 12:
			_check_billboard_rumors(poi_id)
		if on_arrive.is_valid():
			on_arrive.call()
		_action_timer = duration
	)

## 檢查並學習公佈欄上的新情報 (當 NPC 抵達專屬布告欄 POI 22 或 廣場/商店時)
func _check_billboard_rumors(poi_id: int) -> void:
	if npc_data == null or is_dead:
		return
	var g: Node = _get_global()
	if g == null or not g.has_method("get_diffusion_manager"):
		return
	var diff_mgr = g.get_diffusion_manager()
	if diff_mgr == null:
		return

	var billboard_rumors: Array[Dictionary] = diff_mgr.get_billboard_rumors()
	for r in billboard_rumors:
		var r_id: String = str(r.get("id", ""))
		if not npc_data.has_rumor(r_id):
			# 若專門前來布告欄 (POI 22) 則 100% 閱讀；若只是路過廣場/商店則 35% 機率駐足閱讀
			var read_chance: float = 1.0 if (poi_id == 22) else 0.35
			if randf() <= read_chance:
				var cur_day: int = _get_current_day()
				var cur_tick: int = _get_current_tick()
				var s_name: String = npc_data.npc_name if not npc_data.npc_name.is_empty() else name
				var ok: bool = npc_data.learn_rumor(r, "billboard", "小鎮布告欄", cur_day, cur_tick, 1)
				if ok:
					diff_mgr.record_spread(r_id, "billboard", "小鎮布告欄", npc_data.npc_id, s_name, cur_day, cur_tick, poi_id, 0)
					show_speech_bubble("📋 閱覽布告欄公告...", 3.0)
					# [保留接口] 未來切換不同氣泡 frame / 圖像時取消以下註解：
					# set_bubble_frame(3) # 閱讀公佈欄氣泡
					break


## 社交互動行為 (防重疊、獨立站位、距離防呆、互斥鎖定)
func _execute_social_interaction(target_poi: int) -> void:
	if is_dead:
		return
	if is_concealed:
		exit_building()

	# 1. 搜尋視野/近距離內的可用待機對象
	var other_npc: NPCController = _find_available_partner()
	if other_npc and is_instance_valid(other_npc):
		var dist_to_partner: float = global_position.distance_to(other_npc.global_position)

		# 若已在身旁 (2 格以內)，直接展開對話
		if dist_to_partner <= SOCIAL_INTERACT_DIST:
			_start_mutual_conversation(other_npc)
			return

		# 鎖定目標，避免其他 NPC 同時鎖定或目標在短時間內切換行為
		other_npc.is_social_target = true
		other_npc.face_toward(global_position)
		_current_social_partner = other_npc

		var nav = _get_nav_manager()
		if nav:
			var partner_cell: Vector2i = nav.local_to_map(other_npc.global_position)
			var stand_cell: Vector2i = _get_free_adjacent_cell(partner_cell)
			if stand_cell != Vector2i(-1, -1):
				# 發射事件通知 UI 顯示為「前往社交」
				action_started.emit(6, "前往社交", target_poi)
				move_along_grid(stand_cell, func():
					if not is_instance_valid(other_npc) or other_npc.is_dead or other_npc.is_concealed:
						if is_instance_valid(other_npc):
							other_npc.is_social_target = false
						_current_social_partner = null
						_complete_current_action()
						return

					# 抵達後防呆：確認對方是否仍在身旁 (在有效距離內)
					var actual_dist: float = global_position.distance_to(other_npc.global_position)
					if actual_dist <= SOCIAL_INTERACT_DIST:
						_start_mutual_conversation(other_npc)
					else:
						# 若對方已不在身旁，不進入社交中狀態，安全釋放鎖定
						other_npc.is_social_target = false
						_current_social_partner = null
						set_state(State.IDLE)
						_action_timer = 2.0
				)
				return
			else:
				# 找不到合適相鄰站格，釋放鎖定
				other_npc.is_social_target = false
				_current_social_partner = null

	# 2. 周遭無合適對象：前往社交廣場 (POI 20) 散步尋友
	action_started.emit(6, "前往社交", target_poi)
	_move_to_poi_and_act(target_poi, State.IDLE, 4.0, func():
		# 抵達廣場後，嘗試尋找現場是否已有其他待機的 NPC
		var plaza_partner: NPCController = _find_available_partner()
		if plaza_partner and is_instance_valid(plaza_partner):
			if global_position.distance_to(plaza_partner.global_position) <= SOCIAL_INTERACT_DIST:
				_start_mutual_conversation(plaza_partner)
				return
		if npc_data:
			npc_data.mood = clampf(npc_data.mood + 8.0, 0.0, 100.0)
			npc_data.social_desire = clampf(npc_data.social_desire + 10.0, 0.0, 100.0)
			npc_data.stats_changed.emit(npc_data.npc_id)
	)

## 與目標 NPC 展開雙向面對面交談 (雙方均在身旁，正式進入社交中狀態)
func _start_mutual_conversation(other_npc: NPCController) -> void:
	if not is_instance_valid(other_npc) or other_npc.is_dead or other_npc.is_concealed:
		if is_instance_valid(other_npc):
			other_npc.is_social_target = false
		_current_social_partner = null
		_complete_current_action()
		return

	is_social_target = true
	other_npc.is_social_target = true
	_current_social_partner = other_npc
	other_npc._current_social_partner = self

	# 停止任何殘留位移
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if other_npc._move_tween and other_npc._move_tween.is_valid():
		other_npc._move_tween.kill()
	_current_path.clear()
	other_npc._current_path.clear()

	# 面對面交流
	face_toward(other_npc.global_position)
	other_npc.face_toward(global_position)

	# 雙方切換為社交中
	set_state(State.INTERACTING)
	other_npc.set_state(State.INTERACTING)

	show_bubble(3.0)
	other_npc.show_bubble(3.0)

	# 依據圖 4 進行社交決策與記憶寫入 (STSM)
	if npc_data and other_npc.npc_data:
		var g: Node = _get_global()
		var decision_service: DecisionServiceClass = g.get_decision_service() if g else null
		var s_num: int = _extract_npc_number(npc_data.npc_id)
		var t_num: int = _extract_npc_number(other_npc.npc_data.npc_id)
		var cur_tick: int = _get_current_tick()
		var cur_day: int = _get_current_day()

		var s_fav_to_t: float = npc_data.get_friendship(other_npc.npc_data.npc_id)
		var s_mood: float = npc_data.mood
		var social_action: int = 1 # 預設普通聊天 (1~7)
		# 優先採用 Social Transformer 端到端神經預測之動作
		if _last_candidates_eval.has("predicted_action_id") and int(_last_candidates_eval.get("target_id", -1)) == t_num:
			social_action = int(_last_candidates_eval["predicted_action_id"])
		elif decision_service:
			social_action = decision_service.decide_social_action(t_num, false, s_fav_to_t, s_mood)

		var s_social: Dictionary = {
			"trust_to_target": npc_data.get_trust(other_npc.npc_data.npc_id),
			"fav_to_target": s_fav_to_t
		}
		var t_social: Dictionary = {
			"trust_to_source": other_npc.npc_data.get_trust(npc_data.npc_id),
			"fav_to_source": other_npc.npc_data.get_friendship(npc_data.npc_id)
		}

		var res: Dictionary = {}
		if decision_service and decision_service.is_database_available():
			res = decision_service.save_social_action_memory(
				s_num,
				t_num,
				cur_tick,
				social_action,
				s_social,
				t_social
			)

		var action_str: String = decision_service.get_social_action_name(social_action) if decision_service else "普通聊天"
		var s_history: float = npc_data.get_history_score_to_npc(t_num)
		var t_history: float = other_npc.npc_data.get_history_score_to_npc(s_num)
		var s_name: String = npc_data.npc_name if not npc_data.npc_name.is_empty() else name
		var t_name: String = other_npc.npc_data.npc_name if not other_npc.npc_data.npc_name.is_empty() else other_npc.name
		var time_str: String = "第 %d 天 %02d:%02d" % [cur_day, cur_tick / 60, cur_tick % 60]

		var phase_str: String = "破冰期"
		if s_fav_to_t >= 65.0:
			phase_str = "好友深度交流"
		elif s_fav_to_t < 35.0:
			phase_str = "關係緊張/排斥"

		var s_delta_fav: float = 0.0
		var s_delta_trust: float = 0.0
		var s_delta_mood: float = 0.0
		var t_delta_fav: float = 0.0
		var t_delta_trust: float = 0.0
		var t_delta_mood: float = 0.0

		if res.get("success", false):
			var s_ch: Dictionary = res.get("source", {})
			var t_ch: Dictionary = res.get("target", {})
			s_delta_fav = float(s_ch.get("change_favorability", 0))
			s_delta_trust = float(s_ch.get("change_trust", 0))
			s_delta_mood = float(s_ch.get("change_mood", 0))
			t_delta_fav = float(t_ch.get("change_favorability", 0))
			t_delta_trust = float(t_ch.get("change_trust", 0))
			t_delta_mood = float(t_ch.get("change_mood", 0))

			npc_data.modify_relationship(other_npc.npc_data.npc_id, s_delta_fav, s_delta_trust)
			npc_data.mood = clampf(npc_data.mood + s_delta_mood, 0.0, 100.0)
			npc_data.stamina = clampf(npc_data.stamina + float(s_ch.get("change_stamina", 0)), 0.0, 100.0)
			npc_data.social_desire = clampf(npc_data.social_desire + 40.0, 0.0, 100.0)
			npc_data.record_interaction(other_npc.npc_data.npc_id, cur_day)

			other_npc.npc_data.modify_relationship(npc_data.npc_id, t_delta_fav, t_delta_trust)
			other_npc.npc_data.mood = clampf(other_npc.npc_data.mood + t_delta_mood, 0.0, 100.0)
			other_npc.npc_data.stamina = clampf(other_npc.npc_data.stamina + float(t_ch.get("change_stamina", 0)), 0.0, 100.0)
			other_npc.npc_data.social_desire = clampf(other_npc.npc_data.social_desire + 40.0, 0.0, 100.0)
			other_npc.npc_data.record_interaction(npc_data.npc_id, cur_day)

			print("[NPCController] %s 與 %s 展開社交 [%s] (%s)，記憶已寫入 STSM" % [npc_data.npc_id, other_npc.npc_data.npc_id, action_str, phase_str])
		else:
			# 備用純規則平緩調整
			s_delta_fav = 3.0
			s_delta_trust = 2.0
			s_delta_mood = 15.0
			t_delta_fav = 3.0
			t_delta_trust = 2.0
			t_delta_mood = 15.0

			npc_data.modify_relationship(other_npc.npc_data.npc_id, 3.0, 2.0)
			other_npc.npc_data.modify_relationship(npc_data.npc_id, 3.0, 2.0)
			npc_data.social_desire = clampf(npc_data.social_desire + 40.0, 0.0, 100.0)
			npc_data.mood = clampf(npc_data.mood + 15.0, 0.0, 100.0)
			npc_data.record_interaction(other_npc.npc_data.npc_id, cur_day)

			other_npc.npc_data.social_desire = clampf(other_npc.npc_data.social_desire + 40.0, 0.0, 100.0)
			other_npc.npc_data.mood = clampf(other_npc.npc_data.mood + 15.0, 0.0, 100.0)
			other_npc.npc_data.record_interaction(npc_data.npc_id, cur_day)

		# 雙向寫入最近社交評估快取 (供 NPCInspector 即時呈現 ONNX 社交大腦數據)
		npc_data.last_social_evaluation = {
			"target_id": other_npc.npc_data.npc_id,
			"target_name": "%s (%s)" % [other_npc.npc_data.npc_id.replace("npc_", "NPC "), t_name],
			"score": _last_evaluated_social_score,
			"action_id": social_action,
			"action_name": action_str,
			"phase": phase_str,
			"timestamp": time_str,
			"is_initiator": true,
			"history_score": s_history,
			"delta_fav": s_delta_fav,
			"delta_trust": s_delta_trust,
			"delta_mood": s_delta_mood
		}
		other_npc.npc_data.last_social_evaluation = {
			"target_id": npc_data.npc_id,
			"target_name": "%s (%s)" % [npc_data.npc_id.replace("npc_", "NPC "), s_name],
			"score": _last_evaluated_social_score,
			"action_id": social_action,
			"action_name": action_str,
			"phase": phase_str,
			"timestamp": time_str,
			"is_initiator": false,
			"history_score": t_history,
			"delta_fav": t_delta_fav,
			"delta_trust": t_delta_trust,
			"delta_mood": t_delta_mood
		}

		# 雙向寫入生活日誌 (STM)
		npc_data.add_stm_event("與 %s 互動: %s (好感%+0.1f/信任%+0.1f)" % [t_name, action_str, s_delta_fav, s_delta_trust])
		other_npc.npc_data.add_stm_event("與 %s 互動: %s (好感%+0.1f/信任%+0.1f)" % [s_name, action_str, t_delta_fav, t_delta_trust])

		# 寫入 Transformer 訓練軌跡 (Social Interaction Step)
		if g and g.has_method("get_trajectory_logger"):
			var logger = g.get_trajectory_logger()
			if logger and logger.is_logging:
				var radar_list: Array[Dictionary] = get_nearby_social_candidates()
				var s_ch_dict: Dictionary = res.get("source", {"change_favorability": s_delta_fav, "change_trust": s_delta_trust, "change_mood": s_delta_mood})
				var t_ch_dict: Dictionary = res.get("target", {"change_favorability": t_delta_fav, "change_trust": t_delta_trust, "change_mood": t_delta_mood})
				logger.log_social_interaction_step(
					self,
					other_npc,
					cur_tick,
					cur_day,
					social_action,
					action_str,
					phase_str,
					s_ch_dict,
					t_ch_dict,
					radar_list
				)

		npc_data.stats_changed.emit(npc_data.npc_id)
		other_npc.npc_data.stats_changed.emit(other_npc.npc_data.npc_id)

		# ============================================================
		# 訊息傳播與八卦情報擴散機制 (Information Diffusion Subsystem)
		# 當社交行為為 7 (訊息傳播) 或 一般社交中隨機觸發 (機率 40%)
		# ============================================================
		var is_spreading_rumor: bool = (social_action == 7) or (randf() < 0.40)
		if is_spreading_rumor and g and g.has_method("get_diffusion_manager"):
			var diff_mgr = g.get_diffusion_manager()
			if diff_mgr:
				var cur_poi: int = int(last_decision.get("target_location", 0))
				var unshared_by_s: Array[String] = npc_data.get_unshared_rumors_for(other_npc.npc_data.npc_id)
				var unshared_by_t: Array[String] = other_npc.npc_data.get_unshared_rumors_for(npc_data.npc_id)
				var transferred: bool = false

				if not unshared_by_s.is_empty():
					var r_id: String = unshared_by_s[randi() % unshared_by_s.size()]
					var rumor: Dictionary = diff_mgr.get_rumor_by_id(r_id)
					if not rumor.is_empty():
						var s_gen: int = int(npc_data.known_rumors.get(r_id, {}).get("generation", 1))
						var ok: bool = other_npc.npc_data.learn_rumor(rumor, npc_data.npc_id, s_name, cur_day, cur_tick, s_gen + 1)
						if ok:
							npc_data.mark_rumor_shared(r_id, other_npc.npc_data.npc_id)
							diff_mgr.record_spread(r_id, npc_data.npc_id, s_name, other_npc.npc_data.npc_id, t_name, cur_day, cur_tick, cur_poi, s_gen)
							# 雙向頭頂即時氣泡演繹
							show_speech_bubble("🗣️ %s" % rumor.get("title", "分享情報"), 3.2)
							other_npc.show_speech_bubble("👂 收到情報！", 3.2)
							# [保留接口] 未來切換不同氣泡 frame / 圖像時取消以下註解：
							# set_bubble_frame(1) # 說話者氣泡幀
							# other_npc.set_bubble_frame(2) # 接收者氣泡幀
							transferred = true
				elif not unshared_by_t.is_empty():
					var r_id: String = unshared_by_t[randi() % unshared_by_t.size()]
					var rumor: Dictionary = diff_mgr.get_rumor_by_id(r_id)
					if not rumor.is_empty():
						var t_gen: int = int(other_npc.npc_data.known_rumors.get(r_id, {}).get("generation", 1))
						var ok: bool = npc_data.learn_rumor(rumor, other_npc.npc_data.npc_id, t_name, cur_day, cur_tick, t_gen + 1)
						if ok:
							other_npc.npc_data.mark_rumor_shared(r_id, npc_data.npc_id)
							diff_mgr.record_spread(r_id, other_npc.npc_data.npc_id, t_name, npc_data.npc_id, s_name, cur_day, cur_tick, cur_poi, t_gen)
							other_npc.show_speech_bubble("🗣️ %s" % rumor.get("title", "分享情報"), 3.2)
							show_speech_bubble("👂 收到情報！", 3.2)
							# [保留接口] 未來切換不同氣泡 frame / 圖像時取消以下註解：
							# other_npc.set_bubble_frame(1)
							# set_bubble_frame(2)
							transferred = true

				if not transferred and social_action == 7:
					show_speech_bubble("🗣️ 「城鎮最近似乎平平靜靜的...」", 2.5)

	_action_memory_saved = true
	other_npc._action_memory_saved = true

	_action_timer = 3.2
	other_npc._action_timer = 3.2
	_is_executing_action = true
	other_npc._is_executing_action = true



# ------------------------------------------------------------------------------
# 8. 狀態機與動畫 (FSM & Directional Animation)
# ------------------------------------------------------------------------------

## 切換 NPC 狀態
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return

	var old_state: State = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

	match new_state:
		State.IDLE, State.WORKING, State.RESTING, State.INTERACTING:
			# 非移動狀態時，若有移動 Tween 則停止，並定格在當前朝向的第 0 幀
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			_current_path.clear()
			face_direction(facing_direction)


## 朝向特定方向並停止在第 0 幀
func face_direction(direction_str: String) -> void:
	facing_direction = direction_str
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var idle_anim: String = "idle_" + direction_str
	var walk_anim: String = "walk_" + direction_str

	if animated_sprite.sprite_frames.has_animation(idle_anim):
		animated_sprite.play(idle_anim)
		animated_sprite.pause()
		animated_sprite.frame = 0
	elif animated_sprite.sprite_frames.has_animation(walk_anim):
		animated_sprite.play(walk_anim)
		animated_sprite.pause()
		animated_sprite.frame = 0


## 朝向特定世界座標
func face_toward(target_pos: Vector2) -> void:
	var diff: Vector2 = target_pos - global_position
	if diff != Vector2.ZERO:
		var dir_str: String = _vector_to_direction(diff)
		face_direction(dir_str)


## 顯示對話氣泡
func show_bubble(duration: float = 2.0) -> void:
	if bubble_node:
		var lbl: Label = bubble_node.get_node_or_null("bubble_text") as Label
		if lbl:
			lbl.text = ""
		bubble_node.visible = true
		if duration > 0.0 and get_tree():
			var timer = get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(bubble_node):
					bubble_node.visible = false
			)

## 設定/切換頭頂氣泡的圖像 Frame (供後續自定義氣泡 Sprite2D / AnimatedSprite2D 圖集使用)
func set_bubble_frame(frame_index: int) -> void:
	# [保留接口] 未來使用者加入自定義氣泡圖集時，取消以下註解或客製邏輯：
	# if bubble_node:
	# 	if bubble_node is Sprite2D:
	# 		(bubble_node as Sprite2D).frame = frame_index
	# 	elif bubble_node is AnimatedSprite2D:
	# 		(bubble_node as AnimatedSprite2D).frame = frame_index
	# 	else:
	# 		var spr = bubble_node.get_node_or_null("Sprite2D")
	# 		if spr and "frame" in spr:
	# 			spr.frame = frame_index
	pass

## 顯示帶有文字/Emoji之對話與告警氣泡
func show_speech_bubble(text: String, duration: float = 2.5, bubble_frame: int = -1) -> void:
	if bubble_node:
		# [保留接口] 若有指定氣泡 frame，調用 set_bubble_frame 切換
		# if bubble_frame >= 0:
		# 	set_bubble_frame(bubble_frame)

		var lbl: Label = bubble_node.get_node_or_null("bubble_text") as Label
		if lbl == null:
			lbl = Label.new()
			lbl.name = "bubble_text"
			lbl.position = Vector2(-36, -34)
			lbl.size = Vector2(96, 20)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
			lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.95))
			lbl.add_theme_constant_override("outline_size", 3)
			bubble_node.add_child(lbl)
		lbl.text = text
		bubble_node.visible = true
		if duration > 0.0 and get_tree():
			var timer = get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(bubble_node):
					bubble_node.visible = false
			)

## 隱藏對話氣泡
func hide_bubble() -> void:
	if bubble_node:
		bubble_node.visible = false

## 進入建築物 / 密林 (淡出並隱藏)
func enter_building(entrance_dir: String = "south") -> void:
	is_concealed = true
	face_direction(entrance_dir)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		visible = false
	)

## 離開建築物 / 密林 (現身並淡入)
func exit_building() -> void:
	if not is_concealed and visible and modulate.a >= 0.99:
		return
	is_concealed = false
	visible = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

# ------------------------------------------------------------------------------
# 9. 尋路與平滑移動 (A* Movement with Tween)
# ------------------------------------------------------------------------------

## 依據目標網格進行 A* 尋路並開始移動
func move_along_grid(target_cell: Vector2i, on_complete: Callable = Callable()) -> void:
	var nav = _get_nav_manager()
	if nav == null:
		push_warning("[NPCController] 未能取得 NavigationManager，移動終止。")
		_complete_current_action(false)
		return

	var start_cell: Vector2i = nav.local_to_map(global_position)
	if start_cell == target_cell:
		# 已在目標格
		target_reached.emit(target_cell)
		if on_complete.is_valid():
			on_complete.call()
		return

	var path: Array[Vector2i] = nav.get_id_path(start_cell, target_cell)

	if path.size() <= 1:
		# 第一次尋路未成 (可能目標格臨時被障礙卡死)，嘗試探查目標地塊周邊最近可通行的備用格進行重試
		var alt_target: Vector2i = nav.get_closest_walkable_cell(target_cell, 4)
		if alt_target != Vector2i(-1, -1) and alt_target != target_cell:
			path = nav.get_id_path(start_cell, alt_target)

		if path.size() <= 1:
			# 若仍無法尋得路徑或被阻擋
			push_warning("[NPCController] %s 無法尋得由 %s 至 %s 之有效路徑。" % [name, str(start_cell), str(target_cell)])
			_complete_current_action(false)
			return

	_current_path = path
	set_state(State.MOVING)
	_step_move(1, on_complete)


## 遞迴式單步 Tween 移動
func _step_move(step_index: int, on_complete: Callable) -> void:
	if step_index >= _current_path.size():
		# 抵達終點
		var dest_cell: Vector2i = _current_path.back()
		_current_path.clear()
		target_reached.emit(dest_cell)
		face_direction(facing_direction) # 抵達後定格
		if on_complete.is_valid():
			on_complete.call()
		return

	var nav = _get_nav_manager()
	if nav == null:
		_complete_current_action()
		return

	var g: Node = _get_global()
	if g and g.is_time_paused:
		_pending_step_index = step_index
		_pending_on_complete = on_complete
		if animated_sprite and animated_sprite.is_playing():
			animated_sprite.pause()
		return

	var next_cell: Vector2i = _current_path[step_index]
	var next_pos: Vector2 = nav.map_to_local(next_cell)

	# 方向與動畫判定
	var move_vec: Vector2 = (next_pos - global_position).normalized()
	if move_vec != Vector2.ZERO:
		facing_direction = _vector_to_direction(move_vec)
		if animated_sprite:
			animated_sprite.play("walk_" + facing_direction)

	# 平滑位移 (移動速度隨全域時間流速倍率縮放，確保與遊戲內時鐘步調一致)
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	var cur_scale: float = g.time_scale if (g and not g.is_time_paused) else 1.0

	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_LINEAR)
	_move_tween.set_speed_scale(cur_scale)
	_move_tween.tween_property(self, "global_position", next_pos, step_duration)
	_move_tween.tween_callback(func():
		_step_move(step_index + 1, on_complete)
	)

# ------------------------------------------------------------------------------
# 10. 內部私有輔助函式 (Internal Helpers)
# ------------------------------------------------------------------------------

## 判斷當前是否為夜間就寢時段 (23:00 ~ 06:00 / tick >= 1380 或 tick < 360)
func _is_bedtime_hour(tick: int) -> bool:
	return tick >= 1380 or tick < 360

func _on_action_timer_finished() -> void:
	_complete_current_action(true)

func _complete_current_action(is_success: bool = true) -> void:
	if not _is_executing_action and current_state == State.IDLE:
		return

	# 依據圖 2：若為一般行動且尚未寫入記憶，計算數值增減並儲存至 STM
	if not _action_memory_saved and current_action_id >= 0 and current_action_id != 6:
		_save_normal_action_memory(current_action_id, is_success)
		_action_memory_saved = true

	_is_executing_action = false
	_action_elapsed_ticks = 0
	is_social_target = false
	_social_target_elapsed_ticks = 0
	if is_instance_valid(_current_social_partner):
		var partner: NPCController = _current_social_partner
		_current_social_partner = null
		partner.is_social_target = false
		partner._social_target_elapsed_ticks = 0
		partner._current_social_partner = null
		partner._complete_current_action(is_success)
	action_completed.emit(current_action_id)

	# 若為夜間就寢行動且當前仍處於夜間就寢時段，保持 State.RESTING 狀態安穩就寢，直到晨起 06:00
	var cur_tick: int = _get_current_tick()
	if current_action_id == 5 and _is_bedtime_hour(cur_tick):
		set_state(State.RESTING)
		return

	set_state(State.IDLE)

## 強制中止目前超時或卡住的行動並恢復為 IDLE 狀態
func _abort_and_reset_action() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_current_path.clear()
	_action_timer = 0.0
	_action_elapsed_ticks = 0
	_social_target_elapsed_ticks = 0
	is_social_target = false
	_pending_step_index = -1
	_pending_on_complete = Callable()

	if is_instance_valid(_current_social_partner):
		var partner: NPCController = _current_social_partner
		_current_social_partner = null
		partner.is_social_target = false
		partner._social_target_elapsed_ticks = 0
		partner._current_social_partner = null
		if partner._is_executing_action:
			partner._complete_current_action(false)

	_complete_current_action(false)
	set_state(State.IDLE)

## 響應飢餓瀕臨危急訊號 (hunger < 20.0)
func _on_hunger_critical(_id: String = "") -> void:
	if not is_dead and current_action_id != 3:
		_handle_emergency_starvation(_get_current_tick())

## 緊急飢餓求生自救處理 (Emergency Survival Interrupt)
func _handle_emergency_starvation(current_tick: int) -> void:
	if is_dead or npc_data == null:
		return

	# 先中止目前進行中之任何常規或社交行為
	if _is_executing_action or current_state == State.MOVING:
		_abort_and_reset_action()

	print("[NPCController] ⚠️ %s 觸發瀕死飢餓緊急自救！(飢餓值: %.1f)" % [npc_data.npc_id, npc_data.hunger])

	current_action_id = 3 # 用餐
	_is_executing_action = true
	_action_elapsed_ticks = 0
	_action_memory_saved = false
	action_started.emit(3, "緊急進食", 13)

	# 若身上有便當/食物，或是手頭有農作物/生鮮，原地立即食用
	if npc_data.lunchbox > 0 or npc_data.food > 0 or npc_data.crops > 0 or npc_data.fish > 0:
		_execute_eat_in_place()
	elif npc_data.money >= 3:
		# 有錢則火速前往餐廳 (POI 13)
		_execute_action(3, 13)
	else:
		# 既無儲糧亦無金錢，原地摘野果/飲水應急充飢，保證生存底線
		_execute_eat_in_place()

## 依據圖 2：計算一般行動數值增減並儲存至 STM
func _save_normal_action_memory(action_id: int, is_success: bool) -> void:
	if npc_data == null or action_id < 0 or action_id == 6:
		return
	var g: Node = _get_global()
	if g == null:
		return
	var decision_service: DecisionServiceClass = g.get_decision_service()
	if decision_service == null or not decision_service.is_database_available():
		return

	var npc_num: int = _extract_npc_number(npc_data.npc_id)
	if npc_num <= 0:
		return

	var cur_tick: int = _get_current_tick()
	var stats_dict: Dictionary = npc_data.get_physiological_dict()
	var loc: int = int(last_decision.get("target_location", 0))

	var res: Dictionary = decision_service.save_normal_action_memory(
		npc_num,
		cur_tick,
		stats_dict,
		action_id,
		loc,
		is_success
	)

	if res.get("success", false):
		npc_data.apply_stat_changes(res)
		var act_name: String = decision_service.get_action_name(action_id)
		var r_val: float = float(res.get("reward_value", 0.0))
		print("[NPCController] %s 完成行動 [%s] (成功=%s)，數值已更新並存入 STM (Reward: %.2f)" % [npc_data.npc_id, act_name, str(is_success), r_val])

		# 寫入 Transformer 訓練軌跡 (Normal Decision Step)
		if g and g.has_method("get_trajectory_logger"):
			var logger = g.get_trajectory_logger()
			if logger and logger.is_logging:
				logger.log_normal_action_step(npc_data, cur_tick, _get_current_day(), last_decision, res)

func _get_current_tick() -> int:
	var g: Node = _get_global()
	if g and "current_tick" in g:
		return int(g.current_tick)
	return 480

func _get_current_day() -> int:
	var g: Node = _get_global()
	if g and "current_day" in g:
		return int(g.current_day)
	return 1

func _initialize_position() -> void:
	var nav = _get_nav_manager()
	if nav:
		var cur_cell: Vector2i = nav.local_to_map(global_position)
		global_position = nav.map_to_local(cur_cell)

func _get_global() -> Node:
	if is_inside_tree() and has_node("/root/Global"):
		return get_node("/root/Global")
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var st: SceneTree = main_loop as SceneTree
		if st.root and st.root.has_node("Global"):
			return st.root.get_node("Global")
	return null

func _get_nav_manager():
	var g: Node = _get_global()
	if g and g.has_method("get_navigation_manager"):
		return g.get_navigation_manager()
	return null

func _get_poi_cell(poi_id: int) -> Vector2i:
	var g: Node = _get_global()
	if g and g.has_method("get_poi_cell"):
		return g.get_poi_cell(poi_id)
	return Vector2i(-1, -1)


## 從字串 ID (如 "npc_05") 提取數值代碼 (5)
func _extract_npc_number(id_str: String) -> int:
	var clean: String = id_str.replace("npc_", "").replace("NPC_", "")
	if clean.is_valid_int():
		return clean.to_int()
	return 1

func _find_available_partner() -> NPCController:
	var g: Node = _get_global()
	if g == null:
		return null
	var decision_service = g.get_decision_service()
	var all_npcs: Array[Node2D] = g.get_all_npcs()

	var candidates: Array = []
	var candidate_ctrls: Dictionary = {}

	for npc in all_npcs:
		if npc != self and npc is NPCController:
			var ctrl: NPCController = npc as NPCController
			# 排除死亡、隱蔽中或已被其他 NPC 鎖定為社交對象者
			if ctrl.is_dead or ctrl.is_concealed or ctrl.is_social_target:
				continue
			# 夥伴必須處於待機狀態，避免打斷他人正在進行的移動、工作或休養
			if ctrl.current_state != State.IDLE:
				continue
			# 檢查該對象是否允許社交 (依照 Google 表格規範：非工作/就醫/閱讀/睡覺)
			if decision_service and decision_service.is_available_for_social(ctrl.current_action_id, ctrl.current_state == State.RESTING):
				var d_pixels: float = global_position.distance_to(ctrl.global_position)
				var d_tiles: float = d_pixels / 16.0
				if d_tiles <= 32.0:
					var target_str_id: String = ctrl.npc_data.npc_id if ctrl.npc_data else ctrl.name
					var num_id: int = _extract_npc_number(target_str_id)
					var fav: float = npc_data.get_friendship(target_str_id) if npc_data else 50.0
					var cur_day: int = g.current_day if "current_day" in g else 1
					var days_since: float = npc_data.get_days_since_interaction(target_str_id, cur_day) if npc_data else 3.0
					var hist: float = npc_data.get_history_score_to_npc(num_id) if npc_data else 0.5

					candidates.append({
						"id": num_id,
						"distance": d_tiles,
						"favorability": fav,
						"days_since_interaction": days_since,
						"history_score": hist
					})
					candidate_ctrls[num_id] = ctrl

	if candidates.is_empty():
		return null

	# 若 C# ONNX 社交推論引擎可用，呼叫 Social Transformer (或社交 MLP) 批次推論與加權輪盤
	if decision_service and decision_service.is_social_engine_available():
		var cur_tick: float = float(g.current_tick) if "current_tick" in g else 720.0
		var s_desire: float = npc_data.social_desire if npc_data else 50.0
		var s_mood: float = npc_data.mood if npc_data else 50.0
		var s_stamina: float = npc_data.stamina if npc_data else 50.0
		var s_job: int = npc_data.job_id if npc_data else 9
		var eval_res: Dictionary = decision_service.evaluate_social_candidates(cur_tick, s_desire, s_mood, candidates, s_stamina, s_job)
		_last_candidates_eval = eval_res
		var chosen_id: int = int(eval_res.get("target_id", -1))
		if chosen_id > 0 and candidate_ctrls.has(chosen_id):
			_last_evaluated_social_score = float(eval_res.get("score", 0.5))
			return candidate_ctrls[chosen_id]

	# 降級方案：挑選距離最近者
	var best_p: NPCController = null
	var min_d: float = 999999.0
	for num_id in candidate_ctrls.keys():
		var c: NPCController = candidate_ctrls[num_id]
		var d: float = global_position.distance_to(c.global_position)
		if d < min_d:
			min_d = d
			best_p = c
	_last_evaluated_social_score = 0.5
	return best_p

## 取得最近一次或即時掃描周遭 32 格內的社交候選人意願評分列表 (供觀測 UI 呈現社交雷達)
func get_nearby_social_candidates() -> Array[Dictionary]:
	var g: Node = _get_global()
	if g == null:
		return []
	var decision_service = g.get_decision_service()
	var all_npcs: Array[Node2D] = g.get_all_npcs()
	var candidates: Array = []
	var cur_day: int = g.current_day if "current_day" in g else 1

	for npc in all_npcs:
		if npc != self and npc is NPCController:
			var ctrl: NPCController = npc as NPCController
			if ctrl.is_dead or ctrl.is_concealed:
				continue
			var d_pixels: float = global_position.distance_to(ctrl.global_position)
			var d_tiles: float = d_pixels / 16.0
			if d_tiles <= 32.0:
				var target_str_id: String = ctrl.npc_data.npc_id if ctrl.npc_data else ctrl.name
				var num_id: int = _extract_npc_number(target_str_id)
				var fav: float = npc_data.get_friendship(target_str_id) if npc_data else 50.0
				var days_since: float = npc_data.get_days_since_interaction(target_str_id, cur_day) if npc_data else 3.0
				var hist: float = npc_data.get_history_score_to_npc(num_id) if npc_data else 0.5
				var t_name: String = ctrl.name if ctrl.npc_data == null else ctrl.npc_data.npc_name

				candidates.append({
					"id": num_id,
					"name": t_name,
					"str_id": target_str_id,
					"distance": d_tiles,
					"favorability": fav,
					"days_since_interaction": days_since,
					"history_score": hist,
					"score": 0.0
				})

	if candidates.is_empty():
		return []

	if decision_service and decision_service.is_social_engine_available():
		var cur_tick: float = float(g.current_tick) if "current_tick" in g else 720.0
		var s_desire: float = npc_data.social_desire if npc_data else 50.0
		var s_mood: float = npc_data.mood if npc_data else 50.0
		var eval_res: Dictionary = decision_service.evaluate_social_candidates(cur_tick, s_desire, s_mood, candidates)
		var c_scores: Dictionary = eval_res.get("candidate_scores", {})
		var c_probs: Dictionary = eval_res.get("candidate_probs", {})
		var highest_id: int = int(eval_res.get("highest_target_id", -1))
		for cand in candidates:
			var cid: int = int(cand["id"])
			if c_scores.has(cid):
				cand["score"] = float(c_scores[cid])
			if c_probs.has(cid):
				cand["prob"] = float(c_probs[cid])
			else:
				cand["prob"] = 0.0
			cand["is_top"] = (cid == highest_id)
	else:
		var total_pow: float = 0.0
		for cand in candidates:
			var f_ratio: float = float(cand["favorability"]) / 100.0
			var d_ratio: float = 1.0 - (float(cand["distance"]) / 32.0)
			var sc: float = clampf(f_ratio * 0.7 + d_ratio * 0.3, 0.0, 1.0)
			cand["score"] = sc
			var pw: float = sc * sc * sc
			cand["_pw"] = pw
			total_pow += pw
		for cand in candidates:
			cand["prob"] = (cand["_pw"] / total_pow) if total_pow > 0.0 else 0.0
			cand["is_top"] = false

	var typed_candidates: Array[Dictionary] = []
	for c in candidates:
		typed_candidates.append(c as Dictionary)
	typed_candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	if not typed_candidates.is_empty():
		typed_candidates[0]["is_top"] = true
	return typed_candidates

## 檢查特定網格地塊是否已被任何非隱蔽且活著的 NPC 佔用
func _is_cell_occupied(cell: Vector2i, exclude_npc: NPCController = null) -> bool:
	var g: Node = _get_global()
	if g == null:
		return false
	var nav = _get_nav_manager()
	if nav == null:
		return false
	for npc in g.get_all_npcs():
		if npc == self or npc == exclude_npc or not (npc is NPCController):
			continue
		var ctrl: NPCController = npc as NPCController
		if ctrl.is_concealed:
			continue
		var npc_cell: Vector2i = nav.local_to_map(ctrl.global_position)
		if npc_cell == cell:
			return true
	return false

## 獲取夥伴身邊相鄰且尚未被佔用的通行地塊 (確保不重疊站位)
func _get_free_adjacent_cell(center_cell: Vector2i) -> Vector2i:
	var nav = _get_nav_manager()
	if nav == null:
		return center_cell

	# 優先檢查上下左右 4 格與對角 4 格
	var offsets: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	for off in offsets:
		var candidate: Vector2i = center_cell + off
		if nav.is_cell_walkable(candidate) and not _is_cell_occupied(candidate):
			return candidate

	# 若周圍 1 格皆被佔用，尋找半徑 2 格內未被佔用之可行走地塊
	for radius in range(2, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) + abs(dy) <= radius:
					var candidate: Vector2i = center_cell + Vector2i(dx, dy)
					if nav.is_cell_walkable(candidate) and not _is_cell_occupied(candidate):
						return candidate

	return nav.get_closest_walkable_cell(center_cell, 2)

## 響應生命值歸零 (飢餓衰竭或體力耗盡)
func _on_hp_depleted(_id: String = "") -> void:
	if not is_dead and not is_fainted:
		var cause_str: String = "飢餓衰竭" if (npc_data and npc_data.hunger <= 0.0) else "體力耗盡"
		faint(cause_str)

## 觸發昏厥倒地 (暫不直接死亡，等待路人通報與醫生外勤救援)
func faint(cause: String = "體力竭盡昏厥") -> void:
	if is_fainted or is_dead:
		return
	is_fainted = true
	fainted_cause = cause
	fainted_elapsed_ticks = 0
	_is_executing_action = false
	_action_timer = 0.0
	_action_elapsed_ticks = 0
	_social_target_elapsed_ticks = 0

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	if is_concealed:
		exit_building()

	# 倒地展演：旋轉 90 度倒下，面色蒼白
	if animated_sprite:
		animated_sprite.stop()
		var faint_tween: Tween = create_tween().set_parallel(true)
		faint_tween.tween_property(animated_sprite, "rotation_degrees", 90.0, 0.4)
		faint_tween.tween_property(animated_sprite, "modulate", Color(0.7, 0.75, 0.85, 0.95), 0.4)

	set_state(State.RESTING)
	show_speech_bubble("💫 昏迷倒地！", 3.0)

	var g: Node = _get_global()
	if g and g.has_method("on_npc_fainted"):
		g.on_npc_fainted(npc_data.npc_id if npc_data else name, fainted_cause)
	print("[NPCController] 💫 %s 因【%s】昏厥倒地 (座標: %s)！" % [
		npc_data.npc_name if npc_data else name, fainted_cause, str(global_position)
	])

## 從昏迷中被醫生施救喚醒
func wake_up_from_faint(doctor_name: String, doctor_id: String = "") -> void:
	if not is_fainted:
		return
	is_fainted = false
	fainted_cause = ""
	fainted_elapsed_ticks = 0

	# 角色回正展演
	if animated_sprite:
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(animated_sprite, "rotation_degrees", 0.0, 0.4)
		t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.4)

	if npc_data:
		npc_data.hp = 60.0
		npc_data.health = clampf(maxf(npc_data.health, 45.0), 0.0, 100.0)
		npc_data.stamina = clampf(maxf(npc_data.stamina, 45.0), 0.0, 100.0)
		npc_data.hunger = clampf(maxf(npc_data.hunger, 35.0), 0.0, 100.0)
		npc_data.mood = clampf(npc_data.mood + 25.0, 0.0, 100.0)
		if not doctor_id.is_empty():
			npc_data.modify_relationship(doctor_id, 35.0, 45.0)
		npc_data.add_stm_event("被 %s 施救喚醒，重獲新生！" % doctor_name)
		npc_data.stats_changed.emit(npc_data.npc_id)

	show_speech_bubble("❤️ 感謝 %s 救了我！" % doctor_name, 3.5)
	set_state(State.IDLE)

	var g: Node = _get_global()
	if g and g.has_method("on_npc_revived"):
		g.on_npc_revived(npc_data.npc_id if npc_data else name, doctor_id)

## 測試/除錯：主動讓此 NPC 進入昏厥狀態，驗證路人通報與醫生出診救援閉環
func trigger_test_faint(reason: String = "中暑體力透支") -> void:
	faint(reason)

## 路人自主發現並通報周遭昏厥市民
func _check_and_report_nearby_emergencies() -> void:
	var g = _get_global()
	if g == null:
		return
	var all_npcs = g.get_all_npcs()
	for other: Node2D in all_npcs:
		if other != self and is_instance_valid(other):
			if bool(other.get("is_fainted")) == true and not bool(other.get("is_dead")) and not bool(other.get("is_concealed")):
				var dist: float = global_position.distance_to(other.global_position)
				if dist <= 180.0: # 視野範圍約 11 格以內
					var patient_id: String = other.npc_data.npc_id if other.get("npc_data") else other.name
					if not g.is_emergency_active(patient_id):
						# 發現倒地者，面向目標並通報
						face_toward(other.global_position)
						show_speech_bubble("🚨 發現有人昏倒！已呼叫急救！", 3.0)
						var nav = _get_nav_manager()
						var p_cell: Vector2i = nav.local_to_map(other.global_position) if nav else Vector2i.ZERO
						var my_id: String = npc_data.npc_id if npc_data else name
						g.report_medical_emergency(patient_id, other.global_position, p_cell, my_id)
						print("[NPCController] 🚨 %s 發現昏厥的 %s，已向全域通報急救！" % [my_id, patient_id])
						break

## 檢查醫護人員當前是否處於值班時間
func _is_doctor_on_duty(tick: int) -> bool:
	if npc_data == null or npc_data.job_id != 5:
		return false
	# Ivy (npc_09): 早班 07:00 ~ 15:00 (420 ~ 900)
	# Jack (npc_10): 晚班 14:00 ~ 22:00 (840 ~ 1320)
	var is_late_shift: bool = (npc_data.npc_id == "npc_10" or npc_data.home_poi_id == 9)
	var s_start: int = 840 if is_late_shift else 420
	var s_end: int = 1320 if is_late_shift else 900
	return tick >= s_start and tick < s_end

## 醫護人員執勤檢查：若醫院無病患且全域存在未處理之昏迷市民，自主出診救援
func _check_doctor_rescue_duty(tick: int) -> void:
	if not _is_doctor_on_duty(tick):
		return
	var g = _get_global()
	if g == null:
		return
	# 條件 1: 醫院當前無病患 (醫院沒人)
	if g.is_hospital_busy():
		return
	# 條件 2: 存在待救援之緊急事件
	if not g.has_pending_emergency():
		return

	var my_id: String = npc_data.npc_id if npc_data else name
	var emergency: Dictionary = g.get_pending_emergency(my_id)
	if emergency.is_empty():
		return

	# 接單出診救援
	_dispatch_doctor_rescue(emergency)

## 啟動外勤出診急救流程
func _dispatch_doctor_rescue(emergency: Dictionary) -> void:
	var g = _get_global()
	var my_id: String = npc_data.npc_id if npc_data else name
	var patient_id: String = String(emergency.get("patient_id", ""))
	if g:
		g.assign_doctor_to_emergency(patient_id, my_id)

	is_rescuing = true
	_current_rescue_emergency = emergency
	_abort_and_reset_action()
	if is_concealed:
		exit_building()

	show_speech_bubble("🚑 收到急救通報！立刻出診救援！", 3.0)
	var target_cell: Vector2i = Vector2i.ZERO
	if emergency.has("location_cell") and emergency["location_cell"] is Array and emergency["location_cell"].size() >= 2:
		target_cell = Vector2i(int(emergency["location_cell"][0]), int(emergency["location_cell"][1]))
	elif emergency.has("location_cell") and emergency["location_cell"] is Vector2i:
		target_cell = emergency["location_cell"]

	var nav = _get_nav_manager()
	var dest_cell: Vector2i = target_cell
	if nav:
		dest_cell = _get_free_adjacent_cell(target_cell)

	move_along_grid(dest_cell, Callable(self, "_on_reached_emergency_patient"))

## 抵達倒地病患身邊並實施急救
func _on_reached_emergency_patient() -> void:
	if not is_rescuing:
		return
	var g = _get_global()
	if g == null:
		_finish_doctor_rescue()
		return

	var patient_id: String = String(_current_rescue_emergency.get("patient_id", ""))
	var patient: Node2D = g.get_npc(patient_id)
	if patient and is_instance_valid(patient) and bool(patient.get("is_fainted")) == true:
		face_toward(patient.global_position)
		set_state(State.INTERACTING)
		show_speech_bubble("💉 正在實施急救復甦...", 2.5)

		var timer = get_tree().create_timer(2.2)
		timer.timeout.connect(func():
			if is_instance_valid(patient) and bool(patient.get("is_fainted")) == true:
				var doc_name: String = npc_data.npc_name if npc_data else "醫生"
				var doc_id: String = npc_data.npc_id if npc_data else name
				if patient.has_method("wake_up_from_faint"):
					patient.wake_up_from_faint(doc_name, doc_id)
				g.resolve_medical_emergency(patient_id, doc_id)

				if npc_data:
					npc_data.mood = clampf(npc_data.mood + 30.0, 0.0, 100.0)
					npc_data.add_item("money", 6)
					npc_data.add_stm_event("出診成功救醒倒地的 %s" % (patient.npc_data.npc_name if patient.get("npc_data") else patient_id))
					npc_data.stats_changed.emit(npc_data.npc_id)

				show_speech_bubble("✨ 急救成功！病患已甦醒脫險。", 2.5)

			_finish_doctor_rescue()
		)
	else:
		_finish_doctor_rescue()

## 結束急救並返回醫院崗位
func _finish_doctor_rescue() -> void:
	is_rescuing = false
	_current_rescue_emergency.clear()
	var g = _get_global()
	if g and g.has_poi(18):
		var hosp_cell: Vector2i = g.get_poi_cell(18)
		if hosp_cell != Vector2i(-1, -1):
			show_speech_bubble("🏥 返院值班中...", 2.0)
			move_along_grid(hosp_cell, func():
				set_state(State.WORKING)
			)
			return
	set_state(State.IDLE)

## 執行 NPC 死亡邏輯
func die(cause: String = "飢餓衰竭") -> void:
	if is_dead:
		return
	is_dead = true
	is_fainted = false
	death_cause = cause
	_is_executing_action = false
	_action_timer = 0.0
	_action_elapsed_ticks = 0
	_social_target_elapsed_ticks = 0

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	if is_concealed:
		exit_building()

	# 倒地展演：旋轉 90 度躺平並轉為灰暗色調
	if animated_sprite:
		animated_sprite.stop()
		var death_tween: Tween = create_tween().set_parallel(true)
		death_tween.tween_property(animated_sprite, "rotation_degrees", 90.0, 0.5)
		death_tween.tween_property(animated_sprite, "modulate", Color(0.45, 0.45, 0.5, 0.85), 0.5)

	hide_bubble()
	set_state(State.RESTING)

	var g: Node = _get_global()
	if g:
		# 寫入 Transformer 訓練軌跡 (Death Step) 終端負向樣本
		if g.has_method("get_trajectory_logger"):
			var logger = g.get_trajectory_logger()
			if logger and logger.is_logging:
				logger.log_death_step(self, _get_current_tick(), _get_current_day(), death_cause)

		if g.has_method("on_npc_died"):
			g.on_npc_died(npc_data.npc_id if npc_data else name, death_cause)

func _vector_to_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

## 取得當前狀態名稱 (中文)
func get_state_name() -> String:
	if is_dead:
		return "💀 亡故"
	if is_fainted:
		return "💫 昏厥倒地 (%s)" % fainted_cause
	if is_rescuing:
		return "🚑 出診急救中"
	match current_state:
		State.IDLE: return "待機"
		State.MOVING: return "移動中"
		State.INTERACTING:
			match current_action_id:
				2: return "購物中"
				3: return "用餐中"
				_: return "社交中"
		State.WORKING: return "工作中"
		State.RESTING: return "休息中"
	return "未知"

## 序列化此 NPC 實體之狀態字典 (供全域存檔)
func to_dict() -> Dictionary:
	var nav = _get_nav_manager()
	var grid_pos: Vector2i = nav.local_to_map(global_position) if nav else Vector2i.ZERO
	return {
		"npc_id": npc_data.npc_id if npc_data else name,
		"global_position": [global_position.x, global_position.y],
		"grid_position": [grid_pos.x, grid_pos.y],
		"facing_direction": facing_direction,
		"current_state": int(current_state),
		"current_action_id": current_action_id,
		"is_concealed": is_concealed,
		"is_dead": is_dead,
		"death_cause": death_cause,
		"is_fainted": is_fainted,
		"fainted_cause": fainted_cause,
		"fainted_elapsed_ticks": fainted_elapsed_ticks,
		"is_rescuing": is_rescuing,
		"npc_data": npc_data.to_dict() if npc_data else {}
	}

## 從存檔字典還原此 NPC 實體之狀態
func from_dict(data: Dictionary) -> void:
	if data.has("global_position") and data["global_position"] is Array:
		var arr: Array = data["global_position"]
		if arr.size() >= 2:
			global_position = Vector2(float(arr[0]), float(arr[1]))

	facing_direction = str(data.get("facing_direction", "down"))
	face_direction(facing_direction)

	current_action_id = int(data.get("current_action_id", -1))
	is_concealed = bool(data.get("is_concealed", false))
	if is_concealed:
		modulate.a = 0.0
		visible = false
	else:
		modulate.a = 1.0
		visible = true

	if data.has("npc_data") and data["npc_data"] is Dictionary and npc_data:
		npc_data.from_dict(data["npc_data"])

	var was_dead: bool = bool(data.get("is_dead", false))
	if was_dead:
		die(str(data.get("death_cause", "飢餓衰竭")))
	else:
		is_dead = false
		death_cause = ""
		is_fainted = bool(data.get("is_fainted", false))
		fainted_cause = str(data.get("fainted_cause", ""))
		fainted_elapsed_ticks = int(data.get("fainted_elapsed_ticks", 0))
		is_rescuing = bool(data.get("is_rescuing", false))
		if is_fainted:
			if animated_sprite:
				animated_sprite.rotation_degrees = 90.0
				animated_sprite.modulate = Color(0.7, 0.75, 0.85, 0.95)
			set_state(State.RESTING)
		else:
			if animated_sprite:
				animated_sprite.rotation_degrees = 0.0
				animated_sprite.modulate = Color.WHITE
			var saved_state: int = int(data.get("current_state", State.IDLE))
			set_state(saved_state as State)

## 初始化滑鼠點擊感應區域 (動態加入 Area2D，無需編輯 .tscn)
func _setup_click_detection() -> void:
	input_pickable = true
	var click_area: Area2D = Area2D.new()
	click_area.name = "ClickArea"
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(24, 36)
	col_shape.shape = rect
	col_shape.position = Vector2(0, -8)
	click_area.add_child(col_shape)
	click_area.input_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	click_area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	add_child(click_area)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_npc_clicked()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_npc_clicked()

func _on_npc_clicked() -> void:
	var g: Node = _get_global()
	if g and g.has_method("select_npc"):
		g.select_npc(self)
	clicked.emit()
