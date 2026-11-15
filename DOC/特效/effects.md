# 给游戏加特效（GameplayCue）

> 类型：指南 | 状态：有效 | 核对：2026-11-15
> 何时读：新增/调试 GameplayCue 特效
> 关键词：特效 GameplayCue Cue 场景 对象池 补间 注册 挂钩 灼烧 剧毒 冻结 爪痕 hit_cue_tag 命中特效 mod 内置 core manifest
> 代码：`base_mods/core/mod.json`、`godot_gas/cue_registry.tres`、`addons/GodotGAS/cues/`、`Scripts/mod/mod_cue_registrar.gd`
> 相关：`架构/GAS.md`

框架自带一套 Cue 系统：**一个标签对应一个场景**。命中该冒什么火花、中毒每跳该闪什么、buff 该罩什么光，
全由数据说，不用写代码。但**接线有三步**，少一步就不出效果。

---

## 一、它是个什么东西

- 你自己的特效场景，**根节点必须继承 `GameplayCueNotify`**
- 它会被挂在**被作用的那个单位身上**（不是飘在世界里），所以场景里的 `(0, 0)` 就是单位的位置
- 播完自动还回**对象池**：同一个标签会反复复用同一个节点实例，不是每次都 `instantiate`
- 单位一销毁，挂在上面的 cue 跟着没 —— 这正好满足"关窗＝全部还原"

代码位置：`addons/GodotGAS/cues/gameplay_cue_notify.gd`（基类）、
`GameplayCueManager`（GodotGAS autoload）启动时加载 `godot_gas/cue_registry.tres`（当前为空）；`ModCueRegistrar`（autoload）随后把 ModLoader 的 core 和第三方 mod Cue 注册进去。注册完成后会检查技能 `hit_cue_tag` 和效果里的 `application/persistent/periodic/removal_cue_tags` 是否指向已注册标签；缺失会写进 `ModLoader.get_errors()`。

---

## 二、三步接上

### 第 1 步：写场景

新建一个场景；官方内容放 `base_mods/core/cues/`（逻辑脚本可留在 `game/battle/cues/`），第三方 mod 放自己的 `content/cues/`。根节点挂一个继承 `GameplayCueNotify` 的脚本：

```gdscript
## 命中火花
class_name HitSparkCue extends GameplayCueNotify

const LIFE : float = 0.3

@onready var sprite: Sprite2D = $Sprite2D

var _tween : Tween


## 每次播放都会走这里。场景是从对象池里捞出来的，
## 上面还留着上一次播完的状态 —— 所以必须先复位，再开新补间
func play_cue() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate.a = 1.0
	sprite.rotation = randf() * TAU

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), LIFE)
	_tween.tween_property(sprite, "rotation", sprite.rotation + 0.8, LIFE)
	_tween.tween_property(sprite, "modulate:a", 0.0, LIFE)
```

场景里可以放任何节点（Sprite2D、GPUParticles2D、AudioStreamPlayer…），
只有一条要注意：**管理器是靠切换子节点的 `visible` 来"关"这个 cue 的**（见下面第五节的坑）。

### 第 2 步：登记

在 manifest 的 `content.cues` 里加一条「标签 → 场景」：

- 官方内容：`base_mods/core/mod.json`，例如 `{ "tag": "Cue.Combat.Hit", "scene": "cues/hit_cue.tscn" }`；core 使用全局标签，不加前缀
- 第三方 mod：自己的 `mod.json`，标签必须是 `Cue.Mod.<PascalModId>.<Name>`
- `scene` 填相对内容根目录的路径

`godot_gas/cue_registry.tres` 现在为空，保留只是满足 GodotGAS 的默认路径检查；不要再往里加官方 Cue。

### 第 3 步：挂钩

最常用的是挂在**效果**上，四种挂点各管一段时机（`GameplayEffect` 的字段）：

| 字段 | 什么时候播 | 典型用途 |
|---|---|---|
| `application_cue_tags` | 效果刚施加到目标身上时 | 命中火花、受击音效 |
| `persistent_cue_tags` | 效果整个持续期间**一直**挂着播 | buff 光环、灼烧火焰；效果被压制时自动暂停 |
| `periodic_cue_tags` | 每次周期 tick 时 | 中毒每跳一次 |
| `removal_cue_tags` | 效果结束时 | 光环消散、状态解除 |

比如剧毒的持续效果，在 `base_mods/core/effects/poison_tick.tres` 里同时填了：

```
application_cue_tags = Array[StringName]([&"Cue.Combat.PoisonApply"])
persistent_cue_tags = Array[StringName]([&"Cue.Status.Poison"])
```

**到这儿就完了** —— 框架会自动：命中时把场景挂到被打的单位身上 → 播 → 到点收回池子。

重复施加一个已经在生效的周期效果时，框架在刷新持续时间的分支里也会重新触发 `application_cue_tags`。
所以 `poison_tick.tres` 同时挂了 `Cue.Combat.PoisonApply`（每次施毒爆一下）和 `Cue.Status.Poison`（持续气泡），
两段表现共用一个效果资源。

---

## 三、其它触发方式

不想走效果数据，也可以在代码里手动触发：

```gdscript
unit.asc.execute_cue(&"Cue.Combat.Hit")                    # 挂到 unit 身上播一下
unit.asc.execute_cue(&"Cue.Combat.Hit", {"damage": 50})    # 带 payload
```

技能内部（`GameplayAbility` 及其子类，比如 `AutoCastAbility`）：

```gdscript
execute_cue(&"Cue.Skill.<Name>.Fire")      # = owner_asc.execute_cue(tag)
```

**要用 payload 的话**，得重写 `execute_cue` 自己先接住 —— 因为基类不会把 payload 传给 `play_cue()`：

```gdscript
func execute_cue(target: Node, payload: Dictionary = {}) -> void:
	_my_payload = payload                      # 先存下来
	super.execute_cue(target, payload)         # 父类会接着调 play_cue()
```

技能数据也可以直接挂命中特效：`UnitSkillStep.hit_cue_tag` 填标签后，`AutoCastAbility` 每次结算到目标身上都会调用 `target.asc.execute_cue()`，并带上 `{"direction": ±1.0}`。这一击会打死目标时，单位会被 `BattleManager` 当场 `queue_free()`，挂在它身下的 Cue 来不及画出来，所以改挂到战场单位层并带上 `{"position": 世界坐标}`，让特效留在怪物最后的位置。需要左右交替的连续命中特效时，方向按每颗魂灵自己的命中次数交替，打空不消耗次数。cue 要读方向和位置时同样重写 `execute_cue()` 接住 payload。

---

## 四、基类给了什么

`GameplayCueNotify` 上的东西：

| 成员 | 作用 |
|---|---|
| `play_cue()` | **你重写这个**。播你的粒子/动画/音效 |
| `finish_cue()` | 手动宣布"播完了"，还回池子。挂到 `AudioStreamPlayer.finished` 之类上很合适 |
| `end_cue()` | 持续型 cue 被收走时调用，默认直接 `finish_cue()`，可以重写成淡出 |
| `auto_destroy` | 默认 `true`：到点自动还池。持续型光环设成 `false` |
| `destroy_delay` | 自动还池前的等待秒数，默认 2.0 |
| `gameplay_cue_tag` | 管理器填进来的本次标签，播的时候想知道自己是谁就用它 |

---

## 五、坑（都踩过）

**1. `destroy_delay` 要 ≥ 动画时长。**
它是"多久之后还池"，不是"动画多长"。设短了动画没放完就被收走，下次复用的时候上一次的补间还在跑。
稳妥写法就是上面那样：自己存一个 `_tween`，`play_cue` 开头先 `kill()`。

**2. 只有直接子节点会被自动隐藏。**
管理器还池时做的是 `cue.process_mode = DISABLED` + **遍历直接子节点设 `visible = false`**。
所以你的可视节点要么是根节点的直接子节点，要么自己在 `play_cue`/`end_cue` 里管好显示。

**3. 做小了、做快了，等于没做。**
之前那个火花就是这样：半径 3→22 像素、0.25 秒、alpha 从头就在淡 —— 等它扩出来已经淡没了，
怎么都看不见。三个数一起调：**尺寸、时长、透明度曲线**（别一上来就线性淡到 0，
先保持一两帧满透明度再淡）。

**4. 标签不用注册。**
框架不校验标签，`&"Cue.随便写"` 也能跑（只是不会自动出现补全）。
但登记到 `godot_gas/tag_registry.tres` 之后编辑器会给补全和校验，推荐还是登记一下。

**5. 没登记的标签不会报错，只是静默不播。**
`GameplayCueManager` 查不到标签就直接 return。所以"效果没出来"的第一嫌疑永远是：
注册表里那条登记写没写、标签字符串对不对（大小写、层级都要一模一样）。

---

## 六、怎么确认它真的在跑

按这个顺序排查，别靠眼睛猜：

1. **注册表查得到吗** —— `GameplayCueManager._cue_scenes.has(标签)`
2. **`play_cue` 被调用了吗** —— 临时在里面 `print` 或加个计数器
3. **节点真的在画吗** —— 有时候是 `_draw`/粒子在跑，但太小太淡看不见

第 3 步可以直接读主视口像素验证（面板是主视口里的 Control；先拿面板的全局矩形，再把面板内部坐标换算成视口坐标）：

```gdscript
await RenderingServer.frame_post_draw
var img := get_viewport().get_texture().get_image()
var origin := Vector2i(battle_window.get_global_rect().position)
print(img.get_pixel(origin + Vector2i(x, y)))   # x, y 是面板内部坐标
```

读之前把特效参数强行钉死（比如 `半径 = 30`、`alpha = 1.0`）再读，能把"时机不对"这个变量排除掉。

---

## 七、现有示例

| 东西 | 在哪 |
|---|---|
| 注册表 | 官方：`base_mods/core/mod.json` 的 `content.cues`；第三方：各自的 `mod.json` |
| 管理器（autoload） | `GameplayCueManager`：`addons/GodotGAS/managers/gameplay_cue_manager.gd` |
| mod 注册（autoload） | `ModCueRegistrar`：`Scripts/mod/mod_cue_registrar.gd` |
| 基类 | `addons/GodotGAS/cues/gameplay_cue_notify.gd` |
| 挂点字段 | `addons/GodotGAS/effects/gameplay_effect.gd` 的 Cue Management 一节 |
| 灼烧光环 | `base_mods/core/cues/burn_cue.tscn`；标签 `Cue.Status.Burn`；挂在 `base_mods/core/effects/burn_tick.tres` 的 `persistent_cue_tags` |
| 剧毒施加飞溅 | `base_mods/core/cues/poison_splash_cue.tscn`；标签 `Cue.Combat.PoisonApply`；挂在 `base_mods/core/effects/poison_tick.tres` 的 `application_cue_tags` |
| 中毒气泡光环 | `base_mods/core/cues/poison_aura_cue.tscn`；标签 `Cue.Status.Poison`；挂在 `poison_tick.tres` 的 `persistent_cue_tags` |
| 冻结光环 | `base_mods/core/cues/freeze_cue.tscn`；标签 `Cue.Status.Freeze`；挂在 `base_mods/core/effects/freeze_unit.tres` 的 `persistent_cue_tags` |
| 左右交替爪痕 | `base_mods/core/cues/claw_slash_cue.tscn`；标签 `Cue.Combat.ClawSlash`；由技能资源的 `hit_cue_tag` 触发；方向由 `AutoCastAbility` 按每颗魂灵的命中次数交替传入 |

魂灵格子被冻结时走的是 `ItemView` 的材质表现，不走 Cue：`SoulRuntime.freeze_seconds` 驱动 `soul_scanline.gdshader` 的 `freeze` 参数和 `game/content/Kits/bingdong.tscn` 徽章。原因是魂灵的显示对象是 UI `Control`，而不是可以挂 Cue 的战场节点。

（项目里原本有一个示例"受击火花"，后来按需要删掉了 —— 自己写的时候照上面三步来就行。）
