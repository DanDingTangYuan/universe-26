# ==============================================================================
# 26號宇宙 (Universe 26) - 獨立遊戲攝影機控制器 (Game Camera Controller)
# 檔案路徑: res://scripts/camera/game_camera.gd
# 職責描述: 封裝獨立攝影機行為：鍵盤方向鍵移動、滑鼠中鍵平移拖曳、滾輪與 Z/X 鍵縮放、平滑導航追蹤與地圖邊界限制
# ==============================================================================
class_name GameCamera
extends Camera2D

# ------------------------------------------------------------------------------
# 1. 訊號 (Signals)
# ------------------------------------------------------------------------------

## 攝影機世界座標變更時發射
signal camera_moved(new_pos: Vector2)

## 攝影機縮放比例變更時發射
signal camera_zoomed(new_zoom: Vector2)

# ------------------------------------------------------------------------------
# 2. 屬性與匯出設定 (Properties & Exports)
# ------------------------------------------------------------------------------

## 是否啟用滑鼠中鍵拖曳平移
@export var enable_pan: bool = true

## 是否啟用縮放功能 (滑鼠滾輪與 Z/X 鍵)
@export var enable_zoom: bool = true

## 是否啟用鍵盤方向鍵平移
@export var enable_keyboard_pan: bool = true

## 鍵盤平移移動速度 (像素/秒)
@export var keyboard_pan_speed: float = 500.0

## 最小縮放倍率 (數值越小看越遠)
@export var min_zoom: float = 0.5

## 最大縮放倍率 (數值越大看越近)
@export var max_zoom: float = 4.0

## 單次滾輪滾動或按鍵縮放倍率變化量
@export var zoom_factor: float = 1.15

## 是否自動根據導航地圖設定邊界 (避免鏡頭拖出地圖黑邊)
@export var auto_bind_map_limits: bool = true

# ------------------------------------------------------------------------------
# 3. 內部狀態 (Internal Variables)
# ------------------------------------------------------------------------------

var _is_panning: bool = false
var _target_node: Node2D = null
var _move_tween: Tween = null
var _zoom_tween: Tween = null
var _target_zoom: Vector2 = Vector2.ONE
var _original_smoothing_enabled: bool = true
var _last_zoom_key_time: float = 0.0

## 鍵盤長按縮放的最小間隔時間 (秒)
const ZOOM_KEY_REPEAT_INTERVAL: float = 0.15

# ------------------------------------------------------------------------------
# 4. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	_original_smoothing_enabled = position_smoothing_enabled
	_target_zoom = zoom
	
	# 延遲一幀以確保 NavigationManager 與 TileMapLayer 已載入
	call_deferred("_try_bind_map_limits")

func _process(delta: float) -> void:
	# 處理鍵盤方向鍵移動視角
	_handle_keyboard_pan(delta)

	# 若有設定跟隨目標且當前未手動拖曳，自動跟隨
	if _target_node and is_instance_valid(_target_node) and not _is_panning:
		global_position = _target_node.global_position

func _unhandled_input(event: InputEvent) -> void:
	# 1. 處理滑鼠滾輪縮放與中鍵點擊
	if event is InputEventMouseButton:
		if enable_pan and event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_start_panning()
			else:
				_stop_panning()
				
		elif enable_zoom and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				
	# 2. 處理滑鼠中鍵拖曳平移
	elif event is InputEventMouseMotion and _is_panning:
		# 除以當前 zoom 值，確保不同縮放比例下滑鼠拖曳皆為 1:1 像素對應
		global_position -= event.relative / zoom
		_clamp_to_limits()
		camera_moved.emit(global_position)

	# 3. 處理鍵盤 Z (放大) / X (縮小)
	elif event is InputEventKey and enable_zoom and event.pressed:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
			return

		var now: float = Time.get_ticks_msec() / 1000.0
		if not event.echo:
			if event.keycode == KEY_Z:
				zoom_in()
				_last_zoom_key_time = now
			elif event.keycode == KEY_X:
				zoom_out()
				_last_zoom_key_time = now
		elif now - _last_zoom_key_time >= ZOOM_KEY_REPEAT_INTERVAL:
			if event.keycode == KEY_Z:
				zoom_in()
				_last_zoom_key_time = now
			elif event.keycode == KEY_X:
				zoom_out()
				_last_zoom_key_time = now

# ------------------------------------------------------------------------------
# 5. 拖曳、鍵盤移動與縮放核心邏輯 (Pan & Zoom Logic)
# ------------------------------------------------------------------------------

func _handle_keyboard_pan(delta: float) -> void:
	if not enable_keyboard_pan:
		return

	# 若使用者正在輸入文字，不觸發視角移動
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
		return

	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		# 手動按鍵移動時，主動中斷跟隨目標與進行中的位移 Tween
		if _move_tween and _move_tween.is_valid():
			_move_tween.kill()
		_target_node = null

		# 除以 zoom.x 確保在不同縮放比例下，畫面捲動速度保持一致手感
		var effective_speed: float = keyboard_pan_speed
		if zoom.x > 0.0:
			effective_speed /= zoom.x

		global_position += dir.normalized() * effective_speed * delta
		_clamp_to_limits()
		camera_moved.emit(global_position)

func _start_panning() -> void:
	_is_panning = true
	# 手動拖曳時關閉平滑過渡，提供即時手感
	position_smoothing_enabled = false
	
	# 打斷任何進行中的相機移動 Tween 或跟隨
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_target_node = null

func _stop_panning() -> void:
	_is_panning = false
	# 恢復原設定的平滑模式
	position_smoothing_enabled = _original_smoothing_enabled

## 依指定倍率進行平滑縮放
func zoom_by_factor(factor: float) -> void:
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	else:
		_target_zoom = zoom

	_target_zoom = _target_zoom * factor
	_target_zoom.x = clampf(_target_zoom.x, min_zoom, max_zoom)
	_target_zoom.y = clampf(_target_zoom.y, min_zoom, max_zoom)

	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "zoom", _target_zoom, 0.12)
	camera_zoomed.emit(_target_zoom)

## 放大視野 (單次依 zoom_factor 放大)
func zoom_in() -> void:
	zoom_by_factor(zoom_factor)

## 縮小視野 (單次依 zoom_factor 縮小)
func zoom_out() -> void:
	zoom_by_factor(1.0 / zoom_factor)

## 確保相機世界座標限制於已設定的地圖邊界內
func _clamp_to_limits() -> void:
	if limit_left > -9999999 and limit_right < 9999999 and limit_left < limit_right:
		global_position.x = clampf(global_position.x, float(limit_left), float(limit_right))
	if limit_top > -9999999 and limit_bottom < 9999999 and limit_top < limit_bottom:
		global_position.y = clampf(global_position.y, float(limit_top), float(limit_bottom))

# ------------------------------------------------------------------------------
# 6. 公開操作介面 (Public Methods)
# ------------------------------------------------------------------------------

## 平滑移動相機至指定世界像素座標
func move_to(target_pos: Vector2, duration: float = 1.0) -> void:
	if _is_panning:
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_target_node = null
	
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", target_pos, duration)

## 設定相機持續跟隨特定節點 (如特定 NPC)
func follow(target: Node2D) -> void:
	_target_node = target
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

## 解除相機跟隨
func stop_following() -> void:
	_target_node = null

## 依據地圖邊界與地塊大小設定相機可捲動邊界
func set_camera_limits(rect: Rect2i, tile_size: Vector2i = Vector2i(16, 16)) -> void:
	limit_left = rect.position.x * tile_size.x
	limit_top = rect.position.y * tile_size.y
	limit_right = (rect.position.x + rect.size.x) * tile_size.x
	limit_bottom = (rect.position.y + rect.size.y) * tile_size.y
	print("[GameCamera] 相機邊界已鎖定: Left=%d, Top=%d, Right=%d, Bottom=%d" % [limit_left, limit_top, limit_right, limit_bottom])

# ------------------------------------------------------------------------------
# 7. 自動邊界綁定 (Auto Limits Binding)
# ------------------------------------------------------------------------------

func _try_bind_map_limits() -> void:
	if not auto_bind_map_limits:
		return
	
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node and global_node.has_method("get_navigation_manager"):
		var nav: Node = global_node.get_navigation_manager()
		if nav and "map_rect" in nav and "tile_size" in nav:
			var rect: Rect2i = nav.map_rect
			var t_size: Vector2i = nav.tile_size
			if rect.size.x > 0 and rect.size.y > 0:
				set_camera_limits(rect, t_size)
