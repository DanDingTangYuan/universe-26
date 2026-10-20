# ==============================================================================
# 26號宇宙 (Universe 26) - 情報擴散拓撲驗證與發布面板 (Rumor Propagation Dialog)
# 檔案路徑: res://scripts/ui/rumor_propagation_dialog.gd
# 職責描述:
#   1. 提供宏觀視角檢驗全鎮情報擴散成效 (知曉率進度條、世代因果拓撲樹)
#   2. 支援 5 大結構化通用模板發布 (經濟特報、醫療警訊、社交號召、工作動機、人際八卦)
#   3. 支援公佈欄張貼與私下耳語指定 NPC
#   4. 純 GDScript 動態構建介面，嚴格遵循專案架構規範
# ==============================================================================
class_name RumorPropagationDialog
extends CanvasLayer

const InformationDiffusionManagerClass = preload("res://scripts/ai/information_diffusion_manager.gd")

var _panel: PanelContainer = null
var _tab_container: TabContainer = null

# Tab 1: 拓撲驗證元件
var _rumor_dropdown: OptionButton = null
var _refresh_btn: Button = null
var _title_label: Label = null
var _category_label: Label = null
var _channel_label: Label = null
var _ratio_bar: ProgressBar = null
var _ratio_text_label: Label = null
var _tree_text: RichTextLabel = null
var _selected_rumor_id: String = ""

# Tab 2: 發布新情報元件
var _pub_channel_opt: OptionButton = null
var _pub_seed_npc_opt: OptionButton = null
var _pub_seed_container: HBoxContainer = null
var _pub_category_opt: OptionButton = null
var _slot_container: VBoxContainer = null
var _preview_title_lbl: Label = null
var _preview_content_lbl: Label = null
var _submit_pub_btn: Button = null

# 動態槽位輸入控件快取
var _slot_inputs: Dictionary = {}

func _init() -> void:
	layer = 125

func _ready() -> void:
	_build_ui()
	visible = false

## 開啟面板
func open() -> void:
	visible = true
	_refresh_rumor_dropdown()
	_update_selected_rumor_view()

## 關閉面板
func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# 1. 動態介面構建 (Programmatic UI Construction)
# ------------------------------------------------------------------------------

func _build_ui() -> void:
	# 半透明全螢幕背景遮罩
	var bg_rect: ColorRect = ColorRect.new()
	bg_rect.color = Color(0.02, 0.04, 0.08, 0.75)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(bg_rect)

	# 中央視窗面板 (寬度 700, 高度 540)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(720, 560)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.17, 0.98)
	panel_style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set("theme_override_constants/separation", 10)
	_panel.add_child(main_vbox)

	# 標題欄
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📢 小鎮情報擴散傳播與拓撲驗證中心 (Diffusion Topology)"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "✖ 關閉 (ESC)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# 分頁容器
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tab_container)

	_build_tab_verification()
	_build_tab_publishing()

# ------------------------------------------------------------------------------
# 2. 分頁一：📡 情報擴散拓撲驗證 (Diffusion Topology Verification)
# ------------------------------------------------------------------------------

func _build_tab_verification() -> void:
	var tab_ver: VBoxContainer = VBoxContainer.new()
	tab_ver.name = "📡 情報擴散拓撲驗證"
	tab_ver.set("theme_override_constants/separation", 8)
	_tab_container.add_child(tab_ver)

	# 頂部選擇列
	var sel_hbox: HBoxContainer = HBoxContainer.new()
	sel_hbox.set("theme_override_constants/separation", 8)
	tab_ver.add_child(sel_hbox)

	var sel_lbl: Label = Label.new()
	sel_lbl.text = "選擇情報條目："
	sel_lbl.add_theme_font_size_override("font_size", 12)
	sel_hbox.add_child(sel_lbl)

	_rumor_dropdown = OptionButton.new()
	_rumor_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rumor_dropdown.focus_mode = Control.FOCUS_NONE
	_rumor_dropdown.item_selected.connect(_on_rumor_selected)
	sel_hbox.add_child(_rumor_dropdown)

	_refresh_btn = Button.new()
	_refresh_btn.text = "🔄 即時刷新"
	_refresh_btn.focus_mode = Control.FOCUS_NONE
	_refresh_btn.pressed.connect(func():
		_refresh_rumor_dropdown()
		_update_selected_rumor_view()
	)
	sel_hbox.add_child(_refresh_btn)

	# 情報概要卡片
	var info_panel: PanelContainer = PanelContainer.new()
	var info_style: StyleBoxFlat = StyleBoxFlat.new()
	info_style.bg_color = Color(0.12, 0.16, 0.24, 0.9)
	info_style.set_corner_radius_all(6)
	info_style.set_content_margin_all(8)
	info_panel.add_theme_stylebox_override("panel", info_style)
	tab_ver.add_child(info_panel)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.set("theme_override_constants/separation", 4)
	info_panel.add_child(info_vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	info_vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "標題: 尚未選擇情報"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	_category_label = Label.new()
	_category_label.text = "[類別: 經濟特報]"
	_category_label.add_theme_font_size_override("font_size", 11)
	_category_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title_row.add_child(_category_label)

	_channel_label = Label.new()
	_channel_label.text = "管道: 公佈欄張貼"
	_channel_label.add_theme_font_size_override("font_size", 10)
	_channel_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	info_vbox.add_child(_channel_label)

	# 知曉率進度條列
	var ratio_row: HBoxContainer = HBoxContainer.new()
	ratio_row.set("theme_override_constants/separation", 8)
	info_vbox.add_child(ratio_row)

	var ratio_tag: Label = Label.new()
	ratio_tag.text = "全鎮知曉率："
	ratio_tag.add_theme_font_size_override("font_size", 11)
	ratio_row.add_child(ratio_tag)

	_ratio_bar = ProgressBar.new()
	_ratio_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ratio_bar.custom_minimum_size = Vector2(0, 18)
	_ratio_bar.min_value = 0.0
	_ratio_bar.max_value = 1.0
	_ratio_bar.show_percentage = false
	ratio_row.add_child(_ratio_bar)

	_ratio_text_label = Label.new()
	_ratio_text_label.text = "0% (0 / 20 居民)"
	_ratio_text_label.add_theme_font_size_override("font_size", 11)
	_ratio_text_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	ratio_row.add_child(_ratio_text_label)

	# 傳播拓撲樹文字視窗 (RichTextLabel)
	var tree_scroll: ScrollContainer = ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_ver.add_child(tree_scroll)

	_tree_text = RichTextLabel.new()
	_tree_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_text.fit_content = true
	_tree_text.bbcode_enabled = true
	_tree_text.text = "點選上方情報以檢驗擴散因果拓撲樹..."
	tree_scroll.add_child(_tree_text)

# ------------------------------------------------------------------------------
# 3. 分頁二：📢 發布新情報 (Structured Templates Publishing)
# ------------------------------------------------------------------------------

func _build_tab_publishing() -> void:
	var tab_pub: VBoxContainer = VBoxContainer.new()
	tab_pub.name = "📢 發布小鎮情報"
	tab_pub.set("theme_override_constants/separation", 10)
	_tab_container.add_child(tab_pub)

	# 傳播管道與種子目標
	var chan_hbox: HBoxContainer = HBoxContainer.new()
	chan_hbox.set("theme_override_constants/separation", 8)
	tab_pub.add_child(chan_hbox)

	var chan_lbl: Label = Label.new()
	chan_lbl.text = "傳播途徑："
	chan_lbl.add_theme_font_size_override("font_size", 12)
	chan_hbox.add_child(chan_lbl)

	_pub_channel_opt = OptionButton.new()
	_pub_channel_opt.focus_mode = Control.FOCUS_NONE
	_pub_channel_opt.add_item("📌 公佈欄公告 (全鎮居民經過可見)", 0)
	_pub_channel_opt.add_item("🤫 秘密耳語 (指定單一居民作為第 1 代傳播種子)", 1)
	_pub_channel_opt.item_selected.connect(_on_pub_channel_selected)
	chan_hbox.add_child(_pub_channel_opt)

	_pub_seed_container = HBoxContainer.new()
	_pub_seed_container.set("theme_override_constants/separation", 6)
	_pub_seed_container.visible = false
	chan_hbox.add_child(_pub_seed_container)

	var seed_lbl: Label = Label.new()
	seed_lbl.text = "目標居民："
	seed_lbl.add_theme_font_size_override("font_size", 12)
	_pub_seed_container.add_child(seed_lbl)

	_pub_seed_npc_opt = OptionButton.new()
	_pub_seed_npc_opt.focus_mode = Control.FOCUS_NONE
	_populate_seed_npc_dropdown()
	_pub_seed_container.add_child(_pub_seed_npc_opt)

	# 情報模板類別
	var cat_hbox: HBoxContainer = HBoxContainer.new()
	cat_hbox.set("theme_override_constants/separation", 8)
	tab_pub.add_child(cat_hbox)

	var cat_lbl: Label = Label.new()
	cat_lbl.text = "情報主題模板："
	cat_lbl.add_theme_font_size_override("font_size", 12)
	cat_hbox.add_child(cat_lbl)

	_pub_category_opt = OptionButton.new()
	_pub_category_opt.focus_mode = Control.FOCUS_NONE
	_pub_category_opt.add_item("🛒 經濟特報 (地點特賣折扣 / 刺激消費)", 0)
	_pub_category_opt.add_item("🏥 醫療警訊 (疫情症狀提醒 / 引導就診)", 1)
	_pub_category_opt.add_item("🎉 社交號召 (廣場慶典聚會 / 提升社交渴望)", 2)
	_pub_category_opt.add_item("🌾 工作動機 (高額補貼激勵 / 提升工作意向)", 3)
	_pub_category_opt.add_item("👥 人際八卦 (兩人間的情感評價 / 改變好感)", 4)
	_pub_category_opt.item_selected.connect(_on_pub_category_selected)
	cat_hbox.add_child(_pub_category_opt)

	tab_pub.add_child(HSeparator.new())

	# 語意槽位輸入區塊 (動態表單)
	_slot_container = VBoxContainer.new()
	_slot_container.set("theme_override_constants/separation", 6)
	tab_pub.add_child(_slot_container)

	_build_slot_form(0) # 預設載入經濟特報

	tab_pub.add_child(HSeparator.new())

	# 即時預覽卡片
	var prev_panel: PanelContainer = PanelContainer.new()
	var prev_style: StyleBoxFlat = StyleBoxFlat.new()
	prev_style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
	prev_style.set_corner_radius_all(6)
	prev_style.set_content_margin_all(8)
	prev_panel.add_theme_stylebox_override("panel", prev_style)
	tab_pub.add_child(prev_panel)

	var prev_vbox: VBoxContainer = VBoxContainer.new()
	prev_panel.add_child(prev_vbox)

	_preview_title_lbl = Label.new()
	_preview_title_lbl.text = "預覽標題: "
	_preview_title_lbl.add_theme_font_size_override("font_size", 12)
	_preview_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	prev_vbox.add_child(_preview_title_lbl)

	_preview_content_lbl = Label.new()
	_preview_content_lbl.text = "預覽內容: "
	_preview_content_lbl.add_theme_font_size_override("font_size", 11)
	_preview_content_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_preview_content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_vbox.add_child(_preview_content_lbl)

	_update_preview()

	# 底部發布按鈕
	_submit_pub_btn = Button.new()
	_submit_pub_btn.text = "🚀 發布情報至小鎮 (立即展開傳播模擬)"
	_submit_pub_btn.custom_minimum_size = Vector2(0, 38)
	_submit_pub_btn.focus_mode = Control.FOCUS_NONE
	_submit_pub_btn.add_theme_font_size_override("font_size", 13)
	_submit_pub_btn.pressed.connect(_on_submit_publish_pressed)
	tab_pub.add_child(_submit_pub_btn)

# ------------------------------------------------------------------------------
# 4. 槽位表單建構與事件回呼 (Slot Templates Form & Events)
# ------------------------------------------------------------------------------

func _on_pub_channel_selected(index: int) -> void:
	if _pub_seed_container:
		_pub_seed_container.visible = (index == 1)

func _populate_seed_npc_dropdown() -> void:
	if _pub_seed_npc_opt == null:
		return
	_pub_seed_npc_opt.clear()
	var g = _get_global()
	if g == null:
		return
	var npcs: Array[Node2D] = g.get_all_npcs()
	for i in range(npcs.size()):
		var n = npcs[i]
		if n and n.get("npc_data"):
			var d: NPCData = n.get("npc_data")
			_pub_seed_npc_opt.add_item("%s (%s)" % [d.npc_name, d.npc_id.replace("npc_", "NPC ")], i)
			_pub_seed_npc_opt.set_item_metadata(i, d.npc_id)

func _on_pub_category_selected(index: int) -> void:
	_build_slot_form(index)
	_update_preview()

func _build_slot_form(cat_idx: int) -> void:
	for ch in _slot_container.get_children():
		ch.queue_free()
	_slot_inputs.clear()

	match cat_idx:
		0: # 經濟特報 (Economy)
			_add_form_field_dropdown("location_name", "促銷設施：", ["商店 (POI 12)", "餐廳 (POI 13)"], [12, 13])
			_add_form_field_dropdown("item_name", "特惠商品：", ["精美便當", "特選料理", "高級工具組", "全品項商品"], ["精美便當", "特選料理", "高級工具組", "全品項商品"])
			_add_form_field_dropdown("discount", "折扣優惠：", ["5 折半價優惠！", "7 折特惠促銷！", "限時買一送一！", "全面超低破盤價！"], ["5折", "7折", "買一送一", "超低破盤價"])

		1: # 醫療警訊 (Health)
			_add_form_field_dropdown("symptom", "流行症狀：", ["秋季流感疲累", "高燒體虛症狀", "過度勞動透支", "突發性眩暈"], ["秋季流感疲累", "高燒體虛症狀", "過度勞動透支", "突發性眩暈"])
			_add_form_field_dropdown("clinic_name", "建議就醫處：", ["小鎮診所 (POI 14)"], [14])

		2: # 社交號召 (Social)
			_add_form_field_dropdown("location_name", "聚會地點：", ["中央噴泉廣場 (POI 20)", "小鎮餐廳前庭 (POI 13)"], [20, 13])
			_add_form_field_dropdown("time_slot", "預定時段：", ["今日晚間 19:00", "午後悠閒時光 (14:00)", "明日破曉 (06:00)"], ["今日晚間 19:00", "午後悠閒時光 (14:00)", "明日破曉 (06:00)"])

		3: # 工作動機 (Work)
			_add_form_field_dropdown("location_name", "豐收勞動地點：", ["南側農田 (POI 16)", "東側礦坑 (POI 15)", "北側伐木場 (POI 17)"], [16, 15, 17])
			_add_form_field_dropdown("bonus", "獎勵補貼：", ["每工期額外發放 $30 獎金", "高額獎金 $50 與便當配給", "全額雙倍產能激勵金"], ["$30 獎金", "$50 與便當", "雙倍產能激勵金"])

		4: # 人際八卦 (Gossip)
			_add_form_field_npc_dropdown("npc_a", "八卦主角 A：", 0)
			_add_form_field_npc_dropdown("npc_b", "八卦主角 B：", 1)
			_add_form_field_dropdown("relation_type", "關係事件：", [
				"冰釋前嫌、私下結為莫逆之交 (+好感/+信任)",
				"因金錢糾紛鬧得不可開交 (-好感/-信任)",
				"在廣場互贈便當並熱情交談 (+好感)",
				"私下發生激烈爭執並互不理睬 (-好感)"
			], [
				{"fav": 12.0, "trust": 8.0, "desc": "在樹下相談甚歡，彼此稱兄道弟"},
				{"fav": -15.0, "trust": -10.0, "desc": "因物資借貸問題反目成仇"},
				{"fav": 10.0, "trust": 5.0, "desc": "互相分享珍藏物資，氣氛十分融洽"},
				{"fav": -10.0, "trust": -5.0, "desc": "冷嘲熱諷並彼此避開接觸"}
			])

func _add_form_field_dropdown(key: String, label_text: String, items: Array[String], values: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set("theme_override_constants/separation", 8)
	_slot_container.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var opt: OptionButton = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.focus_mode = Control.FOCUS_NONE
	for i in range(items.size()):
		opt.add_item(items[i], i)
		opt.set_item_metadata(i, values[i])
	opt.item_selected.connect(func(_idx: int): _update_preview())
	row.add_child(opt)
	_slot_inputs[key] = opt

func _add_form_field_npc_dropdown(key: String, label_text: String, default_idx: int = 0) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set("theme_override_constants/separation", 8)
	_slot_container.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var opt: OptionButton = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.focus_mode = Control.FOCUS_NONE
	var g = _get_global()
	if g:
		var npcs: Array[Node2D] = g.get_all_npcs()
		for i in range(npcs.size()):
			var n = npcs[i]
			if n and n.get("npc_data"):
				var d: NPCData = n.get("npc_data")
				opt.add_item("%s (%s)" % [d.npc_name, d.npc_id.replace("npc_", "NPC ")], i)
				opt.set_item_metadata(i, { "id": d.npc_id, "name": d.npc_name })
	if opt.item_count > default_idx:
		opt.selected = default_idx
	opt.item_selected.connect(func(_idx: int): _update_preview())
	row.add_child(opt)
	_slot_inputs[key] = opt

func _update_preview() -> void:
	if _preview_title_lbl == null or _preview_content_lbl == null:
		return
	var cat_idx: int = _pub_category_opt.selected if _pub_category_opt else 0

	match cat_idx:
		0:
			var loc_name: String = _get_opt_text("location_name", "雜貨店")
			var itm_name: String = _get_opt_text("item_name", "精美便當")
			var disc: String = _get_opt_text("discount", "5折優惠")
			_preview_title_lbl.text = "【預覽標題】%s %s特惠！" % [loc_name, itm_name]
			_preview_content_lbl.text = "【預覽內容】即日起舉辦特賣活動：%s現正特惠【%s】，刺激全鎮消費！" % [itm_name, disc]
		1:
			var sym: String = _get_opt_text("symptom", "流感疲累")
			var cln: String = _get_opt_text("clinic_name", "小鎮診所")
			_preview_title_lbl.text = "【預覽標題】注意！鎮上流傳「%s」" % sym
			_preview_content_lbl.text = "【預覽內容】鎮長提醒：近期居民出現【%s】症狀，請儘速至【%s】就診！" % [sym, cln]
		2:
			var loc: String = _get_opt_text("location_name", "中央噴泉廣場")
			var tm: String = _get_opt_text("time_slot", "晚間 19:00")
			_preview_title_lbl.text = "【預覽標題】%s 居民聯歡集會！" % loc
			_preview_content_lbl.text = "【預覽內容】大家注意！【%s】將在【%s】舉行大型晚間聚會，歡迎鄉親熱情參與！" % [tm, loc]
		3:
			var wrk: String = _get_opt_text("location_name", "南側農田")
			var bns: String = _get_opt_text("bonus", "高額補貼")
			_preview_title_lbl.text = "【預覽標題】%s 產能大豐收！" % wrk
			_preview_content_lbl.text = "【預覽內容】號外！【%s】產量大增，凡參與勞動者均可獲得【%s】！" % [wrk, bns]
		4:
			var a_data: Dictionary = _get_opt_meta("npc_a", {"name": "Alex", "id": "npc_01"})
			var b_data: Dictionary = _get_opt_meta("npc_b", {"name": "Bob", "id": "npc_02"})
			var rel_meta: Dictionary = _get_opt_meta("relation_type", {"desc": "相談甚歡"})
			_preview_title_lbl.text = "【預覽標題】%s 與 %s 的八卦流傳" % [a_data.get("name", "Alex"), b_data.get("name", "Bob")]
			_preview_content_lbl.text = "【預覽內容】街坊傳聞：據目擊者稱，%s 與 %s 最近【%s】！" % [a_data.get("name", "Alex"), b_data.get("name", "Bob"), rel_meta.get("desc", "有所接觸")]

func _get_opt_text(key: String, fallback: String) -> String:
	if _slot_inputs.has(key) and _slot_inputs[key] is OptionButton:
		var opt: OptionButton = _slot_inputs[key]
		if opt.selected >= 0:
			return opt.get_item_text(opt.selected)
	return fallback

func _get_opt_meta(key: String, fallback: Variant) -> Variant:
	if _slot_inputs.has(key) and _slot_inputs[key] is OptionButton:
		var opt: OptionButton = _slot_inputs[key]
		if opt.selected >= 0:
			return opt.get_item_metadata(opt.selected)
	return fallback

# ------------------------------------------------------------------------------
# 5. 情報發布與拓撲刷新實作 (Publishing Submission & View Refresh)
# ------------------------------------------------------------------------------

func _on_submit_publish_pressed() -> void:
	var g = _get_global()
	if g == null or not g.has_method("get_diffusion_manager"):
		return
	var diff_mgr: InformationDiffusionManagerClass = g.get_diffusion_manager()
	if diff_mgr == null:
		return

	var channel_idx: int = _pub_channel_opt.selected if _pub_channel_opt else 0
	var channel_str: String = InformationDiffusionManagerClass.CHANNEL_BILLBOARD if channel_idx == 0 else InformationDiffusionManagerClass.CHANNEL_WHISPER
	var cat_idx: int = _pub_category_opt.selected if _pub_category_opt else 0

	var seed_id: String = ""
	var seed_name: String = ""
	if channel_str == InformationDiffusionManagerClass.CHANNEL_WHISPER and _pub_seed_npc_opt:
		var sel_idx: int = _pub_seed_npc_opt.selected
		if sel_idx >= 0:
			seed_id = str(_pub_seed_npc_opt.get_item_metadata(sel_idx))
			seed_name = _pub_seed_npc_opt.get_item_text(sel_idx)

	var slots: Dictionary = {}
	match cat_idx:
		0: # Economy
			slots = {
				"location_name": _get_opt_text("location_name", "商店"),
				"poi_id": int(_get_opt_meta("location_name", 12)),
				"item_name": _get_opt_text("item_name", "精美便當"),
				"discount": str(_get_opt_meta("discount", "5折"))
			}
		1: # Health
			slots = {
				"symptom": str(_get_opt_meta("symptom", "流感疲累")),
				"clinic_name": _get_opt_text("clinic_name", "小鎮診所"),
				"poi_id": int(_get_opt_meta("clinic_name", 14))
			}
		2: # Social
			slots = {
				"location_name": _get_opt_text("location_name", "噴泉廣場"),
				"poi_id": int(_get_opt_meta("location_name", 20)),
				"time_slot": str(_get_opt_meta("time_slot", "晚間 19:00"))
			}
		3: # Work
			slots = {
				"location_name": _get_opt_text("location_name", "南側農田"),
				"poi_id": int(_get_opt_meta("location_name", 16)),
				"bonus": str(_get_opt_meta("bonus", "$30 獎金"))
			}
		4: # Gossip
			var a_data: Dictionary = _get_opt_meta("npc_a", {"name": "Alex", "id": "npc_01"})
			var b_data: Dictionary = _get_opt_meta("npc_b", {"name": "Bob", "id": "npc_02"})
			var rel_meta: Dictionary = _get_opt_meta("relation_type", {"fav": 10.0, "trust": 5.0, "desc": "相談甚歡"})
			slots = {
				"npc_a_id": a_data.get("id", "npc_01"),
				"npc_a_name": a_data.get("name", "Alex"),
				"npc_b_id": b_data.get("id", "npc_02"),
				"npc_b_name": b_data.get("name", "Bob"),
				"relation_type": _get_opt_text("relation_type", "好友結盟"),
				"desc": rel_meta.get("desc", "關係融洽"),
				"delta_fav": rel_meta.get("fav", 10.0),
				"delta_trust": rel_meta.get("trust", 5.0)
			}

	var cur_day: int = int(g.current_day) if "current_day" in g else 1
	var cur_tick: int = int(g.current_tick) if "current_tick" in g else 480
	var new_rumor: Dictionary = diff_mgr.publish_rumor(
		cat_idx as InformationDiffusionManagerClass.RumorCategory,
		slots,
		channel_str,
		seed_id,
		seed_name,
		cur_day,
		cur_tick
	)

	# 若指定耳語種子，讓該種子 NPC 立即習得該情報
	if not seed_id.is_empty():
		var seed_npc = g.get_npc(seed_id)
		if seed_npc and seed_npc.get("npc_data"):
			var nd: NPCData = seed_npc.get("npc_data")
			nd.learn_rumor(new_rumor, "player", "神秘冒險者 (玩家耳語)", cur_day, cur_tick, 1)
			if seed_npc.has_method("show_speech_bubble"):
				seed_npc.show_speech_bubble("👂 「聽聞了秘密情報...」", 3.0)

	_selected_rumor_id = new_rumor.get("id", "")
	_refresh_rumor_dropdown()
	_update_selected_rumor_view()

	# 切換回驗證分頁檢視
	if _tab_container:
		_tab_container.current_tab = 0

	# 彈出全局提示
	var time_hud = get_tree().root.find_child("TimeHUD", true, false)
	if time_hud and time_hud.has_method("show_toast"):
		time_hud.show_toast("📢 情報已成功發布！傳播因果網已即時啟動", Color(0.3, 0.9, 1.0))

func _refresh_rumor_dropdown() -> void:
	if _rumor_dropdown == null:
		return
	_rumor_dropdown.clear()
	var g = _get_global()
	if g == null or not g.has_method("get_diffusion_manager"):
		return
	var diff_mgr: InformationDiffusionManagerClass = g.get_diffusion_manager()
	if diff_mgr == null:
		return

	var rumors: Array[Dictionary] = diff_mgr.get_active_rumors()
	if rumors.is_empty():
		_rumor_dropdown.add_item("• 小鎮目前無任何傳聞 (請至發布分頁新增)", 0)
		_selected_rumor_id = ""
		return

	var target_index: int = 0
	for i in range(rumors.size()):
		var r: Dictionary = rumors[i]
		var rid: String = str(r.get("id", ""))
		var stats: Dictionary = diff_mgr.get_knowledge_stats(rid)
		var item_str: String = "[%s] %s (知曉率: %s)" % [r.get("category_cn", "情報"), r.get("title", ""), stats["percentage_str"]]
		_rumor_dropdown.add_item(item_str, i)
		_rumor_dropdown.set_item_metadata(i, rid)
		if rid == _selected_rumor_id:
			target_index = i

	_rumor_dropdown.selected = target_index
	_selected_rumor_id = str(_rumor_dropdown.get_item_metadata(target_index))

func _on_rumor_selected(index: int) -> void:
	if index >= 0 and _rumor_dropdown:
		_selected_rumor_id = str(_rumor_dropdown.get_item_metadata(index))
		_update_selected_rumor_view()

func _update_selected_rumor_view() -> void:
	if _title_label == null:
		return
	var g = _get_global()
	if g == null or not g.has_method("get_diffusion_manager"):
		return
	var diff_mgr: InformationDiffusionManagerClass = g.get_diffusion_manager()
	if diff_mgr == null or _selected_rumor_id.is_empty():
		_title_label.text = "標題: 暫無情報"
		_tree_text.text = "尚無情報記錄可供拓撲驗證。"
		return

	var rumor: Dictionary = diff_mgr.get_rumor_by_id(_selected_rumor_id)
	if rumor.is_empty():
		return

	_title_label.text = "標題: %s" % rumor.get("title", "")
	_category_label.text = "[類別: %s]" % rumor.get("category_cn", "")
	var chan_text: String = "📌 公佈欄公告" if rumor.get("channel", "") == InformationDiffusionManagerClass.CHANNEL_BILLBOARD else "🤫 秘密耳語"
	_channel_label.text = "管道: %s (種子源: %s)" % [chan_text, rumor.get("seed_name", "未知")]

	var stats: Dictionary = diff_mgr.get_knowledge_stats(_selected_rumor_id)
	if _ratio_bar:
		_ratio_bar.value = float(stats.get("ratio", 0.0))
	if _ratio_text_label:
		_ratio_text_label.text = "%s (%d / %d 居民)" % [stats.get("percentage_str", "0%"), int(stats.get("count", 0)), int(stats.get("total", 20))]

	if _tree_text:
		var tree_str: String = diff_mgr.get_rumor_topology_tree_text(_selected_rumor_id)
		_tree_text.text = tree_str

func _get_global() -> Node:
	if Engine.has_singleton("Global"):
		return Engine.get_singleton("Global")
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st and st.root and st.root.has_node("Global"):
		return st.root.get_node("Global")
	return null

