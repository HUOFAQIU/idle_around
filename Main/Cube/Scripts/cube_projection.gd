class_name CubeProjection
extends RefCounted
## 立方体屏幕投影工具。
##
## 把立方体本地包围盒的 8 个角投影成屏幕凸包；窗口穿透区域和
## CubeInputSurface 的 GUI 命中共用这份轮廓。

## 立方体本地包围盒半径，略大于本体 1.0，作为拖动和点击的容差
const HALF_EXTENT: float = 1.03


## 返回立方体在屏幕上的凸包；相机或朝向缺失时返回空数组
static func project_hull(
		camera: Camera3D,
		orientation: Node3D,
) -> PackedVector2Array:
	if camera == null or orientation == null:
		return PackedVector2Array()

	var screen_points := PackedVector2Array()
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var local_corner := Vector3(x_sign, y_sign, z_sign) * HALF_EXTENT
				var world_corner := orientation.global_transform * local_corner
				if camera.is_position_behind(world_corner):
					continue
				screen_points.append(camera.unproject_position(world_corner))

	if screen_points.size() < 3:
		return PackedVector2Array()
	return Geometry2D.convex_hull(screen_points)
