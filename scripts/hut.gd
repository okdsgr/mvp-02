extends Node2D

enum HutState { NEUTRAL = 0, PLAYER = 1, ENEMY = 2 }

var state: int = HutState.NEUTRAL
var hut_type: int = 0
var hp: float = 80.0
var max_hp: float = 80.0
var hp_regen: float = 0.25
var spawn_cooldown: float = 3.0
var spawn_timer: float = 0.0
var captured_by: int = -1
var captured_unit_type: int = 0
var attacker_team: int = -1
var attack_pressure: Array = [0.0, 0.0]
var pressure_decay: float = 1.0

const BODY_COLORS = [
	Color(0.88, 0.85, 0.70),
	Color(0.2, 0.45, 0.95),
	Color(0.95, 0.2, 0.2),
]
const TYPE_ACCENT = [
	Color(0.4, 0.85, 1.0),
	Color(1.0, 0.6, 0.2),
	Color(0.5, 1.0, 0.4),
]
const UNIT_SPAWN_COLORS = [
	Color(0.2, 0.45, 0.95),
	Color(0.95, 0.2, 0.2),
]

func _ready() -> void:
	add_to_group("huts")

func _process(delta: float) -> void:
	if hp < max_hp:
		hp = min(hp + hp_regen * delta, max_hp)
	attack_pressure[0] = max(0.0, attack_pressure[0] - pressure_decay * delta)
	attack_pressure[1] = max(0.0, attack_pressure[1] - pressure_decay * delta)
	if attacker_team >= 0 and attack_pressure[attacker_team] <= 0.0:
		attacker_team = -1
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state != HutState.NEUTRAL and captured_by >= 0 and hp >= max_hp * 0.99:
		spawn_timer += delta
		if spawn_timer >= spawn_cooldown:
			spawn_timer = 0.0
			_spawn_unit()

func _spawn_unit() -> void:
	var main = get_tree().current_scene
	if not main:
		return
	var unit = Node2D.new()
	unit.set_script(load("res://scripts/units/unit.gd"))
	unit.position = global_position + Vector2(randf_range(-24, 24), 0)
	unit.team = captured_by
	unit.unit_type = captured_unit_type
	unit.call_deferred("setup", UNIT_SPAWN_COLORS[captured_by])
	main.add_child(unit)

func can_be_attacked_by(team: int) -> bool:
	if state == HutState.PLAYER and team == 0:
		return false
	if state == HutState.ENEMY and team == 1:
		return false
	if attacker_team >= 0 and attacker_team != team:
		return false
	return true

func take_damage(amount: float, att_team: int, att_unit_type: int) -> float:
	if not can_be_attacked_by(att_team):
		return 0.0
	attacker_team = att_team
	attack_pressure[att_team] = min(attack_pressure[att_team] + amount, 200.0)
	hp -= amount
	queue_redraw()
	if hp <= 0:
		return -hp
	return 0.0

func capture(team: int, unit_type: int, remaining_hp: float) -> void:
	captured_by = team
	captured_unit_type = unit_type
	state = HutState.PLAYER if team == 0 else HutState.ENEMY
	hp = max(remaining_hp, 1.0)
	max_hp = 80.0
	spawn_timer = 0.0
	attacker_team = -1
	attack_pressure = [0.0, 0.0]
	queue_redraw()
	var main = get_tree().current_scene
	if main.has_method("on_hut_captured"):
		main.on_hut_captured(self, team)

func _get_my_team() -> int:
	var main = get_tree().current_scene
	if main and "my_team" in main:
		return main.my_team
	return 0

func _draw() -> void:
	# 赤チームのcanvas_transform(180度回転)を打ち消す
	if _get_my_team() == 1:
		draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)

	var body_color = BODY_COLORS[state]
	var accent_idx = clamp(hut_type if state == HutState.NEUTRAL else captured_unit_type, 0, 2)
	var accent = TYPE_ACCENT[accent_idx]

	draw_rect(Rect2(-22, -10, 44, 30), body_color)
	var roof = PackedVector2Array([Vector2(-26, -10), Vector2(0, -34), Vector2(26, -10)])
	draw_colored_polygon(roof, body_color)
	draw_line(Vector2(-22, -10), Vector2(22, -10), accent, 3.0)
	if state != HutState.NEUTRAL:
		draw_circle(Vector2(0, 8), 5, accent)

	var radius = 28.0
	var center = Vector2(0, -52)
	draw_circle(center, radius, Color(0.08, 0.08, 0.08, 0.75))
	var hp_ratio = clamp(hp / max_hp, 0, 1)
	var hp_color: Color
	match state:
		HutState.NEUTRAL: hp_color = Color(0.88, 0.82, 0.3)
		HutState.PLAYER:  hp_color = Color(0.25, 0.55, 1.0)
		HutState.ENEMY:   hp_color = Color(1.0, 0.3, 0.3)
	if hp_ratio > 0.01:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 48, hp_color, 6.0)

	var blue_r = clamp(attack_pressure[0] / 200.0, 0, 1)
	var red_r  = clamp(attack_pressure[1] / 200.0, 0, 1)
	if blue_r > 0.01:
		draw_arc(center, radius + 5, -PI*0.5, -PI*0.5 + TAU*blue_r, 32, Color(0.3,0.6,1.0,0.85), 3.0)
	if red_r > 0.01:
		var sa = -PI*0.5 + TAU*blue_r
		draw_arc(center, radius + 5, sa, sa + TAU*red_r, 32, Color(1.0,0.3,0.3,0.85), 3.0)
