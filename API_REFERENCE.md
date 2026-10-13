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
  - [1.8 存讀檔系統與死亡公告 API](#18-存讀檔系統與死亡公告-api)
- [2. 導航管理器：NavigationManager (scripts/core/navigation_manager.gd)](#2-導航管理器navigationmanager-scriptscorenavigation_managergd)
  - [2.1 訊號](#21-訊號)
  - [2.2 匯出參數 (Exports)](#22-匯出參數-exports)
  - [2.3 核心方法 (Core & Public Methods)](#23-核心方法-core--public-methods)
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
  - [7.5 行為反饋與生理代謝模擬閉環](#75-行為反饋與生理代謝模擬閉環)

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
| `npc_died`             | `npc_id: String, reason: String`                            | NPC 死亡時廣播 (飢餓衰竭或體力耗盡)                    |
| `game_saved`           | `filepath: String`                                          | 遊戲存檔成功寫入檔案時廣播                             |
| `game_loaded`          | `filepath: String`                                          | 遊戲存檔成功讀取並還原時廣播                           |

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

#### `register_poi(poi_id: int, cell_pos: Vector2i, details: Dictionary = {}) -> void`

- **說明**：註冊設施類型、網格座標與完整進階設定字典（包含 `concealed`, `entrance_dir`, `radius`, `doors`, `polygon`, `walkable_cells`）。

#### `get_poi_cell(poi_id: int) -> Vector2i`

- **說明**：取得特定設施的網格座標。若不存在則回傳 `Vector2i(-1, -1)`。

#### `get_poi_data(poi_id: int) -> Dictionary`

- **說明**：取得特定設施的完整設定字典副本。若不存在則回傳 `{}`。

#### `is_poi_concealed(poi_id: int) -> bool`

- **說明**：查詢特定設施是否為進屋/進林隱藏類型（如伐木場、礦場、自宅、商店等）。

#### `get_poi_entrance_dir(poi_id: int) -> String`

- **說明**：取得特定設施門口朝向（如 `"south"`, `"north"`, `"east"`, `"west"`），預設 `"south"`。

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

### 1.8 存讀檔系統與死亡公告 API

#### `save_game(filepath: String = "") -> bool`

- **說明**：將當前遊戲時間、天數、倍速、暫停狀態以及所有場上 NPC 之座標、狀態機、面向、隱藏狀態、死亡狀態與 15 維度生理數值、背包庫存、人際關係完整序列化儲存為 JSON。
- **預設路徑**：`user://universe26_save.json`，於編輯器與 Debug 環境下自動同步鏡像至 `res://data/savegame.json` 方便即時檢閱。
- **回傳值**：成功寫入檔案回傳 `true`，並發射 `game_saved(filepath)` 全域訊號。

#### `load_game(filepath: String = "") -> bool`

- **說明**：讀取指定 JSON 存檔，還原世界時間、天數、流速倍率，並將所有註冊的 NPC 實體還原至存檔時之確切世界座標、朝向、狀態與 15 維度數據（包括死亡狀態倒地展演）。
- **回傳值**：成功還原回傳 `true`，並發射 `game_loaded(filepath)` 全域訊號。

#### `on_npc_died(npc_id: String, reason: String) -> void`

- **說明**：供 `NPCController` 於個體生命值歸零時呼叫，列印死亡紀錄並向全域發射 `npc_died(npc_id, reason)` 訊號。

---

## 2. 導航管理器：NavigationManager (`scripts/core/navigation_manager.gd`)

封裝 Godot 4 原生 `AStarGrid2D`，自動讀取多層 `TileMapLayer`，管理網格尋路與阻擋。

### 2.1 訊號

| 訊號名稱           | 參數清單                                                        | 觸發時機與用途                                   |
| :----------------- | :-------------------------------------------------------------- | :----------------------------------------------- |
| `grid_initialized` | `total_cells: int, walkable_cells: int`                         | A\* 網格初始化完成時發射，回報總格數與可行走格數 |
| `path_calculated`  | `from_cell: Vector2i, to_cell: Vector2i, path: Array[Vector2i]` | 成功計算兩點間網格路徑時發射                     |

### 2.2 匯出參數 (Exports)

| 屬性名稱             | 型別                | 預設值                                                                    | 說明                                                               |
| :------------------- | :------------------ | :------------------------------------------------------------------------ | :----------------------------------------------------------------- |
| `ground_layer`       | `TileMapLayer`      | `null`                                                                    | 地面層（自動探測或手動綁定）                                       |
| `obstacle_layer`     | `TileMapLayer`      | `null`                                                                    | 障礙層（自動探測或手動綁定）                                       |
| `allow_diagonals`    | `bool`              | `false`                                                                   | 是否允許斜向移動（預設關閉，僅 4 向走格避免穿牆）                  |
| `weight_strategy`    | `WeightStrategy`    | `ROAD_PREFERRED`                                                          | 尋路加權策略：`ROAD_PREFERRED` (優先走道路) 或 `AVOID_GRASS` (避開草地) |
| `road_weight`        | `float`             | `1.0`                                                                     | 道路/非草地通行代價權重（數值越低越優先通行）                      |
| `offroad_weight`     | `float`             | `3.0`                                                                     | 草地/非道路通行代價權重，使 A\* 尋路大幅偏好走在道路網格           |
| `road_atlas_coords`  | `Array[Vector2i]`   | 主道路 `(7, 5)`、石板路 `(1, 54)`、木棧道 `(4, 39)`、廣場九宮格等           | 識別為道路/鋪設地磚之圖塊 Atlas 座標清單（白名單模式使用）         |
| `grass_atlas_coords` | `Array[Vector2i]`   | 一般草地 `(1, 4)`、帶花草地 `(5, 0), (5, 1), (5, 2), (6, 2)`              | 識別為草地之圖塊 Atlas 座標清單（黑名單模式使用）                 |

### 2.3 核心方法 (Core & Public Methods)

#### `initialize_grid() -> void`

- **說明**：手動或自動重新掃描 `ground_layer` 與 `obstacle_layer`，重建 `AStarGrid2D` 尋路網格。
- **雙模式加權機制**：
  - `ROAD_PREFERRED` (預設白名單)：在 `road_atlas_coords` 中的地塊給予 `road_weight` (1.0)，其餘地塊給予 `offroad_weight` (3.0)。
  - `AVOID_GRASS` (黑名單)：在 `grass_atlas_coords` 中的地塊給予 `offroad_weight` (3.0)，其餘所有地塊給予 `road_weight` (1.0)，地圖擴充性最高。
- **自訂屬性支援**：
  - `is_solid` (bool)：若 TileData 包含此屬性且為 `true` 則該地塊不可通行。
  - `walk_weight` (float)：若 TileData 包含此自訂數值，覆寫該格專屬權重。

#### `is_road_cell(cell: Vector2i) -> bool`

- **說明**：檢查指定網格座標是否屬於道路或鋪設地磚。

#### `get_cell_weight(cell: Vector2i) -> float`

- **說明**：取得指定網格座標的 A\* 尋路通行權重。

#### `set_cell_weight(cell: Vector2i, weight: float) -> void`

- **說明**：動態自訂指定網格座標的尋路通行權重。

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
    - `NpcStatusLabel`：當前選中焦點 NPC 或全鎮居民存活統計（如「👥 鎮民: 18 存活 (💀 2 亡故)」）。
  - **右側操作按鈕 (RightBox)**：
    - `PauseButton`：切換暫停 / 繼續（同步觸發 `Global.toggle_time_paused()`）。
    - `Speed1xButton`, `Speed2xButton`, `Speed4xButton`：切換時間倍率（`1.0x`, `2.0x`, `4.0x`, `8x`, `16x`, `32x`, `60x`），當前倍速會發光高亮標示。
    - `FFHourButton` (`+1h`)：快速推進 1 小時 (60 Ticks)。
    - `FFMidnightButton` (`🌙午夜`)：快速推進至下一個午夜，觸發 C# 記憶演化。
    - `SaveButton` (`💾 存檔`)：即時將全域進度與 20 隻 NPC 存檔至 JSON（快捷鍵：`F5` 或 `Ctrl+S`）。
    - `LoadButton` (`📂 讀檔`)：即時讀取存檔並還原所有角色位置與代謝數值（快捷鍵：`F9` 或 `Ctrl+L`）。

### 3.2 公開方法與回呼

#### `update_all_display() -> void`

- **說明**：強制即時刷新所有時間、導航狀態與按鈕高亮。

#### `set_npc_status(status_text: String) -> void`

- **說明**：設定中央顯示的 NPC 當前行為或狀態文字（如「尋路前往餐廳」、「待機中」）。

#### `show_toast(msg: String, text_color: Color = Color(0.4, 0.9, 0.5)) -> void`

- **說明**：在 HUD 頂部中央彈出半透明提示橫幅（例如「💾 遊戲進度已成功儲存！(F5)」或「💀 鎮民 NPC_1 因 飢餓衰竭 亡故！」），停留 2.2 秒後平滑淡出。

---

## 4. 遊戲攝影機：GameCamera (`scene/camera/game_camera.tscn`, `scripts/camera/game_camera.gd`)

繼承自 `Camera2D` 的獨立模組化相機節點，支援方向鍵 (及 WASD) 鍵盤平移、滑鼠中鍵即時拖曳平移、滾輪與 Z/X 鍵縮放、平滑導航追蹤與地圖邊界限制。

### 4.1 職責與特性

- **獨立封裝**：相機邏輯完全內聚於 `GameCamera`，不需依賴外部腳本驅動即可自主運作。
- **鍵盤方向鍵平移**：支援方向鍵（`UP` / `DOWN` / `LEFT` / `RIGHT` 及 `W` / `A` / `S` / `D`）長按連續平移視角，並自動依當前縮放比例換算等比移動速度。輸入框焦點時自動避讓。
- **無縫拖曳**：在滑鼠中鍵按住拖曳時自動關閉 `position_smoothing_enabled`，確保 1:1 像素跟手感；放開時自動平滑回彈。
- **靈活縮放 (滾輪與 Z/X 鍵)**：支援滑鼠滾輪滾動與鍵盤 `Z`（放大）、`X`（縮小）鍵（單擊單步、長按平滑連續縮放），具備最小/最大邊界限制防穿幫。
- **自動邊界綁定**：於 `_ready` 時自動向 `Global.get_navigation_manager()` 取得地圖大小與 Tile 像素，鎖定 `limit_left` / `limit_top` / `limit_right` / `limit_bottom`，防止相機移出地圖黑邊。

### 4.2 匯出參數 (Exports)

| 屬性名稱               | 型別    | 預設值  | 說明                                         |
| :--------------------- | :------ | :------ | :------------------------------------------- |
| `enable_pan`           | `bool`  | `true`  | 是否啟用滑鼠中鍵拖曳平移                     |
| `enable_zoom`          | `bool`  | `true`  | 是否啟用縮放功能（滑鼠滾輪與 Z/X 鍵）        |
| `enable_keyboard_pan`  | `bool`  | `true`  | 是否啟用鍵盤方向鍵視角平移                   |
| `keyboard_pan_speed`   | `float` | `500.0` | 鍵盤平移移動速度（像素/秒）                  |
| `min_zoom`             | `float` | `0.5`   | 最小縮放倍率（廣角視野極限）                 |
| `max_zoom`             | `float` | `4.0`   | 最大縮放倍率（特寫視野極限）                 |
| `zoom_factor`          | `float` | `1.15`  | 單次滾輪滾動或按鍵縮放倍率變化量             |
| `auto_bind_map_limits` | `bool`  | `true`  | 是否自動取得導航地圖邊界並鎖定鏡頭可移動區域 |

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
- **特性**：若使用者按下中鍵拖曳或使用方向鍵平移，跟隨狀態將自動中斷並轉由手動控制。

#### `stop_following() -> void`

- **說明**：主動解除對目標節點的跟隨狀態。

#### `zoom_by_factor(factor: float) -> void`

- **說明**：依倍率（如 `1.15` 或 `1.0 / 1.15`）平滑縮放相機，數值自動鉗制在 `[min_zoom, max_zoom]` 之間。

#### `zoom_in() -> void`

- **說明**：依預設 `zoom_factor` 平滑放大相機視野（等同於鍵盤 Z 鍵或滾輪向上滾動）。

#### `zoom_out() -> void`

- **說明**：依預設 `zoom_factor` 平滑縮小相機視野（等同於鍵盤 X 鍵或滾輪向下滾動）。

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
- `4`: 就醫 (MEDICAL) -> 醫院 (POI 18，提供醫療急救與營養點滴，回補健康、生命、體力與飽食度 +25)
- `5`: 回家休息 (REST) -> 自宅 (POI 1~11)
- `6`: 社交 (SOCIAL) -> 社交廣場 (POI 20)
- `7`: 巡田水 (PATROL) -> 農田 (POI 16)
- `8`: 販售物品 (SELL) -> 商店 (POI 12)

#### 職業作息表 (`JOB_SCHEDULES`)

- 1 礦工：08:00 ~ 17:00 (POI 15 礦場)
- 2 圖書管理員：09:00 ~ 20:00 (POI 19 圖書館)
- 3 漁夫：07:00 ~ 09:00 (POI 17 釣魚場)
- 4 餐廳員工：午班 11:00 ~ 13:00、晚班 18:00 ~ 21:00 (POI 13 餐廳)
- 5 醫護人員：醫院 (POI 18)，採雙人輪班制 (早班 07:00 ~ 15:00 / 晚班 14:00 ~ 22:00，交接重疊 1 小時)。工作期間享有醫院茶水間補給（飽食度 +15、健康 +5，且免扣除勞動飽食消耗），避免因長時間執勤飢餓。
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
      personality_offset: PackedFloat32Array = PackedFloat32Array(),
      npc_id: String = ""
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

- **說明**：依據推進的 Tick 數，計算飽食度下降、體力升降（睡眠回血、工作耗體）、健康度聯動與修飾器結算。當飽食度降至 0 時觸發**飢荒飢餓衰竭機制**：每 Tick 健康度損失 `0.2`、生命值 (`hp`) 損失 `0.3`；當健康度過低 (`health < 20.0`) 進入生病重症狀態，每 Tick 額外扣除生命值 `0.15`，促使其前往醫院就醫；生命值歸零時發射 `hp_depleted(npc_id)` 訊號。

#### `add_item(item_type: String, amount: int = 1) -> void` / `consume_item(item_type: String, amount: int = 1) -> bool`

- **說明**：管理物品與金錢的增加與消耗。

#### `eat_food(prefer_lunchbox: bool = true) -> bool`

- **說明**：執行進食，扣減便當或料理，並回復飽食度、體力與心情。

#### `get_friendship(target_id: String) -> float` / `get_trust(target_id: String) -> float`

- **說明**：查詢對特定 NPC 的好感度或信任度（未設定時預設回傳 50.0）。

#### `modify_relationship(target_id: String, delta_friendship: float, delta_trust: float) -> void`

- **說明**：變動與特定 NPC 的好感度或信任度，並發射 `relationship_changed` 訊號。

#### `add_stm_event(event_text: String) -> void`

- **說明**：新增單筆短期生活事件記憶 (STM)，保留最新 5 筆（例如用餐、工作、治療、與特定鄰居社交之互動結果）。

#### `get_days_since_interaction(target_id: String, current_day: int) -> float`

- **說明**：查詢距上次與特定 NPC 互動之遊戲天數（預設 3.0，最大 10.0），作為 7 維社交 ONNX 模型之特徵輸入。

#### `record_interaction(target_id: String, current_day: int) -> void`

- **說明**：記錄與特定 NPC 發生社交互動之遊戲天數。

#### `evolve_midnight_memory(day: int) -> void`

- **說明**：每日午夜 (00:00 / Tick 0) 觸發記憶演化結算：人際好感度網向基準值溫和收斂，沉澱當日思緒並歸檔日記。

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
- **時間暫停與動態倍速響應 (Pause & Time Scale Reactive Sync)**：全面監聽 `Global.time_paused_toggled` 與 `Global.time_scale_changed`。暫停時即時凍結正在運行的位移 `Tween`、定格歩行動畫並暫停內部行為倒數計時器；變速時即時重設 Tween 與 Sprite 動畫播放速率 (`cur_scale`)，杜絕高倍速下按暫停反而還原為 1 倍速移動之邏輯缺陷。

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

#### `is_concealed: bool`

- **說明**：標記該 NPC 目前是否處於進屋/進林隱藏狀態。

#### `enter_building(entrance_dir: String = "south") -> void`

- **說明**：進入建築物或密林工坊，朝向 `entrance_dir` 旋轉並執行 0.35 秒平滑淡出動畫，完成後將 `visible` 設為 `false` 並標記 `is_concealed = true`。

#### `exit_building() -> void`

- **說明**：自建築物或密林現身，將 `visible` 設為 `true` 並執行 0.35 秒平滑淡入動畫，重設 `is_concealed = false`。

#### `is_dead: bool` / `death_cause: String`

- **說明**：標記該 NPC 是否已死亡以及其死亡原因（如 `"飢餓衰竭"`、`"體力耗盡"`）。死亡後將停止計時與神經網路決策，狀態轉為長眠。

#### `is_social_target: bool`

- **說明**：標記該 NPC 當前是否已被另一位居民選為社交對象。社交發起者會將其鎖定，防止全鎮多人同時朝向同一名 NPC 移動造成同格聚集。

#### `die(cause: String = "飢餓衰竭") -> void`

- **說明**：手動或因生命值歸零觸發死亡。中斷當前行為、停止 Tween 位移、停止氣泡並觸發倒地展演（旋轉 90 度躺平、畫面調暗變灰 `Color(0.45, 0.45, 0.5)`），並向全域發射 `Global.on_npc_died` 死亡廣播。

#### `to_dict() -> Dictionary` / `from_dict(data: Dictionary) -> void`

- **說明**：將 NPC 當前世界座標、網格座標、狀態機、面向、隱蔽標記、死亡標記及所屬 `NPCData` 序列化/反序列化，供存讀檔系統還原。

#### `get_state_name() -> String`

- **說明**：取得當前狀態之中文易讀名稱。動態結合 `current_state` 與 `current_action_id` 進行解析：
  - `State.IDLE` -> `"待機"`
  - `State.MOVING` -> `"移動中"`
  - `State.INTERACTING` -> 依據行為細分：`2` 購物為 `"購物中"`、`3` 吃飯為 `"用餐中"`、其他為 `"社交中"`。
  - `State.WORKING` -> `"工作中"`
  - `State.RESTING` -> `"休息中"`
  - 死亡時回傳 `"💀 亡故"`。

#### 社交防空轉、防幽靈對話與雙向握手機制

- **搜尋半徑限制 (`MAX_SOCIAL_SEARCH_DIST = 160.0px`)**：僅在周遭約 10 格範圍內尋找閒置 (`State.IDLE`) 的對象，不再跨越整座城鎮發起社交。
- **移動與狀態明確分離**：在前往對方身旁或前往廣場過程中，狀態維持為 `State.MOVING`，UI 顯示為「前往社交」，絕不提前切換至「社交中」。
- **抵達距離二次確認 (`SOCIAL_INTERACT_DIST = 38.0px`)**：發起者到達目標鄰近格時，再次檢測雙方距離。若對方已走遠或因突發需求離開，立即安全釋放鎖定並轉為普通待機，絕不對著空氣自言自語或強行將遠方的對方改為社交中。
- **面對面同步互動 (`_start_mutual_conversation`)**：雙方確實處於相鄰位置時，同步中止殘留位移、互相面對、同時進入 `State.INTERACTING`、頭頂冒出對話氣泡並提升好感度，結束後雙方安全同步解鎖。
- **廣場無人保護**：若周遭無人而前往社交廣場，抵達後若依然無人，維持 `State.IDLE` 散步待機，不觸發孤立的社交狀態。
- **相鄰獨立站位 (`_get_free_adjacent_cell`)**：尋找對方上下左右 4 格且**未被其他 NPC 佔用**之可行走地塊站立，徹底杜絕兩人疊在同一個地塊。
- **廣域設施目標分散**：前往社交廣場 (POI 20) 或農田等開放性廣域 POI 時，從 POI 的 `walkable_cells` 中隨機選取未被佔用的格子分散站位。

### 7.5 行為反饋與生理代謝模擬閉環 (Action Metabolic & Economic Feedback Loop)

為確保 NPC 15 維度神經模型與生理代謝之自然閉環運轉，各項行為在抵達目標地點與執行期間均具備嚴格的數值增減與經濟代價回饋：

| 行為代碼與名稱 | 觸發地點 (POI) | 經濟收支與物資變動 (對齊 Google 道具表) | 生理與心理屬性變更 | 設計機制與防呆說明 |
| :--- | :--- | :--- | :--- | :--- |
| **0: 閒逛 (Wander)** | POI 20 (廣場) 或 原地鄰格 | 無 | 心情 `+5 ~ +6`<br>體力 `-2.0` | 散步放鬆心情，微量消耗體力。較容易前往社交廣場 (POI 20)。 |
| **1: 閱讀 (Read)** | POI 19 (圖書館) | 無 | 心情 `+20.0`<br>體力 `-5.0` | 閱讀充實精神境界，高度改善心情。 |
| **2: 購物 (Shop)** | POI 13 (餐廳) 或 POI 12 (商店) | 金錢 `-3` 購買便當或料理 | 心情 `+10.0` | 預先購買存糧（道具表售價 $3），儲備後續原地進食之資源。 |
| **3: 吃東西 (Eat)** | POI 13 (餐廳) 或 POI 0 (原地) | 餐廳：金錢 `-3`<br>原地：消耗便當或料理 | 餐廳：飽食 `+60`、體力 `+25`、心情 `+20`<br>原地：飽食 `+35~45`、體力 `+10~15`、心情 `+5~10` | **救濟愛心熱湯防呆**：若 NPC 無錢亦無糧，餐廳提供愛心熱湯 (飽食 `+40`、體力 `+15`、心情 `+10`)，杜絕餓死在餐廳門口。<br>**原地自救防呆**：原地若無便當，依序食用生鮮作物/魚或野果。 |
| **4: 就醫 (Medical)** | POI 18 (醫院) | 金錢 `-5` (掛號醫療費) | 健康 `+45.0`<br>生命 `+35.0`<br>體力 `+20.0`<br>心情 `+15.0` | 全面治療傷病與虛弱狀態，恢復生理指標。 |
| **5: 回家休息 (Rest)** | POI 1~11 / 21 (自宅) | 無 | 體力 `+35.0`<br>心情 `+15.0`<br>生命 `+15.0` (健康良好時) | 居家安歇，快速恢復體力與精神。 |
| **6: 社交 (Social)** | POI 20 (廣場) 或 夥伴身旁 | 無 | 社交慾望 `+40.0`<br>心情 `+15.0`<br>好感/信任 `+3/+2` | 雙向同步補足社交慾望缺口，加深鄰里情誼。 |
| **7: 巡田水 (Patrol)** | POI 16 (農田) | 農作物 `+1` | 體力 `-8.0`<br>飽食 `-4.0`<br>心情 `+6.0` | 農夫特有巡視田埂並採收作物。 |
| **8: 販售物品 (Sell)** | POI 12 (商店/市場) | 出售庫存變現 (依道具表定價)：<br>作物 `+$5`、礦石 `+$2`、魚 `+$2`、木頭 `+$2`、石頭 `+$1` | 心情 `+15.0` | 將生產勞動所得變現為流動資金。若無物可賣則打零工領取基礎津貼 `+$1`。 |
| **崗位執勤 (Work)** | 職業專屬 POI 12~19 | 依各職業產出資源或領取工資 | 體力 `-10.0`<br>飽食 `-5.0` | 勞動消耗能量，自然驅動 NPC 於午餐時間用餐與夜間就寢。 |

- **工作排程判定修正 (`is_work_schedule`)**：
  - 決策大腦嚴格將「工作排程 (`is_work_schedule`)」與一般規則覆蓋（如午餐時間、就寢時間）分離。
  - 確保 NPC 在 12:00 午餐時間前往餐廳時，專注於「進食與恢復飽食度」，不再被誤判為執勤工作。

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
| `spawn_count`         | `int` (`1 ~ 20`) | `20`   | 遊戲啟動時生成之 NPC 數量（預設為全鎮 20 隻完整運轉）                 |
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
- **雙分頁頁籤卡片架構 (Dual-Tab Card Layout)**：面板尺寸設定為 410x250 像素，採用 `TabContainer` 分流呈現複雜數據，視覺乾淨俐落：
  - **分頁 1：📊 生理與決策 (Physiology & Decision Tab)**：
    - **生理數值與庫存 (左欄)**：即時彩色雙欄進度條呈現生命、健康、體力、飽食度、社交慾望、心情（0~100 帶百分比與數值顏色警告），以及持幣量與背包 7 類物品持有數量。
    - **日常決策神經網絡 (右欄)**：顯示推論引擎狀態標籤（C# ONNX Runtime 或 GDScript Fallback）、當前行為意圖與目標 POI、決策模式（規則覆蓋原因或神經自主決策），以及 15 維度神經模型輸出評分最高的 Top 2 機率柱狀進度條。
  - **分頁 2：🧠 社交與記憶 (Social & Memory Tab)**：
    - **社交神經模型推論觀測區 (Social ONNX Inference Radar)**：顯示社交決策引擎加載狀態（`[ONNX 就緒]` 或 `[Fallback]`）、當前鎖定之社交候選 NPC 名稱、神經網路意向指數（%）、以及選定之 7 種社交行為（普通聊天、討論主題、共同活動等）；若未在社交則顯示周遭掃描雷達狀態。
    - **心靈記憶系統觀測區 (Soul Memory System)**：
      - **長期記憶特質 (LTM Traits)**：顯示該 NPC 深層性格標籤（例如 `[友善]`、`[勤奮]`、`[謹慎]`）。
      - **中長期人際網絡 (MTM Network)**：排序顯示與全鎮居民的好感度 (`Friendship`) 與信任度 (`Trust`) 最高之前 2 名對象與數值。
      - **短期生活記憶滾動誌 (STM Events)**：即時記錄最新 3 筆日常微觀生活事件（例如用餐、就醫、採集、工作、與鄰居聊天等真實歷程）。
- **純代碼生成 (Pure Code Driven)**：UI 節點均以純 GDScript 動態構建，完全不需要建立或維護 `.tscn` 場景。
- **鏡頭聚焦連動**：提供「鏡頭鎖定/平移」按鈕，點擊後自動平滑平移至選中的 NPC。
- **操作防呆**：支援點擊其他 NPC 無縫切換、點擊右上角 `[✕]` 或按鍵盤 `ESC` 鍵立即關閉。

### 9.2 公開方法 (Public Methods)

#### `inspect_npc(npc: Node2D) -> void`

- **說明**：選中並開始檢視指定 NPC 實體，開啟懸浮面板並動態更新資訊。

#### `close() -> void`

- **說明**：關閉觀測視窗並取消全域選中狀態。
