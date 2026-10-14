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
	HOME = 21 ## 自宅 (回家休息)
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

## 全域 AI 決策大腦服務 (NPCDecisionService)
const DecisionServiceClass = preload("res://scripts/ai/decision_service.gd")
var _decision_service: DecisionServiceClass = null

# ------------------------------------------------------------------------------
# 4. 生命週期函式 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	print("[Global] 26號宇宙全域管理器已初始化。當前天數: 第 %d 天, 當前時間: %s" % [current_day, get_formatted_time()])

func _process(delta: float) -> void:
	if is_time_paused or time_scale <= 0.0:
		return
	
	_tick_accumulator += delta * time_scale
	while _tick_accumulator >= seconds_per_tick:
		_tick_accumulator -= seconds_per_tick
		_advance_one_tick()

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

## 手動跳躍指定 Tick (用於除錯與測試)
func debug_fast_forward_ticks(ticks: int) -> void:
	for i in range(ticks):
		_advance_one_tick()

## 執行午夜跨日記憶結算管線 (嚴格對應圖 5: 步驟 1 ~ 10)
func _execute_midnight_settlement() -> void:
	var service: DecisionServiceClass = get_decision_service()
	if service == null or not service.is_database_available():
		print("[Global] 決策服務或記憶資料庫未就緒，略過換日結算。")
		return

	print("[Global] 🌙 開始執行第 %d 天午夜換日記憶結算管線..." % current_day)

	# 步驟 1 ~ 5: 結算 STM -> 清空 STM -> 結算 MTSM (重要性-1/清理) -> 結算 STSM -> 清空 STSM
	var step1_ok: bool = service.execute_midnight_settlement_1()
	if not step1_ok:
		push_error("[Global] 午夜結算前半 (步驟 1~5) 失敗！")
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

# ------------------------------------------------------------------------------
# 6. 導航管理器服務定位器 (Navigation Service Locator)
# ------------------------------------------------------------------------------

## 註冊地圖導航管理器
func register_navigation_manager(nav: Node) -> void:
	_navigation_manager = nav
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
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"current_day": current_day,
		"current_tick": current_tick,
		"formatted_time": get_formatted_time(),
		"time_scale": time_scale,
		"is_time_paused": is_time_paused,
		"npcs": []
	}

	for npc in get_all_npcs():
		if npc and is_instance_valid(npc) and npc.has_method("to_dict"):
			save_data["npcs"].append(npc.to_dict())

	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Global] 無法開啟存檔路徑進行寫入: " + path + " (錯誤碼: %d)" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()
	print("[Global] 💾 遊戲已成功儲存至: %s (共 %d 隻 NPC)" % [path, save_data["npcs"].size()])

	# 開發環境下同步鏡像至 res://data/savegame.json 方便直接查驗
	if OS.has_feature("editor") or OS.is_debug_build():
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
		# 若 user:// 不存在，嘗試載入 res://data/savegame.json 鏡像存檔
		if FileAccess.file_exists(DEV_SAVE_PATH):
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

	print("[Global] 📂 存檔載入成功: 第 %d 天 %s, 已還原 %d 隻 NPC" % [current_day, get_formatted_time(), restored_count])
	tick_passed.emit(current_tick)
	day_passed.emit(current_day)
	time_scale_changed.emit(time_scale)
	time_paused_toggled.emit(is_time_paused)
	game_loaded.emit(path)
	return true

