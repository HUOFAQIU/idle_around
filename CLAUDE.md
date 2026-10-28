# idle_around
Godot 4.7 "U:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
工程 "U:\Godot_Project\idle_around"
Godot文档 "U:\Godot_Doc\Godot Engine 4.7 documentation in English MD"

# 一定要遵守的
1、交流沟通，文档记录都用中文。思考过程用英文。
2、我提出需求，你提供解决方案，先把方案输出，待我输入确认后，再修改。（临时探针之类的随意，保证 git diff 干净就行）
3、针对addons下文件，当你提供解决方案时，如不是必要，不要修改任何文件，需要修改时必须向我说明，阅读随意。
4、需求完成时，不要图省事写乱七八糟的代码，应该严格按照项目框架需求写合理的代码，我们不单单是要完成任务，更是要好好的完成任务。

# Godot
### 命名规定遵循 Godot 引擎风格
```
文件名
snake_case
yaml_parser.gd

类名
PascalCase
class_name YAMLParser

节点名称
PascalCase
Camera3D、Player

函数
snake_case
func load_level():

变量
snake_case
var particle_effect

信号
snake_case
signal door_opened

常量
CONSTANT_CASE
const MAX_SPEED = 200

枚举名称
PascalCase
enum Element

枚举成员
CONSTANT_CASE
{EARTH, WATER, AIR, FIRE}
```
### 建议按以下方式来组织 GDScript 代码：
```
01. @tool, @icon, @static_unload
02. class_name
03. extends
04. \#\# doc comment
05. signals
06. enums
07. constants
08. static variables
09. @export variables
10. remaining regular variables
11. @onready variables
12. _static_init()
13. remaining static methods
14. overridden built-in virtual methods:
	1. _init()
	2. _enter_tree()
	3. _ready()
	4. _process()
	5. _physics_process()
	6. remaining virtual methods
15. overridden custom methods
16. remaining methods
17. inner classes
```
