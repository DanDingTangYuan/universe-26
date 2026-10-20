using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace Universe26;

/// <summary>
/// NPC 社交決策推論引擎 (基於 Microsoft.ML.OnnxRuntime)
/// 接收 7 維特徵，輸出社交互動分數 (0.0 ~ 1.0)
/// </summary>
public class NPCSocialDecision : IDisposable
{
    private readonly InferenceSession _session;
    private readonly float[] _mean;
    private readonly float[] _std;
    private readonly string _inputName;

    public static readonly string[] SocialActionNames =
    {
        "無",
        "普通聊天",
        "討論主題",
        "詢問問題",
        "共同活動",
        "捉弄",
        "欺騙",
        "訊息傳播"
    };

    public NPCSocialDecision(string onnxPath, string normalizationPath)
    {
        if (!Universe26.ModelResourceLoader.Exists(onnxPath))
        {
            throw new FileNotFoundException("找不到社交 ONNX 模型檔案：", onnxPath);
        }

        if (!Universe26.ModelResourceLoader.Exists(normalizationPath))
        {
            throw new FileNotFoundException("找不到社交 normalization.json：", normalizationPath);
        }

        string json = Universe26.ModelResourceLoader.LoadText(normalizationPath);
        NormalizationData? data = JsonSerializer.Deserialize<NormalizationData>(json);

        if (data == null)
        {
            throw new InvalidOperationException("無法解析社交 normalization.json。");
        }

        if (data.mean == null || data.mean.Length != 7)
        {
            throw new InvalidOperationException("社交 normalization.json 的 mean 必須包含 7 個數值。");
        }

        if (data.std == null || data.std.Length != 7)
        {
            throw new InvalidOperationException("社交 normalization.json 的 std 必須包含 7 個數值。");
        }

        for (int i = 0; i < 7; i++)
        {
            if (float.IsNaN(data.mean[i]) || float.IsInfinity(data.mean[i]) ||
                float.IsNaN(data.std[i]) || float.IsInfinity(data.std[i]) || data.std[i] <= 0)
            {
                throw new InvalidOperationException($"社交 normalization.json 第 {i} 個標準化參數無效。");
            }
        }

        _mean = data.mean;
        _std = data.std;
        byte[] modelBytes = Universe26.ModelResourceLoader.LoadBytes(onnxPath);
        _session = new InferenceSession(modelBytes);
        _inputName = _session.InputMetadata.Keys.First();
    }

    /// <summary>
    /// 計算針對特定目標 NPC 的社交意願分數 (0.0 ~ 1.0)
    /// </summary>
    /// <param name="time">當前時間 Tick (0 ~ 1440)</param>
    /// <param name="socialDesire">社交慾望 (0 ~ 100)</param>
    /// <param name="mood">心情 (0 ~ 100)</param>
    /// <param name="favorability">對目標的好感度 (0 ~ 100)</param>
    /// <param name="distance">與目標的距離 (格數，<= 32)</param>
    /// <param name="daysSinceInteraction">距離上次互動天數 (0 ~ 10)</param>
    /// <param name="historyScore">歷史事件評分 (0.0 ~ 1.0)</param>
    /// <returns>互動分數 (0.0 ~ 1.0)</returns>
    public float Evaluate(
        float time,
        float socialDesire,
        float mood,
        float favorability,
        float distance,
        float daysSinceInteraction,
        float historyScore)
    {
        // 1. 特徵轉換 (對齊訓練設定)
        float[] input =
        {
            time,
            1.0f - Math.Clamp(socialDesire, 0f, 100f) / 100.0f,
            Math.Clamp(mood, 0f, 100f) / 100.0f,
            Math.Clamp(favorability, 0f, 100f) / 100.0f,
            1.0f - Math.Clamp(distance, 0f, 32f) / 32.0f,
            Math.Clamp(daysSinceInteraction, 0f, 10f) / 10.0f,
            Math.Clamp(historyScore, 0f, 1.0f)
        };

        // 2. 標準化
        float[] normalized = new float[7];
        for (int i = 0; i < 7; i++)
        {
            normalized[i] = (input[i] - _mean[i]) / _std[i];
        }

        // 3. Tensor 前向傳播
        DenseTensor<float> tensor = new DenseTensor<float>(normalized, new[] { 1, 7 });
        List<NamedOnnxValue> inputs = new List<NamedOnnxValue>
        {
            NamedOnnxValue.CreateFromTensor(_inputName, tensor)
        };

        using IDisposableReadOnlyCollection<DisposableNamedOnnxValue> results = _session.Run(inputs);
        float[] output = results.First().AsEnumerable<float>().ToArray();

        if (output.Length != 1)
        {
            throw new InvalidOperationException("社交模型輸出長度必須為 1。");
        }

        float score = output[0];
        if (float.IsNaN(score) || float.IsInfinity(score))
        {
            return 0f;
        }

        // 限制於 0~1 並保留三位小數
        score = Math.Clamp(score, 0f, 1f);
        score = (float)Math.Round(score, 3);
        if (Math.Abs(score) < 0.0005f)
        {
            score = 0f;
        }

        return score;
    }

    /// <summary>
    /// 取得社交行為名稱
    /// </summary>
    public static string GetSocialActionName(int actionId)
    {
        if (actionId >= 0 && actionId < SocialActionNames.Length)
        {
            return SocialActionNames[actionId];
        }
        return "未知";
    }

    /// <summary>
    /// 根據目標與是否擁有可傳播訊息決定社交行為 (1~7，相容舊簽章)
    /// </summary>
    public static int DecideSocialAction(int targetId, bool hasSpreadMessage)
    {
        return DecideSocialAction(targetId, hasSpreadMessage, 50f, 50f);
    }

    /// <summary>
    /// 根據目標、好感度、心情與是否擁有可傳播訊息決定啟發式社交行為 (1~7)
    /// 1=普通聊天, 2=討論主題, 3=詢問問題, 4=共同活動, 5=捉弄, 6=欺騙, 7=訊息傳播
    /// 為後續 Transformer 訓練提供具備正負摩擦多樣性、高因果性的專家軌跡
    /// </summary>
    public static int DecideSocialAction(int targetId, bool hasSpreadMessage, float favorability, float mood)
    {
        if (targetId <= 0) return 0;
        if (hasSpreadMessage)
        {
            return 7; // 7 = 訊息傳播
        }

        int roll = Random.Shared.Next(1, 101);

        // 階層 1: 心情差 / 情緒低落 (mood < 45f) - 大幅提升捉弄與欺騙機率，打破烏托邦
        if (mood < 45f)
        {
            // 捉弄 20% (1~20), 欺騙 15% (21~35), 詢問問題 25% (36~60), 普通聊天 40% (61~100)
            if (roll <= 20) return 5;
            if (roll <= 35) return 6;
            if (roll <= 60) return 3;
            return 1;
        }

        // 階層 2: 宿敵/冷淡關係 (favorability < 35f) 且心情正常 (mood >= 45f)
        if (favorability < 35f)
        {
            // 詢問問題 40% (1~40), 普通聊天 30% (41~70), 捉弄 15% (71~85), 欺騙 15% (86~100)
            if (roll <= 40) return 3;
            if (roll <= 70) return 1;
            if (roll <= 85) return 5;
            return 6;
        }

        // 階層 3: 好友關係 (favorability >= 65f) 且心情良好 (mood >= 45f)
        if (favorability >= 65f)
        {
            // 共同活動 45% (1~45), 討論主題 35% (46~80), 普通聊天 15% (81~95), 友善玩笑捉弄 5% (96~100)
            if (roll <= 45) return 4;
            if (roll <= 80) return 2;
            if (roll <= 95) return 1;
            return 5;
        }

        // 階層 4: 一般關係與破冰期 (35f <= favorability < 65f) 且心情正常 (mood >= 45f)
        // 賦予自然的日常小摩擦機率：普通聊天 60% (1~60), 詢問 20% (61~80), 討論 10% (81~90), 捉弄 5% (91~95), 欺騙 5% (96~100)
        if (roll <= 60) return 1;
        if (roll <= 80) return 3;
        if (roll <= 90) return 2;
        if (roll <= 95) return 5;
        return 6;
    }

    public void Dispose()
    {
        _session?.Dispose();
    }

    private class NormalizationData
    {
        public string[] input_columns { get; set; } = Array.Empty<string>();
        public float[] mean { get; set; } = Array.Empty<float>();
        public float[] std { get; set; } = Array.Empty<float>();
    }
}

