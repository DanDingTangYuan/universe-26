# ==============================================================================
# 26號宇宙 (Universe 26) - 居民性格詞條設定面板 (NPC Trait Settings Dialog)
# 檔案路徑: res://scripts/ui/npc_trait_settings_dialog.gd
# 職責描述:
#   1. 提供開場選單 (TitleScreen) 與暫停選單自訂 20 位 NPC 之 12 大靈魂性格詞條
#   2. 支援即時計算並預覽對神經網路輸入偏移 (personality_offset) 的實時影響
#   3. 將玩家自訂之詞條持久化至 user://custom_npc_traits.json 與 Global 單例
#   4. 純 GDScript 動態佈局構建，遵守 Rule 6
# ==============================================================================
class_name NPCTraitSettingsDialog
extends CanvasLayer

const CONFIG_PATH: String = "user://custom_npc_traits.json"
const TEMPLATES_PATH: String = "res://data/npc_templates.json"

var _panel: PanelContainer = null
var _npc_list_vbox: VBoxContainer = null
var _npc_buttons: Array[Button] = []
var _selected_npc_id: String = "npc_01"

# 右側編輯元件
var _cur_npc_name_lbl: Label = null
var _cur_npc_job_lbl: Label = null
var _trait_checkboxes: Dictionary = {}
var _active_tags_lbl: Label = null
var _offset_preview_lbl: Label = null

# 暫存編輯字典 { npc_id: { trait_key: bool } }
var _custom_traits_cache: Dictionary = {}

# 12 大性格特質配置
const TRAIT_CONFIGS: Array[Dictionary] = [
	{ "key": "healthy", "name": "健康強健", "desc": "體質強健抗病 (健康 +10)" },
	{ "key": "medicine_jar", "name": "藥罐子", "desc": "體虛容易發病 (健康 -10)" },
	{ "key": "eat_like_a_bird", "name": "小鳥胃", "desc": "食量小飽食平緩 (飽食 +10)" },
	{ "key": "greedy", "name": "貪吃", "desc": "食慾旺盛易餓 (飽食 -10)" },
	{ "key": "social_person", "name": "社交達人", "desc": "熱愛群體活動 (社交需求 +10)" },
	{ "key": "asocial", "name": "社恐孤僻", "desc": "偏好獨處離群 (社交需求 -10)" },
	{ "key": "optimistic", "name": "樂觀開朗", "desc": "抗壓高不易憂鬱 (心情 +10)" },
	{ "key": "pessimistic", "name": "悲觀憂慮", "desc": "敏感易陷入低潮 (心情 -10)" },
	{ "key": "strong", "name": "筋骨強壯", "desc": "體魄強悍體力流失較緩" },
	{ "key": "debility", "name": "體質虛弱", "desc": "容易感到疲累勞頓" },
	{ "key": "big_e", "name": "大E外向", "desc": "極高頻率主動打招呼與互動" },
	{ "key": "big_i", "name": "大I內斂", "desc": "沉穩少言重視個人思維時間" }
]

func _init() -> void:
	layer = 126

func _ready() -> void:
	_load_saved_configs()
	_build_ui()
	visible = false

## 開啟設定面板
func open() -> void:
	visible = true
	_load_saved_configs()
	_select_npc(_selected_npc_id)

## 關閉設定面板
func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# 1. 介面動態構建 (Programmatic UI Construction)
# ------------------------------------------------------------------------------

func _build_ui() -> void:
	# 背景遮罩
	var bg_rect: ColorRect = ColorRect.new()
	bg_rect.color = Color(0.02, 0.04, 0.08, 0.85)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(bg_rect)

	# 中央視窗面板 (寬度 760, 高度 560)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 560)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	panel_style.border_color = Color(0.3, 0.65, 0.95, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel_style.shadow_size = 20
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set("theme_override_constants/separation", 10)
	_panel.add_child(main_vbox)

	# 標題列
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "⚙️ 全鎮居民 12 大靈魂性格詞條配置 (LTM Traits & Neural Bias)"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "✖ 關閉 (ESC)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# 雙欄主要內容 (左: NPC 選擇列表, 右: 詞條編輯與即時偏移預覽)
	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.set("theme_override_constants/separation", 14)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# ===== 左欄：NPC 清單 (捲動列表) =====
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(230, 0)
	left_vbox.set("theme_override_constants/separation", 6)
	content_hbox.add_child(left_vbox)

	var npc_list_title: Label = Label.new()
	npc_list_title.text = "👥 選擇居民 (共 20 位)："
	npc_list_title.add_theme_font_size_override("font_size", 12)
	npc_list_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	left_vbox.add_child(npc_list_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_vbox.add_child(scroll)

	_npc_list_vbox = VBoxContainer.new()
	_npc_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_list_vbox.set("theme_override_constants/separation", 3)
	scroll.add_child(_npc_list_vbox)

	_build_npc_list()

	content_hbox.add_child(VSeparator.new())

	# ===== 右欄：詞條編輯區塊 =====
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.set("theme_override_constants/separation", 8)
	content_hbox.add_child(right_vbox)

	# 目前編輯角色標頭
	var cur_header: HBoxContainer = HBoxContainer.new()
	cur_header.set("theme_override_constants/separation", 10)
	right_vbox.add_child(cur_header)

	_cur_npc_name_lbl = Label.new()
	_cur_npc_name_lbl.text = "居民: Alex (NPC 01)"
	_cur_npc_name_lbl.add_theme_font_size_override("font_size", 14)
	_cur_npc_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cur_header.add_child(_cur_npc_name_lbl)

	_cur_npc_job_lbl = Label.new()
	_cur_npc_job_lbl.text = "[職業: 礦工]"
	_cur_npc_job_lbl.add_theme_font_size_override("font_size", 12)
	_cur_npc_job_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	cur_header.add_child(_cur_npc_job_lbl)

	# 12 大性格 CheckBox 雙列排列
	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(grid_scroll)

	var traits_grid: GridContainer = GridContainer.new()
	traits_grid.columns = 2
	traits_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_grid.set("theme_override_constants/h_separation", 12)
	traits_grid.set("theme_override_constants/v_separation", 6)
	grid_scroll.add_child(traits_grid)

	for tc in TRAIT_CONFIGS:
		var chk: CheckBox = CheckBox.new()
		chk.text = "%s - %s" % [tc["name"], tc["desc"]]
		chk.add_theme_font_size_override("font_size", 10)
		chk.focus_mode = Control.FOCUS_NONE
		var t_key: String = tc["key"]
		chk.toggled.connect(func(pressed: bool):
			_on_trait_toggled(t_key, pressed)
		)
		traits_grid.add_child(chk)
		_trait_checkboxes[t_key] = chk

	# 預覽資訊框
	var prev_panel: PanelContainer = PanelContainer.new()
	var prev_style: StyleBoxFlat = StyleBoxFlat.new()
	prev_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	prev_style.set_corner_radius_all(6)
	prev_style.set_content_margin_all(8)
	prev_panel.add_theme_stylebox_override("panel", prev_style)
	right_vbox.add_child(prev_panel)

	var prev_vbox: VBoxContainer = VBoxContainer.new()
	prev_vbox.set("theme_override_constants/separation", 3)
	prev_panel.add_child(prev_vbox)

	_active_tags_lbl = Label.new()
	_active_tags_lbl.text = "靈魂標籤: [健康強健] [大E外向]"
	_active_tags_lbl.add_theme_font_size_override("font_size", 11)
	_active_tags_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	prev_vbox.add_child(_active_tags_lbl)

	_offset_preview_lbl = Label.new()
	_offset_preview_lbl.text = "神經輸入偏置 (Bias): 健康 +10.0 | 心情 +0.0 | 社交需求 +0.0"
	_offset_preview_lbl.add_theme_font_size_override("font_size", 10)
	_offset_preview_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	prev_vbox.add_child(_offset_preview_lbl)

	# 底部操作按鈕列
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.set("theme_override_constants/separation", 10)
	right_vbox.add_child(btn_hbox)

	var reset_btn: Button = Button.new()
	reset_btn.text = "🔄 重設為初始預設"
	reset_btn.custom_minimum_size = Vector2(130, 34)
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_hbox.add_child(reset_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "💾 儲存並應用居民詞條 (Save)"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0, 34)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_pressed)
	btn_hbox.add_child(save_btn)

# ------------------------------------------------------------------------------
# 2. 居民列表構建與選取 (NPC List & Selection)
# ------------------------------------------------------------------------------

func _build_npc_list() -> void:
	for ch in _npc_list_vbox.get_children():
		ch.queue_free()
	_npc_buttons.clear()

	var templates: Array = _load_templates()
	for i in range(templates.size()):
		var t: Dictionary = templates[i]
		var nid: String = String(t.get("id", "npc_%02d" % (i + 1)))
		var nname: String = String(t.get("name", "NPC"))
		var jname: String = String(t.get("job_name", "鎮民"))

		var btn: Button = Button.new()
		btn.text = "%s. %s [%s]" % [nid.replace("npc_", ""), nname, jname]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		var btn_id: String = nid
		btn.pressed.connect(func():
			_select_npc(btn_id)
		)
		_npc_list_vbox.add_child(btn)
		_npc_buttons.append(btn)

func _select_npc(npc_id: String) -> void:
	_selected_npc_id = npc_id

	# 更新左側按鈕高亮
	for btn in _npc_buttons:
		if btn.text.begins_with(npc_id.replace("npc_", "") + "."):
			btn.modulate = Color(1.3, 1.3, 0.7)
		else:
			btn.modulate = Color.WHITE

	# 讀取該 NPC 的性格配置
	var npc_traits: Dictionary = _custom_traits_cache.get(npc_id, {})
	for tc in TRAIT_CONFIGS:
		var k: String = tc["key"]
		var chk: CheckBox = _trait_checkboxes.get(k)
		if chk:
			chk.set_pressed_no_signal(bool(npc_traits.get(k, false)))

	# 更新角色名稱標題
	var t_data: Dictionary = _get_template_by_id(npc_id)
	_cur_npc_name_lbl.text = "居民: %s (%s)" % [t_data.get("name", "Alex"), npc_id.replace("npc_", "NPC ")]
	_cur_npc_job_lbl.text = "[職業: %s]" % t_data.get("job_name", "鎮民")

	_update_offset_preview()

func _on_trait_toggled(trait_key: String, pressed: bool) -> void:
	if not _custom_traits_cache.has(_selected_npc_id):
		_custom_traits_cache[_selected_npc_id] = {}
	_custom_traits_cache[_selected_npc_id][trait_key] = pressed
	_update_offset_preview()

func _update_offset_preview() -> void:
	var cur_traits: Dictionary = _custom_traits_cache.get(_selected_npc_id, {})
	var tags: Array[String] = []
	for tc in TRAIT_CONFIGS:
		var k: String = tc["key"]
		if bool(cur_traits.get(k, false)):
			tags.append(tc["name"])

	if tags.is_empty():
		_active_tags_lbl.text = "靈魂標籤: (尚無勾選詞條，依職業預設特質)"
	else:
		_active_tags_lbl.text = "靈魂標籤: " + " ".join(tags.map(func(t: String) -> String: return "[%s]" % t))

	# 計算偏移
	var health_off: float = 0.0
	var hunger_off: float = 0.0
	var social_off: float = 0.0
	var mood_off: float = 0.0

	if bool(cur_traits.get("medicine_jar", false)): health_off -= 10.0
	if bool(cur_traits.get("healthy", false)): health_off += 10.0
	if bool(cur_traits.get("greedy", false)): hunger_off -= 10.0
	if bool(cur_traits.get("eat_like_a_bird", false)): hunger_off += 10.0
	if bool(cur_traits.get("social_person", false)): social_off -= 10.0
	if bool(cur_traits.get("asocial", false)): social_off += 10.0
	if bool(cur_traits.get("optimistic", false)): mood_off += 10.0
	if bool(cur_traits.get("pessimistic", false)): mood_off -= 10.0

	_offset_preview_lbl.text = "神經特徵輸入偏置：健康 %+0.1f | 飽食需求 %+0.1f | 社交需求 %+0.1f | 心情 %+0.1f" % [
		health_off, -hunger_off, -social_off, mood_off
	]

# ------------------------------------------------------------------------------
# 3. 儲存、讀取與重設 (Config I/O & Application)
# ------------------------------------------------------------------------------

func _on_save_pressed() -> void:
	# 1. 寫入 user:// 磁碟檔案
	var json_str: String = JSON.stringify(_custom_traits_cache, "\t")
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()

	# 2. 同步至 Global
	var g = _get_global()
	if g and g.has_method("set_all_custom_npc_traits"):
		g.set_all_custom_npc_traits(_custom_traits_cache)

	# 3. 若遊戲場景已有實體 NPC，直接即時套用更新
	if g and g.has_method("get_all_npcs"):
		var npcs: Array[Node2D] = g.get_all_npcs()
		for n in npcs:
			if n and n.get("npc_data"):
				var nd: NPCData = n.get("npc_data")
				if _custom_traits_cache.has(nd.npc_id):
					var c_traits: Dictionary = _custom_traits_cache[nd.npc_id]
					for k in c_traits.keys():
						nd.ltm_entries[k] = bool(c_traits[k])
					nd.calculate_personality_offset_from_entries()
					nd.stats_changed.emit(nd.npc_id)

	# 4. 顯示通知 Toast
	var time_hud = get_tree().root.find_child("TimeHUD", true, false)
	if time_hud and time_hud.has_method("show_toast"):
		time_hud.show_toast("💾 居民性格詞條設定已儲存並套用！", Color(0.4, 0.9, 0.5))

func _on_reset_pressed() -> void:
	if _custom_traits_cache.has(_selected_npc_id):
		_custom_traits_cache[_selected_npc_id].clear()
	_select_npc(_selected_npc_id)

func _load_saved_configs() -> void:
	var g = _get_global()
	if g and g.has_method("get_all_custom_npc_traits"):
		var global_traits: Dictionary = g.get_all_custom_npc_traits()
		if not global_traits.is_empty():
			_custom_traits_cache = global_traits.duplicate(true)
			return

	if FileAccess.file_exists(CONFIG_PATH):
		var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var txt: String = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary:
				_custom_traits_cache = (parsed as Dictionary).duplicate(true)
				if g and g.has_method("set_all_custom_npc_traits"):
					g.set_all_custom_npc_traits(_custom_traits_cache)

func _load_templates() -> Array:
	if not FileAccess.file_exists(TEMPLATES_PATH):
		return []
	var file: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if not file:
		return []
	var txt: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(txt)
	return parsed if (parsed is Array) else []

func _get_template_by_id(npc_id: String) -> Dictionary:
	var templates: Array = _load_templates()
	for t in templates:
		if String(t.get("id", "")) == npc_id:
			return t
	return {}

func _get_global() -> Node:
	if Engine.has_singleton("Global"):
		return Engine.get_singleton("Global")
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st and st.root and st.root.has_node("Global"):
		return st.root.get_node("Global")
	return null

