using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.NetworkInformation;
using System.Text;
using System.Threading.Tasks;
using npc_class;

namespace computeAttribute
{
    public static class attributeCalculator
    {
        // 計算一般行動的數值改變量
        public static void ComputeNormalAttributes(int time, PhysiologicalStats physiological, ActionValue actionValue, ChangedStateValue changedStateValue) 
        { 
            // 重置changedStateValue內的值
            ResetChangedStateValue(changedStateValue);

            /*
            - 0. 閒逛
            - 1. 閱讀
            - 2. 購物
            - 3. 吃東西
            - 4. 就醫
            - 5. 回家
            - 6. 社交
            - 7. 巡田水
            - 8. 販售物品
             */

            if (actionValue.IsLastActionSuccess)
            {
                switch (actionValue.ActionState)
                {
                    case 0:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 閒逛成功會稍微增加心情
                        break;
                    case 1:
                        changedStateValue.ChangeMood += Random.Shared.Next(8, 16); // 閱讀適度增加心情，平抑回報斷層
                        break;
                    case 2:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5);
                        int availableMoney = physiological.Money;   // 計算購物時可用的金錢

                        // 料理不足時，嘗試購買料理
                        if (physiological.Food <= 2)
                        {
                            int desiredFood = Random.Shared.Next(2, 5);
                            int affordableFood = availableMoney / 5;
                            int buyFood = Math.Min(desiredFood, affordableFood);

                            changedStateValue.ChangeFood += buyFood;
                            changedStateValue.ChangeMoney -= buyFood * 5;

                            availableMoney -= buyFood * 5;
                        }

                        // 便當不足時，使用剩餘金錢購買便當（單價 8）
                        if (physiological.Lunchbox <= 2)
                        {
                            int desiredLunchbox = Random.Shared.Next(2, 5);
                            int affordableLunchbox = availableMoney / 8;
                            int buyLunchbox = Math.Min(desiredLunchbox, affordableLunchbox);

                            changedStateValue.ChangeLunchbox += buyLunchbox;
                            changedStateValue.ChangeMoney -= buyLunchbox * 8;

                            availableMoney -= buyLunchbox * 8;
                        }

                        break;
                    case 3:
                        if (actionValue.Destination == 0)   // 原地吃
                        {
                            if (physiological.Food > 0)
                            {
                                changedStateValue.ChangeFood -= 1; // 吃掉一個食物
                                changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 吃食物會增加心情
                                changedStateValue.ChangeHunger += Random.Shared.Next(40, 60); // 吃食物會增加飢餓值
                                changedStateValue.ChangeStamina += Random.Shared.Next(25, 36); // 食用食物大幅回補體力 (+25~+35)
                            }
                            else if (physiological.Lunchbox > 0)
                            {
                                changedStateValue.ChangeLunchbox -= 1; // 吃掉一個便當
                                changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 吃便當會增加心情
                                changedStateValue.ChangeHunger += Random.Shared.Next(40, 60); // 吃便當會增加飢餓值
                                changedStateValue.ChangeStamina += Random.Shared.Next(35, 46); // 食用便當大幅回補體力 (+35~+45)
                            }
                        }
                        break;
                    case 4:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 就醫成功會稍微增加心情
                        changedStateValue.ChangeHealth += Random.Shared.Next(20, 40); // 就醫會大幅增加健康值
                        if (physiological.Hp <= 100)
                        {
                            changedStateValue.ChangeHp += Random.Shared.Next(0, (100 - physiological.Hp + 1)); // 就醫會隨機回補未滿血量
                        }
                        changedStateValue.ChangeMoney -= Random.Shared.Next(10, 40); // 就醫會花費金錢
                        break;
                    case 5:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 回家成功會稍微增加心情
                        if (physiological.Stamina <= 50)
                        {
                            changedStateValue.ChangeStamina += Random.Shared.Next(30, 50); // 體力不足時回家會增加體力
                        }
                        break;
                    case 6:
                        break;
                    case 7:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 巡田水成功會稍微增加心情
                        changedStateValue.ChangeStamina -= Random.Shared.Next(2, 6); // 巡田水/勞動適度消耗體力 (單次扣2~5)
                        break;
                    case 8:
                        changedStateValue.ChangeMood += Random.Shared.Next(1, 5); // 販售物品成功會稍微增加心情
                        if (physiological.Wood > 0)
                        {
                            changedStateValue.ChangeWood -= physiological.Wood; // 販售木材會減少木材
                            changedStateValue.ChangeMoney += physiological.Wood * 4; // 販售木材會增加金錢
                        }
                        if (physiological.Stone > 0)
                        {
                            changedStateValue.ChangeStone -= physiological.Stone; // 販售石材會減少石材
                            changedStateValue.ChangeMoney += physiological.Stone * 1; // 販售石材會增加金錢
                        }
                        if (physiological.Mineral > 0)
                        {
                            changedStateValue.ChangeMineral -= physiological.Mineral; // 販售礦物會減少礦物
                            changedStateValue.ChangeMoney += physiological.Mineral * 5; // 販售礦物會增加金錢
                        }
                        if (physiological.Crops > 0)
                        {
                            changedStateValue.ChangeCrops -= physiological.Crops; // 販售農作物會減少農作物
                            changedStateValue.ChangeMoney += physiological.Crops * 3; // 販售農作物會增加金錢
                        }
                        if (physiological.Fish > 0)
                        {
                            changedStateValue.ChangeFish -= physiological.Fish; // 販售魚會減少魚
                            changedStateValue.ChangeMoney += physiological.Fish * 4; // 販售魚會增加金錢
                        }
                        break;
                }
            }
            else
            {
                changedStateValue.ChangeMood -= Random.Shared.Next(10, 21); // 行動失敗會降低心情
            }
        }

        // 計算社交行動的數值改變量
        public static void ComputeSocialAttributes(NPCclass source, NPCclass target)
        {
            int sourceId = source.Id;
            int targetId = target.Id;
            ResetChangedStateValue(source.ChangedStateValue);
            ResetChangedStateValue(target.ChangedStateValue);
            /*
            - 1. 普通聊天（chat with）
            - 2. 討論某個主題（talk about something）
            - 3. 詢問問題（ask something）
            - 4. 一起做一些事情( do something together )
            - 5. 捉弄( tease )
            - 6. 欺騙( cheat )
            - 7. 訊息傳播（spread message）
             */
            switch (source.Action.SocialAction)
            {
                case 1: // 普通聊天
                    int sFav1 = (targetId >= 1 && targetId <= 20) ? source.Social.Favorability[targetId - 1] : 50;
                    if (sFav1 >= 40)
                    {
                        source.ChangedStateValue.ChangeMood += Random.Shared.Next(5, 16); // 穩定提升心情
                        source.ChangedStateValue.ChangeTrust += Random.Shared.Next(1, 5); // 稍微增加信任度
                        source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(2, 6); // 破冰正向回饋增加好感度
                    }
                    else
                    {
                        source.ChangedStateValue.ChangeMood += Random.Shared.Next(-2, 4); // 氣氛微尷尬
                        source.ChangedStateValue.ChangeTrust += Random.Shared.Next(-1, 3);
                        source.ChangedStateValue.ChangeFavorability += (sFav1 < 25) ? -Random.Shared.Next(1, 4) : Random.Shared.Next(-1, 2);
                    }

                    int tFav1 = (sourceId >= 1 && sourceId <= 20) ? target.Social.Favorability[sourceId - 1] : 50;
                    if (tFav1 >= 40)
                    {
                        target.ChangedStateValue.ChangeMood += Random.Shared.Next(5, 16);
                        target.ChangedStateValue.ChangeTrust += Random.Shared.Next(1, 5);
                        target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(2, 6);
                    }
                    else
                    {
                        target.ChangedStateValue.ChangeMood += Random.Shared.Next(-2, 4);
                        target.ChangedStateValue.ChangeTrust += Random.Shared.Next(-1, 3);
                        target.ChangedStateValue.ChangeFavorability += (tFav1 < 25) ? -Random.Shared.Next(1, 4) : Random.Shared.Next(-1, 2);
                    }
                    break;

                case 2: // 討論主題
                    int sTrust2 = (targetId >= 1 && targetId <= 20) ? source.Social.Trust[targetId - 1] : 50;
                    if (sTrust2 >= 45)
                    {
                        source.ChangedStateValue.ChangeMood += Random.Shared.Next(10, 21); // 討論共鳴增加心情
                        source.ChangedStateValue.ChangeTrust += Random.Shared.Next(2, 6); // 增加信任度
                        source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(2, 6); // 增加好感度
                    }
                    else
                    {
                        source.ChangedStateValue.ChangeMood -= Random.Shared.Next(0, 6); // 意見稍有分歧
                        source.ChangedStateValue.ChangeTrust += Random.Shared.Next(-1, 3);
                        source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(-1, 2);
                    }

                    int tTrust2 = (sourceId >= 1 && sourceId <= 20) ? target.Social.Trust[sourceId - 1] : 50;
                    if (tTrust2 >= 45)
                    {
                        target.ChangedStateValue.ChangeMood += Random.Shared.Next(10, 21);
                        target.ChangedStateValue.ChangeTrust += Random.Shared.Next(2, 6);
                        target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(2, 6);
                    }
                    else
                    {
                        target.ChangedStateValue.ChangeMood -= Random.Shared.Next(0, 6);
                        target.ChangedStateValue.ChangeTrust += Random.Shared.Next(-1, 3);
                        target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(-1, 2);
                    }
                    break;

                case 3: // 詢問問題 (雙向回饋)
                    source.ChangedStateValue.ChangeMood += Random.Shared.Next(1, 6); // 請教獲益增加心情
                    source.ChangedStateValue.ChangeTrust += Random.Shared.Next(2, 7); // 增加信任度
                    source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(1, 5); // 增加好感度

                    target.ChangedStateValue.ChangeMood += Random.Shared.Next(1, 6); // 受請教感增加心情
                    target.ChangedStateValue.ChangeTrust += Random.Shared.Next(1, 5);
                    target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(1, 4);
                    break;

                case 4: // 共同活動 (依關係動態判定成功率)
                    int sFav4 = (targetId >= 1 && targetId <= 20) ? source.Social.Favorability[targetId - 1] : 50;
                    int tFav4 = (sourceId >= 1 && sourceId <= 20) ? target.Social.Favorability[sourceId - 1] : 50;
                    int successRate = Math.Clamp(70 + (sFav4 + tFav4) / 10, 70, 90);

                    if (Random.Shared.Next(1, 101) <= successRate) // 共同活動成功
                    {
                        source.ChangedStateValue.ChangeMood += Random.Shared.Next(12, 25); // 大幅提升心情
                        source.ChangedStateValue.ChangeTrust += Random.Shared.Next(6, 13); // 大幅增加信任度
                        source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(7, 15); // 大幅增加好感度
                        source.ChangedStateValue.ChangeStamina -= Random.Shared.Next(3, 8); // 輕量體力消耗

                        target.ChangedStateValue.ChangeMood += Random.Shared.Next(12, 25);
                        target.ChangedStateValue.ChangeTrust += Random.Shared.Next(6, 13);
                        target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(7, 15);
                        target.ChangedStateValue.ChangeStamina -= Random.Shared.Next(3, 8);
                    }
                    else // 共同活動略有不順
                    {
                        source.ChangedStateValue.ChangeMood -= Random.Shared.Next(1, 6);
                        source.ChangedStateValue.ChangeTrust -= Random.Shared.Next(0, 3);
                        source.ChangedStateValue.ChangeFavorability -= Random.Shared.Next(0, 3);
                        source.ChangedStateValue.ChangeStamina -= Random.Shared.Next(2, 6);

                        target.ChangedStateValue.ChangeMood -= Random.Shared.Next(1, 6);
                        target.ChangedStateValue.ChangeTrust -= Random.Shared.Next(0, 3);
                        target.ChangedStateValue.ChangeFavorability -= Random.Shared.Next(0, 3);
                        target.ChangedStateValue.ChangeStamina -= Random.Shared.Next(2, 6);
                    }
                    break;

                case 5: // 捉弄
                    source.ChangedStateValue.ChangeMood += Random.Shared.Next(2, 8); // 惡作劇心情
                    source.ChangedStateValue.ChangeStamina -= Random.Shared.Next(1, 6);

                    target.ChangedStateValue.ChangeMood -= Random.Shared.Next(4, 10); // 被捉弄不悅
                    target.ChangedStateValue.ChangeTrust -= Random.Shared.Next(1, 4);
                    target.ChangedStateValue.ChangeFavorability -= Random.Shared.Next(2, 6);
                    break;

                case 6: // 欺騙
                    source.ChangedStateValue.ChangeMood += Random.Shared.Next(2, 8);
                    source.ChangedStateValue.ChangeStamina -= Random.Shared.Next(1, 6);

                    target.ChangedStateValue.ChangeMood -= Random.Shared.Next(5, 12); // 被欺騙憤怒
                    target.ChangedStateValue.ChangeTrust -= Random.Shared.Next(3, 8);
                    target.ChangedStateValue.ChangeFavorability -= Random.Shared.Next(3, 7);
                    break;

                case 7: // 訊息傳播
                    source.ChangedStateValue.ChangeMood += Random.Shared.Next(2, 6);
                    source.ChangedStateValue.ChangeTrust += Random.Shared.Next(1, 5);
                    source.ChangedStateValue.ChangeFavorability += Random.Shared.Next(1, 4);

                    target.ChangedStateValue.ChangeMood += Random.Shared.Next(2, 6);
                    target.ChangedStateValue.ChangeTrust += Random.Shared.Next(1, 5);
                    target.ChangedStateValue.ChangeFavorability += Random.Shared.Next(1, 4);
                    break;
            }

        }

        // 計算一般行動的reward
        public static double ComputeRewardValue(ChangedStateValue changedStateValue)
        {
            double n = 0.0;
            n += changedStateValue.ChangeHp * 0.1;
            n += changedStateValue.ChangeHealth * 0.1;
            n += changedStateValue.ChangeStamina * 0.1;
            n += changedStateValue.ChangeHunger * 0.1;
            n += changedStateValue.ChangeSocialDesire * 0.1;
            n += changedStateValue.ChangeMood * 0.1;
            n += changedStateValue.ChangeMoney * 0.2;

            // 勞動即時產出估值：計入剛採集/生產物資的資產估值，抵消勞動體力消耗，消除跨職業獎勵斷層
            n += changedStateValue.ChangeCrops * 0.5;
            n += changedStateValue.ChangeMineral * 0.4;
            n += changedStateValue.ChangeWood * 0.3;
            n += changedStateValue.ChangeStone * 0.2;
            n += changedStateValue.ChangeFish * 0.4;

            return n;
        }

        // 每日結算時計算一般行動單一選項的reward用(未完成)
        public static double ComputeWeight(double todayReward, double Weight)
        { 
            if (Weight > 1.0)
                Weight *= 0.9;
            else
                Weight *= 1.1;

            Weight += todayReward * 0.1; // 之後要再修改這一行

            if (Weight > 1.3)
                Weight = 1.3;
            if (Weight < 0.7)
                Weight = 0.7;
            return Weight;
        }

        // 計算社交行動的正向(1)/中性(0)/負向(-1)
        public static int DetermineSTSMType(int changeTrust, int changeFriendship, int changeMood, int eventType)
        {
            if (eventType == 5 || eventType == 6)
                return -1;

            int sum = changeTrust + changeFriendship + changeMood;
            if (sum < 0)
                return -1;
            if (sum > 0)
                return 1;

            return 0;
        }

        // 重置changedStateValue的值
        public static void ResetChangedStateValue(ChangedStateValue changedStateValue)
        {
            changedStateValue.ChangeHp = 0;
            changedStateValue.ChangeHealth = 0;
            changedStateValue.ChangeStamina = 0;
            changedStateValue.ChangeHunger = 0;
            changedStateValue.ChangeSocialDesire = 0;
            changedStateValue.ChangeMood = 0;
            changedStateValue.ChangeMoney = 0;
            changedStateValue.ChangeWood = 0;
            changedStateValue.ChangeStone = 0;
            changedStateValue.ChangeMineral = 0;
            changedStateValue.ChangeCrops = 0;
            changedStateValue.ChangeFish = 0;
            changedStateValue.ChangeFood = 0;
            changedStateValue.ChangeLunchbox = 0;
            changedStateValue.ChangeTrust = 0;
            changedStateValue.ChangeFavorability = 0;
        }
    }
}
