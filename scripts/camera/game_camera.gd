# ==============================================================================
# 26號宇宙 (Universe 26) - 獨立遊戲攝影機控制器 (Game Camera Controller)
# 檔案路徑: res://scripts/camera/game_camera.gd
# 職責描述: 封裝獨立攝影機行為：滑鼠中鍵平移拖曳、滾輪縮放、平滑導航追蹤與地圖邊界限制
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

## 是否啟用滑鼠滾輪縮放
@export var enable_zoom: bool = true

## 最小縮放倍率 (數值越小看越遠)
@export var min_zoom: float = 0.5

## 最大縮放倍率 (數值越大看越近)
@export var max_zoom: float = 4.0

## 單次滾輪滾動縮放倍率變化量
@export var zoom_factor: float = 1.15

## 是否自動根據導航地圖設定邊界 (避免鏡頭拖出地圖黑邊)
@export var auto_bind_map_limits: bool = true

# ------------------------------------------------------------------------------
# 3. 內部狀態 (Internal Variables)
# ------------------------------------------------------------------------------

var _is_panning: bool = false
var _target_node: Node2D = null
var _move_tween: Tween = null
var _original_smoothing_enabled: bool = true

# ------------------------------------------------------------------------------
# 4. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	_original_smoothing_enabled = position_smoothing_enabled
	
	# 延遲一幀以確保 NavigationManager 與 TileMapLayer 已載入
	call_deferred("_try_bind_map_limits")

func _process(_delta: float) -> void:
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
				zoom_by_factor(zoom_factor)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by_factor(1.0 / zoom_factor)
				
	# 2. 處理滑鼠中鍵拖曳平移
	elif event is InputEventMouseMotion and _is_panning:
		# 除以當前 zoom 值，確保不同縮放比例下滑鼠拖曳皆為 1:1 像素對應
		global_position -= event.relative / zoom
		camera_moved.emit(global_position)

# ------------------------------------------------------------------------------
# 5. 拖曳與縮放核心邏輯 (Pan & Zoom Logic)
# ------------------------------------------------------------------------------

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
	var target_zoom: Vector2 = zoom * factor
	target_zoom.x = clampf(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clampf(target_zoom.y, min_zoom, max_zoom)
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", target_zoom, 0.12)
	camera_zoomed.emit(target_zoom)

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
