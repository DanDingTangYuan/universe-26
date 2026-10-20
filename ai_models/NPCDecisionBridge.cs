using System;
using System.Collections.Generic;
using Godot;

namespace Universe26;

[GlobalClass]
public partial class NPCDecisionBridge : RefCounted
{
    private NPCDecision? _decision;
    private NPCSocialDecision? _socialDecision;
    private NPCTransformerDecision? _transformerDecision;
    private NPCSocialTransformerDecision? _socialTransformerDecision;
    private bool _isInitialized = false;
    private bool _isSocialInitialized = false;
    private bool _isTransformerInitialized = false;
    private bool _isSocialTransformerInitialized = false;

    public bool IsInitialized => _isInitialized;
    public bool IsSocialInitialized => _isSocialInitialized;
    public bool IsTransformerInitialized => _isTransformerInitialized;
    public bool IsSocialTransformerInitialized => _isSocialTransformerInitialized;

    /// <summary>
    /// 無參數初始化 (使用預設模型路徑)
    /// </summary>
    public bool Initialize()
    {
        return Initialize(
            "res://ai_models/npc_decision_mlp.onnx",
            "res://ai_models/npc_normalization.json",
            "res://ai_models/npc_interaction_mlp.onnx",
            "res://ai_models/npc_interaction_normalization.json"
        );
    }

    /// <summary>
    /// 初始化一般決策模型 (相容舊版 2 參數呼叫，並自動加載預設社交模型)
    /// </summary>
    public bool Initialize(string onnxPath, string normalizationPath)
    {
        return Initialize(
            onnxPath,
            normalizationPath,
            "res://ai_models/npc_interaction_mlp.onnx",
            "res://ai_models/npc_interaction_normalization.json"
        );
    }

    /// <summary>
    /// 完整初始化一般決策與社交互動模型 (4 個參數)
    /// </summary>
    public bool Initialize(
        string onnxPath,
        string normalizationPath,
        string socialOnnxPath,
        string socialNormPath)
    {
        bool generalOk = false;
        try
        {
            _decision = new NPCDecision(onnxPath, normalizationPath);
            _isInitialized = true;
            generalOk = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化一般決策 C# ONNX Runtime: {onnxPath}");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化一般決策 C# ONNX Runtime 失敗: {ex.Message}");
            _isInitialized = false;
        }

        // 嘗試自動初始化社交模型
        if (Universe26.ModelResourceLoader.Exists(socialOnnxPath) && Universe26.ModelResourceLoader.Exists(socialNormPath))
        {
            InitializeSocial(socialOnnxPath, socialNormPath);
        }

        // 嘗試自動初始化 Transformer 決策大腦
        string defaultTransformerPath = "res://ai_models/universe_policy_transformer.onnx";
        if (Universe26.ModelResourceLoader.Exists(defaultTransformerPath))
        {
            InitializeTransformer(defaultTransformerPath);
        }

        // 嘗試自動初始化 Social Transformer 決策大腦
        string defaultSocialTransformerPath = "res://ai_models/universe_social_transformer.onnx";
        if (Universe26.ModelResourceLoader.Exists(defaultSocialTransformerPath))
        {
            InitializeSocialTransformer(defaultSocialTransformerPath);
        }

        return generalOk || _isTransformerInitialized || _isSocialTransformerInitialized;
    }

    /// <summary>
    /// 初始化社交互動 ONNX 模型 (無參數)
    /// </summary>
    public bool InitializeSocial()
    {
        return InitializeSocial(
            "res://ai_models/npc_interaction_mlp.onnx",
            "res://ai_models/npc_interaction_normalization.json"
        );
    }

    /// <summary>
    /// 初始化社交互動 ONNX 模型 (指定路徑)
    /// </summary>
    public bool InitializeSocial(string socialOnnxPath, string socialNormPath)
    {
        try
        {
            _socialDecision?.Dispose();
            _socialDecision = new NPCSocialDecision(socialOnnxPath, socialNormPath);
            _isSocialInitialized = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化社交決策 C# ONNX Runtime: {socialOnnxPath}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化社交決策 C# ONNX Runtime 失敗: {ex.Message}");
            _isSocialInitialized = false;
            return false;
        }
    }

    /// <summary>
    /// 查詢 Transformer 決策大腦是否啟用
    /// </summary>
    public bool IsTransformerActive()
    {
        return _isTransformerInitialized;
    }

    /// <summary>
    /// 初始化 Causal Transformer 決策模型 (支援選填路徑)
    /// </summary>
    public bool InitializeTransformer(string onnxPath = "res://ai_models/universe_policy_transformer.onnx")
    {
        try
        {
            if (!Universe26.ModelResourceLoader.Exists(onnxPath))
            {
                GD.PrintErr($"[NPCDecisionBridge] Transformer ONNX 模型檔案不存在: {onnxPath}");
                _isTransformerInitialized = false;
                return false;
            }

            _transformerDecision?.Dispose();
            _transformerDecision = new NPCTransformerDecision(onnxPath);
            _isTransformerInitialized = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化 Transformer 決策大腦 C# ONNX Runtime: {onnxPath}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化 Transformer 決策大腦 C# ONNX Runtime 失敗: {ex.Message}");
            _isTransformerInitialized = false;
            return false;
        }
    }

    /// <summary>
    /// 查詢 Social Transformer 決策大腦是否啟用
    /// </summary>
    public bool IsSocialTransformerActive()
    {
        return _isSocialTransformerInitialized;
    }

    /// <summary>
    /// 初始化 Causal Social Transformer 決策模型 (支援選填路徑)
    /// </summary>
    public bool InitializeSocialTransformer(string onnxPath = "res://ai_models/universe_social_transformer.onnx")
    {
        try
        {
            if (!Universe26.ModelResourceLoader.Exists(onnxPath))
            {
                GD.PrintErr($"[NPCDecisionBridge] Social Transformer ONNX 模型檔案不存在: {onnxPath}");
                _isSocialTransformerInitialized = false;
                return false;
            }

            _socialTransformerDecision?.Dispose();
            _socialTransformerDecision = new NPCSocialTransformerDecision(onnxPath);
            _isSocialTransformerInitialized = true;
            GD.Print($"[NPCDecisionBridge] 🚀 成功初始化 Social Transformer 決策大腦 C# ONNX Runtime: {onnxPath}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化 Social Transformer 決策大腦失敗: {ex.Message}");
            _isSocialTransformerInitialized = false;
            return false;
        }
    }

    // =========================================================================
    // 1. 一般日常行為決策 API (General Decision APIs)
    // =========================================================================

    /// <summary>
    /// 輸入 15 個特徵數值，回傳長度為 9 的行為分數
    /// </summary>
    public float[] Evaluate(float[] stats)
    {
        if (!_isInitialized || _decision == null || stats == null || stats.Length < 15)
        {
            GD.PrintErr("[NPCDecisionBridge] Evaluate 失敗: 模型尚未初始化或特徵長度不足 15");
            return Array.Empty<float>();
        }

        return _decision.decision(
            stats[0], stats[1], stats[2], stats[3], stats[4],
            stats[5], stats[6], stats[7], stats[8], stats[9],
            stats[10], stats[11], stats[12], stats[13], stats[14]
        );
    }

    /// <summary>
    /// 取得最高分行為索引 (Argmax)
    /// </summary>
    public int GetBestAction(float[] scores)
    {
        return _decision?.GetBestAction(scores) ?? -1;
    }

    /// <summary>
    /// 取得最高分行為名稱
    /// </summary>
    public string GetBestActionName(float[] scores)
    {
        return _decision?.GetBestActionName(scores) ?? "無";
    }

    /// <summary>
    /// 依據分數進行輪盤機率抽樣
    /// </summary>
    public int SampleAction(float[] scores)
    {
        return _decision?.SampleAction(scores, null) ?? -1;
    }

    /// <summary>
    /// 依據分數與權重進行輪盤機率抽樣
    /// </summary>
    public int SampleActionWithWeights(float[] scores, float[] weights)
    {
        return _decision?.SampleAction(scores, weights) ?? -1;
    }

    /// <summary>
    /// 取得指定行為的目的地 POI 代碼
    /// </summary>
    public int GetLocation(int bestIndex, int food, int lunchbox)
    {
        return _decision?.GetLocation(bestIndex, food, lunchbox) ?? -1;
    }

    // =========================================================================
    // 1.5. Causal Transformer 決策大腦 API (Transformer Decision APIs)
    // =========================================================================

    /// <summary>
    /// 使用 Causal Transformer 評估下一步行為與目標地點 (端到端雙頭輸出)
    /// </summary>
    /// <param name="stats">15 維度特徵向量 (對應 NPCData.to_feature_vector)</param>
    /// <param name="tick">當前遊戲 Tick (0~1440)</param>
    /// <param name="jobId">職業 ID (1~9)</param>
    /// <param name="homePoi">自宅 POI (0~25)</param>
    /// <param name="prevAction">上一時間步行為代碼 (0~8)</param>
    /// <returns>Godot Dictionary，包含 success, best_action, best_poi, action_scores, poi_scores</returns>
    public Godot.Collections.Dictionary EvaluateTransformer(
        float[] stats,
        int tick,
        int jobId,
        int homePoi,
        int prevAction)
    {
        var result = new Godot.Collections.Dictionary();
        if (!_isTransformerInitialized || _transformerDecision == null)
        {
            GD.PrintErr("[NPCDecisionBridge] EvaluateTransformer 失敗: Transformer 模型尚未初始化");
            result["success"] = false;
            result["best_action"] = 0;
            result["best_poi"] = 0;
            result["action_scores"] = new Godot.Collections.Array<float>();
            result["poi_scores"] = new Godot.Collections.Array<float>();
            return result;
        }

        try
        {
            var res = _transformerDecision.EvaluateStep(stats, tick, jobId, homePoi, prevAction);
            var actionArr = new Godot.Collections.Array<float>();
            foreach (var a in res.ActionScores) actionArr.Add(a);

            var poiArr = new Godot.Collections.Array<float>();
            foreach (var p in res.PoiScores) poiArr.Add(p);

            result["success"] = true;
            result["best_action"] = res.BestAction;
            result["best_poi"] = res.BestPoi;
            result["action_scores"] = actionArr;
            result["poi_scores"] = poiArr;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] EvaluateTransformer 推論異常: {ex.Message}");
            result["success"] = false;
            result["best_action"] = 0;
            result["best_poi"] = 0;
            result["action_scores"] = new Godot.Collections.Array<float>();
            result["poi_scores"] = new Godot.Collections.Array<float>();
        }

        return result;
    }

    // =========================================================================
    // 2. 社交互動決策 API (Social Decision APIs)
    // =========================================================================

    /// <summary>
    /// 評估單一對象的社交互動意願分數 (0.0 ~ 1.0)
    /// </summary>
    public float EvaluateSocial(
        float time,
        float socialDesire,
        float mood,
        float favorability,
        float distance,
        float daysSinceInteraction,
        float historyScore)
    {
        if (!_isSocialInitialized || _socialDecision == null)
        {
            GD.PrintErr("[NPCDecisionBridge] EvaluateSocial 失敗: 社交模型尚未初始化");
            return 0f;
        }

        return _socialDecision.Evaluate(
            time, socialDesire, mood, favorability, distance, daysSinceInteraction, historyScore
        );
    }

    /// <summary>
    /// 批次評估多位候選 NPC，並透過加權輪盤機率選出最佳社交對象
    /// candidates 陣列中每個元素為 Dictionary:
    /// { "id": int, "distance": float, "favorability": float, "days_since_interaction": float, "history_score": float }
    /// 回傳 Dictionary:
    /// { "target_id": int, "highest_target_id": int, "score": float, "candidate_scores": Dictionary }
    /// </summary>
    public Godot.Collections.Dictionary EvaluateSocialCandidates(
        float time,
        float socialDesire,
        float mood,
        Godot.Collections.Array candidates,
        float stamina = 50.0f,
        int initiatorJobId = 9)
    {
        // 優先使用 Causal Social Transformer 端到端推論
        if (_isSocialTransformerInitialized && _socialTransformerDecision != null)
        {
            return _socialTransformerDecision.Evaluate(time, socialDesire, mood, stamina, initiatorJobId, candidates);
        }

        var result = new Godot.Collections.Dictionary
        {
            { "target_id", -1 },
            { "highest_target_id", -1 },
            { "score", 0.0f },
            { "candidate_scores", new Godot.Collections.Dictionary() }
        };

        if (!_isSocialInitialized || _socialDecision == null || candidates == null || candidates.Count == 0)
        {
            return result;
        }

        var candidateScores = new Godot.Collections.Dictionary();
        var validCandidates = new List<(int id, float score)>();
        float totalScore = 0f;
        int highestId = -1;
        float highestScore = -1f;

        foreach (Variant item in candidates)
        {
            if (item.VariantType != Variant.Type.Dictionary)
                continue;

            var dict = item.As<Godot.Collections.Dictionary>();
            int targetId = dict.TryGetValue("id", out Variant vId) ? vId.As<int>() : -1;
            if (targetId <= 0) continue;

            float distance = dict.TryGetValue("distance", out Variant vDist) ? vDist.As<float>() : 999f;
            if (distance < 0f || distance >= 32f) continue; // 僅考慮 32 格內之目標

            float favorability = dict.TryGetValue("favorability", out Variant vFav) ? vFav.As<float>() : 50f;
            float daysSince = dict.TryGetValue("days_since_interaction", out Variant vDays) ? vDays.As<float>() : 0f;
            float historyScore = dict.TryGetValue("history_score", out Variant vHist) ? vHist.As<float>() : 0.5f;

            float score = _socialDecision.Evaluate(
                time, socialDesire, mood, favorability, distance, daysSince, historyScore
            );

            candidateScores[targetId] = score;

            if (score > 0f)
            {
                validCandidates.Add((targetId, score));
                totalScore += score;

                if (score > highestScore)
                {
                    highestScore = score;
                    highestId = targetId;
                }
            }
        }

        result["candidate_scores"] = candidateScores;
        result["highest_target_id"] = highestId;
        result["highest_score"] = highestScore > 0f ? highestScore : 0.0f;

        if (validCandidates.Count == 0 || totalScore <= 0f)
        {
            result["candidate_probs"] = new Godot.Collections.Dictionary();
            return result;
        }

        // 指數立方放大權重抽樣 (Power-3 Exponential Roulette Wheel Selection)
        // 強化 Top 1 首選權重，大幅提升決策信噪比與因果性，產出高質量 Transformer 訓練資料
        var expCandidates = new List<(int id, float rawScore, double expWeight)>();
        double totalExpWeight = 0.0;
        foreach (var (id, score) in validCandidates)
        {
            double w = Math.Pow(score, 3.0);
            expCandidates.Add((id, score, w));
            totalExpWeight += w;
        }

        var candidateProbs = new Godot.Collections.Dictionary();
        foreach (var (id, score, w) in expCandidates)
        {
            float prob = totalExpWeight > 0.0 ? (float)(w / totalExpWeight) : 0f;
            candidateProbs[id] = prob;
        }
        result["candidate_probs"] = candidateProbs;

        if (totalExpWeight <= 0.0)
        {
            result["target_id"] = highestId;
            result["score"] = highestScore;
            return result;
        }

        double randomVal = Random.Shared.NextDouble() * totalExpWeight;
        double cumulative = 0.0;
        int selectedTargetId = expCandidates[^1].id;
        float selectedScore = expCandidates[^1].rawScore;

        foreach (var (id, score, w) in expCandidates)
        {
            cumulative += w;
            if (randomVal <= cumulative)
            {
                selectedTargetId = id;
                selectedScore = score;
                break;
            }
        }

        result["target_id"] = selectedTargetId;
        result["score"] = selectedScore;

        return result;
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7，相容舊版單參數)
    /// </summary>
    public int DecideSocialAction(int targetId)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, false, 50f, 50f);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7，相容舊版雙參數)
    /// </summary>
    public int DecideSocialAction(int targetId, bool hasSpreadMessage)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage, 50f, 50f);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7，啟發式完整參數：目標、好感度、心情、訊息傳播)
    /// </summary>
    public int DecideSocialAction(int targetId, bool hasSpreadMessage, float favorability, float mood)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage, favorability, mood);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7，具名相容方法)
    /// </summary>
    public int DecideSocialActionWithSpread(int targetId, bool hasSpreadMessage)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage, 50f, 50f);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7，具名啟發式方法，供 GDScript 明確呼叫避免重載歧義)
    /// </summary>
    public int DecideSocialActionHeuristic(int targetId, bool hasSpreadMessage, float favorability, float mood)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage, favorability, mood);
    }

    /// <summary>
    /// 取得社交行為名稱
    /// </summary>
    public string GetSocialActionName(int actionId)
    {
        return NPCSocialDecision.GetSocialActionName(actionId);
    }

    // =========================================================================
    // 3. 記憶資料庫與圖 1 啟動載入 API (Memory Database & Startup APIs)
    // =========================================================================

    /// <summary>
    /// 解析並設置活動 SQLite 資料庫路徑 (自動建立目錄，支援 user:// 與空白預設)
    /// </summary>
    public string ResolveDatabasePath(string dbPath)
    {
        if (string.IsNullOrWhiteSpace(dbPath))
        {
            dbPath = "user://saves/active_memory.db";
        }
        string globalPath = ProjectSettings.GlobalizePath(dbPath);
        try
        {
            string? dir = System.IO.Path.GetDirectoryName(globalPath);
            if (!string.IsNullOrEmpty(dir) && !System.IO.Directory.Exists(dir))
            {
                System.IO.Directory.CreateDirectory(dir);
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 建立資料庫目錄失敗: {ex.Message}");
        }
        UseDatabase.DatabasePath = globalPath;
        return globalPath;
    }

    /// <summary>
    /// 釋放 SQLite 連線池佔用的檔案控制代碼 (在刪除、覆蓋或備份 .db 檔前呼叫)
    /// </summary>
    public void ClearDatabaseConnections()
    {
        try
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] ClearDatabaseConnections 失敗: {ex.Message}");
        }
    }

    /// <summary>
    /// 複製/備份 SQLite 資料庫檔案 (例如從 active_memory.db 鏡像至 slot_X_memory.db，或反向載入)
    /// </summary>
    public bool CopyDatabase(string srcDbPath, string dstDbPath)
    {
        try
        {
            ClearDatabaseConnections();
            string srcGlobal = ProjectSettings.GlobalizePath(string.IsNullOrWhiteSpace(srcDbPath) ? "user://saves/active_memory.db" : srcDbPath);
            string dstGlobal = ProjectSettings.GlobalizePath(string.IsNullOrWhiteSpace(dstDbPath) ? "user://saves/active_memory.db" : dstDbPath);

            if (!System.IO.File.Exists(srcGlobal))
            {
                GD.PrintErr($"[NPCDecisionBridge] 複製失敗，來源資料庫不存在: {srcGlobal}");
                return false;
            }

            string? dstDir = System.IO.Path.GetDirectoryName(dstGlobal);
            if (!string.IsNullOrEmpty(dstDir) && !System.IO.Directory.Exists(dstDir))
            {
                System.IO.Directory.CreateDirectory(dstDir);
            }

            System.IO.File.Copy(srcGlobal, dstGlobal, true);
            GD.Print($"[NPCDecisionBridge] 記憶資料庫複製成功: {srcGlobal} -> {dstGlobal}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 複製記憶資料庫失敗: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// 初始化記憶資料庫 (對應圖 1: 初始化所有資料庫 STSM, MTSM, LTSM, STM, MTM, LTM)
    /// </summary>
    public bool InitializeMemoryDatabase(string dbPath = "", bool forceReset = false)
    {
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);
            if (forceReset)
            {
                UseDatabase.ResetDatabase();
            }
            else
            {
                UseDatabase.InitializeDatabase();
            }
            GD.Print($"[NPCDecisionBridge] 記憶資料庫 (SQLite) 初始化成功: {globalPath}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化記憶資料庫失敗: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// 檢查資料庫檔案是否存在
    /// </summary>
    public bool HasMemoryDatabase(string dbPath = "")
    {
        string globalPath = ResolveDatabasePath(dbPath);
        return System.IO.File.Exists(globalPath);
    }

    /// <summary>
    /// 依據圖 1 (讀取存檔流程)，依序從 MTM, LTM, LTSM 載入資料並計算歷史分數
    /// 回傳 Godot Dictionary 供 NPCData 載入
    /// </summary>
    public Godot.Collections.Dictionary LoadNPCStartupData(int npcId, string dbPath = "")
    {
        var result = new Godot.Collections.Dictionary();
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            var npc = new npc_class.NPCclass(npcId);

            // 1. 從 MTM 載入現有 NPC 數值 (及 LTM 初始欄位)
            UseDatabase.LoadMTMintoNPCclass(npc);

            // 2. 從 LTM 載入行動權重及詞條
            UseDatabase.LoadActionWeights(npcId, npc.NormalOffset);

            // 3. 從 LTSM 載入 NPC 之間的信任度及好感度
            UseDatabase.LoadLTSM(npcId, npc.Social);

            // 4. 計算 NPC 對彼此的互動歷史分數 (統計 10 天內歷史好壞事件比例)
            UseDatabase.LoadHistoryEvent(npcId, npc.Social.HistoryEventToOther);

            // 打包生理數值 (MTM)
            var stats = new Godot.Collections.Dictionary
            {
                { "hp", (float)npc.Physiological.Hp },
                { "health", (float)npc.Physiological.Health },
                { "stamina", (float)npc.Physiological.Stamina },
                { "hunger", (float)npc.Physiological.Hunger },
                { "social_desire", (float)npc.Physiological.SocialDesire },
                { "mood", (float)npc.Physiological.Mood },
                { "money", npc.Physiological.Money },
                { "wood", npc.Physiological.Wood },
                { "stone", npc.Physiological.Stone },
                { "mineral", npc.Physiological.Mineral },
                { "crops", npc.Physiological.Crops },
                { "fish", npc.Physiological.Fish },
                { "food", npc.Physiological.Food },
                { "lunchbox", npc.Physiological.Lunchbox }
            };
            result["stats"] = stats;

            // 打包詞條 (LTM)
            var entries = new Godot.Collections.Dictionary
            {
                { "medicine_jar", npc.Entry.MedicineJar },
                { "healthy", npc.Entry.Healthy },
                { "greedy", npc.Entry.Greedy },
                { "eat_like_a_bird", npc.Entry.EatLikeABird },
                { "social_person", npc.Entry.SocialPerson },
                { "asocial", npc.Entry.Asocial },
                { "optimistic", npc.Entry.Optimistic },
                { "pessimistic", npc.Entry.Pessimistic },
                { "debility", npc.Entry.Debility },
                { "strong", npc.Entry.Strong },
                { "big_e", npc.Entry.BigE },
                { "big_i", npc.Entry.BigI }
            };
            result["entries"] = entries;

            // 打包行動權重 (LTM)
            var weights = new Godot.Collections.Array<float>
            {
                (float)npc.NormalOffset.WanderOffset,
                (float)npc.NormalOffset.ReadOffset,
                (float)npc.NormalOffset.ShoppingOffset,
                (float)npc.NormalOffset.EatOffset,
                (float)npc.NormalOffset.GoToADoctorOffset,
                (float)npc.NormalOffset.GoHomeOffset,
                (float)npc.NormalOffset.SocialContactOffset,
                (float)npc.NormalOffset.CheckTheFieldOffset,
                (float)npc.NormalOffset.SellingOffset
            };
            result["action_weights"] = weights;

            // 打包信任度與好感度 (LTSM)
            var trustDict = new Godot.Collections.Dictionary();
            var favDict = new Godot.Collections.Dictionary();
            for (int i = 0; i < 20; i++)
            {
                string targetKey = $"npc_{(i + 1):D2}";
                trustDict[targetKey] = (float)npc.Social.Trust[i];
                favDict[targetKey] = (float)npc.Social.Favorability[i];
            }
            result["trust"] = trustDict;
            result["friendships"] = favDict;

            // 打包互動歷史分數 (0.0 ~ 1.0)
            var histArray = new Godot.Collections.Array<float>();
            for (int i = 0; i < 20; i++)
            {
                histArray.Add((float)npc.Social.HistoryEventToOther[i]);
            }
            result["history_scores"] = histArray;

            result["job_id"] = npc.JobId;
            result["home_id"] = npc.Home;
            result["success"] = true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 載入 NPC {npcId} 啟動資料失敗: {ex.Message}");
            result["success"] = false;
            result["error"] = ex.Message;
        }

        return result;
    }

    /// <summary>
    /// 依據圖 1 (新開局流程)，將使用者設定的詞條存入 LTM
    /// </summary>
    public bool StoreNPCEntry(int npcId, Godot.Collections.Dictionary traitsDict, string dbPath = "")
    {
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            var entry = new npc_class.Entry
            {
                MedicineJar = traitsDict.TryGetValue("medicine_jar", out Variant v1) && v1.As<bool>(),
                Healthy = traitsDict.TryGetValue("healthy", out Variant v2) && v2.As<bool>(),
                Greedy = traitsDict.TryGetValue("greedy", out Variant v3) && v3.As<bool>(),
                EatLikeABird = traitsDict.TryGetValue("eat_like_a_bird", out Variant v4) && v4.As<bool>(),
                SocialPerson = traitsDict.TryGetValue("social_person", out Variant v5) && v5.As<bool>(),
                Asocial = traitsDict.TryGetValue("asocial", out Variant v6) && v6.As<bool>(),
                Optimistic = traitsDict.TryGetValue("optimistic", out Variant v7) && v7.As<bool>(),
                Pessimistic = traitsDict.TryGetValue("pessimistic", out Variant v8) && v8.As<bool>(),
                Debility = traitsDict.TryGetValue("debility", out Variant v9) && v9.As<bool>(),
                Strong = traitsDict.TryGetValue("strong", out Variant v10) && v10.As<bool>(),
                BigE = traitsDict.TryGetValue("big_e", out Variant v11) && v11.As<bool>(),
                BigI = traitsDict.TryGetValue("big_i", out Variant v12) && v12.As<bool>()
            };

            UseDatabase.StoreEntry(npcId, entry);
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 存入 NPC {npcId} 詞條至 LTM 失敗: {ex.Message}");
            return false;
        }
    }

    // =========================================================================
    // 4. 圖 2 & 圖 4 執行期記憶寫入 API (Runtime Memory APIs)
    // =========================================================================

    /// <summary>
    /// 依據圖 2 (行動完成或失敗)，計算一般行動數值增減並儲存至 STM
    /// </summary>
    public Godot.Collections.Dictionary SaveNormalActionMemory(
        int npcId,
        int time,
        Godot.Collections.Dictionary statsDict,
        int action,
        int location,
        bool isSuccess,
        string dbPath = "")
    {
        var result = new Godot.Collections.Dictionary();
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            var physiological = new npc_class.PhysiologicalStats
            {
                Hp = statsDict.TryGetValue("hp", out Variant vHp) ? (int)vHp.As<float>() : 100,
                Health = statsDict.TryGetValue("health", out Variant vHea) ? (int)vHea.As<float>() : 100,
                Stamina = statsDict.TryGetValue("stamina", out Variant vSta) ? (int)vSta.As<float>() : 100,
                Hunger = statsDict.TryGetValue("hunger", out Variant vHun) ? (int)vHun.As<float>() : 100,
                SocialDesire = statsDict.TryGetValue("social_desire", out Variant vSoc) ? (int)vSoc.As<float>() : 100,
                Mood = statsDict.TryGetValue("mood", out Variant vMoo) ? (int)vMoo.As<float>() : 100,
                Money = statsDict.TryGetValue("money", out Variant vMon) ? vMon.As<int>() : 100,
                Wood = statsDict.TryGetValue("wood", out Variant vWoo) ? vWoo.As<int>() : 0,
                Stone = statsDict.TryGetValue("stone", out Variant vSto) ? vSto.As<int>() : 0,
                Mineral = statsDict.TryGetValue("mineral", out Variant vMin) ? vMin.As<int>() : 0,
                Crops = statsDict.TryGetValue("crops", out Variant vCro) ? vCro.As<int>() : 0,
                Fish = statsDict.TryGetValue("fish", out Variant vFis) ? vFis.As<int>() : 0,
                Food = statsDict.TryGetValue("food", out Variant vFoo) ? vFoo.As<int>() : 0,
                Lunchbox = statsDict.TryGetValue("lunchbox", out Variant vLun) ? vLun.As<int>() : 0
            };

            var actionValue = new npc_class.ActionValue
            {
                ActionState = action,
                Destination = location,
                IsLastActionSuccess = isSuccess
            };

            var changedState = new npc_class.ChangedStateValue();
            UseDatabase.SaveMemory(npcId, time, physiological, actionValue, changedState);
            double rewardValue = computeAttribute.attributeCalculator.ComputeRewardValue(changedState);

            result["change_hp"] = changedState.ChangeHp;
            result["change_health"] = changedState.ChangeHealth;
            result["change_stamina"] = changedState.ChangeStamina;
            result["change_hunger"] = changedState.ChangeHunger;
            result["change_social_desire"] = changedState.ChangeSocialDesire;
            result["change_mood"] = changedState.ChangeMood;
            result["change_money"] = changedState.ChangeMoney;
            result["change_wood"] = changedState.ChangeWood;
            result["change_stone"] = changedState.ChangeStone;
            result["change_mineral"] = changedState.ChangeMineral;
            result["change_crops"] = changedState.ChangeCrops;
            result["change_fish"] = changedState.ChangeFish;
            result["change_food"] = changedState.ChangeFood;
            result["change_lunchbox"] = changedState.ChangeLunchbox;
            result["reward_value"] = rewardValue;
            result["success"] = true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] SaveNormalActionMemory 失敗: {ex.Message}");
            result["success"] = false;
            result["error"] = ex.Message;
        }
        return result;
    }

    /// <summary>
    /// 依據圖 4 (決定社交動作選項並嘗試行動)，計算社交數值增減並儲存雙向記憶至 STSM
    /// </summary>
    public Godot.Collections.Dictionary SaveSocialActionMemory(
        int sourceId,
        int targetId,
        int time,
        int socialAction,
        Godot.Collections.Dictionary sourceSocial,
        Godot.Collections.Dictionary targetSocial,
        string dbPath = "")
    {
        var result = new Godot.Collections.Dictionary();
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            var sourceNPC = new npc_class.NPCclass(sourceId)
            {
                Time = time
            };
            sourceNPC.Action.SocialAction = socialAction;

            var targetNPC = new npc_class.NPCclass(targetId)
            {
                Time = time
            };
            targetNPC.Action.SocialAction = socialAction;

            // 雙方對彼此的好感與信任度
            int sTrust = sourceSocial.TryGetValue("trust_to_target", out Variant vST) ? (int)vST.As<float>() : 50;
            int sFav = sourceSocial.TryGetValue("fav_to_target", out Variant vSF) ? (int)vSF.As<float>() : 50;
            int tTrust = targetSocial.TryGetValue("trust_to_source", out Variant vTT) ? (int)vTT.As<float>() : 50;
            int tFav = targetSocial.TryGetValue("fav_to_source", out Variant vTF) ? (int)vTF.As<float>() : 50;

            if (targetId >= 1 && targetId <= 20)
            {
                sourceNPC.Social.Trust[targetId - 1] = sTrust;
                sourceNPC.Social.Favorability[targetId - 1] = sFav;
            }
            if (sourceId >= 1 && sourceId <= 20)
            {
                targetNPC.Social.Trust[sourceId - 1] = tTrust;
                targetNPC.Social.Favorability[sourceId - 1] = tFav;
            }

            UseDatabase.SaveMemory(sourceNPC, targetNPC);

            var sChanges = new Godot.Collections.Dictionary
            {
                { "change_trust", sourceNPC.ChangedStateValue.ChangeTrust },
                { "change_favorability", sourceNPC.ChangedStateValue.ChangeFavorability },
                { "change_mood", sourceNPC.ChangedStateValue.ChangeMood },
                { "change_stamina", sourceNPC.ChangedStateValue.ChangeStamina }
            };

            var tChanges = new Godot.Collections.Dictionary
            {
                { "change_trust", targetNPC.ChangedStateValue.ChangeTrust },
                { "change_favorability", targetNPC.ChangedStateValue.ChangeFavorability },
                { "change_mood", targetNPC.ChangedStateValue.ChangeMood },
                { "change_stamina", targetNPC.ChangedStateValue.ChangeStamina }
            };

            result["source"] = sChanges;
            result["target"] = tChanges;
            result["success"] = true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] SaveSocialActionMemory 失敗: {ex.Message}");
            result["success"] = false;
            result["error"] = ex.Message;
        }
        return result;
    }

    // =========================================================================
    // 5. 圖 5 午夜換日結算記憶處理 API (Midnight Settlement APIs)
    // =========================================================================

    /// <summary>
    /// 依據圖 5 執行換日記憶結算前半 (步驟 1~5: SettleSTM -> SettleMTSM -> SettleSTSM)
    /// </summary>
    public bool ExecuteMidnightSettlement1(string dbPath = "")
    {
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            UseDatabase.DailySettlement1();
            GD.Print("[NPCDecisionBridge] 午夜記憶結算前半 (STM/MTSM/STSM) 執行成功！");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] ExecuteMidnightSettlement1 失敗: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// 依據圖 5 執行換日記憶結算後半 (步驟 6~10: SaveState -> LoadHistoryEvent -> LoadActionWeights)
    /// </summary>
    public Godot.Collections.Dictionary ExecuteMidnightSettlement2(
        int npcId,
        Godot.Collections.Dictionary currentPhysiological,
        Godot.Collections.Dictionary currentTrust,
        Godot.Collections.Dictionary currentFriendships,
        string dbPath = "")
    {
        var result = new Godot.Collections.Dictionary();
        try
        {
            string globalPath = ResolveDatabasePath(dbPath);

            var npc = new npc_class.NPCclass(npcId);

            // 填入當前生理數值
            npc.Physiological.Hp = currentPhysiological.TryGetValue("hp", out Variant vHp) ? (int)vHp.As<float>() : 100;
            npc.Physiological.Health = currentPhysiological.TryGetValue("health", out Variant vHea) ? (int)vHea.As<float>() : 100;
            npc.Physiological.Stamina = currentPhysiological.TryGetValue("stamina", out Variant vSta) ? (int)vSta.As<float>() : 100;
            npc.Physiological.Hunger = currentPhysiological.TryGetValue("hunger", out Variant vHun) ? (int)vHun.As<float>() : 100;
            npc.Physiological.SocialDesire = currentPhysiological.TryGetValue("social_desire", out Variant vSoc) ? (int)vSoc.As<float>() : 100;
            npc.Physiological.Mood = currentPhysiological.TryGetValue("mood", out Variant vMoo) ? (int)vMoo.As<float>() : 100;
            npc.Physiological.Money = currentPhysiological.TryGetValue("money", out Variant vMon) ? vMon.As<int>() : 100;
            npc.Physiological.Wood = currentPhysiological.TryGetValue("wood", out Variant vWoo) ? vWoo.As<int>() : 0;
            npc.Physiological.Stone = currentPhysiological.TryGetValue("stone", out Variant vSto) ? vSto.As<int>() : 0;
            npc.Physiological.Mineral = currentPhysiological.TryGetValue("mineral", out Variant vMin) ? vMin.As<int>() : 0;
            npc.Physiological.Crops = currentPhysiological.TryGetValue("crops", out Variant vCro) ? vCro.As<int>() : 0;
            npc.Physiological.Fish = currentPhysiological.TryGetValue("fish", out Variant vFis) ? vFis.As<int>() : 0;
            npc.Physiological.Food = currentPhysiological.TryGetValue("food", out Variant vFoo) ? vFoo.As<int>() : 0;
            npc.Physiological.Lunchbox = currentPhysiological.TryGetValue("lunchbox", out Variant vLun) ? vLun.As<int>() : 0;

            // 填入對其他 20 隻 NPC 的信任度與好感度
            for (int i = 0; i < 20; i++)
            {
                int targetNum = i + 1;
                string targetKey1 = $"npc_{targetNum:D2}";
                string targetKey2 = $"npc_{targetNum}";

                if (currentTrust.TryGetValue(targetKey1, out Variant vT) || currentTrust.TryGetValue(targetKey2, out vT) || currentTrust.TryGetValue(targetNum, out vT))
                {
                    npc.Social.Trust[i] = (int)vT.As<float>();
                }
                if (currentFriendships.TryGetValue(targetKey1, out Variant vF) || currentFriendships.TryGetValue(targetKey2, out vF) || currentFriendships.TryGetValue(targetNum, out vF))
                {
                    npc.Social.Favorability[i] = (int)vF.As<float>();
                }
            }

            // 執行結算後半
            UseDatabase.DailySettlement2(npc);

            // 回傳更新後的一般行動權重
            var weights = new Godot.Collections.Array<float>
            {
                (float)npc.NormalOffset.WanderOffset,
                (float)npc.NormalOffset.ReadOffset,
                (float)npc.NormalOffset.ShoppingOffset,
                (float)npc.NormalOffset.EatOffset,
                (float)npc.NormalOffset.GoToADoctorOffset,
                (float)npc.NormalOffset.GoHomeOffset,
                (float)npc.NormalOffset.SocialContactOffset,
                (float)npc.NormalOffset.CheckTheFieldOffset,
                (float)npc.NormalOffset.SellingOffset
            };
            result["action_weights"] = weights;

            // 回傳重算的互動歷史分數
            var histArray = new Godot.Collections.Array<float>();
            for (int i = 0; i < 20; i++)
            {
                histArray.Add((float)npc.Social.HistoryEventToOther[i]);
            }
            result["history_scores"] = histArray;

            result["success"] = true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] ExecuteMidnightSettlement2 (NPC {npcId}) 失敗: {ex.Message}");
            result["success"] = false;
            result["error"] = ex.Message;
        }
        return result;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _decision?.Dispose();
            _decision = null;
            _socialDecision?.Dispose();
            _socialDecision = null;
            _transformerDecision?.Dispose();
            _transformerDecision = null;
            _isInitialized = false;
            _isSocialInitialized = false;
            _isTransformerInitialized = false;
        }
        base.Dispose(disposing);
    }
}
