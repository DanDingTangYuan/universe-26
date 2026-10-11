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
        if (!File.Exists(onnxPath))
        {
            throw new FileNotFoundException("找不到社交 ONNX 模型檔案：", onnxPath);
        }

        if (!File.Exists(normalizationPath))
        {
            throw new FileNotFoundException("找不到社交 normalization.json：", normalizationPath);
        }

        string json = File.ReadAllText(normalizationPath);
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
        _session = new InferenceSession(onnxPath);
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
    /// 根據目標與是否擁有可傳播訊息決定社交行為 (1~7)
    /// </summary>
    public static int DecideSocialAction(int targetId, bool hasSpreadMessage)
    {
        if (targetId <= 0) return 0;
        if (hasSpreadMessage)
        {
            return 7; // 7 = 訊息傳播
        }
        return Random.Shared.Next(1, 7); // 1~6 隨機行為
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

