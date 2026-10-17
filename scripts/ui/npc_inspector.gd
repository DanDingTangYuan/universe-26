# ==============================================================================
# 26號宇宙 (Universe 26) - NPC 即時狀態與大腦觀測器 (NPC Inspector GUI)
# 檔案路徑: res://scripts/ui/npc_inspector.gd
# 職責描述: 
#   1. 繼承 CanvasLayer，以橫向雙欄卡片形式浮動於 NPC「左側或右側」
#   2. 角色完全不被遮擋，可同時觀看角色動畫與即時狀態
#   3. 即時顯示 NPC 身份、當前狀態 (FSM)、座標
#   4. 即時顯示 AI 大腦決策：目標行動、目標 POI、推論引擎、排程覆蓋原因、神經輸出評分
#   5. 即時顯示 15 維度生理代謝 (HP, 體力, 飽食度, 心情等) 與經濟庫存
#   6. 提供關閉按鈕與攝影機鏡頭聚焦功能
# ==============================================================================
class_name NPCInspector
extends CanvasLayer

const NPCControllerClass = preload("res://scripts/entities/npc_controller.gd")

# ------------------------------------------------------------------------------
# 1. 內部節點引用 (UI Components)
# ------------------------------------------------------------------------------

var _target_npc: Node2D = null
var _panel: PanelContainer = null

# UI 標籤與控制件
var _name_label: Label = null
var _job_label: Label = null
var _state_badge: Label = null
var _pos_label: Label = null

var _action_label: Label = null
var _target_poi_label: Label = null
var _engine_label: Label = null
var _override_label: Label = null
var _score_box: VBoxContainer = null

var _hp_bar: ProgressBar = null
var _health_bar: ProgressBar = null
var _stamina_bar: ProgressBar = null
var _hunger_bar: ProgressBar = null
var _social_bar: ProgressBar = null
var _mood_bar: ProgressBar = null

var _money_label: Label = null
var _inventory_label: Label = null

# 行為動態權重 (Tab 1)
var _action_weights_label: Label = null

# 社交大腦與靈魂記憶 UI 元件 (Tab 2)
var _social_engine_label: Label = null
var _social_target_label: Label = null
var _social_act_label: Label = null
var _social_feedback_label: Label = null
var _social_time_label: Label = null
var _social_radar_box: VBoxContainer = null
var _ltm_label: Label = null
var _mtm_label: Label = null
var _stm_vbox: VBoxContainer = null

var _focus_btn: Button = null
var _close_btn: Button = null

# 行為中文名稱對照表 (0 ~ 8)
const ACTION_NAMES: Array[String] = [
	"閒逛", "閱讀", "購物", "吃東西", "就醫",
	"回家休息", "社交", "巡田水", "販售物品"
]

# 社交具體行為圖示與名稱 (1 ~ 7)
const SOCIAL_ACTION_ICONS: Dictionary = {
	1: "💬 普通聊天",
	2: "💡 討論主題",
	3: "❓ 詢問問題",
	4: "🤝 共同活動",
	5: "🎭 捉弄他人",
	6: "🤫 欺騙隱瞞",
	7: "📢 訊息傳播"
}

# ------------------------------------------------------------------------------
# 2. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	layer = 12 # 位於遊戲地圖與大部分物件之上，不遮擋頂部核心 TimeHUD (layer 10/HUD)
	_build_ui()
	_connect_global_signals()
	visible = false

func _process(_delta: float) -> void:
	if not visible:
		return

	if _target_npc == null or not is_instance_valid(_target_npc):
		close()
		return

	_update_screen_position()
	_update_npc_data()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()

# ------------------------------------------------------------------------------
# 3. 介面動態構建 (Programmatic UI Construction - 橫向雙欄卡片)
# ------------------------------------------------------------------------------

func _build_ui() -> void:
	# 主面板容器 (橫向精巧尺寸: 460 x 275)
	_panel = PanelContainer.new()
	_panel.name = "InspectorCard"
	_panel.custom_minimum_size = Vector2(460, 275)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.94) # 深邃黑藍半透明
	panel_style.border_color = Color(0.24, 0.65, 0.92, 0.85) # 科技青亮藍邊框
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set("theme_override_constants/separation", 6)
	_panel.add_child(root_vbox)

	# --- 頂部標題列 (Header) ---
	var header_hbox: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	_name_label = Label.new()
	_name_label.text = "NPC 名稱"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	header_hbox.add_child(_name_label)

	_job_label = Label.new()
	_job_label.text = "[農民]"
	_job_label.add_theme_font_size_override("font_size", 12)
	_job_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	header_hbox.add_child(_job_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	_state_badge = Label.new()
	_state_badge.text = "工作中"
	_state_badge.add_theme_font_size_override("font_size", 12)
	_state_badge.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	header_hbox.add_child(_state_badge)

	_close_btn = Button.new()
	_close_btn.text = " ✕ "
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.3))
	_close_btn.pressed.connect(close)
	header_hbox.add_child(_close_btn)

	root_vbox.add_child(HSeparator.new())

	# --- 雙分頁容器 (TabContainer: 生理決策 / 社交記憶) ---
	var tab_container: TabContainer = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", 10)
	root_vbox.add_child(tab_container)

	# ==============================
	# 分頁一：📊 生理與日常決策
	# ==============================
	var page_vitals: HBoxContainer = HBoxContainer.new()
	page_vitals.name = "📊 生理與決策"
	page_vitals.set("theme_override_constants/separation", 10)
	page_vitals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(page_vitals)

	# ===== 左欄：AI 大腦與決策狀況 =====
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.set("theme_override_constants/separation", 3)
	page_vitals.add_child(left_vbox)

	var brain_title: Label = Label.new()
	brain_title.text = "🧠 AI 大腦日常決策"
	brain_title.add_theme_font_size_override("font_size", 11)
	brain_title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	left_vbox.add_child(brain_title)

	_action_label = Label.new()
	_action_label.text = "行動: 執勤工作"
	_action_label.add_theme_font_size_override("font_size", 11)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	left_vbox.add_child(_action_label)

	_target_poi_label = Label.new()
	_target_poi_label.text = "地點: POI 16 (農田)"
	_target_poi_label.add_theme_font_size_override("font_size", 11)
	_target_poi_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	left_vbox.add_child(_target_poi_label)

	_override_label = Label.new()
	_override_label.text = "機制: ⚠️ 工作排程"
	_override_label.add_theme_font_size_override("font_size", 10)
	_override_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_override_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_override_label)

	_engine_label = Label.new()
	_engine_label.text = "引擎: C# ONNX Runtime"
	_engine_label.add_theme_font_size_override("font_size", 10)
	_engine_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	left_vbox.add_child(_engine_label)

	_score_box = VBoxContainer.new()
	_score_box.set("theme_override_constants/separation", 2)
	left_vbox.add_child(_score_box)

	_action_weights_label = Label.new()
	_action_weights_label.text = "🎯 LTM 習慣: 工作 1.0x | 休息 1.0x"
	_action_weights_label.add_theme_font_size_override("font_size", 9)
	_action_weights_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	_action_weights_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_action_weights_label)

	# 垂直分隔線
	page_vitals.add_child(VSeparator.new())

	# ===== 右欄：生理狀態與經濟庫存 =====
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.set("theme_override_constants/separation", 3)
	page_vitals.add_child(right_vbox)

	var vitals_title: Label = Label.new()
	vitals_title.text = "❤️ 生理與經濟"
	vitals_title.add_theme_font_size_override("font_size", 11)
	vitals_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	right_vbox.add_child(vitals_title)

	var vitals_grid: GridContainer = GridContainer.new()
	vitals_grid.columns = 2
	vitals_grid.set("theme_override_constants/h_separation", 6)
	vitals_grid.set("theme_override_constants/v_separation", 2)
	right_vbox.add_child(vitals_grid)

	_hp_bar = _create_stat_row(vitals_grid, "血量", Color(0.9, 0.2, 0.2))
	_stamina_bar = _create_stat_row(vitals_grid, "體力", Color(0.9, 0.6, 0.1))
	_health_bar = _create_stat_row(vitals_grid, "健康", Color(0.2, 0.8, 0.6))
	_hunger_bar = _create_stat_row(vitals_grid, "飽食", Color(0.9, 0.8, 0.2))
	_social_bar = _create_stat_row(vitals_grid, "社交", Color(0.8, 0.4, 0.9))
	_mood_bar = _create_stat_row(vitals_grid, "心情", Color(0.3, 0.7, 1.0))

	_money_label = Label.new()
	_money_label.text = "💰 金錢: $ 100"
	_money_label.add_theme_font_size_override("font_size", 11)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	right_vbox.add_child(_money_label)

	_inventory_label = Label.new()
	_inventory_label.text = "🎒 木:0 | 石:0 | 礦:0 | 作:0"
	_inventory_label.add_theme_font_size_override("font_size", 10)
	_inventory_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_inventory_label)

	# ==============================
	# 分頁二：🧠 社交與靈魂記憶 (模型實證)
	# ==============================
	var page_social: HBoxContainer = HBoxContainer.new()
	page_social.name = "🧠 社交與記憶"
	page_social.set("theme_override_constants/separation", 10)
	page_social.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(page_social)

	# ===== 社交欄 (左) =====
	var soc_left: VBoxContainer = VBoxContainer.new()
	soc_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	soc_left.set("theme_override_constants/separation", 2)
	page_social.add_child(soc_left)

	var soc_title: Label = Label.new()
	soc_title.text = "🤝 社交 ONNX 大腦"
	soc_title.add_theme_font_size_override("font_size", 11)
	soc_title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	soc_left.add_child(soc_title)

	_social_engine_label = Label.new()
	_social_engine_label.text = "引擎: 🚀 C# ONNX (7維推論)"
	_social_engine_label.add_theme_font_size_override("font_size", 9)
	_social_engine_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	soc_left.add_child(_social_engine_label)

	_social_target_label = Label.new()
	_social_target_label.text = "對象: 尚無近期互動"
	_social_target_label.add_theme_font_size_override("font_size", 9)
	_social_target_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	soc_left.add_child(_social_target_label)

	_social_act_label = Label.new()
	_social_act_label.text = "行為: 普通聊天 (加權輪盤)"
	_social_act_label.add_theme_font_size_override("font_size", 9)
	_social_act_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	soc_left.add_child(_social_act_label)

	_social_feedback_label = Label.new()
	_social_feedback_label.text = "反饋: 尚未產生互動記憶"
	_social_feedback_label.add_theme_font_size_override("font_size", 9)
	_social_feedback_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	_social_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soc_left.add_child(_social_feedback_label)

	_social_time_label = Label.new()
	_social_time_label.text = "特徵: 距離/好感/上次天數"
	_social_time_label.add_theme_font_size_override("font_size", 8)
	_social_time_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_social_time_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soc_left.add_child(_social_time_label)

	var radar_sep: HSeparator = HSeparator.new()
	soc_left.add_child(radar_sep)

	var radar_title: Label = Label.new()
	radar_title.text = "📡 周遭 NPC 意向雷達 (32格):"
	radar_title.add_theme_font_size_override("font_size", 9)
	radar_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	soc_left.add_child(radar_title)

	_social_radar_box = VBoxContainer.new()
	_social_radar_box.set("theme_override_constants/separation", 1)
	soc_left.add_child(_social_radar_box)

	page_social.add_child(VSeparator.new())

	# ===== 記憶欄 (右) =====
	var mem_right: VBoxContainer = VBoxContainer.new()
	mem_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mem_right.set("theme_override_constants/separation", 2)
	page_social.add_child(mem_right)

	var mem_title: Label = Label.new()
	mem_title.text = "📜 靈魂記憶 (LTM/MTM/STM)"
	mem_title.add_theme_font_size_override("font_size", 11)
	mem_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.8))
	mem_right.add_child(mem_title)

	_ltm_label = Label.new()
	_ltm_label.text = "特質(LTM): 隨和親切"
	_ltm_label.add_theme_font_size_override("font_size", 9)
	_ltm_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_ltm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mem_right.add_child(_ltm_label)

	_mtm_label = Label.new()
	_mtm_label.text = "人際(MTM): 尚無熟識居民"
	_mtm_label.add_theme_font_size_override("font_size", 9)
	_mtm_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_mtm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mem_right.add_child(_mtm_label)

	var stm_title: Label = Label.new()
	stm_title.text = "近期生活日誌 (STM):"
	stm_title.add_theme_font_size_override("font_size", 9)
	stm_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	mem_right.add_child(stm_title)

	_stm_vbox = VBoxContainer.new()
	_stm_vbox.set("theme_override_constants/separation", 1)
	mem_right.add_child(_stm_vbox)

	root_vbox.add_child(HSeparator.new())

	# --- 底部狀態與聚焦列 (Footer) ---
	var footer_hbox: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(footer_hbox)

	_pos_label = Label.new()
	_pos_label.text = "座標: (0, 0)"
	_pos_label.add_theme_font_size_override("font_size", 10)
	_pos_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_pos_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(_pos_label)

	_focus_btn = Button.new()
	_focus_btn.text = "🎯 聚焦"
	_focus_btn.add_theme_font_size_override("font_size", 11)
	_focus_btn.pressed.connect(_on_focus_button_pressed)
	footer_hbox.add_child(_focus_btn)

func _create_stat_row(parent: GridContainer, label_text: String, fill_color: Color) -> ProgressBar:
	var hbox: HBoxContainer = HBoxContainer.new()
	parent.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size = Vector2(28, 0)
	lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(lbl)

	var pbar: ProgressBar = ProgressBar.new()
	pbar.custom_minimum_size = Vector2(45, 12)
	pbar.max_value = 100.0
	pbar.value = 100.0
	pbar.show_percentage = false

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(2)
	pbar.add_theme_stylebox_override("fill", fill_style)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.18, 0.8)
	bg_style.set_corner_radius_all(2)
	pbar.add_theme_stylebox_override("background", bg_style)

	hbox.add_child(pbar)
	return pbar

# ------------------------------------------------------------------------------
# 4. 角色側邊平滑跟隨 (Side-by-Side Positioning)
# ------------------------------------------------------------------------------

func _update_screen_position() -> void:
	if _target_npc == null or not is_instance_valid(_target_npc):
		return

	# 取得 NPC 在畫布視口中的像素座標
	var screen_pos: Vector2 = _target_npc.get_global_transform_with_canvas().origin
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var panel_w: float = _panel.size.x
	var panel_h: float = _panel.size.y

	# 預設定位：擺放在角色「右側」28 像素處，垂直居中對齊
	var target_x: float = screen_pos.x + 28.0
	var target_y: float = screen_pos.y - panel_h * 0.5

	# 若太靠近視窗右側邊界，自動翻轉至角色「左側」
	if target_x + panel_w > vp_size.x - 12.0:
		target_x = screen_pos.x - panel_w - 28.0

	# 視窗邊界夾取防呆 (避開頂部 TimeHUD 55px 高度)
	target_x = clampf(target_x, 10.0, maxf(10.0, vp_size.x - panel_w - 10.0))
	target_y = clampf(target_y, 55.0, maxf(55.0, vp_size.y - panel_h - 10.0))

	# 平滑跟隨插值
	_panel.position = _panel.position.lerp(Vector2(target_x, target_y), 0.35)

# ------------------------------------------------------------------------------
# 5. 數據動態刷新 (Data Update)
# ------------------------------------------------------------------------------

func _update_npc_data() -> void:
	if not (_target_npc is NPCControllerClass):
		return

	var ctrl: NPCController = _target_npc as NPCController
	var data: NPCData = ctrl.npc_data as NPCData

	# 1. 標題與基本資料
	if data:
		_name_label.text = data.npc_name
		_job_label.text = "[%s]" % _get_job_name(data.job_id)
	else:
		_name_label.text = ctrl.name
		_job_label.text = ""

	if ctrl.is_dead:
		_state_badge.text = "💀 亡故 (%s)" % ctrl.death_cause
		_state_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_state_badge.text = ctrl.get_state_name()
		_update_state_badge_color(ctrl.current_state)

	var nav = _get_nav_manager()
	if nav and nav.has_method("local_to_map"):
		var cell: Vector2i = nav.local_to_map(ctrl.global_position)
		_pos_label.text = "座標: %s | Cell: %s" % [str(ctrl.global_position.round()), str(cell)]
	else:
		_pos_label.text = "座標: %s" % str(ctrl.global_position.round())

	# 2. AI 大腦決策
	var dec: Dictionary = ctrl.last_decision
	if ctrl.is_dead:
		_action_label.text = "行動: 💀 停止生命活動"
		_target_poi_label.text = "地點: ⚰️ 長眠於此"
		_override_label.text = "機制: 💀 生命跡象終止"
		_override_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		var act_name: String = String(dec.get("best_action_name", _get_action_name(ctrl.current_action_id)))
		if ctrl.current_state == NPCControllerClass.State.MOVING:
			match ctrl.current_action_id:
				6: act_name = "前往社交"
				3: act_name = "前往用餐"
				5: act_name = "返家休息"
				4: act_name = "前往就醫"
				1: act_name = "前往閱讀"
				2: act_name = "前往購物"
				0: act_name = "外出散步" if int(dec.get("target_location", 0)) > 0 else "閒逛中"
				7, 8: act_name = "前往執勤"
		_action_label.text = "行動: %s" % act_name
		var poi_id: int = int(dec.get("target_location", 0))
		_target_poi_label.text = "地點: POI %d (%s)" % [poi_id, _get_poi_desc(poi_id)]

		# 決策機制與引擎
		var is_override: bool = bool(dec.get("is_rule_override", false))
		if is_override:
			var reason: String = String(dec.get("override_reason", "規則覆蓋"))
			_override_label.text = "機制: ⚠️ %s" % reason
			_override_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		else:
			_override_label.text = "機制: 🧠 神經網路自主"
			_override_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

	var global_node: Node = _get_global()
	if global_node and global_node.has_method("get_decision_service"):
		var service = global_node.get_decision_service()
		if service and service.get("_use_csharp_onnx"):
			_engine_label.text = "引擎: 🚀 C# ONNX Runtime"
		else:
			_engine_label.text = "引擎: ⚙️ GDScript MLP"

	# 神經輸出評分 (Top 2)
	if ctrl.is_dead:
		_update_top_scores(PackedFloat32Array())
	else:
		_update_top_scores(dec.get("scores", PackedFloat32Array()))

	# 3. 生理數值
	if data:
		_hp_bar.value = data.hp
		_health_bar.value = data.health
		_stamina_bar.value = data.stamina
		_hunger_bar.value = data.hunger
		_social_bar.value = data.social_desire
		_mood_bar.value = data.mood

		_money_label.text = "💰 金錢: $ %d" % data.money
		_inventory_label.text = "🎒 木:%d | 石:%d | 礦:%d | 作物:%d | 魚:%d | 料理:%d | 便當:%d" % [
			data.wood, data.stone, data.mineral, data.crops, data.fish, data.food, data.lunchbox
		]

		# LTM 行為習慣加權 (午夜結算演化)
		if _action_weights_label:
			if data.action_weights.size() >= 9:
				var w_items: Array = []
				for w_i in range(9):
					var w_name: String = NPCData.ACTION_WEIGHT_NAMES[w_i] if w_i < NPCData.ACTION_WEIGHT_NAMES.size() else "行為%d" % w_i
					w_items.append({"name": w_name, "w": data.action_weights[w_i]})
				w_items.sort_custom(func(a, b): return a["w"] > b["w"])
				var w_parts: Array[String] = []
				for wi in range(mini(3, w_items.size())):
					w_parts.append("%s: %.2fx" % [w_items[wi]["name"], w_items[wi]["w"]])
				_action_weights_label.text = "🎯 LTM 習慣: %s" % " | ".join(w_parts)
			else:
				_action_weights_label.text = "🎯 LTM 習慣: 均等加權 (1.00x)"

		# 4. 社交大腦與靈魂記憶更新 (Tab 2)
		var decision_service = global_node.get_decision_service() if global_node and global_node.has_method("get_decision_service") else null
		var is_social_ready: bool = decision_service.is_social_engine_available() if decision_service else false
		if _social_engine_label:
			if is_social_ready:
				_social_engine_label.text = "引擎: 🚀 C# ONNX (時/慾/心/好/距/天/史)"
				_social_engine_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
			else:
				_social_engine_label.text = "引擎: ⚙️ 原生降級推論"
				_social_engine_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))

		var last_eval: Dictionary = data.last_social_evaluation
		if _social_target_label:
			if last_eval.is_empty():
				_social_target_label.text = "對象: 尚無近期互動"
				_social_target_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			else:
				var t_name: String = str(last_eval.get("target_name", "未知"))
				var s_score: float = float(last_eval.get("score", 0.0))
				_social_target_label.text = "對象: %s (評分: %.1f%%)" % [t_name, s_score * 100.0]
				_social_target_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

		if _social_act_label:
			if last_eval.is_empty():
				_social_act_label.text = "行為: 待機中"
				_social_act_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			else:
				var act_id: int = int(last_eval.get("action_id", 1))
				var act_icon_str: String = SOCIAL_ACTION_ICONS.get(act_id, str(last_eval.get("action_name", "普通聊天")))
				var role_str: String = "發起" if bool(last_eval.get("is_initiator", true)) else "回應"
				_social_act_label.text = "行為: %s (%s)" % [act_icon_str, role_str]
				_social_act_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))

		if _social_feedback_label:
			if last_eval.is_empty():
				_social_feedback_label.text = "反饋: 尚未產生互動記憶"
				_social_feedback_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			else:
				var df: float = float(last_eval.get("delta_fav", 0.0))
				var dt: float = float(last_eval.get("delta_trust", 0.0))
				var dm: float = float(last_eval.get("delta_mood", 0.0))
				_social_feedback_label.text = "反饋: 好感%+0.1f | 信任%+0.1f | 心情%+0.1f" % [df, dt, dm]
				_social_feedback_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))

		if _social_time_label:
			if last_eval.is_empty():
				_social_time_label.text = "特徵: 距離/好感/上次天數"
			else:
				var t_stamp: String = str(last_eval.get("timestamp", ""))
				_social_time_label.text = "時間: %s (7維神經網絡運算)" % t_stamp

		# 5. 周遭 NPC 社交意願雷達 (即時評估身邊村民的 ONNX 意願)
		if _social_radar_box and ctrl.has_method("get_nearby_social_candidates"):
			for ch in _social_radar_box.get_children():
				ch.queue_free()

			var radar_list: Array[Dictionary] = ctrl.get_nearby_social_candidates()
			if radar_list.is_empty():
				var empty_lbl: Label = Label.new()
				empty_lbl.text = "• 32 格內暫無其他居民"
				empty_lbl.add_theme_font_size_override("font_size", 9)
				empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				_social_radar_box.add_child(empty_lbl)
			else:
				var max_show: int = mini(3, radar_list.size())
				for k in range(max_show):
					var c_info: Dictionary = radar_list[k]
					var c_name: String = str(c_info.get("name", "NPC"))
					var c_dist: float = float(c_info.get("distance", 0.0))
					var c_score: float = float(c_info.get("score", 0.0))
					var c_str_id: String = str(c_info.get("str_id", "")).replace("npc_", "NPC ")

					var r_row: HBoxContainer = HBoxContainer.new()
					var r_lbl: Label = Label.new()
					r_lbl.text = "• %s (%s): 意向 %.1f%% (%.1f格)" % [c_str_id, c_name, c_score * 100.0, c_dist]
					r_lbl.add_theme_font_size_override("font_size", 9)
					r_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if k > 0 else Color(1.0, 0.9, 0.4))
					r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					r_row.add_child(r_lbl)
					_social_radar_box.add_child(r_row)

		# 6. LTM 特質 (12 大靈魂性格詞條)
		if _ltm_label:
			var active_traits: Array[String] = data.get_active_ltm_trait_labels()
			var traits_str: String = " ".join(active_traits.map(func(t: String) -> String: return "[%s]" % t))
			_ltm_label.text = "特質(LTM): %s" % traits_str

		# 7. MTM / LTSM 人際關係與 10 天歷史事件分數
		if _mtm_label:
			var top_friends: Array = []
			for fid in data.friendships.keys():
				var num_id: int = _extract_npc_number(fid)
				var h_score: float = data.get_history_score_to_npc(num_id)
				top_friends.append({"id": fid, "f": data.friendships[fid], "t": data.get_trust(fid), "h": h_score})
			top_friends.sort_custom(func(a, b): return a["f"] > b["f"])
			if top_friends.is_empty():
				_mtm_label.text = "人際(MTM): 尚無熟識居民"
			else:
				var rel_str_parts: Array[String] = []
				for k in range(mini(2, top_friends.size())):
					var tf = top_friends[k]
					var h_pct: int = int(round(float(tf["h"]) * 100.0))
					rel_str_parts.append("%s (好感%.0f/信%.0f | 歷史%d%%)" % [tf["id"].replace("npc_", "NPC "), tf["f"], tf["t"], h_pct])
				_mtm_label.text = "人際(MTM): %s" % " | ".join(rel_str_parts)

		# 8. STM 事件清單 (近期生活與社交日誌)
		if _stm_vbox:
			for ch in _stm_vbox.get_children():
				ch.queue_free()
			if data.stm_events.is_empty():
				var empty_lbl: Label = Label.new()
				empty_lbl.text = "• 今日尚無特殊經歷"
				empty_lbl.add_theme_font_size_override("font_size", 9)
				empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				_stm_vbox.add_child(empty_lbl)
			else:
				for k in range(mini(3, data.stm_events.size())):
					var ev_lbl: Label = Label.new()
					ev_lbl.text = "• %s" % data.stm_events[k]
					ev_lbl.add_theme_font_size_override("font_size", 9)
					ev_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
					ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					_stm_vbox.add_child(ev_lbl)

func _update_top_scores(scores: PackedFloat32Array) -> void:
	for child in _score_box.get_children():
		child.queue_free()

	if scores.is_empty():
		return

	var items: Array = []
	for i in range(mini(scores.size(), ACTION_NAMES.size())):
		items.append({"score": scores[i], "idx": i})
	items.sort_custom(func(a, b): return a["score"] > b["score"])

	var count: int = mini(2, items.size())
	for k in range(count):
		var item: Dictionary = items[k]
		var score: float = float(item["score"])
		var idx: int = int(item["idx"])
		var act_name: String = ACTION_NAMES[idx]

		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = "%s: %.1f%%" % [act_name, score * 100.0]
		label.add_theme_font_size_override("font_size", 9)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var mini_bar: ProgressBar = ProgressBar.new()
		mini_bar.custom_minimum_size = Vector2(50, 6)
		mini_bar.max_value = 1.0
		mini_bar.value = score
		mini_bar.show_percentage = false

		var b_style: StyleBoxFlat = StyleBoxFlat.new()
		b_style.bg_color = Color(0.2, 0.7, 0.9, 0.8) if k == 0 else Color(0.4, 0.5, 0.6, 0.6)
		b_style.set_corner_radius_all(2)
		mini_bar.add_theme_stylebox_override("fill", b_style)

		row.add_child(mini_bar)
		_score_box.add_child(row)

func _update_state_badge_color(state: NPCController.State) -> void:
	match state:
		NPCController.State.IDLE:
			_state_badge.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		NPCController.State.MOVING:
			_state_badge.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		NPCController.State.INTERACTING:
			_state_badge.add_theme_color_override("font_color", Color(1.0, 0.5, 0.9))
		NPCController.State.WORKING:
			_state_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		NPCController.State.RESTING:
			_state_badge.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))

# ------------------------------------------------------------------------------
# 6. 公開操作方法與訊號 (Public API & Signals)
# ------------------------------------------------------------------------------

## 檢視特定 NPC
func inspect_npc(npc: Node2D) -> void:
	if npc == null or not is_instance_valid(npc):
		close()
		return

	_target_npc = npc
	visible = true

	# 立即重置至角色側邊
	var screen_pos: Vector2 = _target_npc.get_global_transform_with_canvas().origin
	_panel.position = screen_pos + Vector2(28.0, -_panel.size.y * 0.5)
	_update_npc_data()

## 關閉面板
func close() -> void:
	_target_npc = null
	visible = false
	var g: Node = _get_global()
	if g and g.has_method("deselect_npc"):
		g.deselect_npc()

func _on_focus_button_pressed() -> void:
	if _target_npc and is_instance_valid(_target_npc):
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera and camera.has_method("move_to"):
			camera.call("move_to", _target_npc.global_position)
		elif camera:
			camera.global_position = _target_npc.global_position

func _connect_global_signals() -> void:
	var g: Node = _get_global()
	if g and g.has_signal("npc_selected"):
		g.npc_selected.connect(func(npc: Node2D): inspect_npc(npc))
	if g and g.has_signal("npc_deselected"):
		g.npc_deselected.connect(func(): close())

# ------------------------------------------------------------------------------
# 7. 內部輔助與名稱對照 (Helpers)
# ------------------------------------------------------------------------------

func _get_action_name(act_id: int) -> String:
	if act_id >= 0 and act_id < ACTION_NAMES.size():
		return ACTION_NAMES[act_id]
	return "未知"

func _get_job_name(job_id: int) -> String:
	match job_id:
		1: return "礦工"
		2: return "圖書館員"
		3: return "漁夫"
		4: return "餐廳員工"
		5: return "醫護人員"
		6: return "伐木工"
		7: return "農民"
		8: return "商店店長"
		9: return "家庭主夫/婦"
	return "自由職"

func _get_poi_desc(poi_id: int) -> String:
	match poi_id:
		0: return "原地"
		12: return "商店"
		13: return "餐廳"
		14: return "伐木場"
		15: return "礦場"
		16: return "農田"
		17: return "釣魚場"
		18: return "醫院"
		19: return "圖書館"
		20: return "廣場"
		21: return "自宅"
	if poi_id >= 1 and poi_id <= 11:
		return "住宅 %d 號" % poi_id
	return "地點 %d" % poi_id

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

func _extract_npc_number(id_str: String) -> int:
	var clean: String = id_str.replace("npc_", "").replace("NPC_", "").strip_edges()
	if clean.is_valid_int():
		return clean.to_int()
	return 1

