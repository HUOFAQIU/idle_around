## 受击火花。
##
## 谁触发：GameplayEffect 上的 application_cue_tags（框架在施加瞬间自动发），
## 挂在哪：GameplayCueManager 会把它挂到"被打的那个单位"身上，
## 什么时候收回：destroy_delay 到点自动还回对象池。

class_name ImpactCue extends GameplayCueNotify

@onready var burst: ImpactBurst = $Burst


func play_cue() -> void:
	burst.play()
