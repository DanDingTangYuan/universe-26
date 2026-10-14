using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using npc_class;
using computeAttribute;

public class UseDatabase
{
    public static string DatabasePath { get; set; } = "NPC_Memory.db";
    public static string ConnectionString => $"Data Source={DatabasePath};Default Timeout=5;";    // 資料庫檔名預設為 NPC_Memory.db

    //============================================================
    // 1. 初始化所有資料庫的函式 (什麼都沒有的情況下，剛打開遊戲用)
    //============================================================
    public static void InitializeDatabase()
    {
        CreateDatabase();
        InitializeMTM();
        InitializeLTM();
        InitializeLTSM();
    }

    // 1-1. 建立記憶資料庫及資料表
    public static void CreateDatabase()
    {
        using var connection = new SqliteConnection(ConnectionString);

        connection.Open();

        // ============================================================
        // 1. STSM
        // ============================================================

        string createSTSM = """
            CREATE TABLE IF NOT EXISTS STSM
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                time INTEGER NOT NULL,
                npc_id INTEGER NOT NULL,
                target_npc_id INTEGER NOT NULL,
                event_type INTEGER NOT NULL,
                change_trust INTEGER NOT NULL,
                change_friendship INTEGER NOT NULL,
                change_mood INTEGER NOT NULL,
                content TEXT
            );
            """;


        // ============================================================
        // 2. MTSM
        // ============================================================

        string createMTSM = """
            CREATE TABLE IF NOT EXISTS MTSM
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                npc_id INTEGER NOT NULL,
                target_npc_id INTEGER NOT NULL,
                is_Positive BOOLEAN NOT NULL,
                content TEXT,
                importance INTEGER NOT NULL
            );
            """;


        // ============================================================
        // 3. LTSM
        // ============================================================

        string createLTSM = """
            CREATE TABLE IF NOT EXISTS LTSM
            (
                npc_id INTEGER PRIMARY KEY

            """;

        // impact_trust_1 ~ impact_trust_20
        for (int n = 1; n <= 20; n++)
        {
            createLTSM += $"""

                , impact_trust_{n} INTEGER NOT NULL
            """;
        }

        // impact_friendship_1 ~ impact_friendship_20
        for (int n = 1; n <= 20; n++)
        {
            createLTSM += $"""

                , impact_friendship_{n} INTEGER NOT NULL
            """;
        }

        createLTSM += """
            );
            """;


        // ============================================================
        // 4. STM
        // ============================================================

        string createSTM = """
            CREATE TABLE IF NOT EXISTS STM
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                npc_id INTEGER NOT NULL,
                time INTEGER NOT NULL,
                action INTEGER NOT NULL,
                location INTEGER NOT NULL,
                change_hp INTEGER NOT NULL,
                change_health INTEGER NOT NULL,
                change_stamina INTEGER NOT NULL,
                change_hunger INTEGER NOT NULL,
                change_socialDesire INTEGER NOT NULL,
                change_mood INTEGER NOT NULL,
                change_money INTEGER NOT NULL,
                change_wood INTEGER NOT NULL,
                change_stone INTEGER NOT NULL,
                change_mineral INTEGER NOT NULL,
                change_crops INTEGER NOT NULL,
                change_fish INTEGER NOT NULL,
                change_food INTEGER NOT NULL,
                change_lunchbox INTEGER NOT NULL,
                reward_value DOUBLE NOT NULL
            );
            """;


        // ============================================================
        // 5. MTM
        // ============================================================

        string createMTM = """
            CREATE TABLE IF NOT EXISTS MTM
            (
                npc_id INTEGER PRIMARY KEY,
                hp INTEGER NOT NULL,
                health INTEGER NOT NULL,
                stamina INTEGER NOT NULL,
                hunger INTEGER NOT NULL,
                socialDesire INTEGER NOT NULL,
                mood INTEGER NOT NULL,
                money INTEGER NOT NULL,
                wood INTEGER NOT NULL,
                stone INTEGER NOT NULL,
                mineral INTEGER NOT NULL,
                crops INTEGER NOT NULL,
                fish INTEGER NOT NULL,
                food INTEGER NOT NULL,
                lunchbox INTEGER NOT NULL
            );
            """;


        // ============================================================
        // 6. LTM
        // ============================================================

        string createLTM = """
            CREATE TABLE IF NOT EXISTS LTM
            (
                npc_id INTEGER PRIMARY KEY,
                medicine_jar BOOLEAN NOT NULL DEFAULT 0,
                healthy BOOLEAN NOT NULL DEFAULT 0,
                greedy BOOLEAN NOT NULL DEFAULT 0,
                eat_like_a_bird BOOLEAN NOT NULL DEFAULT 0,
                social_person BOOLEAN NOT NULL DEFAULT 0,
                asocial BOOLEAN NOT NULL DEFAULT 0,
                optimistic BOOLEAN NOT NULL DEFAULT 0,
                pessimistic BOOLEAN NOT NULL DEFAULT 0,
                debility BOOLEAN NOT NULL DEFAULT 0,
                strong BOOLEAN NOT NULL DEFAULT 0,
                big_e BOOLEAN NOT NULL DEFAULT 0,
                big_i BOOLEAN NOT NULL DEFAULT 0,
                wander REAL NOT NULL DEFAULT 0,
                read REAL NOT NULL DEFAULT 0,
                shopping REAL NOT NULL DEFAULT 0,
                eat REAL NOT NULL DEFAULT 0,
                go_to_a_doctor REAL NOT NULL DEFAULT 0,
                go_home REAL NOT NULL DEFAULT 0,
                social_contact REAL NOT NULL DEFAULT 0,
                check_the_field REAL NOT NULL DEFAULT 0,
                selling REAL NOT NULL DEFAULT 0, 
                jobID INTEGER NOT NULL,
                home INTEGER NOT NULL
            );
            """;


        // ============================================================
        // 依照順序建立資料表
        //
        // STSM
        // MTSM
        // LTSM
        // STM
        // MTM
        // LTM
        // ============================================================

        using var command = connection.CreateCommand();

        // 1. STSM
        command.CommandText = createSTSM;
        command.ExecuteNonQuery();

        // 2. MTSM
        command.CommandText = createMTSM;
        command.ExecuteNonQuery();

        // 3. LTSM
        command.CommandText = createLTSM;
        command.ExecuteNonQuery();

        // 4. STM
        command.CommandText = createSTM;
        command.ExecuteNonQuery();

        // 5. MTM
        command.CommandText = createMTM;
        command.ExecuteNonQuery();

        // 6. LTM
        command.CommandText = createLTM;
        command.ExecuteNonQuery();

        //Console.WriteLine("SQLite 資料庫建立完成。");
        //Console.WriteLine("資料庫名稱：NPC_Memory.db");
        //Console.WriteLine("資料表建立順序：STSM → MTSM → LTSM → STM → MTM → LTM");
    }

    // 1-2. 在MTM插入初始化資料的函式
    public static void InitializeMTM()
    {
        using var connection = new SqliteConnection(ConnectionString);

        connection.Open();

        using var transaction = connection.BeginTransaction();

        // ============================================================
        // 檢查並建立 NPC 1 ~ 20
        // ============================================================

        foreach (int npcID in Enumerable.Range(1, 20))
        {
            // --------------------------------------------------------
            // 檢查 NPC 是否已經存在
            // --------------------------------------------------------

            using var checkCommand = connection.CreateCommand();

            checkCommand.Transaction = transaction;

            checkCommand.CommandText = """
            SELECT COUNT(*)
            FROM MTM
            WHERE npc_id = $npc_id;
            """;

            checkCommand.Parameters.AddWithValue("$npc_id", npcID);

            long count = (long)checkCommand.ExecuteScalar()!;


            // --------------------------------------------------------
            // 如果已經存在，就跳過
            // --------------------------------------------------------

            if (count > 0)
            {
                continue;
            }


            // --------------------------------------------------------
            // 新增 NPC 預設資料
            //
            // 生命值、健康度、體力、飽食度、
            // 社交慾望、心情、持有金錢 = 100
            //
            // 其他物品 = 0
            //
            // jobID、home 不在 MTM 中處理
            // --------------------------------------------------------

            using var insertCommand = connection.CreateCommand();

            insertCommand.Transaction = transaction;

            insertCommand.CommandText = """
            INSERT INTO MTM
            (
                npc_id,
                hp,
                health,
                stamina,
                hunger,
                socialDesire,
                mood,
                money,
                wood,
                stone,
                mineral,
                crops,
                fish,
                food,
                lunchbox
            )
            VALUES
            (
                $npc_id,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                0,
                0,
                0,
                0,
                0,
                0,
                0
            );
            """;

            insertCommand.Parameters.AddWithValue("$npc_id", npcID);

            insertCommand.ExecuteNonQuery();
        }


        // ============================================================
        // 確認全部操作成功後提交
        // ============================================================

        transaction.Commit();

        //Console.WriteLine("MTM NPC 預設資料初始化完成。");
    }

    // 1-3. 在LTM插入初始化資料的函式
    public static void InitializeLTM()
    {
        using var connection = new SqliteConnection(ConnectionString);

        connection.Open();

        using var transaction = connection.BeginTransaction();


        // ============================================================
        // NPC 職業編號
        // ============================================================

        Dictionary<int, int> jobIDs = new()
    {
        { 1, 1 },
        { 2, 1 },

        { 3, 2 },
        { 4, 2 },

        { 5, 3 },
        { 6, 3 },

        { 7, 4 },
        { 8, 4 },

        { 9, 5 },
        { 10, 5 },

        { 11, 6 },
        { 12, 6 },

        { 13, 7 },
        { 14, 7 },

        { 15, 8 },

        { 16, 9 },
        { 17, 9 },
        { 18, 9 },
        { 19, 9 },
        { 20, 9 }
    };


        // ============================================================
        // NPC 居住地編號
        // ============================================================

        Dictionary<int, int> homeIDs = new()
    {
        { 1, 1 },

        { 2, 2 },
        { 16, 2 },

        { 3, 3 },
        { 17, 3 },

        { 4, 4 },
        { 18, 4 },

        { 5, 5 },
        { 6, 5 },

        { 7, 6 },
        { 19, 6 },

        { 8, 7 },
        { 20, 7 },

        { 9, 8 },

        { 10, 9 },

        { 11, 10 },
        { 12, 10 },

        { 13, 11 },
        { 14, 11 },

        { 15, 12 }
    };


        // ============================================================
        // 檢查並建立 NPC 1 ~ 20
        // ============================================================

        foreach (int npcID in Enumerable.Range(1, 20))
        {
            // --------------------------------------------------------
            // 檢查 NPC 是否已經存在
            // --------------------------------------------------------

            using var checkCommand = connection.CreateCommand();

            checkCommand.Transaction = transaction;

            checkCommand.CommandText = """
            SELECT COUNT(*)
            FROM LTM
            WHERE npc_id = $npc_id;
            """;

            checkCommand.Parameters.AddWithValue("$npc_id", npcID);

            long count = (long)checkCommand.ExecuteScalar()!;


            // --------------------------------------------------------
            // 如果已經存在，就跳過
            // --------------------------------------------------------

            if (count > 0)
            {
                continue;
            }


            // --------------------------------------------------------
            // 取得預設職業與居住地
            // --------------------------------------------------------

            int jobID = jobIDs[npcID];
            int homeID = homeIDs[npcID];


            // --------------------------------------------------------
            // 新增 NPC 預設資料
            //
            // 詞條：
            // false
            //
            // 行為偏移量：
            // 1.0
            //
            // jobID / home：
            // 使用上面的對照表
            // --------------------------------------------------------

            using var insertCommand = connection.CreateCommand();

            insertCommand.Transaction = transaction;

            insertCommand.CommandText = """
            INSERT INTO LTM
            (
                npc_id,

                jobID,
                home,

                medicine_jar,
                healthy,
                greedy,
                eat_like_a_bird,
                social_person,
                asocial,
                optimistic,
                pessimistic,
                debility,
                strong,
                big_e,
                big_i,

                wander,
                read,
                shopping,
                eat,
                go_to_a_doctor,
                go_home,
                social_contact,
                check_the_field,
                selling
            )
            VALUES
            (
                $npc_id,

                $jobID,
                $home,

                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,

                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0
            );
            """;


            insertCommand.Parameters.AddWithValue("$npc_id", npcID);
            insertCommand.Parameters.AddWithValue("$jobID", jobID);
            insertCommand.Parameters.AddWithValue("$home", homeID);

            insertCommand.ExecuteNonQuery();
        }


        // ============================================================
        // 確認全部操作成功後提交
        // ============================================================

        transaction.Commit();

        //Console.WriteLine("LTM NPC 預設資料初始化完成。");
    }

    // 1-4. 在LTSM插入初始化資料的函式
    public static void InitializeLTSM()
    {
        using var connection = new SqliteConnection(ConnectionString);

        connection.Open();

        using var transaction = connection.BeginTransaction();


        // ============================================================
        // 檢查並建立 NPC 1 ~ 20
        // ============================================================

        foreach (int npcID in Enumerable.Range(1, 20))
        {
            // --------------------------------------------------------
            // 檢查 NPC 是否已經存在
            // --------------------------------------------------------

            using var checkCommand = connection.CreateCommand();

            checkCommand.Transaction = transaction;

            checkCommand.CommandText = """
            SELECT COUNT(*)
            FROM LTSM
            WHERE npc_id = $npc_id;
            """;

            checkCommand.Parameters.AddWithValue("$npc_id", npcID);

            long count = (long)checkCommand.ExecuteScalar()!;


            // --------------------------------------------------------
            // 如果已經存在，就跳過
            // --------------------------------------------------------

            if (count > 0)
            {
                continue;
            }


            // --------------------------------------------------------
            // 建立 INSERT 指令
            // --------------------------------------------------------

            using var insertCommand = connection.CreateCommand();

            insertCommand.Transaction = transaction;


            // --------------------------------------------------------
            // 建立欄位名稱
            // --------------------------------------------------------

            List<string> columns = new()
        {
            "npc_id"
        };


            // --------------------------------------------------------
            // 建立參數名稱
            // --------------------------------------------------------

            List<string> values = new()
        {
            "$npc_id"
        };


            // --------------------------------------------------------
            // impact_trust_1 ~ impact_trust_20
            // --------------------------------------------------------

            for (int n = 1; n <= 20; n++)
            {
                columns.Add($"impact_trust_{n}");
                values.Add($"$trust_{n}");
            }


            // --------------------------------------------------------
            // impact_friendship_1 ~ impact_friendship_20
            // --------------------------------------------------------

            for (int n = 1; n <= 20; n++)
            {
                columns.Add($"impact_friendship_{n}");
                values.Add($"$friendship_{n}");
            }


            // --------------------------------------------------------
            // 組合 INSERT SQL
            // --------------------------------------------------------

            insertCommand.CommandText = $"""
            INSERT INTO LTSM
            (
                {string.Join(",\n                ", columns)}
            )
            VALUES
            (
                {string.Join(",\n                ", values)}
            );
            """;


            // --------------------------------------------------------
            // NPC ID
            // --------------------------------------------------------

            insertCommand.Parameters.AddWithValue("$npc_id", npcID);


            // --------------------------------------------------------
            // 所有信任度預設 50
            // --------------------------------------------------------

            for (int n = 1; n <= 20; n++)
            {
                insertCommand.Parameters.AddWithValue($"$trust_{n}", 50);
            }


            // --------------------------------------------------------
            // 所有好感度預設 50
            // --------------------------------------------------------

            for (int n = 1; n <= 20; n++)
            {
                insertCommand.Parameters.AddWithValue($"$friendship_{n}", 50);
            }


            // --------------------------------------------------------
            // 執行新增
            // --------------------------------------------------------

            insertCommand.ExecuteNonQuery();
        }


        // ============================================================
        // 確認全部操作成功後提交
        // ============================================================

        transaction.Commit();

        //Console.WriteLine("LTSM NPC 預設資料初始化完成。");
    }

    //============================================================
    //2. 清除所有舊有資料後，重新初始化資料庫的函式 (有舊資料的情況下，開新遊戲檔案用)
    //============================================================
    public static void ResetDatabase()
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();
        using var transaction = connection.BeginTransaction();

        // 刪除所有資料表
        string[] tables = { "STSM", "MTSM", "LTSM", "STM", "MTM", "LTM" };
        foreach (string table in tables)
        {
            using var dropCommand = connection.CreateCommand();
            dropCommand.Transaction = transaction;
            dropCommand.CommandText = $"DROP TABLE IF EXISTS {table};";
            dropCommand.ExecuteNonQuery();
        }
        // 確認全部操作成功後提交
        transaction.Commit();
        //Console.WriteLine("舊有資料已清除。");

        // 重新初始化資料庫
        InitializeDatabase();
        //Console.WriteLine("資料庫已重新初始化。");
    }

    //============================================================
    //3. 載入現有NPC數值(MTM、LTM)到npc_class內
    //============================================================
    public static void LoadMTMintoNPCclass(NPCclass npc)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.Parameters.AddWithValue("$npc_id", npc.Id);

        // 讀取 MTM
        command.CommandText = """
        SELECT *
        FROM MTM
        WHERE npc_id = $npc_id;
        """;

        using (var reader1 = command.ExecuteReader())
        {
            if (reader1.Read())
            {
                npc.Physiological.Hp = reader1.GetInt32(reader1.GetOrdinal("hp"));
                npc.Physiological.Health = reader1.GetInt32(reader1.GetOrdinal("health"));
                npc.Physiological.Stamina = reader1.GetInt32(reader1.GetOrdinal("stamina"));
                npc.Physiological.Hunger = reader1.GetInt32(reader1.GetOrdinal("hunger"));
                npc.Physiological.SocialDesire = reader1.GetInt32(reader1.GetOrdinal("socialDesire"));
                npc.Physiological.Mood = reader1.GetInt32(reader1.GetOrdinal("mood"));
                npc.Physiological.Money = reader1.GetInt32(reader1.GetOrdinal("money"));
                npc.Physiological.Wood = reader1.GetInt32(reader1.GetOrdinal("wood"));
                npc.Physiological.Stone = reader1.GetInt32(reader1.GetOrdinal("stone"));
                npc.Physiological.Mineral = reader1.GetInt32(reader1.GetOrdinal("mineral"));
                npc.Physiological.Crops = reader1.GetInt32(reader1.GetOrdinal("crops"));
                npc.Physiological.Fish = reader1.GetInt32(reader1.GetOrdinal("fish"));
                npc.Physiological.Food = reader1.GetInt32(reader1.GetOrdinal("food"));
                npc.Physiological.Lunchbox = reader1.GetInt32(reader1.GetOrdinal("lunchbox"));
            }
        }

        // 讀取 LTM
        command.CommandText = """
        SELECT *
        FROM LTM
        WHERE npc_id = $npc_id;
        """;

        using (var reader2 = command.ExecuteReader())
        {
            if (reader2.Read())
            {
                npc.Entry.MedicineJar = reader2.GetBoolean(reader2.GetOrdinal("medicine_jar"));
                npc.Entry.Healthy = reader2.GetBoolean(reader2.GetOrdinal("healthy"));
                npc.Entry.Greedy = reader2.GetBoolean(reader2.GetOrdinal("greedy"));
                npc.Entry.EatLikeABird = reader2.GetBoolean(reader2.GetOrdinal("eat_like_a_bird"));
                npc.Entry.SocialPerson = reader2.GetBoolean(reader2.GetOrdinal("social_person"));
                npc.Entry.Asocial = reader2.GetBoolean(reader2.GetOrdinal("asocial"));
                npc.Entry.Optimistic = reader2.GetBoolean(reader2.GetOrdinal("optimistic"));
                npc.Entry.Pessimistic = reader2.GetBoolean(reader2.GetOrdinal("pessimistic"));
                npc.Entry.Debility = reader2.GetBoolean(reader2.GetOrdinal("debility"));
                npc.Entry.Strong = reader2.GetBoolean(reader2.GetOrdinal("strong"));
                npc.Entry.BigE = reader2.GetBoolean(reader2.GetOrdinal("big_e"));
                npc.Entry.BigI = reader2.GetBoolean(reader2.GetOrdinal("big_i"));

                npc.NormalOffset.WanderOffset = reader2.GetDouble(reader2.GetOrdinal("wander"));
                npc.NormalOffset.ReadOffset = reader2.GetDouble(reader2.GetOrdinal("read"));
                npc.NormalOffset.ShoppingOffset = reader2.GetDouble(reader2.GetOrdinal("shopping"));
                npc.NormalOffset.EatOffset = reader2.GetDouble(reader2.GetOrdinal("eat"));
                npc.NormalOffset.GoToADoctorOffset = reader2.GetDouble(reader2.GetOrdinal("go_to_a_doctor"));
                npc.NormalOffset.GoHomeOffset = reader2.GetDouble(reader2.GetOrdinal("go_home"));
                npc.NormalOffset.SocialContactOffset = reader2.GetDouble(reader2.GetOrdinal("social_contact"));
                npc.NormalOffset.CheckTheFieldOffset = reader2.GetDouble(reader2.GetOrdinal("check_the_field"));
                npc.NormalOffset.SellingOffset = reader2.GetDouble(reader2.GetOrdinal("selling"));

                npc.JobId = reader2.GetInt32(reader2.GetOrdinal("jobID"));
                npc.Home = reader2.GetInt32(reader2.GetOrdinal("home"));
            }
        }
    }

    //============================================================
    //4. NPC完成動作後計算數值增減及儲存記憶的函式
    //============================================================

    // 分支4-1. 計算一般行動後的數值增減及儲存記憶
    public static void SaveMemory(int id, int time, PhysiologicalStats physiological, ActionValue actionValue, ChangedStateValue changedStateValue)
    {
        // 計算本次行動造成的數值變化
        attributeCalculator.ComputeNormalAttributes(time, physiological, actionValue, changedStateValue);

        // 計算本次行動的 Reward
        double rewardValue = attributeCalculator.ComputeRewardValue(changedStateValue);

        // 儲存到 STM
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.CommandText = """
        INSERT INTO STM
        (
            npc_id,
            time,
            action,
            location,
            change_hp,
            change_health,
            change_stamina,
            change_hunger,
            change_socialDesire,
            change_mood,
            change_money,
            change_wood,
            change_stone,
            change_mineral,
            change_crops,
            change_fish,
            change_food,
            change_lunchbox,
            reward_value
        )
        VALUES
        (
            $npc_id,
            $time,
            $action,
            $location,
            $change_hp,
            $change_health,
            $change_stamina,
            $change_hunger,
            $change_socialDesire,
            $change_mood,
            $change_money,
            $change_wood,
            $change_stone,
            $change_mineral,
            $change_crops,
            $change_fish,
            $change_food,
            $change_lunchbox,
            $reward_value
        );
        """;

        command.Parameters.AddWithValue("$npc_id", id);
        command.Parameters.AddWithValue("$time", time);
        command.Parameters.AddWithValue("$action", actionValue.ActionState);
        command.Parameters.AddWithValue("$location", actionValue.Destination);

        command.Parameters.AddWithValue("$change_hp", changedStateValue.ChangeHp);
        command.Parameters.AddWithValue("$change_health", changedStateValue.ChangeHealth);
        command.Parameters.AddWithValue("$change_stamina", changedStateValue.ChangeStamina);
        command.Parameters.AddWithValue("$change_hunger", changedStateValue.ChangeHunger);
        command.Parameters.AddWithValue("$change_socialDesire", changedStateValue.ChangeSocialDesire);
        command.Parameters.AddWithValue("$change_mood", changedStateValue.ChangeMood);

        command.Parameters.AddWithValue("$change_money", changedStateValue.ChangeMoney);
        command.Parameters.AddWithValue("$change_wood", changedStateValue.ChangeWood);
        command.Parameters.AddWithValue("$change_stone", changedStateValue.ChangeStone);
        command.Parameters.AddWithValue("$change_mineral", changedStateValue.ChangeMineral);
        command.Parameters.AddWithValue("$change_crops", changedStateValue.ChangeCrops);
        command.Parameters.AddWithValue("$change_fish", changedStateValue.ChangeFish);
        command.Parameters.AddWithValue("$change_food", changedStateValue.ChangeFood);
        command.Parameters.AddWithValue("$change_lunchbox", changedStateValue.ChangeLunchbox);
        command.Parameters.AddWithValue("$reward_value", rewardValue);

        command.ExecuteNonQuery();
    }

    //分支4-2. 計算社交行動後的數值增減及儲存記憶
    public static void SaveMemory(NPCclass sourceNPC, NPCclass targetNPC)
    {
        // 計算社交行動造成的數值變化
        attributeCalculator.ComputeSocialAttributes(sourceNPC, targetNPC);

        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var transaction = connection.BeginTransaction();

        try
        {
            // 建立 SQL Command
            using var command = connection.CreateCommand();

            command.Transaction = transaction;

            command.CommandText = """
            INSERT INTO STSM
            (
                time,
                npc_id,
                target_npc_id,
                event_type,
                change_trust,
                change_friendship,
                change_mood,
                content
            )
            VALUES
            (
                $time,
                $npc_id,
                $target_npc_id,
                $event_type,
                $change_trust,
                $change_friendship,
                $change_mood,
                $content
            );
            """;

            // 儲存 Source NPC 的記憶
            command.Parameters.AddWithValue("$time", sourceNPC.Time);
            command.Parameters.AddWithValue("$npc_id", sourceNPC.Id);
            command.Parameters.AddWithValue("$target_npc_id", targetNPC.Id);
            command.Parameters.AddWithValue("$event_type", sourceNPC.Action.SocialAction);
            command.Parameters.AddWithValue("$change_trust", sourceNPC.ChangedStateValue.ChangeTrust);
            command.Parameters.AddWithValue("$change_friendship", sourceNPC.ChangedStateValue.ChangeFavorability);
            command.Parameters.AddWithValue("$change_mood", sourceNPC.ChangedStateValue.ChangeMood);
            command.Parameters.AddWithValue("$content", DBNull.Value);

            command.ExecuteNonQuery();

            // 儲存 Target NPC 的記憶
            command.Parameters["$npc_id"].Value = targetNPC.Id;
            command.Parameters["$target_npc_id"].Value = sourceNPC.Id;
            //command.Parameters["$event_type"].Value = sourceNPC.SocialAction;
            command.Parameters["$change_trust"].Value = targetNPC.ChangedStateValue.ChangeTrust;
            command.Parameters["$change_friendship"].Value = targetNPC.ChangedStateValue.ChangeFavorability;
            command.Parameters["$change_mood"].Value = targetNPC.ChangedStateValue.ChangeMood;

            command.ExecuteNonQuery();

            // 兩筆都成功後提交
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    // ============================================================
    // 5. 每日結算需要呼叫的函式
    // ============================================================

    // 前半 (記憶結算)
    public static void DailySettlement1()
    {
        SettleSTM();
        SettleMTSM();
        SettleSTSM();
    }

    // 5-1. 結算STM，變更LTM內各項行動的權重，清空STM
    public static void SettleSTM()
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var transaction = connection.BeginTransaction();

        try
        {
            // 1. 取得 STM 中每個 NPC、每個 Action 的當日總 Reward
            using var selectCommand = connection.CreateCommand();
            selectCommand.Transaction = transaction;

            selectCommand.CommandText = """
            SELECT
                npc_id,
                action,
                SUM(reward_value) AS total_reward
            FROM STM
            GROUP BY npc_id, action
            ORDER BY npc_id, action;
            """;

            using (var reader = selectCommand.ExecuteReader())
            {
                while (reader.Read())
                {
                    int npcId = reader.GetInt32(reader.GetOrdinal("npc_id"));

                    int action = reader.GetInt32(reader.GetOrdinal("action"));

                    double todayReward = reader.GetDouble(reader.GetOrdinal("total_reward"));

                    // 2. 取得這個 NPC 目前的 Action Offset
                    double oldWeight = GetActionWeight(connection, transaction, npcId, action);

                    // 3. 使用 Reward 計算新的 Weight
                    double newWeight = attributeCalculator.ComputeWeight(todayReward, oldWeight);

                    // 4. 更新 LTM
                    UpdateActionWeight(connection,transaction,npcId,action,newWeight);
                }
            }

            // 5. 所有 NPC 的權重都更新完後，清空 STM
            using var deleteCommand = connection.CreateCommand();

            deleteCommand.Transaction = transaction;

            deleteCommand.CommandText = """DELETE FROM STM;""";

            deleteCommand.ExecuteNonQuery();

            // 6. 全部成功後提交
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    // 5-1.1取得舊的行動權重
    private static double GetActionWeight(SqliteConnection connection, SqliteTransaction transaction, int npcId, int action)
    {
        string columnName = action switch
        {
            0 => "wander",
            1 => "read",
            2 => "shopping",
            3 => "eat",
            4 => "go_to_a_doctor",
            5 => "go_home",
            6 => "social_contact",
            7 => "check_the_field",
            8 => "selling",

            _ => throw new ArgumentException($"未知的 Action: {action}")
        };

        using var command = connection.CreateCommand();

        command.Transaction = transaction;

        command.CommandText = $"""
        SELECT {columnName}
        FROM LTM
        WHERE npc_id = $npc_id;
        """;

        command.Parameters.AddWithValue("$npc_id", npcId);

        object? result = command.ExecuteScalar();

        if (result == null || result == DBNull.Value)
        {
            throw new Exception($"找不到 NPC {npcId} 的 LTM 資料。");
        }

        return Convert.ToDouble(result);
    }

    // 5-1.2更新新的行動權重(LTM)
    private static void UpdateActionWeight(SqliteConnection connection, SqliteTransaction transaction, int npcId, int action, double newWeight)
    {
        if (action == 6) 
        {
            return;
        }
        string columnName = action switch
        {
            0 => "wander",
            1 => "read",
            2 => "shopping",
            3 => "eat",
            4 => "go_to_a_doctor",
            5 => "go_home",
            6 => "social_contact",
            7 => "check_the_field",
            8 => "selling",

            _ => throw new ArgumentException($"未知的 Action: {action}")
        };

        using var command = connection.CreateCommand();

        command.Transaction = transaction;

        command.CommandText = $"""
        UPDATE LTM
        SET {columnName} = $weight
        WHERE npc_id = $npc_id;
        """;

        command.Parameters.AddWithValue("$weight", newWeight);
        command.Parameters.AddWithValue("$npc_id", npcId);

        command.ExecuteNonQuery();
    }

    // 5-2. 結算MTSM
    public static void SettleMTSM()
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var transaction = connection.BeginTransaction();

        try
        {
            // 1. 所有記憶importance - 1
            using (var updateCommand = connection.CreateCommand())
            {
                updateCommand.Transaction = transaction;

                updateCommand.CommandText = """
                UPDATE MTSM
                SET importance = importance - 1
                """;

                updateCommand.ExecuteNonQuery();
            }

            // 2. Importance <= 0 的記憶刪除，有 content 的記憶不刪除
            using (var deleteCommand = connection.CreateCommand())
            {
                deleteCommand.Transaction = transaction;

                deleteCommand.CommandText = """
                DELETE FROM MTSM
                WHERE importance <= 0
                  AND (content IS NULL OR content = '');
                """;

                deleteCommand.ExecuteNonQuery();
            }

            // 3. 完成
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    // 5-3. 結算STSM
    public static void SettleSTSM()
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var transaction = connection.BeginTransaction();

        try
        {
            // 1. 將 STSM 所有資料讀入記憶體
            List<STSMRecord> records = new();

            using (var selectCommand = connection.CreateCommand())
            {
                selectCommand.Transaction = transaction;

                selectCommand.CommandText = """
                SELECT
                    npc_id,
                    target_npc_id,
                    event_type,
                    change_trust,
                    change_friendship,
                    change_mood,
                    content
                FROM STSM;
                """;

                using var reader = selectCommand.ExecuteReader();

                while (reader.Read())
                {
                    records.Add(new STSMRecord
                    {
                        NpcId = reader.GetInt32(reader.GetOrdinal("npc_id")),
                        TargetNpcId = reader.GetInt32(reader.GetOrdinal("target_npc_id")),
                        EventType = reader.GetInt32(reader.GetOrdinal("event_type")),
                        ChangeTrust = reader.GetInt32(reader.GetOrdinal("change_trust")),
                        ChangeFriendship = reader.GetInt32(reader.GetOrdinal("change_friendship")),
                        ChangeMood = reader.GetInt32(reader.GetOrdinal("change_mood")),
                        Content = reader.IsDBNull(reader.GetOrdinal("content"))? null: reader.GetString(reader.GetOrdinal("content"))
                    });
                }
            }

            // 2. 將 STSM 逐筆轉移到 MTSM
            foreach (var record in records)
            {
                int isPositive = attributeCalculator.DetermineSTSMType(
                    record.ChangeTrust,
                    record.ChangeFriendship,
                    record.ChangeMood,
                    record.EventType);

                using var insertCommand = connection.CreateCommand();

                insertCommand.Transaction = transaction;

                insertCommand.CommandText = """
                INSERT INTO MTSM
                (
                    npc_id,
                    target_npc_id,
                    is_Positive,
                    content,
                    importance
                )
                VALUES
                (
                    $npc_id,
                    $target_npc_id,
                    $is_positive,
                    $content,
                    $importance
                );
                """;

                insertCommand.Parameters.AddWithValue("$npc_id",record.NpcId);
                insertCommand.Parameters.AddWithValue("$target_npc_id",record.TargetNpcId);
                insertCommand.Parameters.AddWithValue("$is_positive",isPositive);
                insertCommand.Parameters.AddWithValue("$content",record.Content ?? (object)DBNull.Value);
                insertCommand.Parameters.AddWithValue("$importance",10);

                insertCommand.ExecuteNonQuery();
            }

            // 3. 所有 STSM 都成功轉移後，清空 STSM
            using (var deleteCommand = connection.CreateCommand())
            {
                deleteCommand.Transaction = transaction;

                deleteCommand.CommandText = """DELETE FROM STSM;""";

                deleteCommand.ExecuteNonQuery();
            }

            // 4. 全部完成後提交

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    // 後半(存檔及載入新數值到NPC class內，遊戲端利用20個NPC class的物件逐一呼叫)
    public static void DailySettlement2(NPCclass npc) 
    {
        SaveState(npc.Id, npc.Physiological, npc.Social);
        LoadHistoryEvent(npc.Id, npc.Social.HistoryEventToOther);
        LoadActionWeights(npc.Id, npc.NormalOffset);
    }

    // 5-4. 將NPC當下生理數值及對彼此的信任度、好感度存放至MTM及LTSM
    public static void SaveState(int id, PhysiologicalStats Physiological, SocialStats Social)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var transaction = connection.BeginTransaction();

        try
        {
            // 1. 更新 MTM
            using (var command = connection.CreateCommand())
            {
                command.Transaction = transaction;

                command.CommandText = """
                UPDATE MTM
                SET
                    hp = $hp,
                    health = $health,
                    stamina = $stamina,
                    hunger = $hunger,
                    socialDesire = $socialDesire,
                    mood = $mood,
                    money = $money,
                    wood = $wood,
                    stone = $stone,
                    mineral = $mineral,
                    crops = $crops,
                    fish = $fish,
                    food = $food,
                    lunchbox = $lunchbox
                WHERE npc_id = $npc_id;
                """;

                command.Parameters.AddWithValue("$npc_id", id);
                command.Parameters.AddWithValue("$hp", Physiological.Hp);
                command.Parameters.AddWithValue("$health", Physiological.Health);
                command.Parameters.AddWithValue("$stamina", Physiological.Stamina);
                command.Parameters.AddWithValue("$hunger", Physiological.Hunger);
                command.Parameters.AddWithValue("$socialDesire", Physiological.SocialDesire);
                command.Parameters.AddWithValue("$mood", Physiological.Mood);
                command.Parameters.AddWithValue("$money", Physiological.Money);
                command.Parameters.AddWithValue("$wood", Physiological.Wood);
                command.Parameters.AddWithValue("$stone", Physiological.Stone);
                command.Parameters.AddWithValue("$mineral", Physiological.Mineral);
                command.Parameters.AddWithValue("$crops", Physiological.Crops);
                command.Parameters.AddWithValue("$fish", Physiological.Fish);
                command.Parameters.AddWithValue("$food", Physiological.Food);
                command.Parameters.AddWithValue("$lunchbox", Physiological.Lunchbox);

                command.ExecuteNonQuery();
            }

            // 2. 更新 LTSM
            using (var command = connection.CreateCommand())
            {
                command.Transaction = transaction;

                string sql = "UPDATE LTSM SET ";

                // impact_trust_1 ~ impact_trust_20
                for (int n = 1; n <= 20; n++)
                {
                    if (n > 1)
                    {
                        sql += ", ";
                    }

                    sql += $"impact_trust_{n} = $trust_{n}";
                }

                // impact_friendship_1 ~ impact_friendship_20
                for (int n = 1; n <= 20; n++)
                {
                    sql += $", impact_friendship_{n} = $friendship_{n}";
                }
                sql += " WHERE npc_id = $npc_id;";

                command.CommandText = sql;

                // NPC ID
                command.Parameters.AddWithValue("$npc_id", id);

                // Trust、Favorability
                for (int n = 1; n <= 20; n++)
                {
                    command.Parameters.AddWithValue($"$trust_{n}", Social.Trust[n - 1]);
                    command.Parameters.AddWithValue($"$friendship_{n}", Social.Favorability[n - 1]);
                }

                command.ExecuteNonQuery();
            }

            // 兩個都成功後提交
            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    // 5-5. 將NPC與其他NPC的10 天內歷史事件好壞比例讀入NPC class內
    public static void LoadHistoryEvent(int id, double[] HistoryEventToOthers)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        string sql = """
        SELECT target_npc_id, is_Positive
        FROM MTSM
        WHERE npc_id = $npc_id AND importance > 0;
        """;

        int[] positiveCount = new int[20];
        int[] negativeCount = new int[20];

        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.Parameters.AddWithValue("$npc_id", id);

        using var reader = command.ExecuteReader();

        while (reader.Read())
        {
            int targetNpcId = reader.GetInt32(0);
            int isPositive = reader.GetInt32(1);

            // NPC ID 是 1~20，陣列索引是 0~19
            int index = targetNpcId - 1;

            if (index < 0 || index >= HistoryEventToOthers.Length)
                continue;

            if (isPositive == 1)
            {
                positiveCount[index]++;
            }
            else if (isPositive == -1)
            {
                negativeCount[index]++;
            }
        }

        // 計算每個 NPC 的歷史事件好壞比例
        for (int i = 0; i < HistoryEventToOthers.Length; i++)
        {
            int total = positiveCount[i] + negativeCount[i];

            if (total == 0)
            {
                // 沒有正向或負向事件，視為中性
                HistoryEventToOthers[i] = 0.5;
            }
            else
            {
                HistoryEventToOthers[i] = (double)positiveCount[i] / total;
            }
        }
    }

    // 5-6. 將新的一般行動權重從LTM讀入NPC class內
    public static void LoadActionWeights(int id, NormalOffset normalOffset)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.CommandText = """
        SELECT
            wander,
            read,
            shopping,
            eat,
            go_to_a_doctor,
            go_home,
            social_contact,
            check_the_field,
            selling
        FROM LTM
        WHERE npc_id = $npc_id;
        """;

        command.Parameters.AddWithValue("$npc_id", id);

        using var reader = command.ExecuteReader();

        if (reader.Read())
        {
            normalOffset.WanderOffset = reader.GetDouble(0);
            normalOffset.ReadOffset = reader.GetDouble(1);
            normalOffset.ShoppingOffset = reader.GetDouble(2);
            normalOffset.EatOffset = reader.GetDouble(3);
            normalOffset.GoToADoctorOffset = reader.GetDouble(4);
            normalOffset.GoHomeOffset = reader.GetDouble(5);
            normalOffset.SocialContactOffset = reader.GetDouble(6);
            normalOffset.CheckTheFieldOffset = reader.GetDouble(7);
            normalOffset.SellingOffset = reader.GetDouble(8);
        }
    }

    // ============================================================
    // 6. NPC得到待傳遞訊息後(不是從別人那裏得到的)，將取得的訊息存入MTSM
    // ============================================================
    public static void StoreMessage(int id, string content)
    {
        using (var connection = new SqliteConnection(ConnectionString))
        {
            connection.Open();

            string sql = @"
            INSERT INTO MTSM
            (
                npc_id,
                target_npc_id,
                is_Positive,
                content,
                importance
            )
            VALUES
            (
                $npc_id,
                $target_npc_id,
                $is_positive,
                $content,
                $importance
            );
        ";

            using (var command = new SqliteCommand(sql, connection))
            {
                command.Parameters.AddWithValue("$npc_id", id);
                command.Parameters.AddWithValue("$target_npc_id", id);
                command.Parameters.AddWithValue("$is_positive", false);
                command.Parameters.AddWithValue("$content", content);
                command.Parameters.AddWithValue("$importance", 10);

                command.ExecuteNonQuery();
            }
        }
    }

    // ============================================================
    // 7. 社交決策時取得距離上次互動過了幾天的函式
    // ============================================================
    public static int getDaysSinceInterAction(int source, int target)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.CommandText = """
        SELECT MAX(importance)
        FROM MTSM
        WHERE
            (
                (npc_id = $source AND target_npc_id = $target)
                OR
                (npc_id = $target AND target_npc_id = $source)
            )
            AND importance BETWEEN 1 AND 10;
        """;

        command.Parameters.AddWithValue("$source", source);
        command.Parameters.AddWithValue("$target", target);

        object? result = command.ExecuteScalar();

        // 找不到雙方的互動記憶
        if (result == null || result == DBNull.Value)
        {
            return 10;
        }

        int importance = Convert.ToInt32(result);

        // importance 10 = 1 天前
        // importance 9  = 2 天前
        // importance 8  = 3 天前
        return 11 - importance;
    }

    // ============================================================
    // 8. 社交決策時取得待傳遞訊息string list的函式
    // ============================================================
    public static List<string> getSpreadMessage(int id)
    {
        List<string> messages = new List<string>();

        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.CommandText = """
        SELECT content
        FROM MTSM
        WHERE npc_id = $id
          AND content IS NOT NULL
          AND TRIM(content) <> '';
        """;

        command.Parameters.AddWithValue("$id", id);

        using var reader = command.ExecuteReader();

        while (reader.Read())
        {
            messages.Add(reader.GetString(0));
        }

        return messages;
    }

    // ============================================================
    // 9. 社交決策時確定對方是否知道此訊息的函式
    // ============================================================
    public static bool checkMessageIsKnown(string message, int id)
    {
        using var connection = new SqliteConnection(ConnectionString);
        connection.Open();

        using var command = connection.CreateCommand();

        command.CommandText = """
        SELECT EXISTS
        (
            SELECT 1
            FROM MTSM
            WHERE npc_id = $id
              AND content = $message
        );
        """;

        command.Parameters.AddWithValue("$id", id);
        command.Parameters.AddWithValue("$message", message);

        return Convert.ToInt32(command.ExecuteScalar()) == 1;
    }

    // ============================================================
    // 10. 從LTSM載入NPC之間的信任度及好感度到NPC_class的函式
    // ============================================================
    public static void LoadLTSM(int id, SocialStats social)
    {
        using (var connection = new SqliteConnection(ConnectionString))
        {
            connection.Open();

            string sql = @"
            SELECT *
            FROM LTSM
            WHERE npc_id = $id;
        ";

            using (var command = new SqliteCommand(sql, connection))
            {
                command.Parameters.AddWithValue("$id", id);

                using (var reader = command.ExecuteReader())
                {
                    if (!reader.Read())
                    {
                        throw new InvalidOperationException(
                            $"LTSM 中找不到 NPC ID = {id} 的資料。");
                    }

                    // Trust：欄位索引 1～20
                    for (int i = 0; i < 20; i++)
                    {
                        social.Trust[i] = reader.GetInt32(i + 1);
                    }

                    // Favorability：欄位索引 21～40
                    for (int i = 0; i < 20; i++)
                    {
                        social.Favorability[i] = reader.GetInt32(i + 21);
                    }
                }
            }
        }
    }

    // ============================================================
    // 11. 將詞條設定存入LTM的函式
    // ============================================================
    public static void StoreEntry(int id, Entry entry)
    {
        using (var connection = new SqliteConnection(ConnectionString))
        {
            connection.Open();

            string sql = @"
            INSERT INTO LTM
            (
                npc_id,
                medicine_jar,
                healthy,
                greedy,
                eat_like_a_bird,
                social_person,
                asocial,
                optimistic,
                pessimistic,
                debility,
                strong,
                big_e,
                big_i,
                wander,
                read,
                shopping,
                eat,
                go_to_a_doctor,
                go_home,
                social_contact,
                check_the_field,
                selling,
                jobID,
                home
            )
            VALUES
            (
                $id,
                $medicine_jar,
                $healthy,
                $greedy,
                $eat_like_a_bird,
                $social_person,
                $asocial,
                $optimistic,
                $pessimistic,
                $debility,
                $strong,
                $big_e,
                $big_i,
                1.0, 1.0, 1.0, 1.0, 1.0,
                1.0, 1.0, 1.0, 1.0,
                0, 0
            )
            ON CONFLICT(npc_id) DO UPDATE SET
                medicine_jar = excluded.medicine_jar,
                healthy = excluded.healthy,
                greedy = excluded.greedy,
                eat_like_a_bird = excluded.eat_like_a_bird,
                social_person = excluded.social_person,
                asocial = excluded.asocial,
                optimistic = excluded.optimistic,
                pessimistic = excluded.pessimistic,
                debility = excluded.debility,
                strong = excluded.strong,
                big_e = excluded.big_e,
                big_i = excluded.big_i;
        ";

            using (var command = new SqliteCommand(sql, connection))
            {
                command.Parameters.AddWithValue("$id", id);

                command.Parameters.AddWithValue("$medicine_jar", entry.MedicineJar);
                command.Parameters.AddWithValue("$healthy", entry.Healthy);
                command.Parameters.AddWithValue("$greedy", entry.Greedy);
                command.Parameters.AddWithValue("$eat_like_a_bird", entry.EatLikeABird);
                command.Parameters.AddWithValue("$social_person", entry.SocialPerson);
                command.Parameters.AddWithValue("$asocial", entry.Asocial);
                command.Parameters.AddWithValue("$optimistic", entry.Optimistic);
                command.Parameters.AddWithValue("$pessimistic", entry.Pessimistic);
                command.Parameters.AddWithValue("$debility", entry.Debility);
                command.Parameters.AddWithValue("$strong", entry.Strong);
                command.Parameters.AddWithValue("$big_e", entry.BigE);
                command.Parameters.AddWithValue("$big_i", entry.BigI);

                command.ExecuteNonQuery();
            }
        }
    }
}
