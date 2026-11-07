Config = Config or {}

-- ============================================================================
-- 1. 基本・デバッグ・言語設定
-- ============================================================================
Config.Debug = false

-- 言語設定（サーバーの qb_locale Convar を優先、未設定時は 'ja'）
-- 'ja' | 'en' （locales/ 内のファイル名に対応）
Config.Locale = GetConvar('qb_locale', 'ja')

-- ============================================================================
-- 2. マルチ環境 Bridge 自動検出・明示指定設定
-- ============================================================================
-- フレームワーク: 'auto' | 'qb' | 'qbx' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- インベントリ: 'auto' | 'ox' | 'qb' | 'esx' | 'standalone'
Config.Inventory = 'auto'

-- ターゲット / インタラクション: 'auto' | 'ox' | 'qb' | 'drawtext'
Config.Target = 'auto'

-- 通知・メニュー・プログレスUI: 'auto' | 'ox' | 'qb' | 'native'
Config.UI = 'auto'

-- サーバー側データ永続化ストレージ: 'kvp' | 'mysql' | 'auto'
-- ※ クライアントKVP（プレイヤーPC内保存）とハイブリッドで自動同期されます
Config.Storage = 'kvp'

-- ============================================================================
-- 3. コマンド・キーバインド・起動設定
-- ============================================================================
-- レティクルエディタを開くコマンド名
Config.Commands = { 'reticle' }

-- キーバインド設定（空文字 '' の場合は未割当、'F9' 等を指定するとFiveMキー設定に登録）
Config.Keybind = ''

-- インタラクション地点設定（不要な場合は空テーブルのまま）
Config.Locations = {}

-- ============================================================================
-- 4. レティクル表示タイミング・サーバー管理者制御
-- ============================================================================
-- 初期状態の表示モード:
-- 'aim_only' : 銃を構えている（ADS / 右クリック）時のみ表示
-- 'armed'    : 銃器を手に持っている（抜銃）間は常時表示
-- 'always'   : 素手・移動中を含め常時表示
-- 'off'      : カスタムレティクルを非表示
Config.DefaultDisplayMode = 'aim_only'

-- サーバー管理者がプレイヤーに許可する表示モード
-- 例: 常時表示を禁止し「構えている時のみ」に制限したい場合は always = false, armed = false に設定
Config.AllowedDisplayModes = {
    aim_only = true,
    armed    = true,
    always   = false,
    off      = true,
}

-- GTA V 純正の標準レティクル（HUD Component 14）を自動的に非表示にするか
Config.HideVanillaReticle = true

-- スナイパーライフル等のフルスクリーンスコープ覗き込み中にカスタムレティクルを自動で隠すか（初期値）
Config.DefaultHideOnScope = true

-- 一人称視点（FPS視点）で銃を構えた際にもカスタムレティクルを表示するか（初期値）
Config.DefaultShowInFirstPerson = true

-- 車両乗車中のレティクル表示制御（サーバー管理者設定・デフォルトは両方 false＝非表示）
-- AllowDriverReticle    : 運転席（ドライバー）でのレティクル表示を許可するか
-- AllowPassengerReticle : 助手席・後部座席（同乗者）でのレティクル表示を許可するか
Config.AllowDriverReticle = false
Config.AllowPassengerReticle = false

-- ============================================================================
-- 5. エディタ上限・初期プリセット設定
-- ============================================================================
-- プレイヤー個人が保存できるマイプリセットの最大数
Config.MaxPlayerPresets = 20

-- 追加カスタムレイヤーの最大数（標準4スロット + 追加6レイヤー = 最大10レイヤー）
Config.MaxCustomLayers = 6

-- 初期状態の標準レティクルコード（RT1形式）
Config.DefaultShareCode = 'RT1:n=Default Cyan;d=1,c,3,00ffcc,100,1,1,000000,80;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,80,0'

-- サーバー標準搭載のプリセット一覧（削除不可のテンプレートとして全プレイヤーに表示）
Config.BuiltInPresets = {
    {
        id = 'builtin_cyan_cross',
        name = 'スタンダード・シアンクロス',
        code = 'RT1:n=Standard Cyan;d=0;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,85,0',
    },
    {
        id = 'builtin_red_dot',
        name = 'プレシジョン・レッドドット',
        code = 'RT1:n=Red Dot;d=1,c,4,ff2a55,100,1,1,000000,90;i=0',
    },
    {
        id = 'builtin_tactical_t',
        name = 'タクティカル・Tクロス (Green)',
        code = 'RT1:n=Tactical T;d=1,c,2,22c55e,100,1,1,000000,80;i=1,1,7,2,4,0,22c55e,100,1,1,000000,85,0',
    },
    {
        id = 'builtin_circle_hybrid',
        name = 'サークル＆クロス・ハイブリッド',
        code = 'RT1:n=Circle Hybrid;d=1,c,2,ffffff,100,1,1,000000,80;i=1,0,5,2,5,0,ffffff,95,1,1,000000,80,0;c=1,10,2,360,0,38bdf8,75,1,1,000000,70',
    },
    {
        id = 'builtin_acog_chevron',
        name = 'ACOG シェブロン＆ミル目盛り',
        code = 'RT1:n=ACOG Chevron;d=0;i=0;o=1,1,8,1,18,0,ffffff,65,1,1,000000,70,0;L=chevron,1,8,2,0,70,0,0,0,f43f5e,100,1,1,000000,85|line,1,6,2,0,0,0,0,10,f43f5e,85,1,1,000000,75|line,1,4,2,0,0,0,0,18,f43f5e,70,1,1,000000,75',
    },
    {
        id = 'builtin_shotgun_ring',
        name = 'ショットガン・ワイドリング',
        code = 'RT1:n=Shotgun Ring;d=1,d,3,f59e0b,100,1,1,000000,85;i=0;c=1,18,2,360,0,f59e0b,85,1,1,000000,75',
    },
}

-- ============================================================================
-- 6. Zero-Build NUI テーマ設定（CSS変数としてNUIへ自動注入）
-- ============================================================================
Config.UITheme = {
    primaryColor = '#10b981',      -- メインアクセントカラー（エメラルドグリーン）
    accentColor = '#3b82f6',       -- サブアクセントカラー（ブルー）
    backgroundOpacity = '0.94',    -- パネル背景の不透明度（0.0 〜 1.0）
    borderRadius = '12px',         -- パネル・ボタンの角丸サイズ
    position = 'right',            -- エディタパネル表示位置: 'right' | 'left' （画面中央のレティクルを遮らない配置）
}
