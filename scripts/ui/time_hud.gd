# ==============================================================================
# 26號宇宙 (Universe 26) - 頂部時間與系統資訊 HUD 控制器 (Time HUD)
# 檔案路徑: res://scripts/ui/time_hud.gd
# 職責描述: 於畫面頂部全域呈現遊戲天數、時鐘、晝夜時段、時間流速與導航狀態
# ==============================================================================
class_name TimeHUD
extends CanvasLayer

# ------------------------------------------------------------------------------
# 1. 節點參考 (Node References)
# ------------------------------------------------------------------------------

@onready var day_label: Label = $TopBar/HBoxContainer/LeftBox/DayLabel
@onready var period_label: Label = $TopBar/HBoxContainer/LeftBox/PeriodLabel
@onready var clock_label: Label = $TopBar/HBoxContainer/LeftBox/ClockLabel
@onready var time_progress: ProgressBar = $TopBar/HBoxContainer/LeftBox/TimeProgressBar

@onready var nav_label: Label = $TopBar/HBoxContainer/CenterBox/NavStatusLabel
@onready var npc_label: Label = $TopBar/HBoxContainer/CenterBox/NpcStatusLabel

@onready var pause_btn: Button = $TopBar/HBoxContainer/RightBox/PauseButton
@onready var speed_1x_btn: Button = $TopBar/HBoxContainer/RightBox/Speed1xButton
@onready var speed_2x_btn: Button = $TopBar/HBoxContainer/RightBox/Speed2xButton
@onready var speed_4x_btn: Button = $TopBar/HBoxContainer/RightBox/Speed4xButton
@onready var ff_hour_btn: Button = $TopBar/HBoxContainer/RightBox/FFHourButton
@onready var ff_midnight_btn: Button = $TopBar/HBoxContainer/RightBox/FFMidnightButton

const SaveSlotDialogClass = preload("res://scripts/ui/save_slot_dialog.gd")
const TitleScreenClass = preload("res://scripts/ui/title_screen.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const RumorDialogClass = preload("res://scripts/ui/rumor_propagation_dialog.gd")

var _save_slot_dialog: SaveSlotDialogClass = null
var _title_screen: TitleScreenClass = null
var _pause_menu: PauseMenuClass = null
var _rumor_dialog: RumorDialogClass = null
var menu_btn: Button = null
var rumor_btn: Button = null
var mode_badge_lbl: Label = null

# ------------------------------------------------------------------------------
# 2. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	layer = 10 # 確保繪製在所有遊戲物件與 Camera2D 之上
	_connect_global_signals()
	_connect_ui_buttons()
	_ensure_dialogs()
	update_all_display()
	_update_mode_visibility()

func _ensure_dialogs() -> void:
	if _save_slot_dialog == null:
		_save_slot_dialog = SaveSlotDialogClass.new()
		_save_slot_dialog.name = "SaveSlotDialog"
		_save_slot_dialog.visible = false
		add_child(_save_slot_dialog)

	if _pause_menu == null:
		_pause_menu = PauseMenuClass.new()
		_pause_menu.name = "PauseMenu"
		_pause_menu.save_load_requested.connect(func():
			_save_slot_dialog.open(SaveSlotDialogClass.DialogMode.MANAGE)
		)
		_pause_menu.returned_to_title.connect(func():
			if _title_screen:
				_title_screen.show_screen()
		)
		add_child(_pause_menu)

	if _title_screen == null:
		_title_screen = TitleScreenClass.new()
		_title_screen.name = "TitleScreen"
		_title_screen.load_requested.connect(func():
			_save_slot_dialog.open(SaveSlotDialogClass.DialogMode.LOAD)
		)
		add_child(_title_screen)

	if _rumor_dialog == null:
		_rumor_dialog = RumorDialogClass.new()
		_rumor_dialog.name = "RumorPropagationDialog"
		_rumor_dialog.visible = false
		add_child(_rumor_dialog)

	_save_slot_dialog.slot_action_completed.connect(func(mode: int, _slot_id: int):
		if mode == SaveSlotDialogClass.DialogMode.LOAD:
			if _title_screen and _title_screen.visible:
				_title_screen.hide_screen()
			if _pause_menu and _pause_menu.visible:
				_pause_menu.resume()
	)

func _process(_delta: float) -> void:
	# 持續更新進度條與平滑時鐘，確保即時性
	_update_time_display()

# ------------------------------------------------------------------------------
# 3. 訊號連接 (Signal Connections)
# ------------------------------------------------------------------------------

func _connect_global_signals() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		if global_node.has_signal("tick_passed"):
			global_node.tick_passed.connect(_on_tick_passed)
		if global_node.has_signal("day_passed"):
			global_node.day_passed.connect(_on_day_passed)
		if global_node.has_signal("time_scale_changed"):
			global_node.time_scale_changed.connect(_on_time_scale_changed)
		if global_node.has_signal("time_paused_toggled"):
			global_node.time_paused_toggled.connect(_on_time_paused_toggled)
		if global_node.has_signal("on_midnight_reached"):
			global_node.on_midnight_reached.connect(_on_midnight_reached)
		if global_node.has_signal("npc_selected"):
			global_node.npc_selected.connect(_on_npc_selected)
		if global_node.has_signal("npc_deselected"):
			global_node.npc_deselected.connect(_on_npc_deselected)
		if global_node.has_signal("npc_registered"):
			global_node.npc_registered.connect(_on_npc_registered)
		if global_node.has_signal("npc_died"):
			global_node.npc_died.connect(_on_npc_died)
		if global_node.has_signal("game_saved"):
			global_node.game_saved.connect(_on_game_saved)
		if global_node.has_signal("game_loaded"):
			global_node.game_loaded.connect(_on_game_loaded)
		if global_node.has_signal("trajectory_logging_toggled"):
			global_node.trajectory_logging_toggled.connect(_on_trajectory_logging_toggled)
		if global_node.has_signal("app_mode_changed"):
			global_node.app_mode_changed.connect(_on_app_mode_changed)
		if global_node.has_signal("navigation_manager_registered"):
			global_node.navigation_manager_registered.connect(_on_navigation_manager_registered)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _rumor_dialog and _rumor_dialog.visible:
				_rumor_dialog.close()
				get_viewport().set_input_as_handled()
				return
			if _save_slot_dialog and _save_slot_dialog.visible:
				_save_slot_dialog.close()
				get_viewport().set_input_as_handled()
				return
			if _title_screen and _title_screen.visible:
				return
			if _pause_menu:
				if _pause_menu.visible:
					_pause_menu.resume()
				else:
					_pause_menu.open()
				get_viewport().set_input_as_handled()
				return

		# 存讀檔、軌跡錄製與重開局快捷鍵 (F5/F6/F9/F2, Ctrl+S/Ctrl+L/Ctrl+R)
		if event.keycode == KEY_F5 or (event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed)):
			_on_save_pressed()
			return
		elif event.keycode == KEY_F6:
			_on_record_pressed()
			return
		elif event.keycode == KEY_F7:
			if _rumor_dialog:
				if _rumor_dialog.visible:
					_rumor_dialog.close()
				else:
					_rumor_dialog.open()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_F9 or (event.keycode == KEY_L and (event.ctrl_pressed or event.meta_pressed)):
			_on_load_pressed()
			return
		elif event.keycode == KEY_F2 or (event.keycode == KEY_R and (event.ctrl_pressed or event.meta_pressed)):
			_on_restart_pressed()
			return

		match event.keycode:
			KEY_SPACE:
				_on_pause_button_pressed()
			KEY_1:
				_set_speed(1.0)
			KEY_2:
				_set_speed(2.0)
			KEY_3:
				_set_speed(4.0)
			KEY_4:
				_set_speed(8.0)
			KEY_5:
				_set_speed(16.0)
			KEY_6:
				_set_speed(60.0)

var speed_60x_btn: Button = null
var record_btn: Button = null

func _connect_ui_buttons() -> void:
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_button_pressed)
	if speed_1x_btn:
		speed_1x_btn.pressed.connect(func(): _set_speed(1.0))
	if speed_2x_btn:
		speed_2x_btn.pressed.connect(func(): _set_speed(2.0))
	if speed_4x_btn:
		speed_4x_btn.pressed.connect(func():
			var g = get_node_or_null("/root/Global")
			if g:
				if is_equal_approx(g.time_scale, 4.0):
					_set_speed(8.0)
				elif is_equal_approx(g.time_scale, 8.0):
					_set_speed(16.0)
				elif is_equal_approx(g.time_scale, 16.0):
					_set_speed(32.0)
				else:
					_set_speed(4.0)
		)
	_setup_speed_60x_button()
	if ff_hour_btn:
		ff_hour_btn.pressed.connect(_on_ff_hour_pressed)
	if ff_midnight_btn:
		ff_midnight_btn.pressed.connect(_on_ff_midnight_pressed)

	_setup_save_load_buttons()

func _setup_speed_60x_button() -> void:
	var right_box: HBoxContainer = get_node_or_null("TopBar/HBoxContainer/RightBox") as HBoxContainer
	if right_box and speed_4x_btn:
		speed_60x_btn = Button.new()
		speed_60x_btn.name = "Speed60xButton"
		speed_60x_btn.text = "⚡ 60x"
		speed_60x_btn.tooltip_text = "極速推進 (60 倍速 / 快捷鍵: 6)"
		speed_60x_btn.focus_mode = Control.FOCUS_NONE
		speed_60x_btn.pressed.connect(func(): _set_speed(60.0))
		right_box.add_child(speed_60x_btn)
		right_box.move_child(speed_60x_btn, speed_4x_btn.get_index() + 1)

func _setup_save_load_buttons() -> void:
	var right_box: HBoxContainer = get_node_or_null("TopBar/HBoxContainer/RightBox") as HBoxContainer
	if right_box:
		var sep := VSeparator.new()
		right_box.add_child(sep)

		mode_badge_lbl = Label.new()
		mode_badge_lbl.name = "ModeBadgeLabel"
		mode_badge_lbl.text = " [🔬 模擬工具] "
		mode_badge_lbl.add_theme_font_size_override("font_size", 12)
		mode_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		mode_badge_lbl.visible = false
		right_box.add_child(mode_badge_lbl)

		var save_btn := Button.new()
		save_btn.name = "SaveButton"
		save_btn.text = "💾 存檔"
		save_btn.tooltip_text = "選擇槽位儲存進度 (快捷鍵: F5 / Ctrl+S)"
		save_btn.focus_mode = Control.FOCUS_NONE
		save_btn.pressed.connect(_on_save_pressed)
		right_box.add_child(save_btn)

		var load_btn := Button.new()
		load_btn.name = "LoadButton"
		load_btn.text = "📂 讀檔"
		load_btn.tooltip_text = "選擇槽位載入進度 (快捷鍵: F9 / Ctrl+L)"
		load_btn.focus_mode = Control.FOCUS_NONE
		load_btn.pressed.connect(_on_load_pressed)
		right_box.add_child(load_btn)

		var r_btn := Button.new()
		r_btn.name = "RumorButton"
		r_btn.text = "📢 情報"
		r_btn.tooltip_text = "檢驗全鎮情報擴散因果拓撲與發布傳聞 (快捷鍵: F7)"
		r_btn.focus_mode = Control.FOCUS_NONE
		r_btn.pressed.connect(func():
			if _rumor_dialog:
				if _rumor_dialog.visible:
					_rumor_dialog.close()
				else:
					_rumor_dialog.open()
		)
		right_box.add_child(r_btn)
		rumor_btn = r_btn

		menu_btn = Button.new()
		menu_btn.name = "MenuButton"
		menu_btn.text = "選單"
		menu_btn.tooltip_text = "暫停選單 (快捷鍵: ESC)"
		menu_btn.focus_mode = Control.FOCUS_NONE
		menu_btn.pressed.connect(func():
			if _pause_menu:
				_pause_menu.open()
		)
		right_box.add_child(menu_btn)

		var rec_btn := Button.new()
		rec_btn.name = "RecordButton"
		record_btn = rec_btn
		_update_record_button_ui()
		rec_btn.focus_mode = Control.FOCUS_NONE
		rec_btn.pressed.connect(_on_record_pressed)
		right_box.add_child(rec_btn)

# ------------------------------------------------------------------------------
# 4. 畫面更新邏輯 (Display Updates)
# ------------------------------------------------------------------------------

func update_all_display() -> void:
	_update_time_display()
	_update_nav_display()
	_update_npc_display()
	_update_speed_buttons()
	_update_record_button_ui()

func _update_time_display() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if not global_node:
		return

	# 1. 天數
	if day_label:
		day_label.text = "第 %d 天" % global_node.current_day
	
	# 2. 時間與時鐘
	if clock_label:
		clock_label.text = global_node.get_formatted_time()
	
	# 3. 晝夜時段判斷
	if period_label:
		var hour: int = global_node.get_current_hour()
		var period_str: String = "深夜"
		if hour >= 5 and hour < 8:
			period_str = "清晨"
		elif hour >= 8 and hour < 12:
			period_str = "上午"
		elif hour >= 12 and hour < 14:
			period_str = "中午"
		elif hour >= 14 and hour < 17:
			period_str = "下午"
		elif hour >= 17 and hour < 20:
			period_str = "傍晚"
		elif hour >= 20 and hour < 24:
			period_str = "夜晚"
		period_label.text = period_str

	# 4. 一日時間進度條 (0.0 ~ 1.0)
	if time_progress:
		time_progress.value = global_node.get_normalized_time()

	# 5. 若導航尚未完成顯示，自律嘗試刷新狀態
	if nav_label and nav_label.text.begins_with("導航: 初始化中"):
		_update_nav_display()

func _on_navigation_manager_registered(_nav: Node) -> void:
	_update_nav_display()

func _update_nav_display() -> void:
	if not nav_label:
		return
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_navigation_manager():
		var nav: Node = global_node.get_navigation_manager()
		if "astar" in nav and nav.astar != null:
			var walkable_count: int = nav._walkable_cells.size() if "_walkable_cells" in nav else 0
			nav_label.text = "導航: A* 就緒 (%d格)" % walkable_count
			return
	nav_label.text = "導航: 初始化中..."

func _update_speed_buttons() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if not global_node:
		return

	if pause_btn:
		pause_btn.text = "▶ 繼續" if global_node.is_time_paused else "⏸ 暫停"
	
	# 突顯當前選取的倍速按鈕顏色
	var current_scale: float = global_node.time_scale
	if speed_1x_btn:
		speed_1x_btn.modulate = Color(1.3, 1.3, 0.7) if is_equal_approx(current_scale, 1.0) else Color.WHITE
	if speed_2x_btn:
		speed_2x_btn.modulate = Color(1.3, 1.3, 0.7) if is_equal_approx(current_scale, 2.0) else Color.WHITE
	if speed_4x_btn:
		var is_fast: bool = (current_scale >= 4.0 and current_scale < 60.0)
		speed_4x_btn.modulate = Color(1.3, 1.3, 0.7) if is_fast else Color.WHITE
		if current_scale > 4.0 and current_scale < 60.0:
			speed_4x_btn.text = "%dx" % int(current_scale)
		else:
			speed_4x_btn.text = "4x"
	if speed_60x_btn:
		speed_60x_btn.modulate = Color(1.3, 1.3, 0.7) if is_equal_approx(current_scale, 60.0) else Color.WHITE

## 公開方法：更新 NPC 當前狀態字串
func set_npc_status(status_text: String) -> void:
	if npc_label:
		npc_label.text = status_text

func _update_npc_display() -> void:
	if not npc_label:
		return
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("get_selected_npc"):
		var selected = global_node.get_selected_npc()
		if selected and is_instance_valid(selected):
			var state_str: String = selected.get_state_name() if selected.has_method("get_state_name") else "活動中"
			npc_label.text = "🎯 %s: %s" % [selected.name, state_str]
			return

	if global_node and global_node.has_method("get_all_npcs"):
		var npcs: Array[Node2D] = global_node.get_all_npcs()
		var dead_count: int = 0
		for npc in npcs:
			if npc is CharacterBody2D and "is_dead" in npc and npc.is_dead:
				dead_count += 1
		var alive_count: int = npcs.size() - dead_count
		if dead_count > 0:
			npc_label.text = "👥 鎮民: %d 存活 (💀 %d 亡故)" % [alive_count, dead_count]
		else:
			npc_label.text = "👥 鎮民總數: %d 隻" % npcs.size()
	else:
		npc_label.text = "👥 鎮民總數: 20 隻"

func _on_npc_registered(_id: String, _node: Node2D) -> void:
	_update_npc_display()

func _on_npc_selected(npc: Node2D) -> void:
	if npc_label and is_instance_valid(npc):
		var state_str: String = npc.get_state_name() if npc.has_method("get_state_name") else "活動中"
		npc_label.text = "🎯 %s: %s" % [npc.name, state_str]

func _on_npc_deselected() -> void:
	_update_npc_display()

func _on_npc_died(npc_id: String, reason: String) -> void:
	_update_npc_display()
	show_toast("💀 鎮民 %s 因 %s 亡故！" % [npc_id, reason], Color(1.0, 0.4, 0.4))

# ------------------------------------------------------------------------------
# 5. 事件與按鈕回呼 (Callbacks)
# ------------------------------------------------------------------------------

func _on_tick_passed(_tick: int) -> void:
	_update_time_display()

func _on_day_passed(_day: int) -> void:
	_update_time_display()

func _on_time_scale_changed(_new_scale: float) -> void:
	_update_speed_buttons()

func _on_time_paused_toggled(_paused: bool) -> void:
	_update_speed_buttons()

func _on_midnight_reached(day: int) -> void:
	print("[TimeHUD] 收到午夜廣播訊號 (第 %d 天)" % day)

func _on_pause_button_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		global_node.toggle_time_paused()
		_update_speed_buttons()

func _set_speed(new_scale: float) -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		if global_node.is_time_paused:
			global_node.set_time_paused(false)
		global_node.set_time_scale(new_scale)
		_update_speed_buttons()

func _on_ff_hour_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		global_node.debug_fast_forward_ticks(60)
		_update_time_display()

func _on_ff_midnight_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		var remaining: int = GlobalClass.TICKS_PER_DAY - global_node.current_tick
		global_node.debug_fast_forward_ticks(remaining)
		_update_time_display()

# ------------------------------------------------------------------------------
# 6. 存讀檔操作與浮動提示 (Save/Load & Toast Notification)
# ------------------------------------------------------------------------------

var _toast_label: Label = null

func _on_save_pressed() -> void:
	if _save_slot_dialog:
		_save_slot_dialog.open(SaveSlotDialogClass.DialogMode.SAVE)
	else:
		var global_node: Node = get_node_or_null("/root/Global")
		if global_node and global_node.has_method("save_game"):
			var ok: bool = global_node.save_game()
			if ok:
				show_toast("💾 遊戲進度已成功儲存！(F5)", Color(0.4, 0.9, 0.5))
			else:
				show_toast("❌ 存檔失敗！", Color(1.0, 0.3, 0.3))

func _on_load_pressed() -> void:
	if _save_slot_dialog:
		_save_slot_dialog.open(SaveSlotDialogClass.DialogMode.LOAD)
	else:
		var global_node: Node = get_node_or_null("/root/Global")
		if global_node and global_node.has_method("load_game"):
			var ok: bool = global_node.load_game()
			if ok:
				show_toast("📂 存檔已成功載入！(F9)", Color(0.4, 0.9, 0.5))
				update_all_display()
			else:
				show_toast("⚠️ 找不到存檔檔案！", Color(1.0, 0.7, 0.3))

func _on_app_mode_changed(_new_mode: int) -> void:
	_update_mode_visibility()

func _update_mode_visibility() -> void:
	var global_node = get_node_or_null("/root/Global")
	var is_tool: bool = (global_node != null and global_node.current_app_mode == GlobalClass.AppMode.SIMULATION_TOOL)
	if speed_60x_btn:
		speed_60x_btn.visible = is_tool
	if record_btn:
		record_btn.visible = is_tool
	if ff_hour_btn:
		ff_hour_btn.visible = is_tool
	if ff_midnight_btn:
		ff_midnight_btn.visible = is_tool
	if mode_badge_lbl:
		mode_badge_lbl.visible = is_tool

func _on_restart_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("start_new_game"):
		show_toast("🔄 正在重新開局，記憶與世界已重置！", Color(0.3, 0.9, 1.0))
		global_node.start_new_game(true)

func _on_game_saved(filepath: String) -> void:
	print("[TimeHUD] 收到存檔廣播: ", filepath)

func _on_game_loaded(filepath: String) -> void:
	print("[TimeHUD] 收到讀檔廣播: ", filepath)
	update_all_display()

## 顯示淡出提示橫幅 (Toast)
func show_toast(msg: String, text_color: Color = Color(0.4, 0.9, 0.5)) -> void:
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.name = "ToastNotification"
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.custom_minimum_size = Vector2(300, 32)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
		style.border_color = Color(0.3, 0.7, 1.0, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6)
		_toast_label.add_theme_stylebox_override("normal", style)
		_toast_label.add_theme_font_size_override("font_size", 13)
		var vp_width: float = get_viewport().get_visible_rect().size.x
		_toast_label.position = Vector2(maxf(10.0, vp_width * 0.5 - 150.0), 58)
		add_child(_toast_label)

	_toast_label.text = msg
	_toast_label.add_theme_color_override("font_color", text_color)
	_toast_label.modulate = Color(1, 1, 1, 1)
	_toast_label.visible = true

	var tween: Tween = create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _toast_label.visible = false)

# ------------------------------------------------------------------------------
# 7. 軌跡錄製按鈕與回呼 (Trajectory Recording)
# ------------------------------------------------------------------------------

func _on_record_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("toggle_trajectory_logging"):
		var is_on: bool = global_node.toggle_trajectory_logging()
		_update_record_button_ui()
		if is_on:
			show_toast("🔴 Transformer 軌跡錄製中 (F6)", Color(1.0, 0.4, 0.4))
		else:
			show_toast("⏸ 軌跡錄製已暫停 (F6)", Color(0.8, 0.8, 0.8))

func _on_trajectory_logging_toggled(_is_on: bool) -> void:
	_update_record_button_ui()

func _update_record_button_ui() -> void:
	if record_btn:
		var global_node: Node = get_node_or_null("/root/Global")
		var is_on: bool = global_node.is_trajectory_logging() if (global_node and global_node.has_method("is_trajectory_logging")) else true
		if is_on:
			record_btn.text = "🔴 錄製中"
			record_btn.tooltip_text = "Transformer 軌跡錄製中 (快捷鍵: F6 切換)"
			record_btn.modulate = Color(1.2, 0.8, 0.8)
		else:
			record_btn.text = "⏸ 錄製暫停"
			record_btn.tooltip_text = "軌跡錄製已暫停 (快捷鍵: F6 切換)"
			record_btn.modulate = Color(0.7, 0.7, 0.7)

