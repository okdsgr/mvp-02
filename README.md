# Insect War RTS（虫の戦争）
	
	> 虫たちによるLAN対戦RTS／タワーディフェンス
	
	![Godot](https://img.shields.io/badge/Godot-4.6.1-blue) ![Multiplayer](https://img.shields.io/badge/Multiplayer-LAN-purple) ![Status](https://img.shields.io/badge/Status-Completed-green)
	
	## 概要
	
	LAN上でリアルタイム対戦するRTS＋タワーディフェンスゲーム。
	虫をテーマにしたユニットで相手の城を攻略する。Mac vs Windows の実機LAN対戦確認済み。
	
	## ゲームルール
	
	- 2プレイヤー対戦（LAN必須）
	- ユニット（虫）を生産・配置して相手の城を攻撃
	- 城のHPをゼロにした方が勝利
	- 赤チームは盤面を180°反転した視点でプレイ
	
	## 技術的特徴
	
	| 要素 | 内容 |
	|------|------|
	| 通信方式 | ENetMultiplayerPeer（PORT: 9999） |
	| チーム割り当て | RPC同期 |
	| 盤面反転 | CanvasTransform 180° |
	| 城UI | チームごとにミラー表示 |
	
	## LAN接続方法
	
	1. ホスト側（推奨: Mac）でゲームを起動し「ホスト」を選択
	2. ゲスト側でホストのIPアドレスを入力して接続
	3. Windowsファイアウォールでポート9999を許可
	
	## スプライト生成パイプライン
	
	- n8n ワークフロー: `JhKxeJcAfXpgqGdd` / `XqUakwv4hoqaK124`
	- シェルスクリプト: `sprite_to_godot_win.sh`（Mac/Win両対応）
	
	## 技術スタック
	
	- **エンジン**: Godot 4.6.1
	- **通信**: ENetMultiplayerPeer
	- **画像生成**: Replicate / flux-schnell + n8n
	
	## 開発者
	
	- **okdsgr** - メイン開発
	