using System;
using System.IO;
using Godot;

namespace Universe26;

/// <summary>
/// 26號宇宙 (Universe 26) - 模型與設定資源載入器
/// 同步支援 Godot 虛擬檔案系統 (res:// 與 .pck 封裝) 與本機實體檔案路徑
/// </summary>
public static class ModelResourceLoader
{
    public static bool Exists(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return false;
        }
        if (Godot.FileAccess.FileExists(path))
        {
            return true;
        }
        try
        {
            string globalPath = ProjectSettings.GlobalizePath(path);
            if (System.IO.File.Exists(globalPath))
            {
                return true;
            }
        }
        catch { }
        return System.IO.File.Exists(path);
    }

    public static byte[] LoadBytes(string path)
    {
        if (Godot.FileAccess.FileExists(path))
        {
            byte[] bytes = Godot.FileAccess.GetFileAsBytes(path);
            if (bytes != null && bytes.Length > 0)
            {
                return bytes;
            }
        }
        string globalPath = ProjectSettings.GlobalizePath(path);
        if (System.IO.File.Exists(globalPath))
        {
            return System.IO.File.ReadAllBytes(globalPath);
        }
        if (System.IO.File.Exists(path))
        {
            return System.IO.File.ReadAllBytes(path);
        }
        throw new FileNotFoundException($"找不到模型二進制檔案：{path} (實體探查路徑: {globalPath})");
    }

    public static string LoadText(string path)
    {
        if (Godot.FileAccess.FileExists(path))
        {
            return Godot.FileAccess.GetFileAsString(path);
        }
        string globalPath = ProjectSettings.GlobalizePath(path);
        if (System.IO.File.Exists(globalPath))
        {
            return System.IO.File.ReadAllText(globalPath);
        }
        if (System.IO.File.Exists(path))
        {
            return System.IO.File.ReadAllText(path);
        }
        throw new FileNotFoundException($"找不到設定文本檔案：{path} (實體探查路徑: {globalPath})");
    }
}

