class_name ModContentEntry
extends RefCounted
## ModLoader 交给 CollectionDB 的一条运行时内容记录。

var kind: ContentKind.Kind = ContentKind.Kind.SOUL
var mod_id: StringName = &""
## 魂灵/怪物/魂器：manifest 内容 ID；Cue：标签
var content_id: StringName = &""
var path: String = ""
var resource: Resource
