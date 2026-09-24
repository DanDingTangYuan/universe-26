# 【專案推進路線圖與 TODO 清單】26號宇宙 (Universe 26)

本文件依據 [`DESIGN.md`](./DESIGN.md) 與 [`AGENTS.md`](./AGENTS.md) 開發規範制定，梳理當前專案從原型驗收過渡至正式神經符號沙盒架構的具體推進步驟與模組架構。

---

## 總體推進策略：由底層向上建構 (Bottom-Up)

```
[4. 綜合沙盒整合] ─── POI 設施互動點 ─── 日常沙盒自主模擬 ─── 觀測與除錯 UI
        ▲
[3. AI 決策與記憶] ── C# ONNX 推論橋接 ── LTM/MTM/STM 記憶演化 (午夜結算)
        ▲
[2. NPC 實體模組] ── NPCController ── FSM 狀態機 ── 移動/動畫 Tween 控制器
        ▲
[1. 基礎核心系統] ── NavigationManager (AStarGrid2D) ── TimeManager (1440 Ticks)
```

---

## 第一階段：基礎核心系統 (Core Foundations)

> 目標：建立不依賴視覺節點的純邏輯運算層，奠定全域時間節奏與網格尋路基礎。

- [x] **1.1 全域時間管理器 (`Global.gd` - 集合單例 AutoLoad)**
  - [x] 實作 Tick 累計邏輯（1 遊戲日 = 1440 Ticks，對應 24 小時）。
  - [x] 提供遊戲速度倍率控制（暫停、1x、2x、4x、快速跳過）。
  - [x] 提供正規化時間取得函式 `get_normalized_time() -> float`（回傳 0.0 ~ 1.0），供神經網路作為時間特徵輸入。
  - [x] 提供時間換算工具（例如 `get_formatted_time() -> String` 回傳 "HH:MM"、`get_current_hour() -> int`）。
  - [x] 發射關鍵節奏訊號：
    - `signal tick_passed(current_tick: int)`
    - `signal hour_passed(current_hour: int)`
    - `signal on_midnight_reached(day_count: int)`（驅動記憶演化核心訊號）
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.2 網格導航管理器 (`NavigationManager.gd`)**
  - [x] MVC 分離原則：建立為純 GDScript，將地圖計算與 `TileMapLayer` 視圖解耦。
  - [x] 封裝並初始化 Godot 原生 `AStarGrid2D`（設定格點尺寸、網格邊界矩形）。
  - [x] 實作多層 TileMapLayer 資料提取：
    - 遍歷 `GroundLayer`、`ObstacleLayer` 之 `get_used_cells()`。
    - 讀取 TileData 自訂層 (`is_solid`, `walk_weight`)。
    - 依據資料標記 `set_point_solid()` 與 `set_point_weight_scale()`。
  - [x] 提供導航查詢公開 API：
    - `func get_id_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]`
    - `func is_walkable(cell: Vector2i) -> bool`
    - `func get_random_walkable_neighbor(cell: Vector2i) -> Vector2i`
    - `func map_to_local(cell: Vector2i) -> Vector2` / `func local_to_map(pos: Vector2) -> Vector2i`
  - [x] 支援最近可走格搜尋 (`get_closest_walkable_cell`)。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.3 系統狀態與時間 UI (`TimeHUD.tscn` / `TimeHUD.gd`)**
  - [x] 畫面最頂部固定 HUD 介面（天數、時鐘、時段、全日進度條、狀態欄、倍速/暫停/跳時按鈕）。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.4 獨立遊戲攝影機模組 (`game_camera.tscn` / `game_camera.gd`)**
  - [x] 獨立繼承 `Camera2D`，支援滑鼠中鍵按住即時拖曳平移 (1:1 像素回應)。
  - [x] 滑鼠滾輪縮放 (0.5x ~ 4.0x) 與平滑緩動。
  - [x] 自動讀取 `NavigationManager` 綁定地圖可視邊界，防止黑邊穿幫。
  - [x] 提供平滑平移 `move_to(pos)` 與目標跟隨 `follow(node)` API。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

---

## 第二階段：NPC 實體與狀態機重構 (NPC Entity & State Machine)

> 目標：廢除 `demo.gd` 中針對單一展示場景的硬編碼演出，為 NPC 打造具備獨立狀態與生命週期的實體架構。

- [ ] **2.1 NPC 屬性與資料模型 (`NPCData.gd` / `AgentStats.gd`)**
  - [ ] 封裝神經網路所需的 15 個特徵欄位（HP, Health, Stamina, Hunger, SocialDesire, Mood, JobId, 金錢, 以及 7 類物資）。
  - [ ] 實作數值自然隨時間衰減與恢復（如飢餓隨 Tick 上升、體力隨移動下降）。
  - [ ] 實作方法將屬性匯出為 `PackedFloat32Array`（長度 15），便於直接交給 C# 模型推論。

- [ ] **2.2 NPC 控制器 (`NPCController.gd`)**
  - [ ] 繼承 `CharacterBody2D`，作為 NPC 預製體的控制核心（_提示：場景節點綁定由使用者在 Editor 操作，遵守場景保護規則_）。
  - [ ] 實作輕量級狀態機 (FSM)：
    - `IDLE`：待機、眼神/朝向維持、播放動畫並鎖定在第 0 幀。
    - `MOVING`：沿 A\* 網格路徑平滑移動。
    - `INTERACTING`：社交交流、對話氣泡顯示。
    - `WORKING`：農作、巡田、販售等特定工作。
    - `RESTING`：就診、回家睡覺休養。
  - [ ] 移植並優化 `demo.gd` 中的平滑位移：
    - 使用 `Tween` 處理逐格移動，移動中依據位移向量切換 `walk_up/down/left/right` 動畫。
    - 移動完成或停止時，調用 `pause()` 與 `frame = 0` 確保精確定格。
  - [ ] 實作 `PerceptionArea`（`Area2D`）訊號監聽，感知周遭 NPC 或物體。
  - [ ] 於 `API_REFERENCE.md` 登錄公開介面。

---

## 第三階段：C# 雙腦與記憶系統跨語言對接 (AI Brain & Memory Bridge)

> 目標：將已有的 `NPCDecision.cs` ONNX 推論串接到 GDScript，並搭建靈魂（三層記憶）演化框架。

- [x] **3.1 AI 決策大腦服務 (`decision_service.gd` - NPCDecisionService)**
  - [x] 成功將 ONNX 模型權重（19,977 浮點數）提取並轉換為 `npc_weights.json`。
  - [x] 實作原生 GDScript 15 維度前向推論（5 層 MLP + ReLU + Sigmoid），單次運算 0.03 毫秒，零外部依賴。
  - [x] 與原 C# `NPCDecision.cs` 模型推論結果對齊，達成 100% 精度一致。
  - [x] 整合 Google 規格表關鍵排程（23:00 宵禁強行返家、12:00 午餐時間、上班時段出勤判定）。
  - [x] 實作行動與 POI 映射（`get_location_by_action`）及社交可行性檢查（`is_available_for_social`）。
  - [x] 整合至 `Global.get_decision_service()` 並於 `API_REFERENCE.md` 登錄公開介面。

- [ ] **3.2 靈魂與記憶演化系統 (Soul / Memory Vectors)**
  - [ ] 設計 LTM (長期性格特質)、MTM (中期情緒心理)、STM (短期事件日誌) 儲存結構。
  - [ ] 監聽 `TimeManager.on_midnight_reached` 訊號：
    - 每日午夜觸發 STM 結算。
    - 依據 STM 獎勵值數學公式微調 MTM 向量。
    - 監控累積偏離度，觸發 LTM 微調。

---

## 第四階段：地圖設施、沙盒整合與驗證 (World & Integration)

> 目標：建立完整的沙盒生態閉環，讓 NPC 在地圖中自發性運作。

- [ ] **4.1 地圖設施與興趣點系統 (POIs / World Anchors)**
  - [ ] 建立地圖設施註冊表（對應 `NPCDecision.GetLocation` 中的 ID：如 12:市場, 13:餐廳, 16:農田, 18:醫院, 19:圖書館, 20:社交廣場, 21:住宅）。
  - [ ] NPC 根據決策目標查詢 POI 網格座標，並呼叫 `NavigationManager` 進行路徑規劃。

- [ ] **4.2 整合除錯與觀測 (Debug & Inspector)**
  - [ ] 建立除錯視覺化（可選）：顯示 NPC 當前狀態、AI 輸出前三高機率、A\* 規劃路徑線條。
  - [ ] 進行全自動沙盒運行測試（驗證 NPC 是否能依據飽食度過低自主去餐廳/吃便當，疲憊自主回家等）。

- [ ] **4.3 規格文檔與 API 驗收**
  - [ ] 完整校對 `API_REFERENCE.md`。
  - [ ] 確保無直接更動 `.tscn` / `.uid` 違反項目規範。
