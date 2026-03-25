extends Node2D

enum Team { PLAYER = 0, ENEMY = 1, NEUTRAL = 2 }

var team: int = Team.PLAYER
var unit_type: int = 0
var hp: float = 50.0
var max_hp: float = 50.0
var attack_power: float = 8.0
var move_speed: float = 20.0
var attack_range: float = 84.0
var melee_range: float = 18.0
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var _body_color: Color = Color(0.2, 0.5, 1.0)
var _locked_unit = null

const CASTLE_ATTACK_POWER = 5.0
const ENEMY_CASTLE_Y = 120.0
const PLAYER_CASTLE_Y = 740.0

func _ready() -> void:
	add_to_group("units")

func setup(color: Color) -> void:
	_body_color = color
	queue_redraw()

func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)

	if _locked_unit != null and not is_instance_valid(_locked_unit):
		_locked_unit = null

	if _locked_unit == null:
		_locked_unit = _scan_for_unit()

	if _locked_unit != null:
		var dist = global_position.distance_to(_locked_unit.global_position)
		if dist <= melee_range:
			if attack_timer <= 0.0:
				_locked_unit.take_damage(attack_power)
				attack_timer = attack_cooldown
		else:
			var dir = (_locked_unit.global_position - global_position).normalized()
			global_position += dir * move_speed * delta
	else:
		_march_to_castle(delta)
		_attack_castle()

	# 城壁を通り抜けないようにクランプ
	if team == Team.PLAYER:
		global_position.y = max(global_position.y, ENEMY_CASTLE_Y)
	elif team == Team.ENEMY:
		global_position.y = min(global_position.y, PLAYER_CASTLE_Y)

	queue_redraw()

func _scan_for_unit():
	var best = null
	var best_dist = attack_range
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or u.team == team:
			continue
		var d = global_position.distance_to(u.global_position)
		if d <= best_dist:
			best_dist = d
			best = u
	return best

func _march_to_castle(delta: float) -> void:
	if team == Team.PLAYER:
		global_position.y -= move_speed * delta
	elif team == Team.ENEMY:
		global_position.y += move_speed * delta

func _attack_castle() -> void:
	if attack_timer > 0.0:
		return
	var main = get_tree().current_scene
	if team == Team.PLAYER and global_position.y <= ENEMY_CASTLE_Y:
		if main.has_method("take_enemy_damage"):
			main.take_enemy_damage(CASTLE_ATTACK_POWER)
			take_damage(CASTLE_ATTACK_POWER)
			attack_timer = attack_cooldown
	elif team == Team.ENEMY and global_position.y >= PLAYER_CASTLE_Y:
		if main.has_method("take_player_damage"):
			main.take_player_damage(CASTLE_ATTACK_POWER)
			take_damage(CASTLE_ATTACK_POWER)
			attack_timer = attack_cooldown

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-14, -14, 28, 28), _body_color)
	draw_rect(Rect2(-14, -22, 28, 5), Color(0.25, 0.0, 0.0))
	draw_rect(Rect2(-14, -22, 28.0 * clamp(hp / max_hp, 0, 1), 5), Color(0.15, 0.9, 0.15))

	if _locked_unit == null:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 48, Color(1, 1, 1, 0.2), 1.0)
	else:
		if not is_instance_valid(_locked_unit):
			return
		var local_t = _locked_unit.global_position - global_position
		var dist = local_t.length()
		if dist < 2.0:
			return
		var dir = local_t.normalized()
		var arrow_len = min(dist - 16.0, 70.0)
		if arrow_len < 4.0:
			return
		var s = dir * 16.0
		var e = s + dir * arrow_len
		var perp = Vector2(-dir.y, dir.x)
		draw_line(s, e, Color(1, 1, 0.3, 0.28), 1.0)
		draw_line(e, e - dir * 5 + perp * 4, Color(1, 1, 0.3, 0.28), 1.0)
		draw_line(e, e - dir * 5 - perp * 4, Color(1, 1, 0.3, 0.28), 1.0)
