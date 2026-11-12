class_name ModInfo
extends RefCounted
## 一个已发现 mod 的运行时概况。
##
## 只描述 mod 的身份、来源、启用状态和加载结果；具体内容资源由 ModLoader 统一收集。

## mod 来源；Workshop 预留
enum Source {
	LOCAL,
	WORKSHOP,
	## 随游戏发布的内置 mod，例如官方 core 内容包
	BUILTIN,
}

var id: StringName = &""
var name: String = ""
var version: String = "0.0.0"
var author: String = ""
var description: String = ""
var source: Source = Source.LOCAL
## loose 目录或 PCK 所在目录
var root_path: String = ""
var manifest_path: String = ""
## PCK 路径；空 = loose 目录
var pack_path: String = ""
var manifest: ModManifest
## 玩家是否启用
var enabled: bool = true
## 依赖缺失/未启用导致本次不加载
var blocked: bool = false
## 本次是否完成加载（PCK 挂载成功或 loose 目录读取完成）
var loaded: bool = false
## 是否真的挂载了 PCK
var mounted: bool = false
var soul_count: int = 0
var monster_count: int = 0
var vessel_count: int = 0
var cue_count: int = 0
var errors: Array[String] = []
## 不阻止加载的诊断（例如未知 manifest 字段）
var warnings: Array[String] = []


## 是否为随游戏发布的内置 mod
func is_builtin() -> bool:
	return source == Source.BUILTIN
