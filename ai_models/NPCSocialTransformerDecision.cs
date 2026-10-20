using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace Universe26;

/// <summary>
/// 26號宇宙 (Universe 26) - Causal Social Transformer 決策推論引擎
/// 載入 universe_social_transformer.onnx，提供端到端「候選人指針選擇」與「7 大社交行為預測」
/// </summary>
public class NPCSocialTransformerDecision : IDisposable
{
    private readonly InferenceSession _session;
    public const int MaxCandidates = 10;

    public NPCSocialTransformerDecision(string onnxPath)
    {
        if (!ModelResourceLoader.Exists(onnxPath))
        {
            throw new FileNotFoundException("找不到 Social Transformer ONNX 模型：", onnxPath);
        }

        var sessionOptions = new SessionOptions
        {
            GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
            ExecutionMode = ExecutionMode.ORT_SEQUENTIAL
        };

        byte[] modelBytes = ModelResourceLoader.LoadBytes(onnxPath);
        _session = new InferenceSession(modelBytes, sessionOptions);
        Godot.GD.Print($"[NPCSocialTransformerDecision] 🚀 成功載入 Causal Social Transformer: {onnxPath} ({modelBytes.Length} bytes)");
    }

    /// <summary>
    /// 批次評估雷達內的候選人，產出候選人評分與神經預測之社交行為 (1~7)
    /// </summary>
    public Godot.Collections.Dictionary Evaluate(
        float time,
        float socialDesire,
        float mood,
        float stamina,
        int initiatorJobId,
        Godot.Collections.Array candidates)
    {
        var result = new Godot.Collections.Dictionary
        {
            { "target_id", -1 },
            { "highest_target_id", -1 },
            { "highest_score", 0.0f },
            { "score", 0.0f },
            { "predicted_action_id", 1 },
            { "action_name", "普通聊天" },
            { "candidate_scores", new Godot.Collections.Dictionary() },
            { "candidate_probs", new Godot.Collections.Dictionary() },
            { "action_probs", new Godot.Collections.Array<float>() },
            { "is_transformer", true }
        };

        if (candidates == null || candidates.Count == 0)
        {
            return result;
        }

        // 1. 發起者特徵正規化 [1, 5]
        float[] initFeat = new float[5]
        {
            Math.Clamp(time / 1440.0f, 0.0f, 1.0f),
            Math.Clamp(socialDesire / 100.0f, 0.0f, 1.0f),
            Math.Clamp(mood / 100.0f, 0.0f, 1.0f),
            Math.Clamp(stamina / 100.0f, 0.0f, 1.0f),
            Math.Clamp(initiatorJobId / 10.0f, 0.0f, 1.0f)
        };

        // 2. 候選人特徵正規化 [1, 10, 5] 與掩碼 [1, 10]
        float[] candFeat = new float[MaxCandidates * 5];
        float[] mask = new float[MaxCandidates];
        var slotToTargetId = new int[MaxCandidates];

        int validCount = Math.Min(candidates.Count, MaxCandidates);
        for (int i = 0; i < validCount; i++)
        {
            var item = candidates[i];
            if (item.VariantType != Godot.Variant.Type.Dictionary)
                continue;

            var dict = item.As<Godot.Collections.Dictionary>();
            int targetId = dict.TryGetValue("id", out var vId) ? vId.As<int>() : -1;
            float dist = dict.TryGetValue("distance", out var vDist) ? vDist.As<float>() : 1.0f;
            float fav = dict.TryGetValue("favorability", out var vFav) ? vFav.As<float>() : 50.0f;
            float days = dict.TryGetValue("days_since_interaction", out var vDays) ? vDays.As<float>() : 0.0f;
            float hist = dict.TryGetValue("history_score", out var vHist) ? vHist.As<float>() : 0.5f;
            int job = dict.TryGetValue("job_id", out var vJob) ? vJob.As<int>() : 9;

            slotToTargetId[i] = targetId;
            mask[i] = 1.0f;

            int offset = i * 5;
            candFeat[offset + 0] = Math.Clamp(dist / 32.0f, 0.0f, 1.0f);
            candFeat[offset + 1] = Math.Clamp(fav / 100.0f, 0.0f, 1.0f);
            candFeat[offset + 2] = Math.Clamp(days / 10.0f, 0.0f, 1.0f);
            candFeat[offset + 3] = Math.Clamp(hist, 0.0f, 1.0f);
            candFeat[offset + 4] = Math.Clamp(job / 10.0f, 0.0f, 1.0f);
        }

        // 3. 構造 Tensor
        var initTensor = new DenseTensor<float>(initFeat, new int[] { 1, 5 });
        var candTensor = new DenseTensor<float>(candFeat, new int[] { 1, MaxCandidates, 5 });
        var maskTensor = new DenseTensor<float>(mask, new int[] { 1, MaxCandidates });

        var inputs = new List<NamedOnnxValue>
        {
            NamedOnnxValue.CreateFromTensor("initiator_features", initTensor),
            NamedOnnxValue.CreateFromTensor("candidates_features", candTensor),
            NamedOnnxValue.CreateFromTensor("candidate_mask", maskTensor)
        };

        // 4. 前向推論
        using var outputs = _session.Run(inputs);
        float[]? candScores = null;
        float[]? actionProbs = null;

        foreach (var output in outputs)
        {
            if (output.Name == "candidate_scores")
            {
                candScores = output.AsEnumerable<float>().ToArray();
            }
            else if (output.Name == "action_probs")
            {
                actionProbs = output.AsEnumerable<float>().ToArray();
            }
        }

        if (candScores == null || actionProbs == null)
        {
            return result;
        }

        // 5. 解析候選人機率並選取
        var candidateScoresDict = new Godot.Collections.Dictionary();
        var candidateProbsDict = new Godot.Collections.Dictionary();

        int highestId = -1;
        float highestScore = -1f;
        int highestSlot = -1;

        // 指數立方加權輪盤抽樣
        var expList = new List<(int slot, int id, float rawScore, double expWeight)>();
        double totalExpWeight = 0.0;

        for (int i = 0; i < validCount; i++)
        {
            int tid = slotToTargetId[i];
            float score = candScores[i];
            candidateScoresDict[tid] = score;

            if (score > highestScore)
            {
                highestScore = score;
                highestId = tid;
                highestSlot = i;
            }

            if (score > 0f)
            {
                double w = Math.Pow(score, 3.0);
                expList.Add((i, tid, score, w));
                totalExpWeight += w;
            }
        }

        int selectedSlot = highestSlot;
        int selectedTargetId = highestId;

        if (expList.Count > 0 && totalExpWeight > 0.0)
        {
            foreach (var item in expList)
            {
                candidateProbsDict[item.id] = (float)(item.expWeight / totalExpWeight);
            }

            double roll = Random.Shared.NextDouble() * totalExpWeight;
            double cumulative = 0.0;
            foreach (var item in expList)
            {
                cumulative += item.expWeight;
                if (roll <= cumulative)
                {
                    selectedTargetId = item.id;
                    selectedSlot = item.slot;
                    break;
                }
            }
        }

        result["target_id"] = selectedTargetId;
        result["highest_target_id"] = highestId;
        result["highest_score"] = highestScore > 0f ? highestScore : 0.0f;
        result["score"] = (selectedSlot >= 0 && selectedSlot < candScores.Length) ? candScores[selectedSlot] : 0.0f;
        result["candidate_scores"] = candidateScoresDict;
        result["candidate_probs"] = candidateProbsDict;

        // 6. 提取針對該目標的 7 維社交動作分佈
        if (selectedSlot >= 0 && selectedSlot < MaxCandidates)
        {
            int actionOffset = selectedSlot * 7;
            var actProbsArray = new Godot.Collections.Array<float>();
            int bestActionIdx = 0;
            float maxActionProb = -1f;

            for (int a = 0; a < 7; a++)
            {
                float p = actionProbs[actionOffset + a];
                actProbsArray.Add(p);
                if (p > maxActionProb)
                {
                    maxActionProb = p;
                    bestActionIdx = a;
                }
            }

            int predictedActionId = bestActionIdx + 1; // 1~7
            result["predicted_action_id"] = predictedActionId;
            result["action_probs"] = actProbsArray;
            result["action_name"] = NPCSocialDecision.GetSocialActionName(predictedActionId);
        }

        return result;
    }

    public void Dispose()
    {
        _session?.Dispose();
    }
}

