using System;
using System.IO;
using System.Text.Json;
using System.Collections.Generic;
using System.Linq;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;


public class NPCDecision : IDisposable
{
    // ============================================================
    // ONNX Runtime
    // ============================================================

    private readonly InferenceSession session;


    // ============================================================
    // Normalization
    // ============================================================

    private readonly float[] mean;
    private readonly float[] std;


    // ============================================================
    // 輸出行為名稱
    // ============================================================

    public static readonly string[] ActionNames =
    {
        "閒逛",
        "閱讀",
        "購物",
        "吃東西",
        "就醫",
        "回家休息",
        "社交",
        "巡田水",
        "販售物品"
    };

    // 初始化，載入 ONNX 模型及標準化器 normalization.json
    // 遊戲啟動時就執行，避免需要一直重新載入
    public NPCDecision(string onnxPath, string normalizationPath)
    {
        // 檢查 ONNX
        if (!Universe26.ModelResourceLoader.Exists(onnxPath))
        {
            throw new FileNotFoundException("找不到 ONNX 模型：", onnxPath);
        }

        // 檢查 JSON
        if (!Universe26.ModelResourceLoader.Exists(normalizationPath))
        {
            throw new FileNotFoundException("找不到 normalization.json：", normalizationPath);
        }

        // 載入 ONNX
        byte[] modelBytes = Universe26.ModelResourceLoader.LoadBytes(onnxPath);
        session = new InferenceSession(modelBytes);

        // 載入 normalization.json
        string json = Universe26.ModelResourceLoader.LoadText(normalizationPath);
        NormalizationData? data = JsonSerializer.Deserialize<NormalizationData>(json);
        if (data == null)
        {
            throw new Exception("無法讀取 normalization.json");
        }

        mean = data.mean;
        std = data.std;

        // 檢查資料
        if (mean == null || mean.Length != 15)
        {
            throw new Exception("normalization.json 的 mean 必須有 15 個數值。");
        }


        if (std == null || std.Length != 15)
        {
            throw new Exception("normalization.json 的 std 必須有 15 個數值。");
        }

        Console.WriteLine("NPC Decision Model 載入完成。");
    }



    // decision
    // 輸入 15 個 NPC 狀態，回傳：
    //
    // [0] 閒逛
    // [1] 閱讀
    // [2] 購物
    // [3] 吃東西
    // [4] 就醫
    // [5] 回家休息
    // [6] 社交
    // [7] 巡田水
    // [8] 販售物品
    public float[] decision(
        float hp,
        float health,
        float stamina,
        float hunger,
        float socialDesire,
        float mood,
        float jobId,
        float money,
        float wood,
        float stone,
        float mineral,
        float crops,
        float fish,
        float food,
        float lunchbox
    )
    {
        // 1. 建立原始 NPC 輸入
        // 順序要和訓練時相同
        float[] input =
        {
            hp,
            health,
            stamina,
            hunger,
            socialDesire,
            mood,
            jobId,
            money,
            wood,
            stone,
            mineral,
            crops,
            fish,
            food,
            lunchbox
        };

        // 2. 標準化
        float[] normalized = new float[15];

        for (int i = 0; i < 15; i++)
        {
            normalized[i] = (input[i] - mean[i]) / std[i];
        }

        // ========================================================
        // 3. 建立 Tensor
        // ONNX 模型輸入：
        // [batch_size, 15]
        // 現在只有一個 NPC：
        //
        // [1, 15]
        // ========================================================

        DenseTensor<float> tensor = new DenseTensor<float>(normalized, new[] { 1, 15 });

        // ========================================================
        // 4. 建立 ONNX 輸入
        // ========================================================

        string inputName = session.InputMetadata.Keys.First();

        List<NamedOnnxValue> inputs = new List<NamedOnnxValue>{NamedOnnxValue.CreateFromTensor(inputName, tensor)};

        // 5. 執行 ONNX
        using IDisposableReadOnlyCollection<DisposableNamedOnnxValue> results = session.Run(inputs);

        // 6. 取得輸出
        float[] output = results.First().AsEnumerable<float>().ToArray();

        // 7. 保留小數點後三位(防止格式錯誤)
        for (int i = 0; i < output.Length; i++)
        {
            output[i] =(float)Math.Round(output[i], 3);
            if (Math.Abs(output[i]) < 0.0005f)
            {
                output[i] = 0f;
            }
        }

        return output;
    }

    // 找出最高分行為
    public int GetBestAction(float[] scores)
    {
        if (scores == null || scores.Length == 0)
        {
            return -1;
        }

        int bestIndex = 0;
        for (int i = 1; i < scores.Length; i++)
        {
            if (scores[i] > scores[bestIndex])
            {
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    // 取得最高分行為名稱
    public string GetBestActionName(float[] scores)
    {
        int index = GetBestAction(scores);
        if (index < 0 || index >= ActionNames.Length)
        {
            return "無";
        }
        return ActionNames[index];
    }

    /// <summary>
    /// 依據行為分數與可選權重進行加權輪盤機率抽樣 (Roulette Wheel Selection)
    /// </summary>
    public int SampleAction(float[] scores, float[]? offsets = null)
    {
        if (scores == null || scores.Length == 0)
        {
            return -1;
        }

        int count = scores.Length;
        double[] weightedScores = new double[count];
        double totalScore = 0;

        for (int i = 0; i < count; i++)
        {
            double weight = (offsets != null && i < offsets.Length) ? offsets[i] : 1.0;
            if (weight < 0) weight = 0;
            double s = Math.Max(0f, scores[i]) * weight;
            weightedScores[i] = s;
            totalScore += s;
        }

        if (totalScore <= 0)
        {
            return GetBestAction(scores);
        }

        double randomValue = Random.Shared.NextDouble() * totalScore;
        double cumulative = 0;
        for (int i = 0; i < count; i++)
        {
            cumulative += weightedScores[i];
            if (randomValue < cumulative)
            {
                return i;
            }
        }

        return count - 1;
    }

    //回傳行動的目的地(待修改)
    public int GetLocation(int bestIndex, int food, int lunchbox) {
        switch (bestIndex)
        {
            case 0: // 閒逛，逛到社交廣場的機率稍高
                int randomNum = Random.Shared.Next(1, 26); //隨機產生 1~25 的數字
                if (randomNum < 20) {
                    return randomNum;
                }
                return 20; // 社交廣場

            case 1: // 閱讀
                return 19; // 圖書館
            case 2: // 購物
                return 13; // 餐廳
            case 3: // 吃東西
                if (food != 0 || lunchbox != 0) 
                {
                    return 0; // 如果有食物或便當，原地吃
                }
                return 13;
            case 4: // 就醫
                return 18; // 醫院
            case 5: // 回家休息
                return 21; // 回家的行動代碼
            case 6: // 社交
                return 20; // 進行社交決策，暫時使用社交廣場代替
            case 7: // 巡田水
                return 16; // 農田
            case 8: // 販售物品
                return 12; // 市場
            default:
                return -1; // 無效行為索引
        }
    }

    // 釋放 ONNX Runtime
    public void Dispose()
    {
        session.Dispose();
    }

    // 對應 normalization.json
    private class NormalizationData
    {
        public string[] input_columns { get; set; } = Array.Empty<string>();
        public float[] mean { get; set; } = Array.Empty<float>();
        public float[] std { get; set; } = Array.Empty<float>();
    }
}
