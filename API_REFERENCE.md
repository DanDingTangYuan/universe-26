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
- [10. 記憶系統與換日結算管線 (Memory System & Midnight Settlement Pipeline)](#10-記憶系統與換日結算管線-memory-system--midnight-settlement-pipeline)
  - [10.1 C# 記憶橋接層：NPCDecisionBridge](#101-c-記憶橋接層npcdecisionbridge-ai_modelsnpcdecisionbridgecs)
  - [10.2 GDScript 決策大腦服務：NPCDecisionService](#102-gdscript-決策大腦服務npcdecisionservice-scriptsaidecision_servicegd)
  - [10.3 實體與全域單例整合](#103-實體與全域單例整合)
- [11. Transformer 軌跡收集與 LLM 接口架構 (scripts/ai/trajectory_logger.gd, scripts/ai/social_semantics.gd)](#11-transformer-軌跡收集與-llm-接口架構)
  - [11.1 社交語意與 LLM 接口：SocialSemantics](#111-社交語意與-llm-接口socialsemantics-scriptsaisocial_semanticsgd)
  - [11.2 決策軌跡收集器：TrajectoryLogger](#112-決策軌跡收集器trajectorylogger-scriptsaitrajectory_loggergd)
- [13. Causal Social Transformer 社交大腦架構與推論服務 (Social Transformer System)](#13-causal-social-transformer-社交大腦架構與推論服務-social-transformer-system)
- [14. 存檔槽位系統 (Save Slots) 與 正式版主選單架構 (Main Menu & Model Selection)](#14-存檔槽位系統-save-slots-與-正式版主選單架構-main-menu--model-selection)
  - [14.1 存檔槽位管理器：SaveSlotManager (scripts/core/save_slot_manager.gd)](#141-存檔槽位管理器saveslotmanager-scriptscoresave_slot_managergd)
  - [14.2 存檔槽位互動選擇視窗：SaveSlotDialog (scripts/ui/save_slot_dialog.gd)](#142-存檔槽位互動選擇視窗saveslotdialog-scriptsuisave_slot_dialoggd)
  - [14.3 獨立開始畫面：TitleScreen (scripts/ui/title_screen.gd)](#143-獨立開始畫面titlescreen-scriptsuititle_screengd)
  - [14.4 遊戲內暫停選單：PauseMenu (scripts/ui/pause_menu.gd)](#144-遊戲內暫停選單pausemenu-scriptsuipause_menugd)
  - [14.5 全域單例與決策服務擴充 API](#145-全域單例與決策服務擴充-api)
- [15. 緊急醫療救援與市民自主通報系統 (Emergency Medical Rescue & Bystander Reporting System)](#15-緊急醫療救援與市民自主通報系統-emergency-medical-rescue--bystander-reporting-system)
  - [15.1 核心流程與閉環機制](#151-核心流程與閉環機制)
  - [15.2 全域單例事件匯流排 API (Global)](#152-全域單例事件匯流排-api-global)
  - [15.3 NPC 控制器急救與通報 API (NPCController)](#153-npc-控制器急救與通報-api-npccontroller)
- [16. 情報擴散與傳播驗證系統 (Information Diffusion & Verification System)](#16-情報擴散與傳播驗證系統-information-diffusion--verification-system)
  - [16.1 情報擴散管理器：InformationDiffusionManager (scripts/ai/information_diffusion_manager.gd)](#161-情報擴散管理器informationdiffusionmanager-scriptsaiinformation_diffusion_managergd)
  - [16.2 5 大結構化通用模板與神經行為引力 (Structured Slot Templates & Behavioral Gravity)](#162-5-大結構化通用模板與神經行為引力-structured-slot-templates--behavioral-gravity)
  - [16.3 NPC 數據模型情報擴充 API (NPCData)](#163-npc-數據模型情報擴充-api-npcdata)
  - [16.4 NPC 控制器頭頂氣泡保留接口與傳播演繹 (NPCController)](#164-npc-控制器頭頂氣泡保留接口與傳播演繹-npccontroller)
  - [16.5 全鎮情報傳播拓撲驗證面板：RumorPropagationDialog (scripts/ui/rumor_propagation_dialog.gd)](#165-全鎮情報傳播拓撲驗證面板rumorpropagationdialog-scriptsuirumor_propagation_dialoggd)
  - [16.6 開場居民性格詞條配置面板：NPCTraitSettingsDialog (scripts/ui/npc_trait_settings_dialog.gd)](#166-開場居民性格詞條配置面板npctraitsettingsdialog-scriptsuinpc_trait_settings_dialoggd)
  - [16.7 小鎮布告欄站位物件：BulletinBoard (scripts/objects/bulletin_board.gd)](#167-小鎮布告欄站位物件bulletinboard-scriptsobjectsbulletin_boardgd)

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
    HOME = 21,       # 自宅 (回家休息)
    NOTICE_BOARD = 22 # 小鎮布告欄 (閱覽情報 / 傳播公告)
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
| `navigation_manager_registered` | `nav: Node`                                        | 導航管理器 (NavigationManager) 初始化並註冊至全域時廣播 |
| `npc_action_started`   | `npc_id: String, action: ActionType, target_cell: Vector2i` | NPC 開始執行某行動時廣播 (供 UI 或監控)                |
| `npc_action_completed` | `npc_id: String, action: ActionType`                        | NPC 完成行動時廣播                                     |
| `npc_selected`         | `npc: Node2D`                                               | 玩家點選/選中某 NPC 時廣播 (供觀測 HUD 綁定)           |
| `npc_deselected`       | (無)                                                        | 取消選中 NPC 時廣播                                    |
| `npc_died`             | `npc_id: String, reason: String`                            | NPC 死亡時廣播 (飢餓衰竭或體力耗盡)                    |
| `game_saved`           | `filepath: String`                                          | 遊戲存檔成功寫入檔案時廣播                             |
| `game_loaded`          | `filepath: String`                                          | 遊戲存檔成功讀取並還原時廣播                           |
| `household_money_split` | `home_poi_id: int, total_money: int, split_amount: int`     | 每日午夜同居家庭主夫/主婦戶完成金錢平分時廣播           |

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

#### `start_new_game(reset_memory_db: bool = true) -> void`

- **說明**：重新開局（全新遊戲）。重置世界時間為第 1 天 08:00 (`current_day = 1, current_tick = 480`)、流速倍率恢復 1.0、清除註冊實體快取，並呼叫 `initialize_memory_database(true)` 強制重置 SQLite 6 大資料表為乾淨初始值，隨後重新載入當前場景，避免開局繼承舊存檔之飢荒死亡殘留數據。

#### `on_npc_died(npc_id: String, reason: String) -> void`

- **說明**：供 `NPCController` 於個體生命值歸零時呼叫，列印死亡紀錄並向全域發射 `npc_died(npc_id, reason)` 訊號。

#### `split_homemaker_household_money() -> void`

- **說明**：每日午夜跨日（00:00）記憶結算管線執行完畢後自動觸發。針對所有同居住宅（相同 `home_poi_id`），若住戶中包含家庭主夫/主婦（`job_id == 9`），將該屋所有同居伴侶之現金總額加總並均分（餘數守恆分配），確保無固定薪資的家庭主婦/主夫享有共同家庭財務支配權。
- **內部行為**：
  1. 依據 `home_poi_id` 聚合同居成員。
  2. 計算家庭總資產 $M_{total} = \sum money$，每人分得 $\lfloor M_{total} / N \rfloor$。
  3. 更新雙方 `data.money`、發射 `stats_changed` 訊號、記錄 STM 事件日誌並廣播 `household_money_split` 全域訊號。

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
    - `Speed1xButton`, `Speed2xButton`, `Speed4xButton`, `Speed60xButton`：切換時間倍率（`1.0x`, `2.0x`, `4.0x`, `8x`, `16x`, `32x`, `⚡ 60x`），設有專屬 60 倍速極速按鈕（快捷鍵：`6`）與防凍結保護（限制每幀最大處理 120 Ticks），當前倍速發光高亮標示。
    - `FFHourButton` (`+1h`)：快速推進 1 小時 (60 Ticks)。
    - `FFMidnightButton` (`🌙午夜`)：快速推進至下一個午夜，觸發 C# 記憶演化。
    - `SaveButton` (`💾 存檔`)：即時將全域進度與 20 隻 NPC 存檔至 JSON（快捷鍵：`F5` 或 `Ctrl+S`）。
    - `LoadButton` (`📂 讀檔`)：即時讀取存檔並還原所有角色位置與代謝數值（快捷鍵：`F9` 或 `Ctrl+L`）。
    - **重開局快捷鍵**：支援按 `F2` 或 `Ctrl+R` 立即重置世界、強制重新初始化 SQLite 記憶資料庫並全新開局。

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
  - **規則層 (Rule-based 階層化覆蓋)**：
    - **規則 0：飢餓緊急生存法則 (最高優先級)**：當 `hunger < 30.0` 時，優先原地食用隨身便當/料理（耗時 1.5 秒即時補給飽食 +55、體力 +35、心情 +15），徹底杜絕身懷糧食卻餓死；若無糧食且非深夜，前往餐廳 (POI 13) 點餐 (體力 +35) 或領取愛心熱湯救濟 (體力 +20)。
    - **規則 1：就寢時間 (23:00 ~ 06:00)**：強制返家休息 (`best_action = 5`)。入眠後控制器將 NPC 鎖定於 `State.RESTING` 直至清晨 06:00 晨起，期間自動過濾每 15 ticks 的反覆決策與超時看門狗干擾，且僅在就寢時記錄單次休息記憶，徹底消滅凌晨反覆做出無意義回家睡覺決策與 SQLite 記憶膨脹。
    - **規則 2：緊急就醫**：當健康度 `< 25.0` 或重傷時，強制前往醫院 (POI 18) 治療。
    - **規則 3：常規三餐用餐排程**：早餐 (07:00 ~ 08:00)、午餐 (12:00 ~ 13:00)、晚餐 (18:00 ~ 19:30)，當 `hunger < 85.0` 時觸發進食。
    - **規則 4：體力耗盡休養與遲滯保護 (晝夜分流)**：
      - 白天時段 (06:30 ~ 21:30, tick 390~1290) 嚴禁觸發返家睡眠 (Action 5)；若體力偏低 (`stamina < 30.0`)，優先引導進食 (`Action 3`)，若無存糧金錢則原地小憩摸魚 (`Action 0`)，徹底消除白天全體跑回家大睡的假死現象。
      - 夜間時段 (21:30 ~ 06:30) 體力透支 (stamina < 30.0) 或休養中 (未達 75.0) 才允許返家就寢 (`Action 5`)。
    - **規則 5：崗位工作排程**：依職業作息判定出勤。若處於夜間體力休養（未達 75.0）或健康不適，免除強制出勤。
    - **規則 5.5：自由活動期購物與儲糧活化**：當居民持有金錢充足 (`money >= 6`) 且身上無任何存糧 (`lunchbox == 0 and food == 0`) 時，在自由活動期間給予前往商店 (POI 12) 或餐廳 (POI 13) 採購備糧的傾向。
    - **規則 5.6：自由活動期社交慾望活化**：當居民社交慾望偏低 (`social_desire < 45.0`) 且無排程干預時，給予社交互動傾向，激勵前往社交廣場 (POI 20) 與鄰里交流並觸發 Social Transformer。
  - **神經層 (Neural Model)**：無規則干預時，透過神經網路依據 15 維度生理狀態與個性詞條偏移量輸出 9 種行為分數（0.0 ~ 1.0），並結合 LTM 行動權重進行輪盤抽樣。
- **社交過濾 (Social Filter)**：依據企劃規格，自動過濾處於工作、就醫、閱讀、在家休息等不適合社交狀態的 NPC。

### 5.2 核心常數與排程表

#### 作息關鍵時間點 (`Ticks`)

- `WAKE_UP_TICK`: `360` (06:00 起床活動)
- `BREAKFAST_START_TICK` / `BREAKFAST_END_TICK`: `420 ~ 480` (07:00 ~ 08:00 早餐)
- `LUNCH_START_TICK` / `LUNCH_END_TICK`: `720 ~ 780` (12:00 ~ 13:00 午餐)
- `DINNER_START_TICK` / `DINNER_END_TICK`: `1080 ~ 1170` (18:00 ~ 19:30 晚餐)
- `BEDTIME_TICK`: `1380` (23:00 就寢宵禁)

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
      npc_id: String = "",
      action_weights: Array = [],
      is_resting: bool = false,
      prev_action: int = 0
  ) -> Dictionary
  ```
- **回傳字典格式**：
  ```gdscript
  {
      "best_action": int,          # 0 ~ 8
      "best_action_name": String,  # 行為名稱 (如 "吃東西")
      "target_location": int,      # 目標地點 POI 代碼 (0 ~ 25)
      "scores": PackedFloat32Array,# 9 個行為的機率 (若為規則強制則為空)
      "poi_scores": Array,         # 26 個地點的機率 (Transformer 模式下提供)
      "is_rule_override": bool,    # 是否觸發作息規則覆蓋
      "is_work_schedule": bool,    # 是否為官方工作崗位出勤
      "override_reason": String,   # 覆蓋原因 (如 "飢餓度過低 (25.4 < 30.0)，緊急原地享用便當/料理充飢")
      "decision_mechanism": String # 決策機制 ("transformer_policy", "ai_mlp", "rule_override", "pure_transformer")
  }
  ```

#### `is_transformer_active() -> bool`

- **說明**：查詢 Causal Transformer 決策大腦模型 (`universe_policy_transformer.onnx`) 是否已成功初始化並啟用。

#### `set_pure_transformer(enable: bool) -> void`

- **說明**：切換決策模式。若設為 `true`，除極端飢餓瀕死自救與重傷急診之底線安全守門員外，其餘所有作息、上班與地點皆由 Transformer 模型端到端自主驅動。

#### `evaluate_transformer(stats: PackedFloat32Array, current_tick: int, job_id: int, home_poi: int, prev_action: int = 0) -> Dictionary`

- **說明**：直接調用 Transformer 決策大腦進行單步前向推論，回傳 `{ "success": bool, "best_action": int, "best_poi": int, "action_scores": Array[float], "poi_scores": Array[float] }`。

#### `get_location_by_action(action_index: int, food_count: int, lunchbox_count: int, home_id: int, job_id: int) -> int`

- **說明**：依據行為代碼與當前攜帶物資，計算出對應的目的地 POI ID。

#### `is_available_for_social(current_action: int, is_at_home: bool = false) -> bool`

- **說明**：判斷該 NPC 當前是否處於可進行社交互動的狀態（若正在工作、就醫、閱讀、在家休息則回傳 `false`）。

#### `is_social_engine_available() -> bool`

- **說明**：查詢原生 C# ONNX 社交決策模型推論引擎是否已成功加載並就緒。

#### `evaluate_social(time: float, social_desire: float, mood: float, favorability: float, distance: float, days_since_interaction: float, history_score: float = 0.5) -> float`

- **說明**：透過 7 維社交特徵評估針對特定目標 NPC 的互動意願分數（0.0 ~ 1.0）。

#### `evaluate_social_candidates(time: float, social_desire: float, mood: float, candidates: Array) -> Dictionary`

- **說明**：批次評估半徑 32 格內的候選 NPC 陣列，並透過立方指數放大加權輪盤機率（$score^3$ Exponential Roulette Wheel Selection）選出互動目標。強化首選（Top 1）權重，降低隨機噪聲，為 Transformer 訓練產出高因果性軌跡。
- **輸入 `candidates` 格式**：`Array[Dictionary]`，每個字典格式為 `{ "id": int, "distance": float, "favorability": float, "days_since_interaction": float, "history_score": float }`。
- **回傳字典格式**：
  ```gdscript
  {
      "target_id": int,              # 指數加權輪盤選中之目標 ID (-1 表示無適合目標)
      "highest_target_id": int,      # 分數最高之首選目標 ID
      "highest_score": float,        # 首選目標之意願評分 (0.0 ~ 1.0)
      "score": float,                # 選中目標之意願評分 (0.0 ~ 1.0)
      "candidate_scores": Dictionary,# 各候選者原始分數字典 { target_id: score }
      "candidate_probs": Dictionary  # 各候選者立方放大選中機率字典 { target_id: prob }
  }
  ```

#### `decide_social_action(target_id: int, has_spread_message: bool = false, favorability: float = 50.0, mood: float = 50.0) -> int`

- **說明**：決定具體社交行為代碼（1=普通聊天, 2=討論主題, 3=詢問問題, 4=共同活動, 5=捉弄, 6=欺騙, 7=訊息傳播）。
- **啟發式階層機率分佈 (消滅純隨機，確保高信噪比 Transformer 資料)**：
  - **若 `has_spread_message == true`**：固定為 `7` (訊息傳播)。
  - **仇視關係 (`favorability < 35.0`)**：
    - 心情低落 (`mood < 40.0`)：40% 捉弄(5), 30% 欺騙(6), 20% 詢問問題(3), 10% 普通聊天(1)。
    - 心情尚可 (`mood >= 40.0`)：50% 詢問問題(3), 30% 普通聊天(1), 10% 捉弄(5), 10% 欺騙(6)。
  - **熟識與好友 (`favorability >= 65.0`)**：
    - 心情良好 (`mood >= 50.0`)：50% 共同活動(4), 30% 討論主題(2), 15% 普通聊天(1), 5% 詢問問題(3)。
    - 心情欠佳 (`mood < 50.0`)：45% 討論主題(2), 35% 普通聊天(1), 15% 詢問問題(3), 5% 共同活動(4)。
  - **破冰與普通交往 (`35.0 <= favorability < 65.0`，包含初始 50)**：
    - 70% 普通聊天(1), 20% 詢問問題(3), 7% 討論主題(2), 3% 共同活動(4)。

#### `get_social_action_name(action_id: int) -> String`

- **說明**：取得社交行為代碼對應的中文名稱。

#### `initialize_memory_database(db_path: String = "res://NPC_Memory.db", force_reset: bool = false) -> bool`

- **說明**：對應流程圖「圖 1 (新遊戲)」，於 SQLite 初始化 6 大記憶資料表（STSM, MTSM, LTSM, STM, MTM, LTM）並寫入預設數值。

#### `has_memory_database(db_path: String = "res://NPC_Memory.db") -> bool`

- **說明**：檢查記憶資料庫實體檔案是否存在。

#### `load_npc_startup_data(npc_id: int, db_path: String = "res://NPC_Memory.db") -> Dictionary`

- **說明**：對應流程圖「圖 1 (讀取存檔)」，依序從 MTM 載入數值、從 LTM 載入權重與詞條、從 LTSM 載入信任與好感，並從 MTSM 統計歷史正向事件比例計算歷史分數。
- **回傳結構**：包含 `stats`（生理數值）、`entries`（12 項詞條）、`action_weights`（9 項權重）、`trust`、`friendships`、`history_scores` 與 `success: bool`。

#### `store_npc_entry(npc_id: int, traits_dict: Dictionary, db_path: String = "res://NPC_Memory.db") -> bool`

- **說明**：對應流程圖「圖 1 (新遊戲)」，將玩家或模板設定的 12 大性格詞條寫入 LTM 資料庫。

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

#### `is_exhausted: bool`

- **說明**：體力耗盡休養狀態標記（遲滯保護 Hysteresis）。當體力 `< 25.0` 時自動設為 `true`，直至體力恢復至 `>= 75.0` 方才解除為 `false`。在此期間決策大腦嚴禁指派工作，徹底杜絕在家與工作崗位間來回奔波。

#### `tick_update(delta_ticks: int = 1, is_sleeping: bool = false, is_working: bool = false) -> void`

- **說明**：依據推進的 Tick 數，計算飽食度下降 (`0.03/tick`，每天約 43 點)、體力升降（工作 `0.04/tick`、日常 `0.015/tick`、睡眠回體 `0.35/tick`）、健康度聯動與修飾器結算。當飽食度降至 0 時觸發**飢荒飢餓衰竭機制**：每 Tick 健康度損失 `0.2`、生命值 (`hp`) 損失 `0.3`；當健康度過低 (`health < 20.0`) 進入生病重症狀態，每 Tick 額外扣除生命值 `0.15`，促使其前往醫院就醫；生命值歸零時發射 `hp_depleted(npc_id)` 訊號。

#### `add_item(item_type: String, amount: int = 1) -> void` / `consume_item(item_type: String, amount: int = 1) -> bool`

- **說明**：管理物品與金錢的增加與消耗。

#### `eat_food(prefer_lunchbox: bool = true) -> bool`

- **說明**：執行進食，扣減便當或料理。食用便當回復飽食度 `+55.0`、體力 `+35.0` (由原本 +20 提升)、心情 `+15.0`；食用料理回復飽食度 `+45.0`、體力 `+25.0` (由原本 +15 提升)、心情 `+10.0`。若成功進食回傳 `true`，無存糧回傳 `false`。

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

#### `get_active_ltm_trait_labels() -> Array[String]`

- **說明**：自 `ltm_entries`（12 大靈魂性格特質布林開關）中讀取為 `true` 的項目，並映射為中文性格標籤陣列（如 `["社交達人", "樂觀開朗", "大E外向"]`）。若無啟用項目則退回預設之 `ltm_traits` 職業標籤。

#### `get_history_score_to_npc(target_num: int) -> float`

- **說明**：取得對指定 NPC 編號（1 ~ 20）之 10 天歷史事件好壞分數（`0.0 ~ 1.0`，預設 `0.5`）。此分數作為 7 維社交 ONNX 模型之歷史維度輸入，亦在觀測 UI 呈現為正向互動率百分比。

#### `last_social_evaluation: Dictionary`

- **說明**：快取最近一次社交互動決策之完整評估快照。包含欄位：
  - `target_id: String`：對象 NPC 代號（如 `"npc_02"`）。
  - `target_name: String`：對象名稱（如 `"NPC 02 (露娜)"`）。
  - `score: float`：7 維 ONNX 意願評分（`0.0 ~ 1.0`）。
  - `action_id: int`：選定之 1~7 具體社交行為代碼。
  - `action_name: String`：行為中文名稱。
  - `timestamp: String`：互動時間字串（如 `"第 1 天 12:30"`）。
  - `is_initiator: bool`：本 NPC 是否為主動發起方。
  - `history_score: float`：互動時雙方的 10 天歷史好壞分數。
  - `delta_fav: float` / `delta_trust: float` / `delta_mood: float`：本次社交產生的 STSM 記憶數值反饋量。

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

- **說明**：標記該 NPC 當前是否已被另一位居民選為社交對象。社交發起者會將其鎖定，防止全鎮多人同時朝向同一名 NPC 移動造成同格聚集。帶有 `MAX_SOCIAL_TARGET_TICKS = 15`（15 遊戲分鐘）超時保護機制，若發起方途中受阻或被中斷，計時達標後將自動解鎖，避免對象永久定格。

#### `行動超時看門狗 (Action Timeout Watchdog)`

- **常數**：`MAX_ACTION_TICKS: int = 60`（60 遊戲分鐘 = 1 遊戲小時）。
- **說明**：為防止任何尋路、Tween 播放、異步計時器或協程未釋放導致 `_is_executing_action` 殘留，NPC 在每次 Tick 推進時若處於執行行動中，計數器遞增。一旦超過 60 Ticks，立即強制觸發 `_abort_and_reset_action()`，斬斷殘留狀態並恢復至待機狀態，確保 AI 決策入口暢通。

#### `生理飢餓強制自救中斷 (Emergency Survival Interrupt)`

- **觸發條件**：`npc_data.hunger < 20.0` 且目前非進食狀態 (`current_action_id != 3`)，或接收到 `npc_data.hunger_critical` 訊號。
- **說明**：緊急生存最高優先級中斷。強制中止當前進行中的任何常規、工作或社交行為，自動執行求生三階自救：
  1. **原地進食**：若身上有便當、料理、背包農作物或生鮮魚類，立即就地食用；
  2. **前往餐廳**：若身上無儲糧但手頭資金充裕 (`money >= 3`)，火速前往 POI 13（餐廳）進食與補購便當；
  3. **應急充飢底線**：若既無口糧亦無金錢，原地摘野果/飲水應急充飢（飽食度 `+15.0`），徹底避免居民在任何角落活活餓死。

#### `_abort_and_reset_action() -> void`

- **說明**：強制中止目前卡住或超時的行動。立即銷毀位移 Tween、清空尋路隊列、重設動作計時器與看門狗計數器、解除社交鎖定與夥伴關聯，並重設狀態為 `State.IDLE`。

#### `die(cause: String = "飢餓衰竭") -> void`

- **說明**：手動或因生命值歸零觸發死亡。清空看門狗計數器、中斷當前行為、停止 Tween 位移、停止氣泡並觸發倒地展演（旋轉 90 度躺平、畫面調暗變灰 `Color(0.45, 0.45, 0.5)`），主動調用 `TrajectoryLogger.log_death_step` 寫入終端負向樣本，並向全域發射 `Global.on_npc_died` 死亡廣播。

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

#### `get_nearby_social_candidates() -> Array[Dictionary]`

- **說明**：即時掃描並評估周遭 32 格內之其他非隱蔽、活著的村民。若 C# ONNX 社交模型就緒，即刻調用 7 維神經推論計算各候選人之社交意向評分；若未就緒則透過好感與距離權重估算。
- **回傳值**：排序後的候選人字典陣列 `Array[Dictionary]`，每個元素包含：
  - `id: int`：候選者數值編號（如 `2`）。
  - `str_id: String`：候選者字串編號（如 `"npc_02"`）。
  - `name: String`：候選者姓名（如 `"露娜"`）。
  - `distance: float`：距本 NPC 之網格地塊距離。
  - `favorability: float`：本 NPC 對該目標之好感度。
  - `days_since_interaction: float`：距上次互動天數。
  - `history_score: float`：10 天歷史事件好壞分數。
  - `score: float`：ONNX 社交意願評分（`0.0 ~ 1.0`）。

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
| **1: 閱讀 (Read)** | POI 19 (圖書館) | 無 | 心情 `+20.0`<br>體力 `-1.0` | 閱讀充實精神境界，高度改善心情，微量消耗體力。 |
| **2: 購物 (Shop)** | POI 13 (餐廳) 或 POI 12 (商店) | 金錢 `-3` 購買便當或料理 | 心情 `+10.0` | 預先購買存糧（道具表售價 $3），儲備後續原地進食之資源。 |
| **3: 吃東西 (Eat)** | POI 13 (餐廳) 或 POI 0 (原地) | 餐廳：金錢 `-3`<br>原地：消耗便當或料理 | 餐廳：飽食 `+60`、體力 `+35`、心情 `+20`<br>原地：便當飽食 `+55`、體力 `+35`、心情 `+15`；料理飽食 `+45`、體力 `+25`、心情 `+10` | **外帶備份便當**：若在餐廳用餐且身無便當尚有餘額，自動加購 1 個外帶便當備用。<br>**救濟愛心熱湯防呆**：若 NPC 無錢亦無糧，餐廳提供愛心熱湯 (飽食 `+40`、體力 `+20`、心情 `+10`)，杜絕餓死在餐廳門口。<br>**原地自救防呆**：原地若無便當，依序食用生鮮作物/魚或野果。 |
| **4: 就醫 (Medical)** | POI 18 (醫院) | 金錢 `-5` (掛號醫療費) | 健康 `+45.0`<br>生命 `+35.0`<br>體力 `+20.0`<br>心情 `+15.0` | 全面治療傷病與虛弱狀態，恢復生理指標。 |
| **5: 回家休息 (Rest)** | POI 1~11 / 21 (自宅) | 無 | 體力 `+35.0`<br>心情 `+15.0`<br>生命 `+15.0` (健康良好時) | 居家安歇，快速恢復體力與精神。具備遲滯保護，體力未回升至 75.0 前持續休息。 |
| **6: 社交 (Social)** | POI 20 (廣場) 或 夥伴身旁 | 無 | 社交慾望 `+40.0`<br>心情 `+15.0`<br>好感/信任 `+3/+2` | 雙向同步補足社交慾望缺口，加深鄰里情誼。 |
| **7: 巡田水 (Patrol)** | POI 16 (農田) | 農作物 `+1` | 心情 `+6.0` | 農夫特有巡視田埂並採收作物。體力消耗由 `tick_update` 平滑進行，避免單次重度扣除。 |
| **8: 販售物品 (Sell)** | POI 12 (商店/市場) | 出售庫存變現 (依道具表定價)：<br>作物 `+$5`、礦石 `+$2`、魚 `+$2`、木頭 `+$2`、石頭 `+$1` | 心情 `+15.0` | 將生產勞動所得變現為流動資金。若無物可賣則打零工領取基礎津貼 `+$1`。 |
| **崗位執勤 (Work)** | 職業專屬 POI 12~19 | 依各職業產出資源或領取工資 | 平滑代謝推進 (取消單次扣減) | 勞動生理消耗全面改由每 Tick 之 `STAMINA_DECAY_WORK` (0.04/tick) 與 STM 結算平滑演化，徹底杜絕單次暴扣 10 體力引發之回家乒乓死循環。 |

- **工作排程判定修正 (`is_work_schedule`)**：
  - 決策大腦嚴格將「工作排程 (`is_work_schedule`)」與一般規則覆蓋（如就寢時間、緊急求生、三餐用餐）分離。
  - 確保 NPC 在三餐時間前往餐廳或原地用餐時，專注於「進食與恢復飽食度」，不再被誤判為執勤工作。

---

## 8. NPC 生成工廠：NPCSpawner (`scripts/entities/npc_spawner.gd`)

繼承自 `Node2D` 的資料驅動型生成工廠，負責解析 `data/poi_locations.json` 註冊全域 POI 座標、讀取 `data/npc_templates.json` 模板、動態實例化 NPC 實體、組裝 4 向 SpriteFrames 動畫貼圖並注入獨立的 `NPCData`。

### 8.1 職責與架構

- **資料驅動 (Data-Driven)**：完全與代碼分離，新增或調整 NPC 屬性、住宅、工作地點僅需編輯 JSON。
- **動態換皮 (Dynamic Skinning)**：傳入 16x32 (4 欄 x 4 列) 的 Sprite Sheet 貼圖路徑，於記憶體中自動切分出 `walk_down`、`walk_left`、`walk_right`、`walk_up` 動畫幀，無需在編輯器中重複切圖。
- **個體資料獨立注入**：為每一位生成的 NPC 實例化專屬的 `NPCData` 物件，確保生命、飽食度與物品庫存相互獨立。開局配給安全保障：預設飽食度 `90.0`，且每位村民開局保底配給至少 1 個隨身便當 (`lunchbox >= 1`)，杜絕剛開局時發生意外飢餓暴斃。
- **安全座標配置**：NPC 出生時自動定位至所屬自宅（`home_poi_id`）的網格座標中心。

### 8.2 匯出參數 (Exports)

| 屬性名稱                    | 型別             | 預設值  | 說明                                                                                                   |
| :-------------------------- | :--------------- | :------ | :----------------------------------------------------------------------------------------------------- |
| `spawn_count`               | `int` (`1 ~ 20`) | `20`    | 遊戲啟動時生成之 NPC 數量（預設為全鎮 20 隻完整運轉）                                                 |
| `auto_spawn_on_ready`       | `bool`           | `true`  | 是否在進入場景樹 `_ready` 時自動執行 POI 註冊與 NPC 批量生成                                           |
| `load_existing_memory_save` | `bool`           | `false` | 是否載入現有記憶資料庫（對應圖 1：是否讀取存檔）。預設為 `false` 全新開局，強制初始化 SQLite 6 大資料表為健康滿狀態並寫入模板詞條；手動勾選時才自現有存檔載入。 |

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
- **三分頁頁籤卡片架構 (Tri-Tab Card Layout)**：面板尺寸設定為 460x280 像素，採用 `TabContainer` 分流呈現複雜數據，視覺乾淨俐落：
  - **分頁 1：📊 生理與決策 (Physiology & Decision Tab)**：
    - **日常決策神經網絡 (左欄)**：顯示推論引擎狀態標籤（C# ONNX Runtime 或 GDScript Fallback）、當前行為意圖與目標 POI、決策模式（規則覆蓋原因或神經自主決策）、15 維度神經模型輸出評分最高的 Top 2 機率柱狀進度條，以及 **🎯 LTM 行為習慣加權**（展示午夜記憶結算後的演化成果，如工作 1.25x | 進食 1.10x）。
    - **生理數值與庫存 (右欄)**：即時彩色雙欄進度條呈現生命、健康、體力、飽食度、社交慾望、心情（0~100 帶百分比與數值顏色警告），以及持幣量與背包 7 類物品（木/石/礦/作物/魚/料理/便當）持有數量。
  - **分頁 2：🧠 社交與記憶 (Social & Memory Tab)**：
    - **社交 ONNX 神經大腦 (左欄)**：
      - **推論引擎特徵**：標記 `🚀 C# ONNX (時/慾/心/好/距/天/史 7維特徵)`。
      - **最新社交互動**：顯示最近一次社交對象、ONNX 意向評分百分比（如 `NPC 02 (露娜) (評分: 82.5%)`）。
      - **社交行為 (1~7 動作圖示)**：顯示具體行為（`💬 普通聊天`、`💡 討論主題`、`❓ 詢問問題`、`🤝 共同活動`、`🎭 捉弄他人`、`🤫 欺騙隱瞞`、`📢 訊息傳播`）與角色扮演（發起/回應）。
      - **STSM 記憶反饋效果**：顯示本次社交對好感度、信任度與心情的即時影響數值（如 `好感 +3.0 | 信任 +2.0 | 心情 +15.0`）。
      - **📡 周遭 NPC 意向雷達 (32格)**：即時評估身邊村民的 ONNX 意願評分與距離（如 `• NPC 02 (露娜): 意向 78.4% (4.2格)`），將模型對身邊各角色的選擇傾向完整透明化。
    - **靈魂記憶系統觀測區 (右欄)**：
      - **長期性格特質 (LTM Traits)**：自 SQLite LTM 資料庫的 12 大性格詞條映射真實中文徽章（如 `[社交達人] [樂觀開朗] [大E外向]`）。
      - **中長期人際網絡 (MTM / LTSM)**：排序顯示熟識居民的好感度、信任度，並附帶 **10 天歷史事件正向率**（如 `NPC 02 (好感 75/信 68 | 歷史 100% 正向)`）。
      - **近期生活與社交日誌 (STM Events)**：展示最新生活經歷與面對面社交互動紀實。
  - **分頁 3：🤝 人際網絡 (Relationships & Favorability Matrix Tab)**：
    - **全鎮 19 位居民排行榜**：動態依據好感度由高至低自動排序，相同時以信任度降序排列。
    - **同居伴侶識別徽章**：若對象與目前選中 NPC 居住於同一住宅（相同 `home_poi_id`），特殊標示高亮「`🏠同居`」粉紅徽章；其餘 NPC 則標示其職業標籤（如 `[礦工]`、`[圖書館員]`）。
    - **五大好感階層色籤**：
      - `[莫逆之交]` ($\ge 80.0$, 晶瑩粉紅)
      - `[志同道合]` ($65.0 \sim 79.9$, 活力青綠)
      - `[點頭之交]` ($45.0 \sim 64.9$, 平和淡藍)
      - `[淡漠生疏]` ($25.0 \sim 44.9$, 警戒橘黃)
      - `[交惡宿敵]` ($< 25.0$, 敵意鮮紅)
    - **彩色迷你進度條與數值**：條列呈現好感進度條與精確數值（如 `好感:78 信:65`）。
    - **一鍵聚焦切換按鈕 (`🔍`)**：點擊任一列的放大鏡按鈕，攝影機鏡頭立即平滑移動至該 NPC，同時將觀測面板無縫切換至該居民。
    - **高效原地更新架構**：以節流定時器（每 0.5 秒）原地覆寫 Label 與 ProgressBar 內容，滾動列表時完全不觸發重構，滾動位置零跳動、零 GC 負擔。
- **純代碼生成 (Pure Code Driven)**：UI 節點均以純 GDScript 動態構建，完全不需要建立或維護 `.tscn` 場景。
- **鏡頭聚焦連動**：提供「鏡頭鎖定/平移」按鈕，點擊後自動平滑平移至選中的 NPC。
- **操作防呆**：支援點擊其他 NPC 無縫切換、點擊右上角 `[✕]` 或按鍵盤 `ESC` 鍵立即關閉。

### 9.2 公開方法 (Public Methods)

#### `inspect_npc(npc: Node2D) -> void`

- **說明**：選中並開始檢視指定 NPC 實體，開啟懸浮面板並動態更新資訊。

#### `close() -> void`

- **說明**：關閉觀測視窗並取消全域選中狀態。

---

## 10. 記憶系統與換日結算管線 (Memory System & Midnight Settlement Pipeline)

本系統依據五大架構流程圖（圖 1 啟動載入、圖 2 決策執行整體路徑、圖 3 一般決策、圖 4 社交決策、圖 5 換日結算記憶處理）實裝，底層整合 SQLite 6 大資料表（`STM`, `STSM`, `MTM`, `MTSM`, `LTM`, `LTSM`）與 C# 運算程式庫（`UseDatabase.cs`, `computeAttribute.cs`）。

### 10.1 C# 記憶橋接層：NPCDecisionBridge (`ai_models/NPCDecisionBridge.cs`)

#### `SaveNormalActionMemory(int npcId, int time, Godot.Collections.Dictionary statsDict, int action, int location, bool isSuccess, string dbPath = "res://NPC_Memory.db") -> Godot.Collections.Dictionary`

- **對應流程**：圖 2 (行動完成或失敗 -> 計算數值增減 -> 儲存至 STM)。
- **說明**：
  1. 將 Godot 生理數值字典映射為 `npc_class.PhysiologicalStats`。
  2. 透過 `attributeCalculator.ComputeNormalAttributes` 計算本次行動產生的數值增減量 (`ChangedStateValue`)：
     - **勞動體力消耗平抑**：巡田水/勞動 (Action 7) 單次體力消耗調降為扣除 2~5 點 (原 10~20 點)。
     - **進食體力回補齊全**：原地食用食物體力回補 +25~+35 點，食用便當體力回補 +35~+45 點。
     - **閱讀情緒增量平抑**：閱讀 (Action 1) 心情增量平抑為 +8~+16 點 (原 +25~+40 點)，消除日均 +95 離譜回報斷層。
  3. 透過 `attributeCalculator.ComputeRewardValue` 計算 Reward 分數：
     - **即時產出資產估值**：引入採集物資估值 (農作物 $\times 0.5$, 礦物 $\times 0.4$, 木材 $\times 0.3$, 石材 $\times 0.2$, 魚 $\times 0.4$) 抵消體力扣除，使實體勞動獲得 +0.5 ~ +1.5 正向即時回報。
  4. 呼叫 `UseDatabase.SaveMemory` 將單筆記錄寫入 SQLite `STM` 資料表。
- **回傳值**：包含 `change_hp`, `change_health`, `change_stamina`, `change_hunger`, `change_social_desire`, `change_mood`, `change_money`, `change_food`, `change_lunchbox`, `reward_value`, `success` 等欄位之字典。

#### `EvaluateSocialCandidates(float time, float socialDesire, float mood, Godot.Collections.Array candidates) -> Godot.Collections.Dictionary`

- **對應流程**：圖 4 (批次評估 32 格內社交對象 -> 立方指數放大加權輪盤抽樣)。
- **說明**：
  1. 遍歷 candidates，調用 `NPCSocialDecision.Evaluate` 計算各目標 7 維神經意願分數 (0.0 ~ 1.0)。
  2. 計算立方權重 $w = score^3$，建立加權機率分佈字典 `candidate_probs`，大幅拉開首選目標與平庸目標的選中差距。
  3. 透過指數加權輪盤抽樣選出最終互動對象，兼顧因果確定性 (Exploitation) 與極低機率之探索性 (Exploration)。
- **回傳值**：包含 `target_id`, `highest_target_id`, `highest_score`, `score`, `candidate_scores`, `candidate_probs` 之字典。

#### `DecideSocialAction(int targetId, bool hasSpreadMessage = false, float favorability = 50f, float mood = 50f) -> int` / `DecideSocialActionHeuristic(...) -> int`

- **對應流程**：圖 4 (決定社交動作選項)。
- **說明**：
  1. 依據發起者對目標的好感度 (`favorability`) 與發起者心情 (`mood`)，透過動態階層機率分佈決定行為代碼 (1~7)：
     - **情緒低落 (`mood < 45f`)**：大幅提升負向社交與日常摩擦機率，觸發捉弄 (5, 20%)、欺騙 (6, 15%)、詢問問題 (3, 25%) 與普通聊天 (1, 40%)，打破過往好感度只增不減的「烏托邦偏差」。
     - **一般關係與破冰期 (`35f <= favorability < 65f`) 且心情正常**：賦予日常小摩擦機率：普通聊天 60%、詢問 20%、討論 10%、捉弄 5%、欺騙 5%。
     - **熟識與好友 (`favorability >= 65f`) 且心情良好**：共同活動 45%、討論主題 35%、普通聊天 15%、友善玩笑捉弄 5%。
     - **宿敵關係 (`favorability < 35f`) 且心情正常**：詢問 40%、聊天 30%、捉弄 15%、欺騙 15%。
  2. 若持有可傳播訊息 (`hasSpreadMessage`) 則固定回傳 7 (訊息傳播)。

#### `SaveSocialActionMemory(int sourceId, int targetId, int time, int socialAction, Godot.Collections.Dictionary sourceSocial, Godot.Collections.Dictionary targetSocial, string dbPath = "res://NPC_Memory.db") -> Godot.Collections.Dictionary`

- **對應流程**：圖 4 (決定社交動作選項 -> 嘗試行動 -> 計算數值增減 -> 儲存至 STSM)。
- **說明**：
  1. 實例化雙方 NPC 之 `NPCclass` 並注入好感度與信任度。
  2. 透過 `attributeCalculator.ComputeSocialAttributes` 計算社交互動後雙方的心情、信任度、好感度與體力增減。
     - **普通聊天 (1)**：破冰門檻調整為 `>= 40`，給予穩定正向好感獎勵 (+2 ~ +5)；`< 40` 則產生輕度尷尬或摩擦。
     - **討論主題 (2)**：信任門檻調整為 `>= 45`，產生深度共鳴與好感/信任加成。
     - **詢問問題 (3)**：雙向正面反饋，請教者與受請教者雙方心情與好感皆有微量增長。
     - **共同活動 (4)**：成功率依雙方好感平均動態調整 (70% ~ 90%)，成功大幅拉近好感度 (+7 ~ +15)。
     - **事件類型判定 (`DetermineSTSMType`)**：總增減量 > 0 判定為正向 (1)，< 0 判定為負向 (-1)，捉弄/欺騙固定為負向 (-1)。
  3. 呼叫 `UseDatabase.SaveMemory(sourceNPC, targetNPC)` 寫入 2 筆雙向記錄至 `STSM` 資料表。
- **回傳值**：包含 `source` 與 `target` 之數值增減字典及 `success` 標記。

#### `ExecuteMidnightSettlement1(string dbPath = "res://NPC_Memory.db") -> bool`

- **對應流程**：圖 5 換日結算前半（步驟 1 ~ 5）。
- **說明**：
  1. `SettleSTM()`：聚合當日 STM 中各行動之總 Reward，調用 `ComputeWeight` 計算新權重並更新至 `LTM`，隨後清空 `STM`。
  2. `SettleMTSM()`：將所有中短期社交記憶重要性遞減 1 (`importance - 1`)，清理無文字內容且 `importance <= 0` 的記憶。
  3. `SettleSTSM()`：將 STSM 所有當日互動紀錄透過 `DetermineSTSMType` 標記正負向並轉移至 `MTSM`（初始 `importance = 10`），隨後清空 `STSM`。
- **回傳值**：結算前半成功則回傳 `true`。

#### `ExecuteMidnightSettlement2(int npcId, Godot.Collections.Dictionary currentPhysiological, Godot.Collections.Dictionary currentTrust, Godot.Collections.Dictionary currentFriendships, string dbPath = "res://NPC_Memory.db") -> Godot.Collections.Dictionary`

- **對應流程**：圖 5 換日結算後半（步驟 6 ~ 10）。
- **說明**：
  1. `SaveState`：將 NPC 當前生理數值歸檔儲存至 `MTM`，將對其他 20 隻 NPC 之好感與信任存入 `LTSM`。
  2. `LoadHistoryEvent`：自 `MTSM` 重新計算該 NPC 與其他 20 位 NPC 之 10 天歷史事件好壞比例（`HistoryScores`，0.0~1.0）。
  3. `LoadActionWeights`：自 `LTM` 讀取最新演化之一組 9 個行為加權權重（`ActionWeights`）。
- **回傳值**：`{ "success": true, "action_weights": Array[float], "history_scores": Array[float] }`。

---

### 10.2 GDScript 決策大腦服務：NPCDecisionService (`scripts/ai/decision_service.gd`)

#### `evaluate_decision(current_tick: int, stats: PackedFloat32Array, home_id: int, job_id: int, food_count: int, lunchbox_count: int, personality_offset: PackedFloat32Array = PackedFloat32Array(), npc_id: String = "", action_weights: Array = [], is_resting: bool = false) -> Dictionary`

- **對應流程**：圖 3 (一般決策全流程)。
- **更新**：
  1. **體力休養晝夜分流 (封鎖白天返家大睡)**：
     - 白天時段 (06:30 ~ 21:30, tick 390~1290) 嚴禁觸發返家睡眠 (Action 5)。
     - 白天體力偏低 (`stamina < 30.0`) 時，若有存糧或身懷金錢優先引導進食 (`Action 3`) 回補體力；若無則在原地小憩摸魚 (`Action 0`)，徹底消除白天全體跑回家大睡的假死現象。
     - 僅在夜間時段 (21:30 ~ 06:30) 體力透支或就寢時間才允許返家就寢大睡 (`Action 5`)。
  2. **購物行為 (Action 2) 初步活化**：
     - 當居民持有金錢充足 (`money >= 6`) 且身上無任何存糧 (`lunchbox == 0 and food == 0`) 時，在自由活動期間給予前往商店 (POI 12) 或餐廳 (POI 13) 採購儲糧的傾向 (50% 規則引導，神經分數 +0.35)。
  3. **LTM 行動權重與輪盤抽樣**：
     - 支援 `action_weights` 參數，在無排程覆寫時，依據 LTM 行動權重對 9 種行為分數加權，並調用 `SampleActionWithWeights` 進行輪盤抽樣。

#### `save_normal_action_memory(npc_id: int, time: int, stats: Dictionary, action: int, location: int, is_success: bool, db_path: String = "res://NPC_Memory.db") -> Dictionary`

- **說明**：轉發並呼叫 C# 橋接之一般行動執行期記憶儲存。

#### `save_social_action_memory(source_id: int, target_id: int, time: int, social_action: int, source_social: Dictionary, target_social: Dictionary, db_path: String = "res://NPC_Memory.db") -> Dictionary`

- **說明**：轉發並呼叫 C# 橋接之社交行動執行期記憶儲存。

#### `execute_midnight_settlement_1(db_path: String = "res://NPC_Memory.db") -> bool`

- **說明**：執行換日記憶結算前半管線。

#### `execute_midnight_settlement_2(npc_id: int, current_stats: Dictionary, current_trust: Dictionary, current_friendships: Dictionary, db_path: String = "res://NPC_Memory.db") -> Dictionary`

- **說明**：執行特定 NPC 之換日記憶結算後半管線，獲取最新權重與歷史好壞分數。

---

### 10.3 實體與全域單例整合

#### `NPCData.get_physiological_dict() -> Dictionary` (`scripts/entities/npc_data.gd`)
- **說明**：導出生理與物資欄位為符合 C# 規範之字典格式。

#### `NPCData.apply_stat_changes(changes: Dictionary) -> void` (`scripts/entities/npc_data.gd`)
- **說明**：套用行動結算後的數值改變量，包含邊界鉗制（Clamp）與 `stats_changed` 訊號廣播。

#### `NPCData.apply_settlement_data(new_weights: Array, new_history_scores: Array) -> void` (`scripts/entities/npc_data.gd`)
- **說明**：更新動態行為加權權重（`action_weights`）與人際歷史好壞分數（`history_scores`）。

#### `GlobalClass._execute_midnight_settlement() -> void` (`scripts/core/global.gd`)
- **說明**：於每日 00:00 (`current_tick == 0`) 跨日時自動觸發全域換日記憶結算，先執行前半清空與衰減管線，再遍歷全場 NPC 執行後半歸檔與數據同步。

---

## 11. Transformer 軌跡收集與 LLM 接口架構

為支援後續訓練 Transformer（決策軌跡模型 / Generative Agent）與接入小型大語言模型（SLM），專案提供了流式 JSON Lines 收集器與抽象語意接口。

### 11.1 社交語意與 LLM 接口：SocialSemantics (`scripts/ai/social_semantics.gd`)

#### `get_relationship_label(favorability: float, trust: float) -> String`
- **說明**：將數值化好感與信任映射為離散自然語言標籤（如「宿敵/互看不順眼」、「點頭之交/一般居民」、「莫逆之交/至交好友」），強化 Transformer Self-Attention 聚合效率。

#### `generate_topic(source_job: int, target_job: int, social_action_id: int, phase: String, favorability: float, mood: float) -> String`
- **說明**：依據雙方職業、行為類型與社交階段生成自然語意話題。

#### `add_rumor(author_name: String, subject_name: String, event_desc: String, day: int, tick: int) -> void` / `get_random_rumor() -> Dictionary`
- **說明**：小鎮情報傳播池（最多保留 30 筆近期事件），供行為 7（訊息傳播）擴散社會網絡情報。

#### `build_llm_prompt_context(...) -> Dictionary`
- **說明**：生成符合 ChatML / Alpaca 格式的 Prompt 字典。若外部有注入 `llm_dialogue_hook` 則動態生成對白，否則使用內建情境對話模板。

### 11.2 決策軌跡收集器：TrajectoryLogger (`scripts/ai/trajectory_logger.gd`)

#### `log_normal_action_step(npc_data: NPCData, current_tick: int, current_day: int, decision: Dictionary, exec_result: Dictionary = {}) -> void`
- **說明**：記錄單次日常生理行為（含 15 維輸入、決策機制、目標 POI、數值變化與即時 Reward）。

#### `log_social_interaction_step(source_ctrl: NPCController, target_ctrl: NPCController, current_tick: int, current_day: int, social_action_id: int, action_name: String, phase: String, s_changes: Dictionary, t_changes: Dictionary, candidates_radar: Array[Dictionary] = []) -> void`
- **說明**：記錄雙向社交互動（含 32 格候選人意願雷達、立方放大選中機率、發起與接受者心理變化、STSM 記憶與 LLM Prompt 上下文）。

#### `log_death_step(ctrl: NPCController, current_tick: int, current_day: int, death_cause_str: String) -> void`
- **說明**：記錄居民亡故事件（`step_type: death_event`），寫入死因、死亡當下網格座標、最後執行的行動與決策、最終生理與背包狀態，並附帶 `instant_reward: -1.0` 終端負面懲罰標記，最後立即調用 `flush()` 刷新至磁碟，為後續 Transformer 決策模型提供生存臨界與死亡規避之強化學習樣本。

#### `flush() -> void`
- **說明**：將記憶體緩衝區（每累積 15 步或跨日時自動觸發）批量寫入磁碟 `res://data/trajectories/episode_{timestamp}.jsonl`，保證 60 倍速下無感流暢。

#### `toggle_logging() -> bool`
- **說明**：切換錄製狀態（快捷鍵：`F6` 或點選 HUD 頂部按鈕）。

---

## 12. Transformer 決策大腦推論架構 (Causal Transformer Policy Engine)

專案已將 50 萬步模擬數據訓練完成之 Causal Transformer 策略大腦（`universe_policy_transformer.onnx`）全面整合至遊戲運行時中，為 20 位居民提供基於深度自注意力機制的端到端日常決策與目的地導航。

### 12.1 模型架構規格 (`res://ai_models/universe_policy_transformer.onnx`)

- **參數量與架構**：4 層 Causal Self-Attention Transformer，Embedding 維度 128，4 Multi-Head Attention，前饋維度 256，總參數量約 0.82M，模型體積僅 0.22MB。
- **推論延遲**：在 Mac Apple Silicon MPS / CPU 上單步推論耗時約 0.2 毫秒，支援單步 `(1, 1, D)` 與長時序列滑動窗口 `(1, L, D)`。
- **輸入規格**：
  1. `continuous_features` (`float32[batch_size, sequence_length, 15]`)：
     - 前 6 維：`hp`, `health`, `stamina`, `hunger`, `social_desire`, `mood`（0~100 線性歸一化至 0.0~1.0）。
     - 後 8 維：`money`（$\log1p / 10.0$）、`wood`, `stone`, `mineral`, `crops`, `fish`, `food`, `lunchbox`（$\log1p / 5.0$）。
     - 第 15 維：`tick_norm`（`tick / 1440.0`，0.0~1.0）。
  2. `discrete_features` (`int64[batch_size, sequence_length, 4]`)：
     - `period_id` (0~6，清晨、上午、中午、下午、傍晚、夜晚、深夜)。
     - `job_id` (1~9，職業編號)。
     - `home_poi` (0~25，自宅 POI 代碼)。
     - `prev_action` (0~8，上一時間步行為代碼)。
- **輸出規格**：
  1. `action_logits` (`float32[batch_size, sequence_length, 9]`)：9 種日常行為的對數機率分佈。
  2. `poi_logits` (`float32[batch_size, sequence_length, 26]`)：26 個目標 POI 地點的對數機率分佈。
- **訓練表現**：在 503,448 步真實模擬數據訓練下，行為 Top-1 達 97.34%（Top-3 達 99.89%），地點 Top-1 達 83.43%。

### 12.2 C# 原生推論類別與資源載入器 (`ai_models/NPCTransformerDecision.cs` / `ai_models/ModelResourceLoader.cs`)

- **資源載入器 (ModelResourceLoader)**：
  - 同時相容 Godot 虛擬檔案系統（`res://` 透過 `FileAccess.GetFileAsBytes()` 直讀記憶體，完美支援匯出 `.pck` 封裝包）與作業系統實體檔案路徑（`System.IO.File`）。
  - 方法：`Exists(string path) -> bool`, `LoadBytes(string path) -> byte[]`, `LoadText(string path) -> string`。
- **推論類別命名空間**：`Universe26`
- **實作介面**：`IDisposable`
- **核心方法**：
  - `NPCTransformerDecision(string onnxPath)`：透過 `ModelResourceLoader` 讀取二進制位元組並以 `InferenceSession(byte[], SessionOptions)` 在記憶體中建立推論 Session，設定循序執行與全圖優化，徹底免除打包後實體檔案找不到之痛點。
  - `EvaluateStep(float[] stats, int tick, int jobId, int homePoi, int prevAction) -> TransformerInferenceResult`：
    自動執行特徵連續化與對數縮放、離散時間段映射、Tensor 建構與前向傳播，經 Softmax 後輸出最佳行為與最佳地點。

### 12.3 C# 橋接器：NPCDecisionBridge (`ai_models/NPCDecisionBridge.cs`)

- **新增屬性與公開方法**：
  - `IsTransformerInitialized: bool`：回傳 Transformer 引擎是否成功載入。
  - `IsTransformerActive() -> bool`：供 GDScript 明確呼叫查詢 Transformer 引擎是否就緒。
  - `InitializeTransformer(string onnxPath = "res://ai_models/universe_policy_transformer.onnx") -> bool`：手動或自動載入 Transformer ONNX 模型。
  - `EvaluateTransformer(float[] stats, int tick, int jobId, int homePoi, int prevAction) -> Godot.Collections.Dictionary`：
    供 GDScript 呼叫之橋接方法，回傳包含 `success`, `best_action`, `best_poi`, `action_scores`, `poi_scores` 之字典。

### 12.4 雙模態決策機制與平滑降級 (Decision Modes)

1. **混合安全模式 (Hybrid Mode，預設)**：
   - 守門層：極端飢餓瀕死自救（`hunger < 30`）、極端負傷就醫（`health < 25`）。
   - 作息層：官方排程（三餐、就寢、上下班崗位）仍可作為固定規範。
   - 自由期：無排程干預時（規則 6），全權交由 Transformer 模型推論出行為與目的地 POI，徹底取代舊版靜態 MLP 與隨機地點挑選。
2. **純 Transformer 演繹模式 (Pure Transformer Mode)**：
   - 調用 `NPCDecisionService.set_pure_transformer(true)` 啟用。
   - 僅保留極端飢餓自救與重傷自救底線，其餘所有作息、上班、用餐與娛樂地點 100% 由 Transformer 自主預測演繹。
3. **無縫平滑降級**：
   - 若找不到 Transformer 模型或推論異常，自動降級至原有 5 層 MLP 決策模型；若無 C# 支援則降級至原生 GDScript 神經網路權重。
4. **社交活化與動態機率補償 (Social Drive Activation)**：
   - **規則 5.6 自由活動期社交激勵**：當居民社交慾望偏低（`social_desire < 45.0`）且無排程干預時，給予社交互動傾向，激勵前往廣場交流。
   - **神經分數動態加權補償**：在 Transformer、Pure Transformer 與經典 MLP 推論層中，根據居民社交慾望不足度（`social_desire < 65.0`）動態加權提升 Action 6（社交）分數，並在行為被選定後自動將目標引導至 POI 20（社交廣場），確保 Transformer 決策大腦能順利啟動下游的 Causal Social Transformer 人際交互。

---

## 13. Causal Social Transformer 社交大腦架構與推論服務 (Social Transformer System)

為突破傳統 MLP 與靜態決策樹在微觀人際互動中的「單點打分」與「規則硬湊」瓶頸，專案新增專門負責社交互動的 Causal Social Transformer。

### 13.1 模型架構規格：`universe_social_transformer.onnx`

- **模型架構**：Causal Social Transformer with Cross-Attention Pointer & Action Head (3 層 TransformerEncoder, 4 Heads, $d_{\text{model}}=64$, $d_{\text{ff}}=256$, GELU)。
- **參數量與大小**：168,711 參數 (~0.17M)，單檔獨立 ONNX 僅 **688 KB**，推論耗時 $<0.03\text{ms}$。
- **輸入特徵規格**：
  1. `initiator_features` (`float32[batch_size, 5]`)：發起者狀態 (時間, 社交慾望, 心情, 體力, 職業編號)。
  2. `candidates_features` (`float32[batch_size, 10, 5]`)：最多 10 位候選人雷達矩陣 (距離, 好感度, 間隔天數, 歷史分數, 目標職業)。
  3. `candidate_mask` (`float32[batch_size, 10]`)：有效候選人掩碼 (1.0=有效, 0.0=填充槽位)。
- **輸出特徵規格**：
  1. `candidate_scores` (`float32[batch_size, 10]`)：對各候選人之指針注意力 Softmax 意願機率。
  2. `action_probs` (`float32[batch_size, 10, 7]`)：端到端神經預測針對各目標的 7 大社交行為分佈 (普通聊天、討論主題、詢問問題、共同活動、捉弄、欺騙、訊息傳播)。
- **訓練表現**：在 20,335 筆真實社交軌跡訓練下，候選人選擇準確率達 **99.87%**，社交行為 Top-1 準確率達 **61.28%** (Top-2 達 **84.43%**)。

### 13.2 C# 原生推論類別：NPCSocialTransformerDecision (`ai_models/NPCSocialTransformerDecision.cs`)

- **命名空間**：`Universe26`
- **實作介面**：`IDisposable`
- **核心方法**：
  - `NPCSocialTransformerDecision(string onnxPath)`：載入 Social Transformer ONNX 模型並配置優化 Session。
  - `Evaluate(float time, float socialDesire, float mood, float stamina, int initiatorJobId, Godot.Collections.Array candidates) -> Godot.Collections.Dictionary`：
    將發起者特徵與雷達候選人矩陣轉換為張量前向推論，回傳包含 `target_id`, `highest_target_id`, `score`, `predicted_action_id`, `action_name`, `candidate_scores`, `candidate_probs`, `action_probs`, `is_transformer` 之字典。

### 13.3 C# 橋接器：NPCDecisionBridge (`ai_models/NPCDecisionBridge.cs`)

- **新增與更新公開方法**：
  - `IsSocialTransformerInitialized: bool`：回傳 Social Transformer 引擎是否成功就緒。
  - `IsSocialTransformerActive() -> bool`：供 GDScript 查詢社交 Transformer 是否啟用。
  - `InitializeSocialTransformer(string onnxPath = "res://ai_models/universe_social_transformer.onnx") -> bool`：載入 Social Transformer ONNX 模型。
  - `EvaluateSocialCandidates(float time, float socialDesire, float mood, Godot.Collections.Array candidates, float stamina = 50.0f, int initiatorJobId = 9) -> Godot.Collections.Dictionary`：
    更新方法簽章支援選填 `stamina` 與 `initiatorJobId`，當 Social Transformer 就緒時優先執行端到端指針選人與動作預測，未就緒時平滑回退至經典社交 MLP。

### 13.4 GDScript 決策服務 (`scripts/ai/decision_service.gd` & `npc_controller.gd`)

- **NPCDecisionService**：
  - `is_social_transformer_active() -> bool`：查詢 Social Transformer 是否已接管。
  - `is_social_engine_available() -> bool`：相容 Social Transformer 或社交 MLP 的可用性檢查。
  - `evaluate_social_candidates(...)`：自動向 C# 橋接器傳遞發起者之體力與職業資訊。
- **NPCController**：
  - `_find_available_partner()`：在調用候選人評估時傳遞自身體力與職業，獲取由 Social Transformer 計算之指針機率分佈。
  - `_start_mutual_conversation()`：優先採用 Social Transformer 預測之 `predicted_action_id`（消除人工決策樹硬湊），若為回退狀態才調用啟發式決策樹。

---

## 14. 存檔槽位系統 (Save Slots) 與 正式版主選單架構 (Main Menu & Model Selection)

本章節定義專案由「開發觀測期」過渡至「正式版本輸出」所新增之多槽位存檔系統、AI 決策模型切換介面與全螢幕主選單架構。

### 14.1 存檔槽位管理器：SaveSlotManager (`scripts/core/save_slot_manager.gd`)

- **職責**：管理 Slot 1 ~ 5 之多槽位 JSON 存檔與獨立 SQLite 記憶資料庫 (`.db`) 檔案 I/O，讀取存檔 Header 詮釋資料，並提供舊版單一存檔相容遷移與各槽位記憶嚴格隔離。
- **常數**：
  - `MAX_SLOTS: int = 5`：最大槽位數。
  - `SAVE_DIR_USER: String = "user://saves"`：主要實體存檔目錄。
  - `SAVE_DIR_DEV: String = "res://data/saves"`：編輯器與除錯鏡像目錄。
  - `LEGACY_SAVE_DEV: String = "res://data/savegame.json"`：舊版單一存檔路徑（Slot 1 自動對齊）。
- **訊號**：
  - `slot_saved(slot_id: int, metadata: Dictionary)`：槽位儲存成功時發射。
  - `slot_loaded(slot_id: int, metadata: Dictionary)`：槽位載入成功時發射。
  - `slot_deleted(slot_id: int)`：槽位刪除成功時發射。
- **公開方法**：
  - `get_slot_path(slot_id: int) -> String`：回傳主要 `user://` JSON 槽位路徑 (`user://saves/slot_X.json`)。
  - `get_slot_db_path(slot_id: int) -> String`：回傳該槽位專屬之獨立 SQLite 記憶資料庫路徑 (`user://saves/slot_X_memory.db`)。
  - `get_active_db_path() -> String`：回傳當前遊戲執行期活動記憶資料庫路徑 (`user://saves/active_memory.db`)。
  - `get_slot_dev_path(slot_id: int) -> String`：回傳開發鏡像路徑。
  - `get_slot_dev_db_path(slot_id: int) -> String`：回傳開發鏡像資料庫路徑。
  - `find_active_slot_path(slot_id: int) -> String`：探查有效檔案路徑。打包後的正式遊戲環境（非 Editor）嚴格只認 `user://`，杜絕 `.pck` 唯讀幽靈檔案干擾。
  - `get_slot_metadata(slot_id: int) -> Dictionary`：讀取存檔 Header 資訊，回傳包含 `slot_id`, `is_empty`, `current_day`, `formatted_time`, `timestamp`, `alive_count`, `total_count`, `average_mood`, `total_money`, `ai_model_name`, `app_mode_name` 之字典。
  - `get_all_slots_metadata() -> Array[Dictionary]`：一次性回傳 Slot 1 ~ 5 的完整詮釋資料列表。
  - `save_slot(slot_id: int) -> bool`：調用全域存檔寫入槽位 JSON，並原子化備份當前活動記憶資料庫至 `user://saves/slot_X_memory.db`，確保槽位記憶獨立性。
  - `load_slot(slot_id: int) -> bool`：將槽位專屬 `slot_X_memory.db` 還原至活動庫，並調用全域讀檔載入 JSON 還原實體狀態。
  - `delete_slot(slot_id: int) -> bool`：清理 SQLite 連線池鎖定，徹底刪除指定槽位之 JSON、專屬 `.db` 以及 `-wal`、`-shm`、`-journal` 輔助檔案。

### 14.2 存檔槽位互動選擇視窗：SaveSlotDialog (`scripts/ui/save_slot_dialog.gd`)

- **職責**：純 GDScript 動態渲染之通用 Slot 選擇彈窗，供主選單與遊戲內 HUD 調用。
- **列舉**：
  - `DialogMode.SAVE`：儲存 / 覆蓋模式。
  - `DialogMode.LOAD`：載入進度模式。
  - `DialogMode.MANAGE`：管理模式。
- **訊號**：
  - `slot_action_completed(mode: DialogMode, slot_id: int)`：當使用者完成儲存/讀取/覆蓋時發射。
  - `dialog_closed()`：彈窗關閉時發射。
- **核心方法**：
  - `open(mode: DialogMode) -> void`：以指定模式開啟 Slot 面板並刷新資料。
  - `close() -> void`：關閉彈窗。
  - `refresh_slots() -> void`：重新掃描並渲染 5 個 Slot 卡片。

### 14.3 獨立開始畫面：TitleScreen (`scripts/ui/title_screen.gd`)

- **職責**：獨立的遊戲開始畫面，提供極簡乾淨的介面與模型下拉選單。
- **介面元件**：
  - `OptionButton` 模型選擇下拉選單：僅提供 `Transformer` 與 `MLP` 兩大選項。
  - 核心功能按鈕：
    - `▶ 繼續遊戲`：若當前有進行中之遊戲會話（`Global.has_active_session`），顯示此按鈕供玩家無縫返回遊戲。
    - `✨ 開始新遊戲`：點選後調用 `Global.start_new_game(true)`，重置所有時間、清空並重建 6 大 SQLite 記憶庫、重新生成 20 位初始居民。若當前已有進行中進度，自動彈出二次確認視窗防止誤觸。
    - `📂 載入進度`：開啟 Slot 存檔槽位視窗。
    - `🔬 模擬觀測工具`：切換為模擬工具模式進入世界。
    - `⚙️ 居民性格設定`：開啟 NPC 詞條自訂視窗。
    - `🚪 離開遊戲`：安全退出遊戲處理程序。
- **核心方法**：
  - `show_screen() -> void`：顯示開始畫面並暫停遊戲時間，同時自動根據是否有進行中進度動態更新按鈕顯示。
  - `hide_screen() -> void`：隱藏開始畫面並標記 `has_active_session = true`，恢復遊戲時間。

### 14.4 遊戲內暫停選單：PauseMenu (`scripts/ui/pause_menu.gd`)

- **職責**：遊戲中按下 `ESC` 觸發的極簡暫停面板，無多餘冗贅文字。
- **核心功能**：
  1. `恢復遊戲 (Resume)`：恢復時間推進並關閉暫停視窗。
  2. `存檔 / 讀檔 (Save/Load)`：開啟存檔槽位管理面板。
  3. `✨ 重新開局 (新遊戲)`：遊戲中直接重新開局，彈出二次確認視窗後調用 `Global.start_new_game(true)` 重啟乾淨世界。
  4. `退回主畫面 (Return to Title)`：暫停並返回獨立開始畫面。
- **核心方法**：
  - `open() -> void`：開啟暫停視窗並暫停時間。
  - `resume() -> void`：關閉暫停視窗並恢復時間。

### 14.5 全域單例與決策服務擴充 API

- **Global (`scripts/core/global.gd`)**：
  - `enum AppMode { FORMAL_GAME = 0, SIMULATION_TOOL = 1 }`：應用程式運行模式枚舉。
  - `var current_app_mode: AppMode`：當前模式。
  - `var current_slot_id: int`：當前選定槽位 (1 ~ 5)。
  - `signal app_mode_changed(new_mode: AppMode)`：模式變更時廣播。
  - `signal ai_model_type_changed(new_type: int)`：AI 模型切換時廣播。
  - `get_save_slot_manager() -> SaveSlotManager`：獲取槽位管理器實例。
  - `set_app_mode(mode: AppMode) -> void`：切換模式（正式遊戲自動關閉軌跡 log 並限制速域 $\le 4\text{x}$；模擬工具模式啟用軌跡錄製與 60x 快進）。
  - `get_app_mode() -> AppMode`：查詢當前模式。
  - `set_ai_model_type(type: int) -> void`：設定 AI 決策模型。
  - `get_ai_model_type() -> int`：取得 AI 模型編號。
  - `get_ai_model_name() -> String`：取得 AI 模型名稱。
  - `save_to_slot(slot_id: int) -> bool`：快捷儲存至槽位。
  - `load_from_slot(slot_id: int) -> bool`：快捷自槽位載入。
  - `delete_slot(slot_id: int) -> bool`：刪除槽位。
- **NPCDecisionService (`scripts/ai/decision_service.gd`)**：
  - `enum AIModelType { DUAL_TRANSFORMER = 0, CLASSIC_MLP = 1, RULE_BASED = 2 }`
  - `var active_db_path: String = "user://saves/active_memory.db"`：當前活動資料庫路徑。
  - `set_active_database_path(path: String) -> void`：動態綁定活動記憶資料庫。
  - `get_active_database_path() -> String`：獲取當前活動記憶庫路徑。
  - `clear_database_connections() -> void`：釋放 SQLite 連線池檔案鎖定。
  - `copy_database(src_path: String, dst_path: String) -> bool`：跨資料庫檔案安全備份與複製。
  - `set_ai_model_type(model_type: int) -> void`
  - `get_ai_model_type() -> int`
  - `get_ai_model_name() -> String`

---

## 15. 緊急醫療救援與市民自主通報系統 (Emergency Medical Rescue & Bystander Reporting System)

實現昏厥倒地狀態保護、路人 NPC 視野掃描與主動呼叫救護、當班醫護人員在醫院無其他看診病患時主動接單出診、抵達施救甦醒及好感度飆升之完整社會化運作閉環。

### 15.1 核心流程與閉環機制

1. **倒地昏厥 (Fainted State)**：
   - 當 NPC 生命值歸零 (`hp <= 0.0`) 或極度過勞虛脫 (`stamina <= 0.0` 且 `hunger < 15.0`) 時，進入 `faint()` 狀態而非立即暴斃。
   - 角色旋轉 90 度躺平、顏色轉淡藍灰蒼白調，冒出 `💫 昏迷倒地！` 氣泡並停止一般移動與決策。
2. **路人自主通報 (Bystander Discovery & Reporting)**：
   - 周遭一般非隱藏市民在每 3 個 Tick 進行視野掃描（半徑 180 像素，約 11 格以內）。
   - 一旦發現未被通報的倒地昏迷者，路人立即面向目標並在頭頂彈出 `🚨 發現有人昏倒！已呼叫急救！` 氣泡，同時向全域調用 `Global.report_medical_emergency()`。
3. **當班醫生主動出診 (Doctor Emergency Rescue Dispatch)**：
   - 當班醫護人員（早班 `npc_09 Ivy` 07:00~15:00 / 晚班 `npc_10 Jack` 14:00~22:00）處於執勤時間。
   - 檢查醫院狀態：`!Global.is_hospital_busy()`（當前無其他市民在醫院 POI 18 接受門診醫療）。
   - 若存在待處理之緊急事件，醫生自動接單出診，頭頂冒出 `🚑 收到急救通報！立刻出診救援！` 並自動尋路導航至傷患身邊相鄰地塊。
4. **現場急救甦醒 (On-site Revival & Gratitude)**：
   - 醫生抵達後面向病患，進入施救狀態（顯示 `💉 正在實施急救復甦...`，持續 2.2 秒）。
   - 調用病患 `wake_up_from_faint()`：旋轉回正 0 度、體質回補（HP 60、健康 45、體力 45、飽食 35），對醫護人員好感度大幅飆升 `+40`，並顯示 `❤️ 感謝 {醫生姓名} 救了我！`。
   - 結案通報：調用 `Global.resolve_medical_emergency()`，醫生獲得心情加成 `+30` 與急救津貼 `$6`，並自動返回醫院崗位。

### 15.2 全域單例事件匯流排 API (`Global`)

- **訊號 (Signals)**：
  - `signal medical_emergency_reported(patient_id: String, location_cell: Vector2i, reporter_id: String)`：路人完成通報時廣播。
  - `signal medical_emergency_resolved(patient_id: String, doctor_id: String)`：急救完成結案時廣播。
  - `signal npc_fainted(npc_id: String, reason: String)`：NPC 昏厥時廣播。
  - `signal npc_revived(npc_id: String, doctor_id: String)`：NPC 甦醒時廣播。
- **公開方法 (Public Methods)**：
  - `report_medical_emergency(patient_id: String, world_pos: Vector2, location_cell: Vector2i, reporter_id: String) -> void`：登記緊急急救通報。
  - `resolve_medical_emergency(patient_id: String, doctor_id: String) -> void`：結案急救事件。
  - `is_emergency_active(patient_id: String) -> bool`：查詢病患是否處於急救中。
  - `has_pending_emergency() -> bool`：查詢全域是否有未派工之緊急事件。
  - `get_pending_emergency(doctor_id: String = "") -> Dictionary`：檢索可派工之急救事件資料。
  - `assign_doctor_to_emergency(patient_id: String, doctor_id: String) -> void`：將急救任務派發予指定醫生。
  - `is_hospital_busy() -> bool`：檢查醫院當前是否有其他非醫護人員正在就醫。
  - `trigger_random_medical_emergency() -> void`：測試/除錯用，隨機使一名市民進入昏厥倒地狀態以觀測通報與救援閉環。

### 15.3 NPC 控制器急救與通報 API (`NPCController`)

- **運行屬性 (Properties)**：
  - `var is_fainted: bool`：是否處於昏厥倒地狀態。
  - `var fainted_cause: String`：昏厥原因。
  - `var fainted_elapsed_ticks: int`：昏厥持續累積 Ticks。
  - `var is_rescuing: bool`：醫護人員是否正在出診急救途中。
- **公開方法 (Public Methods)**：
  - `faint(cause: String = "體力竭盡昏厥") -> void`：使該 NPC 進入昏厥倒地狀態。
  - `wake_up_from_faint(doctor_name: String, doctor_id: String = "") -> void`：接受施救甦醒復原。
  - `show_speech_bubble(text: String, duration: float = 2.5) -> void`：顯示帶有 Emoji 或文字的浮動氣泡。
  - `trigger_test_faint(reason: String = "中暑體力透支") -> void`：除錯專用測試方法。

---

## 16. 情報擴散與傳播驗證系統 (Information Diffusion & Verification System)

### 16.1 情報擴散管理器：`InformationDiffusionManager` (`scripts/ai/information_diffusion_manager.gd`)

管理全鎮所有傳聞與情報的生命週期，構建完整的因果拓撲樹 (Diffusion Topology Tree)，提供知曉率統計與三重驗證支援。

- **列舉與常數**：
  - `enum RumorCategory { ECONOMY, HEALTH, SOCIAL, WORK, GOSSIP }`：5 大結構化語意模板。
  - `CHANNEL_BILLBOARD = "BILLBOARD"`：公佈欄公告渠道。
  - `CHANNEL_WHISPER = "WHISPER"`：秘密耳語渠道。
- **訊號 (Signals)**：
  - `signal rumor_published(rumor_id: String, title: String, channel: String)`：情報發布時廣播。
  - `signal rumor_spread(rumor_id: String, from_id: String, to_id: String, generation: int)`：情報擴散時廣播。
- **公開方法 (Public Methods)**：
  - `publish_rumor(category: RumorCategory, slots: Dictionary, channel: String, seed_id: String, seed_name: String, cur_day: int, cur_tick: int) -> Dictionary`：發布一則結構化情報。
  - `record_spread(rumor_id: String, from_id: String, from_name: String, to_id: String, to_name: String, cur_day: int, cur_tick: int, poi_id: int, from_generation: int) -> bool`：登記一次擴散事件並更新拓撲樹。
  - `get_active_rumors() -> Array[Dictionary]`：取得所有小鎮情報。
  - `get_rumor_by_id(rumor_id: String) -> Dictionary`：依 ID 獲取情報。
  - `get_billboard_rumors() -> Array[Dictionary]`：取得公佈欄情報。
  - `get_knowledge_stats(rumor_id: String, total_population: int = 20) -> Dictionary`：計算知曉率 (`count`, `total`, `ratio`, `percentage_str`)。
  - `get_rumor_topology_tree_text(rumor_id: String) -> String`：生成完整的世代因果拓撲文字樹供驗證面板顯示。
  - `to_dict() -> Dictionary` / `from_dict(data: Dictionary) -> void`：存讀檔序列化與還原。

### 16.2 5 大結構化通用模板與神經行為引力 (Structured Slot Templates & Behavioral Gravity)

1. **經濟特報 (`ECONOMY`)**：
   - 槽位：`location_name` (地點), `poi_id` (設施 ID), `item_name` (特惠商品), `discount` (折扣幅度)。
   - 行為引力效果：提升娛樂/消費慾望 (`fun_desire_bonus`)，賦予目標設施優先前往引力 (`gravity_poi_id`)。
2. **醫療警訊 (`HEALTH`)**：
   - 槽位：`symptom` (流行症狀), `clinic_name` (診所名稱), `poi_id` (設施 ID)。
   - 行為引力效果：提升健康警惕度 (`health_vigilance`)，體虛或勞累時就醫傾向優先序提升。
3. **社交號召 (`SOCIAL`)**：
   - 槽位：`location_name` (聚會地點), `poi_id` (設施 ID), `time_slot` (預定時段)。
   - 行為引力效果：大幅提高社交渴望 (`social_desire_bonus +25.0`) 與心情提升。
4. **工作動機 (`WORK`)**：
   - 槽位：`location_name` (工作地點), `poi_id` (設施 ID), `bonus` (激勵獎金/補貼)。
   - 行為引力效果：提高工作動機，平緩體力消耗係數 (`stamina_decay_modifier`)。
5. **人際八卦 (`GOSSIP`)**：
   - 槽位：`npc_a_id`, `npc_a_name`, `npc_b_id`, `npc_b_name`, `relation_type`, `desc`。
   - 行為引力效果：獲知傳聞的居民對八卦主角之好感度與信任度產生偏差微調 (`delta_fav`, `delta_trust`)。

### 16.3 NPC 數據模型情報擴充 API (`NPCData`)

- **屬性 (Properties)**：
  - `@export var known_rumors: Dictionary = {}`：已知情報儲存庫 `{ rumor_id: { learned_from, learned_from_name, learned_day, learned_tick, generation, shared_to } }`。
- **公開方法 (Public Methods)**：
  - `has_rumor(rumor_id: String) -> bool`：查詢是否已知該情報。
  - `get_unshared_rumors_for(target_id: String) -> Array[String]`：檢索尚未向目標 NPC 轉述過的情報清單。
  - `mark_rumor_shared(rumor_id: String, target_id: String) -> void`：登記情報已轉述。
  - `learn_rumor(rumor_dict: Dictionary, from_id: String, from_name: String, day: int, tick: int, gen: int) -> bool`：習得情報並套用引力與生活事件記錄。
  - `apply_rumor_effects(effects: Dictionary) -> void`：套用情報對自身屬性與關係的動態修飾。

### 16.4 NPC 控制器頭頂氣泡保留接口與傳播演繹 (`NPCController`)

- **公開方法 (Public Methods)**：
  - `set_bubble_frame(frame_index: int) -> void`：**[保留接口]** 預留未來切換 Sprite2D / AnimatedSprite2D 氣泡圖集不同 frame 幀數的調用點。
  - `show_speech_bubble(text: String, duration: float = 2.5, bubble_frame: int = -1) -> void`：顯示文字氣泡，若指定 `bubble_frame` 則透過保留接口切換幀數。
  - `_check_billboard_rumors(poi_id: int = 22, is_passing_by: bool = false) -> void`：當居民專程抵達專屬布告欄 (POI 22) 或在世界移動中**物理路過布告欄周遭** (距離 $\le 2.5$ 格) 時觸發。專程前往閱讀率為 100%，路過時為 65% 並具備 30 ticks 冷卻防抖，徹底移除在無關設施 (如 POI 20 廣場、POI 12 商店) 的遠端隔空讀取。
  - `_check_passing_by_billboard(cur_cell: Vector2i) -> void`：移動步伐中與週期巡視時檢測當前網格座標與 POI 22 的距離，實現動態路過閱覽情報機制。

### 16.5 全鎮情報傳播拓撲驗證面板：`RumorPropagationDialog` (`scripts/ui/rumor_propagation_dialog.gd`)

- **架構特點**：
  - 獨立 `CanvasLayer` (Layer 125)，純 GDScript 動態佈局。
  - 提供快捷鍵 `F7` 與 `TimeHUD` 頂部「📢 情報」按鈕一鍵呼出。
  - **分頁一 (拓撲驗證)**：知曉率進度條、知曉人數百分比、文字因果拓撲樹 (G1 -> G2 -> G3 傳播鏈節點)。
  - **分頁二 (情報發布)**：公佈欄 vs 秘密耳語、5 大結構化語意模板動態輸入表單與即時預覽。

### 16.6 開場居民性格詞條配置面板：`NPCTraitSettingsDialog` (`scripts/ui/npc_trait_settings_dialog.gd`)

- **架構特點**：
  - 獨立 `CanvasLayer` (Layer 126)，掛載於開始畫面 `TitleScreen` (點擊「⚙️ 居民性格設定」呼出)。
  - 支援配置全鎮 20 位居民的 12 大靈魂性格詞條 (`healthy`, `medicine_jar`, `greedy`, `eat_like_a_bird`, `social_person`, `asocial`, `optimistic`, `pessimistic`, `strong`, `debility`, `big_e`, `big_i`)。
  - 即時預覽 15 維度神經網路輸入偏移向量 (`personality_offset`)。
  - 自動持久化儲存至 `user://custom_npc_traits.json` 並與 `NPCSpawner` 與 `Global` 深度整合。

### 16.7 小鎮布告欄站位物件：`BulletinBoard` (`scripts/objects/bulletin_board.gd`)

- **職責描述**：
  - 作為 `POI 22`（小鎮布告欄）在遊戲地圖上的具體站位與可視化互動實體。
  - 純程式繪製復古木質布告欄與貼紙外觀（`_draw()`），具備遮雨棚、羊皮紙告示條與圖釘細節，零外部圖片依賴。
- **屬性與訊號 (Properties & Signals)**：
  - `@export var poi_id: int = 22`：關聯之 POI 代號。
  - `signal board_clicked()`：玩家點擊該告示牌時發射。
- **互動機制**：
  - 搭載 `Area2D` 與 `CollisionShape2D` (36x32px)。
  - 滑鼠懸停（Hover）：游標轉為點擊手勢、微幅縮放放大（1.1x），浮動標籤提示 `🔍 點擊查看情報`。
  - 玩家點擊：播放 Q 彈回饋動畫（Scale 0.9x -> 1.18x -> 1.0x），並自動呼叫 `RumorPropagationDialog.open()` 彈出情報中心。
  - 自動網格對齊：啟動時自 `Global.get_poi_cell(22)` 讀取座標，透過 `NavigationManager.map_to_local()` 嚴格對齊網格中心。







