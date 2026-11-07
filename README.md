# wu-reticle — Custom Reticle Studio for FiveM

プレイヤーごとに自由なレティクル（クロスヘア）を作成・個人保存し、短い1行テキストコード（`RT1:...`）で他プレイヤーや別サーバー環境とも即座に共有できる FiveM 用カスタムレティクルリソースです。

**特定フレームワークへの外部ファイル依存が一切ない単体完結型（Portable Multi-Framework Architecture）**のため、**Standalone / QBCore / Qbox / ESX** のどの環境でも `resources/` にフォルダをポン置きするだけでそのまま動作します。

---

## 主な特徴 (Features)

1. **基本4スロット ＋ 追加カスタムレイヤー（最大10レイヤー合成）**
   - **基本スロット**: センタードット（丸・四角・ダイヤ・リング）、インナーライン（内十字）、アウターライン（外十字）、サークル/円弧の4スロットを標準搭載。
   - **追加レイヤー（最大6個）**: シェブロン（ACOG風山型 `∧`）、単一直線（ミル目盛りバー）、十字線、T字線、円リング、ドットを **X/Y座標オフセット・回転角度付き** で自由に重ね合わせ可能。
2. **短い1行テキストでの共有（`RT1:` シェアコード形式）**
   - デフォルト値からの差分のみを圧縮した短いテキストコード（例: `RT1:n=CyanCross;d=0;i=1,0,6,2,3...`）をワンクリックでコピー＆ペースト読込可能。
   - 外部画像URLを一切使わず純粋なSVGベクターとして描画するため、画像リンク切れや不正画像の混入リスクがゼロ。
3. **クライアントKVP ＆ サーバーDB/KVPのハイブリッド個人保存**
   - 最大20件の名前付きマイプリセットを保存可能。
   - プレイヤーPC内の **Client KVP**（通信ラグゼロ・別サーバー環境でも保持）と、サーバー側の **Server KVP / `oxmysql`**（自動テーブル生成対応・手動SQLインポート不要）の両方に自動バックアップ。
4. **表示タイミングの切り替え ＆ サーバー管理者による制限機能**
   - プレイヤーは **「銃を構えている時のみ (`aim_only`)」「抜銃中 (`armed`)」「常時 (`always`)」「非表示 (`off`)」** から選択可能。
   - サーバー管理者は `config/shared.lua` の `Config.AllowedDisplayModes` を書き換えるだけで、特定モード（例: 常時表示の禁止など）をロック・強制可能。
   - ポーズメニュー（ESC）、他NUI操作中（インベントリ・スマホ等）、スナイパースコープ覗き込み中は自動でレティクルを一時非表示化。
5. **0.00ms 省電力設計 ＆ Zero-Build NUI**
   - 非武装時は低頻度スリープ＋状態変化時のみの差分メッセージ送信により、待機時 `0.00ms` の極小CPU負荷を実現。
   - 画面中央の実寸レティクルを遮らないサイドパネル型UIと、背景切り替え（夜間・昼空・市街地・実画面透過）付きの2.0倍ズームプレビューを搭載。

---

## 導入方法 (Installation)

1. [**Releases**](../../releases) から最新の `wu-reticle.zip` をダウンロードして解凍するか、`resources/` ディレクトリ内で以下を実行します：
   ```bash
   git clone https://github.com/wauman336633/wu-reticle.git
   ```
2. `server.cfg` に以下を追加します（または親フォルダごと `ensure` している場合は不要）：
   ```cfg
   ensure wu-reticle
   ```
3. ゲーム内で **`/reticle`** コマンドを実行するとレティクルスタジオが開きます。

> **Note**: 手動での `.sql` インポートや外部ライブラリの事前インストールは一切不要です。

---

## 設定ガイド (`config/shared.lua`)

本体スクリプト（`client/`, `server/`）を一切編集することなく、`config/shared.lua` だけでサーバー仕様に合わせて調整できます。

```lua
-- コマンド名とオプションキーバインド
Config.Commands = { 'reticle' }
Config.Keybind = '' -- 例: 'F9' を指定するとFiveMキーバインド設定へ自動登録

-- 初期状態の表示モード ('aim_only' | 'armed' | 'always' | 'off')
Config.DefaultDisplayMode = 'aim_only'

-- サーバー管理者がプレイヤーに許可する表示モード
-- 例: 常時表示を禁止し「構えている時のみ」に制限したい場合は always = false, armed = false に設定
Config.AllowedDisplayModes = {
    aim_only = true,
    armed    = true,
    always   = true,
    off      = true,
}

-- GTA V 純正の標準レティクル（HUD Component 14）を自動的に非表示にするか
Config.HideVanillaReticle = true

-- 車両乗車中のレティクル表示制御（デフォルトは両方 false＝非表示）
Config.AllowDriverReticle = false    -- 運転席（ドライバー）でのレティクル表示
Config.AllowPassengerReticle = false -- 助手席・後部座席（同乗者）でのレティクル表示
```

---

## 他リソース連携 (Client Exports & Events)

ポーズメニューやラジアルメニュー、武器設定メニューなど他のスクリプトから直接呼び出すことができます。

```lua
-- エディタを開く / 閉じる
exports['wu-reticle']:OpenEditor()
exports['wu-reticle']:CloseEditor()

-- 現在使用中の RT1 シェアコードを取得
local currentCode = exports['wu-reticle']:GetActiveShareCode()

-- RT1 シェアコードを外部から適用
exports['wu-reticle']:SetShareCode('RT1:n=Red Dot;d=1,c,4,ff2a55,100,1,1,000000,90;i=0')

-- 表示モードを変更 ('aim_only' | 'armed' | 'always' | 'off')
exports['wu-reticle']:SetDisplayMode('aim_only')

-- イベント経由でエディタを開く場合
TriggerEvent('wu-reticle:client:openEditor')
```

---

## ライセンス (License)

本リソースはカスタム利用規約（[LICENSE](./LICENSE)）のもとで公開されています。
- **許可**: ご自身の FiveM サーバーへの無料導入、およびサーバー内利用のための設定・コード改変。
- **禁止**: 作者の許可なき無断再配布・二次配布、および有料販売（Tebex等での転売）。
