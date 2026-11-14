class_name TerminalSpan
extends RefCounted
## 跨多格显示的一行大字。
##
## TerminalView 只把它当作绘制装饰：Buffer 对应格子留空，字号和每个字的列宽
## 由 TerminalView 按 rows 和字体度量计算。当前不参与 Buffer 的历史、光标和选中，
## 只用于 Tooltip 标题这类静态内容。

## 要绘制的文本；换行会按空格处理
var text: String = ""
## 左上角在字符网格里的位置
var row: int = 0
var col: int = 0
## 占用的行数；大于 1 时就是多格高大字
var rows: int = 2
## 可选样式；为空时使用终端默认前景色
var style: TerminalStyle
