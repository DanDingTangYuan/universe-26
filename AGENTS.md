# 專案架構與程式碼開發規範 (Cursor Rules)

## 1. 命名慣例 (Naming Conventions)

- 類別名稱 (Classes) 與節點 (Nodes)：使用 `PascalCase` (例如 `BattleManager`, `MapController`)。
- 變數 (Variables) 與函數 (Functions)：使用 `snake_case` (例如 `current_hp`, `get_walkable_cells()`)。
- 常數 (Constants)：使用 `UPPER_SNAKE_CASE` (例如 `MAX_MOVEMENT_RANGE`, `TILE_SIZE`)。
- 內部/私有變數與函數：字首加上底線 `_` (例如 `_internal_counter`, `_initialize_astar()`)。
- 訊號 (Signals)：使用 `snake_case`，並建議帶有事件完成的語意 (例如 `move_finished`, `unit_selected`)。

## 2. 型別宣告 (Type Hinting)

- 強制使用嚴格的型別提示 (Strong Typing) 以提升效能與減少執行時期錯誤。
- 變數宣告必須標明型別：`var movement_cost: int = 2` 或 `var path: Array[Vector2i] = []`。
- 函數必須標明參數型別與回傳型別，無回傳值需標記為 `void`：`func calculate_damage(atk: int, def: int) -> int:`。

## 3. I/O 與資料解析 (File & Data I/O)

- 檔案讀寫：嚴格使用 Godot 4 的 `FileAccess` 處理配置檔的讀取與寫入。
- JSON 處理：使用 `JSON.parse_string()` 將 `class.json` 或 `units.json` 轉換為字典，並映射至 DTO (Data Transfer Object) 結構中。
- 靜態與動態資料分離：JSON 讀取的資料僅作為「靜態模板 (Base Template)」；場上的單位必須是獨立實例化並帶有修飾器 (Modifiers) 陣列的「動態實體 (Runtime Instance)」。

## 4. 系統架構與解耦 (MVC & Logic Separation)

- 視覺與運算絕對分離：
  - `TileMapLayer` 與 `Sprite2D` 等節點僅做視覺渲染 (View)。
  - 地形消耗矩陣、A\* (`AStarGrid2D`) 尋路引擎等底層數學計算，必須由純腳本 (Model/Controller) 在背景處理。
- 節點依賴原則 (Call Down, Signal Up)：
  - 上層管理器 (如 `BattleManager`) 可直接呼叫下層子節點的函數。
  - 下層節點 (如 `BattleUnit`) 嚴禁寫死上層路徑 (避免 `get_parent().do_something()`)，狀態改變必須透過發射訊號 (`emit_signal`) 讓上層監聽。

## 5. 狀態機與執行緒 (State & Execution)

- 互動控制：核心管理器 (`BattleManager` / `UnitControl`) 必須實作輕量級狀態機 (如 `IDLE`, `SELECTED`, `MOVING`)，利用狀態枚舉 (Enum) 攔截並過濾不合法的玩家輸入。
- 動畫與位移：棋子移動必須使用 `Tween` 處理平滑展演，嚴禁在 `_process` 中手刻移動邏輯。

## 6. 場景與資源保護規則 (Scene & Asset Protection)

- **嚴格禁止自動處理 `.tscn` 與 `.uid` 檔案**：
  - AI 代理嚴禁擅自自動編輯、重構、覆寫或生成任何 `.tscn`（Godot 場景檔案）與 `.uid`（資源唯一識別碼檔案）。
  - 場景節點結構、屬性綁定、碰撞體配置（如 `Area2D`、`CollisionShape2D` 等）應優先由開發者在 Godot Editor 編輯器中進行視覺化調整與維護，避免直接修改造成場景結構損壞或 UID 衝突。

## 7. 備份與安全修改規範 (Backup & Modification Safety)

- **修改前手動備份**：
  - 於進行多檔案重構、跨模組調整或重大邏輯變更前，必須先針對即將修改的檔案建立手動備份。
- **備份存放隔離原則 (禁止置於專案目錄內)**：
  - **嚴格禁止**將原始碼備份目錄建立於 Godot 專案目錄 (`res://`) 內部。
  - 理由：Godot 引擎會自動遞迴掃描專案目錄內的所有 `.gd` 腳本，若專案內存在備份副本，將引發 `class_name` 重複註冊、全域命名空間衝突（如 `hides a global script class`）與編譯死鎖。
  - **規範存放位置**：所有手動備份必須存放於專案目錄**外部**的專屬備份路徑（例如 `../slg_demo_backups/<timestamp>/`）。

## 8. Godot 引擎執行檔路徑 (Engine Executable Path)

- **執行檔路徑**：`E:\Code\BetterGodotLauncher\engines\standard\Godot_v4.7.2-stable_win64.exe`
- **所屬資料夾**：`E:\Code\BetterGodotLauncher\engines\standard\`
- **使用規範**：AI 代理若需要執行無頭檢驗 (`--headless`)、語法編譯檢查或執行遊戲，**必須直接調用上述指定路徑**，嚴格禁止遍歷系統或搜尋其他目錄，保障使用者隱私與系統整潔。

## 9. API 文件同步規範 (API Documentation Synchronization)

- **API 變更同步原則**：
  - 凡是只要跟 **API 相關、會串接到其他程式碼中**（包括跨腳本呼叫、跨模組介面、公開方法/函式、全域資料結構與契約、對外訊號等）的任何異動（**新增、刪除、重構或修改函式簽章、參數、傳回值型別或資料格式**），**必須強制同步更新 `API_REFERENCE.md`**。
  - 確保所有跨程式碼串接的介面手冊始終為最新狀態，杜絕代碼與文件脫節所產生的開發混亂。
