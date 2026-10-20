# ==============================================================================
# 26號宇宙 (Universe 26) - 獨立 POI 視覺化與全屬性自訂工具 (POI Visual Editor)
# 檔案路徑: res://tools/poi_editor/poi_editor.gd
# 職責描述: 
#   1. 提供滑鼠點選設定 23 大 POI 之【單點門口】、【雙格/多門口】、【多邊形範圍】
#   2. 提供完整屬性視覺化配置：
#      - 是否進屋/進洞隱藏 (concealed: true / false)
#      - 進出門朝向 (entrance_dir: south / north / east / west)
#      - 到達判定 / 漫遊半徑 (radius: 0 ~ 15 格)
#      - 設施自訂名稱
#   3. 自動檢驗 A* 網格阻擋，一鍵讀取/寫入 res://data/poi_locations.json
#   4. 獨立無耦合架構，設定完成後可隨時將整個 tools/poi_editor 資料夾刪除
# ==============================================================================
extends Node2D

const POI_PATH: String = "res://data/poi_locations.json"
const TEMPLATES_PATH: String = "res://data/npc_templates.json"
const MAP_SCENE_PATH: String = "res://scene/map.tscn"
const NAV_MANAGER_SCRIPT = preload("res://scripts/core/navigation_manager.gd")

# ------------------------------------------------------------------------------
# 1. 內部資料狀態與模式
# ------------------------------------------------------------------------------

enum EditMode {
	SINGLE_POINT, ## 📍 單點門口 (1格)
	MULTI_DOOR,   ## 🚪 雙格/多門口 (2格寬大門，如商店)
	POLYGON       ## 🔷 多邊形範圍 (如社交廣場同心圓環)
}

var poi_list: Array = []
var selected_poi_index: int = 1
var current_mode: EditMode = EditMode.SINGLE_POINT
var resident_map: Dictionary = {}
var worker_map: Dictionary = {}

var active_polygon_points: Array[Vector2i] = []

var _nav_manager: NavigationManager = null
var _camera: Camera2D = null
var _is_dragging: bool = false
var _hover_cell: Vector2i = Vector2i(-999, -999)
var _is_hover_walkable: bool = false

# UI 節點引用
var _ui_layer: CanvasLayer = null
var _sidebar_panel: PanelContainer = null
var _poi_item_buttons: Array[Button] = []
var _hover_hud_label: Label = null
var _status_label: Label = null

# 屬性編輯器控制元件
var _poi_name_edit: LineEdit = null
var _mode_single_btn: Button = null
var _mode_multidoor_btn: Button = null
var _mode_poly_btn: Button = null
var _extra_actions_box: HBoxContainer = null
var _concealed_check: CheckBox = null
var _entrance_dir_opt: OptionButton = null
var _radius_spin: SpinBox = null

# ------------------------------------------------------------------------------
# 2. 生命週期
# ------------------------------------------------------------------------------

func _ready() -> void:
	# 1. 載入並實例化地圖 (若子節點尚未存在)
	var map_node = get_node_or_null("Map")
	if map_node == null and ResourceLoader.exists(MAP_SCENE_PATH):
		var map_packed: PackedScene = load(MAP_SCENE_PATH) as PackedScene
		if map_packed:
			map_node = map_packed.instantiate()
			map_node.name = "Map"
			add_child(map_node)

	# 2. 建立並掛載 NavigationManager
	_nav_manager = get_node_or_null("NavigationManager") as NavigationManager
	if _nav_manager == null:
		_nav_manager = NAV_MANAGER_SCRIPT.new()
		_nav_manager.name = "NavigationManager"
		add_child(_nav_manager)

	# 3. 建立自帶拖曳縮放之攝影機
	_camera = get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "Camera2D"
		add_child(_camera)
		_camera.position = Vector2(40 * 16, 30 * 16)
		_camera.zoom = Vector2(1.5, 1.5)

	# 4. 讀取模板與 POI 資料
	_load_npc_templates_annotations()
	load_pois_from_disk()

	# 5. 動態構建 UI 介面
	_build_ui()

	# 6. 延遲一幀以確保 NavigationManager 網格掃描完畢
	call_deferred("_post_init")

func _post_init() -> void:
	if _nav_manager and _nav_manager.astar == null:
		_nav_manager.initialize_grid()
	_update_ui_list()
	_sync_editor_from_selected()
	queue_redraw()

# ------------------------------------------------------------------------------
# 3. 資料讀取與解析
# ------------------------------------------------------------------------------

func _load_npc_templates_annotations() -> void:
	resident_map.clear()
	worker_map.clear()
	if not FileAccess.file_exists(TEMPLATES_PATH):
		return
	var f: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		for npc in parsed:
			var n_name: String = str(npc.get("name", ""))
			var h_id: int = int(npc.get("home_poi_id", -1))
			var w_id: int = int(npc.get("work_poi_id", -1))
			var j_name: String = str(npc.get("job_name", ""))
			
			if h_id > 0:
				if not resident_map.has(h_id):
					resident_map[h_id] = []
				resident_map[h_id].append(n_name)

			if w_id > 0 and w_id != h_id:
				if not worker_map.has(w_id):
					worker_map[w_id] = []
				worker_map[w_id].append("%s(%s)" % [n_name, j_name])

func load_pois_from_disk() -> void:
	if not FileAccess.file_exists(POI_PATH):
		push_warning("[POIEditor] 找不到 %s" % POI_PATH)
		return
	var f: FileAccess = FileAccess.open(POI_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary and data.has("pois"):
		poi_list = data["pois"]
		# 初始化預設擴充屬性 (防呆)
		for p in poi_list:
			var pid: int = int(p.get("id", -1))
			if not p.has("concealed"):
				# 預設：除原地(0)、農田(16)、釣魚場(17)、廣場(20)、布告欄(22)外，其餘預設為進入隱藏型
				p["concealed"] = not (pid in [0, 16, 17, 20, 22])
			if not p.has("entrance_dir"):
				p["entrance_dir"] = "south"
			if not p.has("radius"):
				p["radius"] = 4 if pid == 20 else (2 if pid == 16 else 0)
	else:
		push_error("[POIEditor] JSON 格式錯誤")
	_show_status("已載入 %d 個 POI 資料！" % poi_list.size(), Color.CHARTREUSE)

func save_pois_to_disk() -> void:
	var f: FileAccess = FileAccess.open(POI_PATH, FileAccess.WRITE)
	if not f:
		_show_status("儲存失敗: 無法寫入檔案！", Color.SALMON)
		return
	var out_dict: Dictionary = {
		"pois": poi_list
	}
	var json_str: String = JSON.stringify(out_dict, "  ")
	f.store_string(json_str)
	f.close()
	_show_status("✅ 成功儲存所有屬性至 %s！" % POI_PATH, Color.GREEN)

# ------------------------------------------------------------------------------
# 4. 輸入監聽與操作 (Input Handling)
# ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# 1. 滾輪縮放
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camera.zoom = (_camera.zoom * 1.15).clamp(Vector2(0.4, 0.4), Vector2(4.0, 4.0))
			queue_redraw()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.zoom = (_camera.zoom / 1.15).clamp(Vector2(0.4, 0.4), Vector2(4.0, 4.0))
			queue_redraw()
			return

		# 2. 中鍵拖曳平移 (以及單點模式下的右鍵拖曳)
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (current_mode == EditMode.SINGLE_POINT and mb.button_index == MOUSE_BUTTON_RIGHT):
			_is_dragging = mb.pressed
			return

		# 多邊形模式下的右鍵：撤銷上一個頂點
		if current_mode == EditMode.POLYGON and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if active_polygon_points.size() > 0:
				active_polygon_points.pop_back()
				_show_status("已撤銷上一個多邊形頂點，剩餘 %d 個頂點" % active_polygon_points.size(), Color.ORANGE)
				queue_redraw()
			return

		# 雙格/多門口模式下的右鍵：撤銷最後一個門口
		if current_mode == EditMode.MULTI_DOOR and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_remove_last_door()
			return

		# 3. 左鍵點擊：依當前模式設定座標
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _sidebar_panel and _sidebar_panel.get_global_rect().has_point(mb.position):
				return
			
			match current_mode:
				EditMode.SINGLE_POINT:
					_apply_single_point_cell(_hover_cell)
				EditMode.MULTI_DOOR:
					_add_door_cell(_hover_cell)
				EditMode.POLYGON:
					_add_polygon_vertex(_hover_cell)
			return

	# 4. 滑鼠移動
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_dragging:
			_camera.position -= mm.relative / _camera.zoom
			queue_redraw()

		_update_hover_cell(mm.position)

func _process(delta: float) -> void:
	# 鍵盤 WASD / 方向鍵平移鏡頭 (輸入框聚焦時不觸發)
	if _poi_name_edit and _poi_name_edit.has_focus():
		return

	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		_camera.position += dir.normalized() * (600.0 / _camera.zoom.x) * delta
		queue_redraw()

func _update_hover_cell(_screen_pos: Vector2) -> void:
	var world_pos: Vector2 = get_global_mouse_position()
	var cell_x: int = int(floor(world_pos.x / 16.0))
	var cell_y: int = int(floor(world_pos.y / 16.0))
	var new_cell: Vector2i = Vector2i(cell_x, cell_y)

	if new_cell != _hover_cell:
		_hover_cell = new_cell
		if _nav_manager and _nav_manager.has_method("is_cell_walkable"):
			_is_hover_walkable = _nav_manager.is_cell_walkable(_hover_cell)
		else:
			_is_hover_walkable = true
		_update_hover_hud()
		queue_redraw()

# ------------------------------------------------------------------------------
# 5. 座標設定實作 (Single Point, Multi-Door, Polygon)
# ------------------------------------------------------------------------------

func _apply_single_point_cell(cell: Vector2i) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	if not _is_hover_walkable:
		_show_status("⚠️ 設定失敗！網格 (%d, %d) 為障礙物或邊界外！" % [cell.x, cell.y], Color.SALMON)
		return

	var current_poi: Dictionary = poi_list[selected_poi_index]
	var p_id: int = int(current_poi.get("id", -1))
	var p_name: String = str(current_poi.get("name", "未命名"))

	current_poi["cell"] = [cell.x, cell.y]
	current_poi.erase("doors")
	current_poi.erase("polygon")
	current_poi.erase("walkable_cells")

	_show_status("已將 [POI %d %s] 設定為單點門口: (%d, %d)" % [p_id, p_name, cell.x, cell.y], Color.AQUAMARINE)
	_update_ui_list()
	queue_redraw()

func _add_door_cell(cell: Vector2i) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	if not _is_hover_walkable:
		_show_status("⚠️ 門口格 (%d, %d) 不可通行，無法加入！" % [cell.x, cell.y], Color.SALMON)
		return

	var current_poi: Dictionary = poi_list[selected_poi_index]
	var p_name: String = str(current_poi.get("name", "未命名"))
	
	if not current_poi.has("doors"):
		current_poi["doors"] = []
	
	var doors: Array = current_poi["doors"]
	var cell_arr: Array = [cell.x, cell.y]
	if doors.has(cell_arr):
		_show_status("該門口網格已在清單中！", Color.ORANGE)
		return

	doors.append(cell_arr)
	current_poi["cell"] = doors[0]
	current_poi.erase("polygon")
	current_poi.erase("walkable_cells")

	_show_status("已為 [%s] 新增第 %d 個門口: (%d, %d)" % [p_name, doors.size(), cell.x, cell.y], Color.AQUAMARINE)
	_update_ui_list()
	queue_redraw()

func _remove_last_door() -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	var current_poi: Dictionary = poi_list[selected_poi_index]
	if current_poi.has("doors") and current_poi["doors"].size() > 0:
		var doors: Array = current_poi["doors"]
		doors.pop_back()
		if doors.size() > 0:
			current_poi["cell"] = doors[0]
		_show_status("已移除上一個門口網格，現有 %d 個門口" % doors.size(), Color.ORANGE)
		_update_ui_list()
		queue_redraw()

func clear_doors() -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	var current_poi: Dictionary = poi_list[selected_poi_index]
	current_poi.erase("doors")
	_show_status("已清空多門口設定，回退為單點門口", Color.ORANGE)
	_update_ui_list()
	queue_redraw()

func _add_polygon_vertex(cell: Vector2i) -> void:
	if active_polygon_points.size() > 0 and active_polygon_points[-1] == cell:
		return
	active_polygon_points.append(cell)
	_show_status("多邊形新增頂點 (%d, %d)，目前共 %d 個點" % [cell.x, cell.y, active_polygon_points.size()], Color.YELLOW)
	queue_redraw()

func finish_polygon() -> void:
	if active_polygon_points.size() < 3:
		_show_status("⚠️ 多邊形至少需要 3 個頂點才能閉合！", Color.SALMON)
		return

	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return

	var current_poi: Dictionary = poi_list[selected_poi_index]
	var poly_2d: PackedVector2Array = PackedVector2Array()
	var min_x: int = 99999
	var max_x: int = -99999
	var min_y: int = 99999
	var max_y: int = -99999

	var poly_data: Array = []
	for p in active_polygon_points:
		poly_2d.append(Vector2(p.x + 0.5, p.y + 0.5))
		poly_data.append([p.x, p.y])
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)

	var inside_walkable_cells: Array = []
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var test_pos: Vector2 = Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(test_pos, poly_2d):
				if _nav_manager and _nav_manager.is_cell_walkable(Vector2i(x, y)):
					inside_walkable_cells.append([x, y])

	if inside_walkable_cells.is_empty():
		_show_status("⚠️ 此多邊形範圍內沒有任何可通行的路面！", Color.SALMON)
		return

	current_poi["polygon"] = poly_data
	current_poi["walkable_cells"] = inside_walkable_cells
	current_poi.erase("doors")
	current_poi["cell"] = inside_walkable_cells[inside_walkable_cells.size() / 2]

	_show_status("✅ 多邊形完成！共收錄 %d 個可走網格（中間障礙噴水池已自動排除）！" % inside_walkable_cells.size(), Color.GREEN)
	active_polygon_points.clear()
	_update_ui_list()
	queue_redraw()

func clear_polygon() -> void:
	active_polygon_points.clear()
	if selected_poi_index >= 0 and selected_poi_index < poi_list.size():
		var current_poi: Dictionary = poi_list[selected_poi_index]
		current_poi.erase("polygon")
		current_poi.erase("walkable_cells")
	_show_status("已清除該 POI 的多邊形自訂範圍！", Color.ORANGE)
	_update_ui_list()
	queue_redraw()

# ------------------------------------------------------------------------------
# 6. 畫面繪製標記與懸浮框 (_draw)
# ------------------------------------------------------------------------------

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	for i in range(poi_list.size()):
		var poi: Dictionary = poi_list[i]
		var is_selected: bool = (i == selected_poi_index)
		var p_id: int = int(poi.get("id", 0))
		var p_name: String = str(poi.get("name", ""))
		var is_conc: bool = bool(poi.get("concealed", true))
		var rad: int = int(poi.get("radius", 0))

		# A. 多邊形範圍 POI
		if poi.has("polygon") and poi.has("walkable_cells"):
			var w_cells: Array = poi["walkable_cells"]
			for c_arr in w_cells:
				var c_pos: Vector2 = Vector2(c_arr[0] * 16, c_arr[1] * 16)
				draw_rect(Rect2(c_pos, Vector2(16, 16)), Color(0.2, 0.8, 0.4, 0.25 if not is_selected else 0.45), true)
				draw_rect(Rect2(c_pos, Vector2(16, 16)), Color(0.3, 0.9, 0.5, 0.4), false, 1.0)

			var poly: Array = poi["polygon"]
			if poly.size() >= 3:
				var border_col: Color = Color.YELLOW if is_selected else Color(0.1, 0.9, 0.4, 0.9)
				for p_idx in range(poly.size()):
					var p1: Vector2 = Vector2(poly[p_idx][0] * 16 + 8, poly[p_idx][1] * 16 + 8)
					var p2: Vector2 = Vector2(poly[(p_idx + 1) % poly.size()][0] * 16 + 8, poly[(p_idx + 1) % poly.size()][1] * 16 + 8)
					draw_line(p1, p2, border_col, 2.5 if is_selected else 1.5)

			var cell_arr: Array = poi.get("cell", [-1, -1])
			if cell_arr.size() >= 2 and cell_arr[0] >= 0:
				var rect_pos: Vector2 = Vector2(cell_arr[0] * 16, cell_arr[1] * 16)
				var tag: String = "🏠隱藏" if is_conc else "🌳露天"
				var label_text: String = "🔷 [%d] %s (%s, %d格)" % [p_id, p_name, tag, w_cells.size()]
				draw_string(font, rect_pos + Vector2(1, -3), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
				draw_string(font, rect_pos + Vector2(0, -4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW if is_selected else Color.WHITE)

		# B. 雙格/多門口 POI
		elif poi.has("doors") and poi["doors"].size() > 0:
			var doors: Array = poi["doors"]
			for d_idx in range(doors.size()):
				var d_pos: Vector2 = Vector2(doors[d_idx][0] * 16, doors[d_idx][1] * 16)
				draw_rect(Rect2(d_pos, Vector2(16, 16)), Color(1.0, 0.4, 0.2, 0.4 if not is_selected else 0.6), true)
				draw_rect(Rect2(d_pos, Vector2(16, 16)), Color.ORANGE if not is_selected else Color.YELLOW, false, 2.0)
				
				var tag: String = "🏠" if is_conc else "🌳"
				var d_label: String = "🚪[%d] %s %s#%d" % [p_id, p_name, tag, d_idx + 1]
				draw_string(font, d_pos + Vector2(1, -3), d_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.BLACK)
				draw_string(font, d_pos + Vector2(0, -4), d_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.YELLOW if is_selected else Color.WHITE)

		# C. 一般單點 POI
		else:
			var cell_arr: Array = poi.get("cell", [-1, -1])
			if cell_arr.size() < 2 or cell_arr[0] < 0 or cell_arr[1] < 0:
				continue

			var cx: int = int(cell_arr[0])
			var cy: int = int(cell_arr[1])
			var rect_pos: Vector2 = Vector2(cx * 16, cy * 16)
			
			var color_fill: Color
			var color_border: Color
			if p_id >= 1 and p_id <= 11:
				color_fill = Color(0.2, 0.6, 1.0, 0.45)
				color_border = Color(0.3, 0.8, 1.0, 0.9)
			elif p_id >= 12 and p_id <= 19:
				color_fill = Color(1.0, 0.6, 0.1, 0.45)
				color_border = Color(1.0, 0.8, 0.2, 0.9)
			elif p_id == 22:
				color_fill = Color(0.9, 0.68, 0.2, 0.55)
				color_border = Color(1.0, 0.88, 0.35, 0.95)
			else:
				color_fill = Color(0.7, 0.7, 0.7, 0.3)
				color_border = Color(0.9, 0.9, 0.9, 0.8)

			if is_selected:
				color_border = Color.YELLOW
				draw_rect(Rect2(rect_pos - Vector2(2, 2), Vector2(20, 20)), Color.YELLOW, false, 2.0)

			draw_rect(Rect2(rect_pos, Vector2(16, 16)), color_fill, true)
			draw_rect(Rect2(rect_pos, Vector2(16, 16)), color_border, false, 1.5)

			# 繪製自訂半徑範圍圈 (若 radius > 0)
			if rad > 0:
				var center_px: Vector2 = rect_pos + Vector2(8, 8)
				draw_circle(center_px, rad * 16.0, Color(1, 0.8, 0.2, 0.08))
				draw_arc(center_px, rad * 16.0, 0, TAU, 32, Color(1, 0.8, 0.2, 0.5 if not is_selected else 0.9), 1.5)

			var tag: String = "📋" if p_id == 22 else ("🏠" if is_conc else "🌳")
			var label_text: String = "[%d] %s %s" % [p_id, p_name, tag]
			var text_pos: Vector2 = rect_pos + Vector2(2, -4)
			draw_string(font, text_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE if not is_selected else Color.YELLOW)

	# 2. 繪製構建中的多邊形
	if current_mode == EditMode.POLYGON and active_polygon_points.size() > 0:
		for idx in range(active_polygon_points.size()):
			var pt: Vector2i = active_polygon_points[idx]
			var pt_world: Vector2 = Vector2(pt.x * 16 + 8, pt.y * 16 + 8)
			draw_circle(pt_world, 3.5, Color.YELLOW)
			if idx > 0:
				var prev_world: Vector2 = Vector2(active_polygon_points[idx - 1].x * 16 + 8, active_polygon_points[idx - 1].y * 16 + 8)
				draw_line(prev_world, pt_world, Color.YELLOW, 2.0)
		
		if _hover_cell != Vector2i(-999, -999):
			var last_pt: Vector2 = Vector2(active_polygon_points[-1].x * 16 + 8, active_polygon_points[-1].y * 16 + 8)
			var hover_pt: Vector2 = Vector2(_hover_cell.x * 16 + 8, _hover_cell.y * 16 + 8)
			draw_line(last_pt, hover_pt, Color(1, 1, 0, 0.6), 1.5)

	# 3. 繪製滑鼠懸浮框
	if _hover_cell != Vector2i(-999, -999):
		var h_pos: Vector2 = Vector2(_hover_cell.x * 16, _hover_cell.y * 16)
		var h_fill: Color = Color(0.1, 0.9, 0.2, 0.35) if _is_hover_walkable else Color(0.9, 0.1, 0.1, 0.45)
		var h_border: Color = Color(0.2, 1.0, 0.3, 0.9) if _is_hover_walkable else Color(1.0, 0.2, 0.2, 0.9)
		draw_rect(Rect2(h_pos, Vector2(16, 16)), h_fill, true)
		draw_rect(Rect2(h_pos, Vector2(16, 16)), h_border, false, 2.0)

# ------------------------------------------------------------------------------
# 7. 動態 UI 建構 (UI Construction)
# ------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100
	add_child(_ui_layer)

	# 頂部資訊條
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(600, 36)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 360
	top_bar.offset_right = -20
	top_bar.offset_top = 10
	top_bar.offset_bottom = 48
	_ui_layer.add_child(top_bar)

	_hover_hud_label = Label.new()
	_hover_hud_label.text = "滑鼠網格: (--) | 狀態: --"
	_hover_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(_hover_hud_label)

	# 側邊導航與設定面板
	_sidebar_panel = PanelContainer.new()
	_sidebar_panel.custom_minimum_size = Vector2(340, 0)
	_sidebar_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_sidebar_panel.offset_left = 10
	_sidebar_panel.offset_top = 10
	_sidebar_panel.offset_bottom = -10
	_sidebar_panel.offset_right = 350
	_ui_layer.add_child(_sidebar_panel)

	var side_vbox: VBoxContainer = VBoxContainer.new()
	side_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_vbox.add_theme_constant_override("separation", 6)
	_sidebar_panel.add_child(side_vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📍 26號宇宙 - POI 全屬性設定器"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_vbox.add_child(title_lbl)

	# --- POI 詳情與屬性設定區塊 ---
	var prop_box: VBoxContainer = VBoxContainer.new()
	prop_box.add_theme_constant_override("separation", 4)
	side_vbox.add_child(prop_box)

	# 名稱編輯
	var name_hbox: HBoxContainer = HBoxContainer.new()
	var name_lbl: Label = Label.new()
	name_lbl.text = "名稱:"
	name_hbox.add_child(name_lbl)
	_poi_name_edit = LineEdit.new()
	_poi_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poi_name_edit.text_changed.connect(_on_poi_name_changed)
	name_hbox.add_child(_poi_name_edit)
	prop_box.add_child(name_hbox)

	# 模式切換 (單門 / 多門 / 範圍)
	var mode_grid: GridContainer = GridContainer.new()
	mode_grid.columns = 3
	mode_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_mode_single_btn = Button.new()
	_mode_single_btn.text = "📍 單門"
	_mode_single_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_single_btn.pressed.connect(func(): _set_mode(EditMode.SINGLE_POINT))
	mode_grid.add_child(_mode_single_btn)

	_mode_multidoor_btn = Button.new()
	_mode_multidoor_btn.text = "🚪 雙格/多門"
	_mode_multidoor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_multidoor_btn.pressed.connect(func(): _set_mode(EditMode.MULTI_DOOR))
	mode_grid.add_child(_mode_multidoor_btn)

	_mode_poly_btn = Button.new()
	_mode_poly_btn.text = "🔷 範圍"
	_mode_poly_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_poly_btn.pressed.connect(func(): _set_mode(EditMode.POLYGON))
	mode_grid.add_child(_mode_poly_btn)
	prop_box.add_child(mode_grid)

	# 延伸操作區 (撤銷/閉合多邊形)
	_extra_actions_box = HBoxContainer.new()
	prop_box.add_child(_extra_actions_box)
	_extra_actions_box.visible = false

	# 核心屬性 1：進屋隱藏開關
	_concealed_check = CheckBox.new()
	_concealed_check.text = "🏠 抵達後進屋/進森林隱藏 (Concealed)"
	_concealed_check.toggled.connect(_on_concealed_toggled)
	prop_box.add_child(_concealed_check)

	# 核心屬性 2：進出門朝向
	var dir_hbox: HBoxContainer = HBoxContainer.new()
	var dir_lbl: Label = Label.new()
	dir_lbl.text = "門口朝向:"
	dir_hbox.add_child(dir_lbl)

	_entrance_dir_opt = OptionButton.new()
	_entrance_dir_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entrance_dir_opt.add_item("南門 (朝上走入)", 0)
	_entrance_dir_opt.add_item("北門 (朝下走入)", 1)
	_entrance_dir_opt.add_item("東門 (朝左走入)", 2)
	_entrance_dir_opt.add_item("西門 (朝右走入)", 3)
	_entrance_dir_opt.item_selected.connect(_on_entrance_dir_selected)
	dir_hbox.add_child(_entrance_dir_opt)
	prop_box.add_child(dir_hbox)

	# 核心屬性 3：到達判定 / 漫遊半徑
	var rad_hbox: HBoxContainer = HBoxContainer.new()
	var rad_lbl: Label = Label.new()
	rad_lbl.text = "抵達/活動半徑:"
	rad_hbox.add_child(rad_lbl)

	_radius_spin = SpinBox.new()
	_radius_spin.min_value = 0
	_radius_spin.max_value = 15
	_radius_spin.step = 1
	_radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radius_spin.value_changed.connect(_on_radius_changed)
	rad_hbox.add_child(_radius_spin)
	prop_box.add_child(rad_hbox)

	# 快捷操作按鈕列 (存檔 / 重載 / 置中)
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	var btn_save: Button = Button.new()
	btn_save.text = "💾 儲存配置 (Save)"
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.pressed.connect(save_pois_to_disk)
	btn_hbox.add_child(btn_save)

	var btn_reload: Button = Button.new()
	btn_reload.text = "🔄 重載"
	btn_reload.pressed.connect(load_pois_from_disk)
	btn_hbox.add_child(btn_reload)

	var btn_center: Button = Button.new()
	btn_center.text = "🎯 置中"
	btn_center.pressed.connect(func(): _focus_camera_on_selected())
	btn_hbox.add_child(btn_center)
	side_vbox.add_child(btn_hbox)

	_status_label = Label.new()
	_status_label.text = "準備就緒"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	side_vbox.add_child(_status_label)

	var sep: HSeparator = HSeparator.new()
	side_vbox.add_child(sep)

	# 滾動清單
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(scroll)

	var list_vbox: VBoxContainer = VBoxContainer.new()
	list_vbox.name = "ListVBox"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(list_vbox)

	_update_mode_ui()

# ------------------------------------------------------------------------------
# 8. 屬性變更回呼 (Property Change Callbacks)
# ------------------------------------------------------------------------------

func _on_poi_name_changed(new_name: String) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	poi_list[selected_poi_index]["name"] = new_name
	_update_ui_list_labels_only()
	queue_redraw()

func _on_concealed_toggled(toggled: bool) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	poi_list[selected_poi_index]["concealed"] = toggled
	var tag: String = "【進屋/進森林隱藏】" if toggled else "【露天可見活動】"
	_show_status("已將此設施設定為: %s" % tag, Color.AQUAMARINE)
	_update_ui_list_labels_only()
	queue_redraw()

func _on_entrance_dir_selected(index: int) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	var dir_strs: Array[String] = ["south", "north", "east", "west"]
	poi_list[selected_poi_index]["entrance_dir"] = dir_strs[index]
	_show_status("門口進出朝向已更新為: %s" % dir_strs[index], Color.AQUAMARINE)

func _on_radius_changed(value: float) -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	poi_list[selected_poi_index]["radius"] = int(value)
	_show_status("抵達/活動半徑已設為: %d 格" % int(value), Color.AQUAMARINE)
	queue_redraw()

## 選取 POI 時將資料同步至屬性編輯器
func _sync_editor_from_selected() -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	var poi: Dictionary = poi_list[selected_poi_index]
	
	if _poi_name_edit:
		_poi_name_edit.text = str(poi.get("name", ""))

	if _concealed_check:
		_concealed_check.set_pressed_no_signal(bool(poi.get("concealed", true)))

	if _entrance_dir_opt:
		var dir: String = str(poi.get("entrance_dir", "south"))
		match dir:
			"south": _entrance_dir_opt.select(0)
			"north": _entrance_dir_opt.select(1)
			"east": _entrance_dir_opt.select(2)
			"west": _entrance_dir_opt.select(3)
			_: _entrance_dir_opt.select(0)

	if _radius_spin:
		_radius_spin.set_value_no_signal(float(poi.get("radius", 0)))

	# 同步模式
	if poi.has("polygon"):
		_set_mode(EditMode.POLYGON)
	elif poi.has("doors") and poi["doors"].size() > 1:
		_set_mode(EditMode.MULTI_DOOR)
	else:
		_set_mode(EditMode.SINGLE_POINT)

func _set_mode(mode: EditMode) -> void:
	current_mode = mode
	active_polygon_points.clear()
	_update_mode_ui()
	match current_mode:
		EditMode.SINGLE_POINT:
			_show_status("📍【單門模式】點擊地圖直接設定單一門口格", Color.AQUAMARINE)
		EditMode.MULTI_DOOR:
			_show_status("🚪【雙格/多門口模式】左鍵依序點擊門口格子，右鍵可撤銷", Color.CORAL)
		EditMode.POLYGON:
			_show_status("🔷【多邊形模式】左鍵點擊頂點繪製外框，右鍵撤銷，完成點【閉合】", Color.YELLOW)
	queue_redraw()

func _update_mode_ui() -> void:
	if _mode_single_btn == null:
		return
	_mode_single_btn.modulate = Color(0.6, 1.0, 0.6) if current_mode == EditMode.SINGLE_POINT else Color.WHITE
	_mode_multidoor_btn.modulate = Color(1.0, 0.7, 0.3) if current_mode == EditMode.MULTI_DOOR else Color.WHITE
	_mode_poly_btn.modulate = Color(1.0, 1.0, 0.4) if current_mode == EditMode.POLYGON else Color.WHITE

	for c in _extra_actions_box.get_children():
		c.queue_free()

	if current_mode == EditMode.MULTI_DOOR:
		_extra_actions_box.visible = true
		var btn_rm_door: Button = Button.new()
		btn_rm_door.text = "↩️ 撤銷門"
		btn_rm_door.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_rm_door.pressed.connect(_remove_last_door)
		_extra_actions_box.add_child(btn_rm_door)

		var btn_clr_doors: Button = Button.new()
		btn_clr_doors.text = "🗑️ 清空多門"
		btn_clr_doors.pressed.connect(clear_doors)
		_extra_actions_box.add_child(btn_clr_doors)

	elif current_mode == EditMode.POLYGON:
		_extra_actions_box.visible = true
		var btn_fin: Button = Button.new()
		btn_fin.text = "✅ 閉合多邊形"
		btn_fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_fin.pressed.connect(finish_polygon)
		_extra_actions_box.add_child(btn_fin)

		var btn_clr: Button = Button.new()
		btn_clr.text = "🗑️ 清除"
		btn_clr.pressed.connect(clear_polygon)
		_extra_actions_box.add_child(btn_clr)
	else:
		_extra_actions_box.visible = false

func _update_ui_list() -> void:
	if _sidebar_panel == null:
		return
	var list_vbox: VBoxContainer = _sidebar_panel.find_child("ListVBox", true, false) as VBoxContainer
	if list_vbox == null:
		return

	for child in list_vbox.get_children():
		child.queue_free()
	_poi_item_buttons.clear()

	for i in range(poi_list.size()):
		var p: Dictionary = poi_list[i]
		var pid: int = int(p.get("id", -1))
		var pname: String = str(p.get("name", ""))
		var cell: Array = p.get("cell", [-1, -1])
		var is_conc: bool = bool(p.get("concealed", true))

		var extra_info: String = ""
		if p.has("walkable_cells"):
			extra_info = " [🔷範圍:%d格]" % p["walkable_cells"].size()
		elif p.has("doors") and p["doors"].size() > 1:
			extra_info = " [🚪%d門]" % p["doors"].size()
		elif resident_map.has(pid):
			extra_info = " [住:%s]" % ", ".join(resident_map[pid])
		elif worker_map.has(pid):
			extra_info = " [工:%s]" % ", ".join(worker_map[pid])

		var tag_icon: String = "📋" if pid == 22 else ("🏠" if is_conc else "🌳")
		var btn: Button = Button.new()
		var is_sel: bool = (i == selected_poi_index)
		btn.text = "%s %s[%d] %s: (%d, %d)%s" % [
			"👉" if is_sel else "  ",
			tag_icon, pid, pname, int(cell[0]), int(cell[1]), extra_info
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_poi_button_pressed.bind(i))
		list_vbox.add_child(btn)
		_poi_item_buttons.append(btn)

func _update_ui_list_labels_only() -> void:
	for i in range(mini(_poi_item_buttons.size(), poi_list.size())):
		var p: Dictionary = poi_list[i]
		var pid: int = int(p.get("id", -1))
		var pname: String = str(p.get("name", ""))
		var cell: Array = p.get("cell", [-1, -1])
		var is_conc: bool = bool(p.get("concealed", true))

		var extra_info: String = ""
		if p.has("walkable_cells"):
			extra_info = " [🔷範圍:%d格]" % p["walkable_cells"].size()
		elif p.has("doors") and p["doors"].size() > 1:
			extra_info = " [🚪%d門]" % p["doors"].size()
		elif resident_map.has(pid):
			extra_info = " [住:%s]" % ", ".join(resident_map[pid])
		elif worker_map.has(pid):
			extra_info = " [工:%s]" % ", ".join(worker_map[pid])

		var tag_icon: String = "📋" if pid == 22 else ("🏠" if is_conc else "🌳")
		var is_sel: bool = (i == selected_poi_index)
		_poi_item_buttons[i].text = "%s %s[%d] %s: (%d, %d)%s" % [
			"👉" if is_sel else "  ",
			tag_icon, pid, pname, int(cell[0]), int(cell[1]), extra_info
		]

func _on_poi_button_pressed(idx: int) -> void:
	selected_poi_index = idx
	active_polygon_points.clear()
	_sync_editor_from_selected()
	_update_ui_list_labels_only()
	_focus_camera_on_selected()
	queue_redraw()

func _focus_camera_on_selected() -> void:
	if selected_poi_index < 0 or selected_poi_index >= poi_list.size():
		return
	var poi: Dictionary = poi_list[selected_poi_index]
	var cell: Array = poi.get("cell", [-1, -1])
	if cell.size() >= 2 and cell[0] >= 0 and cell[1] >= 0:
		var target_pos: Vector2 = Vector2(cell[0] * 16 + 8, cell[1] * 16 + 8)
		var tween: Tween = create_tween()
		tween.tween_property(_camera, "position", target_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_hover_hud() -> void:
	if _hover_hud_label == null:
		return
	var status_text: String = "✅ 可通行" if _is_hover_walkable else "❌ 障礙物/無效"
	var mode_name: String = ""
	match current_mode:
		EditMode.SINGLE_POINT: mode_name = "【單門模式: 左鍵點擊設定】"
		EditMode.MULTI_DOOR: mode_name = "【雙格/多門模式: 左鍵加門，右鍵撤銷】"
		EditMode.POLYGON: mode_name = "【多邊形模式: 左鍵加頂點，右鍵撤銷】"

	_hover_hud_label.text = "%s 滑鼠網格: (%d, %d) | 狀態: %s" % [
		mode_name, _hover_cell.x, _hover_cell.y, status_text
	]

func _show_status(msg: String, color: Color) -> void:
	if _status_label:
		_status_label.text = msg
		_status_label.modulate = color
