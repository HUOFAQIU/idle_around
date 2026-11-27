class_name CubeProjection
extends RefCounted

const HALF_EXTENT: float = 1.03


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
