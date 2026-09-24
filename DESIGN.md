# 【專案設計文件】26號宇宙 (Universe 26)

## 一、專案概述

- **專案名稱**：26號宇宙 (Universe 26)
- **類型定位**：開放世界模擬 / 生成式遊戲代理人沙盒 (Generative Game Agents Sandbox)
- **核心理念**：結合「神經網路直覺決策」與「符號規則狀態機」的神經符號 AI 架構 (Neuro-symbolic AI Architecture)，以輕量級微型神經網路群模擬具備自主意識與記憶演化的高擬真 NPC 生態圈。
- **技術棧與引擎**：
  - **遊戲引擎**：Godot 4.3+ (採用 Godot 4.7 .NET / Forward+，深度運用 `TileMapLayer` 架構)
  - **程式語言分工**：
    - **GDScript**：遊戲主迴圈邏輯、A\* 網格尋路導航、NPC 控制器與狀態機 (FSM)、TileMapLayer 資料解析、UI 與演出表現。
    - **C# (.NET)**：ONNX Runtime 模型載入與推論 (`InferenceSession`)、高維記憶向量數學運算 (LTM / MTM / STM 每日結算)。
    - **Python**：離線神經網路架構設計與代理人模型訓練 (Offline Training)。

---

## 二、核心架構：雙腦與三層記憶體系 (Dual-Brain & Memory System)

### 1. AI 腦 (即時推論 / Inference Only)

- **模型載入與運行**：
  - 使用預訓練的輕量級神經網路（如行為決策模型 `npc_decision_mlp.onnx`）。
  - 運行期權重**完全凍結 (Frozen Weights)**，僅進行即時前向傳播 (Forward Pass)，無即時梯度計算開銷。
  - 由 C# 呼叫 `Microsoft.ML.OnnxRuntime` 進行高效率推論。
- **輸入 (Input Tensor)**：
  - 15 維標準化特徵向量（透過 `npc_normalization.json` 進行 Z-Score 標準化）：
    1. 生命值 (HP)
    2. 健康度 (Health)
    3. 體力 (Stamina)
    4. 飽食度 (Hunger)
    5. 社交慾望 (Social Desire)
    6. 心情 (Mood)
    7. 職業編號 (Job ID)
    8. 持有金錢 (Money)
    9. 持有木頭 (Wood)
    10. 持有石頭 (Stone)
    11. 持有礦物 (Mineral)
    12. 持有農作物 (Crops)
    13. 持有魚 (Fish)
    14. 持有料理 (Food)
    15. 持有便當 (Lunchbox)
- **輸出 (Output Probabilities)**：
  - Softmax 9 種候選行為機率分佈：
    `[0] 閒逛`, `[1] 閱讀`, `[2] 購物`, `[3] 吃東西`, `[4] 就醫`, `[5] 回家休息`, `[6] 社交`, `[7] 巡田水`, `[8] 販售物品`。

### 2. 靈魂體系 (記憶向量 / Memory Vectors)

- **LTM (Long-Term Memory，長期記憶)**：代表 NPC 核心性格特質（如外向/內向、勤勞/懶惰、攻擊/和平），穩定度最高。
- **MTM (Medium-Term Memory，中期記憶)**：代表目前心理與情感狀態，隨近期生活品質波動。
- **STM (Short-Term Memory，短期記憶)**：單日事件日誌、互動經歷與累積獎勵/懲罰數值。
- **演化機制 (Evolutionary Dynamics)**：
  - 不做即時類神經反向傳播。
  - 每日午夜觸發：由 STM 的累積獎勵值與經歷，以數學公式微調 MTM 向量。
  - 當 MTM 出現極端偏離或長時間累積漂移時，觸發 LTM 的不可逆微調（性格微幅重塑）。

---

## 三、核心子系統設計 (Subsystems)

### 1. 時間系統 (Time System - Tick-based)

- **架構**：全域單例 (`TimeManager` Autoload)。
- **時間維度**：
  - 1 遊戲日 = 1440 Ticks (對應 24 小時制的 1440 分鐘)。
  - 換算並輸出正規化時間值 $[0.0, 1.0]$ 作為神經網路的時間輸入參考。
- **週期訊號**：
  - `tick_passed(current_tick: int)`：每 Tick 觸發，用於各系統節奏同步。
  - `hour_changed(current_hour: int)`：每小時觸發。
  - `on_midnight_reached(day_count: int)`：每日午夜 00:00 觸發，通知 C# 記憶系統執行 LTM/MTM/STM 結算。

### 2. 地圖與網格導航系統 (Map & Navigation System)

- **架構原則**：View 與 Logic 徹底分離。
  - 視覺層：多層獨立的 `TileMapLayer`（例如 `GroundLayer`、`ObstacleLayer`、裝飾層等）。
  - 運算層：純邏輯管理類別 (`NavigationManager` 或 `MapController`)。
- **AStarGrid2D 原生尋路**：
  - 嚴格對齊網格座標 (`Vector2i`)。
  - 初始化掃描：遍歷地圖各個 `TileMapLayer`，透過 `get_used_cells()` 取得地塊位置，並由 `TileData.get_custom_data(...)` 讀取自訂屬性：
    - `is_solid: bool`：是否為障礙物（設為不可通行 `set_point_solid`）。
    - `walk_weight: float`：行走代價/權重（設為通行代價 `set_point_weight_scale`）。
- **自主漫遊 (Wandering Logic)**：
  - NPC 隨機漫遊可直接考量地塊權重（如偏好走道路而不踏入高阻力草地），不一定每次都需要全局長途 A\* 尋路。

### 3. NPC 實體架構 (NPC Entity Structure - 待重構)

- **現狀背景**：舊有的 `demo.gd` 及 `demo.tscn` 僅為展示影片專用腳本，需全面重構為模組化、可擴充的正式 NPC 實體架構。
- **推薦節點結構 (Scene Tree)**：
  - **Root (`CharacterBody2D`)**：掛載 `NPCController.gd`。
  - **`CollisionShape2D`**：底層物理碰撞（注意符合無修改 tscn 規範，由 Editor 配置）。
  - **`AnimatedSprite2D`**：四向移動與待機動畫，支援移動中播放動畫、停止後精準定格至第 0 幀 (`pause()` + `frame = 0`)。
  - **`PerceptionArea (Area2D)`**：感官範圍，偵測周圍其他 NPC、設施或可互動道具。
  - **`UIAnchor / Bubble (Node2D)`**：對話氣泡、表情圖示、狀態提示。
- **內部模組與狀態機 (FSM)**：
  - **狀態枚舉**：`IDLE` (待機/定格), `MOVING` (網格巡路移動), `INTERACTING` (社交/對話中), `WORKING` (工作/巡田/採集), `RESTING` (休眠/就醫)。
  - **平滑位移**：嚴禁於 `_process` 中手刻移動，一律使用 `Tween` 逐格平滑平移並同步播放朝向動畫。
  - **決策驅動**：定期或狀態切換時向 C# 大腦 (`NPCDecision`) 請求決策，取得行動與目的地。

---

## 四、開發限制與最佳實踐 (Constraints & Best Practices)

1. **場景保護守則**：
   - 嚴格禁止 AI 擅自覆寫、修改或生成 `.tscn` 與 `.uid` 檔案。場景與節點結構請引導使用者在 Godot Editor 中操作。
2. **多檔案變更外部備份**：
   - 重大修改前，必須先手動在專案外目錄（如 `../slg_demo_backups/<timestamp>/`）建立備份，杜絕專案目錄內類別重複註冊。
3. **API 文檔即時同步**：
   - 跨腳本或跨模組公開介面若有調整，必須即時記錄至 `API_REFERENCE.md`。
4. **強型別與命名規範**：
   - 類別/節點使用 `PascalCase`，變數/函式使用 `snake_case`，常數使用 `UPPER_SNAKE_CASE`。
   - 所有變數與函式均需標明型別提示（無回傳值標記 `void`）。
