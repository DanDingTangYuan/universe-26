# ==============================================================================
# 26號宇宙 (Universe 26) - 全域核心單例 (Global Singleton / AutoLoad)
# 檔案路徑: res://scripts/core/global.gd
# 職責描述: 整合全域時間推進、事件匯流排、導航服務定位器、NPC 與 POI 註冊中心
# ==============================================================================
class_name GlobalClass
extends Node

# ------------------------------------------------------------------------------
# 1. 常數與枚舉定義 (Constants & Enums)
# ------------------------------------------------------------------------------

## 每日總 Tick 數 (1440 分鐘 = 24 小時)
const TICKS_PER_DAY: int = 1440

## 每小時的 Tick 數
const TICKS_PER_HOUR: int = 60

## 預設每個 Tick 對應的真實世界秒數 (0.5 秒 = 遊戲內 1 分鐘，1 遊戲日 = 12 分鐘)
const DEFAULT_SECONDS_PER_TICK: float = 0.5

## 行為類型枚舉 (對齊 C# NPCDecision)
enum ActionType {
	WANDER = 0, ## 閒逛
	READ = 1, ## 閱讀
	SHOP = 2, ## 購物
	EAT = 3, ## 吃東西
	MEDICAL = 4, ## 就醫
	REST = 5, ## 回家休息
	SOCIAL = 6, ## 社交
	PATROL = 7, ## 巡田水
	SELL = 8 ## 販售物品
}

## 行為中文名稱對照陣列 (索引嚴格對齊 ActionType 與 C# ActionNames)
const ACTION_NAMES: Array[String] = [
	"閒逛",
	"閱讀",
	"購物",
	"吃東西",
	"就醫",
	"回家休息",
	"社交",
	"巡田水",
	"販售物品"
]

## 地圖設施/興趣點 (POI) 類型代碼 (對齊 C# NPCDecision.GetLocation)
enum LocationType {
	NONE = 0, ## 無 / 原地
	MARKET = 12, ## 市場 (販售物品)
	RESTAURANT = 13, ## 餐廳 (吃東西 / 購物)
	FARM = 16, ## 農田 (巡田水)
	HOSPITAL = 18, ## 醫院 (就醫)
	LIBRARY = 19, ## 圖書館 (閱讀)
	PLAZA = 20, ## 社交廣場 (社交 / 閒逛)
	HOME = 21, ## 自宅 (回家休息)
	NOTICE_BOARD = 22 ## 小鎮布告欄 (閱覽情報 / 傳播公告)
}

# ------------------------------------------------------------------------------
# 2. 全域訊號 (Global Signals / Event Bus)
# ------------------------------------------------------------------------------

## 每推進 1 個 Tick 時發射
signal tick_passed(current_tick: int)

## 每經過 1 個遊戲小時 (60 Ticks) 時發射
signal hour_passed(current_hour: int)

## 跨過新的一天時發射
signal day_passed(current_day: int)

## 每日午夜 (00:00 / Tick 0) 抵達時發射 (觸發 C# 端 LTM/MTM/STM 記憶演化)
signal on_midnight_reached(day_count: int)

## 時間流速倍率改變時發射
signal time_scale_changed(new_scale: float)

## 時間暫停狀態切換時發射
signal time_paused_toggled(is_paused: bool)

## NPC 註冊進全域管理器時發射
signal npc_registered(npc_id: String, npc_node: Node2D)

## NPC 從全域管理器註銷時發射
signal npc_unregistered(npc_id: String)

## 地圖興趣點 (POI) 註冊時發射
signal poi_registered(poi_id: int, cell_pos: Vector2i)

## 導航管理器註冊時發射
signal navigation_manager_registered(nav: Node)

## NPC 開始執行行為時發射 (可供 UI 或觀測器監聽)
@warning_ignore("unused_signal")
signal npc_action_started(npc_id: String, action: ActionType, target_cell: Vector2i)

## NPC 完成行為時發射
@warning_ignore("unused_signal")
signal npc_action_completed(npc_id: String, action: ActionType)

## NPC 被玩家點選/選中時發射
signal npc_selected(npc: Node2D)

## 取消選中 NPC 時發射
signal npc_deselected()

## NPC 死亡時發射 (飢餓衰竭或體力耗盡)
signal npc_died(npc_id: String, reason: String)

## 遊戲存檔成功時發射
signal game_saved(filepath: String)

## 遊戲讀檔成功時發射
signal game_loaded(filepath: String)

## 軌跡錄製狀態變更時發射
signal trajectory_logging_toggled(is_logging: bool)

## 家庭主夫/主婦與同居伴侶完成金錢平分時發射
signal household_money_split(home_poi_id: int, total_money: int, split_amount: int)

## 緊急醫療事件通報時發射 (路人發現倒地者並通報)
signal medical_emergency_reported(patient_id: String, location_cell: Vector2i, reporter_id: String)

## 緊急醫療事件結案時發射 (醫生救醒病患)
signal medical_emergency_resolved(patient_id: String, doctor_id: String)

## NPC 昏厥倒地時發射
signal npc_fainted(npc_id: String, reason: String)

## NPC 被施救甦醒時發射
signal npc_revived(npc_id: String, doctor_id: String)

## 應用程式運行模式枚舉
enum AppMode {
	FORMAL_GAME = 0,     ## 正式遊戲模式 (乾淨介面、正常速度 1x~4x、無背景巨量軌跡寫入)
	SIMULATION_TOOL = 1  ## 模擬觀測工具模式 (全套 AI 監控、60x 極速、軌跡錄製、NPC Inspector)
}

## 當前應用程式模式
var current_app_mode: AppMode = AppMode.FORMAL_GAME

## 當前選取/啟用的存檔槽位 ID (1 ~ 5)
var current_slot_id: int = 1

## 模式切換與模型切換訊號
signal app_mode_changed(new_mode: AppMode)
signal ai_model_type_changed(new_type: int)

## 存檔槽位管理器實例
const SaveSlotManagerClass = preload("res://scripts/core/save_slot_manager.gd")
var _save_slot_manager: SaveSlotManagerClass = null

## 取得存檔槽位管理器實例
func get_save_slot_manager() -> SaveSlotManagerClass:
	if _save_slot_manager == null:
		_save_slot_manager = SaveSlotManagerClass.new()
	return _save_slot_manager

## 切換應用程式運行模式 (正式遊戲 vs 模擬工具)
func set_app_mode(mode: AppMode) -> void:
	current_app_mode = mode
	if current_app_mode == AppMode.FORMAL_GAME:
		if is_trajectory_logging():
			toggle_trajectory_logging()
		if time_scale > 4.0:
			set_time_scale(1.0)
		print("[Global] 🎮 已切換至【正式遊戲模式 (Formal Game Mode)】")
	elif current_app_mode == AppMode.SIMULATION_TOOL:
		if not is_trajectory_logging():
			toggle_trajectory_logging()
		print("[Global] 🔬 已切換至【模擬觀測工具模式 (Simulation & Research Tool Mode)】")
	app_mode_changed.emit(current_app_mode)

## 取得當前應用程式模式
func get_app_mode() -> AppMode:
	return current_app_mode

## 切換全域 AI 決策模型
func set_ai_model_type(type: int) -> void:
	var ds = get_decision_service()
	if ds and ds.has_method("set_ai_model_type"):
		ds.set_ai_model_type(type)
	ai_model_type_changed.emit(type)

## 取得當前 AI 決策模型代碼
func get_ai_model_type() -> int:
	var ds = get_decision_service()
	if ds and ds.has_method("get_ai_model_type"):
		return ds.get_ai_model_type()
	return 0

## 取得當前 AI 決策模型名稱
func get_ai_model_name() -> String:
	var ds = get_decision_service()
	if ds and ds.has_method("get_ai_model_name"):
		return ds.get_ai_model_name()
	return "雙頭 Transformer 大腦"

## 儲存遊戲至指定槽位 (1 ~ 5)
func save_to_slot(slot_id: int) -> bool:
	current_slot_id = slot_id
	return get_save_slot_manager().save_slot(slot_id)

## 從指定槽位載入遊戲 (1 ~ 5)
func load_from_slot(slot_id: int) -> bool:
	current_slot_id = slot_id
	return get_save_slot_manager().load_slot(slot_id)

## 刪除指定槽位 (1 ~ 5)
func delete_slot(slot_id: int) -> bool:
	return get_save_slot_manager().delete_slot(slot_id)

# ------------------------------------------------------------------------------
# 3. 匯出與內部變數 (Properties)
# ------------------------------------------------------------------------------

## 每個 Tick 所需的真實秒數 (可於編輯器調整)
@export var seconds_per_tick: float = DEFAULT_SECONDS_PER_TICK

## 當前遊戲天數 (從第 1 天開始)
var current_day: int = 1

## 當前當日累積 Tick (0 ~ 1439，預設 480 為上午 08:00 晨間活動開始)
var current_tick: int = 480

## 時間流速倍率 (1.0 = 正常, 2.0 = 雙倍速, 0.0 或暫停 = 不推進)
var time_scale: float = 1.0

## 是否暫停時間
var is_time_paused: bool = false

## 內部秒數累計器
var _tick_accumulator: float = 0.0

## 註冊的導航管理器 (Service Locator)
var _navigation_manager: Node = null

## 註冊的所有 NPC 字典 { npc_id: String -> Node2D }
var _registered_npcs: Dictionary = {}

## 註冊的地圖興趣點字典 { poi_id: int -> Vector2i }
var _registered_pois: Dictionary = {}

## 註冊的地圖興趣點完整詮釋資料字典 { poi_id: int -> Dictionary }
var _poi_metadata: Dictionary = {}

## 註冊的所有緊急醫療事件字典 { patient_id: String -> Dictionary }
var _medical_emergencies: Dictionary = {}

## 全域 AI 決策大腦服務 (NPCDecisionService)
const DecisionServiceClass = preload("res://scripts/ai/decision_service.gd")
var _decision_service: DecisionServiceClass = null

## 全域 Transformer 決策軌跡收集器 (TrajectoryLogger)
const TrajectoryLoggerClass = preload("res://scripts/ai/trajectory_logger.gd")
var _trajectory_logger: TrajectoryLoggerClass = null

## 全域情報擴散管理器 (InformationDiffusionManager)
const InformationDiffusionManagerClass = preload("res://scripts/ai/information_diffusion_manager.gd")
var _diffusion_manager: InformationDiffusionManagerClass = null

## 自訂 NPC 性格詞條覆寫字典 { npc_id: String -> Dictionary }
var _custom_npc_traits: Dictionary = {}

# ------------------------------------------------------------------------------
# 4. 生命週期函式 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	_trajectory_logger = TrajectoryLoggerClass.new()
	print("[Global] 26號宇宙全域管理器已初始化。當前天數: 第 %d 天, 當前時間: %s" % [current_day, get_formatted_time()])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _trajectory_logger:
			_trajectory_logger.close()

func _process(delta: float) -> void:
	if is_time_paused or time_scale <= 0.0:
		return
	
	_tick_accumulator += delta * time_scale
	var max_ticks_per_frame: int = 120
	var ticks_processed: int = 0
	while _tick_accumulator >= seconds_per_tick and ticks_processed < max_ticks_per_frame:
		_tick_accumulator -= seconds_per_tick
		_advance_one_tick()
		ticks_processed += 1

# ------------------------------------------------------------------------------
# 5. 時間系統邏輯 (Time System)
# ------------------------------------------------------------------------------

## 內部前進 1 個 Tick
func _advance_one_tick() -> void:
	current_tick += 1
	
	# 檢查是否跨日 (達到 1440 Ticks)
	if current_tick >= TICKS_PER_DAY:
		current_tick = 0
		current_day += 1
		day_passed.emit(current_day)
		on_midnight_reached.emit(current_day)
		print("[Global] 進入新的一天: 第 %d 天，午夜記憶演化觸發！" % current_day)
		_execute_midnight_settlement()
	
	tick_passed.emit(current_tick)
	
	# 整點觸發
	if current_tick % TICKS_PER_HOUR == 0:
		var hour: int = int(float(current_tick) / float(TICKS_PER_HOUR))
		hour_passed.emit(hour)

## 取得正規化時間 (0.0 ~ 1.0)，供神經網路作為時間特徵輸入
func get_normalized_time() -> float:
	return float(current_tick) / float(TICKS_PER_DAY)

## 取得當前小時 (0 ~ 23)
func get_current_hour() -> int:
	return int(float(current_tick) / float(TICKS_PER_HOUR))

## 取得當前分鐘 (0 ~ 59)
func get_current_minute() -> int:
	return current_tick % TICKS_PER_HOUR

## 取得格式化時間字串 "HH:MM"
func get_formatted_time() -> String:
	return "%02d:%02d" % [get_current_hour(), get_current_minute()]

## 設定時間流速倍率
func set_time_scale(scale: float) -> void:
	time_scale = maxf(0.0, scale)
	time_scale_changed.emit(time_scale)

## 設定是否暫停時間
func set_time_paused(paused: bool) -> void:
	if is_time_paused != paused:
		is_time_paused = paused
		time_paused_toggled.emit(is_time_paused)

## 切換暫停狀態
func toggle_time_paused() -> void:
	set_time_paused(not is_time_paused)

## 暫停時間推進
func pause_time() -> void:
	set_time_paused(true)

## 恢復時間推進
func resume_time() -> void:
	set_time_paused(false)

## 手動跳躍指定 Tick (用於除錯與測試)
func debug_fast_forward_ticks(ticks: int) -> void:
	for i in range(ticks):
		_advance_one_tick()

## 執行午夜跨日記憶結算管線 (嚴格對應圖 5: 步驟 1 ~ 10)
func _execute_midnight_settlement() -> void:
	var service: DecisionServiceClass = get_decision_service()
	if service == null or not service.is_database_available():
		print("[Global] 決策服務或記憶資料庫未就緒，略過換日記憶結算。")
		split_homemaker_household_money()
		return

	print("[Global] 🌙 開始執行第 %d 天午夜換日記憶結算管線..." % current_day)
	if _trajectory_logger:
		_trajectory_logger.flush()

	# 步驟 1 ~ 5: 結算 STM -> 清空 STM -> 結算 MTSM (重要性-1/清理) -> 結算 STSM -> 清空 STSM
	var step1_ok: bool = service.execute_midnight_settlement_1()
	if not step1_ok:
		push_error("[Global] 午夜結算前半 (步驟 1~5) 失敗！")
		split_homemaker_household_money()
		return

	# 步驟 6 ~ 10: 針對所有 20 隻 NPC 執行後半結算 (存入 MTM/LTSM、重算歷史分數、載入新權重回傳遊戲端)
	var all_npcs: Array[Node2D] = get_all_npcs()
	var settled_count: int = 0

	for npc_node in all_npcs:
		if not is_instance_valid(npc_node):
			continue
		var data = npc_node.get("npc_data")
		if data == null:
			continue

		var nid_str: String = data.npc_id
		var clean_id: String = nid_str.replace("npc_", "").replace("NPC_", "")
		if not clean_id.is_valid_int():
			continue
		var npc_num: int = clean_id.to_int()
		if npc_num < 1 or npc_num > 20:
			continue

		var stats_dict: Dictionary = data.get_physiological_dict()
		var trust_dict: Dictionary = data.trust
		var fav_dict: Dictionary = data.friendships

		var res: Dictionary = service.execute_midnight_settlement_2(
			npc_num,
			stats_dict,
			trust_dict,
			fav_dict
		)

		if res.get("success", false):
			var new_weights: Array = res.get("action_weights", [])
			var new_scores: Array = res.get("history_scores", [])
			data.apply_settlement_data(new_weights, new_scores)
			settled_count += 1

	print("[Global] ✨ 第 %d 天午夜換日記憶結算完成！共 %d 隻 NPC 行動權重與歷史好壞分數完成演化同步。" % [current_day, settled_count])

	# 步驟 11: 每日午夜結算後：家庭主夫/主婦與同居伴侶平分兩人現有金錢
	split_homemaker_household_money()

## 每日午夜結算後：家庭主夫/主婦 (Job ID 9) 與同居伴侶 (相同 home_poi_id) 平分彼此現有金錢
func split_homemaker_household_money() -> void:
	var all_npcs: Array[Node2D] = get_all_npcs()
	if all_npcs.is_empty():
		return

	# 依照 home_poi_id 分組
	var households: Dictionary = {}
	for npc_node: Node2D in all_npcs:
		if not is_instance_valid(npc_node):
			continue
		var data: NPCData = npc_node.get("npc_data") as NPCData
		if data == null:
			continue
		var h_id: int = data.home_poi_id
		if h_id <= 0:
			continue
		if not households.has(h_id):
			households[h_id] = []
		households[h_id].append(data)

	var split_count: int = 0
	for h_id: int in households.keys():
		var residents: Array = households[h_id]
		if residents.size() < 2:
			continue

		# 檢查該住處是否包含家庭主夫/主婦 (job_id == 9)
		var has_homemaker: bool = false
		for r_data in residents:
			if r_data.job_id == 9:
				has_homemaker = true
				break

		if not has_homemaker:
			continue

		var total_money: int = 0
		var names: Array[String] = []
		for r_data in residents:
			total_money += r_data.money
			names.append(r_data.npc_name)

		var n: int = residents.size()
		var split_amount: int = int(total_money / n)
		var remainder: int = total_money % n

		for i in range(n):
			var r_data = residents[i]
			var assigned: int = split_amount + (1 if i < remainder else 0)
			r_data.money = assigned
			r_data.stats_changed.emit(r_data.npc_id)
			r_data.add_stm_event("🏠 同居伴侶金錢平分：獲得 $%d (家庭總資產 $%d)" % [assigned, total_money])

		split_count += 1
		household_money_split.emit(h_id, total_money, split_amount)
		print("[Global] 🏠 自宅 POI %d (%s) 完成夫妻金錢平分：家庭總資產 $%d -> 各分得 $%d。" % [
			h_id, " & ".join(names), total_money, split_amount
		])

	if split_count > 0:
		print("[Global] 💰 共有 %d 戶家庭主夫/主婦家庭完成午夜資產平分。" % split_count)

# ------------------------------------------------------------------------------
# 6. 導航管理器服務定位器 (Navigation Service Locator)
# ------------------------------------------------------------------------------

## 註冊地圖導航管理器
func register_navigation_manager(nav: Node) -> void:
	_navigation_manager = nav
	navigation_manager_registered.emit(nav)
	print("[Global] NavigationManager 註冊成功: ", nav.name)

## 註銷地圖導航管理器
func unregister_navigation_manager() -> void:
	_navigation_manager = null
	print("[Global] NavigationManager 已註銷")

## 取得地圖導航管理器
func get_navigation_manager() -> Node:
	return _navigation_manager

## 檢查是否有可用的導航管理器
func has_navigation_manager() -> bool:
	return _navigation_manager != null and is_instance_valid(_navigation_manager)

# ------------------------------------------------------------------------------
# 7. NPC 實體註冊中心 (NPC Registry)
# ------------------------------------------------------------------------------

## 註冊 NPC
func register_npc(npc_id: String, npc_node: Node2D) -> void:
	if npc_id.is_empty():
		push_error("[Global] 註冊失敗: NPC ID 不可為空字串！")
		return
	_registered_npcs[npc_id] = npc_node
	npc_registered.emit(npc_id, npc_node)

## 註銷 NPC
func unregister_npc(npc_id: String) -> void:
	if _registered_npcs.has(npc_id):
		_registered_npcs.erase(npc_id)
		npc_unregistered.emit(npc_id)

## 透過 ID 取得特定 NPC
func get_npc(npc_id: String) -> Node2D:
	if _registered_npcs.has(npc_id):
		var node: Node2D = _registered_npcs[npc_id]
		if is_instance_valid(node):
			return node
		else:
			_registered_npcs.erase(npc_id)
	return null

## 取得所有已註冊的 NPC 陣列
func get_all_npcs() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for id: String in _registered_npcs.keys():
		var node: Node2D = _registered_npcs[id]
		if is_instance_valid(node):
			result.append(node)
	return result

## 檢查特定 NPC 是否存在
func has_npc(npc_id: String) -> bool:
	return _registered_npcs.has(npc_id) and is_instance_valid(_registered_npcs[npc_id])

## 選中特定 NPC
func select_npc(npc: Node2D) -> void:
	if _selected_npc == npc:
		return
	_selected_npc = npc
	npc_selected.emit(npc)

## 取消選中當前 NPC
func deselect_npc() -> void:
	if _selected_npc != null:
		_selected_npc = null
		npc_deselected.emit()

## 取得目前選中的 NPC
func get_selected_npc() -> Node2D:
	if _selected_npc != null and is_instance_valid(_selected_npc):
		return _selected_npc
	_selected_npc = null
	return null

var _selected_npc: Node2D = null

# ------------------------------------------------------------------------------
# 8. POI / 設施註冊中心 (Point of Interest Registry)
# ------------------------------------------------------------------------------

## 註冊興趣點 (傳入 LocationType 或自訂 ID，與地圖網格座標 Vector2i，以及可選的完整資料字典)
func register_poi(poi_id: int, cell_pos: Vector2i, details: Dictionary = {}) -> void:
	_registered_pois[poi_id] = cell_pos
	_poi_metadata[poi_id] = details.duplicate()
	poi_registered.emit(poi_id, cell_pos)
	print("[Global] 註冊 POI 成功: ID=%d, Cell=%s" % [poi_id, str(cell_pos)])

## 取得特定 POI 的網格座標 (找不到時回傳 Vector2i(-1, -1))
func get_poi_cell(poi_id: int) -> Vector2i:
	if _registered_pois.has(poi_id):
		return _registered_pois[poi_id]
	push_warning("[Global] 找不到對應的 POI: ID=%d" % poi_id)
	return Vector2i(-1, -1)

## 取得特定 POI 的完整設定資料 (包含 concealed, entrance_dir, radius, doors, polygon 等)
func get_poi_data(poi_id: int) -> Dictionary:
	if _poi_metadata.has(poi_id):
		return _poi_metadata[poi_id].duplicate()
	return {}

## 查詢特定 POI 是否為隱藏/進入建築物設施
func is_poi_concealed(poi_id: int) -> bool:
	if _poi_metadata.has(poi_id):
		return bool(_poi_metadata[poi_id].get("concealed", false))
	return false

## 取得特定 POI 的進出入口朝向 ("south", "north", "east", "west")
func get_poi_entrance_dir(poi_id: int) -> String:
	if _poi_metadata.has(poi_id):
		return str(_poi_metadata[poi_id].get("entrance_dir", "south"))
	return "south"

## 檢查特定 POI 是否已註冊
func has_poi(poi_id: int) -> bool:
	return _registered_pois.has(poi_id)

## 取得所有 POI 字典副本
func get_all_pois() -> Dictionary:
	return _registered_pois.duplicate()

# ------------------------------------------------------------------------------
# 8.5 緊急醫療通報與外勤救援中心 (Medical Emergency & Rescue Dispatch)
# ------------------------------------------------------------------------------

## 通報緊急醫療事件 (由路人或觀測者觸發)
func report_medical_emergency(patient_id: String, world_pos: Vector2, location_cell: Vector2i, reporter_id: String) -> void:
	if patient_id.is_empty():
		return
	if _medical_emergencies.has(patient_id):
		var em: Dictionary = _medical_emergencies[patient_id]
		if em.get("status", "") == "RESOLVED":
			em["status"] = "PENDING"
			em["world_pos"] = [world_pos.x, world_pos.y]
			em["location_cell"] = [location_cell.x, location_cell.y]
			em["reporter_id"] = reporter_id
			em["reported_tick"] = current_tick
			em["assigned_doctor_id"] = ""
			_medical_emergencies[patient_id] = em
	else:
		_medical_emergencies[patient_id] = {
			"patient_id": patient_id,
			"world_pos": [world_pos.x, world_pos.y],
			"location_cell": [location_cell.x, location_cell.y],
			"reporter_id": reporter_id,
			"reported_tick": current_tick,
			"assigned_doctor_id": "",
			"status": "PENDING"
		}
	medical_emergency_reported.emit(patient_id, location_cell, reporter_id)
	print("[Global] 🚨 緊急醫療通報！路人 %s 通報 %s 於地塊 %s 昏厥倒地，等待醫護人員救援！" % [
		reporter_id, patient_id, str(location_cell)
	])

## 結案緊急醫療事件 (醫生完成施救)
func resolve_medical_emergency(patient_id: String, doctor_id: String) -> void:
	if _medical_emergencies.has(patient_id):
		_medical_emergencies[patient_id]["status"] = "RESOLVED"
		_medical_emergencies[patient_id]["resolved_by"] = doctor_id
		_medical_emergencies[patient_id]["resolved_tick"] = current_tick
	medical_emergency_resolved.emit(patient_id, doctor_id)
	print("[Global] 💉 緊急醫療救援完成！醫護人員 %s 已成功將 %s 施救甦醒。" % [doctor_id, patient_id])

## 查詢特定 NPC 是否處於活躍的緊急急救事件中 (PENDING 或 DISPATCHED)
func is_emergency_active(patient_id: String) -> bool:
	if _medical_emergencies.has(patient_id):
		var st: String = str(_medical_emergencies[patient_id].get("status", ""))
		return st == "PENDING" or st == "DISPATCHED"
	return false

## 查詢全域是否有未派工的緊急醫療事件
func has_pending_emergency() -> bool:
	for pid: String in _medical_emergencies.keys():
		var em: Dictionary = _medical_emergencies[pid]
		if em.get("status", "") == "PENDING":
			return true
	return false

## 取得可指派之緊急急救事件
func get_pending_emergency(doctor_id: String = "") -> Dictionary:
	for pid: String in _medical_emergencies.keys():
		var em: Dictionary = _medical_emergencies[pid]
		if em.get("status", "") == "PENDING":
			return em
		elif not doctor_id.is_empty() and em.get("status", "") == "DISPATCHED" and em.get("assigned_doctor_id", "") == doctor_id:
			return em
	return {}

## 將急救事件指派給當班醫生
func assign_doctor_to_emergency(patient_id: String, doctor_id: String) -> void:
	if _medical_emergencies.has(patient_id):
		_medical_emergencies[patient_id]["status"] = "DISPATCHED"
		_medical_emergencies[patient_id]["assigned_doctor_id"] = doctor_id
		print("[Global] 🚑 醫護人員 %s 接單前往現場急救 %s！" % [doctor_id, patient_id])

## 檢查醫院當前是否有其他非醫護人員病患正在就診
func is_hospital_busy() -> bool:
	var all_npcs: Array[Node2D] = get_all_npcs()
	for npc: Node2D in all_npcs:
		if npc and is_instance_valid(npc):
			var data = npc.get("npc_data")
			if data != null and data.job_id == 5:
				continue # 醫護人員自身不算病患
			var act_id = npc.get("current_action_id")
			var is_exec = npc.get("_is_executing_action")
			if act_id == 4 and is_exec:
				return true
			var nav = get_navigation_manager()
			if nav and has_poi(18):
				var hosp_cell: Vector2i = get_poi_cell(18)
				var npc_cell: Vector2i = nav.local_to_map(npc.global_position)
				if npc_cell == hosp_cell and int(npc.get("current_state")) in [2, 4]:
					return true
	return false

## NPC 進入昏厥時通報全域
func on_npc_fainted(npc_id: String, reason: String) -> void:
	npc_fainted.emit(npc_id, reason)

## NPC 甦醒時通報全域
func on_npc_revived(npc_id: String, doctor_id: String) -> void:
	npc_revived.emit(npc_id, doctor_id)

## 測試/除錯：隨機挑選一名非醫護 NPC 觸發昏迷倒地，便於觀測路人通報與醫生出診
func trigger_random_medical_emergency() -> void:
	var candidates: Array[Node2D] = []
	for npc: Node2D in get_all_npcs():
		if npc and is_instance_valid(npc):
			var data = npc.get("npc_data")
			if data != null and data.job_id != 5 and not npc.get("is_fainted") and not npc.get("is_dead"):
				candidates.append(npc)
	if candidates.size() > 0:
		var chosen: Node2D = candidates.pick_random()
		if chosen.has_method("faint"):
			chosen.faint("突發重度暈眩體力枯竭")
			print("[Global] 🧪 已對 %s 觸發測試昏倒事件！" % (chosen.npc_data.npc_name if chosen.get("npc_data") else chosen.name))

# ------------------------------------------------------------------------------
# 9. 工具輔助函式 (Helper Methods)
# ------------------------------------------------------------------------------

## 依據行為 ID 取得行為中文名稱
func get_action_name(action_id: int) -> String:
	if action_id >= 0 and action_id < ACTION_NAMES.size():
		return ACTION_NAMES[action_id]
	return "未知行為"

## 取得全域 AI 決策大腦服務實例 (延遲單例化)
func get_decision_service() -> DecisionServiceClass:
	if _decision_service == null:
		_decision_service = DecisionServiceClass.new()
	return _decision_service

## 取得全域 Transformer 軌跡收集器實例 (延遲單例化)
func get_trajectory_logger() -> TrajectoryLoggerClass:
	if _trajectory_logger == null:
		_trajectory_logger = TrajectoryLoggerClass.new()
	return _trajectory_logger

## 切換軌跡錄製開關
func toggle_trajectory_logging() -> bool:
	var logger = get_trajectory_logger()
	var state: bool = logger.toggle_logging()
	trajectory_logging_toggled.emit(state)
	return state

## 查詢目前是否正在錄製軌跡
func is_trajectory_logging() -> bool:
	return _trajectory_logger != null and _trajectory_logger.is_logging

## 取得全域情報擴散管理器實例 (延遲單例化)
func get_diffusion_manager() -> InformationDiffusionManagerClass:
	if _diffusion_manager == null:
		_diffusion_manager = InformationDiffusionManagerClass.new()
	return _diffusion_manager

## 取得指定 NPC 的自訂性格詞條
func get_custom_npc_traits(npc_id: String) -> Dictionary:
	return _custom_npc_traits.get(npc_id, {})

## 設定指定 NPC 的自訂性格詞條
func set_custom_npc_traits(npc_id: String, traits_dict: Dictionary) -> void:
	_custom_npc_traits[npc_id] = traits_dict

## 取得所有 NPC 的自訂性格詞條
func get_all_custom_npc_traits() -> Dictionary:
	return _custom_npc_traits

## 批次載入自訂性格詞條
func set_all_custom_npc_traits(traits_map: Dictionary) -> void:
	_custom_npc_traits = traits_map.duplicate(true)

## NPC 死亡事件匯流排轉發
func on_npc_died(npc_id: String, reason: String) -> void:
	print("[Global] ⚠️ NPC 死亡公告: %s 原因: %s" % [npc_id, reason])
	npc_died.emit(npc_id, reason)

# ------------------------------------------------------------------------------
# 10. 遊戲存檔與讀檔系統 (Save & Load System)
# ------------------------------------------------------------------------------

const DEFAULT_SAVE_PATH: String = "user://universe26_save.json"
const DEV_SAVE_PATH: String = "res://data/savegame.json"

## 儲存遊戲進度 (天數、時間、所有 NPC 實體狀態與 15 維度代謝數值)
func save_game(filepath: String = "") -> bool:
	var path: String = filepath if not filepath.is_empty() else DEFAULT_SAVE_PATH
	var save_data: Dictionary = {
		"version": "1.1",
		"timestamp": Time.get_datetime_string_from_system(),
		"current_day": current_day,
		"current_tick": current_tick,
		"formatted_time": get_formatted_time(),
		"time_scale": time_scale,
		"is_time_paused": is_time_paused,
		"slot_id": current_slot_id,
		"app_mode": int(current_app_mode),
		"app_mode_name": "正式遊戲模式" if current_app_mode == AppMode.FORMAL_GAME else "模擬工具模式",
		"ai_model_type": get_ai_model_type(),
		"ai_model_name": get_ai_model_name(),
		"medical_emergencies": _medical_emergencies.duplicate(true),
		"diffusion_manager": get_diffusion_manager().to_dict(),
		"custom_npc_traits": _custom_npc_traits.duplicate(true),
		"npcs": []
	}

	var all_npcs: Array[Node2D] = get_all_npcs()
	var alive_count: int = 0
	var mood_sum: float = 0.0
	var total_money: int = 0

	for npc in all_npcs:
		if npc and is_instance_valid(npc) and npc.has_method("to_dict"):
			var ndict: Dictionary = npc.to_dict()
			save_data["npcs"].append(ndict)
			var vitals: Dictionary = ndict.get("npc_data", {}).get("stats", {})
			if vitals.is_empty():
				vitals = ndict.get("stats", {})
			if float(vitals.get("hp", 100.0)) > 0.0:
				alive_count += 1
			mood_sum += float(vitals.get("mood", 50.0))
			total_money += int(vitals.get("money", 0))

	save_data["alive_npc_count"] = alive_count
	save_data["total_npc_count"] = all_npcs.size()
	save_data["average_mood"] = snappedf(mood_sum / maxf(1.0, float(all_npcs.size())), 0.1) if all_npcs.size() > 0 else 100.0
	save_data["total_town_money"] = total_money

	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Global] 無法開啟存檔路徑進行寫入: " + path + " (錯誤碼: %d)" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()
	print("[Global] 💾 遊戲已成功儲存至: %s (槽位: %d, 共 %d 隻 NPC, 模式: %s, 模型: %s)" % [
		path, current_slot_id, save_data["npcs"].size(), save_data["app_mode_name"], save_data["ai_model_name"]
	])

	# 開發環境下同步鏡像至 res://data/savegame.json 方便直接查驗
	if OS.has_feature("editor"):
		var dev_file: FileAccess = FileAccess.open(DEV_SAVE_PATH, FileAccess.WRITE)
		if dev_file != null:
			dev_file.store_string(json_string)
			dev_file.close()

	game_saved.emit(path)
	return true

## 載入遊戲進度
func load_game(filepath: String = "") -> bool:
	var path: String = filepath if not filepath.is_empty() else DEFAULT_SAVE_PATH
	if not FileAccess.file_exists(path):
		# 僅在 Godot 編輯器開發模式下，才 fallback 讀取 res:// 鏡像
		if OS.has_feature("editor") and FileAccess.file_exists(DEV_SAVE_PATH):
			path = DEV_SAVE_PATH
		else:
			push_warning("[Global] 找不到可用的存檔檔案: " + path)
			return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Global] 無法讀取存檔檔案: " + path)
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or not (parsed is Dictionary):
		push_error("[Global] 存檔格式解析失敗 (非合法 JSON 字典)")
		return false

	var data: Dictionary = parsed as Dictionary
	current_day = int(data.get("current_day", current_day))
	current_tick = int(data.get("current_tick", current_tick))
	time_scale = float(data.get("time_scale", time_scale))
	is_time_paused = bool(data.get("is_time_paused", false))

	if data.has("slot_id"):
		current_slot_id = int(data["slot_id"])
	if data.has("app_mode"):
		set_app_mode(int(data["app_mode"]) as AppMode)
	if data.has("ai_model_type"):
		set_ai_model_type(int(data["ai_model_type"]))

	if data.has("medical_emergencies") and data["medical_emergencies"] is Dictionary:
		_medical_emergencies = (data["medical_emergencies"] as Dictionary).duplicate(true)
	else:
		_medical_emergencies.clear()

	if data.has("diffusion_manager") and data["diffusion_manager"] is Dictionary:
		get_diffusion_manager().from_dict(data["diffusion_manager"])

	if data.has("custom_npc_traits") and data["custom_npc_traits"] is Dictionary:
		_custom_npc_traits = (data["custom_npc_traits"] as Dictionary).duplicate(true)

	# 還原 NPC 實體數據
	var npcs_data: Array = data.get("npcs", [])
	var restored_count: int = 0
	for npc_dict in npcs_data:
		if npc_dict is Dictionary:
			var nid: String = String(npc_dict.get("npc_id", ""))
			var npc_node: Node2D = get_npc(nid)
			if npc_node and is_instance_valid(npc_node) and npc_node.has_method("from_dict"):
				npc_node.from_dict(npc_dict)
				restored_count += 1

	print("[Global] 📂 存檔載入成功: 第 %d 天 %s, 已還原 %d 隻 NPC (模型: %s)" % [
		current_day, get_formatted_time(), restored_count, get_ai_model_name()
	])
	tick_passed.emit(current_tick)
	day_passed.emit(current_day)
	time_scale_changed.emit(time_scale)
	time_paused_toggled.emit(is_time_paused)
	game_loaded.emit(path)
	return true

## 是否請求全新開局 (由 start_new_game 觸發，通知 NPCSpawner 重置世界與資料庫)
var is_new_game_requested: bool = false

## 重新開局載入後是否自動進入遊戲跳過標題選單
var skip_title_screen_on_reload: bool = false

## 是否已有進行中的遊戲會話 (可供標題畫面判斷是否顯示「繼續遊戲」)
var has_active_session: bool = false

## 重新開局 (全新遊戲)：重置時間、重新初始化 SQLite 記憶資料庫並重啟主場景
func start_new_game(reset_memory_db: bool = true) -> void:
	print("[Global] 🔄 正在啟動全新開局流程...")
	current_day = 1
	current_tick = 480 # 上午 08:00
	time_scale = 1.0
	is_time_paused = false
	_tick_accumulator = 0.0
	is_new_game_requested = true
	skip_title_screen_on_reload = true
	has_active_session = true

	# 1. 重置 SQLite 6 大資料庫 (STSM, MTSM, LTSM, STM, MTM, LTM)
	if reset_memory_db:
		var ds = get_decision_service()
		if ds and ds.has_method("initialize_memory_database"):
			ds.initialize_memory_database("", true)
			print("[Global] 記憶資料庫已完成強制重置！")

	# 2. 清理實體快取與緊急事件
	_registered_npcs.clear()
	_medical_emergencies.clear()

	# 3. 廣播重置訊號
	tick_passed.emit(current_tick)
	day_passed.emit(current_day)
	time_scale_changed.emit(time_scale)
	time_paused_toggled.emit(is_time_paused)

	# 4. 重新載入當前場景
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.reload_current_scene()


