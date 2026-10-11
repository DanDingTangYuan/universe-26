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
- [6. NPC 數據模型：NPCData (scripts/entities/npc_data.gd)](#6-npc-數據模型npcdata-scriptsentitiesnpc_datagd)
  - [6.1 職責與架構](#61-職責與架構)
  - [6.2 15 維度神經特徵清單](#62-15-維度神經特徵清單)
  - [6.3 訊號 (Signals)](#63-訊號-signals)
  - [6.4 公開方法 (Public Methods)](#64-公開方法-public-methods)
- [7. NPC 控制器：NPCController (scripts/entities/npc_controller.gd)](#7-npc-控制器npccontroller-scriptsentitiesnpc_controllergd)
  - [7.1 職責與狀態機 (FSM)](#71-職責與狀態機-fsm)
  - [7.2 匯出參數 (Exports)](#72-匯出參數-exports)
  - [7.3 訊號 (Signals)](#73-訊號-signals)
  - [7.4 公開方法 (Public Methods)](#74-公開方法-public-methods)

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
| `npc_selected`         | `npc: Node2D`                                               | 玩家點選/選中某 NPC 時廣播 (供觀測 HUD 綁定)           |
| `npc_deselected`       | (無)                                                        | 取消選中 NPC 時廣播                                    |

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

#### `select_npc(npc: Node2D) -> void`

- **說明**：選中特定 NPC 實體，發射 `npc_selected(npc)` 全域訊號供觀測 HUD 進行追蹤顯示。

#### `deselect_npc() -> void`

- **說明**：取消當前選中的 NPC，發射 `npc_deselected()` 全域訊號關閉觀測視窗。

#### `get_selected_npc() -> Node2D`

- **說明**：取得目前被選中的 NPC 實體節點；若無選中或節點失效則回傳 `null`。

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

- **雙引擎無縫切換 (C# ONNX Runtime / GDScript Fallback)**：
  - **C# ONNX 引擎**（`ai_models/NPCDecisionBridge.cs`）：在 Godot Mono (.NET) 環境下，透過 `Microsoft.ML.OnnxRuntime` 直接讀取原生的 `res://ai_models/npc_decision_mlp.onnx`（一般決策模型）與 `res://ai_models/npc_interaction_mlp.onnx`（社交互動模型），進行硬體加速的高精度模型推論。
  - **GDScript 引擎**（`scripts/ai/decision_service.gd`）：在 Godot Standard（非 Mono）環境下，自動無縫降級使用原生 GDScript 矩陣運算，讀取 `res://ai_models/npc_weights.json`。
- **雙階段決策管線 (Two-Stage Pipeline)**：
  - **日常行為決策**：15 維特徵輸入，輸出 9 大日常行為機率，並可透過加權輪盤抽樣（Roulette Wheel Selection）提高行為豐富度。
  - **社交互動決策**：當行為選定為「社交」時，以 7 維特徵（時間、社交慾望、心情、好感度、距離、上次互動天數、歷史評分）評估半徑 32 格內之候選者，加權抽選互動對象並決定 7 種社交行為。
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

#### `is_social_engine_available() -> bool`

- **說明**：查詢原生 C# ONNX 社交決策模型推論引擎是否已成功加載並就緒。

#### `evaluate_social(time: float, social_desire: float, mood: float, favorability: float, distance: float, days_since_interaction: float, history_score: float = 0.5) -> float`

- **說明**：透過 7 維社交特徵評估針對特定目標 NPC 的互動意願分數（0.0 ~ 1.0）。

#### `evaluate_social_candidates(time: float, social_desire: float, mood: float, candidates: Array) -> Dictionary`

- **說明**：批次評估半徑 32 格內的候選 NPC 陣列，並透過加權輪盤機率選出互動目標。
- **輸入 `candidates` 格式**：`Array[Dictionary]`，每個字典格式為 `{ "id": int, "distance": float, "favorability": float, "days_since_interaction": float, "history_score": float }`。
- **回傳字典格式**：
  ```gdscript
  {
      "target_id": int,             # 加權輪盤選中之目標 ID (-1 表示無適合目標)
      "highest_target_id": int,     # 分數最高之目標 ID
      "score": float,               # 選中目標之意願評分 (0.0 ~ 1.0)
      "candidate_scores": Dictionary# 各候選者分數字典 { npc_id: score }
  }
  ```

#### `decide_social_action(target_id: int, has_spread_message: bool = false) -> int`

- **說明**：決定具體社交行為代碼（1=普通聊天, 2=討論主題, 3=詢問問題, 4=共同活動, 5=捉弄, 6=欺騙, 7=訊息傳播）。若 `has_spread_message` 為真則固定為 7。

#### `get_social_action_name(action_id: int) -> String`

- **說明**：取得社交行為代碼對應的中文名稱。

---

## 6. NPC 數據模型：NPCData (`scripts/entities/npc_data.gd`)

繼承自 `Resource` 的獨立個體數據模型，封裝 15 維度神經特徵向量、隨時間自然代謝模擬、物品庫存、動態修飾器 (Modifiers) 以及 NPC 間好感度/信任度網絡。

### 6.1 職責與架構

- **動態實體數據分離**：嚴格遵循 `AGENTS.md` 規範，作為從 JSON 模板實例化後的個體專屬 Runtime Instance。
- **15 維度完全對齊**：數值欄位排序嚴格對齊 `npc_normalization.json`、`NPCDecision.cs` 及 `NPCDecisionService`。
- **生理與心理代謝**：支援以 Tick 為單位的自動數值衰減與恢復（如飢餓消耗、睡眠體力恢復、飢餓引發健康下降、自癒機制等）。
- **修飾器支援 (Modifiers)**：支援暫時性或持續性效果（如 `buff_coffee`、`sick` 等），每個 Tick 自動結算。
- **關係網絡儲存**：記錄對其他 NPC 的好感度 (`friendships`) 與信任度 (`trust`)。

### 6.2 15 維度神經特徵清單

| 索引 | 欄位名稱        | 型別    | 數值範圍      | 說明                                             |
| :--: | :-------------- | :------ | :------------ | :----------------------------------------------- |
| `0`  | `hp`            | `float` | `0.0 ~ 100.0` | 生命值（歸零死亡，過半驟降昏迷）                 |
| `1`  | `health`        | `float` | `0.0 ~ 100.0` | 健康度（低於一定值扣血，高於 70 配合飽食可自癒） |
| `2`  | `stamina`       | `float` | `0.0 ~ 100.0` | 體力（做事情消耗，睡眠時快速回復）               |
| `3`  | `hunger`        | `float` | `0.0 ~ 100.0` | 飽食度（每 Tick 固定消耗，過低觸發尋找食物）     |
| `4`  | `social_desire` | `float` | `0.0 ~ 100.0` | 社交慾望（隨時間固定衰減）                       |
| `5`  | `mood`          | `float` | `0.0 ~ 100.0` | 心情（生理不適時下降，正常時回穩）               |
| `6`  | `job_id`        | `int`   | `1 ~ 9`       | 職業編號（礦工、農民、醫生等）                   |
| `7`  | `money`         | `int`   | `0 ~ 9999`    | 持有金錢                                         |
| `8`  | `wood`          | `int`   | `0 ~ 9999`    | 持有木頭                                         |
| `9`  | `stone`         | `int`   | `0 ~ 9999`    | 持有石頭                                         |
| `10` | `mineral`       | `int`   | `0 ~ 9999`    | 持有礦物                                         |
| `11` | `crops`         | `int`   | `0 ~ 9999`    | 持有農作物                                       |
| `12` | `fish`          | `int`   | `0 ~ 9999`    | 持有魚                                           |
| `13` | `food`          | `int`   | `0 ~ 9999`    | 持有料理                                         |
| `14` | `lunchbox`      | `int`   | `0 ~ 9999`    | 持有便當                                         |

### 6.3 訊號 (Signals)

| 訊號名稱               | 參數清單                                                                        | 觸發時機與用途                 |
| :--------------------- | :------------------------------------------------------------------------------ | :----------------------------- |
| `stats_changed`        | `npc_id: String`                                                                | 數值變動或每輪 Tick 更新後廣播 |
| `hp_depleted`          | `npc_id: String`                                                                | 生命值降至 0 時觸發            |
| `hunger_critical`      | `npc_id: String`                                                                | 飽食度低於 20 時警報觸發       |
| `stamina_depleted`     | `npc_id: String`                                                                | 體力耗盡低於 10 時觸發         |
| `item_acquired`        | `npc_id: String, item_type: String, amount: int`                                | 獲得物品時觸發                 |
| `item_consumed`        | `npc_id: String, item_type: String, amount: int`                                | 消耗物品時觸發                 |
| `relationship_changed` | `source_id: String, target_id: String, new_friendship: float, new_trust: float` | 與對象關係值變動時觸發         |

### 6.4 公開方法 (Public Methods)

#### `to_feature_vector() -> PackedFloat32Array`

- **說明**：匯出長度為 15 的特徵向量，可直接傳入 `NPCDecisionService.forward()` 或 `evaluate_decision()`。

#### `from_feature_vector(vec: PackedFloat32Array) -> void`

- **說明**：從 15 維陣列中反向賦值至各屬性。

#### `to_dict() -> Dictionary` / `from_dict(data: Dictionary) -> void`

- **說明**：完整資料字典序列化與反序列化（包含基本身份、15 維度數據、好感度、信任度與詞條偏移量）。

#### `tick_update(delta_ticks: int = 1, is_sleeping: bool = false, is_working: bool = false) -> void`

- **說明**：依據推進的 Tick 數，計算飽食度下降、體力升降（睡眠回血、工作耗體）、健康度聯動與修飾器結算。

#### `add_item(item_type: String, amount: int = 1) -> void` / `consume_item(item_type: String, amount: int = 1) -> bool`

- **說明**：管理物品與金錢的增加與消耗。

#### `eat_food(prefer_lunchbox: bool = true) -> bool`

- **說明**：執行進食，扣減便當或料理，並回復飽食度、體力與心情。

#### `get_friendship(target_id: String) -> float` / `get_trust(target_id: String) -> float`

- **說明**：查詢對特定 NPC 的好感度或信任度（未設定時預設回傳 50.0）。

#### `modify_relationship(target_id: String, delta_friendship: float, delta_trust: float) -> void`

- **說明**：變動與特定 NPC 的好感度或信任度，並發射 `relationship_changed` 訊號。

#### `add_modifier(mod: Dictionary) -> void` / `remove_modifier(mod_id: String) -> void`

- **說明**：掛載或移除動態修飾器。

---

## 7. NPC 控制器：NPCController (`scripts/entities/npc_controller.gd`)

繼承自 `CharacterBody2D` 的核心角色控制器，負責驅動 NPC 的有限狀態機 (FSM)、A\* 網格平滑尋路 (Tween)、四方向走動與定格動畫，並在遊戲 Tick 推進時代謝數值與執行 AI 決策。

### 7.1 職責與狀態機 (FSM)

```gdscript
enum State {
    IDLE,         # 待機 (鎖定在當前朝向的第 0 幀)
    MOVING,       # 沿著 A* 網格路徑平滑移動中
    INTERACTING,  # 社交交流或對話中 (開啟氣泡)
    WORKING,      # 崗位執勤工作中 (農作、採礦、巡視等)
    RESTING       # 在家睡覺或醫院治療中 (高速恢復體力)
}
```

- **呼叫下層、訊號上層 (Call Down, Signal Up)**：內部透過發射 `state_changed`、`target_reached`、`action_started`、`action_completed` 與外部系統通信。
- **Tween 平滑位移**：嚴禁在 `_process` 中手動更新座標，全面使用 `Tween.TRANS_LINEAR` 逐格平滑過渡。
- **4 方向行走與定格**：移動時依方向向量自動切換 `walk_up/down/left/right`，到達目的地時調用 `pause()` 與 `frame = 0` 保持自然定格。

### 7.2 匯出參數 (Exports)

| 屬性名稱                  | 型別                   | 預設值 | 說明                                                  |
| :------------------------ | :--------------------- | :----- | :---------------------------------------------------- |
| `npc_data`                | `Resource` (`NPCData`) | `null` | 關聯的個體數值模型，若為空則在 `_ready` 時自動建立    |
| `step_duration`           | `float`                | `0.22` | 每走 1 個地塊所花費之秒數                             |
| `auto_ai_enabled`         | `bool`                 | `true` | 是否啟用 AI 自主決策迴圈                              |
| `decision_interval_ticks` | `int`                  | `30`   | 當前無特定任務時，每隔多少 Ticks 主動觸發一次決策檢查 |

### 7.3 訊號 (Signals)

| 訊號名稱           | 參數清單                                                 | 觸發時機與用途             |
| :----------------- | :------------------------------------------------------- | :------------------------- |
| `state_changed`    | `old_state: State, new_state: State`                     | 狀態機狀態切換時發射       |
| `target_reached`   | `destination_cell: Vector2i`                             | A\* 尋路抵達最終地塊時發射 |
| `action_started`   | `action_type: int, action_name: String, target_poi: int` | 開始執行新行為時發射       |
| `action_completed` | `action_type: int`                                       | 行為結束時發射             |
| `clicked`          | (無)                                                     | 玩家點擊此 NPC 時發射      |

### 7.4 公開方法與屬性 (Public Methods & Properties)

#### `last_decision: Dictionary`

- **說明**：快取該 NPC 最近一次 AI 大腦決策結果（包含 `best_action`, `best_action_name`, `target_location`, `scores`, `is_rule_override`, `override_reason`），供觀測面板讀取。

#### `get_state_name() -> String`

- **說明**：取得當前狀態機狀態之中文描述（如 `"待機"`、`"移動中"`、`"工作中"` 等）。

#### `make_decision(current_tick: int) -> void`

- **說明**：主動觸發 AI 決策，調用 `NPCDecisionService.evaluate_decision()` 並啟動相應行為（如尋路至目標 POI、原地吃便當、社交等）。

#### `set_state(new_state: State) -> void`

- **說明**：強制轉換狀態機狀態，自動處理動畫定格與信號發射。

#### `move_along_grid(target_cell: Vector2i, on_complete: Callable = Callable()) -> void`

- **說明**：向 `NavigationManager` 請求路徑，依序執行平滑 Tween 移動，並在抵達後執行 `on_complete` 回呼。

#### `face_direction(direction_str: String) -> void`

- **說明**：設定 NPC 朝向（`"up"`、`"down"`、`"left"`、`"right"`）並定格於第 0 幀。

#### `face_toward(target_pos: Vector2) -> void`

- **說明**：計算與目標世界座標的相對向量，自動轉向目標。

#### `show_bubble(duration: float = 2.0) -> void` / `hide_bubble() -> void`

- **說明**：控制頭頂對話氣泡顯示與計時隱藏。

---

## 8. NPC 生成工廠：NPCSpawner (`scripts/entities/npc_spawner.gd`)

繼承自 `Node2D` 的資料驅動型生成工廠，負責解析 `data/poi_locations.json` 註冊全域 POI 座標、讀取 `data/npc_templates.json` 模板、動態實例化 NPC 實體、組裝 4 向 SpriteFrames 動畫貼圖並注入獨立的 `NPCData`。

### 8.1 職責與架構

- **資料驅動 (Data-Driven)**：完全與代碼分離，新增或調整 NPC 屬性、住宅、工作地點僅需編輯 JSON。
- **動態換皮 (Dynamic Skinning)**：傳入 16x32 (4 欄 x 4 列) 的 Sprite Sheet 貼圖路徑，於記憶體中自動切分出 `walk_down`、`walk_left`、`walk_right`、`walk_up` 動畫幀，無需在編輯器中重複切圖。
- **個體資料獨立注入**：為每一位生成的 NPC 實例化專屬的 `NPCData` 物件，確保生命、飽食度與物品庫存相互獨立。
- **安全座標配置**：NPC 出生時自動定位至所屬自宅（`home_poi_id`）的網格座標中心。

### 8.2 匯出參數 (Exports)

| 屬性名稱              | 型別             | 預設值 | 說明                                                                   |
| :-------------------- | :--------------- | :----- | :--------------------------------------------------------------------- |
| `spawn_count`         | `int` (`1 ~ 20`) | `3`    | 遊戲啟動時生成之 NPC 數量（預設 3 隻供初步觀察，可調至 20 隻全鎮運轉） |
| `auto_spawn_on_ready` | `bool`           | `true` | 是否在進入場景樹 `_ready` 時自動執行 POI 註冊與 NPC 批量生成           |

### 8.3 公開與核心方法 (Public & Core Methods)

#### `initialize_and_spawn() -> void`

- **說明**：依序執行導航管理器自動探測/實例化 (`_ensure_navigation_manager`)、POI 註冊、模板載入與 NPC 批量生成。

#### `_ensure_navigation_manager() -> void`

- **說明**：自動檢測全域與場景樹中的 `NavigationManager`。若當前場景尚未掛載，將動態實例化並加載至場景樹中，自動關聯地圖地面層與障礙層完成 A\* 網格初始化，並登錄至 `Global` 服務定位器。

#### `load_and_register_pois(path: String = POIS_PATH) -> bool`

- **說明**：讀取 POI 座標配置 JSON 檔，將所有設施與住宅網格座標登記至 `Global.register_poi()`。

#### `load_templates(path: String = TEMPLATES_PATH) -> bool`

- **說明**：讀取 NPC 模板 JSON 檔並解析為字典陣列。

#### `spawn_all() -> Array[CharacterBody2D]`

- **說明**：依據 `spawn_count` 數量批量生成 NPC 實體並加入場景。

#### `spawn_npc(template: Dictionary) -> CharacterBody2D`

- **說明**：根據單一 NPC 字典模板建立實體、換皮、配置初始屬性並放置於地圖上。

#### `create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames` (Static)

- **說明**：將 4x4 16x32 人物貼圖切分為上下左右 4 向歩行動畫之通用靜態工具函式。

---

## 9. 即時觀測視窗：NPCInspector (`scripts/ui/npc_inspector.gd`)

繼承自 `CanvasLayer`（繪製層級 `layer = 12`）的即時資訊懸浮卡片，當玩家點擊地圖上的任一 NPC 時自動彈出並動態跟隨其畫面像素位置，提供模型推論結果與生理狀態的可視化監控。

### 9.1 核心特性

- **角色側邊平滑跟隨 (Side-by-Side Tracking)**：透過 `get_global_transform_with_canvas().origin` 將 NPC 世界座標轉換為螢幕像素座標，預設浮動於角色「右側」（若靠右邊緣則自動翻轉至「左側」），完全不遮擋角色本體與行走動畫，可同時清楚觀看角色肢體演出與 HUD 數據。
- **橫向精巧雙欄版面 (Compact Two-Column)**：尺寸控制在 380x210 像素，左欄顯示 AI 大腦決策（目標 POI、規則覆蓋或神經推論、前 2 高評分條），右欄顯示 15 維度生理進度條與背包庫存，拒絕冗長垂直拉伸。
- **純代碼生成 (Pure Code Driven)**：UI 節點均以純 GDScript 動態構建，完全不需要建立或維護 `.tscn` 場景。
- **即時數據動態展示**：
  - **身份與狀態**：NPC 姓名、職業、FSM 狀態機標籤（彩色高亮）、地圖座標與所屬網格 Cell。
  - **AI 大腦與決策**：當前行為與目標 POI、推論引擎（C# ONNX Runtime 或 GDScript MLP）、決策機制（規則覆蓋原因或神經自主決策）、神經輸出評分 Top 3（數值與微型進度條）。
  - **15 維度生理狀態**：生命、健康、體力、飽食度、社交慾望、心情（雙欄即時彩色進度條）。
  - **經濟與庫存**：金錢餘額、攜帶物品（木/石/礦/作物/魚/料理/便當）。
- **鏡頭聚焦連動**：提供「鏡頭鎖定/平移」按鈕，點擊後自動平滑平移至選中的 NPC。
- **操作防呆**：支援點擊其他 NPC 無縫切換、點擊右上角 `[✕]` 或按鍵盤 `ESC` 鍵立即關閉。

### 9.2 公開方法 (Public Methods)

#### `inspect_npc(npc: Node2D) -> void`

- **說明**：選中並開始檢視指定 NPC 實體，開啟懸浮面板並動態更新資訊。

#### `close() -> void`

- **說明**：關閉觀測視窗並取消全域選中狀態。
