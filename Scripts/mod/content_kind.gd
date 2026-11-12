## 内容种类的唯一定义：ModLoader、CollectionDB 与见闻窗口共用同一套值。
##
## 不要再用裸 int 或各自定义的枚举；新增种类时同时更新 ContentKindSpec。
class_name ContentKind extends RefCounted

enum Kind {
	SOUL,
	MONSTER,
	CUE,
	VESSEL,
}
