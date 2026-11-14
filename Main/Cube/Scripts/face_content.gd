class_name FaceContent
extends Control
## 立方体面的 2D 内容接口。
##
## Face3D 只通过本类建立内容与 3D 面的联系，不关心内容具体是哪种 UI。
## FaceUI（六面识别按钮）和 PetPanelContent（面 02 主菜单）都继承本类。

## 内容需要向立方体外壳报告「面被识别/点击」时发出
signal identify_requested


## 把面索引、名称和强调色传给内容；子类按需覆盖
func setup(_index: int, _display_name: String, _accent: Color) -> void:
	pass
