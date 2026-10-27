现在就会触发 / 数据不一致

  1. 长弓描述与冷却不一致
  game/content/Souls/chang_gong/chang_gong_skill.tres:40
  冷却已经是 4 秒，描述还写“冷却 3 秒”。这是之前改数值留下的，属于确定问题。

  2. 扫描线每帧写 shader 参数
  Windows/Battle/battle_window.gd:240
  set_shader_param() 每次都会 duplicate() 字典并 sig_refresh.emit()，导致 ItemView 每帧 queue_redraw()。4 颗魂灵 × 60 帧不算致命，但确实是持续的无意义分配。
  补充：set_battle_status() 因为有 0.1 秒取整，实际约 10Hz 更新，不是每帧；审查这条说得略重。

  潜在正确性问题

  3. 暴击复制盲目乘所有 modifier
  game/battle/auto_cast_ability.gd:190-195
  现在对所有 modifier 的 magnitude 直接乘 crit_multiplier。遇到 PERCENT_ADD、DIVIDE、OVERRIDE 会算错。
  当前所有技能都没有配 crit_chance，所以暂时不触发；一旦配暴击就是真 bug。

  4. 暴击按 effect 逐条掷骰
  game/battle/auto_cast_ability.gd:184
  一个技能有多个效果时，同一目标可能第一条暴击、第二条不暴击，和注释“每支箭/每个目标独立掷暴击”不一致。当前技能都是单效果，暂时不触发。

  5. 充能满后同帧释放绕过冰冻
  game/battle/auto_cast_ability.gd:137
  BattleBrain 会检查 State.Frozen，但这里直接 target.try_activate()，没有检查。冰冻功能实现后，被冰冻的魂灵会被电池同帧触发。
  当前冰冻还没做，属于未来雷。

  6. 魂灵相邻只比较列，不比较行
  Windows/Battle/battle_window.gd:213
  SoulSlot 只记录 column，没有行号。当前所有魂灵都是 rows = 2，所以不会错；以后加入 1 行高的魂灵，上下不同行也可能被当成左右相邻。

  7. 死亡只停 _process，没停 _physics_process
  game/battle/battle_unit.gd:187
  brain.set_process(false) 对 BattleBrain._physics_process() 无效。目前靠 BattleBrain 开头的 is_dead 提前 return 兜住，属于潜在问题。

  8. 死代码 / 重复倍率逻辑
  game/battle/charged_ability.gd:102
  charge_multiplier() 没有任何调用，倍率逻辑在 _charged_units_for_tick() 里另有一份；charge_seconds() 也没有调用。以后改倍率容易只改一处。

  不建议按审查建议改

  9. base_units 没用 _delta
  game/battle/battle_brain.gd:46
  审查说“掉帧时 delta 会放大”，这个前提在 Godot 的 _physics_process 里不成立：物理帧 delta 是固定步长，掉帧时引擎会补跑多个 tick，而不是给一个更大的 delta。当前公式和 _delta 等价，而且符合你定的固定 tick 模型。除非以后运行中动态改 physics_ticks_per_second，否则不建议改。

  建议的修复顺序

  低风险、可以一起做：

  - 改长弓描述 3 秒 → 4 秒
  - 暴击改成每个目标只掷一次，再对所有效果一起应用
  - 同帧充能释放前加 State.Frozen 检查
  - brain.set_process(false) 改成 set_physics_process(false)
  - 删除 charge_multiplier()；charge_seconds() 没调试用途也一并删

  需要你定语义：

  - 暴击到底是“最终伤害 ×1.5”，还是“每个 modifier 的数值 ×1.5”？我建议前者，当前这种逐 modifier 乘是错的。

  可选：

  - 给 SoulSlot 加 row/height，为以后 1 行魂灵做准备
  - 扫描线进度降频或加专用 setter，避免每帧 duplicate + emit

  你确认要修哪几项，我再按项目规则出具体修改方案。
