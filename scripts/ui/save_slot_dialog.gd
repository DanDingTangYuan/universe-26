# ==============================================================================
# 26號宇宙 (Universe 26) - 存檔槽位互動選擇視窗 (Save Slot Dialog)
# 檔案路徑: res://scripts/ui/save_slot_dialog.gd
# 職責描述: 
#   1. 提供 Slot 1 ~ 5 的視覺化卡片介面 (天數、時間、存活NPC數、平均心情、存檔時間)
#   2. 支援儲存 (Save)、載入 (Load)、覆蓋確認與刪除 (Delete) 存檔
#   3. 純 GDScript 動態建構，免除 .tscn 依賴與衝突風險
# ==============================================================================
class_name SaveSlotDialog
extends CanvasLayer

# ------------------------------------------------------------------------------
# 1. 枚舉與訊號 (Enums & Signals)
# ------------------------------------------------------------------------------

enum DialogMode {
	SAVE = 0,   ## 儲存模式 (點選槽位進行儲存或覆蓋)
	LOAD = 1,   ## 讀取模式 (點選槽位載入遊戲進度)
	MANAGE = 2  ## 管理模式 (檢視與刪除)
}

signal slot_action_completed(mode: DialogMode, slot_id: int)
signal dialog_closed()

# ------------------------------------------------------------------------------
# 2. 內部節點引用 (Node References)
# ------------------------------------------------------------------------------

var _current_mode: DialogMode = DialogMode.SAVE
var _overlay: ColorRect = null
var _main_panel: PanelContainer = null
var _title_label: Label = null
var _slot_container: VBoxContainer = null
var _confirm_modal: PanelContainer = null
var _confirm_label: Label = null
var _confirm_ok_btn: Button = null
var _pending_action_type: String = "" # "overwrite" or "delete"
var _pending_slot_id: int = -1

# ------------------------------------------------------------------------------
# 3. 初始化與介面構建 (Lifecycle & UI Setup)
# ------------------------------------------------------------------------------

func _init(mode: DialogMode = DialogMode.SAVE) -> void:
	layer = 125 # 位於所有視窗與 HUD 之上
	_current_mode = mode

func _ready() -> void:
	_build_ui()
	refresh_slots()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _confirm_modal and _confirm_modal.visible:
				_confirm_modal.visible = false
			else:
				close()
			get_viewport().set_input_as_handled()

## 開啟指定模式的 Slot 彈窗
func open(mode: DialogMode) -> void:
	_current_mode = mode
	if _confirm_modal:
		_confirm_modal.visible = false
	_update_title()
	refresh_slots()
	visible = true

## 關閉彈窗
func close() -> void:
	visible = false
	dialog_closed.emit()

func _update_title() -> void:
	if _title_label == null:
		return
	match _current_mode:
		DialogMode.SAVE:
			_title_label.text = "存檔"
		DialogMode.LOAD:
			_title_label.text = "讀檔"
		DialogMode.MANAGE:
			_title_label.text = "存讀檔"

# ------------------------------------------------------------------------------
# 4. 介面階層動態建立 (Pure GDScript Layout)
# ------------------------------------------------------------------------------

func _build_ui() -> void:
	# 1. 全螢幕半透明遮罩 (點擊阻擋)
	_overlay = ColorRect.new()
	_overlay.name = "ModalOverlay"
	_overlay.color = Color(0.02, 0.04, 0.07, 0.75)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# 2. 中央卡片外框
	_main_panel = PanelContainer.new()
	_main_panel.name = "MainPanel"
	_main_panel.custom_minimum_size = Vector2(680, 480)
	_main_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	panel_style.border_color = Color(0.25, 0.6, 0.9, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 16
	_main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	_main_panel.add_child(root_vbox)

	# 3. 頂部標題列
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_title()
	header_hbox.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✖ 關閉"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	var h_sep := HSeparator.new()
	root_vbox.add_child(h_sep)

	# 4. 中間 Slot 卡片清單 (ScrollContainer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	_slot_container = VBoxContainer.new()
	_slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_slot_container)

	# 5. 二次確認對話框 (覆蓋 / 刪除)
	_build_confirm_modal()

# ------------------------------------------------------------------------------
# 5. 二次確認彈窗 (Confirm Modal)
# ------------------------------------------------------------------------------

func _build_confirm_modal() -> void:
	_confirm_modal = PanelContainer.new()
	_confirm_modal.name = "ConfirmModal"
	_confirm_modal.custom_minimum_size = Vector2(420, 180)
	_confirm_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm_modal.visible = false

	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	c_style.border_color = Color(1.0, 0.4, 0.4, 0.9)
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(8)
	c_style.set_content_margin_all(18)
	c_style.shadow_size = 20
	_confirm_modal.add_theme_stylebox_override("panel", c_style)
	add_child(_confirm_modal)

	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 14)
	_confirm_modal.add_child(c_vbox)

	var c_title := Label.new()
	c_title.text = "⚠️ 操作確認"
	c_title.add_theme_font_size_override("font_size", 18)
	c_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_vbox.add_child(c_title)

	_confirm_label = Label.new()
	_confirm_label.text = "確定要執行此操作嗎？"
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c_vbox.add_child(_confirm_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	c_vbox.add_child(btn_hbox)

	_confirm_ok_btn = Button.new()
	_confirm_ok_btn.text = "✔ 確認執行"
	_confirm_ok_btn.pressed.connect(_on_confirm_ok_pressed)
	btn_hbox.add_child(_confirm_ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "✖ 取消"
	cancel_btn.pressed.connect(func(): _confirm_modal.visible = false)
	btn_hbox.add_child(cancel_btn)

func _show_confirm(action_type: String, slot_id: int, message: String) -> void:
	_pending_action_type = action_type
	_pending_slot_id = slot_id
	if _confirm_label:
		_confirm_label.text = message
	if _confirm_modal:
		_confirm_modal.visible = true

func _on_confirm_ok_pressed() -> void:
	_confirm_modal.visible = false
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node == null:
		return

	if _pending_action_type == "overwrite" or _pending_action_type == "save":
		var ok: bool = global_node.save_to_slot(_pending_slot_id)
		if ok:
			refresh_slots()
			slot_action_completed.emit(_current_mode, _pending_slot_id)
	elif _pending_action_type == "delete":
		var ok: bool = global_node.delete_slot(_pending_slot_id)
		if ok:
			refresh_slots()
			slot_action_completed.emit(_current_mode, _pending_slot_id)

# ------------------------------------------------------------------------------
# 6. 槽位卡片動態渲染 (Slot Cards Rendering)
# ------------------------------------------------------------------------------

## 刷新並重構 5 個 Slot 卡片內容
func refresh_slots() -> void:
	if _slot_container == null:
		return

	for child in _slot_container.get_children():
		child.queue_free()

	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	var slot_mgr: SaveSlotManager = global_node.get_save_slot_manager() if global_node else SaveSlotManager.new()

	for slot_id in range(1, SaveSlotManager.MAX_SLOTS + 1):
		var meta: Dictionary = slot_mgr.get_slot_metadata(slot_id)
		var card := _create_slot_card(slot_id, meta)
		_slot_container.add_child(card)

func _create_slot_card(slot_id: int, meta: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 78)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_empty: bool = bool(meta.get("is_empty", true))

	var card_style := StyleBoxFlat.new()
	if is_empty:
		card_style.bg_color = Color(0.05, 0.06, 0.09, 0.85)
		card_style.border_color = Color(0.2, 0.25, 0.35, 0.5)
	else:
		card_style.bg_color = Color(0.08, 0.11, 0.16, 0.92)
		card_style.border_color = Color(0.2, 0.5, 0.8, 0.8)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	# 槽位序號標籤
	var badge_label := Label.new()
	badge_label.text = "【 槽位 %d 】" % slot_id
	badge_label.custom_minimum_size = Vector2(85, 0)
	badge_label.add_theme_font_size_override("font_size", 15)
	badge_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0) if not is_empty else Color(0.5, 0.6, 0.7))
	hbox.add_child(badge_label)

	# 詳細資訊欄位 (VBox)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_vbox)

	if is_empty:
		var empty_lbl := Label.new()
		empty_lbl.text = "空白"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		empty_lbl.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(empty_lbl)
	else:
		var line1 := Label.new()
		var ts: String = meta.get("timestamp", "")
		line1.text = "第 %d 天  %s   (存檔時間: %s)" % [
			meta.get("current_day", 1),
			meta.get("formatted_time", "08:00"),
			ts
		]
		line1.add_theme_font_size_override("font_size", 14)
		line1.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		info_vbox.add_child(line1)

	# 右側按鈕區域
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(btn_hbox)

	match _current_mode:
		DialogMode.SAVE:
			var save_btn := Button.new()
			save_btn.text = "儲存" if is_empty else "覆蓋"
			save_btn.custom_minimum_size = Vector2(70, 0)
			save_btn.focus_mode = Control.FOCUS_NONE
			save_btn.pressed.connect(func(): _on_slot_save_clicked(slot_id, is_empty))
			btn_hbox.add_child(save_btn)

		DialogMode.LOAD:
			var load_btn := Button.new()
			load_btn.text = "載入"
			load_btn.custom_minimum_size = Vector2(70, 0)
			load_btn.focus_mode = Control.FOCUS_NONE
			load_btn.disabled = is_empty
			load_btn.pressed.connect(func(): _on_slot_load_clicked(slot_id))
			btn_hbox.add_child(load_btn)

	# 刪除按鈕
	var del_btn := Button.new()
	del_btn.text = "刪除"
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.disabled = is_empty
	del_btn.pressed.connect(func(): _on_slot_delete_clicked(slot_id))
	btn_hbox.add_child(del_btn)

	return card

# ------------------------------------------------------------------------------
# 7. 槽位按鈕點擊事件處理 (Slot Action Handlers)
# ------------------------------------------------------------------------------

func _on_slot_save_clicked(slot_id: int, is_empty: bool) -> void:
	if is_empty:
		var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
		if global_node:
			var ok: bool = global_node.save_to_slot(slot_id)
			if ok:
				refresh_slots()
				slot_action_completed.emit(_current_mode, slot_id)
	else:
		_show_confirm("overwrite", slot_id, "確定要覆蓋【槽位 %d】嗎？" % slot_id)

func _on_slot_load_clicked(slot_id: int) -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node:
		var ok: bool = global_node.load_from_slot(slot_id)
		if ok:
			close()
			slot_action_completed.emit(_current_mode, slot_id)

func _on_slot_delete_clicked(slot_id: int) -> void:
	_show_confirm("delete", slot_id, "確定要刪除【槽位 %d】嗎？" % slot_id)

