extends Node2D

const MANA_MAX = 10.0
const MANA_REGEN_START = 1.0
const MANA_REGEN_MAX = 3.0
const FLASH_DURATION = 0.25

const UNIT_COSTS = [2, 3, 3, 4]
const UNIT_COLORS = [
	Color(0.2, 0.4, 0.9),
	Color(0.2, 0.7, 0.3),
	Color(0.15, 0.75, 0.8),
	Color(0.5, 0.2, 0.85)
]

var mana: float = 5.0
var elapsed_time: float = 0.0
var player_hp: float = 500.0
var enemy_hp: float = 500.0
var game_over: bool = false
var selected_card: int = -1
var dragging_card: int = -1
var enemy_spawn_timer: float = 0.0
var player_flash_timer: float = 0.0
var enemy_flash_timer: float = 0.0

@onready var mana_bar = $UI/ManaPannel/ManaBar
@onready var mana_label = $UI/ManaPannel/ManaLabel
@onready var player_hp_bar = $UI/PlayerCastle/HPBar
@onready var enemy_hp_bar = $UI/EnemyCastle/HPBar
@onready var player_castle_bg = $UI/PlayerCastle/BG
@onready var enemy_castle_bg = $UI/EnemyCastle/BG
@onready var card_panel = $UI/CardPanel

func _ready() -> void:
	for i in range(4):
		var card = card_panel.get_node("Card" + str(i))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if mana >= UNIT_COSTS[index]:
				selected_card = index
				dragging_card = index
				_highlight_card(index)
		else:
			dragging_card = -1

func _highlight_card(index: int) -> void:
	for i in range(4):
		var card = card_panel.get_node("Card" + str(i))
		card.color = Color(0.45, 0.45, 0.65) if i == index else Color(0.22, 0.22, 0.32)

func _input(event: InputEvent) -> void:
	if game_over:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var zone_top = vp_size.y * 0.60
	var zone_bottom = vp_size.y * 0.89

	# ドラッグ中に自陣でリリース
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_card >= 0:
			var pos = event.position
			if pos.y >= zone_top and pos.y <= zone_bottom:
				_spawn_unit(pos, dragging_card)
			dragging_card = -1
			selected_card = -1
			_highlight_card(-1)

	# タップで選択後フィールドクリック
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_card >= 0 and dragging_card < 0:
			var pos = event.position
			if pos.y >= zone_top and pos.y <= zone_bottom:
				_spawn_unit(pos, selected_card)
				selected_card = -1
				_highlight_card(-1)

func _make_unit(pos: Vector2, team: int, color: Color) -> Node2D:
	var unit = Node2D.new()
	unit.set_script(load("res://scripts/units/unit.gd"))
	unit.position = pos
	unit.team = team
	unit.call_deferred("setup", color)
	return unit

func _spawn_unit(pos: Vector2, card_index: int) -> void:
	if not spend_mana(UNIT_COSTS[card_index]):
		return
	var unit = _make_unit(pos, 0, UNIT_COLORS[card_index])
	unit.unit_type = card_index
	add_child(unit)

func _spawn_enemy() -> void:
	var unit = _make_unit(
		Vector2(randf_range(60, 480), 180),
		1, Color(1.0, 0.25, 0.25)
	)
	add_child(unit)

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed_time += delta
	_regen_mana(delta)
	_update_ui()
	_update_flash(delta)
	enemy_spawn_timer += delta
	if enemy_spawn_timer >= 12.0:
		enemy_spawn_timer = 0.0
		_spawn_enemy()

func _regen_mana(delta: float) -> void:
	var rate = min(MANA_REGEN_START + elapsed_time * 0.03, MANA_REGEN_MAX)
	mana = min(mana + rate * delta, MANA_MAX)

func _update_ui() -> void:
	mana_bar.value = mana
	mana_label.text = str(int(mana)) + " / " + str(int(MANA_MAX))
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp

func _update_flash(delta: float) -> void:
	if player_flash_timer > 0:
		player_flash_timer -= delta
		var t = player_flash_timer / FLASH_DURATION
		player_castle_bg.color = Color(0.1, 0.2, 0.5).lerp(Color(1.0, 0.2, 0.2), t)
	else:
		player_castle_bg.color = Color(0.1, 0.2, 0.5)

	if enemy_flash_timer > 0:
		enemy_flash_timer -= delta
		var t = enemy_flash_timer / FLASH_DURATION
		enemy_castle_bg.color = Color(0.5, 0.1, 0.1).lerp(Color(1.0, 0.85, 0.1), t)
	else:
		enemy_castle_bg.color = Color(0.5, 0.1, 0.1)

func spend_mana(cost: float) -> bool:
	if mana >= cost:
		mana -= cost
		return true
	return false

func take_player_damage(amount: float) -> void:
	player_hp = max(0.0, player_hp - amount)
	player_flash_timer = FLASH_DURATION
	if player_hp <= 0:
		_end_game(false)

func take_enemy_damage(amount: float) -> void:
	enemy_hp = max(0.0, enemy_hp - amount)
	enemy_flash_timer = FLASH_DURATION
	if enemy_hp <= 0:
		_end_game(true)

func _end_game(win: bool) -> void:
	game_over = true
	var label = $UI/GameOverLabel
	label.text = "VICTORY!" if win else "GAME OVER"
	label.modulate = Color(0.2, 0.9, 0.2) if win else Color(0.9, 0.2, 0.2)
	label.visible = true
