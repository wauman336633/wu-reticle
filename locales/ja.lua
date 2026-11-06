Locales = Locales or {}

Locales['ja'] = {
    -- ヘッダー・共通
    ['ui_title'] = 'カスタムレティクル・スタジオ',
    ['ui_subtitle'] = 'レイヤー合成 ＆ シェアコード共有',
    ['ui_close'] = '閉じる (ESC)',
    ['ui_reset'] = '初期化',
    ['ui_save_preset'] = 'マイプリセットに保存',
    ['ui_apply_close'] = '適用して閉じる',

    -- タブナビゲーション
    ['tab_standard'] = '基本スロット (4)',
    ['tab_layers'] = '追加レイヤー (最大6)',
    ['tab_display'] = '表示・動作設定',
    ['tab_presets'] = 'プリセット ＆ 共有',

    -- プレビュー＆背景切替
    ['preview_title'] = '拡大プレビュー（画面中央にも実寸反映中）',
    ['bg_transparent'] = '透過 (実画面)',
    ['bg_day'] = '昼空 (明)',
    ['bg_night'] = '夜間 (暗)',
    ['bg_urban'] = '市街地',
    ['label_global_scale'] = '全体スケール (%)',
    ['label_global_opacity'] = '全体不透明度 (%)',

    -- 基本4スロット名称
    ['slot_dot'] = 'センタードット',
    ['slot_inner'] = 'インナーライン (内十字)',
    ['slot_outer'] = 'アウターライン (外十字)',
    ['slot_circle'] = 'サークル / リング',

    -- パラメータ共通ラベル
    ['param_enabled'] = '有効化',
    ['param_shape'] = '形状',
    ['param_color'] = 'カラー',
    ['param_opacity'] = '不透明度',
    ['param_size'] = 'サイズ / 長さ',
    ['param_length'] = '線の長さ',
    ['param_thickness'] = '線の太さ',
    ['param_gap'] = '中心ギャップ',
    ['param_radius'] = '半径',
    ['param_arc'] = '円弧角度 (°)',
    ['param_angle'] = '開き角度 (°)',
    ['param_rotation'] = '回転角度 (°)',
    ['param_offset_x'] = 'X座標オフセット',
    ['param_offset_y'] = 'Y座標オフセット',
    ['param_t_style'] = 'T字スタイル (上線を隠す)',
    ['param_round_caps'] = '先端を丸める',
    ['param_outline'] = 'アウトライン (縁取り)',
    ['param_outline_width'] = '縁取りの太さ',
    ['param_outline_color'] = '縁取りカラー',
    ['param_outline_opacity'] = '縁取り不透明度',

    -- 図形プリミティブ名
    ['shape_circle'] = '丸 (Circle)',
    ['shape_square'] = '四角 (Square)',
    ['shape_diamond'] = 'ダイヤ (Diamond)',
    ['shape_ring'] = '中抜き丸 (Ring)',
    ['shape_cross'] = '十字線 (Cross +)',
    ['shape_tcross'] = 'T字線 (T-Cross)',
    ['shape_chevron'] = 'シェブロン (山型 ∧)',
    ['shape_line'] = '単一直線 (目盛りバー)',

    -- 追加レイヤー操作
    ['btn_add_layer'] = '＋ カスタムレイヤーを追加',
    ['layer_empty_hint'] = '「＋ カスタムレイヤーを追加」からシェブロン(∧)やミル目盛り、追加リング等を最大6個まで重ねられます。',
    ['layer_item_title'] = '追加レイヤー #%{index}',
    ['btn_duplicate_layer'] = '複製',
    ['btn_delete_layer'] = '削除',

    -- 表示タイミング・動作設定
    ['display_mode_title'] = 'レティクル表示タイミング',
    ['display_mode_desc'] = 'ゲーム内でカスタムレティクルを表示する条件を選択します（※サーバー設定により一部ロックされている場合があります）。',
    ['mode_aim_only'] = '銃を構えている時のみ (ADS)',
    ['mode_aim_only_desc'] = '右クリックで銃を構えている間だけ表示します。',
    ['mode_armed'] = '武器を手に持っている間 (抜銃中)',
    ['mode_armed_desc'] = '銃器を装備している間は腰だめ時も含めて常時表示します。',
    ['mode_always'] = '常時表示 (Always)',
    ['mode_always_desc'] = '素手や移動中を含め、常に画面中央へ表示します。',
    ['mode_off'] = '非表示 (OFF)',
    ['mode_off_desc'] = 'カスタムレティクルを一時的にオフにします。',
    ['mode_locked_badge'] = 'サーバー制限により選択不可',
    ['opt_hide_on_scope'] = 'スナイパースコープ覗き込み中は自動で隠す',
    ['opt_show_in_fp'] = '一人称視点 (FPS) エイム中も表示する',

    -- シェアコード共有・プリセット
    ['share_title'] = 'テキスト共有コード (RT1形式)',
    ['share_desc'] = '現在のレティクルを短い1行テキストとしてコピーしたり、他の人や別環境のコードを貼り付けて即座に読み込めます。',
    ['btn_copy_code'] = 'コードをコピー',
    ['btn_import_code'] = 'コードを読込',
    ['placeholder_share_code'] = 'RT1:... から始まる共有コードを貼り付け',
    ['preset_save_title'] = '現在のレティクルをマイプリセットに保存',
    ['placeholder_preset_name'] = 'プリセット名を入力 (例: アサルト用シアン)',
    ['btn_save_new_preset'] = '新規保存',
    ['btn_overwrite_preset'] = '選択中に上書き',
    ['my_presets_title'] = 'マイプリセット一覧',
    ['builtin_presets_title'] = 'サーバー標準プリセット',
    ['preset_empty_hint'] = '保存されたマイプリセットはまだありません。',
    ['btn_load'] = '適用',
    ['btn_copy'] = 'コード',
    ['btn_delete'] = '削除',

    -- 通知・フィードバックメッセージ
    ['msg_code_copied'] = '共有コードをクリップボードにコピーしました！',
    ['msg_code_imported'] = '共有コードからレティクルを読み込みました。',
    ['msg_invalid_code'] = '無効な共有コードです。RT1: から始まる正しいコードを入力してください。',
    ['msg_preset_saved'] = 'マイプリセット「%{name}」を保存しました。',
    ['msg_preset_deleted'] = 'マイプリセットを削除しました。',
    ['msg_preset_limit'] = 'マイプリセットの保存上限（最大%{max}件）に達しています。',
    ['msg_reset_done'] = 'レティクルを初期状態にリセットしました。',
    ['msg_saved_sync'] = 'レティクル設定を保存しました。',
    ['error_cannot_interact'] = '現在レティクルエディタを開くことはできません。',
    ['error_invalid_player'] = 'プレイヤー情報の取得に失敗しました。',
}
