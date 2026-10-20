# ==============================================================================
# 26號宇宙 (Universe 26) - 情報擴散與傳播管理器 (Information Diffusion Manager)
# 檔案路徑: res://scripts/ai/information_diffusion_manager.gd
# 職責描述:
#   1. 管理小鎮中所有流傳的情報與傳聞 (Rumors / Intel)
#   2. 提供 5 大結構化語意槽位模板 (經濟特報、醫療恐慌、社交號召、工作動機、人際八卦)
#   3. 支援公佈欄 (Notice Board) 與居民低語 (Whisper) 雙向傳播渠道
#   4. 記錄完整的傳播拓撲樹 (Diffusion Topology Tree)、世代數 (Generation) 與知曉率
#   5. 支援資料序列化 (to_dict / from_dict) 與存檔系統無縫整合
# ==============================================================================
class_name InformationDiffusionManager
extends RefCounted

## 情報發布時發射
signal rumor_published(rumor_id: String, title: String, channel: String)

## 情報在居民間成功擴散時發射
signal rumor_spread(rumor_id: String, from_id: String, to_id: String, generation: int)

## 5 大結構化情報模板類別
enum RumorCategory {
	ECONOMY = 0,  ## 經濟特報 (打折優惠、特價促銷)
	HEALTH = 1,   ## 醫療警訊 (疫情恐慌、就醫提醒)
	SOCIAL = 2,   ## 社交號召 (廣場集會、慶典聚會)
	WORK = 3,     ## 工作動機 (產量激勵、工期補貼)
	GOSSIP = 4    ## 人際八卦 (好感變動、人際評價)
}

## 傳播途徑渠道
const CHANNEL_BILLBOARD: String = "BILLBOARD" ## 公佈欄公告
const CHANNEL_WHISPER: String = "WHISPER"     ## 私下耳語

## 全鎮有效情報儲存庫 { rumor_id: String -> Dictionary }
var _active_rumors: Dictionary = {}

## 序列計數器 (用於生成唯一 ID)
var _counter: int = 0

# ------------------------------------------------------------------------------
# 1. 結構化情報生成與發布 (Publishing & Slot Templates)
# ------------------------------------------------------------------------------

## 發布一則新情報
## slots 依 category 提供不同槽位參數
func publish_rumor(
	category: RumorCategory,
	slots: Dictionary,
	channel: String = CHANNEL_BILLBOARD,
	seed_id: String = "",
	seed_name: String = "",
	cur_day: int = 1,
	cur_tick: int = 480
) -> Dictionary:
	_counter += 1
	var rumor_id: String = "rumor_%d_%d_%d" % [cur_day, cur_tick, _counter]
	var title: String = ""
	var content: String = ""
	var category_str: String = "economy"
	var category_cn: String = "經濟特報"
	var effects: Dictionary = {}

	match category:
		RumorCategory.ECONOMY:
			category_str = "economy"
			category_cn = "經濟特報"
			var loc_name: String = str(slots.get("location_name", "商店"))
			var poi_id: int = int(slots.get("poi_id", 12))
			var item_name: String = str(slots.get("item_name", "精選商品"))
			var discount: String = str(slots.get("discount", "全場 5 折優惠"))
			title = "%s %s特惠！" % [loc_name, item_name]
			content = "【%s】即日起舉辦特賣活動：%s現正特惠【%s】，吸引全鎮居民前往採購！" % [loc_name, item_name, discount]
			effects = {
				"type": "economy",
				"target_poi": poi_id,
				"fun_desire_bonus": 15.0,
				"mood_bonus": 10.0,
				"gravity_poi_id": poi_id
			}

		RumorCategory.HEALTH:
			category_str = "health"
			category_cn = "醫療警訊"
			var symptom: String = str(slots.get("symptom", "流感疲累"))
			var clinic_name: String = str(slots.get("clinic_name", "小鎮診所"))
			var clinic_poi: int = int(slots.get("poi_id", 14))
			title = "注意！鎮上流傳「%s」" % symptom
			content = "鎮長呼籲：近期小鎮居民出現【%s】症狀，請體虛勞累者務必儘速至【%s】接受診療！" % [symptom, clinic_name]
			effects = {
				"type": "health",
				"target_poi": clinic_poi,
				"health_vigilance": 25.0,
				"stamina_threshold_boost": 20.0,
				"gravity_poi_id": clinic_poi
			}

		RumorCategory.SOCIAL:
			category_str = "social"
			category_cn = "社交號召"
			var loc_name: String = str(slots.get("location_name", "噴泉廣場"))
			var loc_poi: int = int(slots.get("poi_id", 20))
			var time_str: String = str(slots.get("time_slot", "晚間 19:00"))
			title = "%s 居民聯歡集會！" % loc_name
			content = "大家注意！【%s】將在【%s】舉行大型晚間聚會，現場備有茶點，歡迎所有鄉親踴躍交流！" % [time_str, loc_name]
			effects = {
				"type": "social",
				"target_poi": loc_poi,
				"social_desire_bonus": 25.0,
				"mood_bonus": 15.0,
				"gravity_poi_id": loc_poi
			}

		RumorCategory.WORK:
			category_str = "work"
			category_cn = "工作動機"
			var work_name: String = str(slots.get("location_name", "農場與礦場"))
			var work_poi: int = int(slots.get("poi_id", 16))
			var bonus_desc: String = str(slots.get("bonus", "高額額外補貼 $30"))
			title = "%s 產能大豐收！" % work_name
			content = "號外！【%s】產量大增，凡於今日參與勞動者，均可獲得【%s】，工人們士氣大振！" % [work_name, bonus_desc]
			effects = {
				"type": "work",
				"target_poi": work_poi,
				"stamina_decay_modifier": -0.01,
				"work_incentive_bonus": 20.0,
				"gravity_poi_id": work_poi
			}

		RumorCategory.GOSSIP:
			category_str = "gossip"
			category_cn = "人際八卦"
			var npc_a_id: String = str(slots.get("npc_a_id", "npc_01"))
			var npc_a_name: String = str(slots.get("npc_a_name", "Alex"))
			var npc_b_id: String = str(slots.get("npc_b_id", "npc_02"))
			var npc_b_name: String = str(slots.get("npc_b_name", "Bob"))
			var relation_type: String = str(slots.get("relation_type", "好友結盟"))
			var desc: String = str(slots.get("desc", "在廣場相談甚歡，彼此稱兄道弟"))
			title = "%s 與 %s 的八卦流傳" % [npc_a_name, npc_b_name]
			content = "街坊傳聞：【%s】與【%s】最近【%s】！據說有人目擊他們【%s】。" % [npc_a_name, npc_b_name, relation_type, desc]
			effects = {
				"type": "gossip",
				"npc_a_id": npc_a_id,
				"npc_b_id": npc_b_id,
				"delta_fav": float(slots.get("delta_fav", 10.0)),
				"delta_trust": float(slots.get("delta_trust", 5.0))
			}

	var knowers_list: Array[String] = []
	var history: Array[Dictionary] = []

	var rumor_data: Dictionary = {
		"id": rumor_id,
		"category": category_str,
		"category_cn": category_cn,
		"title": title,
		"content": content,
		"channel": channel,
		"seed_id": seed_id,
		"seed_name": seed_name if not seed_name.is_empty() else ("公佈欄" if channel == CHANNEL_BILLBOARD else "神秘低語者"),
		"created_day": cur_day,
		"created_tick": cur_tick,
		"knowers": knowers_list,
		"spread_history": history,
		"effects": effects,
		"slots": slots.duplicate()
	}

	# 若指定特定種子 NPC，將該 NPC 納入第 1 世代知曉者 (G1)
	if not seed_id.is_empty():
		knowers_list.append(seed_id)
		history.append({
			"from_id": "seed",
			"from_name": rumor_data["seed_name"],
			"to_id": seed_id,
			"to_name": seed_name,
			"day": cur_day,
			"tick": cur_tick,
			"poi_id": int(slots.get("poi_id", 0)),
			"generation": 1
		})

	_active_rumors[rumor_id] = rumor_data
	rumor_published.emit(rumor_id, title, channel)
	print("[InformationDiffusionManager] 📢 成功發布新情報 [%s] (%s): %s (管道: %s)" % [category_cn, rumor_id, title, channel])
	return rumor_data

# ------------------------------------------------------------------------------
# 2. 擴散記錄與拓撲更新 (Spread Recording & Topology)
# ------------------------------------------------------------------------------

## 記錄一次居民間的情報分享傳播
func record_spread(
	rumor_id: String,
	from_id: String,
	from_name: String,
	to_id: String,
	to_name: String,
	cur_day: int,
	cur_tick: int,
	poi_id: int,
	from_generation: int = 1
) -> bool:
	if not _active_rumors.has(rumor_id):
		return false

	var r: Dictionary = _active_rumors[rumor_id]
	var knowers: Array = r["knowers"]
	if to_id in knowers:
		return false # 對方已知道此情報，不重複計數

	knowers.append(to_id)
	var new_gen: int = from_generation + 1
	var event: Dictionary = {
		"from_id": from_id,
		"from_name": from_name,
		"to_id": to_id,
		"to_name": to_name,
		"day": cur_day,
		"tick": cur_tick,
		"poi_id": poi_id,
		"generation": new_gen
	}
	r["spread_history"].append(event)
	rumor_spread.emit(rumor_id, from_id, to_id, new_gen)
	print("[InformationDiffusionManager] 🗣️ 情報擴散 [%s] 由 %s -> %s (第 %d 代 / 目前知曉率: %d/20)" % [
		r["title"], from_name, to_name, new_gen, knowers.size()
	])
	return true

## 取得所有活躍情報清單
func get_active_rumors() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for k in _active_rumors.keys():
		list.append(_active_rumors[k])
	return list

## 依 ID 取得單一情報
func get_rumor_by_id(rumor_id: String) -> Dictionary:
	return _active_rumors.get(rumor_id, {})

## 取得公佈欄公告情報清單
func get_billboard_rumors() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for k in _active_rumors.keys():
		var r: Dictionary = _active_rumors[k]
		if r.get("channel", "") == CHANNEL_BILLBOARD:
			res.append(r)
	return res

## 取得特定情報的知曉率統計
func get_knowledge_stats(rumor_id: String, total_population: int = 20) -> Dictionary:
	if not _active_rumors.has(rumor_id):
		return { "count": 0, "total": total_population, "ratio": 0.0, "percentage_str": "0%" }
	var knowers: Array = _active_rumors[rumor_id].get("knowers", [])
	var count: int = knowers.size()
	var ratio: float = float(count) / float(maxi(total_population, 1))
	return {
		"count": count,
		"total": total_population,
		"ratio": ratio,
		"percentage_str": "%.1f%%" % (ratio * 100.0)
	}

# ------------------------------------------------------------------------------
# 3. 傳播拓撲樹格式化 (Verifiable Topology Tree Formatting)
# ------------------------------------------------------------------------------

## 取得特定情報的完整文字拓撲樹 (用於驗證介面直觀檢視)
func get_rumor_topology_tree_text(rumor_id: String) -> String:
	if not _active_rumors.has(rumor_id):
		return "⚠️ 查無此情報紀錄"

	var r: Dictionary = _active_rumors[rumor_id]
	var lines: Array[String] = []
	var chan_text: String = "📌 公佈欄張貼" if r.get("channel", "") == CHANNEL_BILLBOARD else "🤫 私下耳語"
	lines.append("【情報名稱】%s [%s]" % [r.get("title", ""), r.get("category_cn", "")])
	lines.append("【發布管道】%s (發布源: %s)" % [chan_text, r.get("seed_name", "")])
	lines.append("【發布時間】第 %d 天 %02d:%02d" % [int(r.get("created_day", 1)), int(r.get("created_tick", 0)) / 60, int(r.get("created_tick", 0)) % 60])
	lines.append("【內容詳情】%s" % r.get("content", ""))

	var stats: Dictionary = get_knowledge_stats(rumor_id)
	lines.append("【擴散成效】知曉率 %s (%d / %d 居民)" % [stats["percentage_str"], stats["count"], stats["total"]])
	lines.append("────────────────────────────────────────")
	lines.append("🌐 傳播因果拓撲樹 (Diffusion Topology):")

	var history: Array = r.get("spread_history", [])
	if history.is_empty():
		lines.append("  └─ (尚未有居民知曉或向外傳播)")
		return "\n".join(lines)

	# 依世代 (Generation) 分組呈現傳播鏈
	var max_gen: int = 1
	for ev in history:
		if int(ev.get("generation", 1)) > max_gen:
			max_gen = int(ev.get("generation", 1))

	# 建立以 to_id 為索引的傳遞字典
	for gen in range(1, max_gen + 1):
		var gen_events: Array[Dictionary] = []
		for ev in history:
			if int(ev.get("generation", 1)) == gen:
				gen_events.append(ev)
		
		if gen == 1:
			lines.append("  [種子世代 G1 (第一手聽聞)]")
		else:
			lines.append("  [擴散世代 G%d]" % gen)

		for ev in gen_events:
			var t_str: String = "%02d:%02d" % [int(ev.get("tick", 0)) / 60, int(ev.get("tick", 0)) % 60]
			var from_str: String = ev.get("from_name", "來源")
			var to_str: String = ev.get("to_name", "居民")
			var poi_id: int = int(ev.get("poi_id", 0))
			var poi_tag: String = "(POI %d)" % poi_id if poi_id > 0 else ""
			if gen == 1:
				lines.append("    • %s 於 第%d天 %s 獲知情報 %s" % [to_str, int(ev.get("day", 1)), t_str, poi_tag])
			else:
				lines.append("    • %s ──> %s (第%d天 %s %s)" % [from_str, to_str, int(ev.get("day", 1)), t_str, poi_tag])

	return "\n".join(lines)

# ------------------------------------------------------------------------------
# 4. 序列化與存檔支援 (Serialization)
# ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var rumors_dict: Dictionary = {}
	for k in _active_rumors.keys():
		rumors_dict[k] = _active_rumors[k].duplicate(true)
	return {
		"counter": _counter,
		"active_rumors": rumors_dict
	}

func from_dict(data: Dictionary) -> void:
	_counter = int(data.get("counter", 0))
	_active_rumors.clear()
	var raw_rumors: Dictionary = data.get("active_rumors", {})
	for k in raw_rumors.keys():
		_active_rumors[str(k)] = raw_rumors[k].duplicate(true)
	print("[InformationDiffusionManager] 成功從存檔載入 %d 筆情報數據！" % _active_rumors.size())

