extends StackableData
class_name ConsumableData

## 当数量为0时，是否摧毁物品
@export var destroy_if_empty: bool = true

func use() -> bool:
	if current_amount > 0:
		var consumed_amount = consume()
		if consumed_amount > 0:
			current_amount -= consumed_amount
			if current_amount <= 0:
				return destroy_if_empty
	return false

func consume() -> int:
	push_warning("[Override this function] consumable item [%s] has been consumed" % item_name)
	return 1
