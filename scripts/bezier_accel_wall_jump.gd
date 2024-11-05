extends Node

@onready var p_0: Vector2 = $p_0.position
@onready var p_1: Vector2 = $p_1.position
@onready var p_2: Vector2 = $p_2.position
@onready var p_3: Vector2 = $p_3.position

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float):
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var q2 = p2.lerp(p3, t)

	var r0 = q0.lerp(q1, t)
	var r1 = q1.lerp(q2, t)

	var s = r0.lerp(r1, t)
	return s
	
func acceleration(t : float) -> float:
	var p_0_c = abs(p_0); p_0_c /= 64
	var p_1_c = abs(p_1); p_1_c /= 64
	var p_2_c = abs(p_2); p_2_c /= 64
	var p_3_c = abs(p_3); p_3_c /= 64
	return _cubic_bezier(p_0_c, p_1_c, p_2_c, p_3_c, t).y
