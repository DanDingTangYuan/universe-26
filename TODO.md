# 【專案推進路線圖與 TODO 清單】26號宇宙 (Universe 26)

本文件依據 [`DESIGN.md`](./DESIGN.md) 與 [`AGENTS.md`](./AGENTS.md) 開發規範制定，梳理當前專案從原型驗收過渡至正式神經符號沙盒架構的具體推進步驟與模組架構。

---

## 總體推進策略：由底層向上建構 (Bottom-Up)

```
[6. 未來長期演化] ─── 靈魂記憶模型 (LTM/MTM/STM) ─── 社交網絡模型 ─── 動態軟偏置決策
        ▲
[5. 目前近期任務] ─── 地圖瓦片排版 ─── 單點 POI 門口對齊 ─── 進屋隱藏/出屋現身演出
        ▲
[4. 綜合沙盒整合] ─── 22 大單點 POI ─── NPCSpawner 工廠 ─── NPCInspector 側邊觀測
        ▲
[3. AI 決策大腦]  ─── C# ONNX Runtime ─── GDScript MLP ─── 1x~60x 超高速倍率同步
        ▲
[2. NPC 實體模組] ─── NPCController ─── 15 維 NPCData ─── 工作生產與行為代謝
        ▲
[1. 基礎核心系統] ─── NavigationManager (AStarGrid2D) ─── Global (1440 Ticks 時間)
```

---

## 第一階段：基礎核心系統 (Core Foundations) - [已完成 100%]

> 目標：建立不依賴視覺節點的純邏輯運算層，奠定全域時間節奏與網格尋路基礎。

- [x] **1.1 全域時間管理器 (`Global.gd` - 集合單例 AutoLoad)**
  - [x] 實作 Tick 累計邏輯（1 遊戲日 = 1440 Ticks，對應 24 小時）。
  - [x] 提供遊戲速度倍率控制（支援 1x、2x、4x、8x、16x、32x、60x 超高速流速）。
  - [x] 提供正規化時間取得函式 `get_normalized_time() -> float`（回傳 0.0 ~ 1.0）。
  - [x] 提供時間換算工具（`get_formatted_time() -> String` 回傳 "HH:MM"、`get_current_hour() -> int`）。
  - [x] 發射關鍵節奏訊號：`tick_passed`、`hour_passed`、`day_passed`、`on_midnight_reached`。
  - [x] 實作 NPC 選中管理：`select_npc()`、`deselect_npc()`、`npc_selected` 訊號。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.2 網格導航管理器 (`NavigationManager.gd`)**
  - [x] MVC 分離原則：純 GDScript，將地圖計算與 `TileMapLayer` 視圖徹底解耦。
  - [x] 封裝並初始化 Godot 原生 `AStarGrid2D`（設定格點尺寸、網格邊界矩形）。
  - [x] 實作多層 TileMapLayer 資料提取：自動掃描 `GroundLayer`（可走路面）與 `ObstacleLayer`（障礙物）。
  - [x] 提供導航查詢公開 API：`get_id_path`、`is_cell_walkable`、`get_closest_walkable_cell`、`map_to_local`、`local_to_map`。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.3 系統狀態與時間 UI (`TimeHUD.tscn` / `TimeHUD.gd`)**
  - [x] 頂部固定 HUD（天數、時鐘、時段、一日進度條、狀態欄、倍速/暫停/跳時按鈕）。
  - [x] 支援 1x ~ 60x 循環切換按鈕，以及數字鍵 `1`~`6` 快速切換倍速、`Space` 鍵即時暫停/繼續。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

- [x] **1.4 獨立遊戲攝影機模組 (`game_camera.tscn` / `game_camera.gd`)**
  - [x] 繼承 `Camera2D`，支援滑鼠中鍵按住即時拖曳平移 (1:1 像素回應)。
  - [x] 滑鼠滾輪縮放 (0.5x ~ 4.0x) 與平滑緩動。
  - [x] 自動讀取 `NavigationManager` 綁定地圖可視邊界，防止黑邊穿幫。
  - [x] 提供平滑平移 `move_to(pos)` 與目標跟隨 `follow(node)` API。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

---

## 第二階段：NPC 實體與狀態機 (NPC Entity & State Machine) - [已完成 100%]

> 目標：為 NPC 打造具備獨立狀態、生理代謝與具體工作產出的實體架構。

- [x] **2.1 NPC 屬性與資料模型 (`NPCData.gd`)**
  - [x] 封裝神經網路所需的 15 維特徵欄位（HP, Health, Stamina, Hunger, Social, Mood, JobId, 金錢, 7 類物資）。
  - [x] 實作數值隨 Tick 自然衰減與恢復（飽食消耗、睡眠回體力、工作中加劇消耗等生理代謝）。
  - [x] 實作 `to_feature_vector()` 匯出長度 15 之 `PackedFloat32Array`。
  - [x] 實作物品庫存管理與 NPC 間好感度/信任度網絡儲存。

- [x] **2.2 NPC 控制器 (`NPCController.gd`)**
  - [x] 繼承 `CharacterBody2D`，掛載於 NPC 實體節點。
  - [x] 實作輕量級狀態機 (FSM)：`IDLE`、`MOVING`、`INTERACTING`、`WORKING`、`RESTING`。
  - [x] 實作基於 `Tween` 的 4 向歩行平滑位移，移動速度隨全域 `time_scale` 等比縮放。
  - [x] 實作具體工作生產邏輯（伐木產木材、採礦產礦石、農民產作物、廚師產料理、店長賺錢等）。
  - [x] 動態注入 24x36 像素之 `ClickArea`，支援滑鼠懸浮手指游標與左鍵點擊選中。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

---

## 第三階段：AI 決策大腦與推論服務 (AI Decision Brain) - [階段 3.1 完成]

> 目標：跨語言對接 C# ONNX Runtime 與 GDScript，驅動自主行為。

- [x] **3.1 AI 決策大腦服務 (`decision_service.gd` - NPCDecisionService)**
  - [x] 封裝 C# 原生 ONNX Runtime 橋接器 (`NPCDecisionBridge.cs`)，單次推論 $<0.03$ 毫秒。
  - [x] 內建原生 GDScript 5 層神經網路權重引擎作為備援降級方案，精度 100% 一致。
  - [x] 整合關鍵作息排程（23:00 宵禁返家就寢、12:00 午餐時間、8 大職業出勤排程）。
  - [x] 實作行動與 POI 映射（`get_location_by_action`）及社交可用性過濾（`is_available_for_social`）。
  - [x] 快取 `last_decision` 結構供觀測器讀取，於 `API_REFERENCE.md` 登錄公開介面。

- [ ] **3.2 靈魂與記憶演化系統 (Soul / Memory Vectors - 移入第六階段中長期)**

---

## 第四階段：世界設施與即時觀測 (World POIs & Inspector) - [已完成 100%]

> 目標：建立 POI 資料註冊、工廠生成與側邊即時觀測卡片。

- [x] **4.1 地圖設施與 NPC 生成工廠 (`poi_locations.json` / `npc_templates.json` / `NPCSpawner.gd`)**
  - [x] 建立 22 個離散單點 POI 註冊表（1~11 自宅、12 商店、13 餐廳、14 伐木場、15 礦場、16 農田、17 釣魚場、18 醫院、19 圖書館、20 廣場、21 回家、0 原地）。
  - [x] 建立 20 位居民配置模板（涵蓋 9 大職業、作息、初始屬性與 4x4 貼圖素材）。
  - [x] 實作 `NPCSpawner.gd` 生成工廠，支援動態 4 向切圖換皮、`NPCData` 獨立注入、導航器與觀測器自動掛載。

- [x] **4.2 NPC 側邊即時觀測器 (`NPCInspector.gd` - GUI)**
  - [x] 純 GDScript 動態構建懸浮面板（CanvasLayer layer 12），完全不需 `.tscn`。
  - [x] 角色側邊平滑懸浮（Side-by-Side Floating，浮於角色右側 28px，靠邊界自動翻至左側），完全不遮擋角色本體。
  - [x] 橫向精緻雙欄版面（380x210）：左欄顯示 AI 大腦行動/POI/引擎/機制/Top 評分；右欄顯示 15 維生理進度條與背包庫存。
  - [x] 支援點擊其他 NPC 即時切換、`[✕]` 或 `ESC` 關閉、底欄「🎯 鏡頭聚焦」平滑移動。
  - [x] 於 `API_REFERENCE.md` 登錄公開介面。

---

## 第五階段：【目前要做的】地圖建築排版與進屋隱藏演出 (Near-Term Tasks)

> 目標：配合討論結論，在維持「單點 POI」與模型對齊的前提下，落實地圖重繪、門口標定與進屋隱藏演出。

- [ ] **5.1 地圖排版與建築門口標定 (Map Layout & POI Alignment)**
  - [ ] 在 Godot Editor 中確認雙層架構：`GroundLayer`（可走道路草皮）與 `ObstacleLayer`（房屋本體、大樹障礙物）。
  - [ ] **門口唯一性規則確認**：每棟建築正門口正下方 1 格，必須保留為可通行 `GroundLayer`，禁止被 `ObstacleLayer` 覆蓋。
  - [ ] 22 大單點 POI 點位記錄（提供場景 `Marker2D` 錨點自動掃描與 `data/poi_locations.json` 雙軌支援）。

- [ ] **5.2 進屋隱藏與出屋現身機制實裝 (`Indoor Concealment`)**
  - [ ] 在 `NPCController` 實作 `enter_building()`：
    - 抵達門口後朝向設為 `walk_up`。
    - 0.4 秒極短 Tween：向上跨步 8~12 像素，同時 `modulate.a` 淡出至 0.0。
    - 淡出後設為 `visible = false`，進入室內駐留狀態。
  - [ ] 在 `NPCController` 實作 `exit_building()`：
    - 行為結束重置於門內，朝向設為 `walk_down`，`visible = true`。
    - 0.4 秒極短 Tween：向下邁步至門口網格，同時 `modulate.a` 淡入至 1.0。
    - 淡入後正式啟動 A\* 尋路走向下一地點。
  - [ ] **設施行為精確分流**：
    - 室內型（進屋隱藏）：自宅 (1~11/21，睡覺休養)、醫院 (18，就醫)、圖書館 (19，閱讀)、餐廳 (13，用餐)、商店 (12，購物)。
    - 室外型（露天幹活）：農田 (16)、伐木場 (14)、礦場 (15)、釣魚場 (17)、社交廣場 (20)。
  - [ ] **隱藏期間狀態維持**：
    - NPC 在屋內時，生理代謝（睡眠回體力等）、工作產出與 AI 決策時鐘照常推進。
    - `NPCInspector` 觀測卡片顯示「在屋內休息中 / 用餐中」，各項數值動態跳動。

- [ ] **5.3 門口防堆疊微位移處理 (Arrival Dispersion)**
  - [ ] 多名 NPC 同時抵達同一門口或同地待機時，在像素層級加入 $\pm 4 \sim 8$ 像素的視覺微偏移，防止同地點角色完全重疊。

---

## 第六階段：【未來要做的】靈魂記憶、社交網絡與神經演進 (Future Roadmap Tasks)

> 目標：解鎖記憶系統與社交模型，打破排程拘束，讓 NPC 社會展現高度自發性與故事性。

- [ ] **6.1 靈魂與三層記憶演化系統 (Soul / Memory Vectors - Phase 3.2)**
  - [ ] 設計 LTM (長期性格特質)、MTM (中期情緒心理)、STM (短期事件日誌) 儲存結構。
  - [ ] 監聽 `Global.on_midnight_reached` 訊號，每日午夜 00:00 觸發 STM 結算。
  - [ ] 生成具備語意的情境記憶日誌（`[時間] + [地點POI] + [互動對象] + [情緒變化]`）。
  - [ ] 依據 STM 獎勵值數學公式微調 MTM 向量；監控長期累積漂移觸發 LTM 微調。
  - [ ] 將記憶演化結果實質反饋至決策大腦輸入之 `personality_offset`。

- [ ] **6.2 社交網絡與互動模型 (Social Network Model)**
  - [ ] 基於同 POI 或空間鄰近（$\le 2$ 格）觸發主動問候、閒聊與面對面寒暄。
  - [ ] NPC 雙向好感度 (`friendships`) 與信任度 (`trust`) 動態增減矩陣。
  - [ ] 社交對話氣泡與情緒表情符號演出（生氣、喜愛、友好、警戒）。
  - [ ] 結合中央廣場公共熱區（Public Hub），促成下班後居民的高頻偶遇與人際交往。

- [ ] **6.3 決策大腦進階演進 (Neuro-Symbolic Brain Evolution)**
  - [ ] **從「硬覆蓋 (Hard Override)」邁向「動態軟偏置 (Soft Biasing)」**：
    - 不直接粗暴截斷神經推論，而是將作息與宵禁規則轉換為神經網路輸出層的加權偏置。
    - 允許極端生理狀態（瀕臨餓死 Hunger < 10 或重病瀕死）自主打破常規（半夜偷溜出門覓食、深夜敲急診大門）。
  - [ ] **空間距離成本折扣 (Distance Cost Discount)**：
    - 決策評分引入距離衰減，促使 NPC 自然偏向就近解決生理需求，減少不合理的長途折返。
  - [ ] **個人性格詞條注入**：
    - 將貪吃、工作狂、孤僻、熱情等性格特徵注入推論偏移量，形成差異化個體。

- [ ] **6.4 專案全生態驗收與沙盒模擬 (Sandbox Verification)**
  - [ ] 20 位居民全鎮無人值守多日模擬測試（7 天 ~ 30 天穩定性運轉）。
  - [ ] 記憶累積與人際關係網絡長期演化數據驗收。
  - [ ] 完整校對 `API_REFERENCE.md`，確認無任何違規編輯 `.tscn` / `.uid` 情事。
