class_name NxGearMesh
extends RefCounted
## Procedural spur-gear mesh (extruded tooth profile along the Y axis).
##
## `pitch_radius` is the radius at which two gears mesh: two gears are in
## contact when the distance between their axes equals the sum of their pitch
## radii, and their speed ratio is the inverse ratio of their tooth counts.


static func build(teeth: int, pitch_radius: float, thickness: float = 0.3,
		tooth_depth: float = -1.0) -> ArrayMesh:
	teeth = maxi(teeth, 6)
	if tooth_depth <= 0.0:
		tooth_depth = TAU * pitch_radius / teeth * 0.55
	var outer := pitch_radius + tooth_depth * 0.5
	var inner := pitch_radius - tooth_depth * 0.5

	# Outline: for each tooth, root -> flank -> tip -> flank.
	var outline := PackedVector2Array()
	var step := TAU / teeth
	for i in teeth:
		var a := i * step
		outline.append(Vector2.from_angle(a) * inner)
		outline.append(Vector2.from_angle(a + step * 0.2) * inner)
		outline.append(Vector2.from_angle(a + step * 0.32) * outer)
		outline.append(Vector2.from_angle(a + step * 0.58) * outer)
		outline.append(Vector2.from_angle(a + step * 0.7) * inner)
	return extrude(outline, thickness)


## Extrudes a closed, counter-clockwise polygon (XZ plane) along +Y, centred.
static func extrude(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := thickness * 0.5
	var tris := Geometry2D.triangulate_polygon(outline)

	# Caps
	for cap in [1.0, -1.0]:
		var y: float = half * cap
		st.set_normal(Vector3(0, cap, 0))
		for t in range(0, tris.size(), 3):
			# Godot front faces are clockwise; the outline maps (x, y) -> (x, z).
			var order := [0, 1, 2] if cap > 0.0 else [0, 2, 1]
			for k in order:
				var v := outline[tris[t + k]]
				st.add_vertex(Vector3(v.x, y, v.y))

	# Sides
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var edge := b - a
		var normal := Vector3(edge.y, 0, -edge.x).normalized()
		st.set_normal(normal)
		var a_top := Vector3(a.x, half, a.y)
		var b_top := Vector3(b.x, half, b.y)
		var a_bot := Vector3(a.x, -half, a.y)
		var b_bot := Vector3(b.x, -half, b.y)
		for v in [a_bot, b_bot, b_top, a_bot, b_top, a_top]:
			st.add_vertex(v)
	return st.commit()
