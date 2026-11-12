class_name PlayerProfile extends Resource
## 角色静态档案：角色窗口和战斗共用的唯一数据源。
##
## 只放展示/初始数值；战斗中的运行期生命在 BattleUnit 的属性集里，不写回这里。

## 角色显示名
@export var display_name: String = "小煤灯"
## 初始/最大生命值
@export var max_health: float = 500.0
