## 见闻的存档域：已遇见的怪物/魂灵。
##
## 存档里没有 collection 段（新档/缺段）时按空状态处理。
class_name CollectionSaveParticipant extends SaveParticipant


func collect_into(document: Dictionary) -> void:
	document[SaveDocument.KEY_COLLECTION] = CollectionDB.to_save_data()


func apply_from(document: Dictionary, has_disk_data: bool) -> bool:
	var collection_data: Variant = document.get(SaveDocument.KEY_COLLECTION)
	if has_disk_data and collection_data is Dictionary:
		CollectionDB.apply_save_data(collection_data)
	else:
		CollectionDB.apply_save_data({})
	return false
