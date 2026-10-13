# ==============================================================================
# 26號宇宙 (Universe 26) - 網格導航管理器 (Navigation Manager)
# 檔案路徑: res://scripts/core/navigation_manager.gd
# 職責描述: 封裝 Godot 4 原生 AStarGrid2D，自動讀取多層 TileMapLayer，管理網格尋路與阻擋
# ==============================================================================
class_name NavigationManager
extends Node2D

# ------------------------------------------------------------------------------
# 1. 訊號 (Signals)
# ------------------------------------------------------------------------------

## 當 A* 網格初始化完成時發射 (總格數, 可通行格數)
signal grid_initialized(total_cells: int, walkable_cells: int)

## 成功計算路徑時發射
signal path_calculated(from_cell: Vector2i, to_cell: Vector2i, path: Array[Vector2i])

# ------------------------------------------------------------------------------
# 2. 屬性與匯出設定 (Properties & Exports)
# ------------------------------------------------------------------------------

## 地面層 TileMapLayer (用於取得地圖範圍與基本可行走區域)
@export var ground_layer: TileMapLayer

## 障礙層 TileMapLayer (用於標記實心不可通行的建築/樹木/岩石)
@export var obstacle_layer: TileMapLayer

## 尋路權重計算模式
enum WeightStrategy {
	ROAD_PREFERRED, ## 優先走道路 (白名單模式：在 road_atlas_coords 中的地塊權重為 1.0，其餘為 offroad_weight)
	AVOID_GRASS ## 避開草地 (黑名單模式：在 grass_atlas_coords 中的地塊權重為 offroad_weight，其餘地塊皆為 1.0)
}

## 是否允許斜向移動 (預設 false: 僅上下左右 4 向，避免穿牆與斜向穿插)
@export var allow_diagonals: bool = false

## 尋路加權策略 (可在編輯器 Inspector 中一鍵切換)
@export var weight_strategy: WeightStrategy = WeightStrategy.ROAD_PREFERRED

## 道路/非草地通行權重 (預設 1.0，值越小越優先行走)
@export var road_weight: float = 1.0

## 草地/非道路通行權重 (預設 3.0，使 A* 尋路大幅偏好走在道路上)
@export var offroad_weight: float = 3.0

## 定義為道路或鋪設地磚之圖塊 Atlas 座標清單 (白名單模式使用)
@export var road_atlas_coords: Array[Vector2i] = [
	Vector2i(7, 5), # 主道路
	Vector2i(1, 54), # 石板路 (廣場核心地磚)
	Vector2i(4, 39), # 木棧道 (釣魚場碼頭)
	# 石板路/廣場外圍九宮格收邊地磚
	Vector2i(0, 53), Vector2i(1, 53), Vector2i(2, 53),
	Vector2i(0, 54),                 Vector2i(2, 54),
	Vector2i(0, 55), Vector2i(1, 55), Vector2i(2, 55),
	# 廣場中心特色地磚
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
]

## 定義為草地之圖塊 Atlas 座標清單 (黑名單模式使用，加重通行代價避免亂走草地)
@export var grass_atlas_coords: Array[Vector2i] = [
	Vector2i(1, 4), # 一般草地主體
	Vector2i(5, 0), # 帶花草地裝飾 1
	Vector2i(5, 1), # 帶花草地裝飾 2
	Vector2i(5, 2), # 帶花草地裝飾 3
	Vector2i(6, 2)  # 帶花草地裝飾 4
]

## 內部 AStarGrid2D 實例
var astar: AStarGrid2D = null

## 地圖邊界矩形 (網格座標)
var map_rect: Rect2i = Rect2i()

## 單一地塊像素尺寸 (預設 16x16)
var tile_size: Vector2i = Vector2i(16, 16)

## 可通行網格快取陣列 (便於隨機漫遊抽樣)
var _walkable_cells: Array[Vector2i] = []

# ------------------------------------------------------------------------------
# 3. 生命週期 (Lifecycle)
# ------------------------------------------------------------------------------

func _ready() -> void:
	_auto_detect_layers()
	initialize_grid()
	
	# 向全域單例註冊自身
	if Engine.has_singleton("Global") or get_node_or_null("/root/Global"):
		var global_node: Node = get_node("/root/Global")
		if global_node.has_method("register_navigation_manager"):
			global_node.register_navigation_manager(self)

func _exit_tree() -> void:
	if get_node_or_null("/root/Global"):
		var global_node: Node = get_node("/root/Global")
		if global_node.has_method("unregister_navigation_manager"):
			global_node.unregister_navigation_manager()

# ------------------------------------------------------------------------------
# 4. 初始化與地圖解析 (Initialization & Map Parsing)
# ------------------------------------------------------------------------------

## 自動偵測圖層 (若 Inspector 未手動拖曳，自動在相鄰或子節點搜尋)
func _auto_detect_layers() -> void:
	if ground_layer == null:
		ground_layer = get_node_or_null("GroundLayer") as TileMapLayer
	if ground_layer == null and get_parent() != null:
		ground_layer = get_parent().find_child("GroundLayer", true, false) as TileMapLayer
		
	if obstacle_layer == null:
		obstacle_layer = get_node_or_null("ObstacleLayer") as TileMapLayer
	if obstacle_layer == null and get_parent() != null:
		obstacle_layer = get_parent().find_child("ObstacleLayer", true, false) as TileMapLayer

## 初始化 AStarGrid2D 網格路網
func initialize_grid() -> void:
	if ground_layer == null:
		push_error("[NavigationManager] 初始化失敗: 找不到 GroundLayer！")
		return

	# 取得地面圖層尺寸與範圍
	if ground_layer.tile_set:
		tile_size = ground_layer.tile_set.tile_size
	map_rect = ground_layer.get_used_rect()
	
	if map_rect.size.x <= 0 or map_rect.size.y <= 0:
		push_warning("[NavigationManager] GroundLayer 沒有任何已放置的瓦片！")
		return

	# 建立並配置 AStarGrid2D
	astar = AStarGrid2D.new()
	astar.region = map_rect
	astar.cell_size = Vector2(tile_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE if allow_diagonals else AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

	# 先將全域區域全部預設封閉 (不可通行)，避免走到地圖外圍空隙
	astar.fill_solid_region(map_rect, true)
	_walkable_cells.clear()

	# 1. 掃描 GroundLayer：將有鋪設地面之地塊設為「可通行」
	var ground_cells: Array[Vector2i] = ground_layer.get_used_cells()
	var ground_has_custom: bool = ground_layer.tile_set and ground_layer.tile_set.get_custom_data_layers_count() > 0
	
	for cell: Vector2i in ground_cells:
		var is_solid: bool = false
		var atlas_coords: Vector2i = ground_layer.get_cell_atlas_coords(cell)
		
		# 依據所選策略決定基礎通行權重
		var walk_weight: float = road_weight
		match weight_strategy:
			WeightStrategy.ROAD_PREFERRED:
				var is_road: bool = atlas_coords in road_atlas_coords
				walk_weight = road_weight if is_road else offroad_weight
			WeightStrategy.AVOID_GRASS:
				var is_grass: bool = atlas_coords in grass_atlas_coords
				walk_weight = offroad_weight if is_grass else road_weight

		if ground_has_custom:
			var tile_data: TileData = ground_layer.get_cell_tile_data(cell)
			if tile_data:
				var custom_solid: Variant = tile_data.get_custom_data("is_solid")
				if custom_solid != null and bool(custom_solid):
					is_solid = true
				var custom_weight: Variant = tile_data.get_custom_data("walk_weight")
				if custom_weight != null and float(custom_weight) > 0.0:
					walk_weight = float(custom_weight)

		if not is_solid:
			astar.set_point_solid(cell, false)
			astar.set_point_weight_scale(cell, walk_weight)

	# 2. 掃描 ObstacleLayer：將障礙物圖層中的地塊強制設為「不可通行」
	if obstacle_layer:
		var obstacle_cells: Array[Vector2i] = obstacle_layer.get_used_cells()
		var obs_has_custom: bool = obstacle_layer.tile_set and obstacle_layer.tile_set.get_custom_data_layers_count() > 0

		for cell: Vector2i in obstacle_cells:
			if not astar.is_in_boundsv(cell):
				continue
			var mark_as_obstacle: bool = true
			if obs_has_custom:
				var tile_data: TileData = obstacle_layer.get_cell_tile_data(cell)
				if tile_data:
					var custom_solid: Variant = tile_data.get_custom_data("is_solid")
					if custom_solid != null and not bool(custom_solid):
						mark_as_obstacle = false
			if mark_as_obstacle:
				astar.set_point_solid(cell, true)

	# 3. 快取所有實際可通行的地塊清單
	for cell: Vector2i in ground_cells:
		if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
			_walkable_cells.append(cell)

	var total_cells: int = map_rect.size.x * map_rect.size.y
	var walkable_count: int = _walkable_cells.size()
	print("[NavigationManager] A* 網格初始化成功！總範圍: %s, 總格數: %d, 可通行格數: %d" % [str(map_rect), total_cells, walkable_count])
	grid_initialized.emit(total_cells, walkable_count)

# ------------------------------------------------------------------------------
# 5. 尋路與路徑查詢 API (Pathfinding Queries)
# ------------------------------------------------------------------------------

## 取得兩個網格座標之間的路徑 (Array[Vector2i])
func get_id_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if astar == null:
		push_error("[NavigationManager] 尋路失敗: A* 尚未初始化！")
		return []

	# 起點防呆
	if not astar.is_in_boundsv(from_cell):
		return []
		
	# 若終點在邊界外或本身是障礙物，尋找距離目標最近的可通行相鄰格
	var target: Vector2i = to_cell
	if not is_cell_walkable(target):
		target = get_closest_walkable_cell(target)
		if target == Vector2i(-1, -1):
			return []

	# 若起點是障礙物，嘗試移至最近可走格
	var start: Vector2i = from_cell
	if not is_cell_walkable(start):
		start = get_closest_walkable_cell(start)
		if start == Vector2i(-1, -1):
			return []

	var path: Array[Vector2i] = astar.get_id_path(start, target)
	path_calculated.emit(from_cell, to_cell, path)
	return path

## 取得世界像素座標路徑 (PackedVector2Array)，每個座標點均對齊地塊中心
func get_point_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var from_cell: Vector2i = local_to_map(from_pos)
	var to_cell: Vector2i = local_to_map(to_pos)
	var id_path: Array[Vector2i] = get_id_path(from_cell, to_cell)
	
	var world_path: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in id_path:
		world_path.append(map_to_local(cell))
	return world_path

## 檢查指定網格是否在地圖內且可通行
func is_cell_walkable(cell: Vector2i) -> bool:
	if astar == null or not astar.is_in_boundsv(cell):
		return false
	return not astar.is_point_solid(cell)

## 將網格座標轉換為地圖本地/世界像素座標 (地塊中心點)
func map_to_local(cell: Vector2i) -> Vector2:
	if ground_layer:
		return ground_layer.to_global(ground_layer.map_to_local(cell))
	return to_global(Vector2(cell.x * tile_size.x + tile_size.x * 0.5, cell.y * tile_size.y + tile_size.y * 0.5))

## 將世界像素座標轉換為網格座標
func local_to_map(pos: Vector2) -> Vector2i:
	if ground_layer:
		return ground_layer.local_to_map(ground_layer.to_local(pos))
	var local_pos: Vector2 = to_local(pos)
	return Vector2i(floor(local_pos.x / tile_size.x), floor(local_pos.y / tile_size.y))

## 取得某網格周遭最近的可通行地塊 (若目標為障礙物時非常實用)
func get_closest_walkable_cell(target_cell: Vector2i, max_radius: int = 4) -> Vector2i:
	if is_cell_walkable(target_cell):
		return target_cell
		
	for r: int in range(1, max_radius + 1):
		# 四向優先搜尋
		var neighbors: Array[Vector2i] = [
			target_cell + Vector2i(0, -r),
			target_cell + Vector2i(0, r),
			target_cell + Vector2i(-r, 0),
			target_cell + Vector2i(r, 0),
			target_cell + Vector2i(-r, -r),
			target_cell + Vector2i(r, -r),
			target_cell + Vector2i(-r, r),
			target_cell + Vector2i(r, r)
		]
		for n: Vector2i in neighbors:
			if is_cell_walkable(n):
				return n
	return Vector2i(-1, -1)

## 取得目標中心周圍半徑內的隨機可通行網格 (供 NPC 隨機漫遊)
func get_random_walkable_neighbor(center_cell: Vector2i, radius: int = 4) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			if is_cell_walkable(cell):
				candidates.append(cell)
	
	if candidates.is_empty():
		return center_cell
	return candidates[randi() % candidates.size()]

## 從全圖隨機抽取一個可通行的網格
func get_random_walkable_cell() -> Vector2i:
	if _walkable_cells.is_empty():
		return Vector2i.ZERO
	return _walkable_cells[randi() % _walkable_cells.size()]

## 檢查指定網格是否屬於道路/低通行代價地塊
func is_road_cell(cell: Vector2i) -> bool:
	if ground_layer == null:
		return false
	var atlas_coords: Vector2i = ground_layer.get_cell_atlas_coords(cell)
	match weight_strategy:
		WeightStrategy.ROAD_PREFERRED:
			return atlas_coords in road_atlas_coords
		WeightStrategy.AVOID_GRASS:
			return not (atlas_coords in grass_atlas_coords)
	return false

## 取得指定網格地塊的尋路權重
func get_cell_weight(cell: Vector2i) -> float:
	if astar == null or not astar.is_in_boundsv(cell):
		return 0.0
	return astar.get_point_weight_scale(cell)

## 動態設定指定網格地塊的尋路權重
func set_cell_weight(cell: Vector2i, weight: float) -> void:
	if astar and astar.is_in_boundsv(cell):
		astar.set_point_weight_scale(cell, weight)
