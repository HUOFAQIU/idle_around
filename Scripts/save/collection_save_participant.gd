## 见闻的存档域：已遇见的怪物/魂灵。
##
## 新档或缺少 collection 段时尝试从旧 collection.cfg 迁移；
## 迁移成功返回 true，让 SaveManager 立即回写新格式。
class_name CollectionSaveParticipant extends SaveParticipant


func collect_into(document: Dictionary) -> void:
	document[SaveDocument.KEY_COLLECTION] = CollectionDB.to_save_data()


func apply_from(document: Dictionary, has_disk_data: bool) -> bool:
	var collection_data: Variant = document.get(SaveDocument.KEY_COLLECTION)
	if has_disk_data and collection_data is Dictionary:
		CollectionDB.apply_save_data(collection_data)
		return false
	if CollectionDB.load_legacy_state():
		push_warning("存档：已从旧 collection.cfg 迁移见闻记录")
		return true
	CollectionDB.apply_save_data({})
	return false
