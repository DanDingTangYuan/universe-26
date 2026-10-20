# ==============================================================================
# 26號宇宙 (Universe 26) - 存檔槽位管理器 (Save Slot Manager)
# 檔案路徑: res://scripts/core/save_slot_manager.gd
# 職責描述: 
#   1. 管理多槽位存檔 (支援 Slot 1 ~ 5)
#   2. 解析並快取存檔槽位之詮釋資料 (天數、時間、現實存檔時間、存活NPC數、平均心情等)
#   3. 支援儲存、載入、覆蓋確認與刪除槽位
#   4. 相容舊版單一存檔 (若 Slot 1 不存在，自動對齊至 res://data/savegame.json)
# ==============================================================================
class_name SaveSlotManager
extends RefCounted

# ------------------------------------------------------------------------------
# 1. 常數與設定 (Constants)
# ------------------------------------------------------------------------------

const MAX_SLOTS: int = 5
const SAVE_DIR_USER: String = "user://saves"
const SAVE_DIR_DEV: String = "res://data/saves"
const LEGACY_SAVE_DEV: String = "res://data/savegame.json"
const LEGACY_SAVE_USER: String = "user://universe26_save.json"

# ------------------------------------------------------------------------------
# 2. 訊號定義 (Signals)
# ------------------------------------------------------------------------------

signal slot_saved(slot_id: int, metadata: Dictionary)
signal slot_loaded(slot_id: int, metadata: Dictionary)
signal slot_deleted(slot_id: int)

# ------------------------------------------------------------------------------
# 3. 槽位路徑與目錄維護 (Path Resolution & Directory Helpers)
# ------------------------------------------------------------------------------

## 取得指定 Slot 的主要存檔路徑 (user://)
func get_slot_path(slot_id: int) -> String:
	_ensure_save_directories()
	return "%s/slot_%d.json" % [SAVE_DIR_USER, slot_id]

## 取得指定 Slot 的獨立 SQLite 記憶資料庫路徑 (user://saves/slot_X_memory.db)
func get_slot_db_path(slot_id: int) -> String:
	_ensure_save_directories()
	return "%s/slot_%d_memory.db" % [SAVE_DIR_USER, slot_id]

## 取得執行期活動記憶資料庫路徑 (user://saves/active_memory.db)
func get_active_db_path() -> String:
	_ensure_save_directories()
	return "%s/active_memory.db" % SAVE_DIR_USER

## 取得指定 Slot 的開發鏡像路徑 (res://data/saves/)
func get_slot_dev_path(slot_id: int) -> String:
	_ensure_save_directories()
	return "%s/slot_%d.json" % [SAVE_DIR_DEV, slot_id]

## 取得指定 Slot 的開發鏡像資料庫路徑 (res://data/saves/slot_X_memory.db)
func get_slot_dev_db_path(slot_id: int) -> String:
	_ensure_save_directories()
	return "%s/slot_%d_memory.db" % [SAVE_DIR_DEV, slot_id]

## 確保存檔目錄存在
func _ensure_save_directories() -> void:
	# 建立 user://saves
	if not DirAccess.dir_exists_absolute(SAVE_DIR_USER):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR_USER)

	# 若處於 Godot 編輯器模式，建立 res://data/saves 鏡像目錄
	if OS.has_feature("editor"):
		if not DirAccess.dir_exists_absolute(SAVE_DIR_DEV):
			DirAccess.make_dir_recursive_absolute(SAVE_DIR_DEV)

## 尋找指定 Slot 現存的最佳讀取路徑 (優先 user://，僅在 Editor 模式下才相容 res://)
func find_active_slot_path(slot_id: int) -> String:
	var user_path: String = get_slot_path(slot_id)
	if FileAccess.file_exists(user_path):
		return user_path

	# 嚴格防護：只有在 Godot 編輯器內開發時，才 fallback 讀取 res:// 鏡像
	# 打包後的正式遊戲環境 (Windows/macOS/Linux) 嚴格只認 user://，絕不讀取 .pck 內的唯讀開發存檔
	if OS.has_feature("editor"):
		var dev_path: String = get_slot_dev_path(slot_id)
		if FileAccess.file_exists(dev_path):
			return dev_path

		# 若是 Slot 1 且尚無 slot_1.json，檢查是否存在舊版 savegame.json
		if slot_id == 1:
			if FileAccess.file_exists(LEGACY_SAVE_DEV):
				return LEGACY_SAVE_DEV

	return ""

# ------------------------------------------------------------------------------
# 4. 槽位詮釋資料讀取 (Metadata Inspection)
# ------------------------------------------------------------------------------

## 讀取指定 Slot 的詮釋資料 (無需完全還原所有 NPC 實體)
func get_slot_metadata(slot_id: int) -> Dictionary:
	var path: String = find_active_slot_path(slot_id)
	if path.is_empty():
		return {
			"slot_id": slot_id,
			"is_empty": true,
			"display_title": "空白存檔槽位 (Empty Slot)",
			"file_path": ""
		}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"slot_id": slot_id,
			"is_empty": true,
			"display_title": "存檔讀取異常",
			"file_path": path
		}

	var text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {
			"slot_id": slot_id,
			"is_empty": true,
			"display_title": "存檔損毀 (非有效 JSON)",
			"file_path": path
		}

	var data: Dictionary = parsed as Dictionary
	var npcs_list: Array = data.get("npcs", [])
	var alive_count: int = 0
	var total_money: int = 0
	var mood_sum: float = 0.0

	for n in npcs_list:
		if n is Dictionary:
			var vitals: Dictionary = n.get("npc_data", {}).get("stats", {})
			if vitals.is_empty():
				vitals = n.get("stats", {})
			var hp: float = float(vitals.get("hp", 100.0))
			if hp > 0.0:
				alive_count += 1
			mood_sum += float(vitals.get("mood", 50.0))
			total_money += int(vitals.get("money", 0))

	var avg_mood: float = (mood_sum / maxf(1.0, float(npcs_list.size()))) if npcs_list.size() > 0 else 100.0
	var timestamp_str: String = String(data.get("timestamp", "未知時間"))
	var day_val: int = int(data.get("current_day", 1))
	var time_str: String = String(data.get("formatted_time", "08:00"))
	var ai_model_str: String = String(data.get("ai_model_name", "雙頭 Transformer 大腦"))
	var app_mode_str: String = String(data.get("app_mode_name", "正式遊戲模式"))

	return {
		"slot_id": slot_id,
		"is_empty": false,
		"display_title": "第 %d 天 • %s" % [day_val, time_str],
		"current_day": day_val,
		"current_tick": int(data.get("current_tick", 480)),
		"formatted_time": time_str,
		"timestamp": timestamp_str,
		"alive_count": alive_count if alive_count > 0 else npcs_list.size(),
		"total_count": npcs_list.size(),
		"average_mood": snappedf(avg_mood, 0.1),
		"total_money": total_money,
		"ai_model_name": ai_model_str,
		"app_mode_name": app_mode_str,
		"file_path": path
	}

## 獲取所有 5 個 Slot 的完整詮釋資料列表
func get_all_slots_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(1, MAX_SLOTS + 1):
		result.append(get_slot_metadata(i))
	return result

# ------------------------------------------------------------------------------
# 5. 槽位儲存、載入與刪除 (Slot Operations)
# ------------------------------------------------------------------------------

## 儲存遊戲至指定槽位 (含世界狀態 JSON 與專屬 SQLite 記憶資料庫)
func save_slot(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		push_error("[SaveSlotManager] 無效的槽位 ID: %d (需介於 1 ~ %d)" % [slot_id, MAX_SLOTS])
		return false

	var global_node: Node = Engine.get_main_loop().root.get_node_or_null("Global") if Engine.get_main_loop() else null
	if global_node == null or not global_node.has_method("save_game"):
		push_error("[SaveSlotManager] 找不到 Global 單例進行存檔")
		return false

	# 1. 儲存遊戲主資料 JSON
	var target_user_path: String = get_slot_path(slot_id)
	var ok: bool = global_node.save_game(target_user_path)
	if not ok:
		return false

	# 2. 同步獨立 SQLite 記憶資料庫 (active_memory.db -> slot_X_memory.db)
	var ds = global_node.get_decision_service() if global_node.has_method("get_decision_service") else null
	if ds:
		var active_db: String = ds.get_active_database_path()
		var slot_db: String = get_slot_db_path(slot_id)
		if ds.has_memory_database(active_db):
			ds.copy_database(active_db, slot_db)
			print("[SaveSlotManager] 🧠 槽位 %d 記憶資料庫已同步封存至: %s" % [slot_id, slot_db])

	# 3. 僅在 Godot 編輯器開發模式下，額外同步鏡像至 res://data/saves/
	if OS.has_feature("editor"):
		var dev_path: String = get_slot_dev_path(slot_id)
		var user_file: FileAccess = FileAccess.open(target_user_path, FileAccess.READ)
		if user_file != null:
			var content: String = user_file.get_as_text()
			user_file.close()
			var dev_file: FileAccess = FileAccess.open(dev_path, FileAccess.WRITE)
			if dev_file != null:
				dev_file.store_string(content)
				dev_file.close()

	var meta: Dictionary = get_slot_metadata(slot_id)
	slot_saved.emit(slot_id, meta)
	print("[SaveSlotManager] 💾 槽位 %d 儲存成功！" % slot_id)
	return true

## 從指定槽位載入遊戲 (還原專屬記憶資料庫與世界狀態)
func load_slot(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		push_error("[SaveSlotManager] 無效的槽位 ID: %d" % slot_id)
		return false

	var active_path: String = find_active_slot_path(slot_id)
	if active_path.is_empty():
		push_warning("[SaveSlotManager] 槽位 %d 為空，無法載入" % slot_id)
		return false

	var global_node: Node = Engine.get_main_loop().root.get_node_or_null("Global") if Engine.get_main_loop() else null
	if global_node == null or not global_node.has_method("load_game"):
		push_error("[SaveSlotManager] 找不到 Global 單例進行讀檔")
		return false

	# 1. 還原獨立 SQLite 記憶資料庫 (slot_X_memory.db -> active_memory.db)
	var ds = global_node.get_decision_service() if global_node.has_method("get_decision_service") else null
	var slot_db: String = get_slot_db_path(slot_id)
	var active_db: String = get_active_db_path()
	if ds:
		if ds.has_memory_database(slot_db):
			ds.copy_database(slot_db, active_db)
			ds.set_active_database_path(active_db)
			print("[SaveSlotManager] 🧠 槽位 %d 記憶資料庫已還原至活動庫: %s" % [slot_id, active_db])
		else:
			# 若該槽位尚無專屬 DB，確保 active_db 存在
			if not ds.has_memory_database(active_db):
				ds.initialize_memory_database(active_db, false)

	# 2. 載入遊戲主資料 JSON 並還原實體狀態
	var ok: bool = global_node.load_game(active_path)
	if ok:
		var meta: Dictionary = get_slot_metadata(slot_id)
		slot_loaded.emit(slot_id, meta)
		print("[SaveSlotManager] 📂 槽位 %d 載入成功！" % slot_id)
		return true

	return false

## 刪除指定槽位的存檔 (徹底刪除 JSON 與專屬 SQLite 資料庫)
func delete_slot(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return false

	var global_node: Node = Engine.get_main_loop().root.get_node_or_null("Global") if Engine.get_main_loop() else null
	if global_node:
		var ds = global_node.get_decision_service() if global_node.has_method("get_decision_service") else null
		if ds and ds.has_method("clear_database_connections"):
			ds.clear_database_connections()

	var user_path: String = get_slot_path(slot_id)
	var user_db_path: String = get_slot_db_path(slot_id)

	var deleted: bool = false

	# 刪除 user:// JSON 存檔
	if FileAccess.file_exists(user_path):
		if DirAccess.remove_absolute(user_path) == OK:
			deleted = true

	# 刪除 user:// 專屬 SQLite DB 與相關日誌檔
	for ext in ["", "-wal", "-shm", "-journal"]:
		var p: String = user_db_path + ext
		if FileAccess.file_exists(p):
			if DirAccess.remove_absolute(p) == OK:
				deleted = true

	# 僅在 Godot 編輯器模式下清除 res:// 開發鏡像
	if OS.has_feature("editor"):
		var dev_path: String = get_slot_dev_path(slot_id)
		var dev_db_path: String = get_slot_dev_db_path(slot_id)
		if FileAccess.file_exists(dev_path):
			if DirAccess.remove_absolute(dev_path) == OK:
				deleted = true
		for ext in ["", "-wal", "-shm", "-journal"]:
			var dp: String = dev_db_path + ext
			if FileAccess.file_exists(dp):
				if DirAccess.remove_absolute(dp) == OK:
					deleted = true

	if deleted:
		slot_deleted.emit(slot_id)
		print("[SaveSlotManager] 🗑️ 槽位 %d (JSON 與記憶 DB) 已徹底刪除" % slot_id)
		return true

	return false

