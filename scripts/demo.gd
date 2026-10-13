# ==============================================================================
# 26號宇宙 (Universe 26) - 第一階段 MVP 驗證與互動測試腳本
# 檔案路徑: res://scripts/demo.gd
# 職責描述: 驗證 Global 時間系統、AStarGrid2D 網格導航、NPC 尋路移動與互動
# ==============================================================================
extends Node

const NavigationManagerClass = preload("res://scripts/core/navigation_manager.gd")
const TimeHUDClass = preload("res://scripts/ui/time_hud.gd")
const TimeHUDScene = preload("res://scene/ui/time_hud.tscn")
const GameCameraClass = preload("res://scripts/camera/game_camera.gd")
const GameCameraScene = preload("res://scene/camera/game_camera.tscn")

# ------------------------------------------------------------------------------
# 1. 節點綁定 (Exports)
# ------------------------------------------------------------------------------

@export var npc_a: CharacterBody2D
@export var npc_b: CharacterBody2D
@export var npc_c: CharacterBody2D
@export var demo_camera: Camera2D

# ------------------------------------------------------------------------------
# 2. 內部狀態 (Internal Variables)
# ------------------------------------------------------------------------------

var _nav_manager: NavigationManagerClass = null
var _time_hud: TimeHUDClass = null
var _is_npc_a_busy: bool = false
var _npc_a_start_cell: Vector2i = Vector2i.ZERO
var _npc_b_start_cell: Vector2i = Vector2i.ZERO
var _npc_c_start_cell: Vector2i = Vector2i.ZERO

# ------------------------------------------------------------------------------
# 3. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	print("[MVP] 開始初始化 26號宇宙 MVP 驗證環境...")
	
	# 1. 確保導航管理器就緒 (若場景無 NavigationManager 節點，則動態建立)
	_setup_navigation_manager()
	
	# 2. 向全域單例註冊 NPC
	_register_all_npcs()
	
	# 3. 記錄初始網格座標
	if _nav_manager:
		_npc_a_start_cell = _nav_manager.local_to_map(npc_a.global_position)
		_npc_b_start_cell = _nav_manager.local_to_map(npc_b.global_position)
		_npc_c_start_cell = _nav_manager.local_to_map(npc_c.global_position)
	
	# 4. 建立頂部時間 HUD 與操作提示 UI
	_setup_time_hud()
	
	# 5. 攝影機初始化與獨立升級
	_setup_camera()
	
	# 6. 稍微延遲後自動執行 A* 尋路展示序列
	await get_tree().create_timer(1.5).timeout
	start_mvp_demo_sequence()


func _unhandled_input(event: InputEvent) -> void:
	# 1. 滑鼠左鍵點擊：命令 NPC_A 進行 A* 尋路前往點擊位置
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_world_pos: Vector2 = demo_camera.get_global_mouse_position() if demo_camera else get_viewport().get_mouse_position()
		_handle_mouse_click_move(mouse_world_pos)

	# 2. 鍵盤快速鍵操控時間系統
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				# 空白鍵：暫停 / 繼續時間
				if Engine.has_singleton("Global") or get_node_or_null("/root/Global"):
					var global_node: Node = get_node("/root/Global")
					global_node.toggle_time_paused()
			KEY_1:
				if get_node_or_null("/root/Global"):
					get_node("/root/Global").set_time_scale(1.0)
			KEY_2:
				if get_node_or_null("/root/Global"):
					get_node("/root/Global").set_time_scale(2.0)
			KEY_4:
				if get_node_or_null("/root/Global"):
					get_node("/root/Global").set_time_scale(4.0)
			KEY_T:
				# T 鍵：快速推進 1 小時 (60 Ticks)
				if get_node_or_null("/root/Global"):
					get_node("/root/Global").debug_fast_forward_ticks(60)
			KEY_M:
				# M 鍵：快速推進至下一個午夜 (觸發記憶演化)
				if get_node_or_null("/root/Global"):
					var global_node: Node = get_node("/root/Global")
					var remaining_ticks: int = GlobalClass.TICKS_PER_DAY - global_node.current_tick
					global_node.debug_fast_forward_ticks(remaining_ticks)
			KEY_R:
				# R 鍵：重新執行巡路演示
				if not _is_npc_a_busy:
					start_mvp_demo_sequence()

# ------------------------------------------------------------------------------
# 4. 初始化輔助函式 (Setup Helpers)
# ------------------------------------------------------------------------------

func _setup_camera() -> void:
	if demo_camera:
		if not (demo_camera is GameCameraClass):
			demo_camera.set_script(GameCameraClass)
			demo_camera._ready()
	else:
		var existing: Node = get_node_or_null("GameCamera")
		if existing is Camera2D:
			demo_camera = existing
		else:
			demo_camera = GameCameraScene.instantiate() as Camera2D
			demo_camera.name = "GameCamera"
			add_child(demo_camera)

	if npc_a and demo_camera:
		demo_camera.global_position = npc_a.global_position


func _setup_navigation_manager() -> void:
	var global_nav: Node = null
	if get_node_or_null("/root/Global"):
		global_nav = get_node("/root/Global").get_navigation_manager()
	
	if global_nav is NavigationManagerClass:
		_nav_manager = global_nav
	else:
		# 動態建立並加入場景
		_nav_manager = NavigationManagerClass.new()
		_nav_manager.name = "NavigationManager"
		add_child(_nav_manager)

func _register_all_npcs() -> void:
	if not get_node_or_null("/root/Global"):
		return
	var global_node: Node = get_node("/root/Global")
	if npc_a:
		global_node.register_npc("npc_1", npc_a)
	if npc_b:
		global_node.register_npc("npc_2", npc_b)
	if npc_c:
		global_node.register_npc("npc_3", npc_c)

func _setup_time_hud() -> void:
	var existing: Node = get_node_or_null("TimeHUD")
	if existing is TimeHUDClass:
		_time_hud = existing
	else:
		_time_hud = TimeHUDScene.instantiate() as TimeHUDClass
		_time_hud.name = "TimeHUD"
		add_child(_time_hud)
	
	# 建立左下角操作提示卡片
	var hint_canvas: CanvasLayer = CanvasLayer.new()
	hint_canvas.name = "HintHUD"
	hint_canvas.layer = 9
	add_child(hint_canvas)
	
	var panel: PanelContainer = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16.0
	panel.offset_top = -48.0
	panel.offset_right = 680.0
	panel.offset_bottom = -12.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	
	var label: Label = Label.new()
	label.text = "💡 操作提示：[滑鼠中鍵 / 方向鍵] 平移視角 | [滾輪 / Z,X] 縮放 | [滑鼠左鍵] 點擊尋路 | [空白鍵] 暫停 | [1/2/4] 倍速 | [T] +1h | [M] 午夜 | [R] 重播"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	panel.add_child(label)
	hint_canvas.add_child(panel)

# ------------------------------------------------------------------------------
# 5. 滑鼠點擊與 A* 尋路互動 (Interactive Pathfinding)
# ------------------------------------------------------------------------------

func _handle_mouse_click_move(target_world_pos: Vector2) -> void:
	if _is_npc_a_busy:
		print("[MVP] NPC_1 正在移動中，請稍候...")
		return
	if _nav_manager == null or not is_instance_valid(npc_a):
		return
		
	var start_cell: Vector2i = _nav_manager.local_to_map(npc_a.global_position)
	var target_cell: Vector2i = _nav_manager.local_to_map(target_world_pos)
	
	print("[MVP] 玩家點擊目標: 世界座標 %s, 網格 %s" % [str(target_world_pos), str(target_cell)])
	
	var path: Array[Vector2i] = _nav_manager.get_id_path(start_cell, target_cell)
	if path.is_empty():
		print("[MVP] 無法找到通往 %s 的可行路徑！" % str(target_cell))
		return
		
	print("[MVP] 成功計算 A* 路徑！節點數: %d，開始移動..." % path.size())
	_is_npc_a_busy = true
	if _time_hud:
		_time_hud.set_npc_status("A* 尋路移動中...")
	move_camera_to(target_world_pos, 0.8)
	await move_npc_along_grid_path(npc_a, path, 0.2)
	_is_npc_a_busy = false
	if _time_hud:
		_time_hud.set_npc_status("已到達目標 (待機)")
	print("[MVP] NPC_1 已安全抵達目標地塊！")

# ------------------------------------------------------------------------------
# 6. A* 路徑平滑移動與動畫控制 (A* Path Walking with Tween)
# ------------------------------------------------------------------------------

## 沿著 AStarGrid2D 算出的路徑逐格移動，並自動切換 4 向動畫與到達定格
func move_npc_along_grid_path(npc: CharacterBody2D, path: Array[Vector2i], step_duration: float = 0.2) -> void:
	if path.size() <= 1:
		return
		
	var sprite: AnimatedSprite2D = npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var last_dir_str: String = "down"
	
	# 從第 1 個節點開始（第 0 個節點是起點當前所在格）
	for i: int in range(1, path.size()):
		var target_cell: Vector2i = path[i]
		var target_world_pos: Vector2 = _nav_manager.map_to_local(target_cell)
		
		# 計算當前步的方向向量
		var move_direction: Vector2 = (target_world_pos - npc.global_position).normalized()
		if move_direction != Vector2.ZERO:
			last_dir_str = get_direction_string(move_direction)
			if sprite:
				sprite.play("walk_" + last_dir_str)
		
		# 使用 Tween 進行單格平滑位移
		var tween: Tween = create_tween()
		tween.tween_property(npc, "global_position", target_world_pos, step_duration)
		await tween.finished
	
	# 到達最終目的地後，精準定格在第 0 幀
	force_idle_frame(npc, last_dir_str)

# ------------------------------------------------------------------------------
# 7. 自動化劇情展示序列 (Automated Demo Sequence with A*)
# ------------------------------------------------------------------------------

func start_mvp_demo_sequence() -> void:
	if _is_npc_a_busy:
		return
	_is_npc_a_busy = true
	print("[MVP] 開始執行 A* 尋路社交展示序列...")

	# --- 【第一幕】A 透過 A* 尋路走向 B ---
	print("【第一幕】A 透過 A* 尋路走向 B")
	if _time_hud: _time_hud.set_npc_status("第一幕: A 尋路拜訪 B")
	var a_cur_cell: Vector2i = _nav_manager.local_to_map(npc_a.global_position)
	var b_cur_cell: Vector2i = _nav_manager.local_to_map(npc_b.global_position)
	# 站在 B 的左側相鄰格
	var target_cell_b: Vector2i = b_cur_cell + Vector2i(-1, 0)
	if not _nav_manager.is_cell_walkable(target_cell_b):
		target_cell_b = _nav_manager.get_closest_walkable_cell(b_cur_cell)
		
	var path_a_to_b: Array[Vector2i] = _nav_manager.get_id_path(a_cur_cell, target_cell_b)
	move_camera_to((npc_a.global_position + npc_b.global_position) / 2.0, 1.2)
	await move_npc_along_grid_path(npc_a, path_a_to_b, 0.2)

	# --- 【第二幕】A 與 B 面對面對話 ---
	print("【第二幕】A 與 B 對話 (定格第一幀)")
	if _time_hud: _time_hud.set_npc_status("第二幕: A 與 B 對話中")
	setup_face_to_face(npc_a, npc_b)
	await play_dialogue(npc_a, npc_b, 2.0)

	# --- 【第三幕】A 尋路回原位，B 尋路走向 C ---
	print("【第三幕】A 回原位，同時 B 走向 C")
	if _time_hud: _time_hud.set_npc_status("第三幕: A 返航 / B 尋路訪 C")
	var c_cur_cell: Vector2i = _nav_manager.local_to_map(npc_c.global_position)
	var target_cell_c: Vector2i = c_cur_cell + Vector2i(-1, 0)
	if not _nav_manager.is_cell_walkable(target_cell_c):
		target_cell_c = _nav_manager.get_closest_walkable_cell(c_cur_cell)

	var b_now_cell: Vector2i = _nav_manager.local_to_map(npc_b.global_position)
	var path_b_to_c: Array[Vector2i] = _nav_manager.get_id_path(b_now_cell, target_cell_c)
	var path_a_home: Array[Vector2i] = _nav_manager.get_id_path(_nav_manager.local_to_map(npc_a.global_position), _npc_a_start_cell)

	move_camera_to((npc_b.global_position + npc_c.global_position) / 2.0, 1.2)
	
	# 並行移動 A 與 B
	move_npc_along_grid_path(npc_a, path_a_home, 0.2)
	await move_npc_along_grid_path(npc_b, path_b_to_c, 0.2)

	# --- 【第四幕】B 與 C 面對面對話 ---
	print("【第四幕】B 與 C 對話")
	if _time_hud: _time_hud.set_npc_status("第四幕: B 與 C 交流對話")
	setup_face_to_face(npc_b, npc_c)
	await play_dialogue(npc_b, npc_c, 2.0)

	# --- 【第五幕】B 尋路回原位 ---
	print("【第五幕】B 回原位")
	if _time_hud: _time_hud.set_npc_status("第五幕: B 尋路返航")
	var b_back_cell: Vector2i = _nav_manager.local_to_map(npc_b.global_position)
	var path_b_home: Array[Vector2i] = _nav_manager.get_id_path(b_back_cell, _npc_b_start_cell)
	move_camera_to(npc_b.global_position - Vector2(60, 0), 1.0)
	await move_npc_along_grid_path(npc_b, path_b_home, 0.2)

	print("[MVP] 演示序列完成！NPC 已全數就位。您現在可以自由用【滑鼠左鍵點擊】測試 NPC_1 尋路！")
	if _time_hud: _time_hud.set_npc_status("待機中 (可點擊地面尋路)")
	_is_npc_a_busy = false

# ------------------------------------------------------------------------------
# 8. 動畫定格與視線工具 (Animation Utilities)
# ------------------------------------------------------------------------------

func setup_face_to_face(actor1: CharacterBody2D, actor2: CharacterBody2D) -> void:
	var dir1: Vector2 = (actor2.global_position - actor1.global_position).normalized()
	var dir2: Vector2 = (actor1.global_position - actor2.global_position).normalized()
	force_idle_frame(actor1, get_direction_string(dir1))
	force_idle_frame(actor2, get_direction_string(dir2))

func force_idle_frame(npc: CharacterBody2D, direction_str: String) -> void:
	var sprite: AnimatedSprite2D = npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	var target_anim: String = "idle_" + direction_str
	if sprite.sprite_frames.has_animation(target_anim):
		sprite.play(target_anim)
		sprite.pause()
		sprite.frame = 0
	else:
		# 若無 idle 則使用 walk 的第 0 幀定格
		var fallback_anim: String = "walk_" + direction_str
		if sprite.sprite_frames.has_animation(fallback_anim):
			sprite.play(fallback_anim)
			sprite.pause()
			sprite.frame = 0

func get_direction_string(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func play_dialogue(actor1: Node2D, actor2: Node2D, duration: float) -> void:
	var bubble1: Node2D = actor1.get_node_or_null("bubble") as Node2D
	var bubble2: Node2D = actor2.get_node_or_null("bubble") as Node2D

	if bubble1: bubble1.visible = true
	if bubble2: bubble2.visible = true

	await get_tree().create_timer(duration).timeout

	if bubble1: bubble1.visible = false
	if bubble2: bubble2.visible = false

func move_camera_to(target_pos: Vector2, duration: float) -> void:
	if demo_camera == null:
		return
	if demo_camera is GameCameraClass:
		demo_camera.move_to(target_pos, duration)
	else:
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(demo_camera, "global_position", target_pos, duration)