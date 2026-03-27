extends Node2D

func _ready() -> void:
	print("=== MAIN READY ===")
	print("unique_id: ", multiplayer.get_unique_id())
	print("is_server: ", multiplayer.is_server())
	print("peers: ", multiplayer.get_peers())
	var peer = multiplayer.multiplayer_peer
	print("peer type: ", peer.get_class() if peer else "null")
