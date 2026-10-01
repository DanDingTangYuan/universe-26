using System;
using Godot;

namespace Universe26;

[GlobalClass]
public partial class NPCDecisionBridge : RefCounted
{
    private NPCDecision? _decision;
    private bool _isInitialized = false;

    public bool IsInitialized => _isInitialized;

    public bool Initialize(string onnxPath = "res://ai_models/npc_decision_mlp.onnx", string normalizationPath = "res://ai_models/npc_normalization.json")
    {
        try
        {
            string globalOnnx = ProjectSettings.GlobalizePath(onnxPath);
            string globalNorm = ProjectSettings.GlobalizePath(normalizationPath);

            _decision = new NPCDecision(globalOnnx, globalNorm);
            _isInitialized = true;
            GD.Print($"[NPCDecisionBridge] 成功初始化 C# ONNX Runtime: {globalOnnx}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PrintErr($"[NPCDecisionBridge] 初始化 C# ONNX Runtime 失敗: {ex.Message}");
            _isInitialized = false;
            return false;
        }
    }

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

    public int GetBestAction(float[] scores)
    {
        return _decision?.GetBestAction(scores) ?? -1;
    }

    public string GetBestActionName(float[] scores)
    {
        return _decision?.GetBestActionName(scores) ?? "無";
    }

    public int GetLocation(int bestIndex, int food, int lunchbox)
    {
        return _decision?.GetLocation(bestIndex, food, lunchbox) ?? -1;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _decision?.Dispose();
            _decision = null;
            _isInitialized = false;
        }
        base.Dispose(disposing);
    }
}
