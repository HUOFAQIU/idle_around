## 被动魂灵的属性效果标记类。
##
## 被动效果在开战时挂到玩家身上，不写“获得/结束状态”日志。
## 用类型判断代替字符串 metadata，避免拼写错误和语义混淆。
class_name PassiveEffect extends GameplayEffect
