## 技能数据加载器：所有技能都是 .tres 资源文件（可在编辑器里双击可视化编辑）。
##
## 技能的执行逻辑在 AutoCastAbility（game/battle/auto_cast_ability.gd）；
## 这里只负责按路径加载数据、组装成各单位的技能表。
##
## 数据文件（game/demo/ 下）：
##   zhan.tres  斩击      du.tres    毒矢
##   zhiyu.tres 治愈      zhua.tres  爪击
##
## @meta_addon: GodotGAS
## @meta_license: MIT

class_name SkillLibrary extends RefCounted

## 技能 id → 数据文件路径（换位置 / 加技能都在这里登记）
const SKILL_PATHS := {
	"slash": "res://game/demo/zhan.tres",
	"poison_bolt": "res://game/demo/du.tres",
	"heal": "res://game/demo/zhiyu.tres",
	"claw": "res://game/demo/zhua.tres",
}


## 我方（勇者）：斩击 / 毒矢 / 治愈
static func build_hero_skills() -> Array[SkillDefinition]:
	return _load_many(["slash", "poison_bolt", "heal"])


## 敌方（哥布林）：爪击
static func build_goblin_skills() -> Array[SkillDefinition]:
	return _load_many(["claw"])


static func _load_many(skill_ids: Array) -> Array[SkillDefinition]:
	var skills: Array[SkillDefinition] = []
	for skill_id in skill_ids:
		var skill := _load_skill(SKILL_PATHS[skill_id])
		if skill:
			skills.append(skill)
	return skills


static func _load_skill(path: String) -> SkillDefinition:
	var skill := load(path) as SkillDefinition
	if skill == null:
		push_error("SkillLibrary: 无法加载技能资源 %s，请确认文件存在" % path)
	return skill
