class_name SoulRes
extends Resource

## 魂灵占位大小
enum Size {
	SMALL,  ## 小型 1×2
	MEDIUM,   ## 中型 2×2
	LARGE,   ## 大型 3×2
}


@export var soul_size : Size = Size.SMALL

@export var sid : String = "0000"

## reference
@export var tags : Array[String] = []

@export var types : Array[String] = []

# Enchantments?
