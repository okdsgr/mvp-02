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

func _get_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		# IPv4 かつ ループバック・リンクローカル除外
		if "." in addr and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			return addr
	return "127.0.0.1"

func _on_host_pressed() -> void:
	print("host button pressed (localhost)")
	_start_host("127.0.0.1")

func _on_lan_host_pressed() -> void:
	print("LAN host button pressed")
	var lan_ip = _get_lan_ip()
	ip_input.text = lan_ip
	lan_ip_label.text = "LAN IP: " + lan_ip + "  ← 相手に伝えてください"
	_start_host(lan_ip)

func _start_host(display_ip: String) -> void:
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
	print("join button pressed")
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	print("create_client err=", err)
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
	print("start pressed is_server=", multiplayer.is_server())
	if multiplayer.is_server():
		_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	print("_start_game called is_server=", multiplayer.is_server())
	get_tree().change_scene_to_file("res://scenes/main.tscn")
