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

# ------------------------------------------------------------------------------
# 2. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	layer = 10 # 確保繪製在所有遊戲物件與 Camera2D 之上
	_connect_global_signals()
	_connect_ui_buttons()
	update_all_display()

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 存讀檔快捷鍵 (F5/F9, Ctrl+S/Ctrl+L)
		if event.keycode == KEY_F5 or (event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed)):
			_on_save_pressed()
			return
		elif event.keycode == KEY_F9 or (event.keycode == KEY_L and (event.ctrl_pressed or event.meta_pressed)):
			_on_load_pressed()
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
				elif is_equal_approx(g.time_scale, 32.0):
					_set_speed(60.0)
				else:
					_set_speed(4.0)
		)
	if ff_hour_btn:
		ff_hour_btn.pressed.connect(_on_ff_hour_pressed)
	if ff_midnight_btn:
		ff_midnight_btn.pressed.connect(_on_ff_midnight_pressed)

	_setup_save_load_buttons()

func _setup_save_load_buttons() -> void:
	var right_box: HBoxContainer = get_node_or_null("TopBar/HBoxContainer/RightBox") as HBoxContainer
	if right_box:
		var sep := VSeparator.new()
		right_box.add_child(sep)

		var save_btn := Button.new()
		save_btn.name = "SaveButton"
		save_btn.text = "💾 存檔"
		save_btn.tooltip_text = "儲存遊戲進度 (快捷鍵: F5 / Ctrl+S)"
		save_btn.focus_mode = Control.FOCUS_NONE
		save_btn.pressed.connect(_on_save_pressed)
		right_box.add_child(save_btn)

		var load_btn := Button.new()
		load_btn.name = "LoadButton"
		load_btn.text = "📂 讀檔"
		load_btn.tooltip_text = "讀取遊戲存檔 (快捷鍵: F9 / Ctrl+L)"
		load_btn.focus_mode = Control.FOCUS_NONE
		load_btn.pressed.connect(_on_load_pressed)
		right_box.add_child(load_btn)

# ------------------------------------------------------------------------------
# 4. 畫面更新邏輯 (Display Updates)
# ------------------------------------------------------------------------------

func update_all_display() -> void:
	_update_time_display()
	_update_nav_display()
	_update_npc_display()
	_update_speed_buttons()

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
		var is_fast: bool = current_scale >= 4.0
		speed_4x_btn.modulate = Color(1.3, 1.3, 0.7) if is_fast else Color.WHITE
		if current_scale > 4.0:
			speed_4x_btn.text = "%dx" % int(current_scale)
		else:
			speed_4x_btn.text = "4x"

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
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("save_game"):
		var ok: bool = global_node.save_game()
		if ok:
			show_toast("💾 遊戲進度已成功儲存！(F5)", Color(0.4, 0.9, 0.5))
		else:
			show_toast("❌ 存檔失敗！", Color(1.0, 0.3, 0.3))

func _on_load_pressed() -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("load_game"):
		var ok: bool = global_node.load_game()
		if ok:
			show_toast("📂 存檔已成功載入！(F9)", Color(0.4, 0.9, 0.5))
			update_all_display()
		else:
			show_toast("⚠️ 找不到存檔檔案！", Color(1.0, 0.7, 0.3))

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

