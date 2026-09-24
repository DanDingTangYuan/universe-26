# 26號宇宙 (Universe 26) - API 參考手冊 (API Reference)

本文件依據 [`AGENTS.md`](./AGENTS.md) 規範編寫，所有跨腳本呼叫、全域介面、對外訊號與資料結構異動時必須同步更新此手冊。

---

## 目錄

- [1. 全域單例：Global (scripts/core/global.gd)](#1-全域單例global-scriptscoreglobalgd)
  - [1.1 列舉與常數](#11-列舉與常數)
  - [1.2 全域訊號 (Event Bus)](#12-全域訊號-event-bus)
  - [1.3 時間系統 API](#13-時間系統-api)
  - [1.4 導航服務定位器 API](#14-導航服務定位器-api)
  - [1.5 NPC 註冊與查詢 API](#15-npc-註冊與查詢-api)
  - [1.6 POI / 設施註冊 API](#16-poi--設施註冊-api)
  - [1.7 工具輔助 API](#17-工具輔助-api)
- [2. 導航管理器：NavigationManager (scripts/core/navigation_manager.gd)](#2-導航管理器navigationmanager-scriptscorenavigation_managergd)
  - [2.1 訊號](#21-訊號)
  - [2.2 核心方法](#22-核心方法)
- [3. 頂部時間 HUD：TimeHUD (scene/ui/time_hud.tscn, scripts/ui/time_hud.gd)](#3-頂部時間-hudtimehud-sceneuitime_hudtscn-scriptsuitime_hudgd)
  - [3.1 職責與結構](#31-職責與結構)
  - [3.2 公開方法與回呼](#32-公開方法與回呼)
- [4. 遊戲攝影機：GameCamera (scene/camera/game_camera.tscn, scripts/camera/game_camera.gd)](#4-遊戲攝影機gamecamera-scenecameragame_cameratscn-scriptscameragame_cameragd)
  - [4.1 職責與特性](#41-職責與特性)
  - [4.2 匯出參數 (Exports)](#42-匯出參數-exports)
  - [4.3 訊號 (Signals)](#43-訊號-signals)
  - [4.4 公開方法 (Public Methods)](#44-公開方法-public-methods)
- [5. AI 決策大腦服務：NPCDecisionService (scripts/ai/decision_service.gd)](#5-ai-決策大腦服務npcdecisionservice-scriptsaidecision_servicegd)
  - [5.1 職責與特性](#51-職責與特性)
  - [5.2 核心常數與排程表](#52-核心常數與排程表)
  - [5.3 公開方法 (Public Methods)](#53-公開方法-public-methods)

---

## 1. 全域單例：Global (`scripts/core/global.gd`)

作為專案唯一的核心 AutoLoad 單例，提供全域時間推進、事件匯流排、服務定位與實體註冊。

### 1.1 列舉與常數

#### 常數

| 常數名稱                   | 型別            | 預設值           | 說明                                                  |
| :------------------------- | :-------------- | :--------------- | :---------------------------------------------------- |
| `TICKS_PER_DAY`            | `int`           | `1440`           | 每日總 Tick 數 (24 小時 × 60 分鐘)                    |
| `TICKS_PER_HOUR`           | `int`           | `60`             | 每小時的 Tick 數                                      |
| `DEFAULT_SECONDS_PER_TICK` | `float`         | `0.5`            | 預設每 Tick 所需真實秒數 (1 遊戲日 = 12 分鐘)         |
| `ACTION_NAMES`             | `Array[String]` | 9 種行為名稱陣列 | 索引對齊 `ActionType` 及 C# `NPCDecision.ActionNames` |

#### `ActionType` (行為類型列舉)

```gdscript
enum ActionType {
    WANDER = 0,   # 閒逛
    READ = 1,     # 閱讀
    SHOP = 2,     # 購物
    EAT = 3,      # 吃東西
    MEDICAL = 4,  # 就醫
    REST = 5,     # 回家休息
    SOCIAL = 6,   # 社交
    PATROL = 7,   # 巡田水
    SELL = 8      # 販售物品
}
```

#### `LocationType` (地圖設施 / POI 類型列舉)

```gdscript
enum LocationType {
    NONE = 0,        # 無 / 原地
    MARKET = 12,     # 市場 (販售物品)
    RESTAURANT = 13, # 餐廳 (吃東西 / 購物)
    FARM = 16,       # 農田 (巡田水)
    HOSPITAL = 18,   # 醫院 (就醫)
    LIBRARY = 19,    # 圖書館 (閱讀)
    PLAZA = 20,      # 社交廣場 (社交 / 閒逛)
    HOME = 21        # 自宅 (回家休息)
}
```

---

### 1.2 全域訊號 (Event Bus)

| 訊號名稱               | 參數清單                                                    | 觸發時機與用途                                         |
| :--------------------- | :---------------------------------------------------------- | :----------------------------------------------------- |
| `tick_passed`          | `current_tick: int`                                         | 每個遊戲 Tick (分鐘) 前進時觸發                        |
| `hour_passed`          | `current_hour: int`                                         | 每個遊戲整點 (每 60 Ticks) 抵達時觸發                  |
| `day_passed`           | `current_day: int`                                          | 進入新的一天時觸發                                     |
| `on_midnight_reached`  | `day_count: int`                                            | 每日午夜 (00:00 / Tick 0) 抵達時觸發，驅動 C# 記憶演化 |
| `time_scale_changed`   | `new_scale: float`                                          | 時間流速倍率調整時觸發                                 |
| `time_paused_toggled`  | `is_paused: bool`                                           | 時間暫停狀態切換時觸發                                 |
| `npc_registered`       | `npc_id: String, npc_node: Node2D`                          | 有新 NPC 註冊進系統時觸發                              |
| `npc_unregistered`     | `npc_id: String`                                            | NPC 註銷時觸發                                         |
| `poi_registered`       | `poi_id: int, cell_pos: Vector2i`                           | 新增地圖設施座標時觸發                                 |
| `npc_action_started`   | `npc_id: String, action: ActionType, target_cell: Vector2i` | NPC 開始執行某行動時廣播 (供 UI 或監控)                |
| `npc_action_completed` | `npc_id: String, action: ActionType`                        | NPC 完成行動時廣播                                     |

---

### 1.3 時間系統 API

#### `get_normalized_time() -> float`

- **說明**：回傳當前時間正規化浮點數 $[0.0, 1.0)$，計算公式為 `float(current_tick) / float(TICKS_PER_DAY)`。
- **用途**：作為神經網路輸入的時間維度特徵。

#### `get_current_hour() -> int`

- **說明**：取得當前遊戲小時（`0 ~ 23`）。

#### `get_current_minute() -> int`

- **說明**：取得當前遊戲分鐘（`0 ~ 59`）。

#### `get_formatted_time() -> String`

- **說明**：取得格式化時間字串，如 `"08:05"`、`"23:59"`。

#### `set_time_scale(scale: float) -> void`

- **說明**：設定時間倍速，負數會被防呆截斷為 `0.0`。

#### `set_time_paused(paused: bool) -> void`

- **說明**：設定是否暫停時間推進。

#### `toggle_time_paused() -> void`

- **說明**：切換時間暫停狀態。

#### `debug_fast_forward_ticks(ticks: int) -> void`

- **說明**：快速推進指定的 Tick 數（除錯與測試用）。

---

### 1.4 導航服務定位器 API

#### `register_navigation_manager(nav: Node) -> void`

- **說明**：地圖上的導航管理器加載完成後向 Global 註冊自身。

#### `unregister_navigation_manager() -> void`

- **說明**：地圖卸載或切換時註銷。

#### `get_navigation_manager() -> Node`

- **說明**：任意實體（如 NPC）獲取當前導航管理器的公開介面。

#### `has_navigation_manager() -> bool`

- **說明**：檢查目前是否已註冊可用的導航管理器。

---

### 1.5 NPC 註冊與查詢 API

#### `register_npc(npc_id: String, npc_node: Node2D) -> void`

- **說明**：將 NPC 實體註冊至全域字典，以便其他系統或 NPC 尋找對象。

#### `unregister_npc(npc_id: String) -> void`

- **說明**：將 NPC 從全域字典移除。

#### `get_npc(npc_id: String) -> Node2D`

- **說明**：依據 ID 查詢 NPC 實體節點；若節點已失效則自動清理並回傳 `null`。

#### `get_all_npcs() -> Array[Node2D]`

- **說明**：取得所有當前在場上的有效 NPC 陣列。

#### `has_npc(npc_id: String) -> bool`

- **說明**：確認特定 ID 的 NPC 是否已在場上存在。

---

### 1.6 POI / 設施註冊 API

#### `register_poi(poi_id: int, cell_pos: Vector2i) -> void`

- **說明**：註冊設施類型與網格座標（例如 `register_poi(Global.LocationType.RESTAURANT, Vector2i(10, 15))`）。

#### `get_poi_cell(poi_id: int) -> Vector2i`

- **說明**：取得特定設施的網格座標。若不存在則回傳 `Vector2i(-1, -1)`。

#### `has_poi(poi_id: int) -> bool`

- **說明**：檢查是否已註冊該設施。

#### `get_all_pois() -> Dictionary`

- **說明**：取得所有已註冊設施的字典副本。

---

### 1.7 工具輔助 API

#### `get_action_name(action_id: int) -> String`

- **說明**：將數值或 `ActionType` 轉換為易讀的中文名稱字串（如 `0` -> `"閒逛"`）。

#### `get_decision_service() -> NPCDecisionService`

- **說明**：取得全域單例化的 AI 決策大腦服務實例（延遲載入神經網路權重），供所有 NPC 共享。

---

## 2. 導航管理器：NavigationManager (`scripts/core/navigation_manager.gd`)

封裝 Godot 4 原生 `AStarGrid2D`，自動讀取多層 `TileMapLayer`，管理網格尋路與阻擋。

### 2.1 訊號

| 訊號名稱           | 參數清單                                                        | 觸發時機與用途                                   |
| :----------------- | :-------------------------------------------------------------- | :----------------------------------------------- |
| `grid_initialized` | `total_cells: int, walkable_cells: int`                         | A\* 網格初始化完成時發射，回報總格數與可行走格數 |
| `path_calculated`  | `from_cell: Vector2i, to_cell: Vector2i, path: Array[Vector2i]` | 成功計算兩點間網格路徑時發射                     |

### 2.2 核心方法

#### `initialize_grid() -> void`

- **說明**：手動或自動重新掃描 `ground_layer` 與 `obstacle_layer`，重建 `AStarGrid2D` 尋路網格。
- **自訂屬性支援**：
  - `is_solid` (bool)：設為 `true` 則該地塊不可通行。
  - `walk_weight` (float)：設定通行代價權重。

#### `get_id_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]`

- **說明**：計算從起點網格到終點網格的路徑陣列。
- **容錯特性**：若起點或終點為障礙物，會自動尋找距離最近的可通行相鄰格進行路徑規劃。

#### `get_point_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array`

- **說明**：計算世界像素座標路徑，陣列中每個點皆對齊地塊中心。

#### `is_cell_walkable(cell: Vector2i) -> bool`

- **說明**：檢查指定網格是否位於地圖範圍內且可正常通行。

#### `map_to_local(cell: Vector2i) -> Vector2`

- **說明**：將網格座標轉換為地圖上的世界像素座標（地塊中心點）。

#### `local_to_map(pos: Vector2) -> Vector2i`

- **說明**：將世界像素座標轉換為對應的網格座標。

#### `get_closest_walkable_cell(target_cell: Vector2i, max_radius: int = 4) -> Vector2i`

- **說明**：以 `target_cell` 為中心向外環形搜尋最近的可通行網格（當目標為牆壁/樹木時獲取身旁站立點）。

#### `get_random_walkable_neighbor(center_cell: Vector2i, radius: int = 4) -> Vector2i`

- **說明**：在指定半徑內隨機挑選一個可通行的網格，用於 NPC 自主漫遊。

#### `get_random_walkable_cell() -> Vector2i`

- **說明**：從全地圖的所有可通行網格中隨機抽取一個。

---

## 3. 頂部時間 HUD：TimeHUD (`scene/ui/time_hud.tscn`, `scripts/ui/time_hud.gd`)

作為畫面頂部常駐的系統與時間控制 UI（CanvasLayer，Layer = 10），負責呈現遊戲狀態與提供玩家互動介面。

### 3.1 職責與結構

- **頂部狀態欄 (TopBar / PanelContainer)**：
  - **左側資訊 (LeftBox)**：
    - `DayLabel`：目前遊戲天數（如「第 1 天」）。
    - `PeriodLabel`：當前晝夜時段（清晨、上午、中午、下午、傍晚、夜晚、深夜）。
    - `ClockLabel`：24 小時制時間（如「08:30」）。
    - `TimeProgressBar`：當日時間進度條（`0.0 ~ 1.0`）。
  - **中央狀態 (CenterBox)**：
    - `NavStatusLabel`：A\* 導航路網狀態與可用格數。
    - `NpcStatusLabel`：當前焦點 NPC（如 NPC_1）之即時動作或尋路狀態。
  - **右側操作按鈕 (RightBox)**：
    - `PauseButton`：切換暫停 / 繼續（同步觸發 `Global.toggle_time_paused()`）。
    - `Speed1xButton`, `Speed2xButton`, `Speed4xButton`：切換時間倍率（`1.0x`, `2.0x`, `4.0x`），當前倍速會發光高亮標示。
    - `FFHourButton` (`+1h`)：快速推進 1 小時 (60 Ticks)。
    - `FFMidnightButton` (`🌙午夜`)：快速推進至下一個午夜，觸發 C# 記憶演化。

### 3.2 公開方法與回呼

#### `update_all_display() -> void`

- **說明**：強制即時刷新所有時間、導航狀態與按鈕高亮。

#### `set_npc_status(status_text: String) -> void`

- **說明**：設定中央顯示的 NPC 當前行為或狀態文字（如「尋路前往餐廳」、「待機中」）。

---

## 4. 遊戲攝影機：GameCamera (`scene/camera/game_camera.tscn`, `scripts/camera/game_camera.gd`)

繼承自 `Camera2D` 的獨立模組化相機節點，支援滑鼠中鍵即時拖曳平移、滾輪縮放、平滑導航追蹤與地圖邊界限制。

### 4.1 職責與特性

- **獨立封裝**：相機邏輯完全內聚於 `GameCamera`，不需依賴外部腳本驅動即可自主運作。
- **無縫拖曳**：在滑鼠中鍵按住拖曳時自動關閉 `position_smoothing_enabled`，確保 1:1 像素跟手感；放開時自動平滑回彈。
- **滾輪縮放**：支援平滑 Tween 縮放，具備最小/最大邊界限制防穿幫。
- **自動邊界綁定**：於 `_ready` 時自動向 `Global.get_navigation_manager()` 取得地圖大小與 Tile 像素，鎖定 `limit_left` / `limit_top` / `limit_right` / `limit_bottom`，防止相機移出地圖黑邊。

### 4.2 匯出參數 (Exports)

| 屬性名稱               | 型別    | 預設值 | 說明                                         |
| :--------------------- | :------ | :----- | :------------------------------------------- |
| `enable_pan`           | `bool`  | `true` | 是否啟用滑鼠中鍵拖曳平移                     |
| `enable_zoom`          | `bool`  | `true` | 是否啟用滑鼠滾輪縮放                         |
| `min_zoom`             | `float` | `0.5`  | 最小縮放倍率（廣角視野極限）                 |
| `max_zoom`             | `float` | `4.0`  | 最大縮放倍率（特寫視野極限）                 |
| `zoom_factor`          | `float` | `1.15` | 單次滾輪滾動縮放倍率變化量                   |
| `auto_bind_map_limits` | `bool`  | `true` | 是否自動取得導航地圖邊界並鎖定鏡頭可移動區域 |

### 4.3 訊號 (Signals)

| 訊號名稱        | 參數清單            | 觸發時機與用途                       |
| :-------------- | :------------------ | :----------------------------------- |
| `camera_moved`  | `new_pos: Vector2`  | 攝影機因拖曳或平移移動世界座標時發射 |
| `camera_zoomed` | `new_zoom: Vector2` | 攝影機縮放比例改變時發射             |

### 4.4 公開方法 (Public Methods)

#### `move_to(target_pos: Vector2, duration: float = 1.0) -> void`

- **說明**：使用 Quad 平滑緩動將相機視角過渡至指定的世界像素座標。
- **特性**：若當前正在手動拖曳則忽略；呼叫時會自動解除任何既有的跟隨目標。

#### `follow(target: Node2D) -> void`

- **說明**：設定相機在每一影格持續跟隨目標節點的世界位置（例如跟隨特定 NPC 行動）。
- **特性**：若使用者按下中鍵拖曳，跟隨狀態將自動中斷並轉由手動控制。

#### `stop_following() -> void`

- **說明**：主動解除對目標節點的跟隨狀態。

#### `zoom_by_factor(factor: float) -> void`

- **說明**：依倍率（如 `1.15` 或 `1.0 / 1.15`）平滑縮放相機，數值自動鉗制在 `[min_zoom, max_zoom]` 之間。

#### `set_camera_limits(rect: Rect2i, tile_size: Vector2i = Vector2i(16, 16)) -> void`

- **說明**：根據網格矩形範圍與單格尺寸手動設定相機的 `limit_left`、`limit_top`、`limit_right`、`limit_bottom`。

---

## 5. AI 決策大腦服務：NPCDecisionService (`scripts/ai/decision_service.gd`)

封裝 15 維度多層感知機（MLP）神經網路前向推論、日常作息規則（上班、12:00 午餐、23:00 就寢宵禁）、行動-地點映射與社交可行性過濾器。

### 5.1 職責與特性

- **純 GDScript 原生推論**：讀取 `res://ai_models/npc_weights.json`（由 ONNX 模型提取的 19,977 浮點權重與標準化數據），完全不依賴 C# / .NET / ONNX Runtime C++ DLL，單次推論僅需約 0.03 毫秒。
- **神經符號雙重決策 (Hybrid)**：
  - **規則層 (Rule-based)**：優先判斷關鍵作息（23:00 宵禁強行返家、12:00 午餐時間找食物或原地吃便當、上班時段依體力/健康判定出勤）。
  - **神經層 (Neural Model)**：無規則干預時，透過神經網路依據 15 維度生理狀態與個性詞條偏移量輸出 9 種行為分數（0.0 ~ 1.0）。
- **社交過濾 (Social Filter)**：依據企劃規格，自動過濾處於工作、就醫、閱讀、在家休息等不適合社交狀態的 NPC。

### 5.2 核心常數與排程表

#### 行為對照 (`ACTION_NAMES`)

- `0`: 閒逛 (WANDER)
- `1`: 閱讀 (READ) -> 圖書館 (POI 19)
- `2`: 購物 (SHOP) -> 餐廳 (POI 13) / 商店 (POI 12)
- `3`: 吃東西 (EAT) -> 身上有食物/便當時原地吃 (POI 0)，否則前往餐廳 (POI 13)
- `4`: 就醫 (MEDICAL) -> 醫院 (POI 18)
- `5`: 回家休息 (REST) -> 自宅 (POI 1~11)
- `6`: 社交 (SOCIAL) -> 社交廣場 (POI 20)
- `7`: 巡田水 (PATROL) -> 農田 (POI 16)
- `8`: 販售物品 (SELL) -> 商店 (POI 12)

#### 職業作息表 (`JOB_SCHEDULES`)

- 1 礦工：08:00 ~ 17:00 (POI 15 礦場)
- 2 圖書管理員：09:00 ~ 20:00 (POI 19 圖書館)
- 3 漁夫：07:00 ~ 09:00 (POI 17 釣魚場)
- 4 餐廳員工：午班 11:00 ~ 13:00、晚班 18:00 ~ 21:00 (POI 13 餐廳)
- 5 醫護人員：07:00 ~ 22:00 (POI 18 醫院)
- 6 伐木工：09:00 ~ 17:00 (POI 14 伐木場)
- 7 農民：07:00 ~ 12:00 (POI 16 農田)
- 8 商店店長：08:00 ~ 20:00 (POI 12 商店)
- 9 家庭主夫/婦：彈性

### 5.3 公開方法 (Public Methods)

#### `load_model(path: String = WEIGHTS_PATH) -> bool`

- **說明**：加載神經網路權重與標準化數據，解析為內部矩陣結構。

#### `forward(stats: PackedFloat32Array, personality_offset: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array`

- **說明**：純神經網路推論。輸入 15 維度原始生理/經濟數據與可選的性格詞條偏移量，回傳長度為 9 的行為機率陣列（數值範圍 0.0 ~ 1.0，小於 0.0005 歸零）。

#### `evaluate_decision(...) -> Dictionary`

- **函式簽章**：
  ```gdscript
  func evaluate_decision(
      current_tick: int,
      stats: PackedFloat32Array,
      home_id: int,
      job_id: int,
      food_count: int,
      lunchbox_count: int,
      personality_offset: PackedFloat32Array = PackedFloat32Array()
  ) -> Dictionary
  ```
- **回傳字典格式**：
  ```gdscript
  {
      "best_action": int,          # 0 ~ 8
      "best_action_name": String,  # 行為名稱 (如 "吃東西")
      "target_location": int,      # 目標地點 POI 代碼 (0 ~ 21)
      "scores": PackedFloat32Array,# 9 個行為的機率 (若為規則強制則為空)
      "is_rule_override": bool,    # 是否觸發作息規則覆蓋
      "override_reason": String    # 覆蓋原因 (如 "就寢時間，強制返家休息")
  }
  ```

#### `get_location_by_action(action_index: int, food_count: int, lunchbox_count: int, home_id: int, job_id: int) -> int`

- **說明**：依據行為代碼與當前攜帶物資，計算出對應的目的地 POI ID。

#### `is_available_for_social(current_action: int, is_at_home: bool = false) -> bool`

- **說明**：判斷該 NPC 當前是否處於可進行社交互動的狀態（若正在工作、就醫、閱讀、在家休息則回傳 `false`）。
