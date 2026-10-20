# ==============================================================================
# 26號宇宙 (Universe 26) - 獨立開始畫面 (Title Screen)
# 檔案路徑: res://scripts/ui/title_screen.gd
# 職責描述: 
#   獨立的遊戲開始畫面。
#   提供極簡乾淨的介面：遊戲標題、模型選擇下拉選單 (Transformer / MLP)、
#   開始遊戲、載入進度、模擬工具與離開，無多餘冗贅描述。
# ==============================================================================
class_name TitleScreen
extends CanvasLayer

signal game_started(app_mode: int)
signal load_requested()

const TraitSettingsDialogClass = preload("res://scripts/ui/npc_trait_settings_dialog.gd")
var _trait_settings_dialog: TraitSettingsDialogClass = null

var _bg_rect: ColorRect = null
var _panel: PanelContainer = null
var _model_dropdown: OptionButton = null
var _continue_btn: Button = null
var _new_game_btn: Button = null
var _confirm_dialog: ConfirmationDialog = null

func _init() -> void:
	layer = 115

func _ready() -> void:
	_build_ui()
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node and "skip_title_screen_on_reload" in global_node and bool(global_node.skip_title_screen_on_reload):
		global_node.skip_title_screen_on_reload = false
		hide_screen()
		game_started.emit(int(global_node.current_app_mode) if "current_app_mode" in global_node else 0)
		return
	show_screen()

## 顯示開始畫面 (暫停遊戲並覆蓋全螢幕)
func show_screen() -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node and global_node.has_method("pause_time"):
		global_node.pause_time()
	_update_buttons_state()
	visible = true

func _update_buttons_state() -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	var has_session: bool = false
	if global_node and "has_active_session" in global_node:
		has_session = bool(global_node.has_active_session)
	
	if _continue_btn:
		_continue_btn.visible = has_session
	if _new_game_btn:
		_new_game_btn.text = "✨ 開始新遊戲 (重置)" if has_session else "✨ 開始新遊戲"

## 隱藏開始畫面 (進入遊戲)
func hide_screen() -> void:
	visible = false
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node:
		global_node.has_active_session = true
		if global_node.has_method("resume_time"):
			global_node.resume_time()

func _build_ui() -> void:
	# 全螢幕背景
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color(0.05, 0.07, 0.1, 0.98)
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_rect)

	# 中央視窗
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 380)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	style.border_color = Color(0.25, 0.55, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	style.shadow_size = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# 遊戲標題
	var title_lbl := Label.new()
	title_lbl.text = "26號宇宙"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	# 模型選擇 (僅下拉選單 Transformer / MLP)
	var model_hbox := HBoxContainer.new()
	model_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	model_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(model_hbox)

	var model_lbl := Label.new()
	model_lbl.text = "AI 模型："
	model_lbl.add_theme_font_size_override("font_size", 14)
	model_hbox.add_child(model_lbl)

	_model_dropdown = OptionButton.new()
	_model_dropdown.custom_minimum_size = Vector2(160, 32)
	_model_dropdown.focus_mode = Control.FOCUS_NONE
	_model_dropdown.add_item("Transformer", 0)
	_model_dropdown.add_item("MLP", 1)

	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	var cur_model: int = global_node.get_ai_model_type() if global_node and global_node.has_method("get_ai_model_type") else 0
	_model_dropdown.selected = 0 if cur_model == 0 else 1

	_model_dropdown.item_selected.connect(func(index: int):
		if global_node and global_node.has_method("set_ai_model_type"):
			global_node.set_ai_model_type(index)
	)
	model_hbox.add_child(_model_dropdown)

	vbox.add_child(HSeparator.new())

	# 按鈕 0：繼續遊戲 (僅當前有進行中會話時顯示)
	_continue_btn = _create_btn("▶ 繼續遊戲")
	_continue_btn.pressed.connect(func():
		var g = Engine.get_main_loop().root.get_node_or_null("Global")
		if g and g.has_method("set_app_mode"):
			g.set_app_mode(0) # FORMAL_GAME
		hide_screen()
		game_started.emit(0)
	)
	vbox.add_child(_continue_btn)

	# 按鈕 1：開始新遊戲 (全新開局，重置世界與記憶資料庫)
	_new_game_btn = _create_btn("✨ 開始新遊戲")
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(_new_game_btn)

	# 按鈕 2：載入進度
	var load_btn := _create_btn("📂 載入進度")
	load_btn.pressed.connect(func():
		load_requested.emit()
	)
	vbox.add_child(load_btn)

	# 按鈕 3：模擬工具
	var tool_btn := _create_btn("🔬 模擬觀測工具")
	tool_btn.pressed.connect(func():
		var g = Engine.get_main_loop().root.get_node_or_null("Global")
		if g and g.has_method("set_app_mode"):
			g.set_app_mode(1) # SIMULATION_TOOL
		hide_screen()
		game_started.emit(1)
	)
	vbox.add_child(tool_btn)

	# 按鈕 4：居民設定 (NPC 詞條自訂)
	var traits_btn := _create_btn("⚙️ 居民性格設定")
	traits_btn.pressed.connect(func():
		if _trait_settings_dialog == null:
			_trait_settings_dialog = TraitSettingsDialogClass.new()
			add_child(_trait_settings_dialog)
		_trait_settings_dialog.open()
	)
	vbox.add_child(traits_btn)

	# 按鈕 5：離開遊戲
	var quit_btn := _create_btn("🚪 離開遊戲")
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	vbox.add_child(quit_btn)

	_update_buttons_state()

func _on_new_game_pressed() -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	var has_session: bool = false
	if global_node and "has_active_session" in global_node:
		has_session = bool(global_node.has_active_session)

	if has_session:
		if _confirm_dialog == null:
			_confirm_dialog = ConfirmationDialog.new()
			_confirm_dialog.title = "新遊戲確認"
			_confirm_dialog.dialog_text = "開始新遊戲將會重置當前世界進度與居民記憶，確定要重新開始嗎？"
			_confirm_dialog.ok_button_text = "確定重新開始"
			_confirm_dialog.cancel_button_text = "取消"
			_confirm_dialog.confirmed.connect(_do_start_new_game)
			add_child(_confirm_dialog)
		_confirm_dialog.popup_centered()
	else:
		_do_start_new_game()

func _do_start_new_game() -> void:
	var global_node = Engine.get_main_loop().root.get_node_or_null("Global")
	if global_node and global_node.has_method("start_new_game"):
		if global_node.has_method("set_app_mode"):
			global_node.set_app_mode(0) # FORMAL_GAME
		global_node.start_new_game(true)
	else:
		hide_screen()
		game_started.emit(0)

func _create_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 38)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	return btn

