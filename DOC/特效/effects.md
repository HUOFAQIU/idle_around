# 给游戏加特效（GameplayCue）

> 类型：指南 | 状态：有效 | 整理：2026-10-31
> 何时读：新增/调试 GameplayCue 特效
> 关键词：特效 GameplayCue Cue 场景 对象池 补间 注册 挂钩
> 代码：`godot_gas/cue_registry.tres`、`addons/GodotGAS/cues/`
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
`addons/GodotGAS/managers/gameplay_cue_manager.gd`（管理器，是 autoload）

---

## 二、三步接上

### 第 1 步：写场景

新建一个场景（放哪都行，比如 `game/battle/cues/`），根节点挂一个继承 `GameplayCueNotify` 的脚本：

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

在 `godot_gas/cue_registry.tres` 里加一条「标签 → 场景」：

- 用编辑器打开这个资源，`entries` 数组里加一项
- `tag` 填标签（例如 `Cue.Combat.Hit`），`scene` 拖你的场景

（GodotGAS 的编辑器面板里也能加，效果一样。）

### 第 3 步：挂钩

最常用的是挂在**效果**上，四种挂点各管一段时机（`GameplayEffect` 的字段）：

| 字段 | 什么时候播 | 典型用途 |
|---|---|---|
| `application_cue_tags` | 效果刚施加到目标身上时 | 命中火花、受击音效 |
| `persistent_cue_tags` | 效果整个持续期间**一直**挂着播 | buff 光环、灼烧火焰；效果被压制时自动暂停 |
| `periodic_cue_tags` | 每次周期 tick 时 | 中毒每跳一次 |
| `removal_cue_tags` | 效果结束时 | 光环消散、状态解除 |

比如长弓的伤害效果，在 `game/content/skills/chang_gong.tres` 里给"伤害"那个子资源填：

```
application_cue_tags = Array[StringName]([&"Cue.Combat.Hit"])
```

**到这儿就完了** —— 框架会自动：命中时把场景挂到被打的单位身上 → 播 → 到点收回池子。

---

## 三、其它触发方式

不想走效果数据，也可以在代码里手动触发：

```gdscript
unit.asc.execute_cue(&"Cue.Combat.Hit")                    # 挂到 unit 身上播一下
unit.asc.execute_cue(&"Cue.Combat.Hit", {"damage": 50})    # 带 payload
```

技能内部（`GameplayAbility` 及其子类，比如 `AutoCastAbility`）：

```gdscript
execute_cue(&"Cue.Skill.Longbow.Fire")     # = owner_asc.execute_cue(tag)
```

**要用 payload 的话**，得重写 `execute_cue` 自己先接住 —— 因为基类不会把 payload 传给 `play_cue()`：

```gdscript
func execute_cue(target: Node, payload: Dictionary = {}) -> void:
	_my_payload = payload                      # 先存下来
	super.execute_cue(target, payload)         # 父类会接着调 play_cue()
```

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

第 3 步可以直接读窗口像素验证（战斗窗口是独立 OS 窗口，能读回自己的画面）：

```gdscript
await RenderingServer.frame_post_draw
var img := battle_window.get_texture().get_image()
print(img.get_pixel(x, y))          # 窗口内部坐标
```

读之前把特效参数强行钉死（比如 `半径 = 30`、`alpha = 1.0`）再读，能把"时机不对"这个变量排除掉。

---

## 七、现有示例

| 东西 | 在哪 |
|---|---|
| 注册表 | `godot_gas/cue_registry.tres` |
| 管理器（autoload） | `addons/GodotGAS/managers/gameplay_cue_manager.gd` |
| 基类 | `addons/GodotGAS/cues/gameplay_cue_notify.gd` |
| 挂点字段 | `addons/GodotGAS/effects/gameplay_effect.gd` 的 Cue Management 一节 |
| 灼烧光环 | `game/battle/cues/burn_cue.tscn`；标签 `Cue.Status.Burn`；挂在 `game/content/effects/burn_tick.tres` 的 `persistent_cue_tags` |

（项目里原本有一个示例"受击火花"，后来按需要删掉了 —— 自己写的时候照上面三步来就行。）
