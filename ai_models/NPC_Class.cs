using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace npc_class
{
    public class NPCclass
    {
        public NPCclass(int id)   // 建構子及初始數值
        {
            Time = 0;
            Id = id;
            JobId = 0;
            Home = 0;
            Info = "";
        }

        // 當前時間
        public int Time { get; set; } // 當前時間

        // npcID、職業編號、家的編號
        public int Id { get; set; } // NPC id
        public int JobId { get; set; } // NPC 職業編號
        public int Home { get; set; } // NPC 家的編號

        // 取得的要傳播給別人的訊息
        public string Info { get; set; }    

        // NPC生理數值
        public PhysiologicalStats Physiological { get; set; } = new PhysiologicalStats();

        // NPC對其他人的信任度、好感度、距離、事件好壞比例
        public SocialStats Social { get; set; } = new SocialStats();

        // NPC詞條
        public Entry Entry { get; set; } = new Entry();

        // 一般決策輸出偏移量(後端用)
        public NormalOffset NormalOffset { get; set; } = new NormalOffset();

        // NPC當前行動狀態參數及提供後端運算用的數值
        public ActionValue Action { get; set; } = new ActionValue();

        // 該次行動改變的數值
        public ChangedStateValue ChangedStateValue { get; set; } = new ChangedStateValue();
    }

    public class PhysiologicalStats
    {
        public PhysiologicalStats()  // 建構子及初始數值
        {
            Hp = 100;
            Health = 100;
            Stamina = 100;
            Hunger = 100;
            SocialDesire = 100;
            Mood = 100;
            Money = 100;
            Wood = 0;
            Stone = 0;
            Mineral = 0;
            Crops = 0;
            Fish = 0;
            Food = 0;
            Lunchbox = 0;
        }

        public int Hp { get; set; } // NPC 生命值
        public int Health { get; set; } // NPC 健康度
        public int Stamina { get; set; } // NPC 體力
        public int Hunger { get; set; } // NPC 飽食度
        public int SocialDesire { get; set; } // NPC 社交慾望
        public int Mood { get; set; } // NPC 心情
        public int Money { get; set; } // NPC 持有金錢
        public int Wood { get; set; } // NPC 持有木頭
        public int Stone { get; set; }  // NPC 持有石頭
        public int Mineral { get; set; } // NPC 持有礦物
        public int Crops { get; set; } // NPC 持有農作物
        public int Fish { get; set; } // NPC 持有魚
        public int Food { get; set; } // NPC 持有料理
        public int Lunchbox { get; set; } // NPC 持有便當

    }

    public class SocialStats
    { 
        public SocialStats()  // 建構子及初始數值
        {
            for (int i = 0; i < Trust.Length; i++)
            {
                Trust[i] = 50;
                Favorability[i] = 50;
                DistanceToOtherNPCs[i] = 10000.0;
                HistoryEventToOther[i] = 0.5;
            }
        }

        public int[] Trust { get; set; } = new int[20]; // NPC 對其他人的信任度
        public int[] Favorability { get; set; } = new int[20]; // NPC 對其他人的好感度
        public double[] DistanceToOtherNPCs { get; set; } = new double[20]; // NPC 與其他NPC的距離
        public double[] HistoryEventToOther { get; set; } = new double[20]; // NPC 與其他NPC的10天內歷史事件好壞比例
    }

    public class Entry
    {
        public Entry()  // 建構子及初始數值
        {
            MedicineJar = false;
            Healthy = false;
            Greedy = false;
            EatLikeABird = false;
            SocialPerson = false;
            Asocial = false;
            Optimistic = false;
            Pessimistic = false;
            Debility = false;
            Strong = false;
            BigE = false;
            BigI = false;
        }

        public bool MedicineJar { get; set; }   // 藥罐子：決策時健康度 -10（更容易去醫院）
        public bool Healthy { get; set; }       // 身體健康：決策時健康度 +10
        public bool Greedy { get; set; }        // 貪吃：決策時飽食度 -10
        public bool EatLikeABird { get; set; }  // 節食大師：決策時飽食度 +10
        public bool SocialPerson { get; set; }  // 喜歡社交：決策時社交慾望 -10
        public bool Asocial { get; set; }       // 厭人：決策時社交慾望 +10
        public bool Optimistic { get; set; }    // 樂天：決策時心情 +10
        public bool Pessimistic { get; set; }   // 悲觀：決策時心情 -10
        public bool Debility { get; set; }  // 體虛：體力的固定消耗值 1.5 倍
        public bool Strong { get; set; }    // 身強體壯：體力的固定消耗值 0.8 倍
        public bool BigE { get; set; }      // 大E人：社交需求的固定消耗值 1.5 倍
        public bool BigI { get; set; }      // 大I人：社交需求的固定消耗值 0.8 倍
    }

    public class NormalOffset
    { 
        public NormalOffset()  // 建構子及初始數值
        {
            WanderOffset = 1.0f;
            ReadOffset = 1.0f;
            ShoppingOffset = 1.0f;
            EatOffset = 1.0f;
            GoToADoctorOffset = 1.0f;
            GoHomeOffset = 1.0f;
            SocialContactOffset = 1.0f;
            CheckTheFieldOffset = 1.0f;
            SellingOffset = 1.0f;
        }

        public double WanderOffset { get; set; }    // 閒逛偏移量
        public double ReadOffset { get; set; }      // 閱讀偏移量
        public double ShoppingOffset { get; set; }  // 購物偏移量
        public double EatOffset { get; set; }       // 吃東西偏移量
        public double GoToADoctorOffset { get; set; }   // 就醫偏移量
        public double GoHomeOffset { get; set; }    // 回家偏移量
        public double SocialContactOffset { get; set; }   // 社交偏移量
        public double CheckTheFieldOffset { get; set; }   // 巡田水偏移量
        public double SellingOffset { get; set; }   // 販售物品偏移量
    }

    public class ActionValue
    {
        public ActionValue()  // 建構子及初始數值
        {
            ActionState = 0;
            Destination = -1;
            SocialTarget = -1;
            SocialAction = -1;
            IsLastActionSuccess = true;
        }

        public int ActionState { get; set; }    // 正在進行/正要去做的行動
        public int Destination { get; set; }    // 正在進行/正要去做的一般行動的目的地

        public int SocialTarget { get; set; }    // 正在進行/正要去做的社交行動的對象
        public int SocialAction { get; set; }    // 正在進行/正要去做的社交行動

        public bool IsLastActionSuccess { get; set; }    // 決策後，行動是否成功
    }

    public class ChangedStateValue
    {
        public ChangedStateValue()  // 建構子及初始數值
        {
            ChangeHp = 0;
            ChangeHealth = 0;
            ChangeStamina = 0;
            ChangeHunger = 0;
            ChangeSocialDesire = 0;
            ChangeMood = 0;
            ChangeMoney = 0;
            ChangeWood = 0;
            ChangeStone = 0;
            ChangeMineral = 0;
            ChangeCrops = 0;
            ChangeFish = 0;
            ChangeFood = 0;
            ChangeLunchbox = 0;

            ChangeTrust = 0;
            ChangeFavorability = 0;
        }

        public int ChangeHp { get; set; } // NPC 生命值改變量
        public int ChangeHealth { get; set; } // NPC 健康度改變量
        public int ChangeStamina { get; set; } // NPC 體力改變量
        public int ChangeHunger { get; set; } // NPC 飽食度改變量
        public int ChangeSocialDesire { get; set; } // NPC 社交慾望改變量
        public int ChangeMood { get; set; } // NPC 心情改變量
        public int ChangeMoney { get; set; } // NPC 持有金錢改變量
        public int ChangeWood { get; set; } // NPC 持有木頭改變量
        public int ChangeStone { get; set; }  // NPC 持有石頭改變量
        public int ChangeMineral { get; set; } // NPC 持有礦物改變量
        public int ChangeCrops { get; set; } // NPC 持有農作物改變量
        public int ChangeFish { get; set; } // NPC 持有魚改變量
        public int ChangeFood { get; set; } // NPC 持有料理改變量
        public int ChangeLunchbox { get; set; } // NPC 持有便當改變量
        public int ChangeTrust { get; set; } // NPC 對其他人的信任度改變量，依附上面的社交行動對象來當參考
        public int ChangeFavorability { get; set; } // NPC 對其他人的好感度改變量，依附上面的社交行動對象來當參考
    }


    // ==========================
    // 每日結算時用於結算STSM用的暫存class
    public class STSMRecord
    {
        public int NpcId { get; set; }
        public int TargetNpcId { get; set; }
        public int EventType { get; set; }
        public int ChangeTrust { get; set; }
        public int ChangeFriendship { get; set; }
        public int ChangeMood { get; set; }
        public string? Content { get; set; }
    }

}
