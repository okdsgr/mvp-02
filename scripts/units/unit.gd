extends Node2D

enum Team { PLAYER = 0, ENEMY = 1 }
enum UnitState { SCOUT, LOCKED, CASTLE }

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
var state: int = UnitState.SCOUT
var _locked_target = null

# world座標での城壁Y（unit.gdは世界座標で動く）
const ENEMY_CASTLE_Y = 214.0   # team0の敵城壁（上）
const PLAYER_CASTLE_Y = 746.0  # team0の自城壁（下）
const CASTLE_ATTACK_POWER = 5.0
const HUT_ATTACK_POWER = 5.0

func _ready() -> void:
	add_to_group("units")

func setup(color: Color) -> void:
	_body_color = color
	queue_redraw()

func _get_my_team() -> int:
	var main = get_tree().current_scene
	if main and "my_team" in main:
		return main.my_team
	return 0

func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)
	match state:
		UnitState.SCOUT:  _do_scout(delta)
		UnitState.LOCKED: _do_locked(delta)
		UnitState.CASTLE: _do_castle()
	if team == Team.PLAYER:
		global_position.y = max(global_position.y, ENEMY_CASTLE_Y)
	else:
		global_position.y = min(global_position.y, PLAYER_CASTLE_Y)
	queue_redraw()

func _do_scout(delta: float) -> void:
	_locked_target = _scan_in_range()
	if _locked_target != null:
		state = UnitState.LOCKED
		return
	_march_forward(delta)
	if team == Team.PLAYER and global_position.y <= ENEMY_CASTLE_Y + 2:
		state = UnitState.CASTLE
	elif team == Team.ENEMY and global_position.y >= PLAYER_CASTLE_Y - 2:
		state = UnitState.CASTLE

func _do_locked(delta: float) -> void:
	if _locked_target == null or not is_instance_valid(_locked_target):
		_locked_target = _scan_in_range()
		if _locked_target == null:
			state = UnitState.SCOUT
		return
	if _locked_target.is_in_group("huts") and not _locked_target.can_be_attacked_by(team):
		_locked_target = _scan_in_range()
		if _locked_target == null:
			state = UnitState.SCOUT
		return
	var dist = global_position.distance_to(_locked_target.global_position)
	if dist <= melee_range:
		if attack_timer <= 0.0:
			_do_attack(_locked_target)
			attack_timer = attack_cooldown
	else:
		global_position += (_locked_target.global_position - global_position).normalized() * move_speed * delta

func _do_castle() -> void:
	if attack_timer > 0.0:
		return
	var main = get_tree().current_scene
	if not main:
		return
	attack_timer = attack_cooldown
	if team == Team.PLAYER:
		main.take_enemy_damage(CASTLE_ATTACK_POWER)
		_self_damage(CASTLE_ATTACK_POWER)
	else:
		main.take_player_damage(CASTLE_ATTACK_POWER)
		_self_damage(CASTLE_ATTACK_POWER)

func _scan_in_range():
	var best = null
	var best_dist = attack_range
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or u.team == team:
			continue
		var d = global_position.distance_to(u.global_position)
		if d <= best_dist:
			best_dist = d
			best = u
	for h in get_tree().get_nodes_in_group("huts"):
		if not h.can_be_attacked_by(team):
			continue
		var d = global_position.distance_to(h.global_position)
		if d <= best_dist:
			best_dist = d
			best = h
	return best

func _march_forward(delta: float) -> void:
	if team == Team.PLAYER:
		global_position.y -= move_speed * delta
	else:
		global_position.y += move_speed * delta

func _do_attack(target: Node2D) -> void:
	if target.is_in_group("huts"):
		var excess = target.take_damage(HUT_ATTACK_POWER, team, unit_type)
		if excess > 0:
			var remaining = hp - HUT_ATTACK_POWER
			target.capture(team, unit_type, max(remaining, 0.1))
			_self_damage(HUT_ATTACK_POWER)
			if is_inside_tree():
				_locked_target = _scan_in_range()
				state = UnitState.LOCKED if _locked_target != null else UnitState.SCOUT
		else:
			_self_damage(HUT_ATTACK_POWER)
	elif target.has_method("take_damage"):
		target.take_damage(attack_power)

func _self_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0:
		queue_free()

func take_damage(amount: float) -> void:
	_self_damage(amount)

func _draw() -> void:
	# 赤チームはcanvas_transformで180度回転されているので逆回転して正立表示
	if _get_my_team() == 1:
		draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)

	draw_rect(Rect2(-14, -14, 28, 28), _body_color)
	draw_rect(Rect2(-14, -22, 28, 5), Color(0.25, 0.0, 0.0))
	draw_rect(Rect2(-14, -22, 28.0 * clamp(hp / max_hp, 0, 1), 5), Color(0.15, 0.9, 0.15))

	if state == UnitState.LOCKED and _locked_target != null and is_instance_valid(_locked_target):
		# world座標でのターゲット方向
		var world_dir = _locked_target.global_position - global_position
		# draw_set_transform(PI)で描画空間が反転しているので方向を反転
		# 自分が青なら通常、赤なら逆
		if _get_my_team() == 1:
			world_dir = -world_dir
		var dist = world_dir.length()
		if dist >= 2.0:
			var dir = world_dir.normalized()
			var arrow_len = min(dist - 16.0, 70.0)
			if arrow_len >= 4.0:
				var s = dir * 16.0
				var e = s + dir * arrow_len
				var perp = Vector2(-dir.y, dir.x)
				draw_line(s, e, Color(1, 1, 0.3, 0.28), 1.0)
				draw_line(e, e - dir * 5 + perp * 4, Color(1, 1, 0.3, 0.28), 1.0)
				draw_line(e, e - dir * 5 - perp * 4, Color(1, 1, 0.3, 0.28), 1.0)
	elif state == UnitState.SCOUT:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 48, Color(1, 1, 1, 0.18), 1.0)
