# ==============================================================================
# 26號宇宙 (Universe 26) - 小鎮布告欄站位物件 (Town Bulletin Board Object)
# 檔案路徑: res://scripts/objects/bulletin_board.gd
# 職責描述:
#   1. 作為 POI 22 (小鎮布告欄) 在地圖上的具體站位與可視化互動實體
#   2. 以純程式繪製 (Procedural Draw) 呈現精美復古木質布告欄與紙張貼圖，無外部紋理依賴
#   3. 提供滑鼠懸停高亮、手勢游標與點擊檢測 (Area2D + CollisionShape2D)
#   4. 點擊時彈出開合動畫，並直接開啟情報擴散拓撲驗證與發布面板 (RumorPropagationDialog)
#   5. 自動依據 POI 22 網格座標對齊世界位置
# ==============================================================================
class_name BulletinBoard
extends Area2D

signal board_clicked()

## 所屬 POI 編號
@export var poi_id: int = 22

var _col_shape: CollisionShape2D = null
var _title_label: Label = null
var _badge_panel: PanelContainer = null
var _is_hovered: bool = false
var _scale_tween: Tween = null

func _ready() -> void:
	# 啟用滑鼠點擊與懸停檢測
	input_pickable = true
	monitoring = true
	monitorable = true
	z_index = 5 # 確保位於地塊之上、與建築/樹木同一層級排序

	_setup_collision()
	_setup_floating_label()
	_align_to_poi_cell()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _setup_collision() -> void:
	if _col_shape == null:
		_col_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 32)
		_col_shape.shape = rect
		_col_shape.position = Vector2(0, -2)
		add_child(_col_shape)

func _setup_floating_label() -> void:
	_badge_panel = PanelContainer.new()
	_badge_panel.position = Vector2(-36, -34)
	_badge_panel.custom_minimum_size = Vector2(72, 18)

	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	p_style.border_color = Color(0.85, 0.65, 0.25, 0.9)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(4)
	p_style.set_content_margin_all(2)
	_badge_panel.add_theme_stylebox_override("panel", p_style)
	add_child(_badge_panel)

	_title_label = Label.new()
	_title_label.text = "📋 小鎮布告欄"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 9)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.95))
	_title_label.add_theme_constant_override("outline_size", 2)
	_badge_panel.add_child(_title_label)

## 依據 POI 22 座標自動定位於網格中心
func _align_to_poi_cell() -> void:
	var g = _get_global()
	var nav = _get_nav_manager()
	var target_cell := Vector2i(35, 25) # 預設座標 (廣場旁)

	if g and g.has_method("get_poi_cell"):
		var c: Vector2i = g.get_poi_cell(poi_id)
		if c != Vector2i(-1, -1):
			target_cell = c

	if nav and nav.has_method("map_to_local"):
		global_position = nav.map_to_local(target_cell)
	else:
		# 若無導航管理器，以標準 16px 瓦片中心計算
		global_position = Vector2(target_cell.x * 16 + 8, target_cell.y * 16 + 8)

# ------------------------------------------------------------------------------
# 2. 繪圖渲染 (Procedural Pixel Art Notice Board)
# ------------------------------------------------------------------------------

func _draw() -> void:
	# 1. 兩側木質支柱 (Support Posts)
	var post_color: Color = Color(0.35, 0.22, 0.12)
	draw_rect(Rect2(-11, -3, 3, 17), post_color)
	draw_rect(Rect2(8, -3, 3, 17), post_color)

	# 2. 布告欄木背板 (Wooden Board)
	var wood_base: Color = Color(0.56, 0.36, 0.20)
	if _is_hovered:
		wood_base = wood_base.lightened(0.15)
	draw_rect(Rect2(-17, -15, 34, 19), wood_base)

	# 3. 外框飾條 (Dark Border)
	var border_color: Color = Color(0.28, 0.16, 0.08)
	draw_rect(Rect2(-17, -15, 34, 19), border_color, false, 1.5)

	# 4. 張貼的情報羊皮紙 (Pinned Notices)
	# 左側告示紙
	draw_rect(Rect2(-14, -12, 12, 13), Color(0.94, 0.92, 0.84))
	draw_rect(Rect2(-14, -12, 12, 13), Color(0.65, 0.60, 0.50), false, 1.0)
	# 右側告示紙
	draw_rect(Rect2(2, -11, 12, 11), Color(0.96, 0.94, 0.86))
	draw_rect(Rect2(2, -11, 12, 11), Color(0.65, 0.60, 0.50), false, 1.0)

	# 5. 紙上微型筆記線條 (Notice Text Lines)
	var ink_color: Color = Color(0.35, 0.35, 0.35, 0.85)
	draw_line(Vector2(-12, -9), Vector2(-4, -9), ink_color, 1.0)
	draw_line(Vector2(-12, -6), Vector2(-5, -6), ink_color, 1.0)
	draw_line(Vector2(-12, -3), Vector2(-6, -3), ink_color, 1.0)

	draw_line(Vector2(4, -8), Vector2(11, -8), ink_color, 1.0)
	draw_line(Vector2(4, -5), Vector2(10, -5), ink_color, 1.0)

	# 6. 彩色圖釘 (Push Pins)
	draw_circle(Vector2(-8, -12), 1.5, Color(0.95, 0.25, 0.25)) # 紅圖釘
	draw_circle(Vector2(8, -11), 1.5, Color(0.95, 0.85, 0.20))  # 黃圖釘

	# 7. 頂部遮雨小木棚 (Slanted Roof)
	var roof_pts: PackedVector2Array = [
		Vector2(-19, -15),
		Vector2(0, -22),
		Vector2(19, -15)
	]
	var roof_color: Color = Color(0.42, 0.24, 0.12)
	draw_colored_polygon(roof_pts, roof_color)
	draw_polyline(roof_pts, Color(0.24, 0.12, 0.06), 1.5)

# ------------------------------------------------------------------------------
# 3. 互動與點擊事件 (Hover & Click Interaction)
# ------------------------------------------------------------------------------

func _on_mouse_entered() -> void:
	_is_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	queue_redraw()

	if _title_label:
		_title_label.text = "🔍 點擊查看情報"
		_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))

	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_is_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()

	if _title_label:
		_title_label.text = "📋 小鎮布告欄"
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))

	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_board_clicked()
		get_viewport().set_input_as_handled()

func _on_board_clicked() -> void:
	# 點擊回彈彈跳動畫 (Juice Animation)
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.06)
	_scale_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

	board_clicked.emit()
	print("[BulletinBoard] 📋 玩家點擊了小鎮布告欄，正在開啟情報中心視窗...")

	# 尋找並開啟 RumorPropagationDialog
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st and st.root:
		var dialog = st.root.find_child("RumorPropagationDialog", true, false)
		if dialog and dialog.has_method("open"):
			dialog.open()
			return

	# 若未找到，嘗試透過 TimeHUD 開啟
	var time_hud = st.root.find_child("TimeHUD", true, false)
	if time_hud and "_rumor_dialog" in time_hud and time_hud._rumor_dialog:
		time_hud._rumor_dialog.open()

# ------------------------------------------------------------------------------
# 4. 輔助函數 (Helpers)
# ------------------------------------------------------------------------------

func _get_global() -> Node:
	if Engine.has_singleton("Global"):
		return Engine.get_singleton("Global")
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st and st.root and st.root.has_node("Global"):
		return st.root.get_node("Global")
	return null

func _get_nav_manager():
	var g: Node = _get_global()
	if g and g.has_method("get_navigation_manager"):
		return g.get_navigation_manager()
	return null

