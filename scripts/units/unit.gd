extends Node2D

enum Team { PLAYER = 0, ENEMY = 1 }
enum UnitState { SCOUT, LOCKED, CASTLE }

const UNIT_DEFS = {
	0: "03_ladyb",
	1: "02_pillb",
	2: "06_hornet",
	3: "09_mantis",
}

const UNIT_SCALES = {
	0: 0.21 * 0.75,
	1: 0.21,
	2: 0.21 * 2.0,
	3: 0.21 * 2.5,
}

# unit_type → [HP, 攻撃力, 移動速度]
const UNIT_STATS = {
	0: [40.0,   8.0,  25.0],  # テントウムシ
	1: [600.0,  16.0, 10.0],  # ダンゴムシ
	2: [150.0,  20.0, 25.0],  # スズメバチ
	3: [300.0,  30.0, 15.0],  # カマキリ
}

const ANIM_FPS = 6.0

var team: int = Team.PLAYER
var unit_type: int = 0
var hp: float = 25.0
var max_hp: float = 25.0
var attack_power: float = 4.0
var move_speed: float = 25.0
var attack_range: float = 84.0
var melee_range: float = 18.0
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var state: int = UnitState.SCOUT
var _locked_target = null
var _sprite: AnimatedSprite2D = null
var _body_color: Color = Color(0.2, 0.5, 1.0)

const ENEMY_CASTLE_Y = 200.0
const PLAYER_CASTLE_Y = 760.0
const CASTLE_ATTACK_POWER = 5.0
const HUT_ATTACK_POWER = 5.0

func _ready() -> void:
	add_to_group("units")

func _get_my_team() -> int:
	var main = get_tree().current_scene
	if main and "my_team" in main:
		return main.my_team
	return 0

func setup(color: Color) -> void:
	_body_color = color
	var stats = UNIT_STATS.get(unit_type, [50.0, 8.0, 20.0])
	hp           = stats[0]
	max_hp       = stats[0]
	attack_power = stats[1]
	move_speed   = stats[2]
	if UNIT_DEFS.has(unit_type):
		_setup_sprite()
	queue_redraw()

func _setup_sprite() -> void:
	var folder = UNIT_DEFS[unit_type]
	var color_str = "blue" if team == 0 else "red"
	var prefix = folder + "/" + folder + "_" + color_str

	var sf = SpriteFrames.new()
	sf.remove_animation("default")

	var dirs = ["down", "up", "rup", "rdown"]
	var actions = ["walk", "attack"]
	for action in actions:
		for dir in dirs:
			var aname = action + "_" + dir
			sf.add_animation(aname)
			sf.set_animation_loop(aname, true)
			sf.set_animation_speed(aname, ANIM_FPS)
			for f in range(2):
				var path = "res://png/" + prefix + "_" + dir + "_" + action + "_" + str(f) + ".png"
				var tex = load(path)
				if tex:
					sf.add_frame(aname, tex)

	var sc = UNIT_SCALES.get(unit_type, 0.21)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.scale = Vector2(sc, sc)
	if _get_my_team() == 1:
		_sprite.rotation = PI
	add_child(_sprite)
	_play_anim("walk", Vector2(0.0, -1.0) if team == 0 else Vector2(0.0, 1.0))

func _play_anim(action: String, world_dir: Vector2) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var vis_dir = world_dir if _get_my_team() == 0 else -world_dir
	var ax = abs(vis_dir.x)
	var ay = abs(vis_dir.y)
	var dir_str: String
	var flip: bool = false
	if ax < ay * 0.5:
		dir_str = "down" if vis_dir.y > 0 else "up"
	elif vis_dir.y <= 0:
		dir_str = "rup"
		flip = vis_dir.x < 0
	else:
		dir_str = "rdown"
		flip = vis_dir.x < 0
	var aname = action + "_" + dir_str
	if not _sprite.sprite_frames.has_animation(aname):
		return
	if _sprite.animation != aname:
		_sprite.play(aname)
	_sprite.flip_h = flip

func _update_animation() -> void:
	if _sprite == null:
		return
	var is_attack = (state == UnitState.LOCKED or state == UnitState.CASTLE)
	var action = "attack" if is_attack else "walk"
	var dir: Vector2
	if is_attack and _locked_target != null and is_instance_valid(_locked_target):
		dir = (_locked_target.global_position - global_position).normalized()
	else:
		dir = Vector2(0.0, -1.0) if team == Team.PLAYER else Vector2(0.0, 1.0)
	_play_anim(action, dir)

func _at_castle() -> bool:
	if team == Team.PLAYER:
		return global_position.y <= ENEMY_CASTLE_Y
	else:
		return global_position.y >= PLAYER_CASTLE_Y

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
	_update_animation()
	queue_redraw()

func _do_scout(delta: float) -> void:
	_locked_target = _scan_in_range()
	if _locked_target != null:
		state = UnitState.LOCKED
		return
	_march_forward(delta)
	if _at_castle():
		state = UnitState.CASTLE

func _do_locked(delta: float) -> void:
	if _locked_target == null or not is_instance_valid(_locked_target):
		_locked_target = _scan_in_range()
		if _locked_target == null:
			if _at_castle():
				state = UnitState.CASTLE
			else:
				state = UnitState.SCOUT
		return
	if _locked_target.is_in_group("huts") and not _locked_target.can_be_attacked_by(team):
		_locked_target = _scan_in_range()
		if _locked_target == null:
			if _at_castle():
				state = UnitState.CASTLE
			else:
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
	if _get_my_team() == 1:
		draw_set_transform(Vector2.ZERO, PI, Vector2.ONE)
	if _sprite == null:
		draw_rect(Rect2(-14, -14, 28, 28), _body_color)
	var bar_w = 28.0
	var bar_h = 5.0
	draw_rect(Rect2(-bar_w * 0.5, -22.0, bar_w, bar_h), Color(0.25, 0.0, 0.0))
	draw_rect(Rect2(-bar_w * 0.5, -22.0, bar_w * clamp(hp / max_hp, 0.0, 1.0), bar_h), Color(0.15, 0.9, 0.15))
	if state == UnitState.SCOUT:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.12), 1.0)
