using System;
using System.Collections.Generic;
using Godot;

namespace Universe26;

[GlobalClass]
public partial class NPCDecisionBridge : RefCounted
{
    private NPCDecision? _decision;
    private NPCSocialDecision? _socialDecision;
    private bool _isInitialized = false;
    private bool _isSocialInitialized = false;

    public bool IsInitialized => _isInitialized;
    public bool IsSocialInitialized => _isSocialInitialized;

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
    /// 完整初始化一般決策與社交互動模型
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
            string globalOnnx = ProjectSettings.GlobalizePath(onnxPath);
            string globalNorm = ProjectSettings.GlobalizePath(normalizationPath);

            _decision = new NPCDecision(globalOnnx, globalNorm);
            _isInitialized = true;
            generalOk = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化一般決策 C# ONNX Runtime: {globalOnnx}");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化一般決策 C# ONNX Runtime 失敗: {ex.Message}");
            _isInitialized = false;
        }

        // 嘗試自動初始化社交模型
        if (FileAccess.FileExists(socialOnnxPath) && FileAccess.FileExists(socialNormPath))
        {
            InitializeSocial(socialOnnxPath, socialNormPath);
        }

        return generalOk;
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
            string globalSocialOnnx = ProjectSettings.GlobalizePath(socialOnnxPath);
            string globalSocialNorm = ProjectSettings.GlobalizePath(socialNormPath);

            _socialDecision?.Dispose();
            _socialDecision = new NPCSocialDecision(globalSocialOnnx, globalSocialNorm);
            _isSocialInitialized = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化社交決策 C# ONNX Runtime: {globalSocialOnnx}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化社交決策 C# ONNX Runtime 失敗: {ex.Message}");
            _isSocialInitialized = false;
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
        Godot.Collections.Array candidates)
    {
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

        if (validCandidates.Count == 0 || totalScore <= 0f)
        {
            return result;
        }

        // 加權輪盤隨機抽樣 (Roulette Wheel Selection)
        double randomVal = Random.Shared.NextDouble() * totalScore;
        double cumulative = 0.0;
        int selectedTargetId = validCandidates[^1].id;
        float selectedScore = validCandidates[^1].score;

        foreach (var (id, score) in validCandidates)
        {
            cumulative += score;
            if (randomVal < cumulative)
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
    /// 決定具體社交行為代碼 (1~7)
    /// </summary>
    public int DecideSocialAction(int targetId)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, false);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7)，可指定是否持有可傳播訊息
    /// </summary>
    public int DecideSocialAction(int targetId, bool hasSpreadMessage)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage);
    }

    /// <summary>
    /// 決定具體社交行為代碼 (1~7)，可指定是否持有可傳播訊息 (具名相容方法)
    /// </summary>
    public int DecideSocialActionWithSpread(int targetId, bool hasSpreadMessage)
    {
        return NPCSocialDecision.DecideSocialAction(targetId, hasSpreadMessage);
    }

    /// <summary>
    /// 取得社交行為名稱
    /// </summary>
    public string GetSocialActionName(int actionId)
    {
        return NPCSocialDecision.GetSocialActionName(actionId);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _decision?.Dispose();
            _decision = null;
            _socialDecision?.Dispose();
            _socialDecision = null;
            _isInitialized = false;
            _isSocialInitialized = false;
        }
        base.Dispose(disposing);
    }
}
