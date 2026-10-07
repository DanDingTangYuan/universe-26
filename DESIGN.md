# 【專案設計文件】26號宇宙 (Universe 26)

## 一、專案概述

- **專案名稱**：26號宇宙 (Universe 26)
- **類型定位**：開放世界模擬 / 生成式遊戲代理人沙盒 (Generative Game Agents Sandbox)
- **核心理念**：結合「神經網路直覺決策」與「符號規則狀態機」的神經符號 AI 架構 (Neuro-symbolic AI Architecture)，以輕量級微型神經網路群模擬具備自主意識與記憶演化的高擬真 NPC 生態圈。
- **技術棧與引擎**：
  - **遊戲引擎**：Godot 4.3+ (採用 Godot 4.7 Mono .NET / Forward+，深度運用 `TileMapLayer` 架構)
  - **程式語言分工**：
    - **GDScript**：遊戲主迴圈邏輯、A\* 網格尋路導航、NPC 控制器與狀態機 (FSM)、TileMapLayer 資料解析、UI 與演出表現。
    - **C# (.NET)**：ONNX Runtime 模型載入與推論 (`NPCDecisionBridge.cs` / `Microsoft.ML.OnnxRuntime`)、高維記憶向量數學運算 (LTM / MTM / STM 每日結算)。
    - **Python**：離線神經網路架構設計與代理人模型訓練 (Offline Training)。

---

## 二、核心架構：雙腦與三層記憶體系 (Dual-Brain & Memory System)

```
       ┌────────────────────────────────────────────────────────┐
       │                神經符號雙腦決策系統                     │
       └──────────────────────────┬─────────────────────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         ▼                                                 ▼
┌──────────────────┐                             ┌──────────────────┐
│   符號排程護欄    │                             │  神經網路直覺大腦  │
│ (Symbolic Rules) │                             │   (MLP / ONNX)   │
│ - 就寢宵禁 (23:00)│                             │ - 15 維生理/經濟 │
│ - 上班崗位出勤   │                             │ - 9 大行為機率   │
│ - 飢餓用餐警報   │                             │ - 0.03ms 極速推論│
└────────┬─────────┘                             └────────┬─────────┘
         │                                                 │
         └────────────────────────┬────────────────────────┘
                                  │ 仲裁決策
                                  ▼
                    ┌──────────────────────────┐
                    │ NPC 實體狀態機 (FSM)     │
                    │ - IDLE / MOVING          │
                    │ - WORKING / RESTING      │
                    │ - INTERACTING            │
                    └─────────────┬────────────┘
                                  │ 每日經歷
                                  ▼
                    ┌──────────────────────────┐
                    │ 三層靈魂與記憶演化系統    │
                    │ - STM: 單日事件日誌      │
                    │ - MTM: 中期情緒心理      │
                    │ - LTM: 長期性格特質      │
                    └──────────────────────────┘
```

### 1. AI 決策大腦 (即時推論 / Inference Only)

- **模型載入與運行**：
  - 使用預訓練的輕量級神經網路（`ai_models/npc_decision_mlp.onnx`）。
  - 運行期權重**完全凍結 (Frozen Weights)**，僅進行即時前向傳播 (Forward Pass)，無即時反向傳播開銷。
  - 具備雙推論引擎相容架構：優先調用 C# 原生 `Microsoft.ML.OnnxRuntime`；於無 Mono 環境時無縫降級為 GDScript 內建矩陣推論 (`npc_weights.json`)。
- **輸入 (Input Tensor - 15 維特徵向量)**：
  1. 生命值 (HP, 0~100)
  2. 健康度 (Health, 0~100)
  3. 體力 (Stamina, 0~100)
  4. 飽食度 (Hunger, 0~100)
  5. 社交慾望 (Social Desire, 0~100)
  6. 心情 (Mood, 0~100)
  7. 職業編號 (Job ID, 1~9)
  8. 持有金錢 (Money, 0~9999)
  9. 持有木頭 (Wood)
  10. 持有石頭 (Stone)
  11. 持有礦物 (Mineral)
  12. 持有農作物 (Crops)
  13. 持有魚 (Fish)
  14. 持有料理 (Food)
  15. 持有便當 (Lunchbox)
- **輸出 (Output Probabilities - 9 大候選行為)**：
  - `[0] 閒逛`, `[1] 閱讀`, `[2] 購物`, `[3] 吃東西`, `[4] 就醫`, `[5] 回家休息`, `[6] 社交`, `[7] 巡田水/工作`, `[8] 販售物品`。

### 2. 靈魂體系 (記憶向量 / Memory Vectors)

- **LTM (Long-Term Memory，長期記憶)**：代表 NPC 核心性格特質（如外向/內向、勤勞/懶惰、隨和/暴躁），穩定度最高。
- **MTM (Medium-Term Memory，中期記憶)**：代表目前心理與情感狀態，隨近期生活品質波動。
- **STM (Short-Term Memory，短期記憶)**：單日事件日誌、互動經歷與累積獎勵/懲罰數值。
- **演化機制 (Evolutionary Dynamics)**：
  - 每日午夜 (00:00 / Tick 0) 觸發結算：由 STM 的累積經歷以數學公式微調 MTM 向量。
  - 當 MTM 出現累積偏離時，觸發 LTM 的微調，並將性格偏移反饋至神經網路的 `personality_offset`。

### 3. 社交網絡模型 (Social Network Model - 待整合)

- **關係儲存**：每個 NPC 獨立維護關係網絡字典：對其他 NPC 的好感度 (`friendships`) 與信任度 (`trust`)。
- **互動觸發**：當兩名 NPC 處於同一 POI 設施（或彼此網格距離 $\le 2$ 格）時，檢驗彼此社交狀態（非工作、就醫、睡眠狀態）觸發面對面交談、氣泡對話與關係分數更新。

---

## 三、空間架構與世界設施 (Spatial Architecture & World POIs)

### 1. 空間定義原則：離散單點 POI (Single-Point POI)
- **模型對齊原則**：因為神經網路訓練階段的標籤為離散地點代碼（Location IDs 0~21），世界空間定義嚴格保持**「一個建築/地點 = 一個離散點 (POI Cell)」**，避免過度設計增加模型負擔。
- **22 大核心 POI 設施清單**：
  - `1 ~ 11`：居民自宅 (Home 1~11)
  - `12`：商店/市場 (Shop/Market)
  - `13`：餐廳 (Restaurant)
  - `14`：伐木場 (Lumberyard)
  - `15`：礦場 (Mine)
  - `16`：農田 (Farm)
  - `17`：釣魚場 (Fishing Spot)
  - `18`：醫院 (Hospital)
  - `19`：圖書館 (Library)
  - `20`：社交廣場 (Plaza)
  - `21`：回家代碼 (Home generic)
  - `0`：原地 (In Place)

### 2. 地圖圖層與門口導航規範
- **`GroundLayer` (地面層)**：鋪設道路、泥土、草皮等所有可通行網格。
- **`ObstacleLayer` (障礙層)**：放置房屋本體、圍牆、樹木、岩石等實體障礙。
- **門口唯一性規則**：所有 POI 的標記網格，必須嚴格座落在**建築正門口外側 1 格的 `GroundLayer` 可走道路**上，嚴禁被 `ObstacleLayer` 覆蓋，確保 A\* 尋路百分之百可抵達。

### 3. 進屋隱藏演出與室內外行為劃分 (Indoor Concealment & Outdoor Activities)
為了解決多名 NPC 抵達同一設施時的「穿模疊羅漢」問題，並大幅提升真實生活沉浸感，設施採取動靜分明的室內外劃分：

- **室內型設施（抵達門口後「進屋隱藏」）**：
  - **適用對象**：自宅 (1~11/21，休息)、醫院 (18，就醫)、圖書館 (19，閱讀)、餐廳 (13，用餐)、商店 (12，購物)。
  - **進屋演出 (`enter_building`)**：抵達門口 $\rightarrow$ 朝向切換為 `walk_up` $\rightarrow$ 透過 0.4 秒極短 Tween 向上跨步 8~12 像素並將 `modulate.a` 淡出至 0.0 $\rightarrow$ `visible = false` 進入屋內。
  - **出屋演出 (`exit_building`)**：行為結束 $\rightarrow$ 重置於門內 $\rightarrow$ 朝向 `walk_down` $\rightarrow$ 透過 0.4 秒 Tween 向下步出門口並將 `modulate.a` 淡入至 1.0 $\rightarrow$ 開始尋路走向下一目的地。
  - **狀態維持**：NPC 在屋內隱藏期間，**生理代謝、工作產出、AI 決策時鐘 100% 照常運轉**。
- **室外型設施（保持「露天可見」幹活）**：
  - **適用對象**：農田 (16)、伐木場 (14)、礦場 (15)、釣魚場 (17)、社交廣場 (20)。
  - **表現機制**：保持角色完全可見，在場地內進行走動、勞動氣泡演出與資源產出，維持城鎮白天的生機與繁榮。

### 4. 地圖分區需求結論 (Map Zoning Strategy)
- **不進行全圖 100% 網格分區**：NPC 決策為目標導向（Goal-driven），無須浪費效能與美術成本標籤化每一塊草皮。
- **保留公共社交人流熱區 (High-Traffic Public Hub)**：
  - 在中央廣場或主街設立核心公共生活圈。
  - NPC 執行 `Action 0 (閒逛)` 或 `Action 6 (社交)` 且無特定對象時，優先引導至公共熱區，促成居民擦肩而過與偶遇，為社交模型提供高頻率的互動溫床。

---

## 四、核心子系統設計 (Subsystems)

### 1. 時間系統 (Time System - Tick-based)
- **架構**：全域單例 (`GlobalClass` AutoLoad)。
- **時間維度**：1 遊戲日 = 1440 Ticks (1 Tick = 遊戲內 1 分鐘)。
- **動態流速與步調同步**：
  - 支援 `1x`、`2x`、`4x`、`8x`、`16x`、`32x`、`60x`（1 真實秒 = 1 遊戲小時）超高速模擬。
  - **全域運動同步**：NPC 移動的 Tween 步進時間與行為計時器嚴格依據 `time_scale` 等比縮放，確保時鐘飛快時 NPC 物理位移同步疾走，作息與路程精準吻合。
  - 提供鍵盤快捷鍵：`1`~`6` 即時切倍速，`Space` 即時暫停/繼續。

### 2. 網格導航系統 (`NavigationManager.gd`)
- **AStarGrid2D 原生尋路**：
  - 自動掃描 `GroundLayer`（鋪設可走網格）與 `ObstacleLayer`（填入阻擋障礙）。
  - 自動防呆與最近可走格修正 (`get_closest_walkable_cell`)。
  - 自動註冊至 `Global` 服務定位器。

### 3. NPC 實體與生成工廠 (`NPCController.gd` / `NPCSpawner.gd`)
- **資料驅動生成**：`NPCSpawner` 動態讀取 `data/poi_locations.json` 與 `data/npc_templates.json`，於記憶體中將 4x4 16x32 人物貼圖切分為上下左右 4 向歩行動畫，注入獨立的 `NPCData`。
- **狀態機 (FSM)**：`IDLE` (待機), `MOVING` (尋路中), `INTERACTING` (社交/進食中), `WORKING` (崗位工作中), `RESTING` (休養/睡眠中)。
- **具體工作生產鏈**：
  - 伐木工 (POI 14) 產出木材；礦工 (POI 15) 產出礦石與石頭；農民 (POI 16) 產出農作物；漁夫 (POI 17) 產出鮮魚；餐廳員工 (POI 13) 產出便當料理與薪水；商店店長 (POI 12) 賺取金錢。

### 4. 側邊即時觀測器 (`NPCInspector.gd` - GUI)
- **角色側邊平滑懸浮 (Side-by-Side Floating)**：
  - 位於 CanvasLayer（layer 12），浮動於角色右側 28 像素處（靠近螢幕右側時自動翻轉至左側），完全不遮擋角色本體與行走動作。
- **橫向精緻雙欄版面 (380x210)**：
  - **左欄（AI 大腦）**：當前行動、目標 POI、推論引擎標籤、決策機制（規則覆蓋原因 vs 神經推論）、Top 2 機率行為微型進度條。
  - **右欄（生理與庫存）**：生命、健康、體力、飽食、社交、心情 6 條即時彩色進度條，持有金錢與背包物資庫存。
  - **底欄**：即時世界/網格座標與「🎯 鏡頭聚焦」按鈕。

---

## 五、決策大腦進階演進規劃 (Decision Brain Evolution Roadmap)

針對目前「規則覆蓋率過高（佔整天 ~70%）、神經網路自主性受限」的現況，規劃以下三階段進階演進：

1. **從「硬覆蓋 (Hard Override)」改為「動態軟偏置 (Soft Biasing)」**：
   - 不直接粗暴中斷神經推論，而是將作息與宵禁規則轉換為神經網路輸出層的加權偏置（如深夜給睡覺 `+3.0`，其他行為 `-2.0`）。
   - **核心價值**：保留「極限生理慾望打破常規」的真實感（例如瀕臨餓死的 NPC 在半夜打破宵禁偷溜出門找食物、重傷者深夜敲急診室大門）。
2. **空間距離成本折扣 (Distance Cost Discount)**：
   - 決策最終評分引入距離衰減：$\text{Score}_{\text{final}} = \text{Score}_{\text{brain}} - \alpha \times \text{Distance}$，讓 NPC 就近解決生理需求，減少不合理的長途奔波。
3. **性格與記憶深度融合**：
   - 將午夜結算的 LTM/MTM 向量轉化為 `personality_offset` 實質干預推論（例如「工作狂」下班仍想加班、「貪吃鬼」餐飲渴望加權）。

---

## 六、開發限制與最佳實踐 (Constraints & Best Practices)

1. **場景保護守則 (Rule 6)**：
   - 嚴格禁止 AI 擅自覆寫、修改或生成 `.tscn` 與 `.uid` 檔案。場景與節點結構優先由開發者在 Godot Editor 中操作，程式碼端以純代碼動態建構輔助節點。
2. **多檔案變更外部備份 (Rule 7)**：
   - 重大修改前，必須先手動在專案外目錄（如 `../slg_demo_backups/<timestamp>/`）建立備份，嚴禁在專案目錄內備份以避免 `class_name` 衝突。
3. **API 文檔即時同步 (Rule 9)**：
   - 跨腳本或跨模組公開介面若有調整，必須即時記錄至 `API_REFERENCE.md`。
4. **強型別與命名規範 (Rule 1 & 2)**：
   - 類別/節點使用 `PascalCase`，變數/函式使用 `snake_case`，常數使用 `UPPER_SNAKE_CASE`。
   - 所有變數與函式均需標明型別提示（無回傳值標記 `void`）。

---

## 七、附錄：歷史原始設計存檔 (Legacy Design Archive)

> **[註釋說明]**：本區塊完整封存專案最早期（原型展示 Demo 階段）之設計草案文字。該階段僅有展示專用腳本 `demo.gd` 與單一場景，現已被正式的 `NPCSpawner`、`NPCController`、`NPCInspector`、A\* 雙層導航與單點 POI 空間架構完整實裝並超越，特此存檔以供歷史追溯對照。

```markdown
### 歷史封存內容 (Old Section 3.3 NPC Entity Structure - 待重構草案)
- 現狀背景：舊有的 demo.gd 及 demo.tscn 僅為展示影片專用腳本，需全面重構為模組化、可擴充的正式 NPC 實體架構。
- 推薦節點結構 (Scene Tree)：
  - Root (CharacterBody2D)：掛載 NPCController.gd。
  - CollisionShape2D：底層物理碰撞（注意符合無修改 tscn 規範，由 Editor 配置）。
  - AnimatedSprite2D：四向移動與待機動畫，支援移動中播放動畫、停止後精準定格至第 0 幀 (pause() + frame = 0)。
  - PerceptionArea (Area2D)：感官範圍，偵測周圍其他 NPC、設施或可互動道具。
  - UIAnchor / Bubble (Node2D)：對話氣泡、表情圖示、狀態提示。
- 內部模組與狀態機 (FSM)：
  - 狀態枚舉：IDLE (待機/定格), MOVING (網格巡路移動), INTERACTING (社交/對話中), WORKING (工作/巡田/採集), RESTING (休眠/就醫)。
  - 平滑位移：嚴禁於 _process 中手刻移動，一律使用 Tween 逐格平滑平移並同步播放朝向動畫。
  - 決策驅動：定期或狀態切換時向 C# 大腦 (NPCDecision) 請求決策，取得行動與目的地。
```
