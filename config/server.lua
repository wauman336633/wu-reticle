ServerConfig = ServerConfig or {}

-- ============================================================================
-- サーバー専用秘匿設定（クライアントには一切同期・公開されません）
-- ============================================================================

-- Discord Webhook URL（空文字の場合は送信しない）
-- ※ GitHub公開時にURLの誤コミットを防ぐため、server.cfg 側で `set wu_reticle_webhook "https://..."` を設定することも可能です
ServerConfig.WebhookUrl = GetConvar('wu_reticle_webhook', '')

-- サーバーストレージ保存時のクールダウン秒数（連打対策）
ServerConfig.CooldownSeconds = 1

-- Config.Storage = 'mysql' 時に起動時自動テーブル生成（CREATE TABLE IF NOT EXISTS）を行うか
ServerConfig.AutoMigrateSQL = true

-- KVP / MySQL で使用するプレフィックス
ServerConfig.StoragePrefix = 'wu_reticle'

-- サーバー側で許容する1プレイヤーあたりの最大マイプリセット保存数
ServerConfig.MaxPresets = 20

-- 1つのシェアコードの最大文字数制限（不正ペイロード対策）
ServerConfig.MaxShareCodeLength = 600
