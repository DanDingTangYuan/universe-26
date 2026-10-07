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

## 最近一次 AI 決策結果字典 (包含 best_action, target_location, scores, is_rule_override, override_reason)
var last_decision: Dictionary = {}

var _current_path: Array[Vector2i] = []
var _move_tween: Tween = null
var _last_decision_tick: int = -1
var _is_executing_action: bool = false
var _action_timer: float = 0.0

# ------------------------------------------------------------------------------
# 5. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	# 1. 確保數據模型就緒
	if npc_data == null:
		npc_data = NPCDataClass.new()
		npc_data.npc_id = name
		npc_data.npc_name = name

	# 2. 向全域單例註冊自身
	var global_node: Node = _get_global()
	if global_node:
		global_node.register_npc(npc_data.npc_id, self)
		if not global_node.tick_passed.is_connected(_on_global_tick_passed):
			global_node.tick_passed.connect(_on_global_tick_passed)

	# 3. 初始化視圖
	if bubble_node:
		bubble_node.visible = false
	face_direction(facing_direction)

	# 4. 初次定位
	call_deferred("_initialize_position")

	# 5. 啟用點選感應
	_setup_click_detection()


func _exit_tree() -> void:
	# 卸載時從全域註銷
	var global_node: Node = _get_global()
	if global_node:
		global_node.unregister_npc(npc_data.npc_id)
		if global_node.tick_passed.is_connected(_on_global_tick_passed):
			global_node.tick_passed.disconnect(_on_global_tick_passed)


func _process(delta: float) -> void:
	# 處理工作或休息時的計時邏輯 (隨全域時間流速倍率縮放)
	var g: Node = _get_global()
	var cur_scale: float = g.time_scale if (g and not g.is_time_paused) else 1.0
	if g and g.is_time_paused:
		cur_scale = 0.0

	if _action_timer > 0.0:
		_action_timer -= delta * cur_scale
		if _action_timer <= 0.0:
			_on_action_timer_finished()

# ------------------------------------------------------------------------------
# 6. 全域時間與代謝更新 (Tick Handling & Metabolism)
# ------------------------------------------------------------------------------

func _on_global_tick_passed(current_tick: int) -> void:
	if npc_data == null:
		return

	# 1. 根據目前狀態推進生理代謝
	var is_sleeping: bool = (current_state == State.RESTING)
	var is_working: bool = (current_state == State.WORKING)
	npc_data.tick_update(1, is_sleeping, is_working)

	# 2. 自動決策判斷
	if auto_ai_enabled and not _is_executing_action:
		# 每隔一定 Ticks 或目前處於閒置狀態時觸發 AI 決策
		if current_state == State.IDLE or (_last_decision_tick < 0) or (current_tick - _last_decision_tick >= decision_interval_ticks):
			_last_decision_tick = current_tick
			make_decision(current_tick)

# ------------------------------------------------------------------------------
# 7. AI 決策大腦連結與行為執行 (AI Decision & Execution)
# ------------------------------------------------------------------------------

## 觸發一次 AI 決策
func make_decision(current_tick: int) -> void:
	var global_node: Node = _get_global()
	if global_node == null or npc_data == null:
		return

	var decision_service: DecisionServiceClass = global_node.get_decision_service()
	if decision_service == null:
		return

	# 呼叫決策大腦 (融合排程規則 + 15 維度神經模型)
	var decision: Dictionary = decision_service.evaluate_decision(
		current_tick,
		npc_data.to_feature_vector(),
		npc_data.home_poi_id,
		npc_data.job_id,
		npc_data.food,
		npc_data.lunchbox,
		npc_data.personality_offset
	)

	last_decision = decision

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
	_is_executing_action = true

	# 檢查是否為工作排程 (目標地點為工作 POI 12~19，且為工作行為或排程覆蓋)
	if target_poi in [12, 13, 14, 15, 16, 17, 18, 19] and (action_id in [1, 7, 8] or last_decision.get("is_rule_override", false)):
		_execute_work(npc_data.job_id if npc_data else 1, target_poi)
		return

	match action_id:
		0: # 閒逛
			_execute_wander()
		1: # 閱讀 (圖書館 POI 19)
			_move_to_poi_and_act(target_poi, State.WORKING, 8.0) # 閱讀 8 秒
		2: # 購物 (餐廳 POI 13 或 商店 POI 12)
			_move_to_poi_and_act(target_poi, State.INTERACTING, 5.0)
		3: # 吃東西
			if target_poi == 0:
				# 原地吃便當或料理
				_execute_eat_in_place()
			else:
				# 移動至餐廳進食
				_move_to_poi_and_act(target_poi, State.INTERACTING, 6.0, func():
					# 在餐廳購買並進食
					if npc_data.money >= 10:
						npc_data.consume_item("money", 10)
						npc_data.hunger = clampf(npc_data.hunger + 40.0, 0.0, 100.0)
				)
		4: # 就醫 (醫院 POI 18)
			_move_to_poi_and_act(target_poi, State.RESTING, 10.0, func():
				npc_data.health = clampf(npc_data.health + 30.0, 0.0, 100.0)
				npc_data.hp = clampf(npc_data.hp + 20.0, 0.0, 100.0)
			)
		5: # 回家休息 (自宅 POI)
			_move_to_poi_and_act(target_poi, State.RESTING, 12.0)
		6: # 社交 (社交廣場或周邊 NPC)
			_execute_social_interaction(target_poi)
		7: # 巡田水 (農民專用 POI 16)
			_move_to_poi_and_act(target_poi, State.WORKING, 8.0)
		8: # 販售物品 (商店 POI 12)
			_move_to_poi_and_act(target_poi, State.WORKING, 6.0, func():
				# 販售農作物或礦物換取金錢
				if npc_data.crops > 0:
					var sold: int = npc_data.crops
					npc_data.consume_item("crops", sold)
					npc_data.add_item("money", sold * 5)
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
				6: # 伐木工 -> 產出木材
					npc_data.add_item("wood", 1)
				7: # 農民 -> 產出農作物
					npc_data.add_item("crops", 1)
				8: # 商店店長 -> 販售營業
					npc_data.add_item("money", 4)
	)


## 原地進食
func _execute_eat_in_place() -> void:
	set_state(State.INTERACTING)
	show_bubble(1.5)
	await get_tree().create_timer(1.5).timeout
	npc_data.eat_food(true)
	_complete_current_action()


## 閒逛行為：隨機在附近可通行地塊漫遊
func _execute_wander() -> void:
	var nav = _get_nav_manager()
	if nav == null:
		_complete_current_action()
		return

	var cur_cell: Vector2i = nav.local_to_map(global_position)
	var target_cell: Vector2i = nav.get_random_walkable_neighbor(cur_cell, 5)
	if target_cell == cur_cell:
		# 找不到合適鄰格，原地待機 2 秒
		set_state(State.IDLE)
		_action_timer = 2.0
		return

	move_along_grid(target_cell, func():
		# 到達後待機片刻再結束
		set_state(State.IDLE)
		_action_timer = 2.5
	)


## 前往特定 POI 並切換至目標狀態執行一段時間
func _move_to_poi_and_act(poi_id: int, target_state: State, duration: float, on_arrive: Callable = Callable()) -> void:
	var target_cell: Vector2i = _get_poi_cell(poi_id)
	if target_cell == Vector2i(-1, -1):
		# 無此 POI 座標，降級為原地執行
		set_state(target_state)
		if on_arrive.is_valid():
			on_arrive.call()
		_action_timer = duration
		return

	move_along_grid(target_cell, func():
		set_state(target_state)
		if on_arrive.is_valid():
			on_arrive.call()
		_action_timer = duration
	)


## 社交互動行為
func _execute_social_interaction(target_poi: int) -> void:
	# 尋找視野內或場上其他可社交的 NPC
	var other_npc: NPCController = _find_available_partner()
	if other_npc and is_instance_valid(other_npc):
		var nav = _get_nav_manager()
		if nav:
			var partner_cell: Vector2i = nav.local_to_map(other_npc.global_position)
			var stand_cell: Vector2i = nav.get_closest_walkable_cell(partner_cell, 2)
			if stand_cell != Vector2i(-1, -1):
				move_along_grid(stand_cell, func():
					# 面對面交流
					face_toward(other_npc.global_position)
					other_npc.face_toward(global_position)
					set_state(State.INTERACTING)
					show_bubble(3.0)
					other_npc.show_bubble(3.0)
					# 調整彼此好感度
					npc_data.modify_relationship(other_npc.npc_data.npc_id, 3.0, 2.0)
					other_npc.npc_data.modify_relationship(npc_data.npc_id, 3.0, 2.0)
					_action_timer = 3.2
				)
				return

	# 若無可互動對象，則前往社交廣場 (POI 20) 閒逛
	_move_to_poi_and_act(target_poi, State.IDLE, 4.0)

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
		State.IDLE, State.WORKING, State.RESTING:
			# 定格在當前朝向的第 0 幀
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
		bubble_node.visible = true
		if duration > 0.0:
			var timer = get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(bubble_node):
					bubble_node.visible = false
			)

## 隱藏對話氣泡
func hide_bubble() -> void:
	if bubble_node:
		bubble_node.visible = false

# ------------------------------------------------------------------------------
# 9. 尋路與平滑移動 (A* Movement with Tween)
# ------------------------------------------------------------------------------

## 依據目標網格進行 A* 尋路並開始移動
func move_along_grid(target_cell: Vector2i, on_complete: Callable = Callable()) -> void:
	var nav = _get_nav_manager()
	if nav == null:
		push_warning("[NPCController] 未能取得 NavigationManager，移動終止。")
		_complete_current_action()
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
		# 無法尋得路徑或被阻擋
		push_warning("[NPCController] %s 無法尋得由 %s 至 %s 之有效路徑。" % [name, str(start_cell), str(target_cell)])
		_complete_current_action()
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

	var g: Node = _get_global()
	var cur_scale: float = g.time_scale if (g and not g.is_time_paused) else 1.0
	var actual_duration: float = step_duration / maxf(0.1, cur_scale)

	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_LINEAR)
	_move_tween.tween_property(self, "global_position", next_pos, actual_duration)
	_move_tween.tween_callback(func():
		_step_move(step_index + 1, on_complete)
	)

# ------------------------------------------------------------------------------
# 10. 內部私有輔助函式 (Internal Helpers)
# ------------------------------------------------------------------------------

func _on_action_timer_finished() -> void:
	_complete_current_action()

func _complete_current_action() -> void:
	_is_executing_action = false
	action_completed.emit(current_action_id)
	set_state(State.IDLE)

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

func _find_available_partner() -> NPCController:
	var g: Node = _get_global()
	if g == null:
		return null
	var decision_service = g.get_decision_service()
	var all_npcs: Array[Node2D] = g.get_all_npcs()

	for npc in all_npcs:
		if npc != self and npc is NPCController:
			var ctrl: NPCController = npc as NPCController
			# 檢查該對象是否允許社交 (依照 Google 表格規範：非工作/就醫/閱讀/睡覺)
			if decision_service and decision_service.is_available_for_social(ctrl.current_action_id, ctrl.current_state == State.RESTING):
				return ctrl
	return null

func _vector_to_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

## 取得當前狀態名稱 (中文)
func get_state_name() -> String:
	match current_state:
		State.IDLE: return "待機"
		State.MOVING: return "移動中"
		State.INTERACTING: return "社交中"
		State.WORKING: return "工作中"
		State.RESTING: return "休息中"
	return "未知"

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
