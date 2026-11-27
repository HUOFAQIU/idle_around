@tool
class_name UnitAnimConfig
extends Resource

@export_group("节奏（CPU）")
## 移动速度换算为动作相位的倍率
@export_range(0.5, 10.0, 0.05) var move_phase_scale: float = 3.8
## 攻击动作播放速率（越大挥击/扑咬越快）
@export_range(0.4, 6.0, 0.05) var attack_speed: float = 1.95
## 攻击伤害判定的归一化时机（0=起手，1=收招）
@export_range(0.1, 0.9, 0.01) var attack_impact_u: float = 0.52
## 受击闪白每秒衰减速率
@export_range(1.0, 15.0, 0.1) var flash_decay: float = 5.0

@export_group("变形（GPU Shader）")
## 移动摆动/游动幅度倍率
@export_range(0.0, 3.0, 0.05) var move_amp: float = 1.0
## 移动波形频率倍率（如蛇身波浪密疏）
@export_range(0.2, 3.0, 0.05) var move_freq: float = 1.0
## 待机呼吸与摇摆幅度倍率
@export_range(0.0, 3.0, 0.05) var idle_sway: float = 1.0
## 攻击蓄力阶段结束点（0..attack_strike）
@export_range(0.1, 0.6, 0.01) var attack_windup: float = 0.40
## 攻击爆发前扑结束点（attack_windup..0.95）
@export_range(0.3, 0.95, 0.01) var attack_strike: float = 0.65
## 攻击前扑/挥击幅度倍率
@export_range(0.0, 3.0, 0.05) var attack_lunge: float = 1.0
## 受击闪光颜色
@export var flash_color: Color = Color(1.0, 0.8, 0.55, 1.0)
## 受击闪光自发光强度
@export_range(0.0, 2.5, 0.05) var flash_intensity: float = 0.55


func apply_to_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	var windup := clampf(attack_windup, 0.05, 0.8)
	var strike := clampf(attack_strike, windup + 0.05, 0.98)
	mat.set_shader_parameter("u_anim_move", Vector3(move_amp, move_freq, idle_sway))
	mat.set_shader_parameter("u_anim_atk", Vector3(windup, strike, attack_lunge))
	mat.set_shader_parameter(
		"u_flash_style",
		Vector4(flash_color.r, flash_color.g, flash_color.b, flash_intensity)
	)
