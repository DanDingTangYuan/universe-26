# ==============================================================================
# 26號宇宙 (Universe 26) - 社交語意與 LLM 接口服務 (Social Semantics & LLM Interface)
# 檔案路徑: res://scripts/ai/social_semantics.gd
# 職責描述:
#   1. 提供社交關係標籤化 (Relationship Tags)
#   2. 提供職業與情境語意話題池 (Job & Context Topic Pool)
#   3. 管理村民八卦傳聞擴散 (Rumor & Information Diffusion)
#   4. 預留並提供未來外掛 LLM (本地/遠端大語言模型) 進行自回歸對話與思考生成的抽象接口
# ==============================================================================
class_name SocialSemantics
extends RefCounted

## 外部掛載 LLM 對話生成 Hook (簽章: func(prompt_dict: Dictionary) -> String)
var llm_dialogue_hook: Callable = Callable()

## 外部掛載 LLM 動機思考 Hook (簽章: func(state_dict: Dictionary) -> String)
var llm_thought_hook: Callable = Callable()

## 全域八卦傳聞隊列 (最多保留 30 條近期小鎮傳聞)
var _rumor_pool: Array[Dictionary] = []

# ------------------------------------------------------------------------------
# 1. 人際關係標籤化 (Relationship Labeling)
# ------------------------------------------------------------------------------

## 依據好感度與信任度轉換為自然語言關係標籤 (供 Transformer Self-Attention 與 Prompt 使用)
func get_relationship_label(favorability: float, trust: float) -> String:
	if favorability < 30.0 or trust < 25.0:
		return "宿敵/互看不順眼"
	elif favorability < 45.0:
		return "冷淡生疏"
	elif favorability >= 75.0 and trust >= 65.0:
		return "莫逆之交/至交好友"
	elif favorability >= 60.0:
		return "相處融洽/熟識朋友"
	else:
		return "點頭之交/一般居民"

# ------------------------------------------------------------------------------
# 2. 語意話題池 (Contextual Dialogue & Topic Generation)
# ------------------------------------------------------------------------------

## 職業名稱對照表
const JOB_NAMES: Dictionary = {
	1: "礦工",
	2: "圖書館員",
	3: "漁夫",
	4: "餐廳廚師",
	5: "醫護人員",
	6: "伐木工",
	7: "農民",
	8: "雜貨店長",
	9: "鎮民"
}

## 依據職業、行為類型與當前社交階段生成自然語意話題
func generate_topic(
	source_job: int,
	target_job: int,
	social_action_id: int,
	phase: String,
	favorability: float,
	_mood: float
) -> String:
	var s_job: String = JOB_NAMES.get(source_job, "鎮民")
	var t_job: String = JOB_NAMES.get(target_job, "鎮民")

	match social_action_id:
		1: # 普通聊天 (Chat)
			if phase == "破冰期":
				var icebreakers: Array[String] = [
					"寒暄問候並打聽彼此近日的作息",
					"閒聊鎮上今天晴朗的好天氣",
					"互相打聽小鎮廣場近期的聚集情況",
					"禮貌性詢問對方的日常行程"
				]
				return icebreakers[randi() % icebreakers.size()]
			elif favorability >= 65.0:
				var friend_chats: Array[String] = [
					"分享彼此昨晚的美夢與趣事",
					"笑談鎮上生活中的輕鬆點滴",
					"關心對方今天的精神與心情狀況",
					"相約晚點有空一起小憩聊天"
				]
				return friend_chats[randi() % friend_chats.size()]
			else:
				return "冷淡地敷衍了兩句近況"

		2: # 討論主題 (Discuss Topic)
			var work_topics: Array[String] = [
				"深入討論 %s 與 %s 在物資供應上的互補合作" % [s_job, t_job],
				"交流城鎮近期物價波動與物資產能狀況",
				"探討日常勞動中的體力分配與工具維護技巧",
				"針對鎮上未來的發展建設交換看法"
			]
			return work_topics[randi() % work_topics.size()]

		3: # 詢問問題 (Ask Question)
			var questions: Array[String] = [
				"向對方請教關於 %s 專業領域的實用經驗" % t_job,
				"打聽鎮上雜貨店與餐廳今天的物資存量",
				"詢問往返居住地與工作崗位的最佳路線",
				"打聽彼此最近是否有生病就醫的需要"
			]
			return questions[randi() % questions.size()]

		4: # 共同活動 (Do Activity Together)
			var activities: Array[String] = [
				"相約在社交廣場中央一同散步放鬆",
				"結伴前往河畔與林邊感受自然微風",
				"相偕至餐廳共進便當並暢聊理想",
				"在空地上切磋手藝與勞動心得"
			]
			return activities[randi() % activities.size()]

		5: # 捉弄 (Tease)
			return "開了個無傷大雅的小玩笑或是惡作劇"

		6: # 欺騙 (Cheat)
			return "編造虛假的八卦情報試圖誤導對方"

		7: # 訊息傳播 (Spread Message)
			var rumor: Dictionary = get_random_rumor()
			if not rumor.is_empty():
				return "分享情報: 「%s」" % rumor.get("text", "城鎮近日和平穩定")
			return "傳遞了關於近期物資交易的小道消息"

		_:
			return "簡單地點頭致意"

# ------------------------------------------------------------------------------
# 3. 八卦與情報傳播機制 (Rumor & Information Diffusion)
# ------------------------------------------------------------------------------

## 註冊一條新發生的小鎮傳聞事件
func add_rumor(author_name: String, subject_name: String, event_desc: String, day: int, tick: int) -> void:
	var rumor: Dictionary = {
		"id": "rumor_%d_%d_%d" % [day, tick, randi() % 1000],
		"day": day,
		"tick": tick,
		"author": author_name,
		"subject": subject_name,
		"event": event_desc,
		"text": "聽說 %s 於第 %d 天在鎮上 %s" % [subject_name, day, event_desc],
		"spread_count": 0
	}
	_rumor_pool.append(rumor)
	if _rumor_pool.size() > 30:
		_rumor_pool.pop_front()

## 隨機抽取一條有效傳聞供行為 7 傳播
func get_random_rumor() -> Dictionary:
	if _rumor_pool.is_empty():
		return {}
	var idx: int = randi() % _rumor_pool.size()
	var r: Dictionary = _rumor_pool[idx]
	r["spread_count"] = int(r.get("spread_count", 0)) + 1
	return r

# ------------------------------------------------------------------------------
# 4. LLM 抽象接口與 Prompt 上下文構建 (LLM Hook & Prompt Formatter)
# ------------------------------------------------------------------------------

## 構建標準 LLM 訓練與推論上下文 (支援 ChatML / Alpaca 格式)
func build_llm_prompt_context(
	source_id: String,
	source_name: String,
	source_job: int,
	target_id: String,
	target_name: String,
	target_job: int,
	favorability: float,
	trust: float,
	action_name: String,
	phase: String,
	topic: String,
	time_str: String
) -> Dictionary:
	var rel_label: String = get_relationship_label(favorability, trust)
	var s_job_str: String = JOB_NAMES.get(source_job, "鎮民")
	var t_job_str: String = JOB_NAMES.get(target_job, "鎮民")

	var system_prompt: String = "你是生活在26號宇宙中的NPC %s，職業為 %s。請根據你與其他居民的人際關係與性格特質進行自然且具備因果性的社交互動。" % [source_name, s_job_str]
	var user_prompt: String = "【情境】時間是 %s。你正在社交廣場遇見了 %s (%s)。你們目前的關係為「%s」(好感: %.1f, 信任: %.1f)。\n【互動】你發起了 [%s] (階段: %s)。討論話題為: %s。\n請以 %s 的口吻回應此對話。" % [
		time_str, target_name, t_job_str, rel_label, favorability, trust, action_name, phase, topic, source_name
	]

	# 若有外掛 LLM Hook 則調用生成，否則生成內建模板對白
	var generated_dialogue: String = ""
	if llm_dialogue_hook.is_valid():
		var hook_res = llm_dialogue_hook.call({
			"system": system_prompt,
			"user": user_prompt,
			"source_name": source_name,
			"target_name": target_name,
			"topic": topic
		})
		if hook_res is String:
			generated_dialogue = hook_res

	if generated_dialogue.is_empty():
		generated_dialogue = "「嗨，%s！關於%s，我覺得挺不錯的。」" % [target_name, topic]

	return {
		"format": "chatml",
		"system": system_prompt,
		"prompt": user_prompt,
		"response": generated_dialogue,
		"relationship_tag": rel_label,
		"topic": topic
	}

