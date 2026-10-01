# ==============================================================================
# 26號宇宙 (Universe 26) - NPC 生成器與工廠 (NPC Spawner & Factory)
# 檔案路徑: res://scripts/entities/npc_spawner.gd
# 職責描述: 讀取 NPC 模板與 POI 座標配置，動態實例化 NPC 實體、換皮與資料注入
# ==============================================================================
class_name NPCSpawner
extends Node2D

const NavigationManagerClass = preload("res://scripts/core/navigation_manager.gd")
const NPCScene = preload("res://scene/NPCs/npc_1.tscn")
const NPCControllerClass = preload("res://scripts/entities/npc_controller.gd")
const NPCDataClass = preload("res://scripts/entities/npc_data.gd")

const TEMPLATES_PATH: String = "res://data/npc_templates.json"
const POIS_PATH: String = "res://data/poi_locations.json"

# ------------------------------------------------------------------------------
# 1. 匯出參數 (Exports)
# ------------------------------------------------------------------------------

## 遊戲啟動時生成之 NPC 數量 (預設 3 隻供第一步除錯驗證，可調整至 20 隻)
@export_range(1, 20) var spawn_count: int = 3

## 是否在 _ready 時自動執行生成
@export var auto_spawn_on_ready: bool = true

# ------------------------------------------------------------------------------
# 2. 內部狀態 (Internal Variables)
# ------------------------------------------------------------------------------

var _templates: Array = []
var _spawned_npcs: Array[CharacterBody2D] = []

# ------------------------------------------------------------------------------
# 3. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	if auto_spawn_on_ready:
		# 稍作延遲確保 NavigationManager 與 TileMapLayer 完成掃描
		call_deferred("initialize_and_spawn")

# ------------------------------------------------------------------------------
# 4. 初始化與批量生成 (Initialization & Spawning)
# ------------------------------------------------------------------------------

## 初始化導航、POI 並依據設定生成指定數量之 NPC
func initialize_and_spawn() -> void:
	_ensure_navigation_manager()
	load_and_register_pois()
	load_templates()
	spawn_all()

## 確保導航管理器就緒且已註冊至 Global
func _ensure_navigation_manager() -> void:
	var global_node: Node = _get_global()
	if global_node and global_node.has_method("has_navigation_manager") and global_node.has_navigation_manager():
		return

	# 檢查場景中是否已有 NavigationManager 但尚未註冊
	var existing_nav: NavigationManager = null
	if get_parent() != null:
		existing_nav = get_parent().find_child("NavigationManager", true, false) as NavigationManager
	if existing_nav == null:
		var st: SceneTree = Engine.get_main_loop() as SceneTree
		if st and st.current_scene:
			existing_nav = st.current_scene.find_child("NavigationManager", true, false) as NavigationManager

	if existing_nav != null:
		if global_node and global_node.has_method("register_navigation_manager"):
			global_node.register_navigation_manager(existing_nav)
		print("[NPCSpawner] 找到現存 NavigationManager 並註冊至 Global。")
		return

	# 動態建立 NavigationManager 並自動解析地圖圖層
	print("[NPCSpawner] 場景中未發現 NavigationManager，自動動態建立並掛載...")
	var nav_instance: NavigationManager = NavigationManagerClass.new()
	nav_instance.name = "NavigationManager"
	if get_parent() != null:
		get_parent().add_child(nav_instance)
	else:
		add_child(nav_instance)

	# 確保其立即偵測圖層與初始化
	if nav_instance.astar == null:
		nav_instance.initialize_grid()
	if global_node and global_node.has_method("register_navigation_manager"):
		global_node.register_navigation_manager(nav_instance)

## 載入並註冊所有 POI 設施座標
func load_and_register_pois(path: String = POIS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("[NPCSpawner] 找不到 POI 配置檔案: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(json_text)
	if not data is Dictionary:
		return false

	var poi_list: Array = data.get("pois", [])
	var global_node: Node = _get_global()
	if global_node and global_node.has_method("register_poi"):
		for poi in poi_list:
			var id: int = int(poi.get("id", -1))
			var cell_arr: Array = poi.get("cell", [-1, -1])
			if cell_arr.size() >= 2 and id >= 0:
				global_node.register_poi(id, Vector2i(int(cell_arr[0]), int(cell_arr[1])))
		print("[NPCSpawner] 成功註冊 %d 個 POI 設施座標！" % poi_list.size())
		return true
	return false

## 載入 NPC 模板清單
func load_templates(path: String = TEMPLATES_PATH) -> bool:
	if not FileAccess.file_exists(path):
		printerr("[NPCSpawner] 找不到 NPC 模板檔案: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(json_text)
	if not data is Array:
		printerr("[NPCSpawner] NPC 模板格式錯誤，應為 Array！")
		return false

	_templates = data
	print("[NPCSpawner] 成功載入 %d 筆 NPC 模板！" % _templates.size())
	return true

## 依據 spawn_count 批量生成 NPC
func spawn_all() -> Array[CharacterBody2D]:
	_spawned_npcs.clear()
	var total_to_spawn: int = mini(spawn_count, _templates.size())
	for i in range(total_to_spawn):
		var t: Dictionary = _templates[i]
		var npc_node: CharacterBody2D = spawn_npc(t)
		if npc_node:
			_spawned_npcs.append(npc_node)

	print("[NPCSpawner] 批量生成完畢！共生成 %d 隻 NPC。" % _spawned_npcs.size())
	return _spawned_npcs

## 根據單一模板建立並配置 NPC 實體
func spawn_npc(template: Dictionary) -> CharacterBody2D:
	var npc: CharacterBody2D = NPCScene.instantiate() as CharacterBody2D
	if npc == null:
		printerr("[NPCSpawner] 無法實例化 npc_1.tscn")
		return null

	var npc_id: String = String(template.get("id", "npc_unknown"))
	var npc_name: String = String(template.get("name", "Unknown"))
	npc.name = "NPC_" + npc_name

	# 1. 確保控制器腳本掛載
	if not (npc is NPCControllerClass):
		npc.set_script(NPCControllerClass)

	# 2. 動態換皮 (SpriteFrames)
	var sprite_tex_path: String = String(template.get("sprite_texture", ""))
	if sprite_tex_path != "" and ResourceLoader.exists(sprite_tex_path):
		var tex: Texture2D = load(sprite_tex_path) as Texture2D
		var anim_sprite: AnimatedSprite2D = npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim_sprite and tex:
			anim_sprite.sprite_frames = create_sprite_frames_from_texture(tex)
			anim_sprite.animation = "walk_down"
			anim_sprite.pause()
			anim_sprite.frame = 0

	# 3. 建立並綁定個體 NPCData
	var data: NPCData = NPCDataClass.new()
	data.npc_id = npc_id
	data.npc_name = npc_name
	data.job_id = int(template.get("job_id", 1))
	data.home_poi_id = int(template.get("home_poi_id", 1))
	data.work_poi_id = int(template.get("work_poi_id", 12))

	# 載入初始數值
	var init_stats: Dictionary = template.get("initial_stats", {})
	data.hp = float(init_stats.get("hp", 100.0))
	data.health = float(init_stats.get("health", 100.0))
	data.stamina = float(init_stats.get("stamina", 100.0))
	data.hunger = float(init_stats.get("hunger", 80.0))
	data.social_desire = float(init_stats.get("social_desire", 60.0))
	data.mood = float(init_stats.get("mood", 80.0))
	data.money = int(init_stats.get("money", 100))
	data.wood = int(init_stats.get("wood", 0))
	data.stone = int(init_stats.get("stone", 0))
	data.mineral = int(init_stats.get("mineral", 0))
	data.crops = int(init_stats.get("crops", 0))
	data.fish = int(init_stats.get("fish", 0))
	data.food = int(init_stats.get("food", 0))
	data.lunchbox = int(init_stats.get("lunchbox", 0))

	# 綁定至控制器
	npc.npc_data = data

	# 4. 出生位置配置：預設出現在自宅門口
	var nav = _get_nav_manager()
	var global_node: Node = _get_global()
	var spawn_cell: Vector2i = Vector2i(20, 20) # 預設安全備用格
	if global_node and global_node.has_method("get_poi_cell"):
		var home_cell: Vector2i = global_node.get_poi_cell(data.home_poi_id)
		if home_cell != Vector2i(-1, -1):
			spawn_cell = home_cell

	# 5. 加入場景樹
	add_child(npc)

	# 6. 加入場景樹後設定 global_position，確保座標對齊網格中心
	if nav and nav.has_method("map_to_local"):
		npc.global_position = nav.map_to_local(spawn_cell)
	else:
		npc.global_position = Vector2(spawn_cell.x * 16 + 8, spawn_cell.y * 16 + 8)

	return npc

# ------------------------------------------------------------------------------
# 5. 動態切分 SpriteFrames 工具
# ------------------------------------------------------------------------------

## 從 4x4 16x32 人物貼圖動態組裝四方向步行動畫
static func create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var anim_names: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]
	var frame_w: int = 16
	var frame_h: int = 32

	for row: int in range(4):
		var anim_name: String = anim_names[row]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 5.0)
		sf.set_animation_loop(anim_name, true)
		for col: int in range(4):
			var atlas_tex: AtlasTexture = AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			sf.add_frame(anim_name, atlas_tex)

	return sf

# ------------------------------------------------------------------------------
# 6. 內部輔助 (Helpers)
# ------------------------------------------------------------------------------

func _get_global() -> Node:
	if Engine.has_singleton("Global"):
		return Engine.get_singleton("Global")
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st and st.root and st.root.has_node("Global"):
		return st.root.get_node("Global")
	return null

func _get_nav_manager():
	var g: Node = _get_global()
	if g and g.has_method("get_navigation_manager"):
		return g.get_navigation_manager()
	return null
