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

func _connect_ui_buttons() -> void:
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_button_pressed)
	if speed_1x_btn:
		speed_1x_btn.pressed.connect(func(): _set_speed(1.0))
	if speed_2x_btn:
		speed_2x_btn.pressed.connect(func(): _set_speed(2.0))
	if speed_4x_btn:
		speed_4x_btn.pressed.connect(func(): _set_speed(4.0))
	if ff_hour_btn:
		ff_hour_btn.pressed.connect(_on_ff_hour_pressed)
	if ff_midnight_btn:
		ff_midnight_btn.pressed.connect(_on_ff_midnight_pressed)

# ------------------------------------------------------------------------------
# 4. 畫面更新邏輯 (Display Updates)
# ------------------------------------------------------------------------------

func update_all_display() -> void:
	_update_time_display()
	_update_nav_display()
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
		speed_4x_btn.modulate = Color(1.3, 1.3, 0.7) if is_equal_approx(current_scale, 4.0) else Color.WHITE

## 公開方法：更新 NPC 當前狀態字串
func set_npc_status(status_text: String) -> void:
	if npc_label:
		npc_label.text = "NPC_1: " + status_text

# ------------------------------------------------------------------------------
# 5. 事件與按鈕回呼 (Callbacks)
# ------------------------------------------------------------------------------

func _on_tick_passed(_tick: int) -> void:
	_update_time_display()

func _on_day_passed(_day: int) -> void:
	_update_time_display()

func _on_time_scale_changed(_scale: float) -> void:
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

func _set_speed(scale: float) -> void:
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node:
		if global_node.is_time_paused:
			global_node.set_time_paused(false)
		global_node.set_time_scale(scale)
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
