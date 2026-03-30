extends Node2D

const PORT = 9999
const MAX_PLAYERS = 2

@onready var status_label = $UI/StatusLabel
@onready var host_btn = $UI/HostBtn
@onready var lan_host_btn = $UI/LanHostBtn
@onready var lan_ip_label = $UI/LanIPLabel
@onready var join_btn = $UI/JoinBtn
@onready var ip_input = $UI/IPInput
@onready var start_btn = $UI/StartBtn

func _ready() -> void:
	print("=== LOBBY READY uid=", multiplayer.get_unique_id(), " ===")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	host_btn.pressed.connect(_on_host_pressed)
	lan_host_btn.pressed.connect(_on_lan_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.visible = false
	ip_input.text = "127.0.0.1"

func _get_all_lan_ips() -> Array:
	var ips = []
	for addr in IP.get_local_addresses():
		if not "." in addr:
			continue
		if addr.begins_with("127."):
			continue
		if addr.begins_with("169.254."):
			continue
		ips.append(addr)
	return ips

# 192.168.x.x を優先、なければ最初のIPを返す
func _get_best_lan_ip(ips: Array) -> String:
	for addr in ips:
		if addr.begins_with("192.168."):
			return addr
	for addr in ips:
		if addr.begins_with("10."):
			return addr
	if ips.size() > 0:
		return ips[0]
	return "127.0.0.1"

func _on_host_pressed() -> void:
	_start_host()

func _on_lan_host_pressed() -> void:
	var ips = _get_all_lan_ips()
	var best = _get_best_lan_ip(ips)
	ip_input.text = best
	# 全IPを表示して手動で選べるようにする
	var all_str = " / ".join(ips)
	lan_ip_label.text = "選択中: " + best + "\n全IP: " + all_str
	_start_host()

func _start_host() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_PLAYERS)
	print("create_server err=", err)
	if err != OK:
		status_label.text = "ホスト起動失敗: " + str(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "待機中...\n相手の接続を待っています"
	host_btn.disabled = true
	lan_host_btn.disabled = true
	join_btn.disabled = true

func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	print("create_client ip=", ip, " err=", err)
	if err != OK:
		status_label.text = "接続失敗: " + str(err)
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = ip + " に接続中..."
	host_btn.disabled = true
	lan_host_btn.disabled = true
	join_btn.disabled = true

func _on_peer_connected(id: int) -> void:
	print("peer_connected id=", id, " is_server=", multiplayer.is_server())
	status_label.text = "接続完了！ (ID:" + str(id) + ")"
	if multiplayer.is_server():
		start_btn.visible = true

func _on_peer_disconnected(_id: int) -> void:
	status_label.text = "切断されました"
	start_btn.visible = false
	ip_input.text = "127.0.0.1"
	lan_ip_label.text = ""

func _on_connected_to_server() -> void:
	print("connected_to_server uid=", multiplayer.get_unique_id())
	status_label.text = "接続成功！\nホストの開始を待っています..."

func _on_connection_failed() -> void:
	print("connection_failed")
	status_label.text = "接続失敗"
	host_btn.disabled = false
	lan_host_btn.disabled = false
	join_btn.disabled = false

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
