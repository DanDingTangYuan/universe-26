# ==============================================================================
# 26號宇宙 (Universe 26) - 遊戲內暫停選單 (In-game Pause Menu)
# 檔案路徑: res://scripts/ui/pause_menu.gd
# 職責描述: 
#   遊戲中按下 ESC 觸發的極簡暫停視窗。
#   僅包含「恢復遊戲」、「存讀檔」、「退回主畫面」三個功能，無多餘描述。
# ==============================================================================
class_name PauseMenu
extends CanvasLayer

signal resumed()
signal save_load_requested()
signal returned_to_title()

var _overlay: ColorRect = null
var _panel: PanelContainer = null
var _confirm_dialog: ConfirmationDialog = null

func _init() -> void:
	layer = 120

func _ready() -> void:
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			resume()
			get_viewport().set_input_as_handled()

func open() -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node and global_node.has_method("pause_time"):
		global_node.pause_time()
	visible = true

func resume() -> void:
	visible = false
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node and global_node.has_method("resume_time"):
		global_node.resume_time()
	resumed.emit()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 260)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	style.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "遊戲暫停"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	# 1. 恢復遊戲
	var resume_btn := _create_btn("恢復遊戲")
	resume_btn.pressed.connect(resume)
	vbox.add_child(resume_btn)

	# 2. 存讀檔
	var save_load_btn := _create_btn("存檔 / 讀檔")
	save_load_btn.pressed.connect(func():
		save_load_requested.emit()
	)
	vbox.add_child(save_load_btn)

	# 3. 重新開局 (新遊戲)
	var restart_btn := _create_btn("✨ 重新開局 (新遊戲)")
	restart_btn.pressed.connect(func():
		if _confirm_dialog == null:
			_confirm_dialog = ConfirmationDialog.new()
			_confirm_dialog.title = "重新開局確認"
			_confirm_dialog.dialog_text = "開始新遊戲將會重置當前世界進度與居民記憶，確定要重新開始嗎？"
			_confirm_dialog.ok_button_text = "確定重新開始"
			_confirm_dialog.cancel_button_text = "取消"
			_confirm_dialog.confirmed.connect(func():
				visible = false
				var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
				if global_node and global_node.has_method("start_new_game"):
					global_node.start_new_game(true)
			)
			add_child(_confirm_dialog)
		_confirm_dialog.popup_centered()
	)
	vbox.add_child(restart_btn)

	# 4. 退回主畫面
	var title_btn := _create_btn("退回主畫面")
	title_btn.pressed.connect(func():
		visible = false
		returned_to_title.emit()
	)
	vbox.add_child(title_btn)

func _create_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	return btn

