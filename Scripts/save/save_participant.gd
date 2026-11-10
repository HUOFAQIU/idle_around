## 一个持久化域的接口：容器、见闻、未来的养成玩法各实现一份。
##
## SaveManager 只负责时机与文件，不关心各域的数据格式；
## participant 只读写 SaveDocument 里的自己的 section。
class_name SaveParticipant extends RefCounted


## 把本域数据写进顶层文档
func collect_into(_document: Dictionary) -> void:
	pass


## 从顶层文档恢复；has_disk_data 表示数据来自磁盘（不是新档默认值）。
## 返回 true 表示发生了迁移/修复，需要回写。
func apply_from(_document: Dictionary, _has_disk_data: bool) -> bool:
	return false


## 所有 participant apply 完之后再调用（例如孤儿物品重试入包）。
## 返回 true 表示发生了修复，需要回写。
func finish_load() -> bool:
	return false
