Hooks = Hooks or {}

-- ============================================================================
-- カスタムフック定義（本体ロジック client/・server/ を書き換えずに挙動を拡張）
-- ============================================================================

if not IsDuplicityVersion() then
    -- ========================================================================
    -- Client Hooks（クライアント側フック）
    -- ========================================================================

    --- レティクルエディタ画面を開く直前に呼ばれるフック
    --- @return boolean false を返すとUIのオープンをキャンセル可能
    function Hooks.OnOpenUI()
        local ped = PlayerPedId()
        if IsPedDeadOrDying(ped, true) then
            return false
        end
        return true
    end

    --- 現在のフレーム・状態でカスタムレティクルを表示してよいかの追加判定フック
    --- 特定のジョブやイベント中、あるいは特定武器でレティクルを強制非表示にしたい場合にカスタマイズ可能
    --- @param ped number PlayerPedId()
    --- @param weaponHash number 現在装備中の武器ハッシュ
    --- @param displayMode string 現在の表示モード ('aim_only' | 'armed' | 'always' | 'off')
    --- @return boolean true で表示許可、false で強制非表示
    function Hooks.ShouldShowReticle(ped, weaponHash, displayMode)
        return true
    end

else
    -- ========================================================================
    -- Server Hooks（サーバー側フック）
    -- ========================================================================

    --- プレイヤーがサーバーへレティクル設定・プリセットを保存できるかの事前検証フック
    --- @param source number プレイヤーのサーバーID
    --- @param action string アクション識別子
    --- @param data table クライアントから送信されたペイロード
    --- @return boolean, string? 実行可否と、拒否時のエラーメッセージ（翻訳キーまたは文字列）
    function Hooks.CanExecuteAction(source, action, data)
        if not source or source <= 0 then
            return false, 'error_invalid_player'
        end
        return true, nil
    end

    --- 保存アクションが正常完了した直後に呼ばれる事後フック
    --- @param source number プレイヤーのサーバーID
    --- @param action string アクション識別子
    --- @param result table 実行結果データ
    function Hooks.OnActionSuccess(source, action, result)
        if Config.Debug then
            print(('[Hooks.OnActionSuccess] Player: %s | Action: %s'):format(tostring(source), tostring(action)))
        end
    end

    --- 監査ログ・Discord Webhook 送信フック
    --- @param source number プレイヤーのサーバーID
    --- @param title string ログタイトル
    --- @param message string ログ本文
    function Hooks.SendLog(source, title, message)
        local webhook = ServerConfig and ServerConfig.WebhookUrl or ''
        if webhook == '' then
            return
        end

        local payload = json.encode({
            username = GetCurrentResourceName(),
            embeds = {
                {
                    title = title,
                    description = ('**Player ID:** `%s`\n%s'):format(tostring(source), tostring(message)),
                    color = 1096065, -- #10b981
                }
            }
        })

        PerformHttpRequest(webhook, function() end, 'POST', payload, {
            ['Content-Type'] = 'application/json'
        })
    end
end
