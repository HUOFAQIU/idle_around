class_name WeatherPreset
extends Resource

@export_group("Identity")
## 天气内部唯一标识（如 sun、rain、snow）
@export var id: String = "sun"
## 右上角天气切换按钮上显示的简称文字
@export var button_label: String = "SUN"

@export_group("Lighting")
## 主方向光（太阳/天光）颜色
@export var sun_color: Color = Color(1.0, 0.91, 0.72, 1.0)
## 主方向光强度
@export_range(0.0, 4.0, 0.05) var sun_energy: float = 1.80
## 天空辅助补光颜色（照亮暗面）
@export var fill_color: Color = Color(0.58, 0.80, 1.0, 1.0)
## 天空辅助补光强度
@export_range(0.0, 3.0, 0.05) var fill_energy: float = 0.56
## 全局环境光颜色
@export var ambient_color: Color = Color(0.66, 0.74, 0.66, 1.0)
## 全局环境光强度
@export_range(0.0, 2.0, 0.02) var ambient_energy: float = 0.58
## 场景最远处的背景底色
@export var background_color: Color = Color(0.14, 0.22, 0.16, 1.0)

@export_group("Mist")
## 贴地流动雾的基础颜色
@export var mist_color: Color = Color(0.52, 0.58, 0.46, 1.0)
## 雾层起始基准高度（世界坐标 Y）
@export_range(-2.0, 3.0, 0.05) var mist_base_y: float = -0.25
## 雾层随高度衰减的厚度（越大雾越高）
@export_range(0.1, 3.0, 0.05) var mist_scale_h: float = 0.45
## 贴地雾整体浓度
@export_range(0.0, 2.0, 0.02) var mist_density: float = 0.72
## 雾层最终亮度增益
@export_range(0.0, 0.5, 0.005) var mist_gain: float = 0.065

@export_group("Surface & Grass")
## 泥土与石块的湿润程度（0 干燥，1 湿润变深并泛微反光）
@export_range(0.0, 1.0, 0.05) var ground_wetness: float = 0.0
## 草坪雨天程度（0 晴天暖绿，1 雨天深冷绿且大风吹动）
@export_range(0.0, 1.0, 0.05) var grass_rain_amount: float = 0.0

@export_group("Post Process")
## 画面整体曝光亮度
@export_range(0.4, 1.6, 0.02) var exposure: float = 0.96
## 画面整体色彩饱和度
@export_range(0.2, 1.6, 0.02) var saturation: float = 0.90
## 屏幕四周暗角强度（0 无暗角）
@export_range(0.0, 1.0, 0.02) var vignette: float = 0.34
## 画面暗部阴影色调抬升（R/G/B 偏移）
@export var shadow_lift: Vector3 = Vector3(0.022, 0.024, 0.018)

@export_group("Lightning")
## 是否允许在此天气下触发随机雷电闪光
@export var allow_lightning: bool = false
## 两次闪电之间的最短随机间隔（秒）
@export_range(1.0, 30.0, 0.5) var lightning_interval_min: float = 6.0
## 两次闪电之间的最长随机间隔（秒）
@export_range(2.0, 40.0, 0.5) var lightning_interval_max: float = 12.5
## 闪电瞬间天光混合的目标冷白色
@export var lightning_sun_color: Color = Color(0.88, 0.94, 1.0, 1.0)
## 闪电瞬间主光额外增加的能量
@export_range(0.0, 5.0, 0.1) var lightning_sun_boost: float = 2.1
## 闪电瞬间补光额外增加的能量
@export_range(0.0, 2.0, 0.05) var lightning_fill_boost: float = 0.95
## 闪电瞬间环境光额外增加的能量
@export_range(0.0, 1.5, 0.05) var lightning_ambient_boost: float = 0.45
## 闪电瞬间后处理曝光额外抬升量
@export_range(0.0, 0.8, 0.02) var lightning_exposure_boost: float = 0.24

@export_group("Particles Ambient")
## 天气粒子受到的环境基础照明色
@export var particle_ambient: Color = Color(0.68, 0.78, 0.64, 1.0)

@export_group("Particles A (Primary: Pollen / Rain)")
## A 组主粒子占总粒子池的比例（如花粉或斜雨丝）
@export_range(0.0, 1.0, 0.02) var particle_a_ratio: float = 0.32
## A 组粒子的世界空间飘落速度（X/Y/Z）
@export var particle_a_vel: Vector3 = Vector3(0.30, -0.14, 0.16)
## A 组粒子水平摇摆（X=摆幅，Y=频率）
@export var particle_a_sway: Vector2 = Vector2(0.65, 0.75)
## A 组粒子随机尺寸范围（X=最小，Y=最大）
@export var particle_a_size: Vector2 = Vector2(0.028, 0.052)
## A 组粒子颜色（Alpha 控制受环境光影响的权重）
@export var particle_a_color: Color = Color(0.96, 0.96, 0.80, 1.0)
## A 组粒子不透明度
@export_range(0.0, 1.0, 0.02) var particle_a_alpha: float = 0.65
## A 组粒子闪烁频率（0 表示不闪烁）
@export_range(0.0, 5.0, 0.1) var particle_a_twinkle: float = 0.0
## A 组粒子按速度方向拉伸的系数（雨丝用 >0，雪/花粉用 0）
@export_range(0.0, 2.0, 0.05) var particle_a_stretch: float = 0.0
## A 组粒子循环生成的高度区间（X=最低 Y，Y=最高 Y）
@export var particle_a_y_range: Vector2 = Vector2(-1.5, 11.0)

@export_group("Particles B (Secondary: Leaves / Mist)")
## B 组次粒子占总粒子池的比例（如飘叶或低空水汽）
@export_range(0.0, 1.0, 0.02) var particle_b_ratio: float = 0.12
## B 组粒子的世界空间飘落速度（X/Y/Z）
@export var particle_b_vel: Vector3 = Vector3(0.24, -0.22, 0.18)
## B 组粒子水平摇摆（X=摆幅，Y=频率）
@export var particle_b_sway: Vector2 = Vector2(0.95, 1.15)
## B 组粒子随机尺寸范围（X=最小，Y=最大）
@export var particle_b_size: Vector2 = Vector2(0.042, 0.072)
## B 组粒子颜色（Alpha 控制受环境光影响的权重）
@export var particle_b_color: Color = Color(0.75, 0.92, 0.48, 0.0)
## B 组粒子不透明度
@export_range(0.0, 1.0, 0.02) var particle_b_alpha: float = 1.0
## B 组粒子闪烁频率（0 表示不闪烁）
@export_range(0.0, 5.0, 0.1) var particle_b_twinkle: float = 2.2
## B 组粒子按速度方向拉伸的系数
@export_range(0.0, 2.0, 0.05) var particle_b_stretch: float = 0.3
## B 组粒子循环生成的高度区间（X=最低 Y，Y=最高 Y）
@export var particle_b_y_range: Vector2 = Vector2(-0.5, 6.5)
