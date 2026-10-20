using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace Universe26;

/// <summary>
/// 26號宇宙 (Universe 26) - Causal Transformer 決策推論引擎
/// 載入 universe_policy_transformer.onnx，提供單步與滑動窗口毫秒級推論
/// </summary>
public class NPCTransformerDecision : IDisposable
{
    private readonly InferenceSession _session;

    public NPCTransformerDecision(string onnxPath)
    {
        if (!ModelResourceLoader.Exists(onnxPath))
        {
            throw new FileNotFoundException("找不到 Transformer ONNX 模型：", onnxPath);
        }

        var sessionOptions = new SessionOptions
        {
            GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
            ExecutionMode = ExecutionMode.ORT_SEQUENTIAL
        };

        byte[] modelBytes = ModelResourceLoader.LoadBytes(onnxPath);
        _session = new InferenceSession(modelBytes, sessionOptions);
        Godot.GD.Print($"[NPCTransformerDecision] Transformer 決策大腦載入完成: {onnxPath} ({modelBytes.Length} bytes)");
    }

    /// <summary>
    /// 單步推論：傳入當前 15 維特徵與環境/身份資訊，輸出 9 維行為分數與 26 維地點分數
    /// </summary>
    /// <param name="stats">15 維原始生理/物資向量 (對應 NPCData.to_feature_vector)</param>
    /// <param name="tick">當前遊戲 Tick (0~1440)</param>
    /// <param name="jobId">職業 ID (1~9)</param>
    /// <param name="homePoi">自宅 POI (0~25)</param>
    /// <param name="prevAction">上一時間步執行的行動代碼 (0~8)</param>
    /// <returns>包含 action_scores (9維) 與 poi_scores (26維) 的字典</returns>
    public TransformerInferenceResult EvaluateStep(
        float[] stats,
        int tick,
        int jobId,
        int homePoi,
        int prevAction)
    {
        if (stats == null || stats.Length < 15)
        {
            throw new ArgumentException("stats 長度必須至少為 15");
        }

        // 1. 特徵正規化 (嚴格對齊 preprocess.py)
        float[] contNorm = new float[15];
        contNorm[0] = Math.Clamp(stats[0] / 100.0f, 0.0f, 1.0f); // hp
        contNorm[1] = Math.Clamp(stats[1] / 100.0f, 0.0f, 1.0f); // health
        contNorm[2] = Math.Clamp(stats[2] / 100.0f, 0.0f, 1.0f); // stamina
        contNorm[3] = Math.Clamp(stats[3] / 100.0f, 0.0f, 1.0f); // hunger
        contNorm[4] = Math.Clamp(stats[4] / 100.0f, 0.0f, 1.0f); // social_desire
        contNorm[5] = Math.Clamp(stats[5] / 100.0f, 0.0f, 1.0f); // mood
        contNorm[6] = (float)(Math.Log(Math.Max(0, stats[7]) + 1.0) / 10.0); // money
        contNorm[7] = (float)(Math.Log(Math.Max(0, stats[8]) + 1.0) / 5.0);  // wood
        contNorm[8] = (float)(Math.Log(Math.Max(0, stats[9]) + 1.0) / 5.0);  // stone
        contNorm[9] = (float)(Math.Log(Math.Max(0, stats[10]) + 1.0) / 5.0); // mineral
        contNorm[10] = (float)(Math.Log(Math.Max(0, stats[11]) + 1.0) / 5.0); // crops
        contNorm[11] = (float)(Math.Log(Math.Max(0, stats[12]) + 1.0) / 5.0); // fish
        contNorm[12] = (float)(Math.Log(Math.Max(0, stats[13]) + 1.0) / 5.0); // food
        contNorm[13] = (float)(Math.Log(Math.Max(0, stats[14]) + 1.0) / 5.0); // lunchbox
        contNorm[14] = Math.Clamp((float)tick / 1440.0f, 0.0f, 1.0f);        // tick_norm

        // 2. 離散特徵 (4 維)
        int periodId = GetPeriodId(tick / 60);
        long[] disc = new long[4]
        {
            periodId,
            Math.Clamp(jobId, 1, 9),
            Math.Clamp(homePoi, 0, 25),
            Math.Clamp(prevAction, 0, 8)
        };

        // 3. 構造 Tensor (Batch Size = 1, Sequence Length = 1)
        var contTensor = new DenseTensor<float>(contNorm, new int[] { 1, 1, 15 });
        var discTensor = new DenseTensor<long>(disc, new int[] { 1, 1, 4 });

        var inputs = new List<NamedOnnxValue>
        {
            NamedOnnxValue.CreateFromTensor("continuous_features", contTensor),
            NamedOnnxValue.CreateFromTensor("discrete_features", discTensor)
        };

        // 4. 前向推論
        using var outputs = _session.Run(inputs);

        float[] actionScores = new float[9];
        float[] poiScores = new float[26];

        foreach (var output in outputs)
        {
            if (output.Name == "action_logits")
            {
                var tensor = output.AsTensor<float>();
                for (int i = 0; i < 9; i++)
                {
                    actionScores[i] = tensor[0, 0, i];
                }
            }
            else if (output.Name == "poi_logits")
            {
                var tensor = output.AsTensor<float>();
                for (int i = 0; i < 26; i++)
                {
                    poiScores[i] = tensor[0, 0, i];
                }
            }
        }

        // 5. Softmax 轉為機率分佈
        float[] actionProbs = Softmax(actionScores);
        float[] poiProbs = Softmax(poiScores);

        int bestAction = ArgMax(actionProbs);
        int bestPoi = ArgMax(poiProbs);

        return new TransformerInferenceResult
        {
            ActionScores = actionProbs,
            PoiScores = poiProbs,
            BestAction = bestAction,
            BestPoi = bestPoi
        };
    }

    private static int GetPeriodId(int hour)
    {
        if (hour >= 5 && hour < 8) return 0;   // 清晨
        if (hour >= 8 && hour < 12) return 1;  // 上午
        if (hour >= 12 && hour < 14) return 2; // 中午
        if (hour >= 14 && hour < 17) return 3; // 下午
        if (hour >= 17 && hour < 20) return 4; // 傍晚
        if (hour >= 20 && hour < 24) return 5; // 夜晚
        return 6;                              // 深夜
    }

    private static float[] Softmax(float[] logits)
    {
        float max = logits.Max();
        float sum = 0f;
        float[] exp = new float[logits.Length];
        for (int i = 0; i < logits.Length; i++)
        {
            exp[i] = (float)Math.Exp(logits[i] - max);
            sum += exp[i];
        }
        for (int i = 0; i < logits.Length; i++)
        {
            exp[i] /= (sum > 0 ? sum : 1f);
        }
        return exp;
    }

    private static int ArgMax(float[] arr)
    {
        int best = 0;
        float maxVal = arr[0];
        for (int i = 1; i < arr.Length; i++)
        {
            if (arr[i] > maxVal)
            {
                maxVal = arr[i];
                best = i;
            }
        }
        return best;
    }

    public void Dispose()
    {
        _session?.Dispose();
    }
}

public class TransformerInferenceResult
{
    public float[] ActionScores { get; set; } = Array.Empty<float>();
    public float[] PoiScores { get; set; } = Array.Empty<float>();
    public int BestAction { get; set; } = 0;
    public int BestPoi { get; set; } = 0;
}

