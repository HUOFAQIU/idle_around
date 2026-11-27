extends ScenarioCase

const SOUL_ID: StringName = &"kong_lang_soul"
const RARITY: int = 1
const SEED: int = 7


func case_name() -> StringName:
	return &"soul_emotion_roll"


func run(ctx: ScenarioContext) -> void:
	var rolled := TestAPI.roll_soul_emotions(SOUL_ID, RARITY, SEED)
	ctx.check(not rolled.is_empty(), "恐狼可以 roll 出情绪构成")
	if rolled.is_empty():
		return

	var emotions: Dictionary = rolled["emotions"]
	var total := 0
	ctx.check(emotions.size() <= SoulEmotion.MAX_TYPES, "参与种类不超过 6")
	for id in emotions:
		total += int(emotions[id])
		ctx.check(int(emotions[id]) >= 1, "%s 至少 1%%" % id)
	ctx.equal(total, 100, "构成合计 100")
	ctx.check(emotions.has("damage") and emotions.has("cast_times"), "有效情绪全部参与")
	ctx.check(emotions.size() == SoulEmotion.MAX_TYPES, "补满 6 种")

	var damage_share := int(emotions.get("damage", 0))
	ctx.equal(
		int(rolled["damage"]),
		int(floorf(10.0 + 90.0 * float(damage_share) / 100.0)),
		"伤害按占比映射"
	)

	if emotions.has("cooldown"):
		ctx.near(
			float(rolled["cooldown"]),
			_cooldown_for(int(emotions["cooldown"])),
			0.0001,
			"冷却按占比反向映射"
		)
	else:
		ctx.near(float(rolled["cooldown"]), _cooldown_for(0), 0.0001, "未抽到冷却时取最慢端")

	var cast_share := int(emotions.get("cast_times", 0))
	var expected_times := 2 if cast_share < 50 else (3 if cast_share < 100 else 4)
	ctx.equal(int(rolled["cast_times"]), expected_times, "多重触发分段")

	var bounds := SoulEmotion.total_range(RARITY)
	var effective_total := damage_share + cast_share
	ctx.check(
		effective_total >= bounds.x and effective_total <= bounds.y,
		"有效总量落在稀有度区间"
	)

	var applied := TestAPI.apply_soul_emotions(
		SOUL_ID, {"damage": 25, "cast_times": 25, "cooldown": 50}
	)
	ctx.equal(int(applied["damage"]), 32, "伤害占比 25 映射到 32")
	ctx.near(float(applied["cooldown"]), _cooldown_for(50), 0.0001, "冷却占比 50 映射到 4.5 秒")
	ctx.equal(int(applied["cast_times"]), 2, "多重触发占比 25 映射到 2 次")

	var tooltip := TestAPI.get_soul_tooltip_with_emotions(SOUL_ID, emotions)
	ctx.check(tooltip.contains("情绪"), "tooltip 显示情绪段")
	ctx.check(
		tooltip.replace(" ", "").contains("伤害%d%%" % damage_share),
		"tooltip 显示伤害情绪占比"
	)
	var widths := _emotion_line_widths(tooltip)
	ctx.check(not widths.is_empty(), "tooltip 有情绪行")
	var aligned := not widths.is_empty()
	for width in widths:
		aligned = aligned and width == widths[0]
	ctx.check(aligned, "情绪行按显示宽度对齐")

	var roundtrip := TestAPI.check_soul_emotion_roundtrip(SOUL_ID, RARITY, SEED)
	for check in roundtrip.get("checks", []):
		ctx.check(bool(check["passed"]), "%s：%s" % [check["name"], check["detail"]])

	_check_type_cap(ctx)
	_check_loot_seam(ctx)
	_check_roll_to_warehouse(ctx)


func _check_loot_seam(ctx: ScenarioContext) -> void:
	var low := TestAPI.roll_loot_soul_emotions(SOUL_ID, 1, SEED)
	var high := TestAPI.roll_loot_soul_emotions(SOUL_ID, 5, SEED)
	ctx.check(not low.is_empty() and not high.is_empty(), "掉落链路能把恐狼交给仓库")
	if low.is_empty() or high.is_empty():
		return
	ctx.check(low["emotions"] != high["emotions"], "掉落按传入稀有度重新抽签")
	var high_share := (
		int(high["emotions"].get("damage", 0)) + int(high["emotions"].get("cast_times", 0))
	)
	var bounds := SoulEmotion.total_range(5)
	ctx.check(high_share >= bounds.x and high_share <= bounds.y, "传说稀有度掉落落在 65~85%")
	ctx.check(CollectionDB.get_soul(SOUL_ID).emotions.is_empty(), "掉落不改共享模板")


func _check_type_cap(ctx: ScenarioContext) -> void:
	var soul := SoulData.new()
	for id in SoulEmotion.IDS:
		if id != SoulEmotion.COOLDOWN:
			soul.emotion_ranges[id] = Vector2(0, 100)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	SoulEmotionRoller.roll(soul, RARITY, rng)
	var declared := SoulEmotion.effective_ids(soul.emotion_ranges)
	var participants := 0
	for id in soul.emotions:
		if declared.has(id):
			participants += 1
	ctx.equal(participants, SoulEmotion.MAX_TYPES, "超过 6 种有效时只保留 6 种")
	ctx.equal(soul.emotions.size(), SoulEmotion.MAX_TYPES, "满 6 种后不再补杂情绪")


func _check_roll_to_warehouse(ctx: ScenarioContext) -> void:
	var rolled := TestAPI.roll_soul_to_warehouse(SOUL_ID, RARITY, SEED)
	ctx.check(not rolled.is_empty(), "soul.roll 生成实例并入仓库")
	if rolled.is_empty():
		return
	var emotions: Dictionary = rolled["emotions"]
	ctx.check(not emotions.is_empty(), "入仓实例带情绪构成")
	var total := 0
	for id in emotions:
		total += int(emotions[id])
	ctx.equal(total, 100, "入仓实例构成合计 100")

	var command: Dictionary = CommandRegistry.run("soul.roll kong_lang_soul 1")
	ctx.check(bool(command["ok"]), "soul.roll 命令可执行")
	ctx.check(
		not (command["value"] as Dictionary).is_empty(),
		"soul.roll 返回入仓快照"
	)
	ctx.check(
		not bool(CommandRegistry.run("soul.roll kong_lang_soul 9")["ok"]),
		"稀有度越界被拒"
	)


func _emotion_line_widths(tooltip: String) -> Array[int]:
	var widths: Array[int] = []
	var in_emotions := false
	for line in tooltip.split("\n"):
		if line == "情绪":
			in_emotions = true
			continue
		if not in_emotions:
			continue
		if line.begins_with("==="):
			break
		widths.append(TerminalWidth.text_columns(line))
	return widths


func _cooldown_for(share: int) -> float:
	var value := 8.0 + (1.0 - 8.0) * float(share) / 100.0
	return roundi(value * 120.0) / 120.0
