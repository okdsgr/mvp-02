extends Node2D

const MANA_MAX = 10.0
const FLASH_DURATION = 0.25
const HUT_FIELD_RADIUS = 120.0
const UNIT_COSTS = [2, 3, 3, 4]
const UNIT_COLORS_BY_TEAM = [
	[Color(0.2, 0.4, 0.9), Color(0.1, 0.7, 0.9), Color(0.2, 0.5, 1.0), Color(0.3, 0.2, 0.9)],
	[Color(0.9, 0.2, 0.2), Color(0.9, 0.5, 0.1), Color(0.9, 0.2, 0.5), Color(0.7, 0.1, 0.1)]
]
const CARD_ACCENT = [Color(0.2,0.5,1.0), Color(0.2,0.8,0.3), Color(0.1,0.8,0.8), Color(0.6,0.2,0.9)]

var my_team: int = 0
var is_pvp: bool = false
var mana: float = 5.0
var elapsed_time: float = 0.0
var player_hp: float = 500.0
var enemy_hp: float = 500.0
var game_over: bool = false
var selected_card: int = -1
var drag_card: int = -1
var player_flash_timer: float = 0.0
var enemy_flash_timer: float = 0.0
var captured_huts: Array = []
var card_rects: Array = []
var mana_notify_timer: float = 0.0
var mana_notify_flash: float = 0.0
const NOTIFY_DURATION = 3.0
var last_mana_mult: int = 1
var enemy_mana: float = 3.0
var enemy_elapsed: float = 0.0
const ENEMY_MANA_MAX = 10.0
const ENEMY_SPAWN_COST = 3
var vp_w: float = 540.0
var vp_h: float = 960.0

@onready var mana_bar = $UI/ManaPannel/ManaBar
@onready var mana_label = $UI/ManaPannel/ManaLabel
@onready var player_hp_bar = $UI/PlayerCastle/HPBar
@onready var enemy_hp_bar = $UI/EnemyCastle/HPBar
@onready var player_castle_bg = $UI/PlayerCastle/BG
@onready var enemy_castle_bg = $UI/EnemyCastle/BG

func _ready() -> void:
	var vp = get_viewport().get_visible_rect().size
	vp_w = vp.x
	vp_h = vp.y
	for i in range(4):
		card_rects.append(Rect2(10 + i * 130, vp_h - 86, 108, 80))

	is_pvp = multiplayer.get_peers().size() > 0
	if is_pvp:
		my_team = 0 if multiplayer.is_server() else 1
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("main: is_pvp=", is_pvp, " my_team=", my_team)

	# 赤チーム：180度回転（点対称）
	# Transform2D の列ベクトル形式：
	# column 0 = x軸方向 = (-1, 0)
	# column 1 = y軸方向 = (0, -1)
	# origin = (vp_w, vp_h)
	if my_team == 1:
		var ct = Transform2D()
		ct[0] = Vector2(-1.0, 0.0)
		ct[1] = Vector2(0.0, -1.0)
		ct[2] = Vector2(vp_w, vp_h)
		get_viewport().canvas_transform = ct
		print("canvas_transform set for red team")

	if not is_pvp or my_team == 0:
		_spawn_and_sync_huts()

func _on_peer_disconnected(_id: int) -> void:
	$UI/GameOverLabel.text = "相手が切断しました"
	$UI/GameOverLabel.visible = true

func _world_to_screen(wp: Vector2) -> Vector2:
	if my_team == 0:
		return wp
	return Vector2(vp_w - wp.x, vp_h - wp.y)

func _screen_to_world(sp: Vector2) -> Vector2:
	if my_team == 0:
		return sp
	return Vector2(vp_w - sp.x, vp_h - sp.y)

func _spawn_and_sync_huts() -> void:
	var cx = 270.0
	var cy = 480.0
	var positions: Array = [Vector2(cx, cy)]
	var o1 = Vector2(randf_range(120, 210), randf_range(-160, 160))
	var o2 = Vector2(randf_range(120, 210), randf_range(-160, 160))
	if abs(o2.y - o1.y) < 60:
		o2.y = o1.y * -1.0 + randf_range(80, 120)
	positions.append(Vector2(cx + o1.x, cy + o1.y))
	positions.append(Vector2(cx - o1.x, cy - o1.y))
	positions.append(Vector2(cx + o2.x, cy + o2.y))
	positions.append(Vector2(cx - o2.x, cy - o2.y))
	for i in range(5):
		if is_pvp:
			_spawn_hut_rpc.rpc(positions[i], i % 3)
		else:
			_do_spawn_hut(positions[i], i % 3)

@rpc("authority", "call_local", "reliable")
func _spawn_hut_rpc(pos: Vector2, htype: int) -> void:
	_do_spawn_hut(pos, htype)

func _do_spawn_hut(pos: Vector2, htype: int) -> void:
	var hut = Node2D.new()
	hut.set_script(load("res://scripts/hut.gd"))
	hut.position = pos
	hut.hut_type = htype
	add_child(hut)

func on_hut_captured(hut: Node2D, team: int) -> void:
	if not captured_huts.has(hut):
		captured_huts.append(hut)
	queue_redraw()

func _get_card_at(pos: Vector2) -> int:
	for i in range(card_rects.size()):
		if card_rects[i].has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos = event.position
	if event.pressed:
		var ci = _get_card_at(pos)
		if ci >= 0:
			if mana >= UNIT_COSTS[ci]:
				selected_card = ci
				drag_card = ci
			return
		if selected_card >= 0 and drag_card < 0:
			if _is_valid_deploy_pos(pos):
				_try_spawn_unit(_screen_to_world(pos), selected_card)
				selected_card = -1
	else:
		if drag_card >= 0:
			var ci2 = _get_card_at(pos)
			if ci2 < 0 and _is_valid_deploy_pos(pos):
				_try_spawn_unit(_screen_to_world(pos), drag_card)
				selected_card = -1
			drag_card = -1

func _is_valid_deploy_pos(sp: Vector2) -> bool:
	if sp.y >= vp_h * 0.60 and sp.y <= vp_h * 0.89:
		return true
	for hut in captured_huts:
		if not is_instance_valid(hut):
			continue
		if hut.captured_by != my_team:
			continue
		if sp.distance_to(_world_to_screen(hut.global_position)) <= HUT_FIELD_RADIUS:
			return true
	return false

func _try_spawn_unit(wp: Vector2, ci: int) -> void:
	if not spend_mana(UNIT_COSTS[ci]):
		return
	if is_pvp:
		_spawn_unit_rpc.rpc(wp, ci, my_team)
	else:
		_do_spawn_unit(wp, ci, 0)

@rpc("any_peer", "call_local", "reliable")
func _spawn_unit_rpc(wp: Vector2, ci: int, team: int) -> void:
	_do_spawn_unit(wp, ci, team)

func _do_spawn_unit(wp: Vector2, ci: int, team: int) -> void:
	var unit = Node2D.new()
	unit.set_script(load("res://scripts/units/unit.gd"))
	unit.position = wp
	unit.team = team
	unit.unit_type = ci
	unit.call_deferred("setup", UNIT_COLORS_BY_TEAM[team][ci])
	add_child(unit)

func take_player_damage(amount: float) -> void:
	if is_pvp:
		_sync_damage.rpc(0, amount)
	else:
		_apply_damage(0, amount)

func take_enemy_damage(amount: float) -> void:
	if is_pvp:
		_sync_damage.rpc(1, amount)
	else:
		_apply_damage(1, amount)

@rpc("any_peer", "call_local", "reliable")
func _sync_damage(side: int, amount: float) -> void:
	_apply_damage(side, amount)

func _apply_damage(side: int, amount: float) -> void:
	if side == 0:
		player_hp = max(0.0, player_hp - amount)
		player_flash_timer = FLASH_DURATION
		if player_hp <= 0.0:
			_end_game(my_team != 0)
	else:
		enemy_hp = max(0.0, enemy_hp - amount)
		enemy_flash_timer = FLASH_DURATION
		if enemy_hp <= 0.0:
			_end_game(my_team != 1)

func _get_mana_mult(t: float) -> int:
	if t >= 60:
		return 8
	elif t >= 45:
		return 4
	elif t >= 30:
		return 3
	elif t >= 15:
		return 2
	return 1

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed_time += delta
	mana = min(mana + 0.1 * _get_mana_mult(elapsed_time) * delta, MANA_MAX)
	var cm = _get_mana_mult(elapsed_time)
	if cm != last_mana_mult:
		last_mana_mult = cm
		mana_notify_timer = NOTIFY_DURATION
		mana_notify_flash = 0.0
	if mana_notify_timer > 0.0:
		mana_notify_timer -= delta
		mana_notify_flash += delta * 8.0
	if not is_pvp:
		enemy_elapsed += delta
		enemy_mana = min(enemy_mana + 0.1 * _get_mana_mult(enemy_elapsed) * delta, ENEMY_MANA_MAX)
		if enemy_mana >= ENEMY_SPAWN_COST:
			enemy_mana -= ENEMY_SPAWN_COST
			_spawn_com_unit()
	_update_ui()
	_update_flash(delta)
	queue_redraw()

func _spawn_com_unit() -> void:
	var unit = Node2D.new()
	unit.set_script(load("res://scripts/units/unit.gd"))
	unit.position = Vector2(randf_range(60, 480), 180)
	unit.team = 1
	unit.unit_type = randi() % 4
	unit.call_deferred("setup", Color(1.0, 0.25, 0.25))
	add_child(unit)

func _update_ui() -> void:
	var my_hp = player_hp if my_team == 0 else enemy_hp
	var opp_hp = enemy_hp if my_team == 0 else player_hp
	mana_bar.value = mana
	mana_label.text = str(int(mana)) + " / " + str(int(MANA_MAX))
	player_hp_bar.value = my_hp
	enemy_hp_bar.value = opp_hp

func _update_flash(delta: float) -> void:
	if player_flash_timer > 0.0:
		player_flash_timer -= delta
		var t = clamp(player_flash_timer / FLASH_DURATION, 0.0, 1.0)
		player_castle_bg.color = Color(0.1, 0.2, 0.5).lerp(Color(1.0, 0.1, 0.1), t)
	else:
		player_castle_bg.color = Color(0.1, 0.2, 0.5)
	if enemy_flash_timer > 0.0:
		enemy_flash_timer -= delta
		var t = clamp(enemy_flash_timer / FLASH_DURATION, 0.0, 1.0)
		enemy_castle_bg.color = Color(0.5, 0.1, 0.1).lerp(Color(1.0, 0.9, 0.1), t)
	else:
		enemy_castle_bg.color = Color(0.5, 0.1, 0.1)

func spend_mana(cost: float) -> bool:
	if mana >= cost:
		mana -= cost
		return true
	return false

func _end_game(win: bool) -> void:
	game_over = true
	for u in get_tree().get_nodes_in_group("units"):
		u.set_physics_process(false)
		u.set_process(false)
	for h in get_tree().get_nodes_in_group("huts"):
		h.set_physics_process(false)
	var label = $UI/GameOverLabel
	label.text = "VICTORY!\n\nRキーでリスタート" if win else "GAME OVER\n\nRキーでリスタート"
	label.modulate = Color(0.2, 0.9, 0.2) if win else Color(0.9, 0.2, 0.2)
	label.visible = true

func _draw() -> void:
	var mc = Color(0.1, 0.2, 0.5, 0.15) if my_team == 0 else Color(0.5, 0.1, 0.1, 0.15)
	draw_rect(Rect2(0, vp_h * 0.60, vp_w, vp_h * 0.29), mc)
	draw_rect(Rect2(0, vp_h - 92, vp_w, 92), Color(0.08, 0.08, 0.12))
	draw_rect(Rect2(40, vp_h - 98, vp_w - 80, 6), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(40, vp_h - 98, (vp_w - 80) * (mana / MANA_MAX), 6), Color(0.3, 0.6, 1.0))
	for i in range(4):
		var r = card_rects[i]
		var is_sel = (i == selected_card or i == drag_card)
		var can_afford = mana >= UNIT_COSTS[i]
		var bg: Color
		if is_sel:
			bg = Color(0.5, 0.5, 0.75)
		elif can_afford:
			bg = CARD_ACCENT[i].darkened(0.55)
		else:
			bg = Color(0.12, 0.12, 0.16)
		draw_rect(r, bg)
		var sc = CARD_ACCENT[i] if can_afford else Color(0.3, 0.3, 0.3)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), sc)
		if is_sel:
			draw_rect(r, Color(1, 1, 0.5, 0.22))
		if not can_afford:
			var cx = r.position.x + r.size.x * 0.5
			var cy = r.position.y + r.size.y * 0.5
			draw_line(Vector2(cx - 10, cy - 10), Vector2(cx + 10, cy + 10), Color(0.7, 0.2, 0.2, 0.7), 2.0)
			draw_line(Vector2(cx + 10, cy - 10), Vector2(cx - 10, cy + 10), Color(0.7, 0.2, 0.2, 0.7), 2.0)
	if mana_notify_timer > 0.0:
		var alpha = (sin(mana_notify_flash) * 0.5 + 0.5) * clamp(mana_notify_timer / 0.5, 0.0, 1.0)
		var nc = Color(1.0, 0.85, 0.2, alpha)
		var nw = 220.0
		var nh = 48.0
		var nx = vp_w * 0.5 - 110.0
		var ny = vp_h * 0.45
		draw_rect(Rect2(nx, ny, nw, nh), Color(0, 0, 0, alpha * 0.6))
		draw_rect(Rect2(nx, ny, nw, 2), nc)
		draw_rect(Rect2(nx, ny + nh - 2, nw, 2), nc)
		draw_rect(Rect2(nx, ny, 2, nh), nc)
		draw_rect(Rect2(nx + nw - 2, ny, 2, nh), nc)
	for hut in captured_huts:
		if not is_instance_valid(hut):
			continue
		var hs = _world_to_screen(hut.global_position)
		var c = Color(0.2, 0.4, 0.9, 0.1) if hut.captured_by == 0 else Color(0.9, 0.2, 0.2, 0.1)
		var b = Color(0.2, 0.4, 0.9, 0.25) if hut.captured_by == 0 else Color(0.9, 0.2, 0.2, 0.25)
		draw_circle(hs, HUT_FIELD_RADIUS, c)
		draw_arc(hs, HUT_FIELD_RADIUS, 0, TAU, 48, b, 1.5)
